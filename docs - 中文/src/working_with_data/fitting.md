# 参数拟合

```@setup usepkg
using PlantSimEngine, PlantMeteo, DataFrames, Statistics
using PlantSimEngine.Examples

meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
m = ModelList(Beer(0.6), status=(LAI=2.0,))
run!(m, meteo)

df = DataFrame(aPPFD=m[:aPPFD][1], LAI=m.status.LAI[1], Ri_PAR_f=meteo.Ri_PAR_f[1])
```

## 拟合 (fit) 方法

模型通常需要利用数据进行校准，但校准过程会根据模型类型以及用户所拥有的数据而有所不同。

`PlantSimEngine` 定义了一个通用的 [`fit`](@ref) 函数。这样模型开发者可以为自己的模型提供拟合参数的方法，用户也可以通过该方法使用数据对模型进行校准。

在本包中，`fit` 函数本身并没有实质作用，仅仅用来为所有模型提供统一的接口。具体方法的实现，需要模型开发者自行为自己的模型进行定义。

此方法的实现遵循如下设计模式：该函数的第一个参数应为模型类型（T::Type{<:AbstractModel}），第二个参数为数据（类型需兼容 `Table.jl`，例如 `DataFrame`），其余信息（如常数或带默认值的初始参数）可作为关键字参数传入。

## Beer 模型的示例

实现 `Beer` 模型的示例脚本（参见 `src/examples/Beer.jl`）展示了如何为模型实现 `fit` 方法：

```julia
function PlantSimEngine.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)
    k = Statistics.mean(log.(df.Ri_PAR_f ./ (df.PPFD ./ J_to_umol)) ./ df.LAI)
    return (k=k,)
end
```

该函数的第一个参数为 `Beer` 类型，第二个参数为数据，要求为兼容 `Tables.jl` 的类型，比如 `DataFrame`。关键字参数 `J_to_umol` 用于单位换算（μmol m⁻² s⁻¹ 与 J m⁻² s⁻¹ 之间的转换）。

`df` 数据框应包含 `PPFD`（单位：μmol m⁻² s⁻¹）、`LAI`（单位：m² m⁻²）以及 `Ri_PAR_f`（单位：W m⁻²）这三列。函数会基于这些值计算参数 `k`，并返回形如 `(参数名=参数值,)` 的 NamedTuple。

下面是 `fit` 方法使用示例：

首先导入需要的脚本和包：

```julia
using PlantSimEngine, PlantMeteo, DataFrames, Statistics
# 导入在 `Examples` 子模块里定义的示例：
using PlantSimEngine.Examples
```

定义气象数据：

```@example usepkg
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
```

用 `Beer` 模型（k=0.6）根据 `Ri_PAR_f` 值计算 `PPFD`：

```@example usepkg
m = ModelList(Beer(0.6), status=(LAI=2.0,))
run!(m, meteo)
```

然后通过模拟得到的 `PPFD` 值构造用于拟合的数据：

```@example usepkg
df = DataFrame(aPPFD=m[:aPPFD][1], LAI=m.status.LAI[1], Ri_PAR_f=meteo.Ri_PAR_f[1])
```

最后可以利用 `fit` 方法进行拟合：

```@example usepkg
fit(Beer, df)
```

!!! note
    这是一个简单的演示示例，仅用于展示拟合方法的用法。实际应用中应直接使用观测到的数据来拟合参数值。