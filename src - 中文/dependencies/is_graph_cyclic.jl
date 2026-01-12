"""
    is_graph_cyclic(dependency_graph::DependencyGraph; full_stack=false, verbose=true)

判断依赖图是否包含环。

# 参数

- `dependency_graph::DependencyGraph`：需要检查的依赖图。
- `full_stack::Bool=false`：若为`true`，返回构成环的所有节点栈，否则只返回环本身。
- `warn::Bool=true`：若为`true`，当检测到环时输出格式化的警告信息。

返回一个布尔值指示图是否有环，以及作为向量的节点栈。
"""
function is_graph_cyclic(dependency_graph::DependencyGraph; full_stack=false, warn=true)
    visited = Dict{Pair{AbstractModel,String},Bool}()
    recursion_stack = Dict{Pair{AbstractModel,String},Bool}()
    for node in values(dependency_graph.roots)
        visited[node.value=>node.scale] = false
        recursion_stack[node.value=>node.scale] = false
    end

    for (root, node) in dependency_graph.roots
        cycle_vec = Vector{Pair{AbstractModel,String}}()
        if is_graph_cyclic_(node, visited, recursion_stack, cycle_vec)

            if full_stack
                push!(cycle_vec, node.value => node.scale)
            else
                # 仅保留形成环的部分（向量中的第一个节点为导致形成环的节点，检测到第二次出现时为环形成点）:
                cycled_nodes = findall(x -> x == cycle_vec[1], cycle_vec)
                cycle_vec = cycle_vec[1:cycled_nodes[2]]
            end

            warn && @warn "Cyclic dependency detected in the graph: \n $(print_cycle(cycle_vec))"

            return true, cycle_vec
        end
    end

    return false, visited
end

function is_graph_cyclic_(node, visited, recursion_stack, cycle_vec)
    node_id = node.value => node.scale
    visited[node_id] = true
    recursion_stack[node_id] = true

    for child in node.children
        child_id = child.value => child.scale
        if !haskey(visited, child_id) && is_graph_cyclic_(child, visited, recursion_stack, cycle_vec)
            push!(cycle_vec, child_id)
            return true
        elseif haskey(recursion_stack, child_id) && recursion_stack[child_id]
            push!(cycle_vec, child_id)
            return true
        end
    end

    recursion_stack[node_id] = false
    return false
end

function print_cycle(cycle_vec)
    printed_cycle = Any[Term.RenderableText(string("{bold red}", last(cycle_vec[1]), ": ", typeof(first(cycle_vec[1]))))]
    leading_space = [1]
    for (m, s) in cycle_vec[2:end]
        node_print = string(repeat(" ", leading_space[1]), "└ ", s, ": ", typeof(m))
        if (m => s) == cycle_vec[1]
            node_print = Term.RenderableText("{bold red}$node_print")
        else
            node_print = Term.RenderableText(node_print)
        end

        push!(printed_cycle, node_print)
        leading_space[1] += 1
    end

    return join(printed_cycle, "")
end