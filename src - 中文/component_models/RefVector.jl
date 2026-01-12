"""
    RefVector(field::Symbol, sts...)
    RefVector(field::Symbol, sts::Vector{<:Status})
    RefVector(v::Vector{Base.RefValue{T}})

一个引用结构体向量中特定字段的引用向量。
用于在不同尺度之间高效地传递数值。

# 参数

- `field`: 要引用的结构体字段
- `sts...`: 要引用的结构体实例
- `sts::Vector{<:Status}`: 要引用的结构体实例向量

# 示例

```jldoctest mylabel
julia> using PlantSimEngine
```

假设有两个 Status 结构体：

```jldoctest mylabel
julia> status1 = Status(a = 1.0, b = 2.0, c = 3.0);
```

```jldoctest mylabel
julia> status2 = Status(a = 2.0, b = 3.0, c = 4.0);
```

我们可以创建引用结构体 status1 和 status2 字段 `a` 的 RefVector：

```jldoctest mylabel
julia> rv = PlantSimEngine.RefVector(:a, status1, status2)
2-element PlantSimEngine.RefVector{Float64}:
 1.0
 2.0
```

这等效于：

```jldoctest mylabel
julia> rv = PlantSimEngine.RefVector(:a, [status1, status2])
2-element PlantSimEngine.RefVector{Float64}:
 1.0
 2.0
```

可以访问 RefVector 的值：

```jldoctest mylabel
julia> rv[1]
1.0
```

修改 RefVector 中的值会同时修改原结构体中的值：

```jldoctest mylabel
julia> rv[1] = 10.0
10.0
```

```jldoctest mylabel
julia> status1.a
10.0
```

我们还可以通过引用向量创建 RefVector：

```jldoctest mylabel
julia> vec = [Ref(1.0), Ref(2.0), Ref(3.0)]
3-element Vector{Base.RefValue{Float64}}:
 Base.RefValue{Float64}(1.0)
 Base.RefValue{Float64}(2.0)
 Base.RefValue{Float64}(3.0)
```

```jldoctest mylabel
julia> rv = PlantSimEngine.RefVector(vec)
3-element PlantSimEngine.RefVector{Float64}:
 1.0
 2.0
 3.0
```

```jldoctest mylabel
julia> rv[1]
1.0
```
"""
struct RefVector{T} <: AbstractVector{T}
    v::Vector{Base.RefValue{T}}
end

function Base.getindex(rv::RefVector, i::Int)
    return rv.v[i][]
end

function Base.setindex!(rv::RefVector, v, i::Int)
    rv.v[i][] = v
end

Base.size(rv::RefVector) = size(rv.v)
Base.length(rv::RefVector) = length(rv.v)
Base.eltype(::Type{RefVector{T}}) where {T} = T
Base.parent(v::RefVector) = v.v

Base.resize!(v::RefVector, nl::Integer) = (resize!(parent(v), nl); v)
Base.push!(v::RefVector, x...) = (push!(parent(v), x...); v)
Base.pop!(v::RefVector) = pop!(parent(v))
Base.append!(v::RefVector, items) = (append!(parent(v), items); v)
Base.empty!(v::RefVector) = (empty!(parent(v)); v)

function Base.show(io::IO, rv::RefVector{T}) where {T}
    print(io, "RefVector{")
    print(io, T)
    print(io, "}[")
    for i in 1:length(rv.v)
        print(io, rv.v[i][])
        if i < length(rv.v)
            print(io, ", ")
        end
    end
    print(io, "]")
end

# 从结构体向量的某个字段生成数值引用向量的函数：
function RefVector(field::Symbol, sts...)
    return RefVector(typeof(refvalue(sts[1], field))[refvalue(st, field) for st in sts])
end

function RefVector(field::Symbol, sts::Vector{<:Status})
    return RefVector(typeof(refvalue(sts[1], field))[refvalue(st, field) for st in sts])
end

function RefVector{T}() where {T}
    return RefVector{T}(Base.RefValue{T}[])
end