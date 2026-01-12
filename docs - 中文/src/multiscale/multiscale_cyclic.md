# 避免循环依赖

在定义模型与尺度之间的映射时，重要的一点是避免出现循环依赖。所谓循环依赖，指的是当一个尺度上的模型依赖于另一个尺度上的模型，并且后者又反过来依赖前者时，就构成了一个循环依赖。循环依赖是不好的，因为它会导致模拟中出现无限循环（依赖关系图会无休止地循环下去）。

PlantSimEngine 会检测循环依赖，并在发现时抛出错误。该错误信息会指出参与循环的模型，并以红色高亮显示导致循环的模型。

例如，下面的映射就会触发一个循环依赖错误：

!!! details
    <summary>示例映射</summary>
    
    ```julia
    mapping_cyclic = Dict(
        "Plant" => (
            MultiScaleModel(
                model=ToyCAllocationModel(),
                mapped_variables=[
                    :carbon_demand => ["Leaf", "Internode"],
                    :carbon_allocation => ["Leaf", "Internode"]
                ],
            ),
            MultiScaleModel(
                model=ToyPlantRmModel(),
                mapped_variables=[:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm],],
            ),
            Status(total_surface=0.001, aPPFD=1300.0, soil_water_content=0.6),
        ),
        "Internode" => (
            ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            ToyMaintenanceRespirationModel(1.5, 0.06, 25.0, 0.6, 0.004),
            Status(TT=10.0, carbon_biomass=1.0),
        ),
        "Leaf" => (
            ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            ToyMaintenanceRespirationModel(2.1, 0.06, 25.0, 1.0, 0.025),
            ToyCBiomassModel(1.2),
            Status(TT=10.0),
        )
    )
    ```

让我们来看看使用这个映射在构建依赖关系图时会发生什么：

```julia
julia> dep(mapping_cyclic)
ERROR: Cyclic dependency detected in the graph. Cycle:
 Plant: ToyPlantRmModel
 └ Leaf: ToyMaintenanceRespirationModel
  └ Leaf: ToyCBiomassModel
   └ Plant: ToyCAllocationModel
    └ Plant: ToyPlantRmModel

 You can break the cycle using the `PreviousTimeStep` variable in the mapping.
```

我们如何理解这条信息？这里列出了五个参与循环的模型。第一个模型是导致循环的起始点，剩下的模型依次相互依赖。在这个例子中，`ToyPlantRmModel` 是循环的发起者，其余的模型则存在相互依赖关系。具体解释如下：

1. `ToyPlantRmModel` 依赖于 `ToyMaintenanceRespirationModel`，即植株尺度的呼吸模型需要累加所有器官的呼吸量；
2. `ToyMaintenanceRespirationModel` 依赖于 `ToyCBiomassModel`，即器官的维持呼吸与器官的碳生物量相关；
3. `ToyCBiomassModel` 依赖于 `ToyCAllocationModel`，即器官的碳生物量取决于器官获得的碳分配量；
4. 最后，`ToyCAllocationModel` 又依赖于 `ToyPlantRmModel`，因此导致循环——碳分配又依赖于植株尺度的呼吸。

这些模型之间无法找到一个能满足所有依赖关系的顺序，因此循环无法自动被打破。为了解决这个问题，我们需要重新思考模型之间的映射方式，将环路打破。

打破循环依赖的方法有几种：

- **合并模型**：如果两个模型相互依赖，例如需要递归计算，可以将它们合并到第三个模型中，由该模型统一完成计算，并把原有两个模型设为“强依赖”。强依赖指的是被显式调用、不会参与依赖图自动推导的模型。
- **更换模型**：当然，也可以通过更换或调整模型来规避循环依赖，但这更像是权宜之计，而不是根本性的方案。
- **PreviousTimeStep（前一时步变量）**：通过将某些变量声明为取自前一时刻，可以打破依赖图中的循环。一个众所周知的例子是植株对光截获的计算，这通常依赖叶面积，而叶面积本身又可能是依赖光截获的模型计算出来的。通常，通过在截获模型中使用前一时刻的叶面积来实现近似，从而打破循环依赖，这在大多数情况下是一个足够好的近似。

在我们的例子中，可以通过让器官呼吸模型使用前一时刻的碳生物量来计算，从而修正原有的映射关系。下面给出具体如何在映射中打破循环依赖（注意叶片和节间两个尺度的处理）：

!!! details
    ```@julia
    mapping_nocyclic = Dict(
            "Plant" => (
                MultiScaleModel(
                    model=ToyCAllocationModel(),
                    mapping=[
                        :carbon_demand => ["Leaf", "Internode"],
                        :carbon_allocation => ["Leaf", "Internode"]
                    ],
                ),
                MultiScaleModel(
                    model=ToyPlantRmModel(),
                    mapped_variables=[:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm],],
                ),
                Status(total_surface=0.001, aPPFD=1300.0, soil_water_content=0.6, carbon_assimilation=5.0),
            ),
            "Internode" => (
                ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
                MultiScaleModel(
                    model=ToyMaintenanceRespirationModel(1.5, 0.06, 25.0, 0.6, 0.004),
                    mapped_variables=[PreviousTimeStep(:carbon_biomass),], #! 这里通过使用前一时刻的碳生物量打破了循环依赖（第一次打破）
                ),
                Status(TT=10.0, carbon_biomass=1.0),
            ),
            "Leaf" => (
                ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
                MultiScaleModel(
                    model=ToyMaintenanceRespirationModel(2.1, 0.06, 25.0, 1.0, 0.025),
                    mapped_variables=[PreviousTimeStep(:carbon_biomass),], #! 这里通过使用前一时刻的碳生物量打破了循环依赖（第二次打破）
                ),
                ToyCBiomassModel(1.2),
                Status(TT=10.0),
            )
        );
    nothing # hide
    ```

`ToyMaintenanceRespirationModel` 现在被定义为 [`MultiScaleModel`](@ref)，而 `carbon_biomass` 变量被包裹在 `PreviousTimeStep` 结构中。`PreviousTimeStep` 结构告诉 PlantSimEngine 从前一时刻获取该变量的数值，从而打破循环依赖关系。

!!! note
    [`PreviousTimeStep`](@ref) 指示 PlantSimEngine 获取所包裹变量在上一时刻的数值；如果当前是第一次迭代，则取初始化时的数值。初始化数值默认为模型输入里设定的，但通常可以通过 [`Status`](@ref) 结构进行覆盖。
    [`PreviousTimeStep`](@ref) 用于包裹模型的**输入**变量，可以有跨尺度映射，也可以没有，例如：`PreviousTimeStep(:carbon_biomass) => "Leaf"`。