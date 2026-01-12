# 修复植物模拟中的Bug

```@setup usepkg
using PlantSimEngine
using PlantSimEngine.Examples
using PlantMeteo, CSV, DataFrames
using MultiScaleTreeGraph

function get_root_end_node(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    return MultiScaleTreeGraph.traverse(root, x->x, symbol="Root", filter_fun = MultiScaleTreeGraph.isleaf)
end

function get_roots_count(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    return length(MultiScaleTreeGraph.traverse(root, x->x, symbol="Root"))
end

function get_n_leaves(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    nleaves = length(MultiScaleTreeGraph.traverse(root, x->1, symbol="Leaf"))
    return nleaves
end

PlantSimEngine.@process "organ_emergence" verbose = false

struct ToyCustomInternodeEmergence{T} <: AbstractOrgan_EmergenceModel
    TT_emergence::T
    carbon_internode_creation_cost::T
    leaf_surface_area::T
    leaves_max_surface_area::T
    water_leaf_threshold::T
end

ToyCustomInternodeEmergence(;TT_emergence=300.0, carbon_internode_creation_cost=200.0, leaf_surface_area=3.0,leaves_max_surface_area=100.0,
water_leaf_threshold=30.0) = ToyCustomInternodeEmergence(TT_emergence, carbon_internode_creation_cost, leaf_surface_area, leaves_max_surface_area, water_leaf_threshold)

PlantSimEngine.inputs_(m::ToyCustomInternodeEmergence) = (TT_cu=0.0,water_stock=0.0, carbon_stock=0.0)
PlantSimEngine.outputs_(m::ToyCustomInternodeEmergence) = (TT_cu_emergence=0.0, carbon_organ_creation_consumed=0.0)

function PlantSimEngine.run!(m::ToyCustomInternodeEmergence, models, status, meteo, constants=nothing, sim_object=nothing)
    leaves_surface_area = m.leaf_surface_area * get_n_leaves(status.node)
    status.carbon_organ_creation_consumed = 0.0

    if leaves_surface_area > m.leaves_max_surface_area
        return nothing
    end
    
    # 如果水分不够，优先生长根
    if status.water_stock < m.water_leaf_threshold
        return nothing
    end

    # 如果碳不够，则不生长器官
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

############################
# 简易水分吸收模型
# 按根的数量吸收降水
############################
PlantSimEngine.@process "water_absorption" verbose = false

struct ToyWaterAbsorptionModel <: AbstractWater_AbsorptionModel
end

PlantSimEngine.inputs_(::ToyWaterAbsorptionModel) = (root_water_assimilation=1.0,)
PlantSimEngine.outputs_(::ToyWaterAbsorptionModel) = (water_absorbed=0.0,)

function PlantSimEngine.run!(m::ToyWaterAbsorptionModel, models, status, meteo, constants=nothing, extra=nothing)
    #root_end = get_root_end_node(status.node)
    #root_len = root_end[:Root_len]
    status.water_absorbed = meteo.Precipitations * status.root_water_assimilation #* root_len
end

PlantSimEngine.TimeStepDependencyTrait(::Type{<:ToyWaterAbsorptionModel}) = PlantSimEngine.IsTimeStepIndependent()
PlantSimEngine.ObjectDependencyTrait(::Type{<:ToyWaterAbsorptionModel}) = PlantSimEngine.IsObjectIndependent()

##########################
### 根的生长：当水分库较低时扩展根
##########################

PlantSimEngine.@process "root_growth" verbose = false

struct ToyRootGrowthModel{T} <: AbstractRoot_GrowthModel
    water_threshold::T
    carbon_root_creation_cost::T
    root_max_len::Int
end

PlantSimEngine.inputs_(::ToyRootGrowthModel) = (water_stock=0.0,carbon_stock=0.0,)
PlantSimEngine.outputs_(::ToyRootGrowthModel) = (carbon_root_creation_consumed=0.0,)

function PlantSimEngine.run!(m::ToyRootGrowthModel, models, status, meteo, constants=nothing, extra=nothing)
    if status.water_stock < m.water_threshold && status.carbon_stock > m.carbon_root_creation_cost
        
        root_end = get_root_end_node(status.node)
        
        if length(root_end) != 1 
            throw(AssertionError("未找到符号为\"Root\"的MTG叶节点"))
        end
        root_len = get_roots_count(root_end[1])
        if root_len < m.root_max_len
            st = add_organ!(root_end[1], extra, "<", "Root", 2, index=1)
            status.carbon_root_creation_consumed = m.carbon_root_creation_cost
        end
    else
        status.carbon_root_creation_consumed = 0.0
    end
end

##########################
### 资源累积模型：碳和水
##########################

PlantSimEngine.@process "resource_stock_computation" verbose = false

struct ToyStockComputationModel <: AbstractResource_Stock_ComputationModel
end
#status.water_stock += meteo.precipitations * root_water_assimilation_ratio

PlantSimEngine.inputs_(::ToyStockComputationModel) = 
(water_absorbed=0.0,carbon_captured=0.0,carbon_organ_creation_consumed=0.0,carbon_root_creation_consumed=0.0)

PlantSimEngine.outputs_(::ToyStockComputationModel) = (water_stock=-Inf,carbon_stock=-Inf)

function PlantSimEngine.run!(m::ToyStockComputationModel, models, status, meteo, constants=nothing, extra=nothing)
    status.water_stock += sum(status.water_absorbed) #- status.water_transpiration
    status.carbon_stock += sum(status.carbon_captured) - sum(status.carbon_organ_creation_consumed) - sum(status.carbon_root_creation_consumed)

    if status.water_stock < 0.0
        status.water_stock = 0.0
    end
end

PlantSimEngine.TimeStepDependencyTrait(::Type{<:ToyStockComputationModel}) = PlantSimEngine.IsTimeStepIndependent()
PlantSimEngine.ObjectDependencyTrait(::Type{<:ToyStockComputationModel}) = PlantSimEngine.IsObjectIndependent()

########################
## 叶片碳固定模型
########################

PlantSimEngine.@process "leaf_carbon_capture" verbose = false

struct ToyLeafCarbonCaptureModel<: AbstractLeaf_Carbon_CaptureModel end

function PlantSimEngine.inputs_(::ToyLeafCarbonCaptureModel)
    NamedTuple()#(TT_cu=-Inf)
end

function PlantSimEngine.outputs_(::ToyLeafCarbonCaptureModel)
    (carbon_captured=0.0,)
end

function PlantSimEngine.run!(::ToyLeafCarbonCaptureModel, models, status, meteo, constants, extra)   
    # 非常粗糙的近似：LAI=1且PPFD恒定
    status.carbon_captured = 200.0 *(1.0 - exp(-0.2))
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:ToyLeafCarbonCaptureModel}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:ToyLeafCarbonCaptureModel}) = PlantSimEngine.IsTimeStepIndependent()

mapping = Dict(
"Scene" => ToyDegreeDaysCumulModel(),
"Plant" => (
    MultiScaleModel(
        model=ToyStockComputationModel(),          
        mapped_variables=[
            :carbon_captured=>["Leaf"],
            :water_absorbed=>["Root"],
            :carbon_root_creation_consumed=>["Root"],
            :carbon_organ_creation_consumed=>["Internode"]

        ],
        ),
        Status(water_stock = 0.0, carbon_stock = 0.0)
    ),
"Internode" => (        
        MultiScaleModel(
            model=ToyCustomInternodeEmergence(), # TT_emergence=20.0
            mapped_variables=[:TT_cu => "Scene",
            PreviousTimeStep(:water_stock)=>"Plant",
            PreviousTimeStep(:carbon_stock)=>"Plant"],
        ),        
        Status(carbon_organ_creation_consumed=0.0),
    ),
"Root" => ( MultiScaleModel(
            model=ToyRootGrowthModel(10.0, 50.0, 10),
            mapped_variables=[PreviousTimeStep(:carbon_stock)=>"Plant",
            PreviousTimeStep(:water_stock)=>"Plant"],
        ),       
            ToyWaterAbsorptionModel(),
            Status(carbon_root_creation_consumed=0.0, root_water_assimilation=1.0),
            ),
"Leaf" => ( ToyLeafCarbonCaptureModel(),),
)

    mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 1, 0))   

    plant = MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
    
    internode1 = MultiScaleTreeGraph.Node(plant, MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
    MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))

    internode2 = MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("<", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode2, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
    MultiScaleTreeGraph.Node(internode2, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))

    plant_root_start = MultiScaleTreeGraph.Node(
        plant, 
        MultiScaleTreeGraph.NodeMTG("+", "Root", 1, 3), 
    )

    meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
    
```

在上一章的实现中有两个关键问题，这里我们会分析和解决这两个问题。

本节完整模拟脚本可在[示例ToyMultiScalePlantModel](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyMultiScalePlantModel/ToyPlantSimulation3.jl)子文件夹找到。

```@contents
Pages = ["multiscale_example_3.md"]
Depth = 3
```

## 器官创建问题

你可能注意到，在观察数据时有一个小问题：当根扩展时，新的根会立刻生效，某些模型会立刻对其作用……包括根生长模型。这意味着新根可能在同一时间步内继续发出其他根，依此类推。

你可以通过查看模拟在前两个时间步内的状态来发现这一点：

```@example usepkg
outs = run!(mtg, mapping, first(meteo_day, 2))

root_nodes_per_timestep = [0, 0]
for i in 1:length(outs["Root"])
    if outs["Root"][i].timestep < 3
        root_nodes_per_timestep[outs["Root"][i].timestep] += 1    
    end
end

root_nodes_per_timestep
```

我们的根在一个时间步内就达到了完全长度。太快了。

这是PlantSimEngine的一个实现决定：**默认情况下，新创建的器官是立即激活的**，相关模型可以**在其创建后马上对其进行操作**。

在我们的例子里，节间生长受到一个积温指标的限制，这种限制通常需要若干时间步的积累，所以即使新的节间马上生效，也无法在同一时间步内再长出新器官。但如我们已见，根就有这个问题。

同样的问题也发生在 [XPalm.jl](https://github.com/PalmStudio/XPalm.jl)（另一个使用PlantSimEngine的包）：部分器官采用状态机，并在创建时被视为“未成熟”，只有当条件满足并进阶为成熟状态后才能继续生长新的器官。器官出现的控制条件可能还包括积温等阈值（参见[这里](https://github.com/PalmStudio/XPalm.jl/blob/433e1c47c743e7a53e764672818a43ed8feb10c6/src/plant/phytomer/leaves/phyllochron.jl#L46)的一个例子）。

!!! note
    新器官立即激活的实现方式在PlantSimEngine的未来版本中有可能更改。请注意，依赖图结构决定了模型的执行顺序，映射中模型的增加或调整会导致模型运行顺序的变化。部分模型可能会出现“晚一拍”的现象，关于详细内容见 [新增模型时的仿真顺序不稳定](@ref)。

!!! note
    MTG节点输出数据有其结构细节，详见 [多尺度输出数据结构](@ref)。

### 延迟器官成熟

如何避免根的“瞬间极长”呢？当然可以像节间那样添加一个积温约束，也可以直接改动水资源等参数。

除此之外，我们可以在MTG的根和节间节点添加一个简单的状态机变量，记录新器官为“未成熟”，从而禁止其在同一时间步内生长新器官。由于本例根不分叉，只需记录一个状态变量即可。见 [状态机](@ref) 小节了解具体例子。

此外，也可以调整执行根生长检查的尺度，由其他模型在合适的时机直接调用根生长模型，这样只有每一时间步最末端根节点满足条件时才执行扩展，而不是每个根每步都检查。

## 资源分配 Bug

你还可以注意到，水和碳的库存是通过累加全部叶片的光合和全部根的吸收得到的……但消耗时却不总是被正确减去！

如果末端根生长，则会输出`carbon_root_creation_consumed`；但在某些条件下，即使碳已经不足，还是可能生成多个根与节间。

具体来说，当根和叶的水分条件都满足，且只够一个根或节间生长时，如果根生长模型比节间模型先运行，则二者都用到了“器官产生之前”的碳库存，节间模型不会计入根的碳消耗。

这是因为`carbon_stock`库存只在时间步更新一次，直到下一个时间步才更新。

### 资源消耗修正：根生长决策模型

为防止这种问题，可以将根生长模型与节间产生模型绑定，并将`carbon_root_creation_consumed`传递给节间模型，使其计算到已消耗的碳。或者插入一个中间模型，在转给节间模型之前，先重新计算一次库存。

更多相关讨论见[技巧与变通(Tips and workarounds)]一章：[模型中变量不能同时作为输入和输出](@ref)。

本节采用第一个方法，即根生长模型与节间模型耦合。

### 节间模型调整

对节间模型的唯一必要修改，就是把`carbon_root_creation_consumed`作为新的输入变量，从"Root"尺度映射过来，然后在`run!`函数中用这个变量修正碳库存。例如：

```julia
 # 考虑已消耗碳
    carbon_stock_updated_after_roots = status.carbon_stock - status.carbon_root_creation_consumed

    # 如果剩余碳不足，不产生新器官
    if carbon_stock_updated_after_roots < m.carbon_internode_creation_cost
        return nothing
    end
```

### 跨尺度强依赖出现

我们的“根生长决策模型”接管了上一章"root_growth"模型的一部分工作，输入、参数以及条件判断类似。原始根生长模型仅负责长度检查，决策模型专注资源分配。

由于决策模型要直接调用实际的根生长模型，因此需要声明依赖于后者，且不能独立运行。

这种依赖是跨多尺度的，因为两个模型分别作用于"Plant"和"Root"层级。更多关于多尺度强依赖见 [多尺度环境下的依赖关系处理](@ref)。

声明多尺度强依赖与单尺度类似，只是要加上尺度映射信息：

```julia
PlantSimEngine.dep(::ToyRootGrowthDecisionModel) = (root_growth=AbstractRoot_GrowthModel=>["Root"],)
```

在决策模型`run!`函数中，`status`变量只有Plant级变量，要调用根模型的状态（"Root"级），可通过`extra`参数获得。

多尺度模拟中，`extra`包含所有不同尺度的状态以及以“尺度-过程名”为索引的所有模型。

在根生长决策模型`run!`中访问"Root"层状态的方法：

```julia
status_Root= extra_args.statuses["Root"][1]
```

随后，在父模型调用子模型的方式：

```julia
PlantSimEngine.run!(extra.models["Root"].root_growth, models, status_Root, meteo, constants, extra)
```

基于此就可以完善完整决策模型：

### 根生长决策模型实现

通过上面的耦合方式，可得到完整的根生长决策模型：

```julia
PlantSimEngine.@process "root_growth_decision" verbose = false

struct ToyRootGrowthDecisionModel{T} <: AbstractRoot_Growth_DecisionModel
    water_threshold::T
    carbon_root_creation_cost::T
end

PlantSimEngine.inputs_(::ToyRootGrowthDecisionModel) = 
(water_stock=0.0,carbon_stock=0.0)

PlantSimEngine.outputs_(::ToyRootGrowthDecisionModel) = NamedTuple()

PlantSimEngine.dep(::ToyRootGrowthDecisionModel) = (root_growth=AbstractRoot_GrowthModel=>["Root"],)

# status为Plant尺度
function PlantSimEngine.run!(m::ToyRootGrowthDecisionModel, models, status, meteo, constants=nothing, extra=nothing)

    if status.water_stock < m.water_threshold && status.carbon_stock > m.carbon_root_creation_cost
        # 获取Root层的状态
        status_Root= extra_args.statuses["Root"][1]
        # 直接以“强依赖方式”调用子模型
        PlantSimEngine.run!(extra.models["Root"].root_growth, models, status_Root, meteo, constants, extra)
    end
end
```

根生长模型仍然输出`carbon_root_creation_consumed`，即便它作为依赖模型对外是隐性的，输出依然可以给下游模型使用。

有了这个“串联”，每步最多只会新长一个根节点，因为决策模型只在Plant层调用一次。

### 根生长模型

该版本比上一章实现更精简：

```julia
PlantSimEngine.@process "root_growth" verbose = false

struct ToyRootGrowthModel <: AbstractRoot_GrowthModel
    root_max_len::Int
end

PlantSimEngine.inputs_(::ToyRootGrowthModel) = NamedTuple()
PlantSimEngine.outputs_(::ToyRootGrowthModel) = (carbon_root_creation_consumed=0.0,)

function PlantSimEngine.run!(m::ToyRootGrowthModel, models, status, meteo, constants=nothing, extra=nothing)    
    status.carbon_root_creation_consumed = 0.0

    root_end = get_root_end_node(status.node)
        
    if length(root_end) != 1 
        throw(AssertionError("未找到符号为\"Root\"的MTG叶节点"))
    end
    
    root_len = get_roots_count(root_end[1])
    if root_len < m.root_max_len
        st = add_organ!(root_end[1], extra, "<", "Root", 2, index=1)
        status.carbon_root_creation_consumed = m.carbon_root_creation_cost
    end
end
```

### 映射调整

新映射变动很直接：一些模型不再跨尺度，部分变量的映射方式也变化。例如，`carbon_root_creation_consumed`不再是向量映射，而是标量：

```julia
mapping = Dict(
"Scene" => ToyDegreeDaysCumulModel(),
"Plant" => (
    MultiScaleModel(
        model=ToyStockComputationModel(),          
        mapped_variables=[
            :carbon_captured=>["Leaf"],
            :water_absorbed=>["Root"],
            :carbon_root_creation_consumed=>"Root",
            :carbon_organ_creation_consumed=>["Internode"]

        ],
        ),
    MultiScaleModel(
        model=ToyRootGrowthDecisionModel(10.0, 50.0),
    ),
        Status(water_stock = 0.0, carbon_stock = 0.0)
    ),
"Internode" => (        
        MultiScaleModel(
            model=ToyCustomInternodeEmergence(), # TT_emergence=20.0
            mapped_variables=[:TT_cu => "Scene",
            :water_stock=>"Plant",
            :carbon_stock=>"Plant", 
            :carbon_root_creation_consumed=>"Root"],
        ),        
        Status(carbon_organ_creation_consumed=0.0),
    ),
"Root" =>   (ToyRootGrowthModel(10),       
            ToyWaterAbsorptionModel(),
            Status(carbon_root_creation_consumed=0.0, root_water_assimilation=1.0),
            ),
"Leaf" => ( ToyLeafCarbonCaptureModel(),),
)
```

现在我们可以像以前一样运行模拟了么？

```julia
ERROR: Cyclic dependency detected for process resource_stock_computation: resource_stock_computation for organ Plant depends on root_growth from organ Root, which depends on the first one. This is not allowed, you may need to develop a new process that does the whole computation by itself.
```

发现由于在当前timestep用到了根消耗的碳，导致依赖循环。

### 断开循环依赖

其实解决办法一目了然：我们不能先用“当前步”的`carbon_root_creation_consumed`计算库存，然后又即刻用更新后的再消耗一次。正确做法是“资源库存总是用上一步的消耗”，即库存模型读取前一时刻的消耗或吸收，根/器官生长模型再决定本步是否生长并输出本步消耗。

如有需要，水的消耗也可采用同理。

### 映射最终版

需要做的只是如下修改：

```julia
mapping = Dict(
...
"Plant" => (
    MultiScaleModel(
        model=ToyStockComputationModel(),          
        mapped_variables=[
            :carbon_captured=>["Leaf"],
            :water_absorbed=>["Root"],
            PreviousTimeStep(:carbon_root_creation_consumed)=>"Root",
            PreviousTimeStep(:carbon_organ_creation_consumed)=>["Internode"],
        ],
        ),
        ToyRootGrowthDecisionModel(10.0, 50.0),
        Status(water_stock = 0.0, carbon_stock = 0.0)
    ),
...
)
```

## 总结与后记

现在你已经可以正常运行模拟了。

完整脚本地址：[ToyMultiScalePlantModel](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyMultiScalePlantModel/ToyPlantSimulation3.jl) 示例子文件夹下。

此模型能模拟有两种生长方向的植物。初期根不断生长直至水分充足。

当然，该实现依然有诸多设计问题，例如水消耗未建模、条件过于简化、健壮性欠佳，模型与变量命名也有优化空间。

不过再次强调，这一示例旨在展示框架能力而非生态生理学合理性。基于此框架可不断丰富模型和参数、引入新的植物信息，逐步完善，朝着真实、生产乃至预测模拟的目标迈进。