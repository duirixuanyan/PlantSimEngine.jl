# 耦合更复杂的模型

```@setup usepkg
using PlantSimEngine, PlantMeteo
# 导入 `Examples` 子模块中定义的示例模型：
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

当两个或多个模型之间存在双向依赖关系（即变量不仅仅是单向从一个模型流向下一个模型，而是存在相互依赖时），我们称之为[硬依赖](@ref hard_dependency_def)。

这种依赖关系要求用户/建模者进行一些额外的设置，才能让 PlantSimEngine 自动生成正确的依赖图。

## 声明硬依赖关系

一个模型如果在其[`run!`](@ref)函数中显式直接调用了其他过程的[`run!`](@ref)函数，则它属于硬依赖关系（或称为硬耦合模型）。

让我们通过[examples/dummy.jl](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/dummy.jl)脚本中提供的示例过程和模型进行说明。

在这个脚本中，我们声明了七个过程和七个模型，每个过程对应一个模型。这些过程分别被称为“process1”、“process2”等，其模型实现分别为`Process1Model`、`Process2Model`等。

在执行时，`Process2Model`会显式调用其他过程的[`run!`](@ref)函数，因此必须将该过程定义为`Process2Model`的硬依赖。例如：

```julia
function PlantSimEngine.run!(::Process2Model, models, status, meteo, constants, extra)
    # 通过 process1 计算 var3：
    run!(models.process1, models, status, meteo, constants)
    # 计算 var4 和 var5：
    status.var4 = status.var3 * 2.0
    status.var5 = status.var4 + 1.0 * meteo.T + 2.0 * meteo.Wind + 3.0 * meteo.Rh
end
```

`Process2Model`与另一个过程（`process1`）耦合，并且调用了其模型的`run!`函数。被调用的[`run!`](@ref)函数参数与调用它的模型的[`run!`](@ref)参数完全相同，只是第一个参数需要传入希望模拟的过程对应的模型。

!!! note
    对于`process1`过程，模型类型是灵活的，并不强制为某一特定实现。这就是为何我们可以通过在[`ModelList`](@ref)中切换模型，实现对同一过程选择不同模型实现的原因。

必须始终在PlantSimEngine中声明硬依赖关系。具体做法是在实现模型时，为`dep`函数添加一个方法。例如，将`process1`对`Process2Model`的硬依赖声明如下：

```julia
PlantSimEngine.dep(::Process2Model) = (process1=AbstractProcess1Model,)
```

这样PlantSimEngine就知道，`Process2Model`在仿真`process1`过程时，需要一个适用于该过程的模型。为了避免只能耦合某个特定模型，实现上只要求依赖的模型是`AbstractProcess1Model`的子类型，从而不限定只能用`Process1Model`，如果你有另一个模型同样可以计算该过程所需变量，也能被替换而无需更改耦合关系。

虽然不推荐，但如果确有需要强制只与某一具体模型耦合，可以将依赖声明为只接受该模型。例如，如果只允许用`Process1Model`来模拟`process1`过程，可以这样声明：

```julia
PlantSimEngine.dep(::Process2Model) = (process1=Process1Model,)
```

## 真实案例举例

在配套包[PlantBioPhysics.jl](https://github.com/VEZY/PlantBiophysics.jl)中可见一个典型例子。其中的能量平衡模型[Monteith model](https://github.com/VEZY/PlantBiophysics.jl/blob/master/src/processes/energy/Monteith.jl)需要在其[`run!`](@ref)函数中[多次迭代调用光合模型](https://github.com/VEZY/PlantBiophysics.jl/blob/c1a75f294109d52dc619f764ce51c6ca1ea897e8/src/processes/energy/Monteith.jl#L154)。