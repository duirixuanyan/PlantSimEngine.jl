"""
    reverse_mapping(mapping::Dict{String,Tuple{Any,Vararg{Any}}}; all=true)
    reverse_mapping(mapped_vars::Dict{String,Dict{Symbol,Any}})

获取模型映射字典的反向映射，即，被映射到其他尺度的变量，换句话说，
从给定尺度向其他尺度传递了哪些变量。
这可以用于，例如，了解哪些尺度需要把数值赋给其他尺度。

# 参数

- `mapping::Dict{String,Any}`: 模型映射的字典。
- `all::Bool`: 是否获取所有被映射到其他尺度的变量，包括那些被映射为单一值的变量。

# 返回值

一个以器官（键）为主的字典，值为字典：源器官 => 一组变量对的字典。你可以这样理解输出结果：
“对于每个器官（源器官），它向哪个其他器官（目标器官）传递了自己的哪些变量。然后对于每个源器官，具体哪个变量
传递到了目标器官（对中的第一个符号），以及它在目标器官中被映射为哪个变量（对中的第二个符号）。”

# 示例

```jldoctest mylabel
julia> using PlantSimEngine
```

导入示例模型（可在包的 `examples` 文件夹，或 `Examples` 子模块中找到）： 

```jldoctest mylabel
julia> using PlantSimEngine.Examples;
```

```jldoctest mylabel
julia> mapping = Dict( \
            "Plant" => \
                MultiScaleModel( \
                    model=ToyCAllocationModel(), \
                    mapped_variables=[ \
                        :carbon_assimilation => ["Leaf"], \
                        :carbon_demand => ["Leaf", "Internode"], \
                        :carbon_allocation => ["Leaf", "Internode"] \
                    ], \
                ), \
            "Internode" => ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0), \
            "Leaf" => ( \
                MultiScaleModel( \
                    model=ToyAssimModel(), \
                    mapped_variables=[:soil_water_content => "Soil",], \
                ), \
                ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0), \
                Status(aPPFD=1300.0, TT=10.0), \
            ), \
            "Soil" => ( \
                ToySoilWaterModel(), \
            ), \
        );
```

注意我们在 `Leaf` 的 `ToyAssimModel` 的映射中提供了 "Soil"，而不是 ["Soil"] 。
这是因为预期在这里映射 `soil_water_content` 的只有一个土壤，因此允许
将该值作为单值获取，而不是一个值向量。

```jldoctest mylabel
julia> PlantSimEngine.reverse_mapping(mapping)
Dict{String, Dict{String, Dict{Symbol, Any}}} with 3 entries:
  "Soil"      => Dict("Leaf"=>Dict(:soil_water_content=>:soil_water_content))
  "Internode" => Dict("Plant"=>Dict(:carbon_allocation=>:carbon_allocation, :ca…
  "Leaf"      => Dict("Plant"=>Dict(:carbon_allocation=>:carbon_allocation, :ca…
```
"""
function reverse_mapping(mapping::Dict{String,T}; all=true) where {T<:Any}
    # 直接基于映射字典进行反向映射的方法（代码库中未使用）
    mapped_vars = mapped_variables(mapping, first(hard_dependencies(mapping; verbose=false)), verbose=false)
    reverse_mapping(mapped_vars, all=all)
end

function reverse_mapping(mapped_vars::Dict{String,Dict{Symbol,Any}}; all=true)
    reverse_multiscale_mapping = Dict{String,Dict{String,Dict{Symbol,Any}}}(org => Dict{String,Dict{Symbol,Any}}() for org in keys(mapped_vars))
    for (organ, vars) in mapped_vars # 例如: organ = "Plant"; vars = mapped_vars[organ]
        for (var, val) in vars # 例如: var = :Rm_organs; val = vars[var]
            if isa(val, MappedVar) && !isa(val, MappedVar{SelfNodeMapping}) && (all || !isa(val, MappedVar{SingleNodeMapping}))
                # 注：跳过 MappedVar{SelfNodeMapping}，因为它是特殊情况，变量映射到自身
                # 因此我们不希望将其加入反向映射。如果 all=false 也跳过 MappedVar{SingleNodeMapping}
                # 因为我们不希望把单值变量加入反向映射。

                mapped_orgs = mapped_organ(val)
                isnothing(mapped_orgs) && continue
                if mapped_orgs isa String
                    mapped_orgs = [mapped_orgs]
                end

                for mapped_o in mapped_orgs # 例如: mapped_o = "Leaf"
                    # if !haskey(reverse_multiscale_mapping, mapped_o)
                    #     reverse_multiscale_mapping[mapped_o] = Dict{Symbol,Vector{MappedVar}}()
                    # end
                    if !haskey(reverse_multiscale_mapping[mapped_o], organ)
                        reverse_multiscale_mapping[mapped_o][organ] = Dict{Symbol,Any}(source_variable(val, mapped_o) => mapped_variable(val))
                    end
                    push!(reverse_multiscale_mapping[mapped_o][organ], source_variable(val, mapped_o) => mapped_variable(val))
                end
            end
        end
    end
    filter!(x -> length(last(x)) > 0, reverse_multiscale_mapping)
end