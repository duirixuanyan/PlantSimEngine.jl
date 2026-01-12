
# 多尺度环境下的依赖关系处理

```@contents
Pages = ["multiscale_coupling.md"]
Depth = 3
```

## 标量变量与向量变量的映射

在前文详细讨论的例子 [多尺度变量映射](@ref) 中，已经多次出现了在不同尺度间进行变量映射的情景。这里我们再简要回顾一下这些映射方式，以便引出后续更为高级的内容。典型的变量映射片段如下：

```julia
"Plant" => (
        MultiScaleModel(
            model=ToyLAIModel(),
            mapped_variables=[
                :TT_cu => "Scene",
            ],
        ),
        ...
        MultiScaleModel(
            model=ToyCAllocationModel(),
            mapped_variables=[
                :carbon_assimilation => ["Leaf"],
                :carbon_demand => ["Leaf", "Internode"],
                :carbon_allocation => ["Leaf", "Internode"]
            ],
        ),
        ...
    ),
```


出于灵活性的考虑，PlantSimEngine 并不是在不同尺度的模型之间显式建立大多数连接，而只是声明某些变量需要从另一个尺度获取（更准确地说，是从输出这些变量的另一个尺度下的模型获取）。这样做的好处在于，切换模型时只需少量修改映射关系，极大提高了便利性。

然而，需要注意的是，由于尺度名称都是由用户自定义的，PlantSimEngine 无法自动推断每个尺度下到底是多实例存在还是单实例存在。

比如上面的例子，“Scene” 只有一个场景，“Plant” 只有一株植物，因此在这两个尺度之间进行 `TT_cu` 变量的映射时，是一对一的标量与标量之间的对应关系。

而另一个变量 `carbon_assimilation` 则是针对每一片叶片分别计算的。在实际模拟时，叶片可能多达数百甚至上千，这就是标量到向量的对应关系。碳同化模型会在每个时间步对每片叶片多次运行，而碳分配模型每个时间步只运行一次。并且一开始也可能只有一个叶片，这意味着 PlantSimEngine 仅根据初始配置无法判断后续模拟过程中会生成多少片叶片。

因此，这两者在映射声明上的差异如下：`TT_cu` 作为标量之间的映射声明为：
```julia
:TT_cu => "Scene",
```
而 `carbon_assimilation`（和其它类似变量）则要声明为向量映射关系：
```julia
:carbon_assimilation => ["Leaf"],
```

需要注意的是，某些情况下，你可能希望自行编写模型来将多实例尺度上的变量进行汇总或聚合。

## 不同尺度下模型之间的强依赖关系

如果一个模型需要某些输入变量，而这些变量是在另一个尺度中计算得到的，那么为该变量提供适当的映射即可解决命名冲突，使得无论对于用户还是模型开发者，只要耦合关系为“软依赖”，模型都可以顺利运行，无需进一步操作。

而当强依赖（hard dependency）发生在**与父级模型相同的尺度**时，强依赖的声明方式与单尺度模拟完全相同，用户侧也无需额外步骤：

- 父模型会直接调用其强依赖的子模型，也就是说这些依赖不会被顶层的依赖关系图显式管理；
- 因此，依赖的“拥有者”模型在依赖图中是可见的，而其强依赖节点只作为内部节点存在；
- 当调用者（或其它需要从强依赖模型获取变量的下游模型）与被调用的强依赖模型处于同一尺度时，变量可以直接访问，无需额外映射。

另一方面，对于开发者来说，需要注意以下情形：如果某个模型的强依赖在**与其父模型不同的器官（尺度）层级下**，则需要根据依赖所处尺度进行声明。

也就是说，如果某个模型需要被父模型直接调用，但它运行在不同的（更细或更粗的）尺度／器官层级上，则开发者必须像用户提供映射那样，声明强依赖所对应的尺度。

概念上如下所示：

```julia
 PlantSimEngine.dep(m::ParentModel) = (
    name_provided_in_the_mapping=AbstractHardDependencyModel => ["Organ_Name_1",],
)
```

### 教学案例中的一个例子

你可以在玩具植物模拟教程第三部分 [跨尺度强依赖出现](@ref) 小节中找到关于强依赖的具体讨论与例子。

### 来自 XPalm.jl 的示例

以下是在 [XPalm](https://github.com/PalmStudio/XPalm.jl)（一个基于 PlantSimEngine 开发的油棕模型）中的一个具体示例。器官是在小枝（phytomer）尺度生成的，但在生殖器官尺度上需要运行年龄模型和生物量模型。

```julia
PlantSimEngine.dep(m::ReproductiveOrganEmission) = (
    initiation_age=AbstractInitiation_AgeModel => [m.male_symbol, m.female_symbol],
    final_potential_biomass=AbstractFinal_Potential_BiomassModel => [m.male_symbol, m.female_symbol],
)
```

用户在映射中为特定的器官级别提供了所需的模型。以下是关于雄性生殖器官的相关映射片段：

```julia
mapping = Dict(
    ...
    "Male" =>
    MultiScaleModel(
        model=XPalm.InitiationAgeFromPlantAge(),
        mapped_variables=[:plant_age => "Plant",],
    ),
    ...
    XPalm.MaleFinalPotentialBiomass(
        p.parameters[:male][:male_max_biomass],
        p.parameters[:male][:age_mature_male],
        p.parameters[:male][:fraction_biomass_first_male],
    ),
    ...
)
```

该模型的构造函数为对应的生殖器官尺度提供了便捷的默认命名。如果用户的命名方案或 MTG 属性有差异，也可以进行覆盖。

```julia
function ReproductiveOrganEmission(mtg::MultiScaleTreeGraph.Node; phytomer_symbol="Phytomer", male_symbol="Male", female_symbol="Female")
    ...
end
```

## 实现细节：如何从不同尺度访问强依赖模型的变量

但是，当一个模型 M 需要调用其强依赖 H 的 [`run!`](@ref) 函数时，该如何为 H 提供所需要的变量呢？用户传递给 M 的 [`status`](@ref) 参数仅作用于 M 所在的器官层级，如果直接用于调用 H 的 run! 函数，H 需要的变量可能会缺失。

为了解决这一问题，PlantSimEngine 在仿真图中引入了 Status 模板。每个器官层级都有自己对应的 Status 模板，模板列出了该层级可用的所有变量。因此，当模型 M 调用强依赖 H 的 [`run!`](@ref) 函数时，可以通过 H 所在器官层级的 Status 模板，获得所需的变量。

### 回到 XPalm 示例

仍以油棕多尺度 FSPM 模型 XPalm 为例：

```julia
# 注意：函数中的 status 参数不包含强依赖所需的变量，因为调用模型所在的器官层级是 "Phytomer"，而非 "Male" 或 "Female"

function PlantSimEngine.run!(m::ReproductiveOrganEmission, models, status, meteo, constants, sim_object)
    ...
    status.graph_node_count += 1

    # 以该小枝为父节点新建一个生殖器官
    st_repro_organ = add_organ!(
        status.node[1],              # 小枝（Phytomer）上的节间是它的第一个子节点
        sim_object,                  # 仿真对象，用于添加新的 status
        "+", status.sex, 4;
        index=status.phytomer_count,
        id=status.graph_node_count,
        attributes=Dict{Symbol,Any}()
    )

    # 计算该器官的起始年龄
    PlantSimEngine.run!(sim_object.models[status.sex].initiation_age, sim_object.models[status.sex], st_repro_organ, meteo, constants, sim_object)
    PlantSimEngine.run!(sim_object.models[status.sex].final_potential_biomass, sim_object.models[status.sex], st_repro_organ, meteo, constants, sim_object)
end
```

在上述示例中，生殖器官节点及其 Status 模板是在运行时动态创建的。
如果不是这种情况，也可以通过仿真图访问到对应的 Status 模板：

```julia
function PlantSimEngine.run!(m::ReproductiveOrganEmission, models, status, meteo, constants, sim_object)

    ...

    if status.sex == "Male"

        status_male = sim_object.statuses["Male"][1]
        run!(sim_object.models["Male"].initiation_age, models, status_male, meteo, constants, sim_object)
        run!(sim_object.models["Male"].final_potential_biomass, models, status_male, meteo, constants, sim_object)
    else
        # 雌性
        ...
    end
end
```