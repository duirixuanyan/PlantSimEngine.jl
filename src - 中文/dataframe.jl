"""
    DataFrame(components <: AbstractArray{<:ModelList})
    DataFrame(components <: AbstractDict{N,<:ModelList})

从[`ModelList`](@ref)（或其数组/字典）的状态中提取数据为一个DataFrame。

# 示例

```@example
using PlantSimEngine
using DataFrames

# 创建一个 ModelList
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status=(var1=15.0, var2=0.3)
)

# 转换为 DataFrame
df = DataFrame(models)

# 创建一个包含 ModelList 的字典
models = Dict(
    "Leaf" => ModelList(
        process1=Process1Model(1.0),
        process2=Process2Model(),
        process3=Process3Model()
    ),
    "InterNode" => ModelList(
        process1=Process1Model(1.0),
        process2=Process2Model(),
        process3=Process3Model()
    )
)

# 转换为 DataFrame
df = DataFrame(models)
```
"""
function DataFrames.DataFrame(components::T) where {T<:AbstractArray{<:ModelList}}
    df = DataFrame[]
    for (k, v) in enumerate(components)
        df_c = DataFrames.DataFrame(v)
        df_c[!, :component] .= k
        push!(df, df_c)
    end
    reduce(vcat, df)
end

function DataFrames.DataFrame(components::T) where {T<:AbstractDict{N,<:ModelList} where {N}}
    df = DataFrames.DataFrame[]
    for (k, v) in components
        df_c = DataFrames.DataFrame(v)
        df_c[!, :component] .= k
        push!(df, df_c)
    end
    reduce(vcat, df)
end

"""
    DataFrame(components::ModelList{T,S}) where {T,S<:Status}

用于只有一个时间步的 `ModelList` 模型的 `DataFrame` 实现。
"""
function DataFrames.DataFrame(components::ModelList{T,S}) where {T,S<:Status}
    DataFrames.DataFrame([NamedTuple(status(components)[1])])
end
