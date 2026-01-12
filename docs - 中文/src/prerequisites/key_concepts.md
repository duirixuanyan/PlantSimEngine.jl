# 关键概念

本页简要介绍了与 PlantSimEngine 相关及在使用过程中涉及到的一些主要概念和术语。

```@contents
Pages = ["key_concepts.md"]
Depth = 4
```

## 作物模型

## FSPM（功能-结构植物模型）

## PlantSimEngine 术语

本页对 PlantSimEngine 中用到的核心概念和术语进行了总体说明。如果你需要更贴近实现的详细设计与术语释义，请参见[简单模拟流程详解](@ref detailed-walkthrough-of-a-simple-simulation)。

!!! 注意
    某些术语在不同语境下可能含义不同，尤以“器官”、“尺度”（scale）和“符号”（symbol）为甚：这些词在[多尺度树图](@ref)中与 PlantSimEngine 其他部分的含义略有区别（见下文[尺度 / 符号（symbol）术语的混淆](@ref)小节）。遇到相关疑问时，请务必参阅对应子章节及相关示例。

### 过程（Processes）

在本包中，“过程”指一个生物或物理现象。你可以将其理解为系统中发生的任何过程，如光拦截、光合作用、水分、碳和能量通量、生长、产量，甚至太阳能电池产生的电力等。

如需了解如何声明一个新过程，可参见[实现一个新过程](@ref)。

### 模型（Models）

在 PlantSimEngine 中，“模型”指的是针对某一过程进行仿真的具体实现。

对于同一个过程，可能存在多种不同的模型选择。例如，针对光合作用有多种建模假说和粒度、精度不同的模型。一种简单光合模型可能只是对总叶面积用一个简明公式进行计算，而更复杂的模型则会模拟光拦截和光衰减等过程。

!!! 注意
    配套包 PlantBiophysics.jl 提供了用于实现光衰减 Beer-Lambert 定律的 [`Beer`](https://vezy.github.io/PlantBiophysics.jl/stable/functions/#PlantBiophysics.Beer) 结构体。本包也为 `light_interception` 过程和 `Beer` 模型提供了示例脚本，见 [`examples/Beer.jl`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/master/examples/Beer.jl)。

模型不仅仅用于文献定义的生理过程，也可以用于各种临时计算或非标准功能。在 PlantSimEngine 中，一切皆为模型。在许多场景下，自定义模型非常实用，比如汇总计算或处理特定信息。例如油棕模型 XPalm 就有多个模型用于管理不同器官的状态，还有专门进行叶片修剪的模型，其实现见 [leaf_pruning.jl](https://github.com/PalmStudio/XPalm.jl/blob/main/src/plant/phytomer/leaves/leaf_pruning.jl)。

要准备一次模拟，你需声明一个 ModelList，包含你所需的全部模型，并初始化各自的参数。具体用法请参见[逐步操作详解](@ref detailed-walkthrough-of-a-simple-simulation)。

对于多尺度模拟，模型在使用时应当与特定尺度（scale）绑定。具体细节见下文的[多尺度建模](@ref)内容，或参见[多尺度建模的注意事项](@ref)页面获取更完整的描述。

### 变量、输入、输出与模型耦合

在模拟过程中，模型需要某些输入数据和参数，并计算输出其它数据，这些输出可供其它模型使用。根据组合的模型不同，同一个变量可能是某些模型的输入、另一些模型的输出，也可能只是中间计算步骤，或者是整个模拟的用户输入。

下面给出一个模型耦合的概念示意图：每个“节点”代表一个不同的 PlantSimEngine 模型，图中的 `compute()` 等价于模型的 "run!" 函数：

![模型耦合示例](../www/GUID-12E2DDAD-7B20-4FE2-AA36-7FAC950382A6-low.png)
(图源: [Autodesk](https://help.autodesk.com/view/MAYAUL/2016/ENU/?guid=__files_GUID_A9070270_9B5D_4511_8012_BC948149884D_htm"))

### 依赖图（Dependency graphs）

通过上述方式将模型耦合起来，会形成所谓的[有向无环图（Directed Acyclic Graph, DAG）](https://en.wikipedia.org/wiki/Directed_acyclic_graph)，它是一类常见的[依赖图](https://en.wikipedia.org/wiki/Dependency_graph)。模型的执行顺序由这个依赖图决定。

![有向无环图（DAG）示例](../www/dags_acyclic_vs_cyclic-d1a669bf1b8b6bfa8ac3041788e81171.png)
一个简单的有向无环图，注意其中不允许出现环（循环）。图源: [Astronomer](https://www.astronomer.io/docs/learn/dags/)（注："Not Acyclic" 即为环状图）

PlantSimEngine 会自动根据变量和模型关系生成这样的有向无环依赖图。用户只需要声明模型，无需手动编写模型之间的连接代码，只要模型间的耦合不存在循环依赖，剩下的连接、调度都会自动完成。

### [“硬依赖”和“软依赖”](@id hard_dependency_def)

通过将一个模型的输出变量设为另一个模型的输入变量，可以处理大多数常见的模型耦合（多尺度模型和变量带来更多复杂情况）。但如果两个模型之间互相依赖，需要相互迭代、多次交换数据，该怎么办？

你可以在配套包 [PlantBioPhysics.jl](https://github.com/VEZY/PlantBiophysics.jl) 中找到一个典型案例。例如，能量平衡模型 [Monteith 模型](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/energy/Monteith.jl)需要在其 [`run!`](@ref) 函数中[多次迭代调用光合模型](https://github.com/VEZY/PlantBiophysics.jl/blob/c1a75f294109d52dc619f764ce51c6ca1ea897e8/src/processes/energy/Monteith.jl#L154)。

下图展示了这种模型互为依赖的方式：

![存在环的耦合示意图](../www/ecophysio_coupling_diagram.png)

存在环的耦合示例。图片来源：PlantBioPhysics.jl

这类模型耦合会导致模拟步骤出现“双向流动”，从而破坏依赖图中的“无环”假设。

PlantSimEngine 对这种情况的处理是：不把这些“高度耦合”的模型（下称 **硬依赖**）纳入主依赖图中。相反，开发者需要在一个模型内部手动调用这些硬依赖模型。这样，被调用的模型就作为父/祖先模型的内部子节点处理，不再与依赖图里的其他节点发生（外部）连接。这样得到的高级依赖图只保留没有双向依赖的模型之间的链接，依然是有向图，可以保证仿真的有序执行。上层依赖图中较简单的“外部”耦合我们称为“软依赖”。

![PlantSimEngine 中的硬依赖耦合可视化](../www/PBP_dependency_graph.png)

如上图所示，PlantSimEngine 对此类耦合的处理方式：
红色的模型（“硬依赖”）不会暴露在最终的依赖图中，最终依赖图只包含蓝色的“软依赖”关系，无任何环路。

这种方法对联动互依类模型的开发有如下影响：硬依赖模型必须被显式声明，并且其父模型需要在自己的 [`run!`](@ref) 函数中显式调用该硬依赖模型的 [`run!`](@ref) 方法。每个硬依赖模型只能对应一个父模型。

依赖其他过程使得此类模型的开发和验证稍显复杂，但这种方式依然保留了实现的灵活性，因为任何实现了该“硬依赖”过程的模型都可由用户传入。

请注意，硬依赖模型自身也可以继续嵌套更深一层的硬依赖，因此也可能出现更为复杂的多重耦合情形。

### 天气数据

要运行一次模拟，通常需要获取靠近目标或部件的气候/气象条件数据。

强烈建议用户使用 [`PlantMeteo.jl`](https://github.com/PalmStudio/PlantMeteo.jl) —— 这是一个配套包，用于高效管理气象数据，内置了一些默认的预处理及高效计算相关的数据结构。本文档将始终使用 PlantMeteo.jl，也推荐大家一同使用。

该包中最基础的数据结构是 [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere) 类型，代表稳态的大气条件，即假设环境处于平衡状态。若需存储多个连续时步的气象数据，则可使用 [`TimeStepTable`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.TimeStepTable)。

创建 [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere) 对象时必须提供以下变量：`T`（空气温度，单位为 °C）、`Rh`（相对湿度，取值范围为 0-1）以及 `Wind`（风速，单位为 m s⁻¹）。

如下例所示，还可以额外传入（可选项）光合有效辐射通量（`Ri_PAR_f`, 单位：W m⁻²）。我们可以这样声明条件：

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)
```

详细信息可参考[该包文档](https://vezy.github.io/PlantMeteo.jl/stable)。如果你不打算使用 PlantMeteo.jl，也可以自行提供气象数据，只要遵循 [Tables.jl 接口](https://tables.juliadata.org/stable/#Implementing-the-Interface-(i.e.-becoming-a-Tables.jl-source))（例如直接用 `DataFrame`）即可。

如果你希望使用更精细的逐时或逐步气象数据，那么往往需要自己扩展模型并操作 MTG 结构，模拟流程也会更复杂。

### 器官 / 尺度（Organ/Scale）

植物拥有不同的器官，每种器官具有不同的生理特性与过程。当对植物生长进行更细致的模拟时，许多模型会绑定到植物的某个特定器官。例如，处理开花状态或根系吸水的模型即属于此类。其他模型（如碳分配与碳需求）则可以以稍微不同的方式被复用于同一植物的多个器官。

在 PlantSimEngine 的文档中，通常“器官”（organ）与“尺度”（scale）这两个术语可以互换使用。实际上，“尺度”更为通用且准确，因为有些模型并不在特定器官方向运行，例如可以作用于整个场景(Scene)层级。因此，MTG 结构及用户所提供的数据中可能会出现“Scene”这一尺度。

处理多尺度数据时，往往需要明确指定尺度以进行变量映射，或指明模型所处的尺度层级。你会看到类似如下的代码：

```julia
"Root" => (RootGrowthModel(), OrganAgeModel()),
"Leaf" => (LightInterceptionModel(), OrganAgeModel()),
"Plant" => (TotalBiomassModel(),),
```

这个示例将具体的模型绑定到了具体的尺度。注意其中一个模型被复用于两个不同的尺度；注意 "Plant" 其实并不是具体的器官，因此推荐更常用“尺度”这个词。

### 多尺度建模

多尺度建模指的是同时在多个细致层次下对系统进行模拟。有些模型可能在器官尺度运行，另一些模型可能在地块（plot）尺度运行。每个模型可以（如有需要）访问其本尺度以及其他尺度的变量，从而得到对系统更全面的表现。这种方法还可以帮助识别在单一层次下难以发现的新兴特征。

例如，可以在叶尺度下采用光合模型，与在植株尺度下的碳分配模型结合，以模拟植物的生长与发育。又如，模拟森林的能量平衡时，既需要针对植物的每一种器官类型的模型，也需要土壤层面的模型，最后还需有一个整合所有模型的地块（plot）尺度模型。

当进行多尺度模拟（即包含在植物不同器官层级上运行的模型）时，用户需要额外提供信息，以指明模型运行所需的尺度。由于有些模型在不同器官层级间复用，因此有必要说明每个模型所作用的器官（尺度）是什么。

这正是多尺度模拟会用到“映射（mapping）”结构的原因：单尺度示例中的 ModelList 没有办法将模型绑定到具体的植物器官，而那些更灵活的模型可以在多处被用到。用户还需要说明模型间如何跨尺度交互，比如输入变量若来自其他尺度，则必须指明其映射自哪个尺度。

你可以在这里了解作为用户针对单尺度与多尺度模拟的实际差异：[多尺度建模的注意事项](@ref)。

!!! note
    当你遇到“单尺度模拟”（Single-scale simulations）或“ModelList 模拟”这样的术语时，它们均指“不具备多尺度映射的模拟”。多尺度模拟使用了器官/尺度之间的映射；而单尺度模拟则没有这种映射，仅使用更简单的 ModelList 接口。当然，你完全可以实现一个仅包含单一尺度层级的映射，这可称为“单尺度的多尺度模拟”。但**除非特别说明，单尺度以及所有关于单尺度模拟的章节默认均指的是 ModelList 对象及无映射结构的模拟。**

### 多尺度树图（MTG, Multi-scale Tree Graphs）

![禾本科植物及其等价 MTG](../www/Grassy_plant_MTG_vertical.svg)

一个禾本科植物与对应的 MTG

多尺度树图（Multi-scale Tree Graphs，简称 MTG）是一种用于表示植物结构的数据结构。有关 MTG 格式与属性的详细介绍，请参考 [MultiScaleTreeGraph.jl 软件包文档](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/the_mtg/mtg_concept/)。

多尺度模拟可以直接在 MTG 对象上操作；随着植物生长、产生新器官，将会向 MTG 添加对应的新节点。

你可以在 REPL 中直接输入 MTG 的变量名，获得其基本的信息展示：

![在 PlantSimEngine 中 MTG 展示的例子](../www/MTG_output.png)

!!! note
    另一个配套包 [PlantGeom.jl](https://github.com/VEZY/PlantGeom.jl) 也可以通过 .opf 文件（对应 [Open Plant Format](https://amap-dev.cirad.fr/projects/xplo/wiki/The_opf_format_(*opf))，用于计算机上描述植物的另一种格式）来创建 MTG 对象。

#### 尺度 / 符号（symbol）术语的混淆

多尺度树图（MTG）中的一些术语与 PlantSimEngine 不完全相同（参见 [器官 / 尺度（Organ/Scale）](@ref)）：

- MTG 节点的 **symbol（符号）** 指代像 "Plant"、"Root"、"Scene" 或 "Leaf" 这样的实体。它对应 PlantSimEngine 中的 *尺度*，与 Julia 语言中 `:var` 这种符号类型没有关系。
- MTG 节点的 **scale（尺度）** 是传递给 Node 构造器的一个整数，用于描述树图对象的描述层级。它与 symbol（或 PlantSimEngine 的尺度）通常不是一一对应的，但二者是类似的概念。

![MTG 上的三级尺度，与 PlantSimEngine 中尺度概念不同](../www/Grassy_plant_scales.svg)

你可以在 [这里](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/the_mtg/mtg_concept/#Node-MTG-and-attributes) 找到对 MTG 概念的简要介绍。

另外，某些词在不同语境下也常被复用且含义不同：比如 tree/leaf/root 在谈论计算机科学数据结构（如图、依赖图、树结构）时意义与生物学不同。

!!! note
    在绝大多数情况下，你可以假定带有 “tree（树）” 的术语指的是生物学意义上的树，"organ（器官）" 指的是植物器官，而 “single-scale（单尺度）”、“multi-scale（多尺度）” 以及 “scale（尺度）” 则指的是 PlantSimEngine 中 [器官 / 尺度（Organ/Scale）](@ref) 章节介绍的尺度概念。MTG 对象一般以每个节点（指图中的节点，不是生物学器官节点）为操作单元进行处理。仅当模型涉及 MTG 遍历相关函数时，才通常会用到计算机科学里数据结构的术语。

#### TLDR

总结如下：

- 在 PlantSimEngine 中，"尺度" 指的是用名称（`String`）定义的描述层级；而在 MTG 中，"尺度" 是一个表示节点描述层级的整数，"符号（symbol）" 是该节点的名称。因此，MTG 中的 symbol 通常等价于 PlantSimEngine 中的 scale；
- “节点（node）”一词总是指多尺度树图（MTG）中的节点，而不是植物学意义上的“节”。

### 状态机

状态机是建模各种机制和装置的经典计算模型，这一点对于你的模拟也许有参考价值。

![State machine image](../www/Turnstile_state_machine_colored.svg.png)
一个简单的状态机。更多示例可参见 [维基百科页面](https://en.wikipedia.org/wiki/Finite-state_machine)。

状态机可以用于描述器官的状态：在 [XPalm.jl](https://github.com/PalmStudio/XPalm.jl)（一个基于 PlantSimEngine 建模油棕榈的包）中，部分器官有一个类似状态机的 `state` 变量，用于表示该器官是否为成熟、已修剪、开花等状态。

你可以在 XPalm 油棕 FSPM 的[此处](https://github.com/PalmStudio/XPalm.jl/blob/main/src/plant/phytomer/phytomer/state.jl)找到一个根据器官年龄和积温对 `state` 变量进行改变的模型示例（以及其他类似模型）。
