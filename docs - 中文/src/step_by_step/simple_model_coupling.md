# 标准模型耦合

```@setup usepkg
using PlantSimEngine
using PlantSimEngine.Examples
using CSV
using DataFrames
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)
nothing
```

## 配置你的环境

同样，请确保你已经拥有一个可用的 Julia 环境，并添加了 PlantSimEngine 以及其他推荐的配套包。详细的安装和运行方法详见[PlantSimEngine 的安装与运行](@ref)一节。

## ModelList

[`ModelList`](@ref) 是一个容器，可以包含多个模型、它们的参数值及相关变量的状态。

在前面的例子中，ModelList 只包含了一个模型，其输入变量在 ModelList 的 [`status`](@ref) 关键字参数中初始化。

示例模型均取自 [`examples`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/master/examples/) 文件夹下的示例脚本。

下面是一个带有光截获模型的 [`ModelList`](@ref) 声明，该模型需要输入叶面积指数（LAI）： 

```julia
modellist_coupling_part_1 = ModelList(Beer(0.5), status = (LAI = 2.0,))
```

下面是第二个 ModelList，包含一个叶面积指数（LAI）模型，并以一个例子形式提供了积温（TT_cu）作为输入（TT_cu 通常由气象数据计算得来）：

```julia
modellist_coupling_part_2 = ModelList(
    ToyLAIModel(),
    status=(TT_cu=1.0:2000.0,), # 将积温作为输入传递给模型
)
```

## 模型耦合

假设我们希望 ToyLAIModel 为光截获模型计算 `LAI` 值。

我们可以通过将这两个模型放在同一个 [`ModelList`](@ref) 容器中实现它们的耦合。此时，`LAI` 变量会作为 ToyLAIModel 的输出并直接供 `Beer` 使用，不再需要在 [`status`] 关键字参数中单独声明。

这就是我们所说的[“软依赖”耦合](@ref hard_dependency_def)：一个模型将自身输入依赖于另一个模型的输出。

下面是第一次尝试：

```@example usepkg
using PlantSimEngine
# 导入 Examples 子模块中定义的示例：
using PlantSimEngine.Examples

# 一个包含两个耦合模型的 ModelList
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    status=(TT_cu=1.0:2000.0,),
)
struct UnexpectedSuccess <: Exception end #hack 用于在不导致文档构建失败的情况下检测错误 #hide
# 参见 https://github.com/JuliaDocs/Documenter.jl/issues/1420 #hide
try #hide
run!(models)
throw(UnexpectedSuccess()) #hide
catch err; err isa UnexpectedSuccess ? rethrow(err) : showerror(stderr, err); end  #hide
```

此时会出现与气象数据相关的报错，详细提示如下：

```julia
ERROR: type NamedTuple has no field Ri_PAR_f
Stacktrace:
  [1] getindex(mnt::Atmosphere{(), Tuple{}}, i::Symbol)
    @ PlantMeteo ~/Path/to/PlantMeteo/src/structs/atmosphere.jl:147
  [2] getcolumn(row::PlantMeteo.TimeStepRow{Atmosphere{(), Tuple{}}}, nm::Symbol)
    @ PlantMeteo ~/Path/to/PlantMeteo/src/structs/TimeStepTable.jl:205
    ...
```

`Beer` 模型需要特定的气象参数。为了解决这个问题，我们可以通过导入示例气象数据文件来实现：

```@example usepkg
using PlantSimEngine

# 现在使用 PlantMeteo 和 CSV 包
using PlantMeteo, CSV

# 导入 Examples 子模块中定义的示例
using PlantSimEngine.Examples

# 导入示例气象数据
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 一个包含两个耦合模型的 ModelList
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    status=(TT_cu=cumsum(meteo_day.TT),), # 现在我们可以根据气象数据计算真正的积温
)

# 在 run! 调用中加入气象数据
outputs_coupled = run!(models, meteo_day)

```

如上所示，光截获模型使用 ToyLAIModel 计算的叶面积指数进行了后续计算。

## 进一步耦合

当然，还可以继续添加更多模型。下面是一个加入了另一个模型 ToyRUEGrowthModel 的 ModelList 示例，该模型用于计算光合作用带来的碳生物量增量。

```julia
models = ModelList(
    ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    status=(TT_cu=cumsum(meteo_day.TT),),
)

nothing # hide
```