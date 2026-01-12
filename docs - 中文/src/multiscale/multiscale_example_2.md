# 扩展多尺度模拟

让我们在前一个示例的基础上，增加一些新的器官生长，并在两者之间引入非常轻微的耦合。

本节完整模拟脚本可在 examples 文件夹下的 [ToyMultiScalePlantModel](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyMultiScalePlantModel/ToyPlantSimulation2.jl) 子目录中找到。

```@contents
Pages = ["multiscale_example_2.md"]
Depth = 3
```

## 初始化设置

同样，确保已正确设置好 Julia 环境：

```@example usepkg
using PlantSimEngine
using PlantSimEngine.Examples
using PlantMeteo
using MultiScaleTreeGraph
using CSV, DataFrames

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

function get_n_leaves(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    nleaves = length(MultiScaleTreeGraph.traverse(root, x->1, symbol="Leaf"))
    return nleaves
end
```

## 给植物添加根

我们将为植物添加一个根，该根能够吸收水分并将其加入到水分库中。由于初始水分存量较低，因此会优先进行根的生长，之后植物像之前一样同时生长叶片和新的节间。根的生长有最大长度限制，且不会分枝。

这导致我们需要在映射中加入一个新的尺度 "Root"，并新增两个模型：一个用于水分吸收，一个用于根生长。同时，为了考虑水分，其他的一些模型也需要进行相应的更新。碳捕获模型保持不变，`get_n_leaves` 这个辅助函数同样无需修改。

## 根系相关的模型

### 水分吸收

让我们实现一个非常简化的根系水分吸收模型。该模型通过天气数据中的降水量，并乘以某个吸收系数，计算根系吸收的水分量。

```@example usepkg
PlantSimEngine.@process "water_absorption" verbose = false

struct ToyWaterAbsorptionModel <: AbstractWater_AbsorptionModel
end

PlantSimEngine.inputs_(::ToyWaterAbsorptionModel) = (root_water_assimilation=1.0,)
PlantSimEngine.outputs_(::ToyWaterAbsorptionModel) = (water_absorbed=0.0,)

function PlantSimEngine.run!(m::ToyWaterAbsorptionModel, models, status, meteo, constants=nothing, extra=nothing)
    status.water_absorbed = meteo.Precipitations * status.root_water_assimilation
end
```

### 根生长

根生长模型与节间生长模型类似：它会检查水分是否低于阈值，并确保碳存量足够。当根的总长度尚未达到最大值时，会在MTG中添加一个新的器官。

同时，也会用到两个辅助函数：分别用于寻找根的末端，并计算根的长度：

```@example usepkg
function get_root_end_node(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    return MultiScaleTreeGraph.traverse(root, x->x, symbol="Root", filter_fun = MultiScaleTreeGraph.isleaf)
end

function get_roots_count(node::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(node)
    return length(MultiScaleTreeGraph.traverse(root, x->x, symbol="Root"))
end

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
            throw(AssertionError("未能找到符号为\"Root\"的MTG叶节点"))
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
```

## 更新其他模型以考虑水分

### 资源存储

吸收的水分现在需要被累积，并且还需考虑根系碳创建的消耗。

```@example usepkg
PlantSimEngine.@process "resource_stock_computation" verbose = false

struct ToyStockComputationModel <: AbstractResource_Stock_ComputationModel
end

PlantSimEngine.inputs_(::ToyStockComputationModel) = 
(water_absorbed=0.0, carbon_captured=0.0, carbon_organ_creation_consumed=0.0, carbon_root_creation_consumed=0.0)

PlantSimEngine.outputs_(::ToyStockComputationModel) = (water_stock=-Inf, carbon_stock=-Inf)

function PlantSimEngine.run!(m::ToyStockComputationModel, models, status, meteo, constants=nothing, extra=nothing)
    status.water_stock += sum(status.water_absorbed)
    status.carbon_stock += sum(status.carbon_captured) - sum(status.carbon_organ_creation_consumed) - sum(status.carbon_root_creation_consumed)
end
```

### 节间生长

这里的小改动是：新器官的创建现在只有在水分库存高于给定阈值时才会发生。

```@example usepkg
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
    
    # 如果水分库存不足，则优先生长根系，节间和叶不会发生
    if status.water_stock < m.water_leaf_threshold
        return nothing
    end

    # 如果碳库存不足，不发生新器官生成
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

## 更新映射关系

资源储存和节间生成模型现在需要额外几个与水分相关的映射变量。
“根（Root）”器官被加入到映射中，并配有其专属模型。同时需要初始化一些新的参数。

```@example usepkg
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
        mapped_variables=[
            :TT_cu => "Scene",
            PreviousTimeStep(:water_stock)=>"Plant",
            PreviousTimeStep(:carbon_stock)=>"Plant"
        ],
        ),        
        Status(carbon_organ_creation_consumed=0.0),
    ),
"Root" => (
        MultiScaleModel(
        model=ToyRootGrowthModel(10.0, 50.0, 10),
        mapped_variables=[
            PreviousTimeStep(:carbon_stock)=>"Plant",
            PreviousTimeStep(:water_stock)=>"Plant"
        ],
        ),       
        ToyWaterAbsorptionModel(),
        Status(carbon_root_creation_consumed=0.0, root_water_assimilation=1.0),
    ),
"Leaf" => ( ToyLeafCarbonCaptureModel(),),
)
```

## 运行模拟

运行这个新的模拟过程和之前几乎一样。气象数据没有变化，但是在MTG中新增了一个“Root（根）”节点。

```@example usepkg
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
    
outs = run!(mtg, mapping, meteo_day)
mtg
```

就这样了吗！

……真的如此吗？

如果你仔细检查代码和输出结果，会发现模拟的运行方式存在一些明显的问题……有些地方似乎不太对劲。如果你想了解更多内容，请阅读下一章：[修复植物模拟中的Bug](@ref)