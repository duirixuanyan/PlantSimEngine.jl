# 提示与变通方法

## PlantSimEngine 正在积极开发中

尽管 PlantSimEngine 的代码库略显抽象，且目标是在模拟上具备一定通用性，但其设计基础依然贴近实际应用。我们确实希望能够适应多种类型的模拟，并尽量不对用户作过多限制。不过，大多数功能都是根据实际需求逐步开发的，其中不少是出于对油棕模型 [XPalm](https://github.com/PalmStudio/XPalm.jl) 这一日益复杂、细致实现的需要。

由于油棕模型仍在持续开发中，并且部分功能尚未在 PlantSimEngine 中实现，或者需要大规模重写（而我们不确定这样做是否值得，尤其是如果结果反而限制了代码库或用户的可操作性），因此偶尔会通过一些变通方法或者取巧手段来规避限制造成的问题。

此外，还有一些功能是为了方便快速原型开发，临时实现的“小黑客”方案，并非面向生产环境。

我们会在这里列出一些相关实例，未来也可能补充列出包的内在限制或隐性的设计预期。

```@contents
Pages = ["tips_and_workarounds.md"]
Depth = 2
```

## 多尺度模拟中利用历史状态的方法

在多尺度模拟中，可以通过映射 API（mapping API）中的 [`PreviousTimeStep`](@ref) 机制，获取变量在上一个仿真步（timestep）的值（事实上，正如其他部分所提，这也是打破模型耦合时出现环形依赖的默认方法，参见：[避免循环依赖](@ref)）。

但通过映射 API，目前无法获取距离当前时刻更早的历史时刻。例如，像 `PreviousTimeStep(PreviousTimeStep(PreviousTimeStep(:carbon_biomass)))` 这样的写法是不被支持的，请勿这样做。

如果确实需要访问更早的状态，可以写一个自定义模型，将所需的历史值存入数组或其他自定义变量中，每个时间步进行更新，并提供给其他需要用到这些历史信息的模型使用。

## 模型中变量不能同时作为输入和输出

PlantSimEngine 的一个现有限制是：不支持在同一个模型中，同时将某个变量作为输入和输出使用。

（相关说明：在同一尺度下，也无法存在两个同名变量，它们会被判定为同一个变量。）

原因在于，对于这种情况下模型间的依赖关系，系统无法自动判断依赖耦合如何处理。如果允许这样做，用户就必须显式声明多个模型之间的模拟顺序，而实现该功能也需要不少编程工作来扩展 PlantSimEngine 的 API。

我们目前还没有找到一种在代码简单性和 API 便利性之间都令人满意的解法。尤其在快速原型开发和不断添加新模型时，这种约束往往意味着需要针对相关变量重新指定模拟顺序，比较繁琐。

目前有两种变通方法：

- 一种可能略显笨拙的方式是：将其中一个变量重命名。这样虽然不能直接“开箱即用”某些预设模型，但避免了以上限制和复杂性。

- 在许多情形下，可以灵活使用 PlantSimEngine 已有的功能安排。

比如，[XPalm.jl](https://github.com/PalmStudio/XPalm.jl/blob/main/src/plant/phytomer/leaves/leaf_pruning.jl) 中有一个叶片修剪（leaf pruning）相关模型，会影响生物量。在理想情况下，可以将 `leaf_biomass` 变量同时作为输入和输出。而实际采用的方案，则是输出一个 `leaf_biomass_pruning_loss` 变量，在下一个时间步再以此作为输入来计算新的叶生物量。

又比如，Toy Plant 教程 [第 3 部分](../multiscale/multiscale_example_3.md) 中，碳库变量 `carbon_stock` 用于表示可用于根和节间生长的碳，但在模型编排中，并不是直接更新和传递该变量，而是让根生长决策模型先计算 `carbon_stock_updated_after_roots`，然后供节间增长模型使用。

这种设计改进既避免了模型间顺序的不确定性，也提高了代码的可读性，并充分体现了 PlantSimEngine 的的设计哲学。

## [多尺度：在指定层级的 mapping status 中传递向量](@id multiscale_vector)

!!! note
    本节内容较为高级，不推荐初学者使用

你可能已经注意到，在文档示例中，有时会将一个向量（一维数组）变量直接传递给 [`ModelList`](@ref) 的 [`status`](@ref) 组件（比如在累计温度的例子中：[模型切换](@ref)）。

这种做法适用于简单模拟或快速原型开发，可以避免为了此类参数专门编写模型。每次迭代时，相关模型会获得一个对应当前时间步的元素。

在多尺度模拟中，也支持这一特性，尽管不是主 API 的一部分。由于输出与状态变量的工作方式有所不同，这个小便利特性并不那么直接可以使用。

此功能较为脆弱，依赖不推荐的 Julia 元编程方式（如 `eval()`），对全局变量有操作，并且可能无法在 REPL 之外的环境中稳定工作，也没有针对复杂交互进行测试。因此在涉及不同尺度变量映射、奇特依赖结构的情况下可能出现问题。

由于实现细节上的原因，正确用法如下：

你需要调用 `replace_mapping_status_vectors_with_generated_models(mapping_with_vectors_in_status, timestep_model_organ_level, nsteps)` 这个函数，并作用在你的 mapping 上。

它会分析 mapping，生成自定义模型，在每个时间步存储并传递向量的值，并返回可用于模拟的新 mapping。此外，会自动插入两个内部模型用于向这些模型提供时间步索引（这意味着在 mapping 中会声明 `:current_timestep` 和 `:next_timestep` 这两个符号）。你可以通过 `timestep_model_organ_level` 参数指定这些模型所在的尺度/器官层级。参数 `nsteps` 作为校验，会要求你提供模拟的时间步数。

!!! warning
    只有 AbstractVector 的子类会被此机制处理。有时气象数据的向量需要类型转换。例如：
    ```
    meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
    status(TT_cu=cumsum(meteo_day.TT),)```

    cumsum(meteo_day.TT) actually returns a CSV.SentinelArray.ChainedVectors{T, Vector{T}}, which is not a subtype of AbstractVector. 
    Replacing it with Vector(cumsum(meteo_day.TT)) will provide an adequate type.
    ```

下面是一个用法示例，修正了 [将单尺度模拟转换为多尺度模拟](@ref) 的初步尝试：

```julia
using PlantSimEngine
using PlantSimEngine.Examples
using PlantMeteo, CSV, DataFrames
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 单尺度模拟的直接翻译
mapping_pseudo_multiscale = Dict(
"Plant" => (
   ToyLAIModel(),
    Beer(0.5),
    ToyRUEGrowthModel(0.2),
    Status(TT_cu=cumsum(meteo_day.TT),)
    ),
)

mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 0),)

# 在多尺度模拟中，直接将向量传递到 Status 会报错
#out_pseudo_multiscale_error = run!(mtg, mapping_pseudo_multiscale, meteo_day)

mapping_pseudo_multiscale_adjusted = PlantSimEngine.replace_mapping_status_vectors_with_generated_models(mapping_pseudo_multiscale, "Plant", PlantSimEngine.get_nsteps(meteo_day))

out_pseudo_multiscale_successful = run!(mtg, mapping_pseudo_multiscale_adjusted, meteo_day)

```

该功能在涉及未来计划引入的新特性（如多时间步模型混用等）的模拟中很可能失效，并且无法保证能及时修复。再次提醒，这主要是多尺度模拟原型开发时的便利捷径，使用时请注意风险。

## 单尺度仿真中的循环依赖问题

在单尺度仿真中有可能出现循环依赖的情况，但目前尚未支持 PreviousTimestep 功能。可以通过引入硬依赖进行处理，或者构建一个实际仅包含单一尺度的多尺度仿真作为替代方案。