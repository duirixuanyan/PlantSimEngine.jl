# 从 DataFrame 创建 TimeStepTable{Status}：
"""
    TimeStepTable{Status}(df::DataFrame)
    
方法：从 `DataFrame` 构建 `TimeStepTable`（来自 [PlantMeteo.jl](https://palmstudio.github.io/PlantMeteo.jl/stable/)），但每一行都是 `Status`。

# 注意

[`ModelList`](@ref) 默认使用 `TimeStepTable{Status}`（见下面的示例）。

# 示例

```julia
using PlantSimEngine, DataFrames

# 从 DataFrame 创建一个 TimeStepTable：
df = DataFrame(
    Tₗ=[25.0, 26.0],
    aPPFD=[1000.0, 1200.0],
    Cₛ=[400.0, 400.0],
    Dₗ=[1.0, 1.2],
)
TimeStepTable{Status}(df)

# 只要其中一个变量有多个值，叶片会自动用带时间步的 TimeStepTable{Status}：
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status=(var1=15.0, var2=0.3)
)

# 叶片的 status 是一个 TimeStepTable：
status(models)

# 当然也可以手动用 Status 创建 TimeStepTable：
TimeStepTable(
    [
        Status(Tₗ=25.0, aPPFD=1000.0, Cₛ=400.0, Dₗ=1.0),
        Status(Tₗ=26.0, aPPFD=1200.0, Cₛ=400.0, Dₗ=1.2),
    ]
)
```
"""
function PlantMeteo.TimeStepTable{Status}(df::DataFrames.DataFrame, metadata=NamedTuple())
    PlantMeteo.TimeStepTable((propertynames(df)...,), metadata, [Status(NamedTuple(ts)) for ts in Tables.rows(df)])
end

# """
#     Tables.schema(m::TimeStepTable{Status})

# 为 `TimeStepTable{Status}` 创建 schema。
# """
# function Tables.schema(m::PlantMeteo.TimeStepTable{T}) where {T<:Status}
#     # 这里比较复杂，因为变量的类型在 Status 中以 RefValue 隐藏了：
#     # col_types = fieldtypes(getfield(m, :ts)[1])

#     # # Tables.Schema(names(m), DataType[i.types[1] for i in T.parameters[2].parameters])
#     # Tables.Schema(names(m), col_types)
# end