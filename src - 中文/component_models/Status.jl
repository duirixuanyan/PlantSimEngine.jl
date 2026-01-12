"""
    Status(vars)

Status类型用于在模拟过程中存储变量的值。主要用作`TimeStepTable`的`TimeStepRow`中用于保存变量的结构体（参见[`PlantMeteo.jl` 文档](https://palmstudio.github.io/PlantMeteo.jl/stable/)），也用于[`ModelList`](@ref)。

大部分代码来自 MasonProtter/MutableNamedTuples.jl，因此`Status`本质上是一个经过少量修改的MutableNamedTuples，
也就是一个用来存储对变量值的引用的`NamedTuple`结构体，使其为可变类型。

# 示例

所有变量只有一个值的叶片将得到一个只有一个时间步长的状态对象：

```jldoctest st1
julia> using PlantSimEngine
```

```jldoctest st1
julia> st = PlantSimEngine.Status(Ra_SW_f=13.747, sky_fraction=1.0, d=0.03, aPPFD=1500.0);
```

以下索引方法均可用：

```jldoctest st1
julia> st[:Ra_SW_f]
13.747
```

```jldoctest st1
julia> st.Ra_SW_f
13.747
```

```jldoctest st1
julia> st[1]
13.747
```

设置 Status 变量也很简单：

```jldoctest st1
julia> st[:Ra_SW_f] = 20.0
20.0
```

```jldoctest st1
julia> st.Ra_SW_f = 21.0
21.0
```
    
```jldoctest st1
julia> st[1] = 22.0
22.0
```
"""
struct Status{N,T<:Tuple{Vararg{Ref}}}
    vars::NamedTuple{N,T}
end

Status(; kwargs...) = Status(NamedTuple{keys(kwargs)}(Ref.(values(values(kwargs)))))
function Status{names}(tuple::Tuple) where {names}
    Status(NamedTuple{names}(Ref.(tuple)))
end

function Status(nt::NamedTuple{names}) where {names}
    Status(NamedTuple{names}(Ref.(values(nt))))
end

Base.keys(::Status{names}) where {names} = names
Base.values(st::Status) = getindex.(values(getfield(st, :vars)))
refvalues(mnt::Status) = values(getfield(mnt, :vars))
refvalue(mnt::Status, key::Symbol) = getfield(getfield(mnt, :vars), key)

Base.NamedTuple(mnt::Status) = NamedTuple{keys(mnt)}(values(mnt))
Base.Tuple(mnt::Status) = values(mnt)

function Base.show(io::IO, ::MIME"text/plain", t::Status)
    st_panel = Term.Panel(
        Term.highlight(PlantMeteo.show_long_format_row(t)),
        title="Status",
        style="red",
        fit=false,
    )
    print(io, st_panel)
end

# 简短格式的打印（例如作为其它对象的一部分时）
function Base.show(io::IO, t::Status)
    length(t) == 0 && return
    print(io, "Status", NamedTuple(t))
end

Base.getproperty(mnt::Status, s::Symbol) = getproperty(getfield(mnt, :vars), s)[]
Base.getindex(mnt::Status, i::Int) = getfield(getfield(mnt, :vars), i)[]
Base.getindex(mnt::Status, i::Symbol) = getproperty(mnt, i)

function Base.setproperty!(mnt::Status, s::Symbol, x)
    nt = getfield(mnt, :vars)
    getfield(nt, s)[] = x
end

function Base.setproperty!(mnt::Status, i::Int, x)
    nt = getfield(mnt, :vars)
    getindex(nt, i)[] = x
end

function Base.setindex!(mnt::Status, x, i::Symbol)
    Base.setproperty!(mnt, i, x)
end

function Base.setindex!(mnt::Status, x, i::Int)
    setproperty!(mnt, i, x)
end

Base.propertynames(::Status{T,R}) where {T,R} = T
Base.length(mnt::Status) = length(getfield(mnt, :vars))
Base.eltype(::Type{Status{N,T}}) where {N,T} = eltype.(eltype(T))

Base.iterate(mnt::Status, iter=1) = iterate(NamedTuple(mnt), iter)

Base.firstindex(mnt::Status) = 1
Base.lastindex(mnt::Status) = lastindex(NamedTuple(mnt))

function Base.indexed_iterate(mnt::Status, i::Int, state=1)
    Base.indexed_iterate(NamedTuple(mnt), i, state)
end

function Base.:(==)(s1::Status, s2::Status)
    return (length(s1) == length(s2)) &&
           (propertynames(s1) == propertynames(s2)) &&
           (values(s1) == values(s2))
end


# 返回一个所有向量变量替换为其第一个值的status（即可用于模拟的Status），
# 同时返回一个对应于向量变量的符号元组
function flatten_status(s::Status{T}) where {T}
    n_vars_several_values = findall(x -> length(x) > 1, s)
    if length(n_vars_several_values) == 0
        return s, n_vars_several_values
    else
        return Status{keys(s)}(first.(values(s))), n_vars_several_values
    end
end

"""
    set_variables_at_timestep!(status_timestep::Status, user_status::Status, variables_to_update, timestep)

将 `status_timestep` 中所有在 `variables_to_update` 中的变量，更新为用户提供的 `user_status` 在指定 `timestep` 上的当前值。
变量名列表由 `variables_to_update` 提供，为符号向量。

`status_timestep` 是表示单次时间步长的状态，`user_status` 是用户提供的状态，包含未被任何模型计算的变量的值。
其变量值可以为常量，也可以是向量。如果为向量，则用 `timestep` 指定当前步长所用的值。

"""
function set_variables_at_timestep!(status_timestep::Status, user_status::Status, variables_to_update, timestep)
    for vec in variables_to_update
        status_timestep[vec] = user_status[vec][timestep]
    end
end

# TODO 更进一步，如果存在步长差异未被考虑，则返回错误
function get_status_vector_max_length(s::Status)
    max_len = 1
    for (var, value) in zip(keys(s), s)
        if length(value) > 1
            max_len = length(value)
        end
    end
    return max_len
end