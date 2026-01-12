"""
    add_organ!(node::MultiScaleTreeGraph.Node, sim_object, link, symbol, scale; index=0, id=MultiScaleTreeGraph.new_id(MultiScaleTreeGraph.get_root(node)), attributes=Dict{Symbol,Any}(), check=true)

向图中添加一个器官，并自动初始化该器官的（多尺度）变量状态。

此函数应从实现器官出现的模型中调用，例如基于热时间的函数。

# 参数说明

* `node`：要向其添加器官的节点（新器官的父节点）
* `sim_object`：模拟对象，例如模型的`extra`参数中的 `GraphSimulation` 对象。
* `link`：新节点与器官之间的连接类型：
    * `"<"`：新节点在父器官之后
    * `"+"`：新节点从父器官分枝
    * `"/"`：新节点分解父器官，即更改尺度
* `symbol`：器官的符号，例如 `"Leaf"`
* `scale`：器官的尺度，例如 `2`。
* `index`：器官的序号，例如 `1`。`index` 可用于方便地标识分枝顺序，或轴上的生长单元序号。它不同于唯一的节点 `id`。
* `id`：新节点的唯一编号。如果未提供，则自动生成新编号。
* `attributes`：新节点的属性。如果未提供，则使用空字典。
* `check`：布尔值，表示是否检查变量初始化。会传递给 `init_node_status!`。

# 返回值

* `status`：新节点的状态

# 示例

具体用法请参考 `Examples` 模块中的 `ToyInternodeEmergence` 示例模型（也可在 `examples` 文件夹找到），或 `test-mtg-dynamic.jl` 测试文件。
"""
function add_organ!(node::MultiScaleTreeGraph.Node, sim_object, link, symbol, scale; index=0, id=MultiScaleTreeGraph.new_id(MultiScaleTreeGraph.get_root(node)), attributes=Dict{Symbol,Any}(), check=true)
    new_node = MultiScaleTreeGraph.Node(id, node, MultiScaleTreeGraph.NodeMTG(link, symbol, index, scale), attributes)
    st = init_node_status!(new_node, sim_object.statuses, sim_object.status_templates, sim_object.reverse_multiscale_mapping, sim_object.var_need_init, check=check)

    return st
end