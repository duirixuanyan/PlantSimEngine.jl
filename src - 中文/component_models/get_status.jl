"""
    status(m)
    status(m::AbstractArray{<:ModelList})
    status(m::AbstractDict{T,<:ModelList})

获取 ModelList 的状态，即输入（和输出）变量的状态。

另见 [`is_initialized`](@ref) 和 [`to_initialize`](@ref)

# 示例

```jldoctest
using PlantSimEngine

# Including example models and processes:
using PlantSimEngine.Examples;

# Create a ModelList
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status = (var1=[15.0, 16.0], var2=0.3)
);

status(models)

# Or just one variable:
status(models,:var1)


# Or the status at the ith time-step:
status(models, 2)

# Or even more simply:
models[:var1]
# output
2-element Vector{Float64}:
 15.0
 16.0
```
"""
function status(m)
    m.status
end

function status(m::T) where {T<:AbstractArray{M} where {M}}
    [status(i) for i in m]
end

function status(m::T) where {T<:AbstractDict{N,M} where {N,M}}
    Dict([k => status(v) for (k, v) in m])
end

# 带变量参数时，返回该变量的值。
function status(m, key::Symbol)
    getproperty(m.status, key)
end

# 带整数参数时，返回第 i 个状态。
function status(m, key::T) where {T<:Integer}
    getindex(m.status, key)
end

"""
    getindex(component<:ModelList, key::Symbol)
    getindex(component<:ModelList, key)

对组件模型结构进行索引:
    - 当参数为整数时，会返回第 i 个时间步的状态
    - 其他（Symbol、String）则会返回状态中的对应变量

# 示例

```julia
using PlantSimEngine

lm = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status = (var1=[15.0, 16.0], var2=0.3)
);

lm[:var1] # 返回 Tₗ 变量的值
lm[2]  # 返回第二个时间步的状态
lm[2][:var1] # 返回第二个时间步的 Tₗ 变量的值
lm[:var1][2] # 等价于上面

# 输出
16.0
```
"""
function Base.getindex(component::T, key) where {T<:ModelList}
    status(component, key)
end

function Base.setindex!(component::T, value, key) where {T<:ModelList}
    setproperty!(status(component), key, value)
end
