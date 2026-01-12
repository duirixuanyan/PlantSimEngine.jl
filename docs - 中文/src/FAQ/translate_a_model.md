# 我想用 PlantSimEngine 来实现我的模型

```@setup mymodel
using PlantSimEngine
using CairoMakie
using CSV, DataFrames
# 导入 `Examples` 子模块中定义的示例模型:
using PlantSimEngine.Examples

function lai_toymodel(TT_cu; max_lai=8.0, dd_incslope=500, inc_slope=70, dd_decslope=1000, dec_slope=20)
    LAI = max_lai * (1 / (1 + exp((dd_incslope - TT_cu) / inc_slope)) - 1 / (1 + exp((dd_decslope - TT_cu) / dec_slope)))
    if LAI < 0
        LAI = 0
    end
    return LAI
end

meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
```

如果你已经有了一个模型，只需要做些小调整，就可以很容易地用 `PlantSimEngine` 与其他模型耦合。

## LAI 玩具模型

### 模型描述

下面我们以一个简单的 LAI 模型为例：

```julia
"""
使用一个简单的双逻辑函数，根据播种后的积温（degree-days）模拟作物的叶面积指数（LAI，单位：m² m⁻²）。

# 参数

- `TT_cu`：播种以来的积温（degree-days）
- `max_lai=8`：LAI 的最大值
- `dd_incslope=500`：LAI 增长最快时对应的积温
- `inc_slope=5`：LAI 曲线上升阶段的斜率
- `dd_decslope=1000`：LAI 下降最快时对应的积温
- `dec_slope=2`：LAI 曲线下降阶段的斜率
"""
function lai_toymodel(TT_cu; max_lai=8.0, dd_incslope=500, inc_slope=70, dd_decslope=1000, dec_slope=20)
    LAI = max_lai * (1 / (1 + exp((dd_incslope - TT_cu) / inc_slope)) - 1 / (1 + exp((dd_decslope - TT_cu) / dec_slope)))
    if LAI < 0
        LAI = 0
    end
    return LAI
end
```

该模型以播种后的天数作为输入，返回模拟得到的 LAI。我们可以绘制一整年模拟得到的 LAI 曲线如下：

```@example mymodel
using CairoMakie

lines(1:1300, lai_toymodel.(1:1300), color=:green, axis=(ylabel="LAI (m² m⁻²)", xlabel="Days since sowing"))
```

### 针对 PlantSimEngine 的调整

该模型可以通过 `PlantSimEngine` 实现，方法如下：

#### 定义一个过程

如果 LAI 动态过程（Process）尚未实现，我们可以这样定义：

```julia
@process LAI_Dynamic
```

#### 定义模型结构体

我们需要为我们的模型定义一个结构体，用于保存模型的参数：

```julia
struct ToyLAIModel <: AbstractLai_DynamicModel
    max_lai::Float64
    dd_incslope::Int
    inc_slope::Float64
    dd_decslope::Int
    dec_slope::Float64
end
```

我们还可以通过定义带有关键字参数的方法，为参数设置默认值：

```julia
ToyLAIModel(; max_lai=8.0, dd_incslope=500, inc_slope=70, dd_decslope=1000, dec_slope=20) = ToyLAIModel(max_lai, dd_incslope, inc_slope, dd_decslope, dec_slope)
```

这样，用户只需调用 `ToyLAIModel()` 就可以使用默认参数创建模型，也可以只指定自己想要更改的参数，例如 `ToyLAIModel(inc_slope=80.0)`。

#### 定义输入 / 输出

接下来我们可以定义模型的输入和输出变量，以及初始化时的默认值：

```julia
PlantSimEngine.inputs_(::ToyLAIModel) = (TT_cu=-Inf,)
PlantSimEngine.outputs_(::ToyLAIModel) = (LAI=-Inf,)
```

!!! note
    请注意，这里我们为默认值使用了 `-Inf`，这是 `Float64` 类型推荐的默认值（`Int` 类型推荐为 -999），因为它对于该类型是有效的，并且如果未正确赋值时很容易在输出中捕捉到（因为它会在计算中持续传播）。你也可以使用 `NaN` 作为默认值。

#### 定义模型函数

最后，我们可以定义模型的主计算函数，此函数会在每个时间步自动被调用：

```julia
function PlantSimEngine.run!(::ToyLAIModel, models, status, meteo, constants=nothing, extra=nothing)
    status.LAI = models.LAI_Dynamic.max_lai * (1 / (1 + exp((models.LAI_Dynamic.dd_incslope - status.TT_cu) / models.LAI_Dynamic.inc_slope)) - 1 / (1 + exp((models.LAI_Dynamic.dd_decslope - status.TT_cu) / models.LAI_Dynamic.dec_slope)))

    if status.LAI < 0
        status.LAI = 0
    end
end
```

!!! note
    请注意，在函数定义中我们没有直接返回 LAI 的值，而是通过更新 status 变量实现对 LAI 的赋值。status 结构体高效地存储了模型在每个时间步的状态，包含了所有声明为输入或输出的变量。通过 `status.LAI`，我们可以在任何时间步访问 LAI 的值。

!!! note
    该函数**只针对单个时间步**进行定义，并且会由 PlantSimEngine 在每个时间步自动调用。这意味着我们不需要在该函数内自行编写时间循环。

#### [运行模拟](@id defining_the_meteo)

现在我们已经完成了前面的准备工作，可以运行一次模拟了。首先需要设置气象数据：

```julia
# 导入所需的包:
using PlantMeteo, Dates, DataFrames

# 定义模拟的时间范围:
period = [Dates.Date("2021-01-01"), Dates.Date("2021-12-31")]

# 获取法国蒙彼利埃 CIRAD 站点的气象数据:
meteo = get_weather(43.649777, 3.869889, period, sink = DataFrame)

# 计算以10°C为基温的积温(°C日):
meteo.TT = max.(meteo.T .- 10.0, 0.0)

# 将气象数据聚合为日尺度:
# 为什么要 sum(x) / 24
meteo_day = to_daily(meteo, :TT => (x -> sum(x) / 24) => :TT)
```

接下来我们可以定义模型列表，并在初始化状态时传递 `TT_cu` 的数值：

```@example mymodel
m = ModelList(
    ToyLAIModel(),
    status = (TT_cu = cumsum(meteo_day.TT),),
)

outputs_sim = run!(m)

lines(outputs_sim[:TT_cu], outputs_sim[:LAI], color=:green, axis=(ylabel="LAI (m² m⁻²)", xlabel="Days since sowing"))
```
