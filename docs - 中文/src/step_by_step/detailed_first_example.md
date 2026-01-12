# [简单模拟的详细演示](@id detailed-walkthrough-of-a-simple-simulation)

本页面将带您深入了解一个基础模拟案例，主要面向编程经验较少的用户，目的是结合先前介绍的概念，展示在具体情境下进行模拟所需的各项要素。

在本页面下方的[示例模拟](@ref)小节可以找到一个经过简化的可运行脚本，其它小节详细说明了设置、辅助函数和如何查询输出结果。

如果您只是想复制粘贴范例并做些尝试，可以直接前往[快速示例](@ref)页面查阅多个案例。

```@setup usepkg
using PlantSimEngine, PlantMeteo
using PlantSimEngine.Examples
meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)
leaf = ModelList(Beer(0.5), status = (LAI = 2.0,))
out_sim = run!(leaf, meteo)
```

```@contents
Pages = ["detailed_first_example.md"]
Depth = 3
```

## 环境准备

在本手册涉及的所有脚本中，您都需要一个已安装 PlantSimEngine 的正常 Julia 环境，通常还需添加若干配套包。具体安装与运行方法详见[PlantSimEngine 的安装与运行](@ref)页面。

## 基本概念

### 过程 (Processes)

在本包中，“过程”定义了某种生物或物理现象。可以将其类比为系统中发生的各种活动，如：光截获、光合作用、水分交换、碳与能量流、生长、产量，乃至太阳能电池板发电等。

“声明”一个过程意味着我们对其做出定义，并实现对应的模型用于模拟。在本例中，我们使用了已定义好并实现了对应模型的过程。

### 模型（ModelList）

每个过程都需要通过特定的实现方式——即**模型**（model）来进行模拟。每个模型都通过一个结构体来实现，并在结构体中列出了该模型的参数。例如，PlantBiophysics 包提供了[`Beer`](https://vezy.github.io/PlantBiophysics.jl/stable/functions/#PlantBiophysics.Beer)结构体，用于实现描述光衰减的 Beer-Lambert 定律。在本包中，`light_interception`（光截获过程）及其所用的 `Beer` 模型，也作为示例脚本包含在[`examples/Beer.jl`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/master/examples/Beer.jl)文件中。

模型可包含如下内容：

- 参数（Parameters）
- 气象信息（Meteorological information）
- 变量（Variables）
- 常量（Constants）
- 额外信息（Extras）

**参数** 是模型内部用于计算输出的常量，仅在该模型内部使用。  
**气象信息** 由用户提供，作为模型输入，定义每个时间步的环境条件，`PlantSimEngine.jl` 会自动为每个时间步应用这些信息。  
**变量** 包含模型所用或计算得到的数据，可选地在模拟前初始化。变量可以在多个模型中流转——由一个模型计算，再被另一个模型使用；也可以作为全局输出或在模拟开始时由用户指定。  
**常量** 是常量参数，通常为各模型公用，如气体常数等。  
**额外信息（extras）** 可作为模型备用信息或者做为内部数据的占位。

用户需声明用于模拟的一组模型，以及每个模型所需的参数和应初始化的变量。其操作结构为[`ModelList`](@ref)。

例如，下面通过 `ModelList` 结构体声明一个仅含 Beer-Lambert 光截获模型的模型组。该模型由 [`Beer`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/master/examples/Beer.jl) 结构实现，并且只含一个参数——消光系数（`k`）。

导入主包：

```@example usepkg
using PlantSimEngine
```

再导入[`Examples`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples)子模块中定义的示例（如 `light_interception` 和 `Beer`）：

```julia
using PlantSimEngine.Examples
```

然后，使用 `Beer` 模型来声明一个 [`ModelList`](@ref) ：

```@example usepkg
m = ModelList(Beer(0.5))
```

发生了什么？我们把 `Beer` 模型的实例提供给了 `ModelList`，用以模拟光截获过程。

## 参数（Parameters）

参数（Parameter）是在模型内部用于模拟计算且在模拟过程中保持不变的数值。例如，Beer-Lambert 模型使用消光系数（`k`）来计算光的衰减。具体来说，Beer-Lambert 模型实现中的 `Beer` 结构体只有一个字段：`k`。我们可以通过对模型结构体使用 `fieldnames` 来查看这一点：

```@example usepkg
fieldnames(Beer)
```

## 变量（Variables，输入与输出）

变量可作为模型的输入或输出（即被模型计算得到）。变量及其数值都存储在[`ModelList`](@ref)结构体中，可以自动或手动初始化。

例如，`Beer` 模型需要叶面积指数 (`LAI`, m²/m²) 作为输入。

可使用 [`inputs`](@ref) 查看模型的输入变量：

```@example usepkg
inputs(Beer(0.5))
```

用 [`outputs`](@ref) 可以查看模型的输出变量：

```@example usepkg
outputs(Beer(0.5))
```

[`ModelList`](@ref) 会在模拟运行期间维护每个变量的当前状态，保存在字段 `status` 中。我们可以利用 [`status`](@ref) 函数查看，例如本例中可见两个变量：`LAI` 和 `aPPFD`。前者为输入，后者为输出。

```@example usepkg
m = ModelList(Beer(0.5))
keys(status(m))
```

要确定哪些变量需要初始化，可用[`to_initialize`](@ref)：

```@example usepkg
m = ModelList(Beer(0.5))
to_initialize(m)
```

这些变量尚未初始化（因此会出现警告）：

```@example usepkg
(m[:LAI], m[:aPPFD])
```

未初始化变量的初值由模型代码中的 [`inputs`](@ref) 或 [`outputs`](@ref) 方法赋予，通常等于类型的最小值，比如 `Float64` 类型的 `-Inf`。

!!! tip
    推荐使用[`to_initialize`](@ref) 而不是 [`inputs`](@ref) 检查应初始化哪些变量。前者只返回**需要且未初始化**的变量，后者则返回模型需要的所有输入变量。在多模型耦合场景下，有些输入实际可由其它模型计算而无需初始化。

初始化变量时，可在声明 ModelList 时直接赋值：

```@example usepkg
m = ModelList(Beer(0.5), status = (LAI = 2.0,))
```

也可在实例化后用 [`init_status!`](@ref) 赋值：

```@example usepkg
m = ModelList(Beer(0.5))

init_status!(m, LAI = 2.0)
```

可调用[`is_initialized`](@ref) 检查组件是否正确初始化：

```@example usepkg
is_initialized(m)
```

有些变量作为输入参数，但实际上由其它模型输出。当多个模型耦合时，[`to_initialize`](@ref) 只会请求未被其他模型计算的变量。

## 气象驱动（Climate forcing）

进行模拟时一般需要测量对象或组件周围的气象条件。

强烈推荐配合使用 [`PlantMeteo.jl`](https://github.com/PalmStudio/PlantMeteo.jl) 包，其内置高效的数据结构与预处理功能，可便捷管理气象数据。该包的基本气象结构体叫 [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere)，表示稳态（平衡）大气条件。若有多个时间步数据，可用 [`TimeStepTable`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.TimeStepTable)。

声明 [`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere) 时必须指定如下变量：`T`（气温℃）、`Rh`（相对湿度0-1）、`Wind`（风速m/s）。在本例中还需给出光合有效辐射通量（`Ri_PAR_f`, W/m²）。示例如下：

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)
```

上述例子中，`meteo` 就是可用于模拟的单一气象时段数据。

更多细节可查看[包文档](https://vezy.github.io/PlantMeteo.jl/stable)。

## 模拟

### 过程模拟

运行模拟时，可在 [`ModelList`](@ref) 上调用 [`run!`](@ref) 方法。如需输入多步气象数据，也可将其作为可选参数传入。

调用方式如下：

```julia
run!(model_list, meteo)
```

第一个参数是模型组（见[`ModelList`](@ref)），第二个参数是微气候条件。

调用前应确保[`ModelList`](@ref) 已为该过程完成初始化，可回顾前述[输入与输出](@ref)部分。

### 示例模拟

例如，下面模拟单片叶片的“光截获”过程：

```@example usepkg
using PlantSimEngine, PlantMeteo

# 导入 `Examples` 子模块中的示例
using PlantSimEngine.Examples

meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)

leaf = ModelList(Beer(0.5), status = (LAI = 2.0,))

outputs_example = run!(leaf, meteo)

outputs_example[:aPPFD]
```

### 输出

[`ModelList`](@ref) 的[`status`](@ref) 字段，用于在模拟前初始化变量，也能实时追踪模拟过程中及最后的变量取值。调用 [`status`](@ref) 可获得最终时间步的输出结果。

而 [`run!`](@ref) 方法返回的是完整的模拟所有步长的输出数据。通常输出采用 `PlantMeteo.jl` 的 [`TimeStepTable`](@ref) 结构（类似 DataFrame，但每行为一个 [`Status`](@ref)），当然也支持 `Tables.jl` 的其它结构如常规 DataFrame。气象数据同理，默认也支持 [`TimeStepTable`](@ref)，每行为一个 `Atmosphere`。

本例只用了单一气象时段，因此 [`run!`](@ref) 返回值和模型组的 [`status`](@ref) 字段内容相同。

现在查看前面叶片模拟的输出结构：

```@setup usepkg
outputs_example
```

可用索引读取具体变量的值，比如截获的光合有效光：

```@example usepkg
outputs_example[:aPPFD]
```

也可以用点语法读取：

```@example usepkg
outputs_example.aPPFD
```

您可以将输出打印、转为其它格式或用 Julia 其它绘图库直接可视化。具体方法请参考[输出和数据可视化](@ref)页面。

另一种便捷输出方法是将结果转为 DataFrame，因为 [`TimeStepTable`](@ref) 实现了 Tables.jl 接口，这非常容易：

```@example usepkg
using DataFrames
convert_outputs(outputs_example, DataFrame)
```

## 模型耦合

模型既可单独工作，也可联合运行。例如气孔导度模型通常与光合模型耦合使用（由光合模型调用）。

PlantSimEngine.jl 特别设计以方便建模与用户无痛实现模型耦合。更多详细说明请参阅[标准模型耦合](@ref)、[耦合更复杂的模型](@ref)，以及[多尺度环境下的依赖关系处理](@ref)。
