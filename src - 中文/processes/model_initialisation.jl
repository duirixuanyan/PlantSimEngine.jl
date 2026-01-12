"""
    to_initialize(; verbose=true, vars...)
    to_initialize(m::T)  where T <: ModelList
    to_initialize(m::DependencyGraph)
    to_initialize(mapping::Dict{String,T}, graph=nothing)

返回必须初始化的变量，提供一组模型与过程。
该函数考虑模型耦合，仅返回必需的变量，即只返回那些由于部分模型的输出变量被其他模型作为输入变量而需要的变量。

# 参数

- `verbose`: 如果为`true`，打印信息消息。
- `vars...`: 要考虑的模型和过程。
- `m::T`: 一个[`ModelList`](@ref)。
- `m::DependencyGraph`: 一个 [`DependencyGraph`](@ref)。
- `mapping::Dict{String,T}`: 一个模型与器官的映射。
- `graph`: 表示植物或场景的图（如多尺度树图）。该图被用于检测未初始化变量是否在图节点属性中已存在。

# 示例

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

to_initialize(process1=Process1Model(1.0), process2=Process2Model())

# 或直接使用组件：
models = ModelList(process1=Process1Model(1.0), process2=Process2Model())
to_initialize(models)

m = ModelList(
    (
        process1=Process1Model(1.0),
        process2=Process2Model()
    ),
    Status(var1 = 5.0, var2 = -Inf, var3 = -Inf, var4 = -Inf, var5 = -Inf)
)

to_initialize(m)
```

或者带有映射：

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

mapping = Dict(
    "Leaf" => ModelList(
        process1=Process1Model(1.0),
        process2=Process2Model(),
        process3=Process3Model()
    ),
    "Internode" => ModelList(
        process1=Process1Model(1.0),
    )
)

to_initialize(mapping)
```
"""
function to_initialize(m::ModelList)
    needed_variables = to_initialize(dep(m))
    to_init = Dict{Symbol,Tuple}()
    for (process, vars) in needed_variables
        # default_values = needed_variables[:process1]
        # st = m.status
        not_init = vars_not_init_(m.status, vars)
        length(not_init) > 0 && push!(to_init, process => not_init)
    end
    return NamedTuple(to_init)
end

function to_initialize(m::DependencyGraph)
    dependencies = traverse_dependency_graph(m, to_initialize)

    outputs_all = Set{Symbol}()
    for (key, value) in dependencies
        outputs_all = union(outputs_all, keys(value.outputs))
    end

    needed_variables_process = Dict{Symbol,NamedTuple}()
    for (key, value) in dependencies
        for (key_in, val_in) in pairs(value.inputs)
            if key_in ∉ outputs_all
                if haskey(needed_variables_process, key)
                    needed_variables_process[key] = merge(needed_variables_process[key], NamedTuple{(key_in,)}(val_in))
                else
                    push!(needed_variables_process, key => NamedTuple{(key_in,)}(val_in))
                end
            end
        end
    end
    # 注意：needed_variables_process 示例为：
    # Dict{Symbol, NamedTuple} with 2 entries:
    #     :process1 => (var1 = -Inf, var2 = -Inf)
    #     :process2 => (var1 = -Inf,)
    return needed_variables_process
end


# 返回必须初始化的变量，给定一组模型与过程。
# 该函数只返回各个模型的输入与输出及其默认值。
# 若要考虑模型之间的耦合，请使用上层方法，如
# `to_initialize(m::ModelList)` 或 `to_initialize(m::DependencyGraph)`。
function to_initialize(m::AbstractDependencyNode)
    return (inputs=inputs_(m.value), outputs=outputs_(m.value))
end

function to_initialize(m::T) where {T<:Dict{String,ModelList}}
    toinit = Dict{String,NamedTuple}()
    for (key, value) in m
        # key = "Leaf"; value = m[key]
        toinit_ = to_initialize(value)

        if length(toinit_) > 0
            push!(toinit, key => toinit_)
        end
    end

    return toinit
end


function to_initialize(; verbose=true, vars...)
    needed_variables = to_initialize(dep(; verbose=verbose, (; vars...)...))
    to_init = Dict{Symbol,Tuple}()
    for (process, vars) in pairs(needed_variables)
        not_init = keys(vars)
        length(not_init) > 0 && push!(to_init, process => not_init)
    end
    return NamedTuple(to_init)
end

# 用于给 MTG 的映射列表：
function to_initialize(mapping::Dict{String,T}, graph=nothing) where {T}
    # 获取MTG中的变量：
    if isnothing(graph)
        vars_in_mtg = Symbol[]
    else
        vars_in_mtg = names(graph)
    end

    to_init = Dict(org => Symbol[] for org in keys(mapping))
    mapped_vars = mapped_variables(mapping, first(hard_dependencies(mapping; verbose=false)), verbose=false)
    for (org, vars) in mapped_vars
        for (var, val) in vars
            if isa(val, UninitializedVar) && var ∉ vars_in_mtg
                push!(to_init[org], var)
            end
        end
    end

    filter!(x -> length(last(x)) > 0, to_init)

    return to_init
end

"""
    init_status!(object::Dict{String,ModelList};vars...)
    init_status!(component::ModelList;vars...)

为组件赋予用户输入的初值。

# 示例

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

models = Dict(
    "Leaf" => ModelList(
        process1=Process1Model(1.0),
        process2=Process2Model(),
        process3=Process3Model()
    ),
    "InterNode" => ModelList(
        process1=Process1Model(1.0),
    )
)

init_status!(models, var1=1.0 , var2=2.0)
status(models["Leaf"])
```
"""
function init_status!(object::Dict{String,ModelList}; vars...)
    new_vals = (; vars...)

    for (component_name, component) in object
        for j in keys(new_vals)
            if !in(j, keys(component.status))
                @info "Key $j not found as a variable for any provided models in $component_name" maxlog = 1
                continue
            end
            setproperty!(component.status, j, new_vals[j])
        end
    end
end

function init_status!(component::T; vars...) where {T<:ModelList}
    new_vals = (; vars...)
    for j in keys(new_vals)
        if !in(j, keys(component.status))
            @info "Key $j not found as a variable for any provided models"
            continue
        end
        setproperty!(component.status, j, new_vals[j])
    end
end

"""
    init_variables(models...)

用模型的默认值初始化变量。这些变量取自模型的输入和输出。

# 示例

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

init_variables(Process1Model(2.0))
init_variables(process1=Process1Model(2.0), process2=Process2Model())
```
"""
function init_variables(model::T; verbose::Bool=true) where {T<:AbstractModel}
    # 仅提供了一个模型：
    in_vars = inputs_(model)
    out_vars = outputs_(model)
    # 合并两者：
    vars = merge(in_vars, out_vars)

    return vars
end

function init_variables(m::ModelList; verbose::Bool=true)
    init_variables(dep(m))
end

function init_variables(m::DependencyGraph)
    dependencies = traverse_dependency_graph(m, init_variables)
    return NamedTuple(dependencies)
end

function init_variables(node::AbstractDependencyNode)
    return init_variables(node.value)
end

# 以关键字参数的形式提供模型：
function init_variables(; verbose::Bool=true, kwargs...)
    mods = (; kwargs...)
    init_variables(dep(; verbose=verbose, mods...))
end

# 以NamedTuple形式提供模型：
function init_variables(models::T; verbose::Bool=true) where {T<:NamedTuple}
    init_variables(dep(; verbose=verbose, models...))
end

"""
    is_initialized(m::T) where T <: ModelList
    is_initialized(m::T, models...) where T <: ModelList

检查必须初始化的变量是否已经被初始化。如果已初始化全部变量，返回 `true`，否则返回 `false` 并给出信息提示。

# 注意

无法预先知道用户将仿真哪些过程，因此，如果一个组件为每个过程都定义了模型，则需要初始化的变量始终是所有变量中最小的那个子集，即认为用户将仿真其它模型所需的变量。

# 示例

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model()
)

is_initialized(models)
```
"""
function is_initialized(m::T; verbose=true) where {T<:ModelList}
    var_names = to_initialize(m)

    if any([length(to_init) > 0 for (process, to_init) in pairs(var_names)])
        verbose && @info "Some variables must be initialized before simulation: $var_names (see `to_initialize()`)" maxlog = 1
        return false
    else
        return true
    end
end

function is_initialized(models...; verbose=true)
    var_names = to_initialize(models...)
    if length(var_names) > 0
        verbose && @info "Some variables must be initialized before simulation: $(var_names) (see `to_initialize()`)" maxlog = 1
        return false
    else
        return true
    end
end

"""
    vars_not_init_(st<:Status, var_names)

获取状态结构体中尚未正确初始化的变量。
"""
function vars_not_init_(st::T, default_values) where {T<:Status}
    length(default_values) == 0 && return () # 没有变量

    not_init = Symbol[]
    for i in keys(default_values)
        # 如果变量值等于默认值，或为未初始化的RefVector（长度为0）
        if getproperty(st, i) == default_values[i] || (isa(getproperty(st, i), RefVector) && length(getproperty(st, i)) == 0)
            push!(not_init, i)
        end
    end
    return (not_init...,)
end

# 针对具有多个时间步长的status结构体组件：
function vars_not_init_(status, default_values)
    length(default_values) == 0 && return () # 没有变量

    not_init = Set{Symbol}()
    for st in Tables.rows(status), i in eachindex(default_values)
        if getproperty(st, i) == getproperty(default_values, i)
            push!(not_init, i)
        end
    end

    return Tuple(not_init)
end

"""
    init_variables_manual(models...;vars...)

以给定值初始化模型变量。

# 示例

```@example
using PlantSimEngine

# 加载包中的示例虚拟模型：
using PlantSimEngine.Examples

models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model()
)

PlantSimEngine.init_variables_manual(status(models), (var1=20.0,))
```
"""
function init_variables_manual(status, vars)
    for i in keys(vars)
        !in(i, keys(status)) && error("Key $i not found as a variable of the status.")
        setproperty!(status, i, vars[i])
    end
    status
end
