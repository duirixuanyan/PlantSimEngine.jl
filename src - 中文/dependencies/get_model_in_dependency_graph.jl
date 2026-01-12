"""
    get_model_nodes(dep_graph::DependencyGraph, model)

获取依赖图中实现某种模型类型的节点。

# 参数

- `dep_graph::DependencyGraph`：依赖关系图。
- `model`：要查找的模型类型。

# 返回

- 实现该模型类型的节点数组。

# 示例

```julia
PlantSimEngine.get_model_nodes(dependency_graph, Beer)
```
"""
function get_model_nodes(dep_graph::DependencyGraph, model)
    model_node = Union{SoftDependencyNode,HardDependencyNode}[]

    traverse_dependency_graph!(dep_graph) do node
        if isa(node.value, model)
            push!(model_node, node)
        end
    end

    return model_node
end

function get_model_nodes(dep_graph::DependencyGraph, process::Symbol)
    process_node = Union{SoftDependencyNode,HardDependencyNode}[]

    traverse_dependency_graph!(dep_graph) do node
        if node.process == process
            push!(process_node, node)
        end
    end

    return process_node
end