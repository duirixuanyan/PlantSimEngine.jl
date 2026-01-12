# 编写多尺度模拟

本小节分为三部分，逐步带你从零构建一个多尺度模拟。这主要演示你在开发和逐步调整一个功能-结构植物模型（FSPM）过程中会经历的迭代流程，而前面的多尺度示例更多侧重于API语法的介绍。

你可以在示例文件夹下的 [ToyMultiScalePlantModel](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyMultiScalePlantModel/ToyPlantSimulation1.jl) 子目录找到本节第一部分的玩具模拟完整脚本。

```@contents
Pages = ["multiscale_example_1.md"]
Depth = 3
```

## 声明

这里实现的“植物”以及自定义模型并没有真正的生物学意义，仅为临时拼凑（因此大多也不是 examples 文件夹内的标准独立模型）。同样地，许多参数都纯属虚构，并不对应真实的文献或实验数据。

这里的重点在于展示 PlantSimEngine 的多尺度特性和模型的组织方式，而不是准确性、现实性或性能。

## 初始化设置

像往常一样，我们需要先在 Julia 环境中添加并使用几个包：

```@example usepkg
using PlantSimEngine
using PlantSimEngine.Examples # 导入 ToyDegreeDaysCumulModel 示例模型
using PlantMeteo
using MultiScaleTreeGraph # 多尺度
using CSV, DataFrames # 导入示例气象数据
```

## 一个基础的生长植物模型

要模拟一个简单的“生长”过程，至少需要：

- 一个多尺度树图（MTG）来表示植物本体
- 一种向植物中添加新器官的方法
- 某种时间推进机制，让生长能够跨多个时间步展开

我们先设定一个“叶片”的概念，用以吸收生长器官所需的（碳）资源；器官的产生则发生在“节间”层级，这样可以演示不同类型器官的行为差异。

我们将假设节间利用的是来自公共碳池的碳。我们还将利用积温作为生长延迟因子。

总结下来，模型包括如下内容：
- 一个包含生长中节间和叶片的 MTG
- 不同叶片分别吸收碳，但都汇总到一个公共池
- 节间从碳池中获取资源来制造新器官，但过程受到积温的限制

这种建模方式可以按照多个尺度和模型来实现：

- 场景（Scene）尺度：用于累积温度积算时间。 [examples 文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyDegreeDays.jl) 中的 [`ToyDegreeDaysCumulModel`](@ref) 可根据温度数据计算积温
- 植株（Plant）尺度：定义碳资源池
- 节间（Internode）尺度：从碳池中抽取碳，产生新器官
- 叶片（Leaf）尺度：负责碳捕获

此外，我们还人为地引入一个限制：如果总叶面积超过某一阈值，则不再生成新器官。

仿真的模型与比例映射大致如下所示（实际会更复杂）：

```julia
mapping = Dict(
"Scene" => ToyDegreeDaysCumulModel(),
"Plant" => ToyStockComputationModel(),
"Internode" => ToyCustomInternodeEmergence(),
"Leaf" => ToyLeafCarbonCaptureModel(),
)
```

其中，部分模型需要获取别的尺度上的变量信息，因此需要转化为 MultiScaleModels。

## 实现

### 碳捕获

我们先从最简单的模型开始。我们的“假”叶片在每个时间步都持续固定地捕获一定量的碳。该模型不需要任何输入或参数。

```@example usepkg
PlantSimEngine.@process "leaf_carbon_capture" verbose = false

struct ToyLeafCarbonCaptureModel<: AbstractLeaf_Carbon_CaptureModel end

function PlantSimEngine.inputs_(::ToyLeafCarbonCaptureModel)
    NamedTuple() # 无需输入
end

function PlantSimEngine.outputs_(::ToyLeafCarbonCaptureModel)
    (carbon_captured=0.0,)
end

function PlantSimEngine.run!(::ToyLeafCarbonCaptureModel, models, status, meteo, constants, extra)   
    status.carbon_captured = 40
end
```

### 资源储存

用于存储整个植株资源的模型需要两个输入：叶片捕获的碳量，以及用于新器官形成所消耗的碳量。该模型输出当前的碳库量。

```@example usepkg
PlantSimEngine.@process "resource_stock_computation" verbose = false

struct ToyStockComputationModel <: AbstractResource_Stock_ComputationModel
end

PlantSimEngine.inputs_(::ToyStockComputationModel) = 
(carbon_captured=0.0,carbon_organ_creation_consumed=0.0)

PlantSimEngine.outputs_(::ToyStockComputationModel) = (carbon_stock=-Inf,)

function PlantSimEngine.run!(m::ToyStockComputationModel, models, status, meteo, constants=nothing, extra=nothing)
    status.carbon_stock += sum(status.carbon_captured) - sum(status.carbon_organ_creation_consumed)
end
```

### 器官创建

本模型为 ToyInternodeEmergence 模型的改进版本，[可以在 examples 文件夹中找到](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyInternodeEmergence.jl)。一个节间会生成两个叶片和一个新的节间。

我们首先定义一个辅助函数，用于遍历多尺度树图，并返回叶片的数量：

```@example usepkg
function get_n_leaves(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    nleaves = length(MultiScaleTreeGraph.traverse(root, x->1, symbol="Leaf"))
    return nleaves
end
```

现在我们已经有了这些，让我们为模型定义几个参数。需要以下参数：
- 一个积温出苗阈值
- 器官形成的碳消耗成本

我们还将添加另外几个参数，这些参数可以放在其他位置：
- 叶片的表面积（无变化，无生长阶段）
- 叶片最大表面积，超过此值器官形成停止

```@example usepkg
PlantSimEngine.@process "organ_emergence" verbose = false

struct ToyCustomInternodeEmergence{T} <: AbstractOrgan_EmergenceModel
    TT_emergence::T
    carbon_internode_creation_cost::T
    leaf_surface_area::T
    leaves_max_surface_area::T
end
```

!!! note 
    这里我们采用了参数化类型而非直观的 Float64，以获得更高的灵活性。详情请参见[参数化类型](@ref)。

并为它们设置一些默认值：

```@example usepkg
ToyCustomInternodeEmergence(;TT_emergence=300.0, carbon_internode_creation_cost=200.0, leaf_surface_area=3.0, leaves_max_surface_area=100.0) = ToyCustomInternodeEmergence(TT_emergence, carbon_internode_creation_cost, leaf_surface_area, leaves_max_surface_area)
```

节间模型需要积温和可用的碳，并输出碳的消耗量，以及最近一次器官发生时的积温（当同一节间可以多次产生新器官时很有用，但本例中不会发生）。

```@example usepkg
PlantSimEngine.inputs_(m::ToyCustomInternodeEmergence) = (TT_cu=0.0, carbon_stock=0.0)
PlantSimEngine.outputs_(m::ToyCustomInternodeEmergence) = (TT_cu_emergence=0.0, carbon_organ_creation_consumed=0.0)
```

最后，[`run!`](@ref) 函数会检查是否满足创建新器官的条件：
- 积温超过阈值
- 所有叶片的总表面积不超过限定阈值
- 碳储量充足
- 该节间还没有创建新器官

满足条件时会更新 MTG。

```@example usepkg
function PlantSimEngine.run!(m::ToyCustomInternodeEmergence, models, status, meteo, constants=nothing, sim_object=nothing)

    leaves_surface_area = m.leaf_surface_area * get_n_leaves(status.node)
    status.carbon_organ_creation_consumed = 0.0

    if leaves_surface_area > m.leaves_max_surface_area
        return nothing
    end
    
    # if not enough carbon, no organ creation
    if status.carbon_stock < m.carbon_internode_creation_cost
        return nothing
    end
  
    if length(MultiScaleTreeGraph.children(status.node)) == 2 && 
        status.TT_cu - status.TT_cu_emergence >= m.TT_emergence            
        status_new_internode = add_organ!(status.node, sim_object, "<", "Internode", 2, index=1)
        add_organ!(status_new_internode.node, sim_object, "+", "Leaf", 2, index=1)
        add_organ!(status_new_internode.node, sim_object, "+", "Leaf", 2, index=1) 

        status_new_internode.TT_cu_emergence = m.TT_emergence - status.TT_cu
        status.carbon_organ_creation_consumed = m.carbon_internode_creation_cost
    end

    return nothing
end
```

### 更新后的映射

现在我们可以为本次模拟定义最终的映射。

碳捕获和积温模型不需要从早期版本进行更改。
"节间"尺度的器官创建模型需要来自"植株"尺度的碳库存，以及来自"场景"尺度的积温。
"植株"尺度的资源存储模型需要**每个**叶片捕获的碳，以及**每个**在此时间步创建了新器官的节间所消耗的碳。这需要对向量变量进行映射：

```julia
 mapped_variables=[
            :carbon_captured=>["Leaf"],
            :carbon_organ_creation_consumed=>["Internode"]
        ],
```
这与只映射单变量（如碳存量）有所不同。例如：

```julia
 mapped_variables=[:TT_cu => "Scene",
            PreviousTimeStep(:carbon_stock)=>"Plant"],
```

当然，某些变量也需要在 status 结构体中初始化：

```@example usepkg
mapping = Dict(
    "Scene" => ToyDegreeDaysCumulModel(),
    "Plant" => (
        MultiScaleModel(
            model=ToyStockComputationModel(),          
            mapped_variables=[
                :carbon_captured=>["Leaf"],
                :carbon_organ_creation_consumed=>["Internode"]
            ],
        ),
        Status(carbon_stock = 0.0)
    ),
    "Internode" => (        
        MultiScaleModel(
            model=ToyCustomInternodeEmergence(), # TT_emergence=20.0
            mapped_variables=[
                :TT_cu => "Scene",
                PreviousTimeStep(:carbon_stock)=>"Plant"
            ],
        ),        
        Status(carbon_organ_creation_consumed=0.0),
    ),
    "Leaf" => ToyLeafCarbonCaptureModel(),
)
```

!!! note
    以上代码片段（以及完整脚本）展示了经过完整初始化的最终映射结构。但在开发过程中，建议多使用辅助函数[`to_initialize`](@ref)并关注 PlantSimEngine 的用户报错信息，以便及时发现和修正未初始化的变量。

### 运行模拟

我们只需要一个 MTG，以及一些气象数据，就可以开始模拟了。让我们先创建一个简单的 MTG：

```@example usepkg
 mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 1, 0))   
    plant = MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
    
    internode1 = MultiScaleTreeGraph.Node(plant, MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
    MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))

    internode2 = MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("<", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode2, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
    MultiScaleTreeGraph.Node(internode2, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
```

导入气象数据：

```@example usepkg
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
nothing # hide
```

就可以开始模拟啦！

```@example usepkg
outs = run!(mtg, mapping, meteo_day)
```

如果你在模拟之后查询或显示 MTG，你会发现它扩展并生长出了多个节间和叶片：

```@example usepkg
mtg
# get_n_leaves(mtg)
```

就是这样！可以随意调整参数，看看什么时候模拟会崩溃，从而更好地理解模拟过程。

当然，这只是一个非常粗糙且不现实的模拟，存在很多有问题的假设和参数。但通过同样的方法，也可以实现显著更复杂的建模：XPalm 就是在九个尺度上，利用几十个模型运行的。

本教程为三部分内容，后续章节请参考[扩展多尺度模拟](@ref)。