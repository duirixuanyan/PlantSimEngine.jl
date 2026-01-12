abstract type AbstractDependencyNode end

mutable struct HardDependencyNode{T} <: AbstractDependencyNode
    value::T
    process::Symbol
    dependency::NamedTuple
    missing_dependency::Vector{Int}
    scale::String
    inputs
    outputs
    parent::Union{Nothing,<:AbstractDependencyNode}
    children::Vector{HardDependencyNode}
end

mutable struct SoftDependencyNode{T} <: AbstractDependencyNode
    value::T
    process::Symbol
    scale::String
    inputs
    outputs
    hard_dependency::Vector{HardDependencyNode}
    parent::Union{Nothing,Vector{SoftDependencyNode}}
    parent_vars::Union{Nothing,NamedTuple}
    children::Vector{SoftDependencyNode}
    simulation_id::Vector{Int} # 模拟的 id
end

# 添加方法以检查节点是否可并行化:
object_parallelizable(x::T) where {T<:AbstractDependencyNode} = x.value => object_parallelizable(x.value)
timestep_parallelizable(x::T) where {T<:AbstractDependencyNode} = x.value => timestep_parallelizable(x.value)

"""
    DependencyGraph{T}(roots::T, not_found::Dict{Symbol,DataType})

模型之间依赖关系的图。

# 参数

- `roots::T`：图的根节点。
- `not_found::Dict{Symbol,DataType}`：在图中未找到的模型。
"""
struct DependencyGraph{T,N}
    roots::T
    not_found::Dict{Symbol,N}
end

# 添加方法以检查节点是否可并行化:
function which_timestep_parallelizable(x::T) where {T<:DependencyGraph}
    return traverse_dependency_graph(x, timestep_parallelizable)
end

function which_object_parallelizable(x::T) where {T<:DependencyGraph}
    return traverse_dependency_graph(x, object_parallelizable)
end

object_parallelizable(x::T) where {T<:DependencyGraph} = all([i.second.second for i in which_object_parallelizable(x)])
timestep_parallelizable(x::T) where {T<:DependencyGraph} = all([i.second.second for i in which_timestep_parallelizable(x)])

AbstractTrees.children(t::AbstractDependencyNode) = t.children
AbstractTrees.nodevalue(t::AbstractDependencyNode) = t.value # 需要较新版本的 AbstractTrees
AbstractTrees.ParentLinks(::Type{<:AbstractDependencyNode}) = AbstractTrees.StoredParents()
AbstractTrees.parent(t::AbstractDependencyNode) = t.parent
AbstractTrees.printnode(io::IO, node::HardDependencyNode{T}) where {T} = print(io, T)
AbstractTrees.printnode(io::IO, node::SoftDependencyNode{T}) where {T} = print(io, T)
Base.show(io::IO, t::AbstractDependencyNode) = AbstractTrees.print_tree(io, t)
Base.length(t::AbstractDependencyNode) = length(collect(AbstractTrees.PreOrderDFS(t)))
Base.length(t::DependencyGraph) = length(traverse_dependency_graph(t))
AbstractTrees.children(t::DependencyGraph) = collect(t.roots)

# 长格式打印
function Base.show(io::IO, ::MIME"text/plain", t::DependencyGraph)
    # 如果图是有环的，则打印出循环，因为无法无限打印:
    iscyclic, cycle_vec = is_graph_cyclic(t; warn=false, full_stack=true)
    if iscyclic
        print(io, "⚠ Cyclic dependency graph: \n $(print_cycle(cycle_vec))")
        return nothing
    else
        draw_dependency_graph(io, t)
    end
end

"""
    variables_multiscale(node, organ, mapping, st=NamedTuple())

获取 HardDependencyNode 的变量，考虑多尺度映射，也就是说，
如果变量被映射到了另一个尺度，则定义为 `MappedVar`。默认值
取自模型本身，如果用户未指定（`st`），且如果为节点的输入变量，则
用 `UninitializedVar` 标记。

返回一个包含变量及其默认值的 NamedTuple。

# 参数

- `node::HardDependencyNode`：需要获取变量的节点。
- `organ::String`：器官类型，如 "Leaf"。
- `vars_mapping::Dict{String,T}`：模型的映射（详见下方）。
- `st::NamedTuple`：可选，包含变量默认值的 NamedTuple。

# 详情

`vars_mapping` 是一个以器官类型为 key、以字典为 value 的字典。
它由用户映射计算得到：
"""
function variables_multiscale(node, organ, vars_mapping, st=NamedTuple())
    node_vars = variables(node) # 例如 (inputs = (:var1=-Inf, :var2=-Inf), outputs = (:var3=-Inf,))
    ins = node_vars.inputs
    ins_variables = keys(ins)
    outs_variables = keys(node_vars.outputs)
    defaults = merge(node_vars...)
    map((inputs=ins_variables, outputs=outs_variables)) do vars # 遍历 :inputs 和 :outputs 的变量
        vars_ = Vector{Pair{Symbol,Any}}()
        for var in vars # 例如 var = :carbon_biomass
            if var in keys(st)
                # 如果用户给定状态，则用作默认值。
                default = st[var]
            elseif var in ins_variables
                # 否则，使用模型给定的默认值:
                # 如果变量是输入，则标记为未初始化:
                default = UninitializedVar(var, defaults[var])
            else
                # 如果变量是输出，使用模型给定的默认值:
                default = defaults[var]
            end

            if haskey(vars_mapping[organ], var)
                organ_mapped, organ_mapped_var = _node_mapping(vars_mapping[organ][var])
                push!(vars_, var => MappedVar(organ_mapped, var, organ_mapped_var, default))
                #* 仍需要检查变量是否以 PreviousTimeStep 包裹，因为一个模型可能用当前值，另一个模型用前一时刻的值。
                if haskey(vars_mapping[organ], PreviousTimeStep(var, node.process))
                    organ_mapped, organ_mapped_var = _node_mapping(vars_mapping[organ][PreviousTimeStep(var, node.process)])
                    push!(vars_, var => MappedVar(organ_mapped, PreviousTimeStep(var, node.process), organ_mapped_var, default))
                end
            elseif haskey(vars_mapping[organ], PreviousTimeStep(var, node.process))
                # 如果当前时刻未找到，则检查变量是否映射到了前一时刻:
                organ_mapped, organ_mapped_var = _node_mapping(vars_mapping[organ][PreviousTimeStep(var, node.process)])
                push!(vars_, var => MappedVar(organ_mapped, PreviousTimeStep(var, node.process), organ_mapped_var, default))
            else
                # 否则取默认值:
                push!(vars_, var => default)
            end
        end
        return (; vars_...,)
    end
end

function _node_mapping(var_mapping::Pair{String,Symbol})
    # 一个器官映射到变量:
    return SingleNodeMapping(first(var_mapping)), last(var_mapping)
end

function _node_mapping(var_mapping)
    # 多个器官映射到变量:
    organ_mapped = MultiNodeMapping([first(i) for i in var_mapping])
    organ_mapped_var = [last(i) for i in var_mapping]

    return organ_mapped, organ_mapped_var
end