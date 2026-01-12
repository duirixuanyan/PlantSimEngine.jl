"""
    DependencyTrait(T::Type)

返回关于模型 `T` 在计算时是否依赖于其他时间步或对象的信息。依赖特性用于判断模型能否并行化。

支持以下依赖特性：

- `TimeStepDependencyTrait`：定义模型对于时间步是否可以并行化计算的特性。
- `ObjectDependencyTrait`：定义模型对于对象是否可以并行化计算的特性。
"""
abstract type DependencyTrait end

abstract type TimeStepDependencyTrait <: DependencyTrait end
struct IsTimeStepDependent <: TimeStepDependencyTrait end
struct IsTimeStepIndependent <: TimeStepDependencyTrait end

"""
    TimeStepDependencyTrait(::Type{T})

定义模型 `T` 计算时是否依赖其他时间步的特性。该依赖特性用于判断模型是否可以在时间步上并行化。

支持以下依赖特性：

- `IsTimeStepDependent`：该模型的计算依赖其他时间步，不能并行执行。
- `IsTimeStepIndependent`：该模型的计算不依赖其他时间步，可以并行执行。

所有模型默认设为时间步依赖（即 `IsTimeStepDependent`）。虽然大多数模型不一定如此，但这样设计有两个原因：

1. 这是最安全的默认值——如果用户忘记重载这个 trait，不会导致错误结果，相反（设为独立）则可能出错。
2. 对于时间步独立的模型，用户可以很方便地重载此 trait。

# 参见

- [`timestep_parallelizable`](@ref)：判断模型能否在时间步并行。
- [`object_parallelizable`](@ref)：判断模型能否在对象间并行。
- [`parallelizable`](@ref)：判断模型是否可并行化。
- [`ObjectDependencyTrait`](@ref)：定义模型对其他对象的依赖性。

# 示例

定义一个测试过程:
```julia
using PlantSimEngine

# 定义一个测试过程:
@process "TestProcess"
```

定义一个时间步独立的模型:

```julia
struct MyModel <: AbstractTestprocessModel end

# 重载时间步依赖 trait:
PlantSimEngine.TimeStepDependencyTrait(::Type{MyModel}) = IsTimeStepIndependent()
```

检查模型能否按时间步并行:

```julia
timestep_parallelizable(MyModel()) # false
```

定义一个时间步依赖的模型:

```julia
struct MyModel2 <: AbstractTestprocessModel end

# 重载时间步依赖 trait:
PlantSimEngine.TimeStepDependencyTrait(::Type{MyModel2}) = IsTimeStepDependent()
```

检查模型能否按时间步并行:

```julia
timestep_parallelizable(MyModel()) # true
```
"""
TimeStepDependencyTrait(::Type) = IsTimeStepDependent()

"""
    timestep_parallelizable(x::T)
    timestep_parallelizable(x::DependencyGraph)

返回 `true` 表示模型 `x` 可以按时间步进行并行计算，否则返回 `false`。

默认情况下，所有模型都返回 `false`。
如果您开发的模型能够按时间步并行，请为您的模型添加 [`ObjectDependencyTrait`](@ref) 的方法。

本方法也可直接用于 [`DependencyGraph`](@ref)，若图中所有模型可并行化则返回 `true`，否则为 `false`。

# 参见

- [`object_parallelizable`](@ref)：判断模型能否按时间步并行。
- [`parallelizable`](@ref)：判断模型是否可并行化。
- [`TimeStepDependencyTrait`](@ref)：定义模型对其他时间步的依赖性。

# 示例

定义一个测试过程:
```julia
using PlantSimEngine

# 定义一个测试过程:
@process "TestProcess"
```

定义一个时间步独立的模型:

```julia
struct MyModel <: AbstractTestprocessModel end

# 重载时间步依赖 trait:
PlantSimEngine.TimeStepDependencyTrait(::Type{MyModel}) = IsTimeStepIndependent()
```

检查模型能否按对象并行:

```julia
timestep_parallelizable(MyModel()) # true
```
"""
timestep_parallelizable(x::T) where {T} = timestep_parallelizable(TimeStepDependencyTrait(T), x)
timestep_parallelizable(::IsTimeStepDependent, x) = false
timestep_parallelizable(::IsTimeStepIndependent, x) = true

"""
    ObjectDependencyTrait(::Type{T})

定义模型 `T` 计算时是否依赖其他对象的特性。该依赖特性用于判断模型是否可以在对象上并行化。

支持以下依赖特性：

- `IsObjectDependent`：模型依赖其他对象计算，不能并行。
- `IsObjectIndependent`：模型不依赖其他对象，可以并行。

所有模型默认设为对象依赖（即 `IsObjectDependent`）。这样设计的考虑：

1. 这是最安全的默认值，如果用户忘记重载不会导致错误，而相反则可能出错。
2. 对于对象独立模型，用户可以方便重载 trait。

# 参见

- [`timestep_parallelizable`](@ref)：判断模型能否按时间步并行。
- [`object_parallelizable`](@ref)：判断模型能否按对象并行。
- [`parallelizable`](@ref)：判断模型是否可并行化。
- [`TimeStepDependencyTrait`](@ref)：定义模型对其他时间步的依赖性。

# 示例

定义一个测试过程:
```julia
using PlantSimEngine

# 定义一个测试过程:
@process "TestProcess"
```

定义一个对象独立的模型:

```julia
struct MyModel <: AbstractTestprocessModel end

# 重载对象依赖 trait:
PlantSimEngine.ObjectDependencyTrait(::Type{MyModel}) = IsObjectIndependent()
```

检查模型能否按对象并行:

```julia
object_parallelizable(MyModel()) # false
```

定义一个对象依赖的模型:

```julia
struct MyModel2 <: AbstractTestprocessModel end

# 重载对象依赖 trait:
PlantSimEngine.ObjectDependencyTrait(::Type{MyModel2}) = IsObjectDependent()
```

检查模型能否按对象并行:

```julia
object_parallelizable(MyModel()) # true
```
"""
abstract type ObjectDependencyTrait <: DependencyTrait end
struct IsObjectDependent <: ObjectDependencyTrait end
struct IsObjectIndependent <: ObjectDependencyTrait end
ObjectDependencyTrait(::Type) = IsObjectDependent()

"""
    object_parallelizable(x::T)
    object_parallelizable(x::DependencyGraph)

判断模型 `x` 是否可以并行化计算，即模型是否能在不同对象间并行计算，返回 `true` 或 `false`。

默认情况下，所有模型均返回 `false`。
如果你的模型可以按对象并行化，应为其添加 [`ObjectDependencyTrait`](@ref) 方法。

本方法也可直接用于 [`DependencyGraph`](@ref)，若图中所有模型可并行化则返回 `true`，否则为 `false`。

# 参见

- [`timestep_parallelizable`](@ref)：判断模型能否按时间步并行。
- [`parallelizable`](@ref)：判断模型是否可并行化。
- [`ObjectDependencyTrait`](@ref)：定义模型对其他对象的依赖性。

# 示例

定义一个测试过程:
```julia
using PlantSimEngine

# 定义一个测试过程:
@process "TestProcess"
```

定义一个对象独立的模型:

```julia
struct MyModel <: AbstractTestprocessModel end

# 重载对象依赖 trait:
PlantSimEngine.ObjectDependencyTrait(::Type{MyModel}) = IsObjectIndependent()
```

检查模型能否按对象并行:

```julia
object_parallelizable(MyModel()) # true
```
"""
object_parallelizable(x::T) where {T} = object_parallelizable(ObjectDependencyTrait(T), x)
object_parallelizable(::IsObjectDependent, x) = false
object_parallelizable(::IsObjectIndependent, x) = true

"""
    parallelizable(::T)
    object_parallelizable(x::DependencyGraph)

判断模型 `T` 或整个依赖图是否可并行化，也即模型是否可在不同的时间步或对象之间并行计算。默认所有模型均返回 `false`。

# 参见

- [`timestep_parallelizable`](@ref)：判断模型能否按时间步并行。
- [`object_parallelizable`](@ref)：判断模型能否按对象并行。
- [`TimeStepDependencyTrait`](@ref)：定义模型对其他时间步的依赖性。

# 示例

定义一个测试过程:
```julia
using PlantSimEngine

# 定义一个测试过程:
@process "TestProcess"
```

定义一个可并行化模型:

```julia
struct MyModel <: AbstractTestprocessModel end

# 重载时间步依赖 trait:
PlantSimEngine.TimeStepDependencyTrait(::Type{MyModel}) = IsTimeStepIndependent()

# 重载对象依赖 trait:
PlantSimEngine.ObjectDependencyTrait(::Type{MyModel}) = IsObjectIndependent()
```

检查模型是否可并行化:

```julia
parallelizable(MyModel()) # true
```

或者更细致地查看：

```julia
timestep_parallelizable(MyModel())
object_parallelizable(MyModel())
```
"""
parallelizable(x::T) where {T} = timestep_parallelizable(x) && object_parallelizable(x)