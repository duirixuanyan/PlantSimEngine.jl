"""
    hard_dependencies(models; verbose::Bool=true)
    hard_dependencies(mapping::Dict{String,T}; verbose::Bool=true)

计算模型之间的硬依赖关系。
"""
function hard_dependencies(models; scale="", verbose::Bool=true)
    dep_graph = initialise_all_as_hard_dependency_node(models, scale)
    dep_not_found = Dict{Symbol,Any}()
    for (process, i) in pairs(models) # 针对模型列表中的每个模型进行遍历。process=:state; i=pairs(models)[process]
        level_1_dep = dep(i) # 获取模型依赖关系所需的类型
        length(level_1_dep) == 0 && continue # 如果没有依赖关系则跳过本次循环
        dep_graph[process].dependency = level_1_dep
        for (p, depend) in pairs(level_1_dep) # 针对模型i的每个依赖项。p=:leaf_rank; depend=pairs(level_1_dep)[p]
            # 依赖项可以是多尺度的，例如 `leaf_area=AbstractLeaf_AreaModel => [m.leaf_symbol],`
            # 这意味着我们应该在另一个尺度中搜索该模型。这一步不会在这里进行，而是在下面另一个`hard_dependencies`方法被调用后完成。
            if isa(depend, Pair) 
                if scale != ""
                    # 如果是多尺度依赖，则跳过该硬依赖项，此情形会在后续处理
                    push!(dep_not_found, p => (parent_process=process, type=first(depend), scales=last(depend)))
                    continue
                else
                    # 如果不是多尺度设置（例如ModelList），理论上不应该出现多尺度模型。
                    # 但这里依然允许并给出警告，然后继续在当前模型列表中寻找依赖项。
                    verbose && @warn "Model $i has a multiscale hard dependency on $(first(depend)): $depend. Trying to find the model in this scale instead."
                    depend = first(depend)
                end
            end

            if hasproperty(models, p)
                if typeof(getfield(models, p)) <: depend
                    parent_dep = dep_graph[process]
                    push!(parent_dep.children, dep_graph[p])
                    for child in parent_dep.children
                        child.parent = parent_dep
                    end
                else
                    if verbose
                        @info string(
                            "Model ", typeof(i).name.name, " from process ", process,
                            scale == "" ? "" : " at scale $scale",
                            " needs a model that is a subtype of ", depend, " in process ",
                            p
                        )
                    end

                    push!(dep_not_found, p => depend)

                    push!(
                        dep_graph[process].missing_dependency,
                        findfirst(x -> x == p, keys(level_1_dep))
                    ) # 缺失依赖的索引
                    # 注意：可以通过 dep_graph[process].dependency[dep_graph[process].missing_dependency] 获取缺失依赖
                end
            else
                if verbose
                    @info string(
                        "Model ", typeof(i).name.name, " from process ", process,
                        scale == "" ? "" : " at scale $scale",
                        " needs a model that is a subtype of ", depend, " in process ",
                        p, ", but the process is not parameterized in the ModelList."
                    )
                end
                push!(dep_not_found, p => depend)

                push!(
                    dep_graph[process].missing_dependency,
                    findfirst(x -> x == p, keys(level_1_dep))
                ) # 缺失依赖的索引
                # 注意：可以通过 dep_graph[process].dependency[dep_graph[process].missing_dependency] 获取缺失依赖
            end
        end
    end

    roots = [AbstractTrees.getroot(i) for i in values(dep_graph)]
    # 只保留没有共同根节点的图，即移除为更大依赖图一部分的图
    unique_roots = Dict{Symbol,HardDependencyNode}()
    for (p, m) in dep_graph
        if m in roots
            push!(unique_roots, p => m)
        end
    end

    return DependencyGraph(unique_roots, dep_not_found)
end

"""
    initialise_all_as_hard_dependency_node(models)

针对一组模型，为每个模型初始化一个硬依赖节点，
并返回`:process => HardDependencyNode`组成的字典。
"""
function initialise_all_as_hard_dependency_node(models, scale)
    dep_graph = Dict(
        p => HardDependencyNode(
            i,
            p,
            NamedTuple(),
            Int[],
            scale,
            inputs_(i),
            outputs_(i),
            nothing,
            HardDependencyNode[]
        ) for (p, i) in pairs(models)
    )

    return dep_graph
end


# 当使用映射（多尺度）时，返回软依赖集合（将硬依赖添加为它们的子节点）：
function hard_dependencies(mapping::Dict{String,T}; verbose::Bool=true) where {T}
    full_vars_mapping = Dict(first(mod) => Dict(get_mapped_variables(last(mod))) for mod in mapping)
    soft_dep_graphs = Dict{String,Any}()
    not_found = Dict{Symbol,DataType}()

    mods = Dict(organ => parse_models(get_models(model)) for (organ, model) in mapping)

    # 对于每个尺度，将硬依赖模型挂于其父模型下
    # 注意：此时是单尺度（每个尺度独立计算）
    # 由于硬依赖模型被作为子节点插入软依赖图，不再被其他地方引用
    # 很难在需要时追踪它们，必须遍历整个图
    # 因此初始化期间维护它们，直到不再需要
    hard_dependency_dict = Dict{Pair{Symbol, String}, HardDependencyNode}()
    
    hard_deps = Dict(organ => hard_dependencies(mods_scale, scale=organ, verbose=false) for (organ, mods_scale) in mods)

    # 计算所有硬依赖“根节点”的输入和输出，使得接管其他模型的根节点拥有自身及其硬依赖节点的输入（或输出）合集。
    #* 注意在计算多尺度硬依赖前处理此步，因为硬依赖模型的输入/输出应保持在其自身尺度
    #* 硬依赖模型的变量未必出现在其自身尺度，这将在软依赖处理中处理
    inputs_process = Dict{String,Dict{Symbol,Vector}}()
    outputs_process = Dict{String,Dict{Symbol,Vector}}()
    for (organ, model) in mapping
        # 获取用户指定状态（用于设置映射中变量的默认值）
        st_scale_user = get_status(model)
        if isnothing(st_scale_user)
            st_scale_user = NamedTuple()
        else
            st_scale_user = NamedTuple(st_scale_user)
        end

        status_scale = Dict{Symbol,Vector{Pair{Symbol,NamedTuple}}}()
        for (procname, node) in hard_deps[organ].roots # procname = :leaf_surface ; node = hard_deps.roots[procname]
            var = Pair{Symbol,NamedTuple}[]
            traverse_dependency_graph!(node, x -> variables_multiscale(x, organ, full_vars_mapping, st_scale_user), var)
            push!(status_scale, procname => var)
        end

        inputs_process[organ] = Dict(key => [j.first => j.second.inputs for j in val] for (key, val) in status_scale)
        outputs_process[organ] = Dict(key => [j.first => j.second.outputs for j in val] for (key, val) in status_scale)
    end

    # 若某些硬依赖模型未在当前尺度被找到，尝试在其它尺度中查找
    for (organ, model) in mapping
        # organ = "Plant"; model = mapping[organ]
        # 过滤出定义为多尺度（带有NamedTuple信息）的硬依赖
        multiscale_hard_dep = filter(x -> isa(last(x), NamedTuple), hard_deps[organ].not_found)
        for (p, (parent_process, model_type, scales)) in multiscale_hard_dep
            # 调试: p = :initiation_age; parent_process, model_type, scales = multiscale_hard_dep[p]
            parent_node = get_model_nodes(hard_deps[organ], parent_process)
            if length(parent_node) == 0
                continue
            end
            parent_node = only(parent_node)
            # 父节点就是需要查找硬依赖的节点
            is_found = Ref(false) # 标志位，指示是否在其它尺度找到目标模型
            for s in scales # s="Phytomer"
                dep_node_model = filter(x -> x.scale == s, get_model_nodes(hard_deps[s], p))
                # 注意：这里应用过滤，是因为图会动态修改，且有时
                # 已经计算过多尺度硬依赖，此处也会展现，
                # 因此只保留声明于目标尺度的模型。

                if length(dep_node_model) > 0
                    is_found[] = true
                else
                    error("Model `$(typeof(parent_node.value))` from scale $organ requires a model of type `$model_type` at scale $s as a hard dependency, but no model was found for this process.")
                end
                dep_node_model = only(dep_node_model)

                if !isa(dep_node_model.value, model_type)
                    error("Model `$(typeof(parent_node.value))` from scale $organ requires a model of type `$model_type` at scale $s as a hard dependency, but the model found for this process is of type $(typeof(dep_node_model.value)).")
                end

                # 基于原有依赖节点生成新节点
               new_node = HardDependencyNode(
                    dep_node_model.value,
                    dep_node_model.process,
                    dep_node_model.dependency,
                    dep_node_model.missing_dependency,
                    dep_node_model.scale,
                    dep_node_model.inputs,
                    dep_node_model.outputs,
                    parent_node,
                    dep_node_model.children
                )
                
                # 将新生成子节点作为父节点的子节点（即硬依赖关系的持有者）
                push!(parent_node.children, new_node)

                # 之前已生成的嵌套硬依赖节点的祖先，其parent属性可能已指向过时的parent，
                # （以及目前处于过时状态的硬依赖节点），因此在自底向上遍历时其祖父节点可能被错误设置为nothing
                # 需要更新其parent至当前正确的新节点
                for ((hd_sym, hd_scale), hd_node) in hard_dependency_dict

                    if (hd_node.parent.process == p) && (hd_node.scale == hd_scale)
                        hd_node.parent = new_node
                    end
                end

                # 将新节点加入flat表，以便后续不直接遍历依赖图时也能便捷访问
                hard_dependency_dict[Pair(p, new_node.scale)] = new_node

                # 如果新节点原本是根节点，则将其从根节点列表删除
                if dep_node_model in values(hard_deps[s].roots)
                    delete!(hard_deps[s].roots, p) # 删除以process为key的节点
                end
            end
            # 如果在其它尺度至少找到一个目标，则从not_found字典中删除该模型
            is_found[] && delete!(hard_deps[organ].not_found, p)
        end
    end

    for (organ, model) in mapping
        soft_dep_graph = Dict(
            process_ => SoftDependencyNode(
                soft_dep_vars.value,
                process_, # 过程名称
                organ, # 尺度
                inputs_process[organ][process_], # 输入，可能为多尺度
                outputs_process[organ][process_], # 输出，可能为多尺度
                AbstractTrees.children(soft_dep_vars), # 硬依赖
                nothing,
                nothing,
                SoftDependencyNode[],
                [0] # 长度等于时间步数的零数组
            )
            for (process_, soft_dep_vars) in hard_deps[organ].roots # proc_ = :carbon_assimilation ; soft_dep_vars = hard_deps.roots[proc_]
        )

        # 将硬依赖节点的父节点指向新的SoftDependencyNode替换原有HardDependencyNode
        for (p, node) in soft_dep_graph
            for n in node.hard_dependency
                n.parent = node
            end
        end

        soft_dep_graphs[organ] = (soft_dep_graph=soft_dep_graph, inputs=inputs_process[organ], outputs=outputs_process[organ])
        not_found = merge(not_found, hard_deps[organ].not_found)
    end

    return (DependencyGraph(soft_dep_graphs, not_found), hard_dependency_dict)
end