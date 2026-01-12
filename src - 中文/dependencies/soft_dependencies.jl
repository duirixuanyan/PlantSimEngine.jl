"""
    soft_dependencies(d::DependencyGraph)

返回一个带有依赖图 `d` 中进程的软依赖的 [`DependencyGraph`](@ref)。
软依赖是指模型中没有显式定义，但可以通过进程的输入输出推断出来的依赖关系。

# 参数

- `d::DependencyGraph`: 硬依赖图。

# 示例

```julia
using PlantSimEngine

# 加载包中提供的示例模型：
using PlantSimEngine.Examples

# 创建模型列表：
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    process4=Process4Model(),
    process5=Process5Model(),
    process6=Process6Model(),
)

# 创建硬依赖图：
hard_dep = hard_dependencies(models.models, verbose=true)

# 获取软依赖图：
soft_dep = soft_dependencies(hard_dep)
```
"""
function soft_dependencies(d::DependencyGraph{Dict{Symbol,HardDependencyNode}}, nsteps=1)

    # 计算硬依赖图中每个节点的变量：
    d_vars = Dict{Symbol,Vector{Pair{Symbol,NamedTuple}}}()
    for (procname, node) in d.roots
        var = Pair{Symbol,NamedTuple}[]
        nodes_visited = Set{AbstractDependencyNode}()
        traverse_dependency_graph!(node, variables, var; node_visited=nodes_visited)
        push!(d_vars, procname => var)
    end

    # 注意：所有变量一次性收集，因为硬耦合节点之后作为一个进程处理（见下文）

    # 获取依赖图（硬依赖和软依赖）的所有节点：
    # all_nodes = Dict(traverse_dependency_graph(d, x -> x))

    # 计算依赖图中每个过程子图的输入和输出
    inputs_process = Dict{Symbol,Vector{Pair{Symbol,Tuple{Vararg{Symbol}}}}}(
        key => [j.first => keys(j.second.inputs) for j in val] for (key, val) in d_vars
    )
    outputs_process = Dict{Symbol,Vector{Pair{Symbol,Tuple{Vararg{Symbol}}}}}(
        key => [j.first => keys(j.second.outputs) for j in val] for (key, val) in d_vars
    )

    soft_dep_graph = Dict(
        process_ => SoftDependencyNode(
            soft_dep_vars.value,
            process_, # 进程名称
            "",
            inputs_(soft_dep_vars.value),
            outputs_(soft_dep_vars.value),
            AbstractTrees.children(soft_dep_vars), # 硬依赖
            nothing,
            nothing,
            SoftDependencyNode[],
            fill(0, nsteps)
        )
        for (process_, soft_dep_vars) in d.roots
    )

    independant_process_root = Dict{Symbol,SoftDependencyNode}()
    for (proc, i) in soft_dep_graph
        # proc = :process3; i = soft_dep_graph[proc]
        # 查找该进程是否有软依赖：
        soft_deps = search_inputs_in_output(proc, inputs_process, outputs_process)

        # 从软依赖中移除硬依赖
        soft_deps_not_hard = drop_process(soft_deps, [hd.process for hd in i.hard_dependency])
        # 注意：如果一个节点已经是该节点的硬依赖，则不能成为软依赖

        if length(soft_deps_not_hard) == 0 && i.process in keys(d.roots)
            # 如果该进程没有软依赖，则它是独立的（为根节点）
            # 注意仅当该进程同时也是硬依赖图的根节点时才算独立
            independant_process_root[proc] = i
        else
            # 如果该进程有软依赖，则它不是独立的
            # 需要将其父节点加入并将自己加为子节点
            for (parent_soft_dep, soft_dep_vars) in pairs(soft_deps_not_hard)
                # parent_soft_dep = :process5; soft_dep_vars = soft_deps[parent_soft_dep]

                # 防止循环依赖
                if parent_soft_dep == proc
                    error("Cyclic model dependency detected for process $proc")
                end

                # 防止循环依赖：如果父节点已经依赖当前节点：
                if soft_dep_graph[parent_soft_dep].parent !== nothing && i in soft_dep_graph[parent_soft_dep].parent
                    error(
                        "Cyclic dependency detected for process $proc:",
                        " $proc depends on $parent_soft_dep, which depends on $proc.",
                        " This is not allowed, but is possible via a hard dependency."
                    )
                end

                # 防止循环依赖：如果当前节点已将父节点作为子节点：
                if i.children !== nothing && soft_dep_graph[parent_soft_dep] in i.children
                    error(
                        "Cyclic dependency detected for process $proc:",
                        " $proc depends on $parent_soft_dep, which depends on $proc.",
                        " This is not allowed, but is possible via a hard dependency."
                    )
                end

                # 将当前节点加为其依赖节点的子节点
                push!(soft_dep_graph[parent_soft_dep].children, i)

                # 把依赖的父节点加为当前节点的父节点
                if i.parent === nothing
                    # 如果节点还没有父节点，则初始化为Vector
                    i.parent = [soft_dep_graph[parent_soft_dep]]
                else
                    push!(i.parent, soft_dep_graph[parent_soft_dep])
                end

                # 把父节点的软依赖（变量）赋值给当前节点
                i.parent_vars = soft_deps
            end
        end
    end

    return DependencyGraph(independant_process_root, d.not_found)
end

# 多层级映射用
function soft_dependencies_multiscale(soft_dep_graphs_roots::DependencyGraph{Dict{String,Any}}, reverse_multiscale_mapping, hard_dep_dict::Dict{Pair{Symbol,String},HardDependencyNode})
    
    independant_process_root = Dict{Pair{String,Symbol},SoftDependencyNode}()
    for (organ, (soft_dep_graph, ins, outs)) in soft_dep_graphs_roots.roots # 例如 organ = "Plant"; soft_dep_graph, ins, outs = soft_dep_graphs_roots.roots[organ]
        for (proc, i) in soft_dep_graph
            # proc = :leaf_surface; i = soft_dep_graph[proc]
            # 查找该进程是否有软依赖：
            soft_deps = search_inputs_in_output(proc, ins, outs)

            # 从软依赖中移除硬依赖
            soft_deps_not_hard = drop_process(soft_deps, [hd.process for hd in i.hard_dependency])

            hard_dependencies_from_other_scale = [hd for hd in i.hard_dependency if hd.scale != i.scale]

            # 注意：如果一个节点已经是该节点的硬依赖，则不能成为软依赖

            # 检查进程在其他层级下是否有软依赖：
            soft_deps_multiscale = search_inputs_in_multiscale_output(proc, organ, ins, soft_dep_graphs_roots.roots, reverse_multiscale_mapping, hard_dependencies_from_other_scale)
            # 示例输出: "Soil" => Dict(:soil_water=>[:soil_water_content])，表示 :soil_water_content 由 "Soil" 层级下的 :soil_water 过程计算

            if length(soft_deps_not_hard) == 0 && i.process in keys(soft_dep_graph) && length(soft_deps_multiscale) == 0
                # 如果该进程没有软依赖（多尺度依赖），则为独立节点（根节点）
                # 注意仅当该进程也是硬依赖图的根节点时才算独立
                independant_process_root[organ=>proc] = i
            else
                # 如果该进程有本层级软依赖，则加上它：
                if length(soft_deps_not_hard) > 0
                    # 存在软依赖，则不是独立的
                    # 需要将其父节点加入并将自己加为子节点
                    for (parent_soft_dep, soft_dep_vars) in pairs(soft_deps_not_hard)

                        # 若父节点当前没有注册为软依赖，很可能是内部硬依赖，需要指向其主节点
                        if (!haskey(soft_dep_graph, parent_soft_dep))

                            roots_at_given_scale = soft_dep_graphs_roots.roots[i.scale][:soft_dep_graph]
                            if !(parent_soft_dep in keys(roots_at_given_scale))
                                master_node = ()
                                for ((hd_key, hd_scale), hd) in hard_dep_dict
                                    if parent_soft_dep == hd_key
                                        master_node = hd
                                        depth = 0
                                        # 更优雅地防止循环或无限循环需要更好的实现
                                        while !isa(master_node, SoftDependencyNode) && depth < 50
                                            master_node.parent === nothing && error("Finalised hard dependency has no parent")
                                            master_node = master_node.parent
                                            depth += 1
                                        end

                                        break
                                    end
                                end
                                master_node == () && error("Parent is not located in hard deps, nor in roots, which should be the case when initalizing soft dependencies")
                            end
                            # 注意：此处主节点可能需要向上传递到模型的祖先硬依赖节点
                            parent_node = soft_dep_graphs_roots.roots[master_node.scale][:soft_dep_graph][master_node.process]
                        else
                            parent_node = soft_dep_graph[parent_soft_dep]
                        end



                        # 防止循环依赖
                        if parent_soft_dep == proc
                            error("Cyclic model dependency detected for process $proc from organ $organ.")
                        end

                        # 防止循环依赖：如果父节点已经依赖当前节点：
                        if parent_node.parent !== nothing && i in parent_node.parent
                            error(
                                "Cyclic dependency detected for process $proc from organ $organ:",
                                " $proc depends on $parent_soft_dep, which depends on $proc.",
                                " This is not allowed, but is possible via a hard dependency."
                            )
                        end

                        # 防止循环依赖：如果当前节点已将父节点作为子节点：
                        if i.children !== nothing && parent_node in i.children
                            error(
                                "Cyclic dependency detected for process $proc from organ $organ:",
                                " $proc depends on $parent_soft_dep, which depends on $proc.",
                                " This is not allowed, but is possible via a hard dependency."
                            )
                        end

                        i in parent_node.children && error("Cyclic dependency detected for process $proc from organ $organ.")

                        # 将当前节点加为其依赖节点的子节点
                        push!(parent_node.children, i)

                        # 把依赖的父节点加为当前节点的父节点
                        if i.parent === nothing
                            # 如果节点还没有父节点，则初始化为Vector
                            i.parent = [parent_node]
                        else
                            parent_node in i.parent && error("Cyclic dependency detected for process $proc from organ $organ.")
                            push!(i.parent, parent_node)
                        end

                        # 把父节点的软依赖（变量）赋值给当前节点
                        i.parent_vars = soft_deps
                    end
                end

                # 如果节点在其他层级下有软依赖，将其作为另一层级的子节点（并作为父节点）：
                if length(soft_deps_multiscale) > 0
                    for org in keys(soft_deps_multiscale)
                        for (parent_soft_dep, soft_dep_vars) in soft_deps_multiscale[org]

                            # 如果节点对嵌套硬依赖节点有软依赖，应该指向该硬依赖的主节点而不是内部节点
                            # 该检测主要处理属于硬依赖、而不在根的情况

                            roots_at_given_scale = soft_dep_graphs_roots.roots[org][:soft_dep_graph]
                            if !(parent_soft_dep in keys(roots_at_given_scale))
                                master_node = ()
                                for ((hd_key, hd_scale), hd) in hard_dep_dict
                                    if parent_soft_dep == hd_key
                                        master_node = hd
                                        depth = 0
                                        # 更优雅地防止循环或无限循环需要更好的实现
                                        while !isa(master_node, SoftDependencyNode) && depth < 50
                                            master_node.parent === nothing && error("Finalised hard dependency has no parent")
                                            master_node = master_node.parent
                                            depth += 1
                                        end

                                        break
                                    end
                                end

                                master_node == () && error("Parent is not located in hard deps, nor in roots, which should be the case when initalizing soft dependencies")

                                # 注意：此处主节点可能需要向上传递到模型的祖先硬依赖节点
                                parent_node = soft_dep_graphs_roots.roots[master_node.scale][:soft_dep_graph][master_node.process]
                            else
                                parent_node = soft_dep_graphs_roots.roots[org][:soft_dep_graph][parent_soft_dep]
                            end

                            # 防止循环依赖：如果父节点已经依赖当前节点
                            if parent_node.parent !== nothing && any([i == p for p in parent_node.parent])
                                error(
                                    "Cyclic dependency detected for process $proc:",
                                    " $proc for organ $organ depends on $parent_soft_dep from organ $org, which depends on the first one",
                                    " This is not allowed, you may need to develop a new process that does the whole computation by itself."
                                )
                            end

                            # 防止循环依赖：如果当前节点已将父节点作为子节点
                            if i.children !== nothing && parent_node in i.children
                                error(
                                    "Cyclic dependency detected for process $proc:",
                                    " $proc for organ $organ depends on $parent_soft_dep from organ $org, which depends on the first one.",
                                    " This is not allowed, you may need to develop a new process that does the whole computation by itself."
                                )
                            end


                            if !(i in parent_node.children) # && error("Cyclic dependency detected for process $proc from organ $organ.")

                                # 将当前节点加为其依赖节点的子节点
                                push!(parent_node.children, i)
                            end
                            # 把依赖的父节点加为当前节点的父节点
                            if i.parent === nothing
                                # 如果节点还没有父节点，则初始化为Vector
                                i.parent = [parent_node]
                            else
                                if !(parent_node in i.parent) # && error("Cyclic dependency detected for process $proc from organ $organ.")
                                    push!(i.parent, parent_node)
                                end
                            end

                            # 把父节点的多尺度软依赖变量赋值给当前节点
                            i.parent_vars = NamedTuple(Symbol(k) => NamedTuple(v) for (k, v) in soft_deps_multiscale)
                        end
                    end
                end
            end
        end
    end

    return DependencyGraph(independant_process_root, soft_dep_graphs_roots.not_found)
end


"""
    drop_process(proc_vars, process)

返回将 `NamedTuple` `proc_vars` 中 process `process` 删除后的新 `NamedTuple`。

# 参数

- `proc_vars::NamedTuple`: 要删除进程的 `NamedTuple`。
- `process::Symbol`: 需要从 `NamedTuple` `proc_vars` 中删除的进程。

# 返回

删除了 process 后的 `NamedTuple`。

# 示例

```julia
julia> drop_process((a = 1, b = 2, c = 3), :b)
(a = 1, c = 3)

julia> drop_process((a = 1, b = 2, c = 3), (:a, :c))
(b = 2,)
```
"""
drop_process(proc_vars, process::Symbol) = Base.structdiff(proc_vars, NamedTuple{(process,)})
drop_process(proc_vars, process) = Base.structdiff(proc_vars, NamedTuple{(process...,)})

"""
    search_inputs_in_output(process, inputs, outputs)

返回依赖图 `d` 中进程的软依赖组成的字典。
软依赖是指模型中没有显式定义，但可以通过进程的输入输出推断出来的依赖关系。

# 参数

- `process::Symbol`: 需要查找软依赖的进程。
- `inputs::Dict{Symbol, Vector{Pair{Symbol}, Tuple{Symbol, Vararg{Symbol}}}}`: 一个 dict，进程对应其输入符号。
- `outputs::Dict{Symbol, Tuple{Symbol, Vararg{Symbol}}}`: 一个 dict，进程对应其输出符号。

# 细节

输入（输出同理）给出了每个进程的输入，按来源进程分类，来源可以是进程自身或硬依赖的其他进程。

# 返回

进程软依赖组成的字典。

# 示例

```julia
in_ = Dict(
    :process3 => [:process3=>(:var4, :var5), :process2=>(:var1, :var3), :process1=>(:var1, :var2)],
    :process4 => [:process4=>(:var0,)],
    :process6 => [:process6=>(:var7, :var9)],
    :process5 => [:process5=>(:var5, :var6)],
)

out_ = Dict(
    :process3 => Pair{Symbol}[:process3=>(:var4, :var6), :process2=>(:var4, :var5), :process1=>(:var3,)],
    :process4 => [:process4=>(:var1, :var2)],
    :process6 => [:process6=>(:var8,)],
    :process5 => [:process5=>(:var7,)],
)

search_inputs_in_output(:process3, in_, out_)
(process4 = (:var1, :var2),)
```
"""
function search_inputs_in_output(process, inputs, outputs)
    # proc, ins, outs
    # 获取节点的输入
    vars_input = flatten_vars(inputs[process])

    inputs_as_output_of_process = Dict()
    for (proc_output, pairs_vars_output) in outputs # 例如 proc_output = :carbon_biomass; pairs_vars_output = outs[proc_output]
        if process != proc_output
            vars_output = flatten_vars(pairs_vars_output)
            inputs_in_outputs = vars_in_variables(vars_input, vars_output)

            if any(inputs_in_outputs)
                ins_in_outs = [vars_input...][inputs_in_outputs]

                # 移除由上一时刻计算出的变量（用于打破循环依赖）：
                filter!(x -> !isa(x, MappedVar) || !isa(mapped_variable(x), PreviousTimeStep), ins_in_outs)

                # proc_input 的输入中位于 proc_output 输出中的变量
                length(ins_in_outs) > 0 && push!(inputs_as_output_of_process, proc_output => Tuple(ins_in_outs))
                # 注意：proc_output 是计算 proc_input 输入的过程
                # 这些输入由 `vars_input[inputs_in_outputs]` 给出
            end
        end
    end

    return NamedTuple(inputs_as_output_of_process)
end

function vars_in_variables(vars::T1, variables::T2) where {T1<:NamedTuple,T2<:NamedTuple}
    [i in keys(variables) for i in keys(vars)]
end

function vars_in_variables(vars, variables)
    [i in variables for i in vars]
end

"""
    search_inputs_in_multiscale_output(process, organ, inputs, soft_dep_graphs)

# 参数

- `process::Symbol`: 需要查找其它尺度下软依赖的进程。
- `organ::String`: 需要查找软依赖的器官（层级）。
- `inputs::Dict{Symbol, Vector{Pair{Symbol}, Tuple{Symbol, Vararg{Symbol}}}}`: 一个 dict，进程 => [:子进程 => (:var1, :var2)]。
- `soft_dep_graphs::Dict{String, ...}`: 一个 dict，器官 => (依赖子图, 输入, 输出)。
- `rev_mapping::Dict{Symbol, Symbol}`: 反向映射，映射变量 => 来源变量。
- 'hard_dependencies_from_other_scale' : 存储跨层级硬依赖的 HardDependencyNode 向量，便于不遍历整个图时访问

# 细节

输入（输出同理）给出了每个进程的输入，按来源进程分类，来源可以是进程自身或硬依赖的其他进程。

# 返回

每个进程在其他层级下在输出中找到的软依赖变量组成的字典，例如：
    
```julia
Dict{String, Dict{Symbol, Vector{Symbol}}} with 2 entries:
    "Internode" => Dict(:carbon_demand=>[:carbon_demand])
    "Leaf"      => Dict(:carbon_assimilation=>[:carbon_assimilation], :carbon_demand=>[:carbon_demand])
```

上述结果表示变量 `:carbon_demand` 由 "Internode" 层级下的 :carbon_demand 过程计算，变量 `:carbon_assimilation` 则由 "Leaf" 层级下的 :carbon_assimilation 过程计算。这些变量作为当前进程的输入。
"""
function search_inputs_in_multiscale_output(process, organ, inputs, soft_dep_graphs, rev_mapping, hard_dependencies_from_other_scale)
    # proc, organ, ins, soft_dep_graphs=soft_dep_graphs_roots.roots
    vars_input = flatten_vars(inputs[process])

    inputs_as_output_of_other_scale = Dict{String,Dict{Symbol,Vector{Symbol}}}()
    for (var, val) in pairs(vars_input) # 例如 var = :leaf_surfaces;val = vars_input[var]
        # 变量为多尺度变量
        if isa(val, MappedVar)
            var_organ = mapped_organ(val)
            var_organ == "" && continue # 若变量未映射到任何层级（如 [PreviousTimeStep(:var1)] 或 [:var => :new_var]），则跳过
            if !isa(var_organ, AbstractVector)
                # 若器官仅为单一值（如 "Soil" 而非 ["Soil"]），转成数组
                var_organ = [var_organ]
            end

            @assert all(var_o != organ for var_o in var_organ) "$var in process $process is set to be multiscale, but points to its own scale ($organ). This is not allowed."
            for org in var_organ # 例如 org = "Leaf"
                # 变量是多尺度变量
                haskey(soft_dep_graphs, org) || error("Scale $org not found in the mapping, but mapped to the $organ scale.")
                mapped_var = mapped_variable(val)
                isa(mapped_var, PreviousTimeStep) && continue # 不收集上时刻（防止循环依赖）

                # 避免收集来源于硬依赖的其它层级变量
                # 硬依赖内部已处理这些变量，若硬依赖有该变量则不作为软依赖收集
                # （仅需在软依赖节点下一层检测，硬依赖的内部依赖无需暴露变量）

                in_hard_dep::Bool = false
                hd_os_current_scale = filter(x -> x.scale == org, hard_dependencies_from_other_scale)
                for hd_os in hd_os_current_scale
                    hd_os_output_vars = [first(p) for p in pairs(hd_os.outputs)]
                    in_hard_dep |= length(filter(x -> x == var, hd_os_output_vars)) > 0
                end
                !in_hard_dep && add_input_as_output!(inputs_as_output_of_other_scale, soft_dep_graphs, org, source_variable(val, org), mapped_var)
            end
        elseif isa(val, UninitializedVar) && haskey(rev_mapping, organ)
            # 变量可能是其他层级写入的变量
            for (organ_source, proc_vars_dict) in rev_mapping[organ]
                if haskey(proc_vars_dict, var)
                    add_input_as_output!(inputs_as_output_of_other_scale, soft_dep_graphs, organ_source, var, proc_vars_dict[var])
                end
            end
        end
    end

    return inputs_as_output_of_other_scale
end


function add_input_as_output!(inputs_as_output_of_other_scale, soft_dep_graphs, organ_source, variable, value)
    for (proc_output, pairs_vars_output) in soft_dep_graphs[organ_source][:outputs] # 例如 proc_output = :maintenance_respiration; pairs_vars_output = soft_dep_graphs_roots.roots[organ_source][:outputs][proc_output]
        vars_output = flatten_vars(pairs_vars_output)

        # 判断变量是否在该层级的该进程输出中
        if variable in keys(vars_output)
            # 该变量在另外的层级找到了
            if haskey(inputs_as_output_of_other_scale, organ_source)
                if haskey(inputs_as_output_of_other_scale[organ_source], proc_output)
                    push!(inputs_as_output_of_other_scale[organ_source][proc_output], value)
                else
                    inputs_as_output_of_other_scale[organ_source][proc_output] = [value]
                end
            else
                inputs_as_output_of_other_scale[organ_source] = Dict(proc_output => [value])
            end
        end
    end
end
"""
    flatten_vars(vars)

返回 `vars` 字典中的变量集合。

# 参数

- `vars::Dict{Symbol, Tuple{Symbol, Vararg{Symbol}}}`: 进程到变量内容的字典。

# 返回

`vars` 字典中的变量集合。

# 示例

```julia
julia> flatten_vars(Dict(:process1 => (:var1, :var2), :process2 => (:var3, :var4)))
Set{Symbol} with 4 elements:
  :var4
  :var3
  :var2
  :var1
```

```julia
julia> flatten_vars([:process1 => (var1 = -Inf, var2 = -Inf), :process2 => (var3 = -Inf, var4 = -Inf)])
(var2 = -Inf, var4 = -Inf, var3 = -Inf, var1 = -Inf)
```
"""
function flatten_vars(vars)
    vars_input = Set()
    for (key, val) in vars
        flatten_vars(val, vars_input)
    end
    format_flatten((vars_input...,))
end

function flatten_vars(val::NamedTuple, vars_input::Set)
    for (k, j) in pairs(val)
        push!(vars_input, k => j)
    end
end

function flatten_vars(val::Tuple, vars_input::Set)
    for j in val
        push!(vars_input, j)
    end
end

format_flatten(vars::Tuple{Vararg{Pair}}) = NamedTuple(vars)
format_flatten(vars) = vars