
"""
    fit()

利用观测值（以及可能的初始化值）优化模型参数。

建模者应为其模型实现一个 `fit` 方法，建议采用以下设计模式：

函数调用应将模型类型作为第一个参数（T::Type{<:AbstractModel}），
数据作为第二个参数（支持 Table.jl 的类型，如 DataFrame），并将参数初始化作为关键字参数传递（必要时可设默认值）。

例如，拟合示例脚本中的 `Beer` 模型的方法（参考 `src/examples/Beer.jl`）如下：

```julia
function PlantSimEngine.fit(::Type{Beer}, df; J_to_umol=PlantMeteo.Constants().J_to_umol)
    k = Statistics.mean(log.(df.Ri_PAR_f ./ (df.aPPFD ./ J_to_umol)) ./ df.LAI)
    return (k=k,)
end
```

该函数应返回以 `NamedTuple` 形式包含优化参数的元组，如 `(parameter_name=parameter_value,)`。

以下是使用 `Beer` 模型的一个示例，其中通过"aPPFD"、"LAI" 和 "Ri_PAR_f" 的观测值拟合参数 `k`。

```julia
# 引入示例过程与模型：
using PlantSimEngine.Examples;

m = ModelList(Beer(0.6), status=(LAI=2.0,))
meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0)
run!(m, meteo)
df = DataFrame(aPPFD=m[:aPPFD][1], LAI=m.status.LAI[1], Ri_PAR_f=meteo.Ri_PAR_f[1])
fit(Beer, df)
```

注意，这是一个用于演示拟合方法有效性的虚拟示例。在该例中，通过设置 `k=0.6` 用 Beer-Lambert 定律模拟 aPPFD，并再次利用模拟得到的 aPPFD 来拟合 `k`，最终得到与模拟时一致的参数值。
"""
function fit end