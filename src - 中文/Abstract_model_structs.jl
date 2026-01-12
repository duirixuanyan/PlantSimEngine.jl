"""
抽象模型类型。所有模型都是此类型的子类型。
"""
abstract type AbstractModel end

"""
    process(x)

返回模型 `x` 的过程名称（process name）。
"""
# process(x) = error("process() is not defined for $(typeof(x))")
# process(x::AbstractModel) = error("process() is not defined for $(x), did you forget to define it?")
process(x::A) where {A<:AbstractModel} = process_(supertype(A))

# 针对以过程名称给出的模型：
process(x::Pair{Symbol,A}) where {A<:AbstractModel} = first(x)
process_(x) = error("process() is not defined for $(x)")

"""
    model_(m::AbstractModel)

获取抽象模型的模型（如果不是多尺度模型 MultiScaleModel，则返回其本身）。
"""
model_(m::AbstractModel) = m
get_models(m::AbstractModel) = [model_(m)] # 获取 AbstractModel 的模型
# 注意：这里返回的是模型的向量，因为在这种情况下用户提供的是单个模型而不是模型数组。
get_status(m::AbstractModel) = nothing
get_mapped_variables(m::AbstractModel) = Pair{Symbol,String}[]