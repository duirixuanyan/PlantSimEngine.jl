# 多尺度变量映射

上一页介绍了如何将单一尺度的模拟转换为多尺度模拟。

本页将通过一个更复杂的多尺度版本示例，进一步展示变量映射的细节和技巧。所有模型均来自[examples文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/tree/main/examples)。

```@contents
Pages = ["multiscale.md"]
Depth = 3
```

## 从单模型映射开始

我们首先导入`PlantSimEngine`包，以及本教程需要使用的所有示例模型：

```@example usepkg
using PlantSimEngine
using PlantSimEngine.Examples # 导入一些示例模型
```

接下来我们将创建一个简单的映射，只有一个初始模型，即负责叶片碳同化过程的ToyAssimModel。
它类似于单尺度模拟中[模型切换](@ref)小节所用的ToyAssimGrowth模型。

因此，我们的尺度与模型映射关系为：

```@example usepkg
mapping = Dict("Leaf" => ToyAssimModel())
```

和单尺度模拟类似，我们可以通过调用`to_initialize`来检查是否有变量需要初始化。不同的是，这次会按尺度进行索引：

```@example usepkg
to_initialize(mapping)
```

在此示例中，ToyAssimModel需要`:aPPFD`与`:soil_water_content`作为输入，但它们在我们当前的映射中尚未初始化。

这些变量的初始化值可以通过[`Status`](@ref)对象传递：

```@example usepkg
mapping = Dict(
    "Leaf" => (
        ToyAssimModel(),
        Status(aPPFD=1300.0, soil_water_content=0.5),
    ),
)
```

如果我们对上述新的 mapping 调用 [`to_initialize`](@ref)，它会返回一个空字典，意味着变量映射已经有效，我们可以开始进行模拟了：

```@example usepkg
to_initialize(mapping)
```

## 多尺度下模型与尺度间的变量映射

在之前的示例中，`soil_water_content` 变量是直接通过 mapping 提供的，并没有被任何模型计算，因此它是一个常量。实际上，我们也可以用模型来动态计算它（例如根据气象数据或更真实的物理过程）。

通常，这类模型应当运行在与 "Leaf"（叶片）不同的尺度。例如，examples 文件夹中就有一个简单的土壤模型（`ToySoilWaterModel`）。我们可以将其放在新的 "Soil"（土壤）尺度。

此时，ToyAssimModel 不再通过自身的 Status 初始化获得 `soil_water_content`，而是从 "Soil" 尺度获取。为此，我们需要将 `ToyAssimModel` 包装为 `MultiScaleModel`，并指定 `soil_water_content` 要从 "Soil" 尺度映射而来：

```@example usepkg
mapping = Dict(
    "Soil" => ToySoilWaterModel(),
    "Leaf" => (
        MultiScaleModel(
            model=ToyAssimModel(),
            mapped_variables=[:soil_water_content => "Soil" => :soil_water_content,],
        ),
        Status(aPPFD=1300.0),        
    ),
);
nothing # hide
```

在这个例子里，我们把 "Leaf" 尺度下的 `soil_water_content` 变量与 "Soil" 尺度下的同名变量进行了映射。如果两个尺度之间变量名称相同，还可以省略目标尺度的变量名，比如写为 `[:soil_water_content => "Soil"]` 即可。

变量 `aPPFD` 依然作为常量通过 Status 进行初始化。

我们可以再次用 [`to_initialize`](@ref) 检查映射是否合理：

```@example usepkg
to_initialize(mapping)
```

如前，同样会返回空字典，说明映射已经完全满足要求。

## 一个更复杂的多尺度模型映射

现在，我们来扩展这个 mapping，展示变量如何以不同方式从一个尺度映射到另一个尺度。我们保留前两个模型，并添加几个新模型，以模拟植物体内的其他过程。

```@example usepkg
mapping = Dict(
    "Scene" => ToyDegreeDaysCumulModel(),
    "Plant" => (
        MultiScaleModel(
            model=ToyLAIModel(),
            mapped_variables=[
                :TT_cu => "Scene",
            ],
        ),
        Beer(0.6),
        MultiScaleModel(
            model=ToyCAllocationModel(),
            mapped_variables=[
                :carbon_assimilation => ["Leaf"],
                :carbon_demand => ["Leaf", "Internode"],
                :carbon_allocation => ["Leaf", "Internode"]
            ],
        ),
        MultiScaleModel(
            model=ToyPlantRmModel(),
            mapped_variables=[:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm],],
        ),
    ),
    "Internode" => (
        MultiScaleModel(
            model=ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            mapped_variables=[:TT => "Scene",],
        ),
        ToyMaintenanceRespirationModel(1.5, 0.06, 25.0, 0.6, 0.004),
        Status(carbon_biomass=1.0),
    ),
    "Leaf" => (
        MultiScaleModel(
            model=ToyAssimModel(),
            mapped_variables=[:soil_water_content => "Soil", :aPPFD => "Plant"],
        ),
        MultiScaleModel(
            model=ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            mapped_variables=[:TT => "Scene",],
        ),
        ToyMaintenanceRespirationModel(2.1, 0.06, 25.0, 1.0, 0.025),
        Status(carbon_biomass=0.5),
    ),
    "Soil" => (
        ToySoilWaterModel(),
    ),
);
nothing # hide
```

这种变量映射相比之前的例子看起来要复杂一些，但细看仍然能发现很多熟悉的模型。实际上，你可以认为这里的变量映射，是在[模型切换](@ref)小节中那个包含光合模型、LAI模型和碳生物量增长模型的单尺度示例的增强和更复杂的多尺度版本。

```julia
models2 = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyAssimGrowthModel(),
    status=(TT_cu=cumsum(meteo_day.TT),),
)
```

在该多尺度建模中，模型模拟了通过光合作用获得碳，以及碳在植物器官间分配用于维持呼吸和生长发育的过程。

LAI和光合模型与ModelList示例中的是相同的。[`ToyDegreeDaysCumulModel`](@ref)为植物提供累计温度时间（Cumulative Thermal Time）。

新引入的各个模型动态如下：

碳分配（ToyCAllocationModel）依赖于“叶片”（"Leaf"）层次的同化值（即供给），以及各器官（“叶片”、“节间”）的碳需求（ToyCDemandModel），从而决定植物不同器官的碳分配。在“土壤”层级（"Soil" scale）利用(`ToySoilWaterModel`](@ref)计算土壤含水量，该值用于“叶片”层级的光合模型（ToyAssimModel）进行同化计算。此外，维持呼吸分别在“叶片”和“节间”两级通过ToyMaintenanceRespirationModel单独计算，再在“植株”层级通过ToyPlantRmModel聚合成整体的维持呼吸总量。

## 不同的变量映射方式

上面的变量映射展示了在 `MultiScaleModel` 中定义变量映射的几种不同方式：

```julia
 mapped_variables=[:TT_cu => "Scene",],
```

- 在 "Plant"（植株）层级，变量 TT_cu 被作为标量从 "Scene"（场景）层级映射过来。在 MTG（多重拓扑图）中只包含一个 "Scene" 节点，因此每个仿真步长只有一个 "TT_cu" 值。

```julia
:carbon_allocation => ["Leaf"]
```

- 另一方面，在“Plant”尺度的 `ToyCAllocationModel`，我们有 `:carbon_allocation => ["Leaf"]`。这里 `carbon_assimilation` 变量作为一个向量被映射：因为可能存在多个 "Leaf"（叶片）节点，但只有一个 "Plant" 节点，该节点聚合所有叶片的值。这样就形成了“多对一”的向量映射，在该尺度下模型的 [`run!`](@ref) 函数中，`status` 下的 `carbon_allocation` 将作为向量提供。

```julia
:carbon_allocation => ["Leaf", "Internode"]
```

- 第三种映射方式是 `:carbon_allocation => ["Leaf", "Internode"]`，即从多个层级（如 "Leaf" 和 "Internode"）同时为某变量提供数值。在这种情况下，值也会以向量形式出现在模型内部的 [`status`](@ref) 的 `carbon_assimilation` 变量中，节点的顺序与其在图中遍历顺序一致。

```julia
:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm]
```

- 最后，还可以将变量映射到目标层级下的特定变量名，例如 `:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm]`。这种语法适用于不同层级间变量名不一致，希望明确指定映射目标变量名的场景。在本例中，plant 层级下的变量 `Rm_organs` 从 "Leaf" 和 "Internode" 层级下的 `Rm` 变量获取数值（进行映射）。

## 运行模拟

现在我们已经有了有效的变量映射，可以运行一次多尺度模拟。运行一个多尺度模拟需要一棵植物结构图（plant graph），以及为每个层级动态定义我们想要输出的变量。

### 植物结构图

可以通过如下方式导入一个示例多尺度树结构图：

```@example usepkg
mtg = import_mtg_example()
```

!!! note
    只有在预先导入了 PlantSimEngine 的 `Examples` 子模块（即 `using PlantSimEngine.Examples`）时，才能使用 `import_mtg_example`。

这个结构图包含一个根节点（代表“场景”Scene）、一个“土壤”节点，以及包含两个节间和两个叶片的“植株”节点。

### 输出变量

对于具有很多器官并且模拟步数较长的模拟来说，输出的数据量可能非常庞大。可以通过限制需要追踪的输出变量，仅追踪所有变量的一个子集，从而减少数据量：

```@example usepkg
outs = Dict(
    "Scene" => (:TT, :TT_cu,),
    "Plant" => (:aPPFD, :LAI),
    "Leaf" => (:carbon_assimilation, :carbon_demand, :carbon_allocation, :TT),
    "Internode" => (:carbon_allocation,),
    "Soil" => (:soil_water_content,),
)
```

这个字典可以作为可选参数 `tracked_outputs` 传递给 [`run!`](@ref) 函数（详见下一部分）。如果不提供该字典，则默认会追踪所有变量。

以上这些变量会在 [`run!`](@ref) 返回的输出结果中提供，并且每个时间步均有相应的取值。输出还会包含对应的时间步和该变量所属的 MTG 节点。

### 气象数据

与单尺度模型一样，我们需要为模拟提供气象数据。我们可以使用 `PlantMeteo` 包生成两个时间步的示例气象数据：

```@example usepkg
meteo = Weather(
    [
    Atmosphere(T=20.0, Wind=1.0, Rh=0.65, Ri_PAR_f = 200.0),
    Atmosphere(T=25.0, Wind=0.5, Rh=0.8, Ri_PAR_f = 180.0)
]
)
```

### 模拟运行

让我们用刚才定义的结构图和输出变量来进行一次模拟：

```@example usepkg
outputs_sim = run!(mtg, mapping, meteo, tracked_outputs = outs);
nothing # hide
```

就是这样！现在我们可以以“NamedTuple 对象的向量字典”形式访问各个尺度的模拟输出。

或者，也可以借助 [`DataFrames`](https://dataframes.juliadata.org) 包，将模拟结果转为 `DataFrame` 组成的字典：

```@example usepkg
using DataFrames
df_dict = convert_outputs(outputs_sim, DataFrame)
```