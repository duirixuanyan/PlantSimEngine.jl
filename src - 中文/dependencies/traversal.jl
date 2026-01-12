"""
    traverse_dependency_graph(graph::DependencyGraph, f::Function; visit_hard_dep=true)
    traverse_dependency_graph(graph; visit_hard_dep=true)

遍历依赖 `graph`，并对每个节点应用函数 `f`。如果未提供 `f`，则仅返回节点本身。

首先遍历第一层软依赖节点，然后遍历它们的硬依赖节点（如果 `visit_hard_dep=true`），最后遍历软依赖节点的子节点。

返回一个由节点与函数 `f` 结果组成的元组对的向量。

# 示例

```julia
using PlantSimEngine

# 包含示例进程和模型:
using PlantSimEngine.Examples;

function f(node)
    node.value
end

vars = (
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    process4=Process4Model(),
    process5=Process5Model(),
    process6=Process6Model(),
    process7=Process7Model(),
)

graph = dep(vars)
traverse_dependency_graph(graph, f)
```
"""
function traverse_dependency_graph(
    graph::DependencyGraph,
    f::Function;
    visit_hard_dep=true
)

    var = Pair{Symbol,Any}[]
    nodes_types = visit_hard_dep ? AbstractDependencyNode : SoftDependencyNode
    node_visited = Set{nodes_types}()
    for (p, root) in graph.roots
        traverse_dependency_graph!(root, f, var; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end

    return var
end

function traverse_dependency_graph(
    graph::DependencyGraph,
    visit_hard_dep=true
)
    nodes_types = visit_hard_dep ? AbstractDependencyNode : SoftDependencyNode
    var = Pair{Symbol,nodes_types}[]
    node_visited = Set{nodes_types}()
    for (p, root) in graph.roots
        traverse_dependency_graph!(root, x -> x, var; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end

    return last.(var)
end

function traverse_dependency_graph!(f::Function, graph::DependencyGraph; visit_hard_dep=true, node_visited::Set=Set{AbstractDependencyNode}())
    for (p, root) in graph.roots
        traverse_dependency_graph!(f, root, visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end
end

function traverse_dependency_graph!(f::Function, node::SoftDependencyNode; visit_hard_dep=true, node_visited::Set=Set{AbstractDependencyNode}())
    if node in node_visited
        return nothing
    end

    f(node)

    push!(node_visited, node)

    # 若有，遍历SoftDependencyNode的硬依赖节点:
    if visit_hard_dep && node isa SoftDependencyNode
        # 如果后面还有更多软依赖，可以在这里绘制分支线
        for child in node.hard_dependency
            traverse_dependency_graph!(f, child; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
        end
    end

    for child in node.children
        traverse_dependency_graph!(f, child; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end
end

function traverse_dependency_graph!(f::Function, node::HardDependencyNode; visit_hard_dep=true, node_visited::Set=Set{AbstractDependencyNode}())
    if node in node_visited
        return nothing
    end

    f(node)

    push!(node_visited, node)

    # 遍历所有硬依赖节点:
    for child in node.children
        traverse_dependency_graph!(f, child; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end
end


"""
    traverse_dependency_graph(node::SoftDependencyNode, f::Function, var::Vector; visit_hard_dep=true)

对 `node` 应用函数 `f`，遍历其硬依赖节点（当 `visit_hard_dep=true` 时），然后遍历其软依赖的子节点。

通过将节点的进程名和函数 `f` 的结果组成的对推入向量 `var`，以实现对 `var` 的累加。
"""
function traverse_dependency_graph!(
    node::SoftDependencyNode,
    f::Function,
    var::Vector;
    visit_hard_dep=true,
    node_visited::Set=Set{AbstractDependencyNode}()
)
    if node in node_visited
        return nothing
    end

    push!(var, node.process => f(node))

    push!(node_visited, node)

    # 若有，遍历SoftDependencyNode的硬依赖节点:
    if visit_hard_dep && node isa SoftDependencyNode
        # 如果后面还有更多软依赖，可以在这里绘制分支线
        for child in node.hard_dependency
            traverse_dependency_graph!(child, f, var; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
        end
    end

    for child in node.children
        traverse_dependency_graph!(child, f, var; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end
end

"""
    traverse_dependency_graph(node::HardDependencyNode, f::Function, var::Vector)

对 `node` 应用函数 `f`，然后遍历其子节点（硬依赖节点）。

通过将节点的进程名和函数 `f` 的结果组成的对推入向量 `var`，以实现对 `var` 的累加。
"""
function traverse_dependency_graph!(
    node::HardDependencyNode,
    f::Function,
    var::Vector;
    visit_hard_dep=true,  # 为了与SoftDependencyNode方法的调用保持兼容
    node_visited::Set=Set{HardDependencyNode}()
)

    if node in node_visited
        return nothing
    end

    push!(var, node.process => f(node))

    push!(node_visited, node)

    for child in node.children
        traverse_dependency_graph!(child, f, var; visit_hard_dep=visit_hard_dep, node_visited=node_visited)
    end
end
