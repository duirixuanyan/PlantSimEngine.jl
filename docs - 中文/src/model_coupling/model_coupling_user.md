# 用户使用的模型耦合

```@setup usepkg
using PlantSimEngine, PlantMeteo
# 导入 `Examples` 子模块中定义的示例模型:
using PlantSimEngine.Examples

m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    Process7Model(),
)
```

`PlantSimEngine.jl` 的设计目标是让模型耦合对模型开发者和用户都变得简单。例如，`PlantBiophysics.jl` 实现了 [`Fvcb`](https://vezy.github.io/PlantBiophysics.jl/stable/functions/#PlantBiophysics.Fvcb) 模型以模拟光合作用过程。该模型需要气孔导度过程来参与模拟，因此在其实现过程中会再次调用 `run!`。请注意，这里并不强制要求某一种特定的导度模型，而只要求有一个导度模型即可，这样用户可以根据实际需求选择用哪种模型来进行模拟，与所选用的光合模型无关。

我们在 [`examples/dummy`](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/dummy.jl) 提供了一个示例脚本，实现了七个虚拟过程。过程名称依次为 "process1", "process2"……，相应的模型实现为 `Process1Model`, `Process2Model`…… 

## 硬耦合模型（Hard Coupling）

`Process3Model` 会调用 `Process2Model`，而 `Process2Model` 又会调用 `Process1Model`。在 PlantSimEngine 中，这种显式的调用关系称为“硬依赖（hard-dependency）”。

余下的几个过程的模型分别为 `Process4Model`, `Process5Model` ……，它们在运行时并不会显式地调用其它模型，但它们的部分输出会被其他模型作为输入，这种被称为“软依赖（soft-dependency）”。

!!! tip
    模型的硬耦合通常用于某些模型之间存在迭代型计算、相互依赖的情况。本示例其实非常简单，这里并不需要这样的耦合，模型完全可以按顺序依次调用。对于更具代表性的例子，参见 `PlantBiophysics.jl` 中的 Monteith 能量平衡计算，它与光合模型存在硬耦合。

回到我们的示例，使用 `Process3Model` 时需要有 "process2" 模型，这里我们只有一个实现：`Process2Model`。后者同样要求有 "process1" 模型，而当前实现中也仅有 `Process1Model`。

让我们用一下 `Examples` 子模块看看效果：

```julia
# 导入在 `Examples` 子模块中定义的示例模型：
using PlantSimEngine.Examples
```

!!! tip
    使用 `subtypes(x)` 可以了解某个过程可用的模型类型。例如，对于 "process1"，可以使用 `subtypes(AbstractProcess1Model)` 查询。

下面展示如何进行模型耦合：

```@example usepkg
m = ModelList(Process1Model(2.0), Process2Model(), Process3Model())
nothing # hide
```

可以看到，只有第一个模型有参数。通常可以通过查看结构体的帮助信息（例如 `?Process1Model`）来了解参数情况，或者也可以通过 `fieldnames(Process1Model)` 查看结构体的字段名称。

注意，用户只需要声明要用的模型，而不需要声明模型之间的耦合方式，因为 `PlantSimEngine.jl` 会自动处理这些耦合关系。

在上面的例子中，系统会返回一些警告，提示需要初始化一些变量：`var1` 和 `var2`。`PlantSimEngine.jl` 会根据所有模型的输入输出变量（包括硬依赖和软依赖）自动推断需要初始化哪些变量。

例如，`Process1Model` 需要以下变量作为输入：

```@example usepkg
inputs(Process1Model(2.0))
```

`Process2Model` 需要以下变量作为输入：

```@example usepkg
inputs(Process2Model())
```

我们可以看到，`var1` 在这两个模型中都需要作为输入变量，同时我们也注意到 `var3` 是 `Process2Model` 的输出变量：

```@example usepkg
outputs(Process2Model())
```

所以考虑到这两个模型，我们只需要初始化 `var1` 和 `var2`，因为 `var3` 会被模型计算得出。这也是我们推荐使用 [`to_initialize`](@ref) 而不是 [`inputs`](@ref) 的原因，`to_initialize` 只返回真正需要初始化的变量。因为某些输入变量在多个模型中重复，同时有的输入变量实际上是由其它模型计算得出的（即它们是其他模型的输出）：

```@example usepkg
m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    variables_check=false # 只是为了不打印出警告信息
)

to_initialize(m)
```

最直接初始化模型列表的方法，就是在实例化时通过 `status` 关键字参数传递初始变量：

```@example usepkg
m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    status = (var1=15.0, var2=0.3)
)
nothing # hide
```

我们的组件模型结构现在已经被完全参数化，并且为模拟做好了初始化！

让我们来进行一次模拟：

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

run!(m, meteo)

m[:var5]
```


## 软耦合模型

接下来的所有模型（`Process4Model` 到 `Process7Model`）在运行时不会显式调用其他模型，但部分模型的输出会作为其他模型的输入。在 PlantSimEngine 中，这被称为软依赖（soft-dependency）。

让我们创建一个包含这些软耦合模型的新模型列表：

```@example usepkg
m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    Process7Model(),
)
nothing # hide
```

在这个模型列表中，我们只需要初始化 `var0`，它是 `Process4Model` 和 `Process7Model` 的输入：

```@example usepkg
to_initialize(m)
```

我们可以如下进行初始化：

```@example usepkg
m = ModelList(
    Process1Model(2.0), 
    Process2Model(),
    Process3Model(),
    Process4Model(),
    Process5Model(),
    Process6Model(),
    Process7Model(),
    status = (var0=15.0,)
)
nothing # hide
```

让我们来进行一次模拟：

```@example usepkg
using PlantMeteo
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

run!(m, meteo)

status(m)
```

## 仿真执行顺序

当调用 `run!` 时，模型会根据它们之间的强依赖和软依赖关系，自动建立依赖图并依照以下规则顺序执行：

1. 首先运行独立的模型。一个模型是独立的，如果它可以单独运行，或只依赖初始值，即没有依赖其他模型。
2. 按其子节点依赖关系执行：
   1. 总是优先运行强依赖。内部的强依赖关系图会整体被视为一个软依赖（即作为一个整体去处理软依赖）。
   2. 然后依次运行软依赖。如果某个软依赖有多个父节点（即它所需的输入由多个模型计算），只有在所有父节点都已经被执行过后才会运行该节点。实际上，当访问一个节点时，如果它有某个父节点还未执行，则会暂停遍历该分支，直到从最后一个被运行的父节点分支重新访问到该节点时才执行。
