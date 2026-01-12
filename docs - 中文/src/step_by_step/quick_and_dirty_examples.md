# 快速示例

本页面适用于已经配置好环境，并希望直接复制粘贴一个或两个示例代码、查看 REPL 返回结果并快速上手的用户。

如果你对 Julia 不太熟悉，或者还没有配置好环境，请参阅此页面：[Julia 入门指南](@ref)。
如果你希望获得更详细的示例讲解，可以查阅[分步讲解](#step_by_step)部分，该部分会提供更深入的说明。

以下示例均为单尺度（single-scale）模拟。如需多尺度建模教程和示例，请参考[此节][#multiscale]。

你可以在[examples 文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/tree/main/examples)中找到所有示例模型的实现以及其它玩具模型。

```@contents
Pages = ["quick_and_dirty_examples.md"]
Depth = 2
```

## 环境说明

这些示例假定你已拥有安装了 PlantSimEngine 及其它所需包的 Julia 环境。如何配置环境的具体细节请参考 [PlantSimEngine 的安装与运行](@ref) 页面。

## 单一光截获模型与单一气象时步的示例

```@example usepkg
using PlantSimEngine, PlantMeteo
using PlantSimEngine.Examples
meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)
leaf = ModelList(Beer(0.5), status = (LAI = 2.0,))
out = run!(leaf, meteo)
```

## 光截获模型与叶面积指数模型的耦合

本示例中的气象数据包含 365 天的数据，因此模拟将有同样数量的时步。

```@example usepkg
using PlantSimEngine
using PlantMeteo, CSV, DataFrames

using PlantSimEngine.Examples

meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

outputs_coupled = run!(models, meteo_day)
```

## 光截获模型、叶面积指数模型与生物量增长模型的耦合示例

```@example usepkg
using PlantSimEngine
using PlantMeteo, CSV, DataFrames

using PlantSimEngine.Examples

meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

outputs_coupled = run!(models, meteo_day)
```

## 使用 PlantBioPhysics 的示例

PlantBioPhysics 是一个与 PlantSimEngine 配套的软件包，内置了诸多应用于生态生理模拟的模型。

你可以在[此处](https://vezy.github.io/PlantBiophysics.jl/stable/)查看它的文档。

该文档中提供了数个示例模拟。以下是摘自[此页面](https://vezy.github.io/PlantBiophysics.jl/stable/simulation/first_simulation/)的一个示例：

```julia
using PlantBiophysics, PlantSimEngine

meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = ModelList(
        Monteith(),
        Fvcb(),
        Medlyn(0.03, 12.0),
        status = (Ra_SW_f = 13.747, sky_fraction = 1.0, aPPFD = 1500.0, d = 0.03)
    )

out = run!(leaf,meteo)
```