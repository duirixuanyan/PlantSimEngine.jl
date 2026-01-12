"""
    mapped_variables(mapping, dependency_graph=first(hard_dependencies(mapping; verbose=false)); verbose=false)

从依赖图中获取每种器官类型的变量，并为多尺度映射构建`MappedVar`。

# 参数

- `mapping::Dict{String,T}`: 模型与尺度的映射关系。
- `dependency_graph::DependencyGraph`: 第一阶依赖图，每个mapping中的模型为一个节点。
  但被识别为“硬依赖”的模型不会分配单独节点，而是作为子节点嵌套到其他模型下。
- `verbose::Bool`: 是否打印在mapping中寻找默认值时的堆栈跟踪。
"""
function mapped_variables(mapping, dependency_graph=first(hard_dependencies(mapping; verbose=false)); verbose=false)
    # 初始化一个字典，定义每种器官类型的多尺度变量
    mapped_vars = mapped_variables_no_outputs_from_other_scale(mapping, dependency_graph)

    # 添加那些仅从其他尺度输出、而在本尺度未计算的变量，并添加到organs_mapping中
    add_mapped_variables_with_outputs_as_inputs!(mapped_vars)
    # 例如：碳分配在植株尺度计算，但随后分配给每个器官（如叶片和节间），
    # 意味着叶片和节间等尺度应将碳分配作为输入变量。

    # 查找作为`SingleNodeMapping`输入到其他尺度的变量，并以自身为源在其源尺度声明为MappedVar。
    # 这样有助于我们在创建模板status对象时以引用方式声明。
    transform_single_node_mapped_variables_as_self_node_output!(mapped_vars)

    # 现在将inputs和outputs合并到一个字典中：
    mapped_vars_per_organ = merge(merge, mapped_vars[:inputs], mapped_vars[:outputs])
    #* 重要说明：merge顺序很重要，如果输入变量未初始化但在同一尺度被模型计算，
    #* 就无需初始化（已经计算），因此取模型输出作为默认值。
    #* 这对PreviousTimeStep以及跨尺度映射变量尤为重要，因为这类变量需要从输出尺度获得初始化。
    mapped_vars = default_variables_from_mapping(mapped_vars_per_organ, verbose)

    return mapped_vars
end

"""
    mapped_variables_no_outputs_from_other_scale(mapping, dependency_graph=first(hard_dependencies(mapping; verbose=false)))

从依赖图中获取每种器官类型的变量，但不包括那些来自其他尺度输出的变量。

# 参数

- `mapping::Dict{String,T}`: 模型与尺度的映射关系。
- `dependency_graph::DependencyGraph`: 第一阶依赖图，每个mapping中的模型为一个节点。但硬依赖模型不会分配独立节点，而作为子节点嵌套到其他模型下。

# 细节

本函数返回每个器官类型的（多尺度）输入输出变量字典。

注意本函数不包括来自其他尺度但在本尺度未计算的输出变量，
相关处理见`mapped_variables_with_outputs_as_inputs`。
 """
function mapped_variables_no_outputs_from_other_scale(mapping, dependency_graph=first(hard_dependencies(mapping; verbose=false)))
    nodes_insouts = Dict(organ => (inputs=ins, outputs=outs) for (organ, (soft_dep_graph, ins, outs)) in dependency_graph.roots)
    ins = Dict{String,NamedTuple}(organ => flatten_vars(vcat(values(ins)...)) for (organ, (ins, outs)) in nodes_insouts)
    outs = Dict{String,NamedTuple}(organ => flatten_vars(vcat(values(outs)...)) for (organ, (ins, outs)) in nodes_insouts)

    return Dict(:inputs => ins, :outputs => outs)
end

"""
    variables_outputs_from_other_scale(mapped_vars)

对于`mapped_vars`中的每个器官，查找那些仅为其他尺度输出、而本尺度未计算的变量。
该函数用于mapped_variables。
"""
function variables_outputs_from_other_scale(mapped_vars)
    vars_outputs_from_scales = Dict{String,Vector{Pair{Symbol,Any}}}()
    # 需要添加变量的尺度 => [(source_process, source_scale, variable), ...]
    for (organ, outs) in mapped_vars[:outputs] # organ = "Leaf" ; outs = mapped_vars[:outputs][organ]
        for (var, val) in pairs(outs) # var = :carbon_biomass ; val = outs[1]
            if isa(val, MappedVar)
                orgs = mapped_organ(val)
                orgs_iterable = isa(orgs, AbstractString) ? [orgs] : orgs

                filter!(o -> length(o) > 0, orgs_iterable)
                length(orgs_iterable) == 0 && continue # 当仅用PreviousTimeStep时可能出现

                for o in orgs_iterable
                    # MappedVar只能有一个默认值，因为它来自计算尺度（源尺度）
                    var_default_value = mapped_default(val)

                    if mapped_organ_type(val) == MultiNodeMapping
                        # 变量写入多个器官，默认值必须为向量
                        if isa(var_default_value, AbstractVector)
                            # 映射为器官向量，默认值也必须是向量
                            @assert length(var_default_value) == 1 "The variable `$(mapped_variable(val))` is an output variable computed by scale `$organ` and written to organs at scale `$(join(mapped_organ(val), ", "))`, " *
                                                                   "but the default value coming from `$organ` is not of length 1: $(var_default_value). " *
                                                                   "Make sure the model that computes this variable at scale `$organ` has a vector of values of length 1 as " *
                                                                   "default outputs for variable `$(mapped_variable(val))`."
                            var_default_value = var_default_value[1]
                        else
                            error(
                                "The variable `$(mapped_variable(val))` is an output variable computed by scale `$organ` and written to organs at scale `$(join(mapped_organ(val), ", "))`, " *
                                "but the default value coming from `$organ` is of length 1: $(var_default_value) instead of a vector. " *
                                "Make sure the model that computes this variable at scale `$organ` has a vector of values of length 1 as " *
                                "default outputs for variable `$(mapped_variable(val))`."
                            )
                        end
                    else
                        # 映射到单一器官时，默认值必须是标量
                        @assert !isa(var_default_value, AbstractVector) "The variable `$(mapped_variable(val))` is an output variable computed by scale `$organ` and written to organ at scale `$o`, " *
                                                                        "but the default value coming from `$organ` is a vector: $(var_default_value). " *
                                                                        "Make sure the model that computes this variable at scale `$organ` has a scalar value as " *
                                                                        "default outputs for variable `$(mapped_variable(val))` (*e.g.* $(var_default_value[1])), or update your mapping to map the organ as a vector: " *
                                                                        """`$(mapped_variable(val)) => ["$o"]`."""
                    end
                    # 构造MappedVar对象，将该变量声明为本尺度输入
                    # mapped_var = MappedVar(
                    #     SelfNodeMapping(), # 源器官本身，这样变量存在于自身status
                    #     source_variable(val, o),
                    #     source_variable(val, o),
                    #     var_default_value,
                    # )

                    if !haskey(vars_outputs_from_scales, o)
                        vars_outputs_from_scales[o] = [source_variable(val, o) => var_default_value]
                    else
                        push!(vars_outputs_from_scales[o], source_variable(val, o) => var_default_value)
                    end
                end
            end
        end
    end
    return vars_outputs_from_scales
end


"""
    add_mapped_variables_with_outputs_as_inputs!(mapped_vars)

将计算于一个尺度并写入到另一个尺度的变量添加进映射字典。
"""
function add_mapped_variables_with_outputs_as_inputs!(mapped_vars)
    # 获取由某尺度计算并写入其他尺度的变量（需将它们添加为“另一个”尺度的输入）
    outputs_written_by_other_scales = variables_outputs_from_other_scale(mapped_vars)

    for (organ, vars) in outputs_written_by_other_scales # organ = "" ; vars = outputs_written_by_other_scales[organ]
        if haskey(mapped_vars[:inputs], organ)
            mapped_vars[:inputs][organ] = merge(mapped_vars[:inputs][organ], NamedTuple(first(v) => last(v) for v in vars))
        else
            error("The scale $organ is mapped as an output scale from anothe scale, but is not declared in the mapping.")
        end
    end

    return mapped_vars
end


"""
    transform_single_node_mapped_variables_as_self_node_output!(mapped_vars)

查找作为`SingleNodeMapping`输入到其他尺度的变量，并以自身为源在源尺度声明为MappedVar。
这样有助于我们在创建模板status对象时以引用方式声明。

这些节点表现为`[:variable_name => "Plant"]`的写法（注意"Plant"为标量）。
"""
function transform_single_node_mapped_variables_as_self_node_output!(mapped_vars)
    for (organ, vars) in mapped_vars[:inputs] # 例：organ = "Leaf"; vars = mapped_vars[:inputs][organ]
        for (var, mapped_var) in pairs(vars) # 例：var = :carbon_biomass; mapped_var = vars[var]
            if isa(mapped_var, MappedVar{SingleNodeMapping})
                source_organ = mapped_organ(mapped_var)
                source_organ == "" && continue # 跳过映射到自身的变量（如[PreviousTimeStep(:variable_name)]或变量重命名）
                @assert source_organ != organ "Variable `$var` is mapped to its own scale in organ $organ. This is not allowed."

                @assert haskey(mapped_vars[:outputs], source_organ) "Scale $source_organ not found in the mapping, but mapped to the $organ scale."
                @assert haskey(mapped_vars[:outputs][source_organ], source_variable(mapped_var)) "The variable `$(source_variable(mapped_var))` is mapped from scale `$source_organ` to " *
                                                                                                 "scale `$organ`, but is not computed by any model at `$source_organ` scale."

                # 若该源变量已被别的尺度定义为`MappedVar{SelfNodeMapping}`，则跳过
                isa(mapped_vars[:outputs][source_organ][source_variable(mapped_var)], MappedVar{SelfNodeMapping}) && continue
                # 注意：当变量映射到多个尺度，如soil_water_content在土壤尺度计算，可在“Leaf”和“Internode”尺度映射。

                # 将变量转为指向自身的MappedVar：
                self_mapped_var = (;
                    source_variable(mapped_var) =>
                        MappedVar(
                            SelfNodeMapping(),
                            source_variable(mapped_var),
                            source_variable(mapped_var),
                            mapped_vars[:outputs][source_organ][source_variable(mapped_var)],
                        )
                )
                mapped_vars[:outputs][source_organ] = merge(mapped_vars[:outputs][source_organ], self_mapped_var)
                # 注意：merge会以RHS覆盖LHS同key值
            end
        end
    end

    return mapped_vars
end

"""
    get_multiscale_default_value(mapped_vars, val, mapping_stacktrace=[])

从映射关系获取变量的默认值。

# 参数

- `mapped_vars::Dict{String,Dict{Symbol,Any}}`: 每个器官的映射变量。
- `val::Any`: 需要获取默认值的变量。
- `mapping_stacktrace::Vector{Any}`: 在向上查找映射值时的堆栈追踪。
"""
function get_multiscale_default_value(mapped_vars, val, mapping_stacktrace=[], level=1)
    if isa(val, MappedVar) && !isa(val, MappedVar{SelfNodeMapping})
        # 若val为MappedVar，需查找其映射到的变量默认值
        # 除非自引用，此时直接返回
        level += 1
        # 从其映射的尺度（上级尺度）中查找默认值
        m_organ = mapped_organ(val)
        m_organ == "" && return mapped_default(val) # 跳过映射到自身的变量，例如[PreviousTimeStep(:variable_name)]或变量重命名

        if isa(m_organ, AbstractString)
            m_organ = [m_organ]
        end
        default_vals = []
        for o in m_organ # 例：o = "Leaf"
            haskey(mapped_vars[o], source_variable(val, o)) || error("Variable `$(source_variable(val, o))` is mapped from scale `$o` to another scale, but is not computed by any model at `$o` scale.")
            upper_value = mapped_vars[o][source_variable(val, o)]
            push!(mapping_stacktrace, (mapped_organ=o, mapped_variable=source_variable(val, o), mapped_value=mapped_default(upper_value), level=level))
            # 递归查找，直到默认值不是MappedVar
            push!(default_vals, get_multiscale_default_value(mapped_vars, upper_value, mapping_stacktrace, level))
        end

        default_vals = unique(default_vals)
        if length(default_vals) == 1
            return default_vals[1]
        else
            error(
                "The variable `$(mapped_variable(val))` is mapped to several scales: $(m_organ), but the default values from the models that compute ",
                "this variable at these scales is different: $(default_vals). Please make sure that the default values are the same for variable `$(mapped_variable(val))`.",
            )
        end
    elseif isa(val, MappedVar{SelfNodeMapping})
        return mapped_default(val)
    else
        return val
    end
end

"""
    default_variables_from_mapping(mapped_vars, verbose=true)

递归从映射关系中查找原始映射值，获取映射变量的默认值。

# 参数

- `mapped_vars::Dict{String,Dict{Symbol,Any}}`: 每个器官的映射变量。
- `verbose::Bool`: 是否打印在mapping中查找默认值的堆栈追踪。
"""
function default_variables_from_mapping(mapped_vars, verbose=true)
    mapped_vars_mutable = Dict{String,Dict{Symbol,Any}}(k => Dict(pairs(v)) for (k, v) in mapped_vars)
    for (organ, vars) in mapped_vars # organ = "Leaf"; vars = mapped_vars[organ]
        for (var, val) in pairs(vars) # var = :carbon_biomass; val = getproperty(vars,var)
            if isa(val, MappedVar) && !isa(val, MappedVar{SelfNodeMapping}) && mapped_organ(val) != ""
                mapping_stacktrace = Any[(mapped_organ=organ, mapped_variable=var, mapped_value=mapped_default(mapped_vars[organ][var]), level=1)]
                default_value = get_multiscale_default_value(mapped_vars, val, mapping_stacktrace)
                mapped_vars_mutable[organ][var] = MappedVar(source_organs(val), mapped_variable(val), source_variable(val), default_value)
                if verbose
                    @info """Default value for $(var) in $(organ) is taken from a mapping, here is the stacktrace: """ maxlog = 1

                    @info Term.Tables.Table(Tables.matrix(reverse(mapping_stacktrace)); header=["Scale", "Variable name", "Default value", "Level"])

                    @info """The stacktrace shows the step-by-step search for the default value, the last row is the value starting from the organ itself,
                    and going up to the upper-most model in the dependency graph (first row). The `level` column indicates the level of the search,
                    with 1 being the upper-most model in the dependency graph. The default value is the value found in the first row of the stacktrace,
                    or the unique value between common levels.
                    """ maxlog = 1
                end
            end
        end
    end
    return mapped_vars_mutable
end


"""
    convert_reference_values!(mapped_vars::Dict{String,Dict{Symbol,Any}})

将`MappedVar{SelfNodeMapping}`或`MappedVar{SingleNodeMapping}`变量转为参考同一变量值的RefValue；
将`MappedVar{MultiNodeMapping}`转为RefVector，引用源器官的变量值。
"""
function convert_reference_values!(mapped_vars::Dict{String,Dict{Symbol,Any}})
    # 对即将成为RefValue的变量，即在不同尺度下引用共同变量的值，首先需要在dict_mapped_vars字典中
    # 建立通用引用，每次用到时引用这里的值。实质上用RefValue替换掉MappedVar{SelfNodeMapping}和MappedVar{SingleNodeMapping}。
    dict_mapped_vars = Dict{Pair,Any}()

    # 第一遍：将MappedVar{SelfNodeMapping}和MappedVar{SingleNodeMapping}转为RefValue
    for (organ, vars) in mapped_vars # 例：organ = "Plant"; vars = mapped_vars[organ]
        for (k, v) in vars # 例：k = :aPPFD_larger_scale; v = vars[k]
            if isa(v, MappedVar{SelfNodeMapping}) || isa(v, MappedVar{SingleNodeMapping})
                mapped_org = isa(v, MappedVar{SelfNodeMapping}) ? organ : mapped_organ(v)
                mapped_org == "" && continue
                key = mapped_org => source_variable(v)

                # 首次遇到该变量的MappedVar，则在dict_mapped_vars中创建其值
                if !haskey(dict_mapped_vars, key)
                    push!(dict_mapped_vars, key => Ref(mapped_default(vars[k])))
                end

                # 对该变量，用dict_mapped_vars中的RefValue替换MappedVar
                vars[k] = dict_mapped_vars[key]
            end
        end
    end

    # 第二遍：将MappedVar{MultiNodeMapping}转换为RefVector
    for (organ, vars) in mapped_vars # 例：organ = "Plant"; vars = mapped_vars[organ]
        for (k, v) in vars # 例：k = :carbon_allocation; v = vars[k]
            if isa(v, MappedVar{MultiNodeMapping})
                # 创建目标器官的RefVector
                orgs_defaults = [mapped_vars[org][source_variable(v, org)] for org in mapped_organ(v)] |> unique

                if eltype(orgs_defaults) <: Ref
                    orgs_defaults = [org[] for org in orgs_defaults] |> unique
                end

                if length(orgs_defaults) > 1
                    error(
                        "In organ $organ, the variable `$(mapped_variable(v))` is mapped to several scales: $(mapped_organ(v)), but the default values from the models that compute ",
                        "this variable at these scales are different: $(orgs_defaults) (note that `type_promotion` has been applied). ",
                        "Please make sure that the default values are the same for variable `$(mapped_variable(v))`."
                    )
                end
                vars[k] = RefVector{eltype(orgs_defaults)}()
            end
        end
    end

    # 第三遍：将同尺度下重命名的变量获得同一引用
    for (organ, vars) in mapped_vars # 例：organ = "Plant"; vars = mapped_vars[organ]
        for (k, v) in vars # 例：k = :carbon_allocation; v = vars[k]
            if isa(v, MappedVar) && mapped_organ(v) == ""
                mapped_var = mapped_variable(v)
                isa(mapped_var, PreviousTimeStep) && (mapped_var = mapped_var.variable)
                if mapped_var == source_variable(v)
                    # 当仅有[PreviousTimeStep(:variable_name)]映射时
                    vars[k] = mapped_default(vars[k])
                else
                    # 若在同一尺度下重命名变量，则引用原始变量。采用PerStatusRef确保每个status拥有独立引用（引用不会被不同status共享）
                    vars[k] = RefVariable(source_variable(v))
                end
            end
        end
    end
    return mapped_vars
end