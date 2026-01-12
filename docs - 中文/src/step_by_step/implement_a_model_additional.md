# 模型实现补充说明

```@contents
Pages = ["implement_a_model_additional.md"]
Depth = 3
```

## 参数化类型

在[实现一个模型](@ref model_implementation_page)章节，Beer 模型的结构体是以参数化类型声明的。

```julia
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end
```

为什么不直接强制指定类型呢？毕竟 Float64 比 Float32 更精确：

```julia
struct YourStruct <: AbstractLight_InterceptionModel
    k::Float64
    x::Float64
    y::Float64
    z::Int
end
```

这样做会损失用户对模型使用上的灵活性。例如，用户可能想用 [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) 包中的 `Particles` 类型来做自动不确定性传播，只有类型支持参数化，这样的用法才成为可能。如果强制字段为 `Float64`，就无法和 `Particles` 类型兼容。

## 类型提升

当你实现一个新模型时，可以做一些额外的、可选的细化工作以方便未来的用户。

你可以为类型提升（type promotion）专门添加一个方法。对于前面的 `Beer` 示例来说没必要，因为只有一个参数。但我们可以举一个包含两个参数的新模型，比如叫作 `Beer2`：

```julia
struct Beer2{T} <: AbstractLight_InterceptionModel
    k::T
    x::T
end
```

为了给 `Beer2` 添加类型提升（type promotion）的功能，我们可以这样做：

```julia
function Beer2(k,x)
    Beer2(promote(k,x)...)
end
```

!!! note
    `promote` 返回一个 NamedTuple，需要用展开（splatting）操作符 `...` 传递给构造函数。更多解释可以参考 [Julia 官方文档](https://docs.julialang.org/en/v1/manual/conversion-and-promotion/#Promotion)，或参见我们的 [Julia 入门指南](@ref) 页面，里面有关于 PlantSimEngine 使用的一些 Julia 概念的参考链接。

这样可以让用户使用不同类型参数来实例化模型。例如，用户可以写：

```julia
Beer2(0.6,2)
```

`Beer2` 是一个参数化类型，所有字段都具有相同的类型 `T`。这里的 `T` 就出现在 `Beer2{T}` 以及 `k::T` 和 `x::T`。这要求用户提供的所有参数类型相同。

在上面的例子中，`k` 的值是 `0.6`（类型为 `Float64`），而 `x` 的值是 `2`（类型为 `Int`）。如果没有类型提升，Julia 会报错，因为两个参数类型不同。而类型提升则在这里派上用场：它会自动将你的所有输入提升为一种统一类型（如果可能的话）。在本例中，`2` 会被提升为 `2.0`。

## 其他辅助函数和构造方法

### 参数默认值

你可以通过为某些参数（如果适用）提供默认值，简化用户的模型使用方式。例如，在 `Beer` 模型中，用户几乎不会去修改 `k` 的值，所以我们可以如下提供默认值：

```@example usepkg
Beer() = Beer(0.6)
```

现在，用户可以直接使用无参数的 `Beer()` 调用，此时 `k` 会默认采用 `0.6`。

### 以关键字参数形式传递参数值

另一个很实用的做法是允许使用关键字参数来实例化你的模型类型，也就是给参数显式命名。你可以通过添加如下方法实现：

```@example usepkg
Beer(;k) = Beer(k)
```

这里的 `;` 语法表示后面的参数可以作为关键字参数传递，因此现在我们可以这样调用 `Beer`：

```julia
Beer(k = 0.7)
```

当参数较多、部分参数有默认值时，这种方式可以大大提升代码的可读性。

### eltype

最后一个可选的辅助方法，是为你的模型类型实现 `eltype` 方法：

```julia
Base.eltype(x::Beer{T}) where {T} = T
```

这样可以让 Julia 知道结构体中元素的类型，从而提升执行效率。