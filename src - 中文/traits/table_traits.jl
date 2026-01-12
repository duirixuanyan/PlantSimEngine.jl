abstract type DataFormat end
struct TableAlike <: DataFormat end
struct SingletonAlike <: DataFormat end
struct TreeAlike <: DataFormat end

"""
    DataFormat(T::Type)

返回类型 `T` 的数据格式。数据格式用于确定如何遍历数据。支持以下数据格式：

- `TableAlike`：数据为类似表格的对象，例如 `DataFrame` 或 `TimeStepTable`。数据通过 `Tables.jl` 接口按行遍历。
- `SingletonAlike`：数据为类似单例的对象，例如 `NamedTuple` 或 `TimeStepRow`。数据通过按列遍历。
- `TreeAlike`：数据为类似树结构的对象，例如 `Node`。

默认实现中，`AbstractDataFrame`、`TimeStepTable`、`AbstractVector` 和 `Dict` 返回 `TableAlike`；`GraphSimulation` 返回 `TreeAlike`；`Status`、`ModelList`、`NamedTuple` 和 `TimeStepRow` 返回 `SingletonAlike`。

`Any` 的默认实现会抛出异常。如果用户希望使用其他输入类型，应为新数据格式定义此 trait，例如：

```julia
PlantSimEngine.DataFormat(::Type{<:MyType}) = TableAlike()
```

# 示例

```jldoctest
julia> using PlantSimEngine, PlantMeteo, DataFrames

julia> PlantSimEngine.DataFormat(DataFrame)
PlantSimEngine.TableAlike()

julia> PlantSimEngine.DataFormat(TimeStepTable([Status(a = 1, b = 2, c = 3)]))
PlantSimEngine.TableAlike()

julia> PlantSimEngine.DataFormat([1, 2, 3])
PlantSimEngine.TableAlike()

julia> PlantSimEngine.DataFormat(Dict(:a => 1, :b => 2))
PlantSimEngine.TableAlike()

julia> PlantSimEngine.DataFormat(Status(a = 1, b = 2, c = 3))
PlantSimEngine.SingletonAlike()
```
"""
DataFormat(::Type{<:DataFrames.AbstractDataFrame}) = TableAlike()
DataFormat(::Type{<:PlantMeteo.TimeStepTable}) = TableAlike()

# 将 ModelList 作为向量或字典对象给出：
DataFormat(::Type{<:AbstractVector}) = TableAlike()
DataFormat(::Type{<:Dict}) = TableAlike()

DataFormat(::Type{<:NamedTuple}) = SingletonAlike()
DataFormat(::Type{<:Status}) = SingletonAlike()
DataFormat(::Type{<:ModelList{Mo,S} where {Mo,S}}) = SingletonAlike()
DataFormat(::Type{<:GraphSimulation}) = TreeAlike()

DataFormat(::Type{<:PlantMeteo.AbstractAtmosphere}) = SingletonAlike()
DataFormat(::Type{<:PlantMeteo.TimeStepRow}) = SingletonAlike()
DataFormat(::Type{<:Nothing}) = SingletonAlike() # 适用于 meteo == Nothing 的情况
DataFormat(T::Type{<:Any}) = error("Unknown data format: $T.\nPlease define a `DataFormat` method, e.g.: DataFormat(::Type{$T}) method.")
DataFormat(x::T) where {T} = DataFormat(T)
DataFormat(::Type{<:DataFrames.DataFrameRow}) = SingletonAlike()