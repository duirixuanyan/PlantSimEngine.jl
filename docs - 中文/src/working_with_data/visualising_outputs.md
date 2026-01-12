```@setup usepkg
# ] add PlantSimEngine, DataFrames, CSV
using PlantSimEngine, PlantMeteo, DataFrames, CSV

# 从示例文件夹中引入模型定义：
using PlantSimEngine.Examples

# 导入示例气象数据：
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 定义耦合模型的列表：
model = ModelList(
    ToyLAIModel(),
    Beer(0.6),
    status=(TT_cu=cumsum(meteo_day[:, :TT]),),  # 将积温作为 ToyLAIModel 的输入，也可以通过其他模型完成
)

# 运行模拟：
sim_out = run!(model, meteo_day)

```

# 输出和数据可视化

## 输出结构

PlantSimEngine 的 `run!` 函数会在每个时间步返回所请求变量（通过 `tracked_outputs` 关键字参数设定，若未指定则返回所有变量）的状态。多尺度模拟还会指明这些状态变量关联的器官和 MTG 节点。

以下是一个使用 CairoMakie（绘图用包）来绘制输出数据的示例。

```@example usepkg
# ] add PlantSimEngine, DataFrames, CSV
using PlantSimEngine, PlantMeteo, DataFrames, CSV

# 从示例文件夹中引入模型定义：
using PlantSimEngine.Examples

# 导入示例气象数据：
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 定义耦合模型的列表：
models = ModelList(
    ToyLAIModel(),
    Beer(0.6),
    status=(TT_cu=cumsum(meteo_day[:, :TT]),),  # 将积温作为 ToyLAIModel 的输入，也可以通过其他模型完成
)

# 运行模拟：
sim_outputs = run!(models, meteo_day)
```

输出的数据默认以 `TimeStepTable` 结构显示。也可以通过可选的 `tracked_outputs` 关键字参数筛选需要保留的变量。

## 输出结果的可视化

使用 CairoMakie，可以绘制选定的变量：

!!! note
    你需要先通过 Pkg 模式向环境中添加 CairoMakie。

```@example usepkg
# 绘制结果：
using CairoMakie

fig = Figure(resolution=(800, 600))
ax = Axis(fig[1, 1], ylabel="LAI (m² m⁻²)")
lines!(ax, sim_outputs[:TT_cu], sim_outputs[:LAI], color=:mediumseagreen)

ax2 = Axis(fig[2, 1], xlabel="Cumulated growing degree days since sowing (°C)", ylabel="aPPFD (mol m⁻² d⁻¹)")
lines!(ax2, sim_outputs[:TT_cu], sim_outputs[:aPPFD], color=:firebrick1)

fig
```

## TimeStepTable 与 DataFrame

```@setup usepkg
sim_out = run!(model, meteo_day)
```

输出数据通常以 `PlantMeteo.jl` 中定义的 `TimeStepTable` 结构存储，这是一种高效的类似 DataFrame 的结构，每个时间步储存一个 [`Status`](@ref)。输出也可以为任何 `Tables.jl` 兼容结构，例如普通的 `DataFrame`。气象数据也常以 `TimeStepTable` 结构存储，但每个时间步是一个 `Atmosphere`。

还有一种简单方法可以将结果转换为 `DataFrame`，这很容易，因为 `TimeStepTable` 实现了 Tables.jl 接口：

```@example usepkg
using DataFrames
sim_outputs_df = PlantSimEngine.convert_outputs(sim_outputs, DataFrame)
sim_outputs_df[[1, 2, 3, 363, 364, 365], :]
```

也可以从特定变量创建 DataFrame：

```julia
df = DataFrame(aPPFD=sim_outputs[:aPPFD][1], LAI=sim_outputs.LAI[1], Ri_PAR_f=meteo.Ri_PAR_f[1])
```

在 [参数拟合](@ref) 时，这种方法也非常有用。