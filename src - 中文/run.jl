"""
    run!(object, meteo, constants, extra=nothing; check=true, executor=Floops.ThreadedEx())
    run!(object, mapping, meteo, constants, extra; nsteps, outputs, check, executor)

运行仿真，对模型列表中的每个模型按照正确顺序（即按照依赖关系图）执行。

如果给定多个时间步，模型将在每个时间步顺序运行。

# 参数说明

- `object`：一个 [`ModelList`](@ref)、`ModelList` 的数组或字典，或者一个植物图（MTG）。
- `meteo`：一个 [`PlantMeteo.TimeStepTable`](https://palmstudio.github.io/PlantMeteo.jl/stable/API/#PlantMeteo.TimeStepTable)，其元素为 [`PlantMeteo.Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/API/#PlantMeteo.Atmosphere)，或单一 `PlantMeteo.Atmosphere`。
- `constants`：一个 [`PlantMeteo.Constants`](https://palmstudio.github.io/PlantMeteo.jl/stable/API/#PlantMeteo.Constants) 对象，或由常量键和值组成的 NamedTuple。
- `extra`：额外参数。在仿真植物图（MTG）时不可用（仿真对象通过此参数传递）。
- `check`：若为 `true`，在运行仿真前检查模型列表合法性（会花费少量时间），且在运行过程中返回更多信息。
- `executor`：用于运行仿真的 [`Floops`](https://juliafolds.github.io/FLoops.jl/stable/) 执行器，可以顺序执行（`executor=SequentialEx()`）、多线程并行（`executor=ThreadedEx()`，默认）、分布式并行（`executor=DistributedEx()`）。
- `mapping`：MTG 与模型列表之间的映射关系。
- `nsteps`：需要运行的时间步数，仅在未给定 meteo 时需要（否则会自动从 meteo 推断）。
- `outputs`：对于 MTG 的每个节点类型，需动态获得的输出变量。

# 返回值

在原地修改对象的 status。用户可通过 [`status`](https://virtualplantlab.github.io/PlantSimEngine.jl/stable/API/#PlantSimEngine.status-Tuple{Any}) 函数（参见示例）从对象获取结果。

# 细节

## 模型执行

模型按照依赖图顺序运行。如果一个模型对另一个模型有软依赖（即输入由另一模型计算），会优先运行被依赖模型。若有多个软依赖，则会优先计算所有父模型（软依赖）。

## 并行执行

用户可以通过为 `executor` 参数提供兼容执行器实现并行。软件包会自动检查是否允许并行。如果不允许而用户指定了并行，将会发出警告，并转为顺序执行。
我们使用 [`Floops`](https://juliafolds.github.io/FLoops.jl/stable/) 包实现并行仿真，意味着你可将任何相容的执行器传入 `executor` 参数。
可参考 [FoldsThreads.jl](https://github.com/JuliaFolds/FoldsThreads.jl)（线程执行器）、[FoldsDagger.jl](https://github.com/JuliaFolds/FoldsDagger.jl)（Dagger 框架并行 fold）、以及即将发布的 [FoldsCUDA.jl](https://github.com/JuliaFolds/FoldsCUDA.jl)（GPU 计算，详见 [本议题](https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues/22)）和 [FoldsKernelAbstractions.jl](https://github.com/JuliaFolds/FoldsKernelAbstractions.jl)。也可以通过 [ParallelMagics.jl](https://github.com/JuliaFolds/ParallelMagics.jl) 检查是否可自动并行。

# 示例

导入相关包：

```jldoctest run
julia> using PlantSimEngine, PlantMeteo;
```

加载 `Examples` 子模块中给出的示例模型：

```jldoctest run
julia> using PlantSimEngine.Examples;
```

创建模型列表：

```jldoctest run
julia> models = ModelList(Process1Model(1.0), Process2Model(), Process3Model(), status = (var1=1.0, var2=2.0));
```

创建气象数据：

```jldoctest run
julia> meteo = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65, Ri_PAR_f=300.0);
```

运行仿真：

```jldoctest run
julia> outputs_sim = run!(models, meteo);
```

获取仿真输出：

```jldoctest run
julia> (outputs_sim[:var4],outputs_sim[:var6])
([12.0], [41.95])
```
"""
run!



function adjust_weather_timesteps_to_given_length(desired_length, meteo)
    # 这里在代码流程上不是很理想，但 check_dimensions 稍后会介入
    # 并决定是否有 status 向量长度不一致的情况

    meteo_adjusted = meteo

    if DataFormat(meteo_adjusted) == TableAlike()
        if get_nsteps(meteo) == 1
            return Tables.rows(meteo_adjusted)[1]
        end
        return Tables.rows(meteo_adjusted)
    end

    if isnothing(meteo)
        meteo_adjusted = Weather(repeat([Atmosphere(NamedTuple())], desired_length))
    elseif get_nsteps(meteo) == 1 && desired_length > 1
        if isa(meteo, Atmosphere)
            meteo_adjusted = Weather(repeat([meteo], desired_length))
        end
    end

    return meteo_adjusted
end


# 用户入口，利用 traits 分派到正确的方法。
# traits 在 table_traits.jl 中定义，
# 决定对象属于 TableAlike、TreeAlike 还是 SingletonAlike。
function run!(
    object,
    meteo=nothing,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
)
    run!(
        DataFormat(object),
        object,
        meteo,
        constants,
        extra;
        tracked_outputs,
        check,
        executor
    )
end

##########################################################################################
## ModelList（单尺度）仿真
##########################################################################################

# 1- 多个 ModelList 对象和多个时间步
function run!(
    ::TableAlike,
    object::T,
    meteo::TimeStepTable{A},
    constants=PlantMeteo.Constants(),
    extra=nothing;
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
) where {T<:Union{AbstractArray,AbstractDict},A}

    if executor != SequentialEx()
        @warn string(
            "Parallelisation over objects was removed, (but may be reintroduced in the future). Parallelisation will only occur over timesteps."
        ) maxlog = 1
    end

    outputs_collection = isa(object, AbstractArray) ? [] : isnothing(tracked_outputs) ? Dict() : Dict{TimeStepTable{Status{typeof(tracked_outputs)}}}

    # 遍历每个对象
    for obj in object
        if isa(object, AbstractArray)
            push!(outputs_collection, run!(obj, meteo, constants, extra, tracked_outputs=tracked_outputs, check=check, executor=executor))
        else
            outputs_collection[obj.first] = run!(obj.second, meteo, constants, extra, tracked_outputs=tracked_outputs, check=check, executor=executor)
        end
    end
    return outputs_collection
end

# 2 - 一个对象，一个或多个 meteo 时间步（status 提供向量）
# （即一个 meteo 时间步可能被扩展到 status 向量长度）
function run!(
    ::SingletonAlike,
    object::T,
    meteo=nothing,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
) where {T<:ModelList}

    meteo_adjusted = adjust_weather_timesteps_to_given_length(get_status_vector_max_length(object.status), meteo)
    nsteps = get_nsteps(meteo_adjusted)

    dep_graph = dep!(object, nsteps)

    if check
        # 检查 meteo 和 status 是否长度一致（或者为 1）
        check_dimensions(object, meteo_adjusted)

        if length(dep_graph.not_found) > 0
            error(
                "The following processes are missing to run the ModelList: ",
                dep_graph.not_found
            )
        end
    end

    if executor != SequentialEx() && nsteps > 1
        if !timestep_parallelizable(dep_graph)
            is_ts_parallel = which_timestep_parallelizable(dep_graph)
            mods_not_parallel = join([i.second.first for i in is_ts_parallel[findall(x -> x.second.second == false, is_ts_parallel)]], "; ")

            check && @warn string(
                "A parallel executor was provided (`executor=$(executor)`) but some models cannot be run in parallel: $mods_not_parallel. ",
                "The simulation will be run sequentially. Use `executor=SequentialEx()` to remove this warning."
            ) maxlog = 1
        else
            outputs_preallocated_mt = pre_allocate_outputs(object, tracked_outputs, nsteps; type_promotion=object.type_promotion, check=check)
            local vars = length(outputs_preallocated_mt) > 0 ? keys(outputs_preallocated_mt[1]) : NamedTuple()
            status_flattened_template, vector_variables_mt = flatten_status(object.status)

            # 并行计算每个时间步
            @floop executor for i in 1:nsteps
                @init begin
                    status_flattened = deepcopy(status_flattened_template)
                    roots = collect(dep_graph.roots)
                end
                meteo_i = meteo_adjusted[i]
                set_variables_at_timestep!(status_flattened, status(object), vector_variables_mt, i)
                for (process, node) in roots
                    run_node!(object, node, i, status_flattened, meteo_i, constants, extra)
                end
                for var in vars
                    outputs_preallocated_mt[i][var] = status_flattened[var]
                end
            end
            return outputs_preallocated_mt
        end
    end

    outputs_preallocated = pre_allocate_outputs(object, tracked_outputs, nsteps; type_promotion=object.type_promotion, check=check)
    status_flattened, vector_variables = flatten_status(status(object))

    # 若时间步不可并行，说明部分变量依赖前一时刻值。
    # 此时将除用户指定所有时间步的变量外，其它变量从前一时刻传递到下一时刻。
    roots = collect(dep_graph.roots)

    # 针对 DataFrameRow meteos，此部分必要，详见 XPalm 测试
    if nsteps == 1
        for (process, node) in roots
            run_node!(object, node, 1, status_flattened, meteo_adjusted, constants, extra)
        end
        save_results!(status_flattened, outputs_preallocated, 1)
    else
        for (i, meteo_i) in enumerate(meteo_adjusted)
            for (process, node) in roots
                run_node!(object, node, i, status_flattened, meteo_i, constants, extra)
            end
            save_results!(status_flattened, outputs_preallocated, i)
            i + 1 <= nsteps && set_variables_at_timestep!(status_flattened, status(object), vector_variables, i + 1)
        end
    end

    return outputs_preallocated
end

# 3- 多个对象和一个 meteo 时间步
function run!(
    ::TableAlike,
    object::T,
    meteo,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
) where {T<:Union{AbstractArray,AbstractDict}}

    dep_graphs = [dep(obj) for obj in collect(values(object))]
    #obj_parallelizable = all([object_parallelizable(graph) for graph in dep_graphs])

    # 检查是否可对对象并行仿真
    if executor != SequentialEx()
        @warn string(
            "Parallelisation over objects was removed, (but may be reintroduced in the future). Parallelisation will only occur over timesteps."
        ) maxlog = 1
    end

    # 遍历每个对象
    for (i, obj) in enumerate(collect(values(object)))
        if check
            # 检查 meteo 和 status 是否长度一致（或为 1）
            check_dimensions(obj, meteo)

            if length(dep_graphs[i].not_found) > 0
                error(
                    "The following processes are missing to run the ModelList: ",
                    dep_graphs[i].not_found
                )
            end
        end
    end

    outputs_collection = isa(object, AbstractArray) ? [] : isnothing(tracked_outputs) ? Dict() : Dict{TimeStepTable{Status{typeof(tracked_outputs)}}}

    # 遍历每个对象
    for obj in object
        if isa(object, AbstractArray)
            push!(outputs_collection, run!(obj, meteo, constants, extra, tracked_outputs=tracked_outputs, check=check, executor=executor))
        else
            outputs_collection[obj.first] = run!(obj.second, meteo, constants, extra, tracked_outputs=tracked_outputs, check=check, executor=executor)
        end
    end
    return outputs_collection
end



# 用户不可访问：
# 遍历依赖图中每个依赖节点（始终为一个对象的一个时间步），实际的“工作马”
function run_node!(
    object::T,
    node::SoftDependencyNode,
    i, # 所在时间步，用于索引依赖节点，判断该模型是否已调用
    st,
    meteo,
    constants,
    extra
) where {T<:ModelList}

    # 检查所有父节点是否都已在该时间步调用过
    if !AbstractTrees.isroot(node) && any([p.simulation_id[i] <= node.simulation_id[i] for p in node.parent])
        # 若未调用，则本节点会被其它父节点调用
        return nothing
    end

    # 实际模型调用
    run!(node.value, object.models, st, meteo, constants, extra)
    node.simulation_id[i] += 1 # 更新 simulation id，用于判断是否已执行过模型

    # 递归调用其子节点（仅软依赖；硬依赖由模型自身处理）
    for child in node.children
        #! 检查是否可用 @floop 并行执行，建议不能，
        #! 因为我们已在上方开启并行，且会同时修改 node.simulation_id，
        #! 并不是线程安全的。
        run_node!(object, child, i, st, meteo, constants, extra)
    end
end


##########################################################################################
### 多尺度仿真
##########################################################################################

# 另一用户接口
# 传入 MTG 和 mapping，生成 GraphSimulation 对象
# 然后用通用 run! 入口即可启动仿真
function run!(
    object::MultiScaleTreeGraph.Node,
    mapping::Dict{String,T} where {T},
    meteo=nothing,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    nsteps=nothing,
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
)
    isnothing(nsteps) && (nsteps = get_nsteps(meteo))
    meteo_adjusted = adjust_weather_timesteps_to_given_length(nsteps, meteo)

    # 注意：如果已调用 replace_mapping_status_vectors_with_generated_models 则没问题，
    # 否则映射生成的模型向量长度可能和时间步发生冲突
    sim = GraphSimulation(object, mapping, nsteps=nsteps, check=check, outputs=tracked_outputs)
    run!(
        sim,
        meteo_adjusted,
        constants,
        extra;
        check=check,
        executor=executor
    )

    return outputs(sim)
end

function run!(
    ::TreeAlike,
    object::GraphSimulation,
    meteo,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
)

    dep_graph = object.dependency_graph
    models = get_models(object)
    # st = status(object)

    !isnothing(extra) && error("Extra parameters are not allowed for the simulation of an MTG (already used for statuses).")

    nsteps = get_nsteps(meteo)

    # 若直接用大气对象调用本函数，则不使用 Rows 接口
    if nsteps == 1
        roots = collect(dep_graph.roots)
        for (process_key, dependency_node) in roots
            run_node_multiscale!(object, dependency_node, 1, models, meteo, constants, object, check, executor)
        end
        save_results!(object, 1)
    else
        for (i, meteo_i) in enumerate(Tables.rows(meteo))
            roots = collect(dep_graph.roots)
            for (process_key, dependency_node) in roots
                run_node_multiscale!(object, dependency_node, i, models, meteo_i, constants, object, check, executor)
            end
            # 在每个时间步结束，保存仿真结果到对象中
            save_results!(object, i)
        end
    end

    # save_results! 在多尺度仿真中极端调整结果数组长度，因为模型可能新生成器官等，节点数未知，
    # 所以最终需将输出结果裁剪为最终大小
    for (organ, index) in object.outputs_index
        resize!(outputs(object)[organ], index - 1)
    end

    return outputs(object)
end


# 运行依赖图节点的函数，实际“工作马”：
function run_node_multiscale!(
    object::T,
    node::SoftDependencyNode,
    i, # 当前依赖节点所在时间步（用于判断是否已调用）
    models,
    meteo,
    constants,
    extra::T, # 通过 extra 传递仿真对象，以便仿真时可访问其参数
    check,
    executor
) where {T<:GraphSimulation} # T 为各器官类型的状态

    # run!(status(object), dependency_node, meteo, constants, extra)
    # 检查父节点是否都已调用过
    if !AbstractTrees.isroot(node) && any([p.simulation_id[1] <= node.simulation_id[1] for p in node.parent])
        # 若未调用，本节点会由其它父节点调用
        return nothing
    end

    node_statuses = status(object)[node.scale] # 获取当前尺度下所有节点的状态
    models_at_scale = models[node.scale]

    for st in node_statuses # 遍历当前尺度下每个节点状态（可并行）
        # 实际模型调用
        run!(node.value, models_at_scale, st, meteo, constants, extra)
    end

    node.simulation_id[1] += 1 # 更新 simulation id，记录已调用

    # 递归遍历并运行其子节点（仅软依赖，硬依赖由模型自身处理）
    for child in node.children
        #! 检查是否可用 @floop 并行。建议不能，
        #! 因为已并行处理，并且 simulation_id 非线程安全。
        run_node_multiscale!(object, child, i, models, meteo, constants, extra, check, executor)
    end
end