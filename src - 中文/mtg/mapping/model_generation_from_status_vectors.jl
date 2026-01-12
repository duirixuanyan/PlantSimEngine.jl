# 工具函数：用于处理传递给mapping中status的向量
# 主要用于原型开发时的便利，**不推荐**在生产或正式拟合时使用
# （正式定型的模型应明确写出）

# 从status向量生成模型的方式是：运行时用eval()动态生成代码
# 一个自定义的timestep模型为所生成的模型提供正确的索引
# 这种方式虽然有点脆弱但确实可行。可能的改进方案之一是直接操作AST，但那会更复杂
# 另一种方式是生成字符串再用include_string，这样可能可以避开全局变量和world age的问题

# 依然存在脆弱性，因为处理用户/建模者错误并不简单
# 比如，在scale mapping里用到一个向量，通常会出错

# 未来可能需要更复杂的timestep模型
# TODO : 未处理的情况：如果传入的modellist中已经包含timestep模型怎么办？

# 这些模型未来可能值得暴露出来？

PlantSimEngine.@process "basic_current_timestep" verbose = false

struct HelperCurrentTimestepModel <: AbstractBasic_Current_TimestepModel
end

PlantSimEngine.inputs_(::HelperCurrentTimestepModel) = (next_timestep=1,)
PlantSimEngine.outputs_(m::HelperCurrentTimestepModel) = (current_timestep=1,)

function PlantSimEngine.run!(m::HelperCurrentTimestepModel, models, status, meteo, constants=nothing, extra=nothing)
    status.current_timestep = status.next_timestep
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:HelperCurrentTimestepModel}) = PlantSimEngine.IsObjectDependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:HelperCurrentTimestepModel}) = PlantSimEngine.IsTimeStepDependent()

PlantSimEngine.@process "basic_next_timestep" verbose = false
struct HelperNextTimestepModel <: AbstractBasic_Next_TimestepModel
end

PlantSimEngine.inputs_(::HelperNextTimestepModel) = (current_timestep=1,)
PlantSimEngine.outputs_(m::HelperNextTimestepModel) = (next_timestep=1,)

function PlantSimEngine.run!(m::HelperNextTimestepModel, models, status, meteo, constants=nothing, extra=nothing)
    status.next_timestep = status.current_timestep + 1
end

PlantSimEngine.ObjectDependencyTrait(::Type{<:HelperNextTimestepModel}) = PlantSimEngine.IsObjectDependent()
PlantSimEngine.TimeStepDependencyTrait(::Type{<:HelperNextTimestepModel}) = PlantSimEngine.IsTimeStepDependent()


# TODO new_status 是否应当复制？
# 注意：用户指定在哪一级插入基础timestep模型，以及气象数据长度（meteo length）
function replace_mapping_status_vectors_with_generated_models(mapping_with_vectors_in_status, timestep_model_organ_level, nsteps)

    (organ, check) = check_statuses_contain_no_remaining_vectors(mapping_with_vectors_in_status)
    if check
        @warn "No vectors, or types deriving from AbstractVector found in statuses, returning mapping as is."
        return mapping_with_vectors_in_status
    end

    # 此时可以确定会生成模型，且timestep模型也要插入
    mapping = Dict(organ => models for (organ, models) in mapping_with_vectors_in_status)
    for (organ,models) in mapping
        for status in models
            if isa(status, Status)
                # 生成模型，并从status中去除相应的向量
                new_status, generated_models = generate_model_from_status_vector_variable(mapping, timestep_model_organ_level, status, organ, nsteps)

                # 避免向mapping中插入空的namedtuple
                models_and_new_status = [model for model in models if !isa(model, Status)]
                if length(new_status) != 0
                    models_and_new_status = [models_and_new_status..., new_status]
                end

                # timestep模型可能要插入到mapping的其他地方，需兼容多种情况
                if length(generated_models) > 0
                    mapping[organ] = (
                        generated_models...,
                        models_and_new_status...,)
                end
            end
        end

        # 在需要的地方插入timestep模型
        if organ == timestep_model_organ_level
            # 指定level的mapping可以是tuple，也可以是单一模型
            if isa(mapping[organ], AbstractModel) || isa(mapping[organ], MultiScaleModel)
                mapping[organ] = (
                    HelperNextTimestepModel(),
                    MultiScaleModel(
                        model=HelperCurrentTimestepModel(),
                        mapped_variables=[PreviousTimeStep(:next_timestep),],
                    ),
                    mapping[organ], )
            else
                mapping[organ] = (
                    HelperNextTimestepModel(),
                    MultiScaleModel(
                        model=HelperCurrentTimestepModel(),
                        mapped_variables=[PreviousTimeStep(:next_timestep),],
                    ),
                    mapping[organ]..., )
            end
        end
    end

    return mapping
end

# 注意：eval在全局作用域执行，状态同步直到返回顶层才会发生
# 这能优化性能，但会引发“world-age problem”。eval文档对此并不详细。
# 本质上，如果用process_方法生成一个struct，然后立刻创建仿真图graph并调用process_，会因状态未同步失败；
# 返回新的mapping到顶层*然后*创建graph才可行。
# 之所以用一些全局变量，是因为eval只在全局作用域有效
function generate_model_from_status_vector_variable(mapping, timestep_scale, status, organ, nsteps)

    # 注意：534f1c161f91bb346feba1a84a55e8251f5ad446前缀用于降低全局变量名冲突概率
    # 它是 bytes2hex(sha1("PlantSimEngine_prototype")) 得到的哈希
    # 若此函数太难读，拷到临时文件去除哈希后缀即可

    # 补充说明：从meteo文件读到的CSV.SentinelArrays.ChainedVector不是AbstractVector
    # 意味着现阶段不会以它为基础自动生成模型，除非提前转换
    # 另一个小的提升点是：在生成模型时，提醒用户并做自动转换
    # 参见test-mapping.jl中的测试代码：cumsum(meteo_day.TT)就会返回该类型

    global generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446 = ()
    global new_status_534f1c161f91bb346feba1a84a55e8251f5ad446 = Status(NamedTuple())

    for symbol in keys(status)
        global value_534f1c161f91bb346feba1a84a55e8251f5ad446 = getproperty(status, symbol)
        if isa(value_534f1c161f91bb346feba1a84a55e8251f5ad446, AbstractVector)
            @assert length(value_534f1c161f91bb346feba1a84a55e8251f5ad446) > 0 "Error during generation of models from vector values provided at the $organ-level status : provided $symbol vector is empty"
            # TODO：未来如有变化步长（timestep）模型，这里还需处理
            @assert nsteps == length(value_534f1c161f91bb346feba1a84a55e8251f5ad446) "Error during generation of models from vector values provided at the $organ-level status : provided $symbol vector length doesn't match the expected # of timesteps"
            var_type = eltype(value_534f1c161f91bb346feba1a84a55e8251f5ad446)
            base_name = string(symbol) * bytes2hex(sha1(join(value_534f1c161f91bb346feba1a84a55e8251f5ad446)))
            process_name = lowercase(base_name)

            var_titlecase::String = titlecase(base_name)
            model_name = "My$(var_titlecase)Model"
            process_abstract_name = "Abstract$(var_titlecase)Model"
            var_vector = "$(symbol)_vector"

            abstract_process_decl = "abstract type $process_abstract_name <: PlantSimEngine.AbstractModel end"
            eval(Meta.parse(abstract_process_decl))

            process_name_decl = "PlantSimEngine.process_(::Type{$process_abstract_name}) = :$process_name"
            eval(Meta.parse(process_name_decl))

            struct_decl::String = "struct $model_name <: $process_abstract_name \n$var_vector::Vector{$var_type} \nend\n"
            eval(Meta.parse(struct_decl))

            inputs_decl::String = "function PlantSimEngine.inputs_(::$model_name)\n(current_timestep=1,)\nend\n"
            eval(Meta.parse(inputs_decl))

            default_value = value_534f1c161f91bb346feba1a84a55e8251f5ad446[1]
            outputs_decl::String = "function PlantSimEngine.outputs_(::$model_name)\n($symbol=$default_value,)\nend\n"
            eval(Meta.parse(outputs_decl))

            constructor_decl =  "$model_name(; $var_vector = Vector{$var_type}()) = $model_name($var_vector)\n"
            eval(Meta.parse(constructor_decl))

            run_decl = "function PlantSimEngine.run!(m::$model_name, models, status, meteo, constants=nothing, extra_args=nothing)\nstatus.$symbol = m.$var_vector[status.current_timestep]\nend\n"
            eval(Meta.parse(run_decl))

            model_add_decl = "generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446 = (generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446..., $model_name($var_vector=$value_534f1c161f91bb346feba1a84a55e8251f5ad446),)"

            # 若:current_timestep不在当前scale
            if timestep_scale != organ
                model_add_decl = "generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446 = (generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446..., MultiScaleModel(model=$model_name($value_534f1c161f91bb346feba1a84a55e8251f5ad446), mapped_variables=[:current_timestep=>\"$timestep_scale\"],),)"
            end

            eval(Meta.parse(model_add_decl))
        else
            new_status_decl = "new_status_534f1c161f91bb346feba1a84a55e8251f5ad446 = Status(; NamedTuple(new_status_534f1c161f91bb346feba1a84a55e8251f5ad446)..., $symbol=$value_534f1c161f91bb346feba1a84a55e8251f5ad446)"
            eval(Meta.parse(new_status_decl))
        end
    end

    @assert length(status) == length(new_status_534f1c161f91bb346feba1a84a55e8251f5ad446) + length(generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446) "Error during generation of models from vector values provided at the $organ-level status"
    return new_status_534f1c161f91bb346feba1a84a55e8251f5ad446, generated_models_534f1c161f91bb346feba1a84a55e8251f5ad446
end


# 仅为测试目的的辅助函数，但合理放在这里，因为它会调用带有那些全局变量的generate_model_from_status_vector_variable
function modellist_to_mapping(modellist_original::ModelList, modellist_status; nsteps=nothing, outputs=nothing)

    modellist = Base.copy(modellist_original, modellist_original.status)

    default_scale = "Default"
    mtg = MultiScaleTreeGraph.Node(MultiScaleTreeGraph.NodeMTG("/", default_scale, 0, 0),)

    models = modellist.models

    mapping_incomplete = isnothing(modellist_status) ?
        (
            Dict(
                default_scale => (
                    models...,
                    MultiScaleModel(
                        model=HelperCurrentTimestepModel(),
                        mapped_variables=[PreviousTimeStep(:next_timestep),],
                    ),
                    Status((current_timestep=1,next_timestep=1,))
                ),
            )) : (
            Dict(
                default_scale => (
                    models...,
                    MultiScaleModel(
                        model=HelperCurrentTimestepModel(),
                        mapped_variables=[PreviousTimeStep(:next_timestep),],
                    ),
                    Status((modellist_status..., current_timestep=1,next_timestep=1,))
                ),
            )
        )
    timestep_scale = "Default"
    organ = "Default"

    # todo 再改进
    st = (last(mapping_incomplete["Default"]))
    new_status, generated_models = generate_model_from_status_vector_variable(mapping_incomplete, timestep_scale, st, organ, nsteps)

    mapping = Dict(default_scale => (
        models..., generated_models...,
        HelperNextTimestepModel(),
        MultiScaleModel(
            model=HelperCurrentTimestepModel(),
            mapped_variables=[PreviousTimeStep(:next_timestep),],
        ),
        new_status,
    ),
    )

    if isnothing(outputs)
        f = []
        for i in 1:length(modellist.models)
            aa = init_variables(modellist.models[i])
            bb = keys(aa)
            for j in 1:length(bb)
                push!(f, bb[j])
            end
            #f = (f..., bb...)
        end

        f = unique!(f)
        all_vars = (f...,)
        #all_vars = merge((keys(init_variables(object.models[i])) for i in 1:length(object.models))...)
    else
        all_vars = outputs
        # TODO 校验
    end

    return mtg, mapping, Dict(default_scale => all_vars)
end

function check_statuses_contain_no_remaining_vectors(mapping)
    for (organ,models) in mapping

        # 特殊情况（user为了方便，scale映射单一模型时不用写成tuple）
        if isa(models, AbstractModel) || isa(models, MultiScaleModel)
            continue
        end

        for status in models
            if isa(status, Status)
                for symbol in keys(status)
                    value = getproperty(status, symbol)
                    if isa(value, AbstractVector)
                        return (organ, false)
                    end
                end
            end
        end
    end
    return ("", true)
end