"""
    get_models(m)

获取模型映射字典中的模型。

# 参数

- `m::Dict{String,Any}`: 一个模型映射的字典

返回一个模型的向量

# 示例

```jldoctest mylabel
julia> using PlantSimEngine;
```

导入示例模型（可以在本包的`examples`文件夹或`Examples`子模块中找到）:

```jldoctest mylabel
julia> using PlantSimEngine.Examples;
```

如果只提供一个MultiScaleModel，将获得其模型，结果为单元素向量：

```jldoctest mylabel
julia> models = MultiScaleModel( \
            model=ToyCAllocationModel(), \
            mapped_variables=[ \
                :carbon_assimilation => ["Leaf"], \
                :carbon_demand => ["Leaf", "Internode"], \
                :carbon_allocation => ["Leaf", "Internode"] \
            ], \
        );
```

```jldoctest mylabel
julia> PlantSimEngine.get_models(models)
1-element Vector{ToyCAllocationModel}:
 ToyCAllocationModel()
```

如果提供一个模型元组，将分别得到每个模型，返回为向量：

```jldoctest mylabel
julia> models2 = (  \
        MultiScaleModel( \
            model=ToyAssimModel(), \
            mapped_variables=[:soil_water_content => "Soil",], \
        ), \
        ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0), \
        Status(aPPFD=1300.0, TT=10.0), \
    );
```

注意此处在映射时提供的是"Soil"而不是["Soil"]，因为此处只需要一个值。

```jldoctest mylabel
julia> PlantSimEngine.get_models(models2)
2-element Vector{AbstractModel}:
 ToyAssimModel{Float64}(0.2)
 ToyCDemandModel{Float64}(10.0, 200.0)
```
"""
get_models(m) = [model_(i) for i in m if !isa(i, Status)]


# 同理，获取状态（如果提供）：

"""
    get_status(m)

获取模型映射字典中的状态。

# 参数

- `m::Dict{String,Any}`: 一个模型映射的字典

返回[`Status`](@ref)或`nothing`。

# 示例

参见[`get_models`](@ref)中的示例。
"""
function get_status(m)
    st = Status[i for i in m if isa(i, Status)]
    @assert length(st) <= 1 "Only one status can be provided for each organ type."
    length(st) == 0 && return nothing
    return first(st)
end

"""
    get_mapped_variables(m)

获取模型映射字典中的变量映射。

# 参数

- `m::Dict{String,Any}`: 一个模型映射的字典

返回由符号和字符串或字符串向量组成的Pair的向量。

# 示例

参见[`get_models`](@ref)中的示例。
"""
function get_mapped_variables(m)
    mod_mapping = [mapped_variables_(i) for i in m if isa(i, MultiScaleModel)]
    if length(mod_mapping) == 0
        return Pair{Symbol,String}[]
    end
    return reduce(vcat, mod_mapping) |> unique
end