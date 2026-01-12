# 实现一个新过程

```@setup usepkg
using PlantSimEngine
using PlantMeteo
PlantSimEngine.@process growth
```

## 引言

在本软件包中，"过程"用于定义某种生物或物理现象。你可以将过程理解为系统中发生的任何现象，比如光拦截、光合作用、水分、碳和能量通量、生长、产量，甚至太阳能电池板产生的电力等。

`PlantSimEngine.jl` 的设计使得新过程和模型的实现变得简单而迅速。下一节将通过一个简单示例（生长模型的实现）展示如何实现一个新的过程。

## 实现一个过程

过程需要先“声明”，也就是说我们需要先定义一个过程，然后才能为其实现相应的模型。声明过程会自动为该过程的仿真生成一些样板代码：

- 一个用于该过程的抽象类型
- 一个内部使用的 `process` 函数方法

这个抽象过程类型会作为所有与该过程相关的模型实现的超类型，其命名方式为 `Abstract<process_name>Process`，例如：`AbstractLight_InterceptionModel`。

幸运的是，PlantSimEngine 提供了一个宏 [`@process`](@ref)，可以一次性自动生成上述内容。这个宏只需要一个参数：过程名称。

例如，在 [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl) 中，光合作用过程的声明只需这样一句代码：

```julia
@process "photosynthesis"
```

如果我们想模拟植物的生长，可以添加一个名为 `growth` 的新过程：

```julia
@process "growth"
```

就是这样！注意，该函数还会引导你在创建过程后可以进行的后续步骤。

## 为过程实现一个新模型

在实现过程之后，你可以为该过程编写相应的模型实现。展示光拦截模型实现的教程页面可以在[这里](@ref model_implementation_page)找到。

本过程的完整模型实现可参见示例脚本 [ToyAssimGrowthModel.jl](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/ToyAssimGrowthModel.jl)。

## [幕后原理](@id under_the_hood)

`@process` 宏实际上只是用来减少样板代码的快捷方式。

你也可以不使用宏，手动定义一个过程：只需定义一个继承自 `AbstractModel` 的抽象类型：
```julia
abstract type AbstractGrowthModel <: PlantSimEngine.AbstractModel end
```
然后为 `process_` 函数增加一个方法，使其返回过程的名称：
```julia
PlantSimEngine.process_(::Type{AbstractGrowthModel}) = :growth
```

因此，在前面的例子中，我们创建了一个名为 `growth` 的新过程。这会自动定义一个名为 `AbstractGrowthModel` 的抽象结构体，它作为所有相关模型的超类型。抽象类型的命名规则是：把过程名称转换为首字母大写（使用 `titlecase()`），前面加 `Abstract`，后面加 `Model` 作为后缀。