""" 
    UninitializedVar(variable, value)

尚未初始化的变量，赋予一个名称和一个默认值。
"""
struct UninitializedVar{T}
    variable::Symbol
    value::T
end

Base.eltype(u::UninitializedVar{T}) where {T} = T
source_variable(m::UninitializedVar) = m.variable
source_variable(m::UninitializedVar, org) = m.variable

"""
    PreviousTimeStep(variable)

用于手动标记模型中某变量以采用上一个时间步中计算的值的结构体。
这意味着该变量不会被用于构建依赖关系图，因为依赖关系图仅适用于当前时间步。
当变量依赖于自身时，为了避免循环依赖，可以使用该方法。
如有需要，其值可以在 Status 中初始化。

当构建 MultiScaleModel 时会添加该过程，以避免不同进程之间具有相同变量名时的冲突。
例如，一个进程可以将变量 `:carbon_biomass` 定义为 `PreviousTimeStep`，而另一个进程则将该变量作为当前时间步的依赖项使用（这样是允许的，因为它们不会出现循环依赖的问题）。
"""
struct PreviousTimeStep
    variable::Symbol
    process::Symbol
end

PreviousTimeStep(v::Symbol) = PreviousTimeStep(v, :unknown)

"""
    RefVariable(reference_variable)

用于手动标记模型中的某个变量，以在**相同尺度**下采用另一个变量的值的结构体。
用于变量重命名，当某变量已经由一个模型计算，但被另一个名称所引用时使用。

注意：在 status 中我们并不会真正重命名变量（其他模型可能需要这个变量），而是新建一个对原有变量的引用。
"""
struct RefVariable
    reference_variable::Symbol
end