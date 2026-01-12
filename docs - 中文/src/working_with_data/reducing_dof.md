# 减少自由度（DoF）

```@setup usepkg
using PlantSimEngine, PlantMeteo
# 导入 `Examples` 子模块中定义的示例：
using PlantSimEngine.Examples

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
struct ForceProcess1Model <: AbstractProcess1Model end
PlantSimEngine.inputs_(::ForceProcess1Model) = (var3=-Inf,)
PlantSimEngine.outputs_(::ForceProcess1Model) = (var3=-Inf,)
function PlantSimEngine.run!(::ForceProcess1Model, models, status, meteo, constants=nothing, extra=nothing)
    return nothing
end
```

## 概述

### 为什么要减少模型的自由度

通过将某些变量强制设为观测值来减少模型的自由度，有以下几个作用：

1. 可以通过约束模型并降低模型复杂性来防止过拟合。
2. 通过减少变量之间的协变性，有助于更好地校准模型的其他组成部分（参见[参数退化（Parameter Degeneracy）](@ref)）。
3. 通过识别最关键的变量和关系，提高模型的可解释性。
4. 通过减少需要估算的变量个数，提高模型的计算效率。
5. 有助于确保模型与已知的物理或观测约束一致，提高模型及其预测结果的可信度。
6. 需要注意的是，过度约束模型可能导致不良拟合和得出错误结论，因此必须谨慎选择要约束哪些变量以及约束为哪些观测值。

## 参数退化（Parameter Degeneracy）

模型中的“退化”或“参数退化”指的是当模型中的两个或多个变量高度相关时，一个变量的微小变化可以被另一个变量的微小变化补偿，从而导致模型整体预测结果保持不变。参数退化会导致难以准确估算变量的真实值，也难以确定模型的唯一解。这也会使模型对初始条件（如参数）和优化算法变得敏感。

退化与“协变性”或“共线性”相关，它们都指多个变量之间的线性关系程度。在退化模型中，两个及以上变量高度协变，即高度相关，能够产生类似的预测。通过将某个变量固定为观测值，模型调整其他变量的灵活性会降低，有助于减少协变性，提升模型的稳健性。

这是植物/作物建模中非常重要的话题，因为此类模型常常是退化的。在该领域通常称为“多重共线性（multicollinearity）”。在模型校准情境下，也常被称为“参数退化”或“参数共线性”。在模型简化（模型约减）时，也常称为“冗余”或“冗余变量”。

## 在 PlantSimEngine 中减少自由度（DoF）

### 弱耦合模型（Soft-coupled models）

PlantSimEngine 提供了一种简单的方法来减少模型的自由度：通过将某些变量的值强制为观测值进行约束。

我们先像往常一样，定义一个模型列表，包含 `examples/dummy.jl` 中的七个过程：

```@example usepkg
using PlantSimEngine, PlantMeteo
# 导入 Examples 子模块中定义的示例模型：
using PlantSimEngine.Examples

meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    Process7Model(),
    status=(var0 = 0.5,)
)

run!(m, meteo)

status(m)
```

假设 `m` 是我们的完整模型，现在我们想要通过强制 `var9` 的值为观测值来减少自由度。`var9` 之前是通过 `Process7Model`（一个弱依赖模型）计算得到的。在 PlantSimEngine 中，非常容易实现这个目标：只需从模型列表中移除对应模型，然后在 status 中给出观测值即可：

```@example usepkg
m2 = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    status=(var0 = 0.5, var9 = 10.0),
)

out = run!(m2, meteo)
```

就这样！所有依赖 `var9` 的模型现在都会直接使用观测值 `var9`，而不会再使用 `Process7Model` 计算出的值。

### 强耦合模型（Hard-coupled models）

对于与其他模型强耦合（hard-coupled）的模型，减少自由度会稍微复杂一些，因为它会调用其他模型的 [`run!`](@ref) 方法。

在这种情况下，我们需要用一个新模型替换原有的模型，使变量值强制等于观测值。具体方法是：将测量值作为新模型的输入，并在 `run!` 方法中返回 `nothing`，这样变量的值就不会被修改。

依然以包含上面七个过程的模型列表为例。假设这一次我们想要通过将原本由 `Process1Model`（一个强依赖模型）计算得到的 `var3` 强制为观测值来减少自由度。在 PlantSimEngine 中，这很容易实现：只需用一个新的模型替代原有模型，将 `var3` 的值设为测量值即可：

```@example usepkg
struct ForceProcess1Model <: AbstractProcess1Model end
PlantSimEngine.inputs_(::ForceProcess1Model) = (var3=-Inf,)
PlantSimEngine.outputs_(::ForceProcess1Model) = (var3=-Inf,)
function PlantSimEngine.run!(::ForceProcess1Model, models, status, meteo, constants=nothing, extra=nothing)
    return nothing
end
```

现在，我们可以用新的 `ForceProcess1Model` 替换原有的 `Process1Model`，创建一个新的模型列表：

```@example usepkg
m3 = ModelList(
    ForceProcess1Model(), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    Process7Model(),
    status = (var0=0.5,var3 = 10.0)
)

out = run!(m3, meteo)
```

!!! note
    理论上也可以通过 meteo 数据传递观测变量，但一般并不推荐。meteo 数据仅应用于气象变量，而不建议用作模型内部变量的输入。对于此类变量，最好仍然通过 status 进行赋值。
