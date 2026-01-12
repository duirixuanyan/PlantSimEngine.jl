"""
    pre_allocate_outputs(statuses, outs, nsteps; check=true)

为每种结点类型需要的变量预分配输出（向量的向量）。
第一层向量长度为 nsteps，第二层向量长度为该类型节点的数量。

注意：我们只为时间步预分配向量，而不是为每个器官预分配，因为我们无法预知每个器官将来有多少节点（器官可能会出现或消失）。

# 参数

- `statuses`：按结点类型划分的状态字典
- `outs`：按结点类型划分的输出变量字典
- `nsteps`：时间步数
- `check`：是否检查映射有无错误。默认为 `true`，如果部分变量不存在则会报错。如果为 false 并且有部分缺失变量，将给出提示，移除未知变量并继续执行。

# 返回值

- 每种类型预分配好的时间步向量和该类型节点的输出变量字典。

# 示例

```jldoctest mylabel
julia> using PlantSimEngine, MultiScaleTreeGraph, PlantSimEngine.Examples
```

导入示例模型（可在包的 `examples` 文件夹或 `Examples` 子模块中找到）: 

```jldoctest mylabel
julia> using PlantSimEngine.Examples;
```

定义模型映射关系:

```jldoctest mylabel
julia> mapping = Dict( \
    "Plant" =>  ( \
        MultiScaleModel(  \
            model=ToyCAllocationModel(), \
            mapped_variables=[ \
                :carbon_assimilation => ["Leaf"], \
                :carbon_demand => ["Leaf", "Internode"], \
                :carbon_allocation => ["Leaf", "Internode"] \
            ], \
        ), 
        MultiScaleModel(  \
            model=ToyPlantRmModel(), \
            mapped_variables=[:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm],] \
        ), \
    ),\
    "Internode" => ( \
        ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0), \
        ToyMaintenanceRespirationModel(1.5, 0.06, 25.0, 0.6, 0.004), \
        Status(TT=10.0, carbon_biomass=1.0) \
    ), \
    "Leaf" => ( \
        MultiScaleModel( \
            model=ToyAssimModel(), \
            mapped_variables=[:soil_water_content => "Soil",], \
        ), \
        ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0), \
        ToyMaintenanceRespirationModel(2.1, 0.06, 25.0, 1.0, 0.025), \
        Status(aPPFD=1300.0, TT=10.0, carbon_biomass=1.0), \
    ), \
    "Soil" => ( \
        ToySoilWaterModel(), \
    ), \
);
```

导入包内提供的示例 MTG:

```jldoctest mylabel
julia> mtg = import_mtg_example();
```

```jldoctest mylabel
julia> statuses, status_templates, reverse_multiscale_mapping, vars_need_init = PlantSimEngine.init_statuses(mtg, mapping);
```

```jldoctest mylabel
julia> outs = Dict("Leaf" => (:carbon_assimilation, :carbon_demand), "Soil" => (:soil_water_content,));
```

字典形式预分配输出变量:

```jldoctest mylabel
julia> preallocated_vars = PlantSimEngine.pre_allocate_outputs(statuses, status_templates, reverse_multiscale_mapping, vars_need_init, outs, 2);
```

该字典有每个需要导出的器官的键:

```jldoctest mylabel
julia> collect(keys(preallocated_vars))
2-element Vector{String}:
 "Soil"
 "Leaf"
```

每个器官对应一个输出变量的字典，内含预分配好的空向量（一组每时间步，每节点的待填值）:

```jldoctest mylabel
julia> collect(keys(preallocated_vars["Leaf"]))
3-element Vector{Symbol}:
 :carbon_assimilation
 :node
 :carbon_demand
```
"""

function pre_allocate_outputs(statuses, statuses_template, reverse_multiscale_mapping, vars_need_init, outs, nsteps; type_promotion=nothing, check=true)
    outs_ = Dict{String,Vector{Symbol}}()

    # 默认行为：追踪所有可用变量
    if isnothing(outs)
        for organ in keys(statuses)
            outs_[organ] = [keys(statuses_template[organ])...]
        end
        # 用户未指定输出：仅返回时间步和节点
    elseif length(outs) == 0
        for i in keys(statuses)
            outs_[i] = []
        end
    else
        for i in keys(outs) # i = "Plant"
            @assert isa(outs[i], Tuple{Vararg{Symbol}}) """Outputs for scale $i should be a tuple of symbols, *e.g.* `"$i" => (:a, :b)`, found `"$i" => $(outs[i])` instead."""
            outs_[i] = [outs[i]...]
        end
    end

    len = Dict{String,Int}()
    for (organ, vals) in outs_
        len[organ] = length(outs_[organ])
        unique!(outs_[organ])
    end

    for (organ, vals) in outs_
        if length(outs_[organ]) != len[organ]
            @info "One or more requested output variable duplicated at scale $organ, removed it"
        end
    end

    statuses_ = copy(statuses_template)
    # 检查输出指定的器官是否存在于 mtg（statuses）中:
    if !all(i in keys(statuses) for i in keys(outs_))
        not_in_statuses = setdiff(keys(outs_), keys(statuses))
        e = string(
            "You requested outputs for organs ",
            join(keys(outs_), ", "),
            ", but organs ",
            join(not_in_statuses, ", "),
            " have no models."
        )

        if check
            error(e)
        else
            @info e
            [delete!(outs_, i) for i in not_in_statuses]
        end
    end

    # 检查输出变量是否存在于状态里，并添加 :node 变量:
    for (organ, vars) in outs_ # organ = "Leaf"; vars = outs_[organ]
        if length(statuses[organ]) == 0
            # mtg 中未找到该器官，提示并继续（可能未来仿真中会创建）:
            check && @info "You required outputs for organ $organ, but this organ is not found in the provided MTG at this point."
        end
        if !all(i in collect(keys(statuses_[organ])) for i in vars)
            not_in_statuses = (setdiff(vars, keys(statuses_[organ]))...,)
            plural = length(not_in_statuses) == 1 ? "" : "s"
            e = string(
                "You requested outputs for variable", plural, " ",
                join(not_in_statuses, ", "),
                " in organ $organ, but ",
                length(not_in_statuses) == 1 ? "it has no model." : "they have no models."
            )
            if check
                error(e)
            else
                @info e
                existing_vars_requested = setdiff(outs_[organ], not_in_statuses)
                if length(existing_vars_requested) == 0
                    # 用户请求的变量一个也不存在于当前器官的模型
                    delete!(outs_, organ)
                else
                    # 只保留存在的变量
                    outs_[organ] = [existing_vars_requested...]
                end
            end
        end

        if :node ∉ outs_[organ]
            push!(outs_[organ], :node)
        end
    end

    node_types = []
    for o in keys(statuses)
        if length(statuses[o]) > 0
            push!(node_types, typeof(statuses[o][1].node))
        end
    end

    node_type = unique(node_types)
    @assert length(node_type) == 1 "All plant graph nodes should have the same type, found $(unique(node_type))."
    node_type = only(node_type)

    # 我不确定这个函数屏障是否有必要
    preallocated_outputs = Dict{String,Vector}()
    complete_preallocation_from_types!(preallocated_outputs, nsteps, outs_, node_type, statuses_template)
    return preallocated_outputs
end

function complete_preallocation_from_types!(preallocated_outputs, nsteps, outs_, node_type, statuses_template)
    types = Vector{DataType}()
    for organ in keys(outs_)

        outs_no_node = filter(x -> x != :node, outs_[organ])

        #types = [typeof(status_from_template(statuses_template[organ])[var]) for var in outs[organ]]
        values = [status_from_template(statuses_template[organ])[var] for var in outs_no_node]

        #push!(types, node_type)

        # 包含 :node
        symbols_tuple = (:timestep, :node, outs_no_node...,)
        # 使用 node_type.parameters[1] 处理 NodeMTG 与 AbstractNodeMTG
        values_tuple = (1, MultiScaleTreeGraph.Node((node_type.parameters[1])("/", "Uninitialized", 0, 0),), values...,)

        # 虚拟值，便于后续类型分析
        # （空数组没有实例引用，不容易检查和操作类型）
        dummy_status = (; zip(symbols_tuple, values_tuple)...)
        data = typeof(Status(dummy_status))[]
        resize!(data, nsteps)

        for ii in 1:nsteps
            data[ii] = Status(dummy_status)
        end
        preallocated_outputs[organ] = data
    end
end

"""
    save_results!(object::GraphSimulation, i)

将时间步 `i` 的仿真结果存储到 object 中。
对于 `GraphSimulation` 对象，此操作会把 `status(object)` 里的结果写入 `outputs(object)`。
"""
function save_results!(object::GraphSimulation, i)
    outs = outputs(object)

    if length(outs) == 0
        return
    end

    statuses = status(object)
    indexes = object.outputs_index
    for organ in keys(outs)

        if length(outs[organ]) == 0
            continue
        end

        index = indexes[organ]

        # Samuel：简单的扩容策略
        # 理论上可以更精细，由用户/启发式控制
        # 这里数组填充值的写法可能略繁琐，但即席构造 NamedTuple 影响性能
        # 多次尝试 Status 复制、扩容、fill、deepcopy...（和类型系统斗争）
        # 尚可简化（或许不用函数屏障，扩容可以一行写完...）
        # 经实际测试，对于 XPalm 不会带来明显性能瓶颈
        len = length(outs[organ])
        if length(statuses[organ]) + index - 1 > len
            min_required = max(length(statuses[organ]) + index - len, index)

            extra_length = 2 * min_required - len
            data = eltype(outs[organ])[]
            resize!(data, extra_length)
            dummy_value = NamedTuple(outs[organ][1])
            # TODO: 时间步设为0更直观？

            # 使用 fill! 会导致 Ref 问题，所以在此调用 Status 构造函数而不是传递预先构造的值
            # 这样可以避免数组中的所有元素都指向相同的引用，同时保持最小的构造开销
            for new_entry in 1:extra_length
                data[new_entry] = Status(dummy_value)
            end

            outs[organ] = cat(outs[organ], data, dims=1)
            #println("len : ", len, " statuses #", length(statuses[organ]), " index ", index)
            #println("min_required : ", min_required, " extra_length ", extra_length, " new len ", length(outs[organ]))
        end

        tracked_outputs = filter(i -> i != :timestep, keys(outs[organ][1]))

        indexes[organ] = copy_tracked_outputs_into_vector!(outs[organ], i, statuses[organ], tracked_outputs, indexes[organ])
    end
end

function copy_tracked_outputs_into_vector!(outs_organ, i, statuses_organ, tracked_outputs, index)
    j = index
    for status in statuses_organ
        outs_organ[j].timestep = i
        for var in tracked_outputs
            outs_organ[j][var] = status[var]
        end
        j += 1
    end
    return j
end

function pre_allocate_outputs(m::ModelList, outs, nsteps; type_promotion=nothing, check=true)
    st, = flatten_status(status(m))
    out_vars_all = convert_vars(st, type_promotion)

    out_keys_requested = Symbol[]
    if !isnothing(outs)
        if length(outs) == 0 # 若无任何期望输出
            return NamedTuple()
        end
        out_keys_requested = Symbol[outs...]
    end
    out_vars_requested = NamedTuple()

    # 默认行为：追踪全部变量
    if isempty(out_keys_requested)
        # 已有对应 status，直接重用
        out_vars_requested = NamedTuple(out_vars_all)
    else
        unexpected_outputs = setdiff(out_keys_requested, keys(st))

        if !isempty(unexpected_outputs)
            e = string(
                "You requested as output ",
                join(unexpected_outputs, " ,"),
                " not found in any model."
            )

            if check
                error(e)
            else
                @info e
                [delete!(unexpected_outputs, i) for i in unexpected_outputs]
            end
        end

        out_defaults_requested = (out_vars_all[i] for i in out_keys_requested)
        out_vars_requested = (; zip(out_keys_requested, out_defaults_requested)...)
    end

    return TimeStepTable([Status(out_vars_requested) for i in Base.OneTo(nsteps)])
end

function save_results!(status_flattened::Status, outputs, i)
    if length(outputs) == 0
        return
    end
    outs = outputs[i]

    for var in keys(outs)
        outs[var] = status_flattened[var]
    end
end