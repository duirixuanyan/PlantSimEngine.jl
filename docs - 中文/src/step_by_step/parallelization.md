## 并行执行

!!! note
    本页内容可能会变动且随着时间变得不再适用。目前，并行执行只适用于单尺度模拟（多尺度模拟因MTG结构随步骤变动及额外复杂性，目前尚不支持直接并行化）

### FLoops

`PlantSimEngine.jl` 使用 [`FLoops`](https://juliafolds.github.io/FLoops.jl/stable/) 包以顺序、并行（多线程）或分布式（多进程）方式对对象、时间步、独立进程进行计算和模拟。

这意味着你可以向[`run!`](@ref)的`executor`参数提供任何兼容的执行器。默认情况下，[`run!`](@ref) 使用 [`ThreadedEx`](https://juliafolds.github.io/FLoops.jl/stable/reference/api/#executor) 执行器（多线程执行器）。你也可以使用 [`SequentialEx`](https://juliafolds.github.io/Transducers.jl/dev/reference/manual/#Transducers.SequentialEx) 顺序执行（非并行），或使用 [`DistributedEx`](https://juliafolds.github.io/Transducers.jl/dev/reference/manual/#Transducers.DistributedEx) 实现分布式计算。

### 并行特性（trait）

`PlantSimEngine.jl` 通过 [Holy traits](https://invenia.github.io/blog/2019/11/06/julialang-features-part-2/)机制定义某个模型是否可以并行运行。

!!! note
    如果模型在不同时间步之间没有读取或设置其他时间步的值，则可以在时间步上并行；如果模型在对象之间没有读取或设置其他对象的值，则可以在对象上并行。

你可以通过为时间步和对象定义特性（trait），声明模型可并行执行。例如，[examples 文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/tree/main/examples)中的 ToyLAIModel 模型可以在时间步和对象维度并行运行，因此它定义如下特性：

```julia
PlantSimEngine.TimeStepDependencyTrait(::Type{<:ToyLAIModel}) = PlantSimEngine.IsTimeStepIndependent()
PlantSimEngine.ObjectDependencyTrait(::Type{<:ToyLAIModel}) = PlantSimEngine.IsObjectIndependent()
```

默认情况下，所有模型都被认为不可并行执行，这是最安全的选择以避免难以察觉的bug。因此，只有需要并行执行的模型才需主动定义这些特性。

!!! tip
    被声明为可并行执行的模型实际上未必会并行。首先，用户需要将并行执行器（如 `ThreadedEx`）传递给[`run!`](@ref)。其次，如果该模型与其他不可并行执行的模型耦合，`PlantSimEngine` 将以顺序方式运行所有模型。

### 其他执行器

你还可以了解 [FoldsThreads.jl](https://github.com/JuliaFolds/FoldsThreads.jl)（更多基于线程的执行器）、[FoldsDagger.jl](https://github.com/JuliaFolds/FoldsDagger.jl)（基于 Dagger.jl 框架、兼容 Transducers.jl 的并行归约）、即将发布的 [FoldsCUDA.jl](https://github.com/JuliaFolds/FoldsCUDA.jl)（用于GPU计算，见[相关 issue](https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues/22)）、及 [FoldsKernelAbstractions.jl](https://github.com/JuliaFolds/FoldsKernelAbstractions.jl)。你还可以查阅 [ParallelMagics.jl](https://github.com/JuliaFolds/ParallelMagics.jl)，判断是否能自动并行化。

最后，你可以查阅 [Transducers.jl 的文档](https://github.com/JuliaFolds/Transducers.jl)获取更多信息。如果你不清楚什么是"executor"，可参见[本说明](https://juliafolds.github.io/Transducers.jl/stable/explanation/glossary/#glossary-executor)。
