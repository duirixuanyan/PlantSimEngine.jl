# 错误信息排查指南

PlantSimEngine 致力于为用户提供尽可能舒适和易用的体验，许多用户错误都会被捕获并给出相应的解释以帮助解决问题，但仍然存在一些盲点，以及语法错误，这些通常会生成 Julia 的错误（这类错误有时不易理解）而不是 PlantSimEngine 的专有错误。

为帮助 Julia 新手排查问题，以下列出了一些在当前 API 下容易出现且不易解读的常见错误类型，并给出了修复建议。

这些错误是按“错误性质”而不是错误提示信息分类的，因此你可能需要在本页面搜索才能找到具体的错误。

如果你需要进一步帮助以解读 Julia 错误信息，可以访问 [Julia 论坛](https://discourse.julialang.org) 寻求帮助。
如果你需要 FSPM（功能-结构植物模型） 方面的建议，研究社区有[专属的讨论论坛](https://fspm.discourse.group)。

如果你遇到 PlantSimEngine 相关的问题，或者有建模方面的疑问和建议，也可以在 Github 上[提交 issue](https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues)。

```@contents
Pages = ["plantsimengine_and_julia_troubleshooting.md"]
Depth = 3
```

## 排查技巧与工作流

有些错误的原因非常明确，PlantSimEngine 的错误信息通常会直接指出是哪一个参数/变量/器官导致了错误，方便你定位问题。

有些看似泛泛的错误消息，实际包含了有助于调试的重要线索。例如，由于参数或关键字参数存在问题导致 run! 调度失败时，错误提示往往会明确指出当前冲突的参数。在 VSCode 编辑器中，这些参数会被红色高亮显示（例如下面例子中第一个和最后一个参数）：

```julia
a = 1
run!(a, simple_mtg, mapping, meteo_day, a)

ERROR: MethodError: no method matching run!(::Int64, ::Node{NodeMTG, Dict{…}}, ::Dict{String, Tuple{…}}, ::DataFrame, ::Int64)
The function [`run!`](@ref) exists, but no method is defined for this combination of argument types.

Closest candidates are:
  run!(::ToyPlantLeafSurfaceModel, ::Any, ::Any, ::Any, ::Any, ::Any)
   @ PlantSimEngine /PlantSimEngine/examples/ToyLeafSurfaceModel.jl:75
   ...
```

如果你想在本页快速定位某个错误，请复制错误描述中不特定于你脚本的部分，然后在此页面使用 Ctrl+F 搜索。例如上述例子中的泛用搜索词为：
```julia
ERROR: MethodError: no method matching
```

## 常见的 Julia 错误

### 单元素 NamedTuple 必须带逗号：

这一点很容易被忽略。

空的 NamedTuple 对象可以用 x = NamedTuple() 初始化。有多个变量时可以这样初始化：
```julia
a = (var1 = 0, var2 = 0)
```
或者这样写也是可以的：
```julia
a = (var1 = 0, var2 = 0,)
```
第二个逗号是可选的。

然而，如果只有一个变量，则必须这样写：
```julia
a = (var1 = 0,)
```
这个逗号是必须的。如果省略了逗号：
```julia
a = (var1 = 0)
```
此时这行代码会被理解为将变量 a 赋值为 var1 的值（如上即赋为 0），所以 a 会变成 Int64 类型的 0，而不是 NamedTuple。

这在编写自定义模型时很容易出错，因为某些函数需要 NamedTuple 类型的参数。例如：
```julia
function PlantSimEngine.inputs_(::HardDepSameScaleAvalModel)
    (e2 = -Inf,)
end
```

如果写错，通常会看到类似下面的 Julia 错误信息：
```julia
[ERROR: MethodError: no method matching merge(::Float64, ::@NamedTuple{g::Float64})

候选方法有：
merge(::NamedTuple{()}, ::NamedTuple)
@ Base namedtuple.jl:337
merge(::NamedTuple{an}, ::NamedTuple{bn}) where {an, bn}
@ Base namedtuple.jl:324
merge(::NamedTuple, ::NamedTuple, NamedTuple...)
@ Base namedtuple.jl:343

Stacktrace:
[1] variables_multiscale(node::PlantSimEngine.HardDependencyNode{…}, organ::String, vars_mapping::Dict{…}, st::@NamedTuple{})
...
```
有时 PlantSimEngine 能检测到并给出友好的提示（如传入 tracked_outputs 时），但在定义状态量等场合此类错误也可能出现。

### 空 inputs/outputs 声明错误

空 NamedTuple 的写法是 `NamedTuple()`。如果错误地写成 `()` 或 `(,)`，将分别触发 PlantSimEngine 或 Julia 返回的错误提示。

## PlantSimEngine 用户常见错误

以下大多数错误仅在多尺度模拟（multi-scale simulation）时出现，因为其 API 更为复杂。但也有一些是单尺度和多尺度模拟都可能遇到的。

### ModelList/Mapping：错误地提供了类型名而不是实例

```julia
m = ModelList(day=MyToyModel, week=MyToyModel2)
```
这行代码是错误的，会报如下错误：
```julia
MethodError: no method matching inputs_(::Type{MyToyDayModel})
```

正确的写法（假设相应的构造函数存在）是：
```julia
m = ModelList(day=MyToyModel(), week=MyToyModel2())
```

### 实现新模型时：忘记导入函数或加上模块前缀

在实现新模型时，需要确保你的实现被正确识别为扩展了`PlantSimEngine`的方法和类型，而不是在当前作用域新建的独立函数。

在下面这个可运行的玩具模型实例中，注意`inputs_`、`outputs_`和[`run!`](@ref)函数都以模块名作前缀。如果有硬依赖管理，[`dep`](@ref)函数同样需要加模块名前缀。

```julia
using PlantSimEngine
@process "toy" verbose = false

struct ToyToyModel{T} <: AbstractToyModel 
    internal_constant::T
end

function PlantSimEngine.inputs_(::ToyToyModel)
    (a = -Inf, b = -Inf, c = -Inf)
end

function PlantSimEngine.outputs_(::ToyToyModel)
    (d = -Inf, e = -Inf)
end

function PlantSimEngine.run!(m::ToyToyModel, models, status, meteo, constants=nothing, extra_args=nothing)
    status.d = m.internal_constant * status.a 
    status.e += m.internal_constant
end

meteo = Weather([
        Atmosphere(T=20.0, Wind=1.0, Rh=0.65, Ri_PAR_f=200.0),
        Atmosphere(T=20.0, Wind=1.0, Rh=0.65, Ri_PAR_f=200.0),
        Atmosphere(T=18.0, Wind=1.0, Rh=0.65, Ri_PAR_f=100.0),
])

model = ModelList(
    ToyToyModel(1),
    status = ( a = 1, b = 0, c = 0),
)
to_initialize(model) 
sim = PlantSimEngine.run!(model, meteo)
```

如果在声明这些函数时没有先导入，或没有加上模块名前缀，它们会被认为是当前作用域下的新函数，而不是扩展`PlantSimEngine`的方法。这会导致`PlantSimEngine`无法正确调用这些功能，结果通常会报错或行为异常。

比如忘记给[`run!`](@ref)函数加模块前缀，会收到如下错误：
```julia
ERROR: MethodError: no method matching run!(::ModelList{@NamedTuple{…}, Status{…}}, ::TimeStepTable{Atmosphere{…}})
函数[`run!`](@ref)虽存在，但没有适用于这组参数类型的方法。

最接近的方法候选有:
  run!(::ToyToyModel, ::Any, ::Any, ::Any, ::Any, ::Any)
   @ Main ~/path/to/file.jl:20
```

如果`inputs_`或`outputs_`没有加前缀，有时未必立刻出错（取决于你在ModelList或mapping的Status下是否声明了对应变量）。

某些情况下会报如下类错误：
```julia
ERROR: type NamedTuple has no field d
Stacktrace:
 [1] setproperty!(mnt::Status{(:a, :b, :c), Tuple{…}}, s::Symbol, x::Int64)
   @ PlantSimEngine ~/path/to/package/PlantSimEngine/src/component_models/Status.jl:100
 [2] run!(m::ToyToyModel{…}, models::@NamedTuple{…}, status::Status{…}, meteo::PlantMeteo.TimeStepRow{…}, constants::Constants{…}, extra_args::Nothing)
 ...
```

!!! note
    未来我们或许会在库内部做更多改进以让错误更直接易懂，但目前最佳实践仍然是所有需要声明和调用的相关方法都加上`PlantSimEngine.`前缀，或明确导入你希望扩展的方法，例如：`import PlantSimEngine: inputs_, outputs_`。

### MultiScaleModel：声明时遗漏关键字参数

MultiScaleModel 需要两个关键字参数，分别为 `model` 和 `mapped_variables`：

```julia
models = MultiScaleModel(
        model=ToyLAIModel(),
        mapped_variables=[:TT_cu => "Scene",],
    )
```

忘记写 `model=` 的情况：

```julia
models = MultiScaleModel(
        ToyLAIModel(),
        mapped_variables=[:TT_cu => "Scene",],
    )
ERROR: MethodError: no method matching MultiScaleModel(::ToyLAIModel; mapped_variables::Vector{Pair{Symbol, String}})
虽然类型 `MultiScaleModel` 存在，但该参数组合未定义对应的构造方法。

最接近的候选方法有：
    MultiScaleModel(::T, ::Any) where T<:AbstractModel got unsupported keyword argument "mapped_variables"
    @ PlantSimEngine PlantSimEngine/src/mtg/MultiScaleModel.jl:188
    MultiScaleModel(; model, mapped_variables)
    @ PlantSimEngine PlantSimEngine/src/mtg/MultiScaleModel.jl:191
```

忘记写 `mapped_variables=` 的情况：

```julia
models = MultiScaleModel(
        model=ToyLAIModel(),
        [:TT_cu => "Scene",],
    )

ERROR: MethodError: no method matching MultiScaleModel(::Vector{Pair{Symbol, String}}; model::ToyLAIModel)
虽然类型 `MultiScaleModel` 存在，但该参数组合未定义对应的构造方法。

最接近的候选方法有：
  MultiScaleModel(; model, mapping)
   @ PlantSimEngine PlantSimEngine/src/mtg/MultiScaleModel.jl:191
  MultiScaleModel(::T, ::Any) where T<:AbstractModel got unsupported keyword argument "model"
```

信息'got unsupported keyword argument "model"'可能会产生误导，因为此处的错误并非关键字参数*不被支持*，而是关键字参数*缺失*。

### MultiScaleModel：在映射中未定义变量

导致此类错误的一个常见原因是，在多尺度模型的映射中，使用了变量名而不是符号（Symbol）：

```julia
mapping = Dict("Scale" =>
MultiScaleModel(
    model = ToyModel(),
    mapped_variables = [should_be_symbol => "Other_Scale"] # should_be_symbol 是变量名，很可能在当前模块中未定义
),
...
),
```

正确的做法是使用符号（Symbol），例如：
```julia
mapping = Dict("Scale" =>
MultiScaleModel(
    model = ToyModel(),
    mapped_variables=[:should_be_symbol => "Other_Scale"] # should_be_symbol 现在是符号
),
...
),
```

### 调用 run! 时位置参数与关键字参数问题

不幸的是，给 run! 函数传递参数时有多种方式可能会混淆 Julia 的动态分派机制。其中一部分原因是 PlantSimEngine 本身类型声明还不够完善，未来可能会有所改进。

下面举几个典型例子，说明在正常多尺度模型的 run! 调用中稍作修改就容易引发困惑：

```julia
    meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)
    mtg = Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1))
    var1 = 15.0

    mapping = Dict(
        "Leaf" => (
            Process1Model(1.0),
            Process2Model(),
            Process3Model(),
            Status(var1=var1,)
        )
    )

    outs = Dict(
        "Leaf" => (:var1,), # :non_existing_variable 不是任何模型计算的变量
    )

run!(mtg, mapping, meteo_day, PlantMeteo.Constants(), tracked_outputs=outs)
```

该函数的完整签名如下： 
```julia
function run!(
    object::MultiScaleTreeGraph.Node,
    mapping::Dict{String,T} where {T},
    meteo=nothing,
    constants=PlantMeteo.Constants(),
    extra=nothing;
    nsteps=nothing,
    tracked_outputs=nothing,
    check=true,
    executor=ThreadedEx()
```

在 mtg 和 mapping 之后的参数都有默认值，因此都是可选的；在 ';' 分隔符之后的参数是关键字参数，必须显式命名。

如果你忘记传入 mtg，由于 run! 的定义方式存在缺陷，会出现如下错误：
```julia
run!(mapping, meteo_day, PlantMeteo.Constants(), tracked_outputs=outs)

ERROR: MethodError: no method matching check_dimensions(::PlantSimEngine.TableAlike, ::Tuple{…}, ::DataFrame)
虽然函数 `check_dimensions` 存在，但没有针对这些参数类型的实现。

最接近的候选方法如下：
  check_dimensions(::Any, ::Any)
   @ PlantSimEngine PlantSimEngine/src/checks/dimensions.jl:43
 ...
```

如果在函数调用时忘记添加必要的参数名 `tracked_outputs=`，`outs` 会被当作位置参数传递给 `extra`，而不是作为关键字参数。`extra` 参数一般默认为 nothing，并在多尺度模式下保留，因此会导致如下报错：

```julia
run!(mtg, mapping, meteo_day, PlantMeteo.Constants(), outs)

ERROR: Extra parameters are not allowed for the simulation of an MTG (already used for statuses).
Stacktrace:
 [1] error(s::String)
   @ Base ./error.jl:35
 [2] run!(::PlantSimEngine.TreeAlike, object::PlantSimEngine.GraphSimulation{…}, meteo::DataFrames.DataFrameRows{…}, constants::Constants{…}, extra::Dict{…}; tracked_outputs::Nothing, check::Bool, executor::ThreadedEx{…})
```

另外一种情况：如果错用了不存在的关键字参数，则 Julia 会抛出带有更多信息的通用调度错误，例如出现
`got unsupported keyword argument "constants"`

```julia
run!(mtg, mapping, meteo_day, constants=PlantMeteo.Constants(), tracked_outputs=outs)

ERROR: MethodError: no method matching run!(::Node{…}, ::Dict{…}, ::DataFrame, ::Dict{…}, ::Nothing; constants::Constants{…})
这个错误是手动显式抛出的，因此函数本身可能存在，但被明确标记为未实现。

最接近的候选方法如下：
  run!(::Node, ::Dict{String}, ::Any, ::Any, ::Any; nsteps, tracked_outputs, check, executor) got unsupported keyword argument "constants"
```

### 映射中缺少硬依赖过程的情况

当前 PlantSimEngine 的错误检查机制存在一个不足：当你的 mapping 中包含模型 A，且 A 存在**硬依赖**模型 B（即 A 运行前必须有 B），但 mapping 里却没有添加 B，这时 Julia 会抛出一个比较隐晦的报错。

例如，A 是 `Process3Model`，它声明自己硬依赖一个名为 `process2` 的模型 B（实现自 `Process2Model`）。在 `Process3Model` 的源码中声明如下：

```julia
PlantSimEngine.dep(::Process3Model) = (process2=Process2Model,)
```

但下方的示例 mapping 中，缺少了对应的 `Process2Model`：

```julia
simple_mtg = Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 1, 1))    
mapping = Dict(
    "Leaf" => (
        Process3Model(),
        Status(var5=15.0,)
    )
)
outs = Dict(
    "Leaf" => (:var5,),
)
run!(simple_mtg, mapping, meteo_day, tracked_outputs=outs)

ERROR: type NamedTuple has no field process2
Stacktrace:
 [1] getproperty(x::@NamedTuple{process3::Process3Model}, f::Symbol)
   @ Base ./Base.jl:49
 [2] run!(::Process3Model, models::@NamedTuple{…}, status::Status{…}, meteo::DataFrameRow{…}, constants::Constants{…}, extra::PlantSimEngine.GraphSimulation{…})
 ...
```

出现这种报错时，**解决方法**就是在 mapping 里补上 `Process2Model()`（或者其它实现该过程的模型）。

### Status API 歧义问题

目前 PlantSimEngine 的 API 存在一个问题：在声明仿真的 Status 或 Statuses 时，单尺度与多尺度的写法不同。

回到[实现新模型时：忘记导入函数或加上模块前缀](@ref)中的例子，`ModelList` 中 status 的声明如下：

```julia
model = ModelList(
    ToyToyModel(1),
    status = ( a = 1, b = 0, c = 0),
)
```
如果你把 `status = ...` 替换为多尺度的写法 `Status(...)`，会遇到如下报错：

```julia
ERROR: MethodError: no method matching process(::Status{(:a, :b, :c), Tuple{Base.RefValue{Int64}, Base.RefValue{Int64}, Base.RefValue{Int64}}})
虽然存在名为 `process` 的函数，但没有为这种参数组合定义该方法。

最接近的方法是：
  process(::Pair{Symbol, A}) where A<:AbstractModel
   @ PlantSimEngine ~/path/to/pkg/PlantSimEngine/src/Abstract_model_structs.jl:16
  process(::A) where A<:AbstractModel
   @ PlantSimEngine ~/path/to/pkg/PlantSimEngine/src/Abstract_model_structs.jl:13

堆栈跟踪:
 [1] (::PlantSimEngine.var"#5#6")(i::Status{(:a, :b, :c), Tuple{Base.RefValue{…}, Base.RefValue{…}, Base.RefValue{…}}})
   @ PlantSimEngine ./none:0
 [2] iterate
```

如果你在多尺度仿真中做了相反的事情——即将必需的 `Status(...)` 写法替换成 `status = ...`，你可能会遇到 `ERROR: syntax: invalid named tuple element` 这样的错误。下面是对 Toy Plant 教程的 mapping 做这种修改时出现的典型报错示例：

```julia
ERROR: syntax: invalid named tuple element "MultiScaleModel(...)" around /path/to/Pkg/PlantSimEngine/examples/ToyMultiScalePlantTutorial/ToyPlantSimulation3.jl:196
Stacktrace:
 [1] top-level scope
   @ ~/path/to/pkg/PlantSimEngine/examples/ToyMultiScalePlantTutorial/ToyPlantSimulation3.jl:196
```
或
```julia
ERROR: syntax: invalid named tuple element "ToyRootGrowthModel(50, 10)" around /path/to/Pkg/PlantSimEngine/examples/ToyMultiScalePlantTutorial/ToyPlantSimulation3.jl:196
Stacktrace:
 [1] top-level scope
   @ ~/path/to/Pkg/PlantSimEngine/examples/ToyMultiScalePlantTutorial/ToyPlantSimulation3.jl:196
```

## 在 mapping 中忘记声明某个尺度，但变量却指向了该尺度

如果需要在两个不同尺度上收集变量，但 mapping 里某个尺度完全没有声明模型，目前 Julia 端会报错如下：

```julia
# mapping 里没有 E3 尺度的模型！

"E2" => (
        MultiScaleModel(
        model = HardDepSameScaleEchelle2Model(),
        mapped_variables=[:c => "E1" => :c, :e3 => "E3" => :e3, :f3 => "E3" => :f3,], 
        ),
    ),

Exception has occurred: KeyError
*
KeyError: key "E3" not found
Stacktrace:
[1] hard_dependencies(mapping::Dict{String, Tuple{Any, Any}}; verbose::Bool)
@ PlantSimEngine ......./src/dependencies/hard_dependencies.jl:175
...
```

### mapping 声明时的括号位置问题

在声明 mapping 时，曾遇到过一种让人迷惑的错误：

```julia
ERROR: ArgumentError: AbstractDict(kv): kv needs to be an iterator of 2-tuples or pairs
```

这个错误经常发生在 mapping 声明中 `=>` 后面应有括号却忘记加，并且与另一个括号写法错误叠加时。例如：

```julia
mapping = Dict( "Scale" => (ToyAssimGrowthModel(0.0, 0.0, 0.0), ToyCAllocationModel(), Status( TT_cu=Vector(cumsum(meteo_day.TT))), ), )
```

除此以外，还可能遇到如下错误：

```julia
ERROR: MethodError: no method matching Dict(::Pair{String, ToyAssimGrowthModel{Float64}}, ::ToyCAllocationModel, ::Status{(:TT_cu,), Tuple{Base.RefValue{…}}})
The type `Dict` exists, but no method is defined for this combination of argument types when trying to construct it.

Closest candidates are:
  Dict(::Pair{K, V}...) where {K, V}
```

这通常暗示 mapping 声明的语法有误，请仔细检查括号和逗号的位置。

### 多尺度模拟中的空状态向量

这种情况下不会直接报错。如果你在 MTG 中忘记在相应尺度上增加某个节点，并且没有为该节点生成器官，对应输出变量会返回空向量，容易让人疑惑。

这里有一个例子，取自[将单尺度模拟转换为多尺度模拟](@ref)页面，并对伪 MTG 做了修改：把传入 [`run!`](@ref) 函数的 "Plant" 节点去掉了。没有 "Plant" 节点时，只能先运行 "Scene" 尺度的模型，由于没有新节点创建，"Plant" 尺度的模型永远不会被运行。

```julia
PlantSimEngine.@process "tt_cu" verbose = false

struct ToyTt_CuModel <: AbstractTt_CuModel end

function PlantSimEngine.run!(::ToyTt_CuModel, models, status, meteo, constants, extra=nothing)
    status.TT_cu +=
        meteo.TT
end

function PlantSimEngine.inputs_(::ToyTt_CuModel)
    NamedTuple() # 没有输入变量
end

function PlantSimEngine.outputs_(::ToyTt_CuModel)
    (TT_cu=-Inf,)
end

mapping_multiscale = Dict(
    "Scene" => ToyTt_CuModel(),
    "Plant" => (
        MultiScaleModel(
            model=ToyLAIModel(),
            mapped_variables=[
                :TT_cu => "Scene",
            ],
        ),
        Beer(0.5),
        ToyRUEGrowthModel(0.2),
    ),
)

mtg_multiscale = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", "Plant", 0, 0),)
#plant = MultiScaleTreeGraph.Node(mtg_multiscale, MultiScaleTreeGraph.NodeMTG("+", "Plant", 1, 1))

out_multiscale = run!(mtg_multiscale, mapping_multiscale, meteo_day)

out_multiscale["Plant"][:LAI]
```

在上述代码中，取消第二行的注释可以为 MTG 增加一个 "Plant" 节点，此时模拟的行为会符合我们直觉的预期。