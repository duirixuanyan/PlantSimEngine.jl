# 浮点数注意事项

```@setup usepkg
using PlantSimEngine
using PlantSimEngine.Examples
using PlantMeteo, MultiScaleTreeGraph, CSV
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

out_singlescale = run!(models, meteo_day)
```
## 误差调查

在[将单尺度模拟转换为多尺度模拟](@ref)页面，我们将一个单尺度仿真转换为了等价的多尺度仿真并对输出进行了比较。这里有一个细节虽然被略过了，但作为 PlantSimEngine 用户十分重要：那就是浮点数近似所带来的影响。

### 单尺度仿真

```@example usepkg
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

models_singlescale = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

outputs_singlescale = run!(models_singlescale, meteo_day)
```

### 多尺度等价实现

```@example usepkg
PlantSimEngine.@process "tt_cu" verbose = false

struct ToyTt_CuModel <: AbstractTt_CuModel end

function PlantSimEngine.run!(::ToyTt_CuModel, models, status, meteo, constants, extra=nothing)
    status.TT_cu +=
        meteo.TT
end

function PlantSimEngine.inputs_(::ToyTt_CuModel)
    NamedTuple() # 没有输入变量
end

function PlantSimEngine.outputs_(::ToyTt_CuModel)
    (TT_cu=0.0,)
end

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

mtg_multiscale = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 0, 0),)
    plant = MultiScaleTreeGraph.Node(mtg_multiscale, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))

outputs_multiscale = run!(mtg_multiscale, mapping_multiscale, meteo_day)
```

### 输出比较

```@setup usepkg
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

mtg_multiscale = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Scene", 0, 0),)
    plant = MultiScaleTreeGraph.Node(mtg_multiscale, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))

outputs_multiscale = run!(mtg_multiscale, mapping_multiscale, meteo_day)
```

```@example usepkg

computed_TT_cu_multiscale = [outputs_multiscale["Scene"][i].TT_cu for i in 1:length(outputs_multiscale["Scene"])]
is_approx_equal = length(unique(computed_TT_cu_multiscale .≈ outputs_singlescale.TT_cu)) == 1
```

为什么要近似比较？为什么使用 `≈` 而不是 `==`？

我们来尝试一下。如果直接这么写会怎么样：

```@example usepkg
computed_TT_cu_multiscale = [outputs_multiscale["Scene"][i].TT_cu for i in 1:length(outputs_multiscale["Scene"])]
is_perfectly_equal = length(unique(computed_TT_cu_multiscale .== outputs_singlescale.TT_cu)) == 1
```

为什么结果是 false（假）？让我们看一下数据。

仔细观察输出，可以发现前 105 个时间步的取值实际上是完全一致的：

```@example usepkg
(computed_TT_cu_multiscale .== outputs_singlescale.TT_cu)[104]
```

```@example usepkg
(computed_TT_cu_multiscale .== outputs_singlescale.TT_cu)[105]
```

这时的值分别是 132.33333333333331（多尺度）和 132.33333333333334（单尺度）。最终输出值分别为 2193.8166666666643（多尺度）和 2193.816666666666（单尺度）。

两者的差异很小，但在更多时间步或累积更多节点后，这个偏差就有可能逐步扩大并变为潜在问题。

## 浮点数累加

数值不完全相等的原因是很多数字无法用浮点数精确地表示。一个经典例子是 [0.1 + 0.2 != 0.3](https://blog.reverberate.org/2016/02/06/floating-point-demystified-part2.html) ： 

```@example usepkg
println(0.1 + 0.2 - 0.3)
```

当对许多数字进行累加时，根据加法的顺序不同，浮点误差聚积得快慢有别。

本例中的 `Toy_Tt_CuModel` 模拟每个时间步采用了普通的逐步累加方式。而在单尺度仿真中直接计算 TT_cu 时使用的 `cumsum` 函数采用了成对（pairwise）累加的方法，这种方式累计误差的位数更少，误差增长更慢。

在我们的简单例子中，由于使用 Float64，误差尚不足以影响整体结果，但对于更长的时间步、更多节点的累计、或更复杂的模型，若模型不加留意，浮点误差很可能逐步放大，最终影响仿真结果的准确性。

根据具体计算值和数学运算方式不同，解决办法可能只是对输入数据缩放、也可能需要较大幅度地重构模型，以降低累加误差的风险。

## 其他关于浮点数精度问题的相关链接

请注意，以下博客文章中的许多示例讨论的是 Float32 精度。Float64 值则有更多额外的精度位可供使用。

关于浮点数精度的一系列博客文章：
- [https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/](https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/)
- 浮点数直观解释：[https://fabiensanglard.net/floating_point_visually_explained/](https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/)
- 浮点数问题实例：[https://jvns.ca/blog/2023/01/13/examples-of-floating-point-problems/](https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/)

特别关于浮点数求和的资料：

- 成对求和法：[https://en.wikipedia.org/wiki/Pairwise_summation](https://en.wikipedia.org/wiki/Pairwise_summation)
- Kahan 求和算法：[https://en.wikipedia.org/wiki/Kahan_summation_algorithm](https://en.wikipedia.org/wiki/Kahan_summation_algorithm)
- 驯服浮点求和：[https://orlp.net/blog/taming-float-sums/](https://orlp.net/blog/taming-float-sums/)