"""
    AbstractNodeMapping

用于节点映射类型的抽象类型，例如单节点映射或多节点映射。
"""
abstract type AbstractNodeMapping end

"""
    SingleNodeMapping(scale)

用于单节点映射的类型，例如 `[:soil_water_content => "Soil",]`。注意 "Soil" 是以标量形式给出，
这意味着 `:soil_water_content` 将会是从植物图中特定的 "Soil" 节点取得的一个标量值。
"""
struct SingleNodeMapping <: AbstractNodeMapping
    scale::String
end

"""
    SelfNodeMapping()

自节点映射类型，即节点映射到其自身。
用于标记将会被其他模型以标量值引用的变量。可出现于两种情况：
    - 该变量由其他层级计算，因此需要作为输入存在于本层级（否则不会在本层级计算）
    - 该变量作为输入用于其他层级，但仅以单值（标量）引用，因此需要将其作为标量引用。
"""
struct SelfNodeMapping <: AbstractNodeMapping end

"""
    MultiNodeMapping(scale)

用于多节点映射的类型，例如 `[:carbon_assimilation => ["Leaf"],]`。注意 "Leaf" 以向量形式给出，
这意味着 `:carbon_assimilation` 将会是从植物图中每个 "Leaf" 取得的值的向量。
"""
struct MultiNodeMapping <: AbstractNodeMapping
    scale::Vector{String}
end

MultiNodeMapping(scale::String) = MultiNodeMapping([scale])

"""
    MappedVar(source_organ, variable, source_variable, source_default)

映射到其他层级的变量。

# 参数

- `source_organ`: 映射所针对的器官（或多个器官）
- `variable`: 被映射的变量名
- `source_variable`: 来源器官中的变量名（实际计算该变量的变量名）
- `source_default`: 变量的默认值

# 示例

```jldoctest
julia> using PlantSimEngine
```

```jldoctest
julia> PlantSimEngine.MappedVar(PlantSimEngine.SingleNodeMapping("Leaf"), :carbon_assimilation, :carbon_assimilation, 1.0)
PlantSimEngine.MappedVar{PlantSimEngine.SingleNodeMapping, Symbol, Symbol, Float64}(PlantSimEngine.SingleNodeMapping("Leaf"), :carbon_assimilation, :carbon_assimilation, 1.0)
```
"""
struct MappedVar{O<:AbstractNodeMapping,V1<:Union{Symbol,PreviousTimeStep},V2<:Union{S,Vector{S}} where {S<:Symbol},T}
    source_organ::O
    variable::V1
    source_variable::V2
    source_default::T
end

mapped_variable(m::MappedVar) = m.variable
source_organs(m::MappedVar) = m.source_organ
source_organs(m::MappedVar{O,V1,V2,T}) where {O<:AbstractNodeMapping,V1,V2,T} = nothing
mapped_organ(m::MappedVar{O,V1,V2,T}) where {O,V1,V2,T} = source_organs(m).scale
mapped_organ(m::MappedVar{O,V1,V2,T}) where {O<:SelfNodeMapping,V1,V2,T} = nothing
mapped_organ_type(m::MappedVar{O,V1,V2,T}) where {O<:AbstractNodeMapping,V1,V2,T} = O
source_variable(m::MappedVar) = m.source_variable
function source_variable(m::MappedVar{O,V1,V2,T}, organ) where {O<:SingleNodeMapping,V1,V2<:Symbol,T}
    @assert organ == mapped_organ(m) "Organ $organ not found in the mapping of the variable $(mapped_variable(m))."
    m.source_variable
end

function source_variable(m::MappedVar{O,V1,V2,T}, organ) where {O<:MultiNodeMapping,V1,V2<:Vector{Symbol},T}
    @assert organ in mapped_organ(m) "Organ $organ not found in the mapping of the variable $(mapped_variable(m))."
    m.source_variable[findfirst(o -> o == organ, mapped_organ(m))]
end

mapped_default(m::MappedVar) = m.source_default
mapped_default(m::MappedVar{O,V1,V2,T}, organ) where {O<:MultiNodeMapping,V1,V2<:Vector{Symbol},T} = m.source_default[findfirst(o -> o == organ, mapped_organ(m))]
mapped_default(m) = m # 对于不是 MappedVar 的变量，直接返回其自身