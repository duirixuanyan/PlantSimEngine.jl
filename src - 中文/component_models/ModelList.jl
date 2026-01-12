
"""
    ModelList(models::M, status::S)
    ModelList(;
        status=nothing,
        type_promotion=nothing,
        variables_check=true,
        kwargs...
    )

列举用于模拟的一组模型 (`models`)，并自动完成变量初始化、类型提升、时间步长处理等样板工作。

!!! note
    `status` 字段取决于输入的模型。你可以通过已实例化模型上的 [`variables`](@ref) 方法获取模型所需变量，也可以使用 [`inputs`](@ref) 和 [`outputs`](@ref)。

# 参数说明

- `models`: 一个模型的列表。通常采用 `NamedTuple`，但也可以是实现了 `getproperty` 的其他结构。
- `status`: 包含模型变量初始化的结构体。作为关键字参数时通常为 NamedTuple，或为实现了 `Tables.jl` 接口的任何结构体（如 DataFrame，详见下文）。
- `type_promotion`: 可选，用于默认值变量的类型转换。默认为 `nothing`（即不转换）。注意，用户以 `kwargs` 提供的变量不会自动转换（需要手动转换）。需提供以当前类型为键、新类型为值的 Dict。
- `variables_check=true`: 检查用户是否初始化了所有必需变量。
- `kwargs`: 各过程名称对应的模型。

# 细节

如果你需要自定义 `status` 的类型，并希望用户能够只初始化部分字段，则必须为 `add_model_vars!` 实现一个方法，以在类型未完全初始化时添加模型变量。默认方法兼容任何实现了 `Tables.jl` 接口的类型（如 DataFrame），以及 `NamedTuples`。

注意，如果输入 `status` 未涵盖所有变量，`ModelList` 会对其进行复制。

## 示例

以下示例采用包中 `examples/dummy.jl` 的示例模型。其实现了三个虚拟过程：`Process1Model`、`Process2Model` 和 `Process3Model`，且每个过程有一个模型实现。

```jldoctest 1
julia> using PlantSimEngine;
```

包含示例过程和模型：

```jldoctest 1
julia> using PlantSimEngine.Examples;
```

```jldoctest 1
julia> models = ModelList(process1=Process1Model(1.0), process2=Process2Model(), process3=Process3Model());
[ Info: Some variables must be initialized before simulation: (process1 = (:var1, :var2), process2 = (:var1,)) (see `to_initialize()`)
```

```jldoctest 1
julia> typeof(models)
ModelList{@NamedTuple{process1::Process1Model, process2::Process2Model, process3::Process3Model}, Status{(:var5, :var4, :var6, :var1, :var3, :var2), NTuple{6, Base.RefValue{Float64}}}}
```

未以关键字参数提供变量，意味着 ModelList 的 status 尚未设置，所有变量将按 inputs 和 outputs 中的默认值初始化（通常是 `typemin(Type)`，比如浮点数则为 `-Inf`）。此时组件尚不可模拟。

模拟前需初始化哪些变量，可通过 [`to_initialize`](@ref) 方法查询：

```jldoctest 1
julia> to_initialize(models)
(process1 = (:var1, :var2), process2 = (:var1,))
```

我们现在可以在 `status` 字段中为这些变量赋值，并对 ModelList 进行模拟。例如针对 `process3`（与 process1 和 process2 耦合）：

```jldoctest 1
julia> models = ModelList(process1=Process1Model(1.0), process2=Process2Model(), process3=Process3Model(), status=(var1=15.0, var2=0.3));
```

```jldoctest 1
julia> meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995);
```

```jldoctest 1
julia> outputs_sim = run!(models,meteo)
TimeStepTable{Status{(:var5, :var4, :var6, ...}(1 x 6):
╭─────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────╮
│ Row │    var5 │    var4 │    var6 │    var1 │    var3 │    var2 │
│     │ Float64 │ Float64 │ Float64 │ Float64 │ Float64 │ Float64 │
├─────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│   1 │ 36.0139 │    22.0 │ 58.0139 │    15.0 │     5.5 │     0.3 │
╰─────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────╯
```

```jldoctest 1
julia> outputs_sim[:var6]
1-element Vector{Float64}:
 58.0138985
```

如需对变量使用特殊类型，可使用 `type_promotion` 参数：

```jldoctest 1
julia> models = ModelList(process1=Process1Model(1.0), process2=Process2Model(), process3=Process3Model(), status=(var1=15.0, var2=0.3), type_promotion = Dict(Float64 => Float32));
```

我们使用 `type_promotion` 将 status 强制转换为 Float32：

```jldoctest 1
julia> [typeof(models[i][1]) for i in keys(status(models))]
6-element Vector{DataType}:
 Float32
 Float32
 Float32
 Float64
 Float64
 Float32
```

可以看到，只有默认变量（未在 status 参数中给定的变量）被转换为 Float32，其余两个用户提供的变量未被转换。这样做是为了让用户可以为 status 中赋值的变量指定任意类型。如需全部变量都转为 Float32，可直接以 Float32 赋值：

```jldoctest 1
julia> models = ModelList(process1=Process1Model(1.0), process2=Process2Model(), process3=Process3Model(), status=(var1=15.0f0, var2=0.3f0), type_promotion = Dict(Float64 => Float32));
```

我们使用 `type_promotion` 将 status 强制转换为 Float32：

```jldoctest 1
julia> [typeof(models[i][1]) for i in keys(status(models))]
6-element Vector{DataType}:
 Float32
 Float32
 Float32
 Float32
 Float32
 Float32
```
"""
struct ModelList{M<:NamedTuple,S}
    models::M
    status::S
    type_promotion::Union{Nothing,Dict}
    dependency_graph::DependencyGraph
end

#=function ModelList(models::M, status::Status) where {M<:NamedTuple{names,T} where {names,T<:NTuple{N,<:AbstractModel} where {N}}}
    ModelList(models, status)
end=#

# 通用接口：
function ModelList(
    args...;
    status=nothing,
    type_promotion::Union{Nothing,Dict}=nothing,
    variables_check::Bool=true,
    kwargs...
)

    # 获取所有模型需要的变量及其默认值：
    if length(args) > 0
        args = parse_models(args)
    else
        args = NamedTuple()
    end

    if length(kwargs) > 0
        kwargs = (; kwargs...)
    else
        kwargs = ()
    end

    if length(args) == 0 && length(kwargs) == 0
        error("No models were given")
    end

    mods = merge(args, kwargs)

    # 从输入生成 NamedTuple 向量（如有需要请自定义你的实现）
    ts_kwargs = homogeneous_ts_kwargs(status)
    ts_kwargs = add_model_vars(ts_kwargs, mods, type_promotion)

    model_list = ModelList(
        mods,
        ts_kwargs,
        type_promotion,
        dep(; verbose=true, mods...)
    )
    variables_check && !is_initialized(model_list)

    return model_list
end

outputs(m::ModelList) = m.outputs

parse_models(m) = NamedTuple([process(i) => i for i in m])

"""
    add_model_vars(x, models, type_promotion)

检测 `x` 中哪些变量还未初始化（根据一组 `models` 及其所需模拟变量）。如有变量未初始化，将其初始化为默认值。

本函数需根据不同类型的 `x` 实现。默认方法适用于任意 Tables.jl 兼容结构和 NamedTuples。

注意，该函数会在变量未齐全时复制输入 `x`。
"""
function add_model_vars(x, models, type_promotion)
    ref_vars = merge(init_variables(models; verbose=false)...)
    # 若无变量需求，直接返回输入：
    length(ref_vars) == 0 && return isa(x, Status) ? x : Status(x)

    # 若用户已提供 status，检查是否所有变量都已初始化：
    vars_in_x = status_keys(x)
    status_x =
        all([k in vars_in_x for k in keys(ref_vars)]) && return isa(x, Status) ? x : Status(x)  # 已全初始化直接返回

    # 否则，通过复制生成新对象（注意这是数据副本，可能较慢）：

    # 转换模型变量类型为用户要求的类型：
    ref_vars = convert_vars(ref_vars, type_promotion)

    # 若 status 为空，则将所有变量初始化为默认值：
    if x === nothing
        return Status(ref_vars)
    end

    if Tables.istable(x)
        # 此情形只在用户提供表格（table）而非 status 时出现
        # 即 status 包含了一批向量值，已初始化到某一进度
        # 不确定这种用法是否合理，因为 run! 可能什么都不做或全部覆盖
        # 总之，此处需生成变量名到向量的 NamedTuple
        x_full = (; zip(propertynames(x), Tables.columns(x))...)
        x_full = merge(ref_vars, x_full)

    else
        x_full = merge(ref_vars, NamedTuple(x))
    end
    #x_full = merge(ref_vars, NamedTuple(x))

    return Status(x_full)
end

function status_keys(st)
    Tables.istable(st) && return Tables.columnnames(st)
    return keys(st)
end

status_keys(::Nothing) = NamedTuple()

# 若用户未提供任何初始值，将所有变量初始化为默认值：
function add_model_vars(x::Nothing, models, type_promotion)
    ref_vars = merge(init_variables(models; verbose=false)...)
    length(ref_vars) == 0 && return x
    # 类型提升
    return Status(convert_vars(ref_vars, type_promotion))
end

"""
    homogeneous_ts_kwargs(kwargs)

默认情况下，此函数直接返回其参数。
"""
homogeneous_ts_kwargs(kwargs) = kwargs

"""
    kwargs_to_timestep(kwargs::NamedTuple{N,T}) where {N,T}

将各变量为（可选）向量的 NamedTuple，转换为每个时间步为一个 NamedTuple 的向量。
可用于对某一变量在所有时间步赋常值。

# 示例

```@example
PlantSimEngine.homogeneous_ts_kwargs((Tₗ=[25.0, 26.0], aPPFD=1000.0))
```
"""
function homogeneous_ts_kwargs(kwargs::NamedTuple{N,T}) where {N,T}
    length(kwargs) == 0 && return kwargs
    vars_vals = collect(Any, values(kwargs))

    vars_array = NamedTuple{keys(kwargs)}(j for j in vars_vals)

    return vars_array
end

"""
    Base.copy(l::ModelList)
    Base.copy(l::ModelList, status)

复制一个 [`ModelList`](@ref)，可选替换新的 status。

# 示例

```@example
using PlantSimEngine

# 包含示例过程和模型：
using PlantSimEngine.Examples;

# 创建模型列表：
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status=(var1=15.0, var2=0.3)
)

# 复制模型列表：
ml2 = copy(models)

# 使用新 status 复制模型列表：
ml3 = copy(models, TimeStepTable([Status(var1=20.0, var2=0.5))])
```
"""
function Base.copy(m::T) where {T<:ModelList}
    ModelList(
        m.models,
        deepcopy(m.status),
        deepcopy(m.type_promotion),
        deepcopy(m.dependency_graph)
    )
end

function Base.copy(m::T, status) where {T<:ModelList}
    ModelList(
        m.models,
        status,
        deepcopy(m.type_promotion),
        deepcopy(m.dependency_graph)
    )
end

"""
    Base.copy(l::AbstractArray{<:ModelList})

复制 [`ModelList`](@ref) 的数组类结构
"""
function Base.copy(l::T) where {T<:AbstractArray{<:ModelList}}
    return [copy(i) for i in l]
end

"""
    Base.copy(l::AbstractDict{N,<:ModelList} where N)

复制字典类 [`ModelList`](@ref)
"""
function Base.copy(l::T) where {T<:AbstractDict{N,<:ModelList} where {N}}
    return Dict([k => v for (k, v) in l])
end


"""
    convert_vars(ref_vars, type_promotion::Dict{DataType,DataType})
    convert_vars(ref_vars, type_promotion::Nothing)
    convert_vars!(ref_vars::Dict{Symbol}, type_promotion::Dict{DataType,DataType})
    convert_vars!(ref_vars::Dict{Symbol}, type_promotion::Nothing)

将 status 变量转换为 type_promotion 字典中指定的类型。
*注：带 ! 的变异版仅适用于变量字典。*

# 示例

若需将所有 Real 类型变量转为 Float32，可使用：

```julia
using PlantSimEngine

# 包含示例过程和模型：
using PlantSimEngine.Examples;

ref_vars = init_variables(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
)
type_promotion = Dict(Real => Float32)

PlantSimEngine.convert_vars(type_promotion, ref_vars.process3)
```
"""
convert_vars, convert_vars!

function convert_vars(ref_vars, type_promotion::Dict{DataType,DataType})
    dict_ref_vars = Dict{Symbol,Any}(zip(keys(ref_vars), values(ref_vars)))
    for (suptype, newtype) in type_promotion
        vars = []
        for var in keys(ref_vars)
            if isa(dict_ref_vars[var], suptype)
                dict_ref_vars[var] = convert(newtype, dict_ref_vars[var])
                push!(vars, var)
            end
        end
        # length(vars) > 1 && @info "$(join(vars, ", ")) are $suptype and were promoted to $newtype"
    end

    return NamedTuple(dict_ref_vars)
end

# 变异版本，需要变量字典：
function convert_vars!(ref_vars::Dict{Symbol,Any}, type_promotion::Dict)
    for (suptype, newtype) in type_promotion
        for var in keys(ref_vars)
            if isa(ref_vars[var], suptype)
                ref_vars[var] = convert(newtype, ref_vars[var])
            elseif isa(ref_vars[var], MappedVar) && isa(mapped_default(ref_vars[var]), suptype)
                ref_mapped_var = ref_vars[var]
                old_default = mapped_default(ref_vars[var])

                if isa(old_default, AbstractArray)
                    new_val = [convert(newtype, i) for i in old_default]
                else
                    new_val = convert(newtype, old_default)
                end

                ref_vars[var] = MappedVar(
                    source_organs(ref_mapped_var),
                    mapped_variable(ref_mapped_var),
                    source_variable(ref_mapped_var),
                    new_val,
                )
            elseif isa(ref_vars[var], UninitializedVar) && isa(ref_vars[var].value, suptype)
                ref_mapped_var = ref_vars[var]
                old_default = ref_vars[var].value

                if isa(old_default, AbstractArray)
                    new_val = [convert(newtype, i) for i in old_default]
                else
                    new_val = convert(newtype, old_default)
                end

                ref_vars[var] = UninitializedVar(var, new_val)
            end
        end
    end
end

# 通用版本，不执行类型转换：
function convert_vars(ref_vars, type_promotion::Nothing)
    return ref_vars
end

function convert_vars!(ref_vars::Dict{String,Dict{Symbol,Any}}, type_promotion::Nothing)
    return ref_vars
end

"""
    convert_vars!(mapped_vars::Dict{String,Dict{String,Any}}, type_promotion)

使用 `type_promotion` 字典将映射（`mapped_vars`）中的变量类型进行转换。

`mapped_vars` 应为器官名称到变量字典的字典，变量名为 Symbol，变量值为值。
"""
function convert_vars!(mapped_vars::Dict{String,Dict{Symbol,Any}}, type_promotion)
    for (organ, vars) in mapped_vars
        convert_vars!(vars, type_promotion)
    end
end

function Base.show(io::IO, m::MIME"text/plain", t::ModelList)
    show(io, m, dep(t))
    println(io, "")
    show(io, m, status(t))
end

# 简短形式打印（例如用于嵌套对象内部）
function Base.show(io::IO, t::ModelList)
    print(io, "ModelList", (; zip(keys(t.models), typeof.(values(t.models)))...))
end