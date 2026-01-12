"""
    MultiScaleModel(model, mapped_variables)

一个用于实现多尺度模型的结构体。它定义了模型变量与节点标记之间的映射，变量值将从这些节点获取。

# 参数

- `model<:AbstractModel`：待多尺度化的模型
- `mapped_variables<:Vector{Pair{Symbol,Union{AbstractString,Vector{AbstractString}}}}`：由符号和字符串（或字符串向量）组成的配对向量

mapped_variables 参数可以有以下形式：

1. `[:variable_name => "Plant"]`：从 Plant 节点获取单个值
2. `[:variable_name => ["Leaf"]]`：从所有 Leaf 节点获取一个值向量
3. `[:variable_name => ["Leaf", "Internode"]]`：从 Leaf 和 Internode 节点获取一个值向量
4. `[:variable_name => "Plant" => :variable_name_in_plant_scale]`：从 Plant 节点以指定变量名获取值
5. `[:variable_name => ["Leaf" => :variable_name_1, "Internode" => :variable_name_2]]`：从 Leaf 和 Internode 节点分别以不同变量名获取值，返回一个向量
6. `[PreviousTimeStep(:variable_name) => ...]`：标记变量用前一时间步的值初始化，该变量不参与依赖图的构建
7. `[:variable_name => :variable_name_from_another_model]`：从相同尺度的其它模型变量获取数据，并重命名
8. `[PreviousTimeStep(:variable_name),]`：纯粹标记为 PreviousTimeStep，不参与依赖图构建

不同形式的详细说明：

1. 模型的 `variable_name` 变量将从 `Plant` 节点获取，假设只有一个节点是 `Plant`。此时 status 里该值是标量，因此用户需确保 MTG 中只有一个 Plant 类型节点。

2. 模型的 `variable_name` 变量将从所有 `Leaf` 节点获取。注意此处为向量，模型需能处理值向量。即使只有一个 Leaf 节点，取到的依然是只有一个元素的向量。

3. 模型的 `variable_name` 变量将从所有 `Leaf` 和 `Internode` 节点获取。即取所有这两类节点的值向量。

4. 模型的 `variable_name` 变量将从 Plant 节点中的 `variable_name_in_plant_scale` 变量获取。当模型变量名与节点变量名不同时可用。

5. 模型的 `variable_name` 变量将分别从 Leaf 节点的 `variable_name_1` 及 Internode 节点的 `variable_name_2` 取得。

6. 模型的 `variable_name` 变量使用上一步计算结果，不用于构建当前步依赖图。可用于变量依赖自身时避免循环依赖。需要时可在 Status 初始化其值。

7. 模型的 `variable_name` 变量从同一尺度但不同变量名的其它模型获取。

8. 模型的 `variable_name` 变量仅作 PreviousTimeStep 标记，不参与依赖图的构建。

请注意，该映射不会复制变量值，仅引用。当某一节点的 status 被更新，其他节点引用的值也随之改变。

# 示例

```jldoctest mylabel
julia> using PlantSimEngine;
```

包含示例过程和模型：

```jldoctest mylabel
julia> using PlantSimEngine.Examples;
```

取一个模型示例：

```jldoctest mylabel
julia> model = ToyCAllocationModel()
ToyCAllocationModel()
```

我们通过定义模型变量和节点标记之间的映射，将其转为多尺度模型。

例如，假设 `carbon_allocation` 来源于 `Leaf` 和 `Internode` 节点，可以定义映射如下：

```jldoctest mylabel
julia> mapped_variables=[:carbon_allocation => ["Leaf", "Internode"]]
1-element Vector{Pair{Symbol, Vector{String}}}:
 :carbon_allocation => ["Leaf", "Internode"]
```

mapped_variables 参数是符号和字符串（或字符串向量）的配对向量。以上例只有一对，表示将 `carbon_allocation` 变量与 `Leaf` 和 `Internode` 关联。

现在将模型及变量映射传递给 `MultiScaleModel` 构造函数，实现多尺度模型：

```jldoctest mylabel
julia> multiscale_model = PlantSimEngine.MultiScaleModel(model, mapped_variables)
MultiScaleModel{ToyCAllocationModel, Vector{Pair{Union{Symbol, PreviousTimeStep}, Union{Pair{String, Symbol}, Vector{Pair{String, Symbol}}}}}}(ToyCAllocationModel(), Pair{Union{Symbol, PreviousTimeStep}, Union{Pair{String, Symbol}, Vector{Pair{String, Symbol}}}}[:carbon_allocation => ["Leaf" => :carbon_allocation, "Internode" => :carbon_allocation]])
```

可访问映射变量和模型：

```jldoctest mylabel
julia> PlantSimEngine.mapped_variables_(multiscale_model)
1-element Vector{Pair{Union{Symbol, PreviousTimeStep}, Union{Pair{String, Symbol}, Vector{Pair{String, Symbol}}}}}:
 :carbon_allocation => ["Leaf" => :carbon_allocation, "Internode" => :carbon_allocation]
```

```jldoctest mylabel
julia> PlantSimEngine.model_(multiscale_model)
ToyCAllocationModel()
```
"""
struct MultiScaleModel{T<:AbstractModel,V<:AbstractVector{Pair{A,Union{Pair{S,Symbol},Vector{Pair{S,Symbol}}}}} where {A<:Union{Symbol,PreviousTimeStep},S<:AbstractString}}
    model::T
    mapped_variables::V

    function MultiScaleModel{T}(model::T, mapped_variables) where {T<:AbstractModel}
        # 检查映射中的变量是否属于模型变量:
        model_variables = keys(variables(model))
        for i in mapped_variables
            # 如果变量是 PreviousTimeStep，则取其 variable 字段，否则取配对的第一个元素:
            var = isa(i, PreviousTimeStep) ? i.variable : first(i)

            # 如果是配对，第一个元素仍可能为 PreviousTimeStep，此时再取 variable 字段:
            var = isa(var, PreviousTimeStep) ? var.variable : var

            if !(var in model_variables)
                error("Mapping for model $model defines variable $var, but it is not a variable of the model.")
            end
        end

        # 若未指定映射目标变量名，则默认为模型中的变量名。具体形式如下:
        # 1. `[:variable_name => "Plant"]` # 从 Plant 节点获取一个值
        # 2. `[:variable_name => ["Leaf"]]` # 从 Leaf 节点获取值向量
        # 3. `[:variable_name => ["Leaf", "Internode"]]` # 从 Leaf 和 Internode 节点获取值向量
        # 4. `[:variable_name => "Plant" => :variable_name_in_plant_scale]` # 从 Plant 节点以指定变量名获取
        # 5. `[:variable_name => ["Leaf" => :variable_name_1, "Internode" => :variable_name_2]]` # 从 Leaf/Internode 节点分别取不同变量名的向量
        # 6. `[PreviousTimeStep(:variable_name) => ...]` # 标记用上一步变量初始化，不参与依赖图构建
        # 7. `[:variable_name => :variable_name_from_another_model]` # 同级其他模型的变量，映射并重命名
        # 8. `[PreviousTimeStep(:variable_name),]` # 仅作 PreviousTimeStep，跳过依赖图

        process_ = process(model)
        unfolded_mapping = Pair{Union{Symbol,PreviousTimeStep},Union{Pair{String,Symbol},Vector{Pair{String,Symbol}}}}[]
        for i in mapped_variables
            push!(unfolded_mapping, _get_var(isa(i, PreviousTimeStep) ? i : Pair(i.first, i.second), process_))
            # 注：使用 Pair(i.first, i.second) 是为了确保配对类型足够专门化，防止向量导致 Pair 类型变为 Pair{Symbol, Any}，如 [:v1 => "S" => :v2,:v3 => "S"] 这种结构
        end

        new{T,typeof(unfolded_mapping)}(model, unfolded_mapping)
    end
end

# 当向量使 Pair 类型不够专门时采用该方法（如 [:v1 => "S" => :v2,:v3 => "S"] 配对变为 Pair{Symbol, Any}）
function _get_var(i::Pair{Symbol,Any}, proc::Symbol=:unknown)
    return _get_var(first(i) => last(i), proc)
end

# 情况1：[:variable_name => "Plant"]
function _get_var(i::Pair{Symbol,S}, proc::Symbol=:unknown) where {S<:String}
    return first(i) => last(i) => first(i)
end

# 情况2和3：[:variable_name => ["Leaf", "Internode"]] 或 [:variable_name => ["Leaf"]]
function _get_var(i::Pair{Symbol,T}, proc::Symbol=:unknown) where {T<:AbstractVector{<:AbstractString}}
    return first(i) => [scale => first(i) for scale in last(i)]
end

# 情况4：[:variable_name => "Plant" => :variable_name_in_plant_scale]，无需处理，直接返回
function _get_var(i::Pair{Symbol,Pair{S,Symbol}}, proc::Symbol=:unknown) where {S<:String}
    return i
end

# 情况5：[:variable_name => ["Leaf" => :variable_name_1, "Internode" => :variable_name_2]]
function _get_var(i::Pair{Symbol,T}, proc::Symbol=:unknown) where {T<:AbstractVector{Pair{S,Symbol}} where {S<:AbstractString}}
    return i # 注：无需处理，映射已符合格式
end

# 情况6：[PreviousTimeStep(:variable_name) => ...]
function _get_var(i::Pair{PreviousTimeStep,T}, proc::Symbol=:unknown) where {T}
    vars = _get_var(i.first.variable => i.second, proc) # 利用已有方法递归生成
    return PreviousTimeStep(first(i).variable, proc) => last(vars) # 恢复 PreviousTimeStep 为第一个元素
end

# 情况7：[:variable_name => :variable_name_from_another_proc]
function _get_var(i::Pair{Symbol,Symbol}, proc::Symbol=:unknown)
    return first(i) => "" => last(i)
end

# 情况8：[PreviousTimeStep(:variable_name),]
function _get_var(i::PreviousTimeStep, proc::Symbol=:unknown)
    return PreviousTimeStep(i.variable, proc) => "" => i.variable
end



function MultiScaleModel(model::T, mapped_variables) where {T<:AbstractModel}
    MultiScaleModel{T}(model, mapped_variables)
end
MultiScaleModel(; model, mapped_variables) = MultiScaleModel(model, mapped_variables)

mapped_variables_(m::MultiScaleModel) = m.mapped_variables
model_(m::MultiScaleModel) = m.model
inputs_(m::MultiScaleModel) = inputs_(m.model)
outputs_(m::MultiScaleModel) = outputs_(m.model)
get_models(m::MultiScaleModel) = [model_(m)] # 获取 MultiScaleModel 的所有内部模型
# 注：此处返回模型向量，是因为用户只传入了一个 MultiScaleModel 而不是一组
get_status(m::MultiScaleModel) = nothing
get_mapped_variables(m::MultiScaleModel{T,S}) where {T,S} = mapped_variables_(m)