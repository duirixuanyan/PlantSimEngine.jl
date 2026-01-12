"""
    inputs(model::AbstractModel)
    inputs(...)

获取一个或多个模型的输入变量。

对于 `AbstractModel`（无输入变量）或 `Missing` 类型的模型，默认返回空元组。

# 示例

```jldoctest
using PlantSimEngine;

# Load the dummy models given as example in the package:
using PlantSimEngine.Examples;

inputs(Process1Model(1.0))

# output
(:var1, :var2)
```
"""
function inputs(model::T) where {T<:AbstractModel}
    keys(inputs_(model))
end

function inputs_(model::AbstractModel)
    NamedTuple()
end

function inputs(v::T, vars...) where {T<:AbstractModel}
    length((vars...,)) > 0 ? union(inputs(v), inputs(vars...)) : inputs(v)
end

function inputs_(model::Missing)
    NamedTuple()
end

"""
    inputs(mapping::Dict{String,T})

获取映射中每个过程和器官类型的模型输入变量。
"""
function inputs(mapping::Dict{String,T}) where {T}
    vars = Dict{String,NamedTuple}()
    for organ in keys(mapping)
        mods = pairs(parse_models(get_models(mapping[organ])))
        push!(vars, organ => (; (i.first => (inputs(i.second)...,) for i in mods)...))
    end
    return vars
end


"""
    outputs(model::AbstractModel)
    outputs(...)

获取一个或多个模型的输出变量。

对于 `AbstractModel`（无输出变量）或 `Missing` 类型的模型，默认返回空元组。

# 示例

```jldoctest
using PlantSimEngine;

# Load the dummy models given as example in the package:
using PlantSimEngine.Examples;

outputs(Process1Model(1.0))

# output
(:var3,)
```
"""
function outputs(model::T) where {T<:AbstractModel}
    keys(outputs_(model))
end

function outputs(v::T, vars...) where {T<:AbstractModel}
    length((vars...,)) > 0 ? union(outputs(v), outputs(vars...)) : outputs(v)
end

"""
    outputs(mapping::Dict{String,T})

获取映射中每个过程和器官类型的模型输出变量。
"""
function outputs(mapping::Dict{String,T}) where {T}
    vars = Dict{String,NamedTuple}()
    for organ in keys(mapping)
        mods = pairs(parse_models(get_models(mapping[organ])))
        push!(vars, organ => (; (i.first => (outputs(i.second)...,) for i in mods)...))
    end
    return vars
end


function outputs_(model::AbstractModel)
    NamedTuple()
end

function outputs_(model::Missing)
    NamedTuple()
end


"""
    variables(model)
    variables(model, models...)

返回模型所需变量的名称元组，或多个模型变量名的并集。

# 注意

每个模型都可以（且应该）为此函数定义一个方法。

```jldoctest

using PlantSimEngine;

# Load the dummy models given as example in the package:
using PlantSimEngine.Examples;

variables(Process1Model(1.0))

variables(Process1Model(1.0), Process2Model())

# output

(var1 = -Inf, var2 = -Inf, var3 = -Inf, var4 = -Inf, var5 = -Inf)
```

# 参见

[`inputs`](@ref), [`outputs`](@ref) and [`variables_typed`](@ref)
"""
function variables(m::T, ms...) where {T<:Union{Missing,AbstractModel}}
    length((ms...,)) > 0 ? merge(variables(m), variables(ms...)) : merge(inputs_(m), outputs_(m))
end

function variables(m::SoftDependencyNode)
    self_variables = (inputs=inputs_(m.value), outputs=outputs_(m.value))
    # hard_dep_vars = map(variables, m.hard_dependencies)
    return self_variables
end

function variables(m::HardDependencyNode)
    return (inputs=inputs_(m.value), outputs=outputs_(m.value))
end

"""
    variables(pkg::Module)

返回某个依赖 PlantSimEngine 的包中所有变量、变量描述及单位的数据表（需包作者实现）。

# 开发者注意事项

依赖 PlantSimEngine 的包开发者应将变量信息写入 "data/variables.csv" 文件，
该函数会返回此文件的内容。

# 示例

以下为 PlantBiophysics 包的示例：

```julia
#] add PlantBiophysics
using PlantBiophysics
variables(PlantBiophysics)
```
"""
function variables(pkg::Module)
    sort!(CSV.read(joinpath(dirname(dirname(pathof(pkg))), "data", "variables.csv"), DataFrames.DataFrame))
end

"""
    variables(mapping::Dict{String,T})

获取映射中每个过程和器官类型模型的变量（输入与输出）。
"""
function variables(mapping::Dict{String,T}) where {T}
    vars = Dict{String,NamedTuple}()
    for organ in keys(mapping)
        mods = pairs(parse_models(get_models(mapping[organ])))
        push!(vars, organ => (; (i.first => (; variables(i.second)...,) for i in mods)...))
    end
    return vars
end

"""
    variables_typed(model)
    variables_typed(model, models...)

返回模型所需变量（变量名及类型）的具名元组，或多个模型的变量类型联合。

# 示例

```jldoctest
using PlantSimEngine;

# Load the dummy models given as example in the package:
using PlantSimEngine.Examples;

PlantSimEngine.variables_typed(Process1Model(1.0))
(var1 = Float64, var2 = Float64, var3 = Float64)

PlantSimEngine.variables_typed(Process1Model(1.0), Process2Model())

# output
(var4 = Float64, var5 = Float64, var1 = Float64, var2 = Float64, var3 = Float64)
```

# 参见

[`inputs`](@ref), [`outputs`](@ref) and [`variables`](@ref)

"""
function variables_typed(m::T) where {T<:AbstractModel}

    in_vars = inputs_(m)
    in_vars_type = Dict(zip(keys(in_vars), typeof(in_vars).types))
    out_vars = outputs_(m)
    out_vars_type = Dict(zip(keys(out_vars), typeof(out_vars).types))

    # 合并输入和输出变量的类型，并进行自动类型提升
    vars = mergewith(promote_type, in_vars_type, out_vars_type)

    # 检查输入输出变量是否具有相同类型
    vars_different_types = diff_vars(in_vars_type, out_vars_type)
    if length(vars_different_types) > 0
        @warn """The following variables have different types between models:
                    $vars_different_types, they will be promoted."""
    end

    return (; vars...)
end

function variables_typed(m::T, ms...) where {T<:AbstractModel}
    if length((ms...,)) > 0
        m_vars = variables_typed(m)
        ms_vars = variables_typed(ms...)
        m_vars_dict = Dict(zip(keys(m_vars), values(m_vars)))
        ms_vars_dict = Dict(zip(keys(ms_vars), values(ms_vars)))
        vars = mergewith(promote_type, m_vars_dict, ms_vars_dict)
        #! 当 NamedTuples 支持 mergewith 时可去除此转换，参见：https://github.com/JuliaLang/julia/issues/36048

        vars_different_types = diff_vars(m_vars, ms_vars)
        if length(vars_different_types) > 0
            @warn """The following variables have different types between models:
            $vars_different_types, they will be promoted."""
        end

        return (; vars...)
    else
        return variables_typed(m)
    end
end

"""
    diff_vars(x, y)

返回 x 和 y 中值不同的变量名称。
"""
function diff_vars(x, y)
    # 检查两个对象中变量是否具有相同的值
    common_vars = intersect(keys(x), keys(y))
    vars_different_types = []

    if length(common_vars) > 0
        for i in common_vars
            if x[i] != y[i]
                push!(vars_different_types, i)
            end
        end
    end
    return vars_different_types
end