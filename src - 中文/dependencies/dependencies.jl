dep(::T, nsteps=1) where {T<:AbstractModel} = NamedTuple()

"""
    dep(m::ModelList)
    dep(mapping::Dict{String,T}; verbose=true)
    dep!(m::ModelList, nsteps=1)

给定 ModelList 或多尺度模型映射，获取模型的依赖图。如果返回一个图，则所有模型耦合在一起；如果返回多个图，则每个图内的模型相互耦合，不同图中的模型不耦合。
`nsteps` 是依赖图将被使用的步数，用于决定每个软依赖在图中的 `simulation_id` 参数长度。对于多尺度映射，该值为 `1`。

# 细节

依赖图通过在每个过程的输入中查找其本层或其他层输出构建。针对每个模型（一个模型模拟一个过程）有五种情况：

1. 过程无输入。它是完全独立的，作为依赖图的根节点之一。
2. 过程需要同层模型输入。被放置为另一个过程的子节点。
3. 过程需要来自另一层的输入。被设置为另一个层过程的子节点。
4. 过程需要本层和另一层的输入。分别作为两个过程的子节点。
5. 过程作为另一个过程的硬依赖（仅可能在同层）。此时该过程被设为另一个过程的硬依赖，仿真由该过程直接控制。

第四种情况，过程有两个父过程。这样处理没有问题，因为仿真时会检查两个父节点是否都已运行，仅当均已运行后再运行当前过程。

第五种情况，依然需要检查变量是否来自另一层。此时父节点作为另一层过程的子节点。需注意，可能存在多层硬依赖图，因此此过程是递归完成的。

如何实现以上功能？首先识别硬依赖，然后将硬依赖根节点的输入输出与其它层连接（如有必要）。随后将所有这些节点转为软依赖，放入一个 Dict（Scale => Dict(process => SoftDependencyNode)）中。
遍历所有节点，将需要其它节点输出作为输入的节点，设置为子/父节点关系。
如某节点无任何依赖，则设置为根节点并推入新 Dict（independant_process_root）。此 Dict 就是返回的依赖图，根节点为各子图的独立起点，这些子图即为被耦合在一起的模型。此后可分别遍历每个子图进行仿真。

# 备注

`dep(m::ModelList)` 与 `dep!(m::ModelList, nsteps)` 的区别在于，前者返回模型列表中的依赖图，后者返回指定步数的依赖图，并对每个节点的 simulation_id 进行修正（`simulation_id=fill(0, nsteps)`）。

# 示例

```@example
using PlantSimEngine

# 包含示例过程与模型：
using PlantSimEngine.Examples;

models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status=(var1=15.0, var2=0.3)
)

dep(models)

# 或直接用过程：
models = (
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    process4=Process4Model(),
    process5=Process5Model(),
    process6=Process6Model(),
    process7=Process7Model(),
)

dep(;models...)
```
"""
function dep(nsteps=1; verbose::Bool=true, vars...)
    hard_dep = hard_dependencies((; vars...), verbose=verbose)
    deps = soft_dependencies(hard_dep, nsteps)

    # 返回依赖图
    return deps
end

function dep(m::ModelList)
    m.dependency_graph
end

function dep!(m::ModelList, nsteps=1)
    traverse_dependency_graph!(m.dependency_graph; visit_hard_dep=false) do node
        if length(node.simulation_id) != nsteps
            node.simulation_id = fill(0, nsteps)
        end
    end

    return m.dependency_graph
end


function dep(m::NamedTuple, nsteps=1; verbose::Bool=true)
    dep(nsteps; verbose=verbose, m...)
end

function dep(mapping::Dict{String,T}; verbose::Bool=true) where {T}
    # 第一步，获取硬依赖图，并为每个硬依赖根节点创建 SoftDependencyNodes。换句话说，我们只需要那些不是其他节点硬依赖的节点，这些节点作为软依赖图的根，因为它们独立。
    soft_dep_graphs_roots, hard_dep_dict = hard_dependencies(mapping; verbose=verbose)
    
    mapped_vars = mapped_variables(mapping, soft_dep_graphs_roots, verbose=false)
    reverse_multiscale_mapping = reverse_mapping(mapped_vars, all=false)
    
    # 第二步，计算第一步中各 SoftDependencyNode 之间的软依赖图。即在同层及不同层中查找每个过程的输入是否由其它过程输出获得。随后保留没有软依赖的节点，设置为软依赖图的根。其余节点设置为依赖它们的节点的子节点。
    dep_graph = soft_dependencies_multiscale(soft_dep_graphs_roots, reverse_multiscale_mapping, hard_dep_dict)
    # 构建软依赖图过程中，已为每个依赖节点识别输入与输出，也为输入如为多尺度时定义为 MappedVar，即其取值来自其它层。
    # 尚有一处遗漏，需要在输出被其它层需要时，定义为多尺度输出。

    # 检查依赖图是否有环:
    iscyclic, cycle_vec = is_graph_cyclic(dep_graph; warn=false)
    # 注意：本操作也可以在 `soft_dependencies_multiscale` 内完成，但为保持函数简洁并单独可用，这里单独处理。

    iscyclic && error("Cyclic dependency detected in the graph. Cycle: \n $(print_cycle(cycle_vec)) \n You can break the cycle using the `PreviousTimeStep` variable in the mapping.")
    # 第三步，we identify which 
    return dep_graph
end
