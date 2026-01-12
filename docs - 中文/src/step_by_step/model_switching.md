# 模型切换

```@setup usepkg
using PlantSimEngine, PlantMeteo, CSV, DataFrames
# 导入 `Examples` 子模块中定义的示例
using PlantSimEngine.Examples

meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
 
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)
run!(models, meteo_day)
models2 = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyAssimGrowthModel(),
    status=(TT_cu=cumsum(meteo_day.TT),),
)
run!(models2, meteo_day)
```

PlantSimEngine 的主要目标之一是允许用户在**无需修改 PlantSimEngine 代码库本身**的情况下，切换某一过程的模型实现。

整个包的设计理念正是围绕这一思想展开的——让容易的更容易，让变化快速高效。只需在[`ModelList`](@ref)中切换具体模型，然后再次调用 [`run!`](@ref) 函数即可。如果没有引入新的变量，不需要进行任何其他更改。

## 第一次模拟：作为起点

有了可用的运行环境后，让我们从[`examples`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/master/examples/)文件夹中的示例脚本，创建一个包含多个模型的[`ModelList`](@ref)。

从脚本导入模型：

```julia
using PlantSimEngine
# 导入 `Examples` 子模块中的示例
using PlantSimEngine.Examples
```

将各个模型组合到一个[`ModelList`](@ref)里进行耦合：

```@example usepkg
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

nothing # hide
```

我们可以通过气象数据和调用[`run!`](@ref)函数来进行模拟。这里用的是一个示例数据集：

```@example usepkg
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
nothing # hide
```

现在我们可以运行模拟了：

```@example usepkg
output_initial = run!(models, meteo_day)
```

## 在模拟中切换单个模型

那如果我们想要更换用于计算生长的模型呢？其实这很简单，只需要在[`ModelList`](@ref)中替换对应的模型，PlantSimEngine 会自动更新依赖图，并适应新的模型进行模拟。

让我们将原本的 ToyRUEGrowthModel 替换为 ToyAssimGrowthModel：

```@example usepkg
models2 = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyAssimGrowthModel(), # 这里之前是 `ToyRUEGrowthModel(0.2)`
    status=(TT_cu=cumsum(meteo_day.TT),),
)

nothing # hide
```

ToyAssimGrowthModel 比`ToyRUEGrowthModel`](@ref)稍微复杂一些，因为它同时计算了植物的维持呼吸和生长呼吸，因此参数也更多（这里我们采用默认参数）。

我们可以重新运行一次模拟，并看到新的模拟输出会和之前不一样：

```@example usepkg
output_updated = run!(models2, meteo_day)
```

就是这么简单！我们无需更改其他代码，也不用手动重新计算依赖关系，就能切换所用的模型。这是 PlantSimEngine 的一大强大功能！💪

!!! note
    这里演示的是非常标准且直接的例子。有时候某些模型的替换会需要你向[`ModelList`](@ref)中额外添加新的模型。例如，ToyAssimGrowthModel 可能需要一个专门的维持呼吸模型，这时 PlantSimEngine 会自动提示你需要哪些额外模型来保证模拟顺利进行。

!!! note
    在我们的例子里，我们替换的是一种[软依赖耦合](@ref hard_dependency_def)，但同样的原则也适用于[硬依赖](@ref hard_dependency_def)。硬依赖和软依赖是模型耦合相关的两个重要概念，相关内容可以在[标准模型耦合](@ref)以及[耦合更复杂的模型](@ref)部分中查阅了解。

