# 多尺度建模的注意事项

```@contents
Pages = ["multiscale_considerations.md"]
Depth = 3
```

本页面简要介绍了多尺度模拟与以往单尺度模拟在细节上的不同之处。接下来的几页将通过示例展示这些微妙的差异。

声明并运行多尺度模拟总体流程与单尺度模拟类似，但多尺度模拟有一些重要区别：

- 模拟需要一个多尺度树图（Multi-scale Tree Graph, MTG）作为基础，并在该图上运行
- 在运行时，模型被绑定到特定的尺度，只能访问与本地相关的信息
- 同一个模型在每个时间步可能会被执行多次
- [`ModelList`](@ref) 被一个更复杂的模型映射（model mapping）取代，用于将模型与它们作用的尺度关联起来

模拟的依赖图依然会被自动计算并处理大多数耦合，因此一旦模型声明好，用户不需要再手动指定模型的执行顺序。不过你仍然需要声明硬依赖，且在多尺度情况下可能需要额外的硬依赖声明。

多尺度模拟通常还需要添加额外的辅助模型，以便为某些主模型准备所需的变量。

## 相关页面

本多尺度章节的其他页面介绍了：

- 如何将单尺度 `ModelList` 模拟直接转为多尺度模拟，并添加另一个尺度：[将单尺度模拟转换为多尺度模拟](@ref)
- 展示跨尺度变量映射的更复杂的多尺度模拟示例：[多尺度变量映射](@ref)
- 通过三步教程组合模型来模拟一个生长中的玩具植物：[编写多尺度模拟](@ref)
- 如何处理变量导致环状依赖（循环依赖）的情况：[避免循环依赖](@ref)
- 多尺度特有的耦合与细节注意事项：[多尺度环境下的依赖关系处理](@ref)

## 多尺度树图

功能-结构植物模型（Functional-Structural Plant Models, FSPM）通常用于模拟植物的生长过程。进行多尺度模拟时，默认的操作对象是一个类似于植物结构的对象，这正是用多尺度树图（Multi-scale Tree Graph, MTG）来表示的。

因此，要运行多尺度模拟，就需要一个多尺度树图（MTG）对象（关于MTG的简要介绍请见[多尺度树图](@ref)小节）。即便你的模拟实际上并不真正影响MTG，也可以使用一个“虚拟”MTG，但该参数始终是多尺度[`run!`](@ref)函数的必要输入。

本章所有多尺度模拟示例均采用了配套包[MultiScaleTreeGraph.jl](https://github.com/VEZY/MultiScaleTreeGraph.jl)，因此强烈推荐你也基于此包运行自己的多尺度模拟。若想可视化多尺度树图，也推荐使用[PlantGeom](https://github.com/VEZY/PlantGeom.jl）。

!!! note
    多尺度树图的部分术语与PlantSimEngine自身的概念存在冲突，详细讨论见[尺度 / 符号（symbol）术语的混淆](@ref)。如果你对这些概念还不熟悉，请务必先阅读相关章节并加以区分。

## 模型每个器官实例运行一次，而不是每个器官层级运行一次

有些模型（如在单尺度模拟中见到的那些）面向整个植株，结构非常简单。

更精细的模型则可以绑定到某一个具体的植物器官。

例如，一个根据叶龄计算叶片面积的模型将在“叶片”这个尺度上运行，也就是说**每片叶子**每个仿真步都会调用一次。而若你要计算整株植物的总叶面积，只需每次仿真步在“植株”尺度上运行一次即可。

这是单尺度与多尺度模拟之间的一个重大区别。在单尺度模拟中，每个模型每个仿真步只会执行**一次**。而在多尺度模拟中，如果一个植物某类器官有多个实例，比如有一百片叶子，那么任何在“叶片”尺度上的模型将默认在每个仿真步被调用一百次，除非通过其他模型（例如通过硬依赖配置）对其执行次数进行明确控制。

## 映射关系（Mappings）

当用户定义要使用哪些模型时，PlantSimEngine 无法预先判断各模型对应的尺度等级。这部分原因是多尺度树图（MTG）中的植物器官并没有统一命名，另外某些器官可能初始并未包含在 MTG 中，因此仅靠解析 MTG 无法推断出所有用到的尺度。

因此，用户需要在模拟中明确指出每个模型对应于哪个物理尺度。

多尺度映射指的是将模型与其运行的尺度关联，通过 Julia 的 `Dict` 实现。例如，将 "Leaf"（叶片）与在该尺度运行的 "LeafSurfaceAreaModel"（叶面积模型）相连。这种映射在多尺度模拟中相当于单尺度模拟下的 [`ModelList`](@ref)。

多尺度模型可以与上文介绍的单尺度模型类似，或者，当需要使用其他尺度变量时，需要包裹为 [`MultiScaleModel`](@ref) 对象。许多模型实际上不固定于某一尺度，因此可在不同尺度或单尺度场景下复用。

## 仿真是基于 MTG 进行的

与单尺度模拟不同，单尺度模拟借助 [`Status`](@ref) 对象来存储每个变量的当前状态；多尺度模拟则以每个器官为基础。

这意味着每个器官实例都会有自己的 [`Status`](@ref)，并带有当前尺度下的专属属性。

这导致了模拟运行时的两个**重要**差别：

- 首先，**MTG 中不存在的尺度将不会被执行**。举例来说，你的 MTG 若没有叶片节点，则所有运行于“叶片”尺度的模型都无法开始，直至创建一个叶片节点并添加到 MTG。否则没有对应的 MTG 节点可作用。唯一例外是“硬依赖”模型（hard dependency models），它们可以被其他已有尺度的节点模型直接调用，即使本尺度节点不存在。

- 其次，模型默认只能访问自己的**本地**器官信息。在 [`run!`](@ref) 函数中，[`status`](@ref) 参数只包含**该模型所属尺度**的变量，除非通过 [`MultiScaleModel`](@ref) 包装将跨尺度变量显式映射进来。

## run! 函数的调用签名

[`run!`](@ref) 函数与单尺度版本稍有不同。目前的基本结构（省略一些高级或已废弃的可选参数）如下：

```julia
run!(mtg, mapping, meteo, constants, extra; nsteps, tracked_outputs)
```

不同于单尺度模型只需 [`ModelList`](@ref)，此处需要一个 MTG 和映射表。可选参数 `meteo` 与 `constants` 与单尺度用法一致。`extra` 参数已预留，不建议使用。新增了 `nsteps` 关键字参数，可以指定仿真的步数上限。

## 多尺度输出数据结构

多尺度仿真的输出结构，与映射类似，是一个以尺度名称为索引的 Julia `Dict` 字典。每个键对应一个特定尺度，其值为 `Vector{NamedTuple}`（命名元组数组），其中列表内为每个仿真步、当前尺度下每个节点需要输出的变量。此外，输出数据中还添加了仿真步（`:timestep`）和树图节点（`:node`）两个入口。

这种字典结构使得多尺度仿真的输出相较于单尺度更为繁琐，不便直接查阅，但整体用法类似，同时该结构紧凑、可高效地转换为 `Dict{String, DataFrame}`，从而便于后续查询分析。

!!! note
    部分映射变量（例如从标量自动扩展为向量的变量）为节省内存和空间不会被写入输出，因为它们是冗余的。

下面以玩具植物教程第 3 部分为例，展示 “Root”（根）尺度下某一变量的输出片段（详细内容见 [修复植物模拟中的Bug](@ref)）：

```julia
julia> outs

Dict{String, Vector} with 5 entries:
  "Internode" => @NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, carbon_root_creation_consumed::Float64, TT_cu::Float64, carbon_…
  "Root"      => @NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, carbon_root_creation_consumed::Float64, water_absorbed::Float64…
  "Scene"     => @NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, TT_cu::Float64, TT::Float64}[(timestep = 1, node = / 1: Scene…
  "Plant"     => @NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, carbon_root_creation_consumed::Float64, carbon_stock::Float64, …
  "Leaf"      => @NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, carbon_captured::Float64}[(timestep = 1, node = + 4: Leaf…

julia> outs["Root"]
3257-element Vector{@NamedTuple{timestep::Int64, node::Node{NodeMTG, Dict{Symbol, Any}}, carbon_root_creation_consumed::Float64, water_absorbed::Float64, root_water_assimilation::Float64}}:
 (timestep = 1, node = + 9: Root
└─ < 10: Root
   └─ < 11: Root
      └─ < 12: Root
         └─ < 13: Root
            └─ < 14: Root
               └─ < 15: Root
                  └─ < 16: Root
                     └─ < 17: Root
, carbon_root_creation_consumed = 50.0, water_absorbed = 0.5, root_water_assimilation = 1.0)
 ⋮
```

与单尺度仿真相比，多尺度仿真下的输出更难直接索引查找，因为无法简单对应到每一个仿真步。

```julia
julia> [Pair(outs["Root"][i][:timestep], outs["Root"][i][:carbon_root_creation_consumed]) for i in 1:length(outs["Root"])]
3257-element Vector{Pair{Int64, Float64}}:
   1 => 50.0
   1 => 50.0
   2 => 50.0
   2 => 50.0
   2 => 50.0
     ⋮
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
 365 => 50.0
```

将输出转换为 DataFrame 对象的字典，可以使此类查询变得更加容易书写。

!!! warning
    当前，`:node` 条目只做了浅拷贝。不同尺度下每一时刻的 `:node` 实际都反映了节点的最终状态，因此在该时刻属性值可能与真实历史值不一致。若需精确记录每步的属性值，建议通过专门的模型输出来保存这些信息。
    另外，目前还没有移除节点的方法，被认为已经修剪/死亡/流产的器官，其对应的节点依然会保留在输出数据结构里。

多尺度模拟，尤其是具有数千个叶片、节间、根分枝、芽和果实的植物，可能会产生大量数据。与单尺度模拟类似，可以通过[`run!`](@ref)函数的 `tracked_outputs` 关键字参数，仅保留每个模拟步中需要跟踪的变量，其余则予以过滤。

这些被跟踪的变量需要按尺度进行索引以避免歧义：

```julia
outs = Dict(
    "Scene" => (:TT, :TT_cu,),
    "Plant" => (:aPPFD, :LAI),
    "Leaf" => (:carbon_assimilation, :carbon_demand, :carbon_allocation, :TT),
    "Internode" => (:carbon_allocation,),
    "Soil" => (:soil_water_content,),
)
```

## 耦合关系与多尺度强依赖

多尺度仿真带来了新的耦合类型：映射是处理不同尺度模型间变量引用的方法之一。某个模型也可能对另一个运作于不同尺度的模型存在强依赖。这些多尺度下的专有复杂性，会在[多尺度环境下的依赖关系处理](@ref)中进一步讨论。