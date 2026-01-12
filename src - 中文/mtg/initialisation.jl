"""
    init_statuses(mtg, mapping, dependency_graph=dep(mapping); type_promotion=nothing, verbose=true, check=true)
    
获取每个MTG节点的状态，按节点类型分组，预初始化，考虑多尺度变量。

# 参数

- `mtg`：植物图
- `mapping`：模型映射的字典
- `dependency_graph::DependencyGraph`：一级依赖图，其中每个模型在映射中被分配为一个节点。
  但是，识别为硬依赖的模型不会单独作为节点存在，而是作为子节点嵌套在其他模型下。
- `type_promotion`：用于变量的类型提升
- `verbose`：在编译映射时打印信息
- `check`：是否检查映射中的错误。此参数会传递给`init_node_status!`。

# 返回值

返回一个NamedTuple，内容包含按节点类型分的状态、按节点类型分的状态模板、被映射到其他尺度的变量字典、
需要被其它模型初始化或计算的变量字典，以及一个有已定义模型符号的节点向量：

`(;statuses, status_templates, reverse_multiscale_mapping, vars_need_init, nodes_with_models)`
"""
function init_statuses(mtg, mapping, dependency_graph; type_promotion=nothing, verbose=false, check=true)
    # 对每个尺度计算变量映射
    mapped_vars = mapped_variables(mapping, dependency_graph, verbose=verbose)

    # 按用户需求更新变量的类型
    convert_vars!(mapped_vars, type_promotion)

    # 计算反向多尺度依赖关系，即对每个尺度，哪个变量映射到了其它尺度
    reverse_multiscale_mapping = reverse_mapping(mapped_vars, all=false)
    # 注：这个用于向其它尺度的RefVector中添加该变量的节点值。
    # 注2：我们使用`all=false`选项仅获取映射到其他尺度的变量向量。
    # 注3：这一步要在`convert_reference_values!`之前完成，因为需要MappedVar{MultiNodeMapping}变量获取反向映射。

    # 将MappedVar{SelfNodeMapping}或MappedVar{SingleNodeMapping}转为RefValues，将MappedVar{MultiNodeMapping}转为RefVectors
    convert_reference_values!(mapped_vars)

    # 获取在输出结果中没有被其它模型初始化或计算的变量
    vars_need_init = Dict(org => filter(x -> isa(last(x), UninitializedVar), vars) |> keys for (org, vars) in mapped_vars) |>
                     filter(x -> length(last(x)) > 0)

    # 注：这些变量可能存在于MTG属性中，下面遍历MTG时会进行检查。

    # 遍历MTG，初始化与节点相关的状态
    statuses = Dict(i => Status[] for i in collect(keys(mapped_vars)))
    MultiScaleTreeGraph.traverse!(mtg) do node # 例如：node = MultiScaleTreeGraph.get_node(mtg, 5)
        init_node_status!(node, statuses, mapped_vars, reverse_multiscale_mapping, vars_need_init, type_promotion, check=check)
    end

    return (; statuses, mapped_vars, reverse_multiscale_mapping, vars_need_init)
end


"""
    init_node_status!(
        node, 
        statuses, 
        mapped_vars, 
        reverse_multiscale_mapping,
        vars_need_init=Dict{String,Any}(),
        type_promotion=nothing;
        check=true,
        attribute_name=:plantsimengine_status)
    )

初始化植物图节点的状态，考虑多尺度映射，并将状态添加到statuses字典中。

# 参数

- `node`：要初始化的节点
- `statuses`：按节点类型分的状态字典
- `mapped_vars`：每个节点类型的状态模板
- `reverse_multiscale_mapping`：被映射到其他尺度的变量
- `var_need_init`：没有被其它模型初始化或计算的变量
- `nodes_with_models`：有模型定义的节点
- `type_promotion`：变量类型提升
- `check`：是否检查映射中的错误（见Details）
- `attribute_name`：状态存储到节点中的属性名，默认为`:plantsimengine_status`

# 细节

大部分参数可以根据图和映射计算获得：
- `statuses`通过第一次初始化获得：`statuses = Dict(i => Status[] for i in nodes_with_models)`
- `mapped_vars`用`mapped_variables()`得到，见`init_statuses`中的代码
- `vars_need_init`通过`vars_need_init = Dict(org => filter(x -> isa(last(x), UninitializedVar), vars) |> keys for (org, vars) in mapped_vars) |> filter(x -> length(last(x)) > 0)` 计算获得

`check`参数表示是否检查变量初始化。在某些变量需要初始化（部分初始化映射）的情况下，会判断节点属性（按变量名）中是否可获取。如果`true`，当属性不存在时会报错，否则使用模型的默认值。
"""
function init_node_status!(node, statuses, mapped_vars, reverse_multiscale_mapping, vars_need_init=Dict{String,Any}(), type_promotion=nothing; check=true, attribute_name=:plantsimengine_status)
    # 检查该节点符号是否有定义模型，否则无需计算
    symbol(node) ∉ collect(keys(mapped_vars)) && return

    # 复制该节点的状态模板
    st_template = copy(mapped_vars[symbol(node)])

    # 向状态中添加对节点的引用，便于模型访问
    push!(st_template, :node => Ref(node))

    # 若有部分变量还未实例化，则尝试在MTG节点属性中查找，并填入status
    if haskey(vars_need_init, symbol(node)) && length(vars_need_init[symbol(node)]) > 0
        for var in vars_need_init[symbol(node)] # 例如：var = :carbon_biomass
            if !haskey(node, var)
                if !check
                    # 若不检查，则用模型的默认值（如果是UninitializedVar则取其默认值）
                    if isa(st_template[var], UninitializedVar)
                        st_template[var] = st_template[var].value
                    end
                    continue
                end
                error("Variable `$(var)` is not computed by any model, not initialised by the user in the status, and not found in the MTG at scale $(symbol(node)) (checked for MTG node $(node_id(node))).")
            end
            # 如有需要，对节点属性应用类型提升
            if isnothing(type_promotion)
                node_var = node[var]
            else
                node_var =
                    try
                        promoted_var_type = []
                        for (subtype, newtype) in type_promotion
                            if isa(node[var], subtype)
                                converted_var = convert(newtype, node[var])
                                @warn "Promoting `$(var)` value taken from MTG node $(node_id(node)) ($(symbol(node))) from $subtype to $newtype: $converted_var ($(typeof(converted_var)))" maxlog = 5
                                push!(promoted_var_type, converted_var)
                            end
                        end
                        length(promoted_var_type) > 0 ? promoted_var_type[1] : node[var]
                    catch e
                        error("Failed to convert variable `$(var)` in MTG node $(node_id(node)) ($(symbol(node))) from type `$(typeof(node[var]))` to type `$(eltype(st_template[var]))`: $(e)")
                    end
            end
            @assert typeof(node_var) == eltype(st_template[var]) string(
                "Initializing variable `$(var)` using MTG node $(node_id(node)) ($(symbol(node))): expected type $(eltype(st_template[var])), found $(typeof(node_var)). ",
                "Please check the type of the variable in the MTG, and make it a $(eltype(st_template[var])) by updating the model, or by using `type_promotion`."
            )
            st_template[var] = node_var
            # 注意：此变量是MTG中的值的拷贝，而不是引用
            # 因为无法引用Dict里的值。如果需要引用，用户可以在MTG中直接放RefValue，它会自动原样传递。
        end
    end

    # 从模板生成节点状态
    st = status_from_template(st_template)

    push!(statuses[symbol(node)], st)

    # 动态为映射到本尺度的他尺度变量实例化RefVectors
    # 即，为来自其它尺度的变量，向其RefVector中添加引用
    if haskey(reverse_multiscale_mapping, symbol(node))
        for (organ, vars) in reverse_multiscale_mapping[symbol(node)] # 例如：organ = "Leaf"; vars = reverse_multiscale_mapping[symbol(node)][organ]
            for (var_source, var_target_) in vars # 例如：var_source = :soil_water_content; var_target = vars[var_source]
                var_target = var_target_ isa PreviousTimeStep ? var_target_.variable : var_target_
                push!(mapped_vars[organ][var_target], refvalue(st, var_source))
            end
        end
    end


    # 最后，把status添加到节点属性里
    node[attribute_name] = st

    return st
end

"""
    status_from_template(d::Dict{Symbol,Any})

从变量和值的模板字典创建一个status。如果值本身是RefValue或RefVector，则直接使用，否则会自动转为Ref。

# 参数

- `d::Dict{Symbol,Any}`：变量和值的字典。

# 返回

- 一个[`Status`](@ref)。

# 示例

```jldoctest mylabel
julia> using PlantSimEngine
```

```jldoctest mylabel
julia> a, b = PlantSimEngine.status_from_template(Dict(:a => 1.0, :b => 2.0));
```

```jldoctest mylabel
julia> a
1.0
```

```jldoctest mylabel
julia> b
2.0
```
"""
function status_from_template(d::Dict{Symbol,T} where {T})
    # 对变量排序，PerStatusRef（用于重命名时引用status中相同变量的特殊引用类型）排在最后
    sorted_vars = Dict{Symbol,Any}(sort([pairs(d)...], by=v -> last(v) isa RefVariable ? 1 : 0))
    # 注意：PerStatusRef 用于在同一个 status 内重命名时引用其他变量。

    # 为变量及PerStatusRef创建最终的引用（PerStatusRef实际引用另一个变量的Ref）
    for (k, v) in sorted_vars
        if isa(v, RefVariable)
            sorted_vars[k] = sorted_vars[v.reference_variable]
        else
            sorted_vars[k] = ref_var(v)
        end
    end

    return Status(NamedTuple(sorted_vars))
end

"""
    ref_var(v)

为变量创建引用。如果变量已经是`Base.RefValue`，则直接返回，否则返回其副本的Ref，
如果是RefVector则返回其Ref。

# 示例

```jldoctest mylabel
julia> using PlantSimEngine;
```

```jldoctest mylabel
julia> PlantSimEngine.ref_var(1.0)
Base.RefValue{Float64}(1.0)
```

```jldoctest mylabel
julia> PlantSimEngine.ref_var([1.0])
Base.RefValue{Vector{Float64}}([1.0])
```

```jldoctest mylabel
julia> PlantSimEngine.ref_var(Base.RefValue(1.0))
Base.RefValue{Float64}(1.0)
```

```jldoctest mylabel
julia> PlantSimEngine.ref_var(Base.RefValue([1.0]))
Base.RefValue{Vector{Float64}}([1.0])
```

```jldoctest mylabel
julia> PlantSimEngine.ref_var(PlantSimEngine.RefVector([Ref(1.0), Ref(2.0), Ref(3.0)]))
Base.RefValue{PlantSimEngine.RefVector{Float64}}(RefVector{Float64}[1.0, 2.0, 3.0])
```
"""
ref_var(v) = Base.Ref(copy(v))
ref_var(v::T) where {T<:AbstractString} = Base.Ref(v) # 字符串没有copy方法，直接生成Ref
ref_var(v::T) where {T<:Base.RefValue} = v
ref_var(v::T) where {T<:RefVector} = Base.Ref(v)
ref_var(v::T) where {T<:RefVariable} = v
ref_var(v::UninitializedVar) = Base.Ref(copy(v.value))

"""
    init_simulation(mtg, mapping; nsteps=1, outputs=nothing, type_promotion=nothing, check=true, verbose=true)

初始化仿真环境，返回：

- mtg
- 各器官类型下每个节点的status，考虑多尺度变量
- 模型依赖图
- 模型字典 organ type => NamedTuple of process => model mapping
- 预分配的输出outputs

# 参数

- `mtg`：MTG
- `mapping::Dict{String,Any}`：模型映射字典
- `nsteps`：仿真步数
- `outputs`：仿真需要的动态输出项
- `type_promotion`：变量类型提升
- `check`：是否检查映射错误，会传递到`init_node_status!`
- `verbose`：关于映射错误的信息

# 细节

本函数首先为每个在mapping中拥有模型的器官类型计算status模板。
然后利用该模板初始化每个节点的status，兼顾用户自定义的初始化和多尺度mapping。
mapping用于对跨尺度定义的变量创建引用，从而保证当变量在其它尺度更新时自动同步。
目前支持两种多尺度变量类型：`RefVector`和`MappedVar`。
前者用于变量映射到一组节点，后者用于变量映射到单个节点。
用法为：只要用字符串即可表示单节点（如`=> "Leaf"`），用字符串数组表示多节点（如`=> ["Leaf"]`或`=> ["Leaf", "Internode"]`）。

本函数还会计算模型的依赖图，即根据模型间的输入输出关系，确定仿真调用顺序。
依赖图用于仿真运行时保证模型调用的合理顺序。

注意，如果变量既没有被模型计算，也没有在mapping初始化，会在MTG属性中查找其值。
该值是拷贝，而非对MTG属性的引用，因为无法引用Dict中的值。
如需引用特定变量，可以在MTG中直接用`Ref`，会被自动原样传递。
"""
function init_simulation(mtg, mapping; nsteps=1, outputs=nothing, type_promotion=nothing, check=true, verbose=false)

    # 确保在继续之前，用户已处理过status中的vector类型
    (organ_with_vector, no_vectors_found) = (check_statuses_contain_no_remaining_vectors(mapping))
    if !no_vectors_found
        @assert false "Error : Mapping status at $organ_with_vector level contains a vector. If this was intentional, call the function generate_models_from_status_vectors on your mapping before calling run!. And bear in mind this is not meant for production. If this wasn't intentional, then it's likely an issue on the mapping definition, or an unusual model."
    end

    soft_dep_graphs_roots, hard_dep_dict = hard_dependencies(mapping; verbose=false)

    # 获取每个节点的status，按节点类型分组，已初始化，多尺度变量已处理
    statuses, status_templates, reverse_multiscale_mapping, vars_need_init =
        init_statuses(mtg, mapping, soft_dep_graphs_roots; type_promotion=type_promotion, verbose=verbose, check=check)

    # 第一步，获得硬依赖关系图，并为每个硬依赖根节点创建SoftDependencyNodes。
    # 也就是，只取不是别人硬依赖的节点作为软依赖图的根节点。
    # 第二步，计算这些SoftDependencyNodes之间的软依赖关系。
    # 做法是，搜索每个过程的inputs来自其它过程的outputs（同尺度与跨尺度均可）。
    # 最后，没有软依赖的作为根节点，其余作为子节点。
    dep_graph = soft_dependencies_multiscale(soft_dep_graphs_roots, reverse_multiscale_mapping, hard_dep_dict)
    # 构建soft-dependency图过程中，已标识每个依赖节点的输入输出变量，并且如果是多尺度，会用MappedVar定义inputs。
    # 但outputs如果被其它尺度需要，也应多尺度定义。

    # 检查依赖图是否为无环图
    iscyclic, cycle_vec = is_graph_cyclic(dep_graph; warn=false)
    # 注：可在`soft_dependencies_multiscale`内部完成，但为保持函数简单和可复用，在此处单独处理。

    iscyclic && error("Cyclic dependency detected in the graph. Cycle: \n $(print_cycle(cycle_vec)) \n You can break the cycle using the `PreviousTimeStep` variable in the mapping.")
    # 第三步……

    # 检查mapping定义了但MTG中不存在的模型，发出提示信息
    if check && any(x -> length(last(x)) == 0, statuses)
        model_no_node = join(findall(x -> length(x) == 0, statuses), ", ")
        @info "Models given for $model_no_node, but no node with this symbol was found in the MTG." maxlog = 1
    end

    models = Dict(first(m) => parse_models(get_models(last(m))) for m in mapping)

    outputs = pre_allocate_outputs(statuses, status_templates, reverse_multiscale_mapping, vars_need_init, outputs, nsteps, type_promotion=type_promotion, check=check)

    outputs_index = Dict{String, Int}(s => 1 for s in keys(outputs))
    return (; mtg, statuses, status_templates, reverse_multiscale_mapping, vars_need_init, dependency_graph=dep_graph, models, outputs, outputs_index)
end