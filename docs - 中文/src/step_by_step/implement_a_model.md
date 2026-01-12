# [实现一个模型](@id model_implementation_page)

```@setup usepkg
using PlantSimEngine
@process "light_interception" verbose = false
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end
```

在你自己的模拟中，你可能会希望在某个阶段不仅仅是使用现有的模型，而是实现你自己的模型。本页将介绍编写新模型所需的步骤。后面有针对编程不太熟悉者的详细版本。

## 快速指南

声明一个新的过程：

```julia
@process "light_interception" verbose = false
```

声明你的模型结构体及其参数：

```@example usepkg
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end
```

为该模型声明 `inputs_` 和 `outputs_` 方法（注意下划线，这些方法与 `inputs` 和 `outputs` 不同）：

```@example usepkg
function PlantSimEngine.inputs_(::Beer)
    (LAI=-Inf,)
end

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end
```

编写针对单步运行的 [`run!`](@ref) 函数：

```@example usepkg
function run!(::Beer, models, status, meteo, constants, extras)
    status.PPFD =
        meteo.Ri_PAR_f *
        exp(-models.light_interception.k * status.LAI) *
        constants.J_to_umol
end
```

判断是否可以并行化，以及需要声明哪些特征：

```@example usepkg
PlantSimEngine.ObjectDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsObjectIndependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsTimeStepIndependent()
```

对于这个包含单个参数且没有依赖关系的示例，以上这些就足够了。

[`@process`](@ref) 宏会自动实现一些样板代码，详见[这里](@ref under_the_hood)。

你还可以实现一些额外的工具函数来方便用户使用，详情参见[模型实现补充说明](@ref)页面。
如果你的自定义模型需要处理比本例更复杂的输入输出耦合，请参阅[耦合更复杂的模型](@ref)页面。

## 详细版本

`PlantSimEngine.jl` 的设计初衷是让新的模型实现变得非常简单。让我们通过一个简单的示例来学习如何实现你自己的模型：实现一个新的光截获（light interception）模型。

我们要（重新）实现的模型已经作为示例模型包含在 `Examples` 子模块中。你可以从这里获取该脚本：[examples/Beer.jl](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/Beer.jl)。这个模型也可以在 `PlantBioPhysics.jl` 包中找到。

你可以通过 `using` 命令将该模型和 PlantSimEngine 的其他示例模型导入你的环境中：

```julia
# 导入 `Examples` 子模块中定义的示例模型:
using PlantSimEngine.Examples
```

## 其他示例

`PlantSimEngine` 的其他简单模型可以在 [examples 文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples) 中找到。

更多示例模型可以参考 [`PlantBiophysics.jl`](https://github.com/VEZY/PlantBiophysics.jl) 的代码。例如，你可以在那里找到一个光合作用模型（`FvCB`），实现代码在 [src/photosynthesis/FvCB.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/photosynthesis/FvCB.jl)；还有一个能量平衡模型，其 `Monteith` 实现在 [src/energy/Monteith.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/energy/Monteith.jl)；或者气孔导度模型在 [src/conductances/stomatal/medlyn.jl](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/conductances/stomatal/medlyn.jl)。

## 基本需求

如果你查看这些示例模型，你会发现要实现一个新的模型，你需要实现如下内容：

- 一个结构体：用于存储参数值并实现方法多分派
- 实际的模型本体：作为“过程”对应的方法来实现
- 一些辅助函数：供包内和/或用户调用

## 示例：比尔-朗伯（Beer-Lambert）模型

### 过程定义

我们首先使用 [`@process`](@ref) 宏在第 7 行声明光截获过程：

```julia
@process "light_interception" verbose = false
```

关于其工作原理及用法的详细说明，请参见 [实现一个新过程](@ref) 页面。

### 结构体定义

要实现一个模型，首先要定义一个结构体。这个结构体有两个主要作用：

- 存储参数值
- 派发到对应的 [`run!`](@ref) 方法

模型结构体（或类型）的定义如下：

```@example usepkg
struct Beer{T} <: AbstractLight_InterceptionModel
    k::T
end
```

第一行定义了模型的名称（`Beer`）。按照惯例，模型名建议采用驼峰命名法，即每个单词首字母大写且不带分隔符，如 `LikeThis`。

`Beer` 结构体被定义为 `AbstractLight_InterceptionModel` 的子类型，表明该模型模拟的是哪一种过程。在定义 "light_interception" 过程时，`AbstractLight_InterceptionModel` 类型会被自动创建。

我们可以从模型声明推断出，`Beer` 是用于模拟光截获过程的模型。

接下来是参数名及其类型的说明。

### 用户自定义类型与参数化类型

这里有一些 Julia 语言的特性，可以让用户在模拟中传递自己定义的类型。

- `Beer` 是一个参数化（泛型）的 `struct`，这通过 `{T}` 注解体现。
- 结构体中的参数 `k` 的类型由 `::T` 指定，这里的 `T` 就是类型参数。

`T` 只是一个任意的字母。如果你的参数有多个、可能属于不同的类型，可以为每个参数指定不同的类型，也可以为其分别参数化，比如再引入一个字母，例如：

```julia
struct CustomModel{T,S} <: AbstractLight_InterceptionModel
    k::T
    x::T
    y::T
    z::S
end
```

参数化类型非常实用，因为它们让用户可以自由选择参数的类型，甚至可以在运行时随需改变。例如，用户可以来自 [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) 的 `Particles` 类型，实现模拟过程中自动的不确定性传播。关于参数化类型的更多信息，推荐查阅[模型实现补充说明](@ref)页面的[参数化类型](@ref)小节。

### 输入与输出

在实现一个新模型时，必须声明该模型所需的变量，包括作为输入变量（输入到模型中）和每个时间步计算产生的输出变量。输入变量可以由用户在 `Status` 对象中初始化，也可以由其他模型提供。输出变量可以作为整体模拟的输出，或被其他模型使用。

以本例的 `Beer` 光截获模型为例，它有一个输入变量和一个输出变量：

- 输入：`:LAI`，叶面积指数（单位：m² m⁻²）
- 输出：`:aPPFD`，光合有效光子通量密度（单位：μmol m⁻² s⁻¹）

我们通过给 [`inputs`](@ref) 和 [`outputs`](@ref) 函数添加方法来声明这些输入/输出。这些函数以模型类型作为参数，返回一个 `NamedTuple`，变量名称为键，默认值为值：

```@example usepkg
function PlantSimEngine.inputs_(::Beer)
    (LAI=-Inf,)
end

function PlantSimEngine.outputs_(::Beer)
    (aPPFD=-Inf,)
end
```

这些函数是内部函数，以下划线“_”结尾。用户实际使用 [`inputs`](@ref) 和 [`outputs`](@ref) 来查询模型变量。

### run! 方法

当使用 [`run!`](@ref) 运行模拟时，每一步的每个模型会按模型列表（ModelList）和当前状态（Status）所确定的顺序依次运行。每个模型都实现了 [`run!`](@ref) 方法，用于在每个时间步更新模拟状态。该函数有六个参数：

```julia
function run!(::Beer, models, status, meteo, constants, extras)
```

- 模型的类型
- models：一个 [`ModelList`](@ref) 对象，包含了模拟中的所有模型
- status：一个 [`Status`](@ref) 对象，包含当前时间步变量的值（即状态），例如此时刻植物的 LAI
- meteo：（通常）一个 `Atmosphere` 对象，或气象数据的一行，包含当前时间步的气象变量值（如该时间步的 PAR）
- constants：一个 `Constants` 对象或 `NamedTuple`，包含模拟中用到的常数（如斯特藩-玻尔兹曼常数，单位转换常数等）
- extras：可传递给模型的其他任何对象，主要用于高级应用，这里不做介绍

因此，典型的 [`run!`](@ref) 函数可以利用模拟常量、通过 [`Status`](@ref) 对象访问的输入/输出变量，或气象数据。

以下是基于 [`ModelList`](@ref) 组件模型的光截获 [`run!`](@ref) 方法实现。注意输入输出变量通过 [`status`](@ref) 参数访问：

```@example usepkg
function run!(::Beer, models, status, meteo, constants, extras)
    status.PPFD =
        meteo.Ri_PAR_f *
        exp(-models.light_interception.k * status.LAI) *
        constants.J_to_umol
end
```

### 补充说明

要使用此模型，用户需要确保该模型涉及的变量已经在 [`Status`](@ref) 对象、气象数据和 `Constants` 对象中定义。

!!! 注意
    [`Status`](@ref) 对象包含了模拟当前时间步的全部状态。默认情况下，无法直接访问早期时间步的变量，除非你编写了自定义模型以实现这一目标。

模型的参数可以通过 [`ModelList`](@ref) 并利用传入的 `models` 参数获得。可通过进程名称以及参数名称索引。例如，`Beer` 模型的 `k` 参数可以通过 `models.light_interception.k` 获取。

!!! 警告
    你需要导入所有要扩展的方法，这样 Julia 才会识别你是在为 PlantSimEngine 的函数添加方法，而不是在定义一个新的同名函数。为此，可以在函数前加上包名前缀，或者提前手动导入，例如：`import PlantSimEngine: inputs_, outputs_`。查看排错子章节 [实现新模型时：忘记导入函数或加上模块前缀](@ref) 可以看到忘记加前缀时可能导致的输出报错。

### 并行化特性

`PlantSimEngine` 提供了 traits（特性）机制，用以告知模型的更多信息。目前，实现了两种并行特性：模型是否可以在空间维度（如不同对象）或时间维度（如不同时间步）并行运行。

默认情况下，为保证安全，所有模型都**不**假定可在对象或时间步上并行。如果你的模型可以并行计算，建议为其添加相应的特性。

例如，如果我们要为 `Beer` 模型添加“对象无依赖”的并行特性，可以这样写：

```@example usepkg
PlantSimEngine.ObjectDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsObjectIndependent()
```

如果我们要为 `Beer` 模型添加“时间步无依赖”的并行特性，可以这样写：

```@example usepkg
PlantSimEngine.TimeStepDependencyTrait(::Type{<:Beer}) = PlantSimEngine.IsTimeStepIndependent()
```

!!! 注意
    当一个模型的计算代码内部未直接调用其他模型时，说明它可以在对象间并行；同样，未直接调用其他时间步的变量时，说明它可以在时间步间并行。实际上，大多数模型总能以某种方式并行，但出于安全，默认假定它们不可并行。

好了！到此为止，针对光截获过程，我们已经实现了一个完整的新模型！其他模型或许会有更复杂的计算逻辑或耦合方式，但实现思路是一致的。

### 依赖关系

如果你的模型在实现时**显式调用了其它模型**，则需要明确告知 PlantSimEngine。这称为“硬依赖”关系，与之相对的“软依赖”是指模型仅使用另一模型输出的变量，但没有直接调用对方。

要声明这样的依赖关系，需要为 [`dep`](@ref) 函数添加一个方法，告诉 PlantSimEngine 该模型运行时依赖于哪些过程（及其模型类型）。

本例中的模型没有直接调用其他模型，因此无需实现该方法。但我们可以参考 [`PlantBiophysics.jl`](https://github.com/VEZY/PlantBiophysics.jl/blob/d1d5addccbab45688a6c3797e650a640209b8359/src/processes/photosynthesis/FvCB.jl#L83) 中 [`Fvcb`] 的实现：

```julia
PlantSimEngine.dep(::Fvcb) = (stomatal_conductance=AbstractStomatal_ConductanceModel,)
```

这里，我们告诉 PlantSimEngine，在气孔导度（stomatal_conductance）过程中需要一个 `AbstractStomatal_ConductanceModel` 类型的模型，以供 `Fvcb` 模型运行时调用。

关于硬依赖的更多内容，可以参考[耦合更复杂的模型](@ref)。
