# 输入类型

[`run!`](@ref) 通常需要两个输入：一个 [`ModelList`](@ref) 和气象数据。气象数据一般可以使用 `Atmosphere` 表示单个时间步，也可以用 `TimeStepTable{Atmosphere}` 表示多个时间步的数据。[`ModelList`](@ref) 也可以用单个元素、向量或字典的形式传递。

[`run!`](@ref) 能够根据 [`PlantSimEngine.DataFormat`](@ref) trait 处理这些数据格式（想了解 trait 的更多信息请参见[这篇博客](https://www.juliabloggers.com/the-emergent-features-of-julialang-part-ii-traits/)）。例如，我们可以通过实现如下 trait 告诉 PlantSimEngine，`TimeStepTable` 应被当作表格处理：

```julia
DataFormat(::Type{<:PlantMeteo.TimeStepTable}) = TableAlike()
```

如果你有其他格式的气象输入数据，可以为它实现新的 trait。例如，如果你有一个类似表格的数据格式，可以这样实现：

```julia
DataFormat(::Type{<:MyTableFormat}) = TableAlike()
```

还有另外两种 trait 可供选择：`SingletonAlike` 适用于仅代表单个时间步的数据格式，`TreeAlike` 适用于树状结构，目前用于 MultiScaleTreeGraphs 的节点（目前不是通用型）。

## 新输入类型的特殊注意事项

如果你希望自定义输入数据格式，需要根据自身用例确保实现了相关的方法。

例如，如果你的模型需要从不同时间步获取数据（*例如* 需要获取前一天的温度），则必须确保可以从当前时间步访问其他时间步的数据。

为此，你需要为定义行的结构体实现以下方法：

- `Base.parent`：返回该行所属的父表，例如完整的 DataFrame
- `PlantMeteo.rownumber`：返回该行在父表中的行号，例如在 DataFrame 中的行号
- （可选）`PlantMeteo.row_from_parent(row, i)`：从父表返回第 `i` 行，例如在 DataFrame 中的第 `i` 行。如果你追求高性能才需要实现，默认会调用 `Tables.rows(parent(row))[i]`。

!!! compat
    `PlantMeteo.rownumber` 是临时方案。未来会被 `DataAPI.rownumber` 替代，后者也会被 DataFrames.jl 等包采用。详见 [这个 Pull Request](https://github.com/JuliaData/DataAPI.jl/issues/60)。

## 使用气象数据

下面是一个展示如何导出示例气象数据到自定义文件的简单例子：

```julia 
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
PlantMeteo.write_weather("examples/meteo_day.csv", meteo_day, duration = Dates.Day)
```

如果你希望过滤、重塑、调整或写出天气数据，可以参考 PlantMeteo 的 [API 文档](https://palmstudio.github.io/PlantMeteo.jl/stable/API/)，内有更多示例。