"""
    check_dimensions(component,weather)
    check_dimensions(status,weather)

检查组件状态（或直接检查状态）和天气数据长度是否一致，或它们是否可以被复用（其中一个的长度为1）。

# 示例
```jldoctest
using PlantSimEngine, PlantMeteo

# 引入包含虚拟过程和模型的示例脚本：
using PlantSimEngine.Examples

# 创建一个虚拟天气：
w = Atmosphere(T = 20.0, Rh = 0.5, Wind = 1.0)

# 创建一个虚拟组件：
models = ModelList(
    process1=Process1Model(1.0),
    process2=Process2Model(),
    process3=Process3Model(),
    status=(var1=[15.0, 16.0], var2=0.3)
)

# 检查时间步数是否兼容（此处兼容，返回nothing）：
PlantSimEngine.check_dimensions(models, w) 

# 创建一个包含3个时间步的虚拟天气：
w = Weather([
    Atmosphere(T = 20.0, Rh = 0.5, Wind = 1.0),
    Atmosphere(T = 25.0, Rh = 0.5, Wind = 1.0),
    Atmosphere(T = 30.0, Rh = 0.5, Wind = 1.0)
])

# 检查时间步数是否兼容（此处不兼容，会抛出错误）：
PlantSimEngine.check_dimensions(models, w)

# output
ERROR: DimensionMismatch: Component status has a vector variable : var1 implying multiple timesteps but weather data only provides a single timestep.
```
"""
check_dimensions(component, weather) = check_dimensions(DataFormat(weather), component, weather)

# 这里添加适用于组件、本身为数组或字典形式的多组件的方法
function check_dimensions(component::T, w) where {T<:ModelList}
    check_dimensions(status(component), w)
end

# 针对数组形式的多个组件
function check_dimensions(component::T, weather) where {T<:AbstractArray{<:ModelList}}
    for i in component
        check_dimensions(i, weather)
    end
end

# 针对字典形式的多个组件
function check_dimensions(component::T, weather) where {T<:AbstractDict{N,<:ModelList} where {N}}
    for (key, val) in component
        check_dimensions(val, weather)
    end
end


# TODO 多步长处理

# Status（单一步长）总是允许与Weather（可复用）一起使用。
# 状态会在每个时间步更新，但不会有中间保存！
function check_dimensions(::TableAlike, st::Status, weather)
    weather_len = get_nsteps(weather)

    for (var, value) in zip(keys(st), st)
        if length(value) > 1
            if length(value) != weather_len
                throw(DimensionMismatch("Component status has a vector variable : $(var) of length $(length(value)) but the weather data expects $(weather_len) timesteps."))
            end
        end
    end

    return nothing
end

function check_dimensions(::SingletonAlike, st::Status, weather)
    for (var, value) in zip(keys(st), st)
        if length(value) > 1 
            throw(DimensionMismatch("Component status has a vector variable : $(var) implying multiple timesteps but weather data only provides a single timestep."))
        end
    end

    return nothing
end

function check_dimensions(::SingletonAlike, ::SingletonAlike, st, weather)
    return nothing
end


"""
    get_nsteps(t)

获取对象的时间步数量。
"""
function get_nsteps(t)
    get_nsteps(DataFormat(t), t)
end

function get_nsteps(::SingletonAlike, t)
    1
end

function get_nsteps(::TableAlike, t)
    DataAPI.nrow(t)
end