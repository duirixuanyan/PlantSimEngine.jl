# 将单尺度模拟转换为多尺度模拟
```@meta
CurrentModule = PlantSimEngine
```
```@setup usepkg
using PlantMeteo
using PlantSimEngine
using PlantSimEngine.Examples
using CSV
using DataFrames
using MultiScaleTreeGraph
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
models_singlescale = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)
```

只需提供一个简单的多尺度树图（multi-scale tree graph），并声明一个将所有模型关联到唯一尺度层级的映射，就可以把单尺度模拟“伪”转变为多尺度模拟。

本页将演示如何完成该转换，并在此基础上添加一个新的尺度上的模型，从而使模拟真正实现多尺度。

完整的示例脚本可在 examples 文件夹找到，[点击此处查看](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToySingleToMultiScale.jl)

```@contents
Pages = ["single_to_multiscale.md"]
Depth = 3
```

# 将 ModelList 转换为多尺度映射

例如，让我们回到[模型切换](@ref)小节中提到的 [`ModelList`](@ref)，该模型组合了光截获模型、叶面积指数模型和碳生物量增长模型：

```@example usepkg
using PlantMeteo
using PlantSimEngine
using PlantSimEngine.Examples
using CSV

meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

models_singlescale = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

outputs_singlescale = run!(models_singlescale, meteo_day)
```

这些模型都作用于单个植株的简化模型，没有任何器官级的局部信息。因此我们可以认为它们都工作在“整株植物”这个尺度上。其变量同样都在 “Plant” 这一尺度下运行，因此不需要映射到其他尺度。

因此，我们可以将其转换为如下的映射关系：

```@example usepkg 
mapping = Dict(
"Plant" => (
   ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    Status(TT_cu=cumsum(meteo_day.TT),)
    ),
)
```
注意，这里 [`Status`](@ref) 的写法与之前略有不同。这是出于实现上的原因（请见谅）。

## 为植物图形引入新的包

上述模型同样没有在多尺度树图（multi-scale tree graph, MTG）上运行，也不存在器官的创建或生长的概念。但要进行多尺度模拟，我们还是必须为模型提供一个多尺度树图。因此，我们可以暂时声明一个非常简单的 MTG，仅包含一个节点：

```@example usepkg
using MultiScaleTreeGraph

mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 0, 0),)
```

!!! note
    你需要将 `MultiScaleTreeGraph` 包添加到你的环境中。如果你对 Julia 还不熟悉或需要复习，请参见[PlantSimEngine 的安装与运行](@ref)。

## 运行多尺度模拟？

到目前为止，我们已经准备好了进行多尺度模拟所需的**几乎所有**条件。

这一步的转换可以作为更复杂多尺度模拟的起点。

多尺度下 [`run!`](@ref) 函数的签名与 ModelList 版本略有不同：

```julia
out_multiscale = run!(mtg, mapping, meteo_day)
```

（一些可选参数的用法也会有所不同）

但需要注意的是，目前在多尺度模式下通过 [`Status`](@ref) 字段传递向量依然可以实现，但需要对映射关系进行更深入的操作。这种机制实际上是动态生成了一个自定义模型，其实现还是实验性的，使用体验也不够友好。

如果你仍然希望了解这种方式，可参考[这里的详细示例](@ref multiscale_vector)，但不推荐初学者这么做。

我们更推荐的做法，是编写你自己的模型，在每个时间步将积温（thermal time）作为变量输入，而不是用 [`Status`](@ref) 直接传递一个整体向量。

这样，我们“伪多尺度”的初始方案就将转变为真正的多尺度模拟。

## 添加第二个尺度

接下来，我们希望让一个模型为叶面积指数模型（Leaf Area Index Model）动态提供积温（Cumulated Thermal Time），而不是像之前那样通过 [`Status`](@ref) 直接初始化。

因此，我们将实现自己的 `ToyTT_cuModel` 模型。

### TT_cu 模型的实现

这个模型不需要任何外部数据或输入变量，它只依赖气象数据来输出我们期望的 TT_cu（积温）。其实现十分直接，也不需要复杂的模型耦合。

```@example usepkg
PlantSimEngine.@process "tt_cu" verbose = false

struct ToyTt_CuModel <: AbstractTt_CuModel
end

function PlantSimEngine.run!(::ToyTt_CuModel, models, status, meteo, constants, extra=nothing)
    status.TT_cu +=
        meteo.TT
end

function PlantSimEngine.inputs_(::ToyTt_CuModel)
    NamedTuple() # 没有任何输入变量
end

function PlantSimEngine.outputs_(::ToyTt_CuModel)
    (TT_cu=0.0,)
end
```

!!! note
    通过 status，在 [`run!`](@ref) 函数内部能够访问到的变量仅限于本层级（如 "Scene" 尺度）下定义的变量。这一点初看并不明显，但在开发模型或者将其用于不同尺度时非常重要。如果你需要访问其它尺度的变量，则必须通过 [`MultiScaleModel`](@ref) 进行变量映射，或者采用更复杂的耦合方式。

### 将新的 TT_cu 模型关联到映射中的某个尺度

我们实现了自己的模型，接下来要在变量映射中将它加入。

这个新模型其实与植物的任何特定器官都没有直接关联。实际上，它描述的并非植物的生理过程，而是影响其生理状态的环境驱动力。因此，我们可以让它运行在与植物结构无关的另一层级，这里我们称为“Scene”（场景）层级。这也是常见的做法。

注意：我们现在需要在多尺度树图（MTG）中新增一个 "Scene" 节点，否则我们的模型不会被调用——因为没有其它模型会主动调用它，而 "Plant" 层级节点只会运行 "Plant" 层级下的模型。关于更多细节，参见 [多尺度模拟中的空状态向量](@ref)。

```@example usepkg
mtg_multiscale = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 0, 0),)
    plant = MultiScaleTreeGraph.Node(mtg_multiscale, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))
```

### 尺度间的变量映射：MultiScaleModel 包装器

先前我们是将积温（`:TT_cu`）作为一个模拟参数直接提供给 LAI 模型，但现在我们需要将其从“Scene”尺度映射过来。

这实现的方法是将我们的 ToyLAIModel 包装在 [`MultiScaleModel`](@ref) 结构体中。 [`MultiScaleModel`](@ref) 需要两个关键字参数：`model` ，指明我们要映射变量的模型本体；`mapped_variables` ，用于指定变量与尺度之间的映射关系，以及变量的重命名（如有需要）。

变量的映射方式有多种语法形式，但在本例中，我们只是将一个单变量（TT_cu 的单一数值）从 "Scene" 尺度传递到 "Plant" 尺度。

因此，我们为 LAI 模型用 [`MultiScaleModel`](@ref) 包装的声明如下：

```@example usepkg
MultiScaleModel(
    model=ToyLAIModel(),
    mapped_variables=[
        :TT_cu => "Scene",
    ],
)
```
而包含两个尺度的新变量映射如下：

```@example usepkg
mapping_multiscale = Dict(
    "Scene" => ToyTt_CuModel(),
    "Plant" => (
        MultiScaleModel(
            model=ToyLAIModel(),
            mapped_variables=[
                :TT_cu => "Scene",
            ],
        ),
        Beer(0.5),
        ToyRUEGrowthModel(0.2),
    ),
)
```

### 运行多尺度模拟

在构建好拥有两个节点的 MTG 后，我们就可以运行多尺度模拟了：

```@example usepkg
outputs_multiscale = run!(mtg_multiscale, mapping_multiscale, meteo_day)
```

### 单尺度与多尺度输出的对比

输出的数据结构略有不同：多尺度输出是按照尺度进行索引的，并且每个变量对其所在尺度的每个节点都有一个对应的数值（例如，对于每一片叶子都会有一个 "leaf_surface" 的值），这些值以数组形式存储。

在我们这个简单的例子中，只有一个 MTG 场景节点和一个植株节点，因此每个变量在多尺度输出中的数组都只包含一个数值。

我们可以通过索引多尺度输出，访问 "Scene" 尺度下的输出变量：

```@example usepkg
outputs_multiscale["Scene"]
```
这里得到的是一个 `Vector{NamedTuple}` 结构。而对应的单尺度输出则是一个 `Vector{T}`：
```@example usepkg
outputs_singlescale.TT_cu
```

 让我们提取多尺度的 `:TT_cu`：
```@example usepkg
computed_TT_cu_multiscale = [outputs_multiscale["Scene"][i].TT_cu for i in 1:length(outputs_multiscale["Scene"])]
```

现在我们可以一一对比它们的值，并做近似相等的判断：
```@example usepkg
for i in 1:length(computed_TT_cu_multiscale)
    if !(computed_TT_cu_multiscale[i] ≈ outputs_singlescale.TT_cu[i])
        println(i)
    end
end
```
或者，也可以用广播操作实现同样的比较：
```@example usepkg
is_approx_equal = length(unique(computed_TT_cu_multiscale .≈ outputs_singlescale.TT_cu)) == 1
```

!!! note
    你可能会疑惑为什么我们要用近似相等判断而不是严格相等。原因是浮点数累积误差造成的，这一问题在[浮点数注意事项](@ref)中有更详细的讨论。

## ToyDegreeDaysCumulModel

有一个模型 [`ToyDegreeDaysCumulModel`](@ref) 可以根据气温数据生成积温，该模型可以在 examples 文件夹中找到。

本例中我们没有使用它，是为了教学的简单性。此外，该模型用默认参数计算得到的积温，与本例天气数据中给出的积温并不一致，因此如果不调整参数，计算结果也会不同。