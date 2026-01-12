"""
    GraphSimulation(graph, mapping)
    GraphSimulation(graph, statuses, dependency_graph, models, outputs)

一个类型，包含了图上仿真所需的所有信息。

# 参数

- `graph`：一个图实例，比如 MTG
- `mapping`：模型映射字典
- `statuses`：定义每个节点状态的结构体
- `status_templates`：状态模板字典
- `reverse_multiscale_mapping`：多尺度下其它层次的映射字典
- `var_need_init`：需要初始化的变量字典
- `dependency_graph`：应用于图的模型的依赖图
- `models`：模型字典
- `outputs`：输出字典
"""
struct GraphSimulation{T,S,U,O,V}
    graph::T
    statuses::S
    status_templates::Dict{String,Dict{Symbol,Any}}
    reverse_multiscale_mapping::Dict{String,Dict{String,Dict{Symbol,Any}}}
    var_need_init::Dict{String,V}
    dependency_graph::DependencyGraph
    models::Dict{String,U}
    outputs::Dict{String,O}
    outputs_index::Dict{String, Int}
end

function GraphSimulation(graph, mapping; nsteps=1, outputs=nothing, type_promotion=nothing, check=true, verbose=false)
    GraphSimulation(init_simulation(graph, mapping; nsteps=nsteps, outputs=outputs, type_promotion=type_promotion, check=check, verbose=verbose)...)
end

dep(g::GraphSimulation) = g.dependency_graph
status(g::GraphSimulation) = g.statuses
status_template(g::GraphSimulation) = g.status_templates
reverse_mapping(g::GraphSimulation) = g.reverse_multiscale_mapping
var_need_init(g::GraphSimulation) = g.var_need_init
get_models(g::GraphSimulation) = g.models
outputs(g::GraphSimulation) = g.outputs

"""
    convert_outputs(sim_outputs::Dict{String,O} where O, sink; refvectors=false, no_value=nothing)
    convert_outputs(sim_outputs::TimeStepTable{T} where T, sink)

将植物图上的仿真结果输出转换为其他格式。

# 细节

第一种方法用于多尺度仿真输出，第二种方法用于一般的单尺度仿真输出。
sink 参数决定输出格式，例如 `DataFrame`。

# 参数

- `sim_outputs`：仿真输出，通常由 `run!` 返回
- `sink`：兼容 Tables.jl 接口的 sink（例如 `DataFrame`）
- `refvectors`：默认是 `false`，会移除 RefVector 类型的变量，否则保留
- `no_value`：用于替换 `nothing` 的值，默认为 `nothing`。通常用于在 DataFrame 中将 `nothing` 转换为 `missing`

# 示例

```@example
using PlantSimEngine, MultiScaleTreeGraph, DataFrames, PlantSimEngine.Examples
```

导入示例模型（可见于包的 `examples` 文件夹，或 `Examples` 子模块）：

```jldoctest mylabel
julia> using PlantSimEngine.Examples;
```

$MAPPING_EXAMPLE

```@example
mtg = import_mtg_example();
```

```@example
out = run!(mtg, mapping, meteo, tracked_outputs = Dict(
    "Leaf" => (:carbon_assimilation, :carbon_demand, :soil_water_content, :carbon_allocation),
    "Internode" => (:carbon_allocation,),
    "Plant" => (:carbon_allocation,),
    "Soil" => (:soil_water_content,),
));
```

```@example
convert_outputs(out, DataFrames)
```
"""
# 另一种可能更好的方式是直接用输出创建 DataFrame，然后移除 RefVector 列并替换 node 列
function convert_outputs(outs::Dict{String,O} where O, sink; refvectors=false, no_value=nothing)
    ret = Dict{String, sink}()
    for (organ, status_vector) in outs
        # 移除 RefVector 变量
        refv = ()
        if length(status_vector) > 0
            for (var, val) in pairs(status_vector[1])
                if !refvectors && isa(val, RefVector)
                    refv = (refv..., var)
                end
                if var == :node
                    refv = (refv..., var)
                end
            end
        else
            @warn "No instance found at the $organ scale, no output available, removing it from the Dict"
            continue
        end
       
        # 获得新的 NamedTuple 类型
        refv_nt = NamedTuple{refv}

        # 用第一个元素确定最终类型，以便分配确定类型的向量
        vector_named_tuple_1 = NamedTuple(status_vector[1])

        # 用 id 替换 MTG node 变量（MTG 节点不适合导出为 CSV）
        filtered_named_tuple = (;node=MultiScaleTreeGraph.node_id(vector_named_tuple_1.node),Base.structdiff(vector_named_tuple_1, refv_nt)...)
        filtered_vector_named_tuple = Vector{typeof(filtered_named_tuple)}(undef, length(status_vector))

        for i in 1:length(status_vector)
            vector_named_tuple_i = NamedTuple(status_vector[i])
            filtered_vector_named_tuple[i] = (;node=MultiScaleTreeGraph.node_id(vector_named_tuple_i.node), Base.structdiff(vector_named_tuple_i, refv_nt)...)
        end

        ret[organ] = sink(filtered_vector_named_tuple)
    end
    return ret
end

# TODO 需要适配新输出结构或删除
function outputs(outs::Dict{String, O} where O, key::Symbol)
    Tables.columns(convert_outputs(outs, Vector{NamedTuple}))[key]
end

function outputs(outs::Dict{String, O} where O, i::T) where {T<:Integer}
    Tables.columns(convert_outputs(outs, Vector{NamedTuple}))[i]
end

# ModelLists 现在返回 TimeStepTable{Status} 类型的 outputs，转换很直接
function convert_outputs(out::TimeStepTable{T} where T, sink)
    @assert Tables.istable(sink) "The sink argument must be compatible with the Tables.jl interface (`Tables.istable(sink)` must return `true`, *e.g.* `DataFrame`)"      
    return sink(out)
end