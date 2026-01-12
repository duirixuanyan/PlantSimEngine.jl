"""
一个包含示例模型的子模块。

这些示例用于多尺度模型集的文档。
相关模型可在包的 `examples` 文件夹中找到，具体存储在以下文件：

- `ToyAssimModel.jl`
- `ToyCDemandModel.jl`
- `ToyCAllocationModel.jl`
- `ToySoilModel.jl`

# 示例

```jl
using PlantSimEngine
using PlantSimEngine.Examples
ToyAssimModel()
```
"""
module Examples

using PlantSimEngine, MultiScaleTreeGraph, PlantMeteo, Statistics

include(joinpath(@__DIR__, "../examples/dummy.jl"))
include(joinpath(@__DIR__, "../examples/ToyDegreeDays.jl"))
include(joinpath(@__DIR__, "../examples/Beer.jl"))
include(joinpath(@__DIR__, "../examples/ToyLAIModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyAssimModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyCDemandModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyAssimGrowthModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyRUEGrowthModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyCAllocationModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyMaintenanceRespirationModel.jl"))
include(joinpath(@__DIR__, "../examples/ToySoilModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyInternodeEmergence.jl"))
include(joinpath(@__DIR__, "../examples/ToyCBiomassModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyLeafSurfaceModel.jl"))
include(joinpath(@__DIR__, "../examples/ToyLightPartitioningModel.jl"))


"""
    import_mtg_example()

返回一个带有场景、土壤和一株带有两个节间和两个叶片的植物的多尺度树图（MTG）示例。

# 示例

```jldoctest mylabel
julia> using PlantSimEngine.Examples
```

```jldoctest mylabel
julia> import_mtg_example()
/ 1: Scene
├─ / 2: Soil
└─ + 3: Plant
   └─ / 4: Internode
      ├─ + 5: Leaf
      └─ < 6: Internode
         └─ + 7: Leaf
```
"""
function import_mtg_example()
    mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 1, 0))
    MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG("/", "Soil", 1, 1))
    plant = MultiScaleTreeGraph.Node(mtg, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
    internode1 = MultiScaleTreeGraph.Node(plant, MultiScaleTreeGraph.NodeMTG("/", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))
    internode2 = MultiScaleTreeGraph.Node(internode1, MultiScaleTreeGraph.NodeMTG("<", "Internode", 1, 2))
    MultiScaleTreeGraph.Node(internode2, MultiScaleTreeGraph.NodeMTG("+", "Leaf", 1, 2))

    return mtg
end

# 过程（Processes）：
export AbstractProcess1Model, AbstractProcess2Model, AbstractProcess3Model
export AbstractProcess4Model, AbstractProcess5Model, AbstractProcess6Model
export AbstractProcess7Model
export AbstractLight_InterceptionModel, AbstractLight_PartitioningModel
export AbstractLai_DynamicModel, AbstractLeaf_SurfaceModel
export AbstractDegreedaysModel
export AbstractCarbon_AssimilationModel, AbstractCarbon_AllocationModel, AbstractCarbon_DemandModel, AbstractCarbon_BiomassModel
export AbstractSoil_WaterModel, AbstractGrowthModel
export AbstractOrgan_EmergenceModel
export AbstractMaintenance_RespirationModel

# 模型（Models）：
export Beer, ToyLightPartitioningModel, ToyLAIModel, ToyLAIfromLeafAreaModel, ToyLeafSurfaceModel, ToyPlantLeafSurfaceModel, ToyDegreeDaysCumulModel
export ToyAssimModel, ToyCAllocationModel, ToyCDemandModel, ToySoilWaterModel
export ToyAssimGrowthModel, ToyRUEGrowthModel, ToyMaintenanceRespirationModel, ToyPlantRmModel, ToyCBiomassModel
export Process1Model, Process2Model, Process3Model, Process4Model, Process5Model
export Process6Model, Process7Model

export ToyInternodeEmergence
export import_mtg_example
end