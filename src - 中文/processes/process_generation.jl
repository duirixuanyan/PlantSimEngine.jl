"""
    @process(process::String, doc::String=""; verbose::Bool=true)

该宏用于生成某一过程的抽象类型及部分仿真的样板代码，并自动生成相关文档。如果`verbose=true`，还会输出简短的模型实现教程。

该抽象过程类型会作为所有该过程模型实现的父类型，其名称形式为 "Abstract<ProcessName>Model"，例如对于过程名 "growth"，其父类型为 `AbstractGrowthModel`。

@process 的第一个参数为新过程名称，第二个参数为附加到 `Abstract<ProcessName>Model` 类型上的额外文档内容，第三个参数决定是否打印简短教程。

建议新用户使用该宏，因为它会详细说明后续的操作流程。更有经验的用户可直接定义 abstract type 并指定为 `AbstractModel` 的子类，而不输出教程：

```julia
abstract type MyNewProcess <: AbstractModel end
```

# 例子

```julia
@process "dummy_process" "This is a dummy process that shall not be used"
```
"""
macro process(f, args...)

    # 解析参数。宏本身不支持关键字参数（详见 https://stackoverflow.com/a/64116235）:
    aargs = []
    aakws = Pair{Symbol,Any}[]
    for el in args
        if Meta.isexpr(el, :(=))
            # 关键字参数:
            push!(aakws, Pair(el.args...))
        else
            # 位置参数:
            push!(aargs, el)
        end
    end

    # 过程函数的文档字符串为第一个位置参数:
    if length(aargs) > 1
        error("Too many positional arguments to @process")
    end
    # 默认为空字符串:
    doc = length(aargs) == 1 ? aargs[1] : ""

    # 唯一的关键字参数为verbose，默认为true:
    if length(aakws) > 1 || (length(aakws) == 1 && aakws[1].first != :verbose)
        error("@process only accepts one keyword argument: verbose")
    end
    verbose = length(aakws) == 1 ? aakws[1].second : true

    process_field = Symbol(f)

    # 文档用字符串:
    process_name = string(process_field)
    process_abstract_type_name = string("Abstract", titlecase(process_name), "Model")
    process_abstract_type = Symbol(process_abstract_type_name)

    expr = quote
        # 为该过程生成抽象结构体:
        @doc string("""
        `$($process_name)` 过程的抽象模型类型。

        所有模拟 `$($process_name)` 过程的模型都必须为此类型的子类型，例如: 
        `struct My$($(titlecase(process_name)))Model <: $($process_abstract_type_name) end`。

        可通过 `subtypes` 查看实现该过程的所有模型：

        # 例子

        ```julia
        subtypes($($process_abstract_type_name))
        ```
        """, $(doc))
        abstract type $(esc(process_abstract_type)) <: AbstractModel end

        # 生成通过类型获取过程名称的函数:
        PlantSimEngine.process_(::Type{$(esc(process_abstract_type))}) = Symbol($process_name)
    end

    # 创建过程时打印帮助信息:
    dummy_type_name = string("My", titlecase(process_name), "Model")
    p = Term.RenderableText(
        Markdown.parse("""\'{underline bold red}$(process_name){/underline bold red}\' process, generated:

        * {#8abeff}run!(){/#8abeff} to compute the process in-place.      

        * {#8abeff}$(process_abstract_type){/#8abeff}, an abstract struct used as a supertype for models implementations.

        !!! tip "What's next?"
            You can now define one or several models implementations for the {underline bold red}$(process_name){/underline bold red} process
            by adding a method to {#8abeff}run!(){/#8abeff} with your own model type

        Here's an example implementation where we define a new model type called {underline bold red}$(dummy_type_name){/underline bold red},
        with a single parameter `a`:

        ```julia
            struct $(dummy_type_name) <: $(process_abstract_type)
                a::Float64
            end
        ```

        We also have to define the model inputs and outputs by adding methods to `inputs_`:

        ```julia
            PlantSimEngine.inputs_(::$(dummy_type_name)) = (X=-Inf,)
        ```

        And `outputs_` from PlantSimEngine:

        ```julia
            PlantSimEngine.outputs_(::$(dummy_type_name)) = (Y=-Inf,)
        ```

        Optionnaly, you can declare a hard-dependency on another process that is called
        inside your process implementation:

        ```julia
            PlantSimEngine.dep(::$(dummy_type_name)) = (other_process_name=AbstractOtherProcessModel,)
        ```

        And finally, we can define the model implementation by adding a method to `run!`:

        ```julia
        function PlantSimEngine.run!(
            ::$(dummy_type_name),
            models,
            status,
            meteo,
            constants,
            extra
        )
            status.Y = model.$(process_name).a * meteo.CO2 + status.X
            run!(model.other_process_name, models, status, meteo, constants, extra)
        end
        ```

        Note that {#8abeff}run!(){/#8abeff} takes six arguments: the model type (used for dispatch), the ModelList, the status, the meteorology,
        the constants and any extra values.

        Then we can use variables from the status as inputs or outputs, model parameters from the ModelList (indexing by process, here 
        using "$(process_name)" as the process name), and meteorology variables.

        Note that our example model has an hard-dependency on another process called `other_process_name` that is called using the {#8abeff}run!(){/#8abeff} function with 
        the process as the first argument: `run!(model.other_process_name, models, status, meteo, constants, extra)`.

        If your model can be run in parallel, you can also add traits to your model type so `PlantSimEngine` knows
        it can safely parallelize the computation:

        - over space (*i.e.* over objects):

        ```@example usepkg
        PlantSimEngine.ObjectDependencyTrait(::Type{<:$(dummy_type_name)}) = PlantSimEngine.IsObjectIndependent()
        ```

        - over time (*i.e.* time-steps):

        ```@example usepkg
        PlantSimEngine.TimeStepDependencyTrait(::Type{<:$(dummy_type_name)}) = PlantSimEngine.IsTimeStepIndependent()
        ```

        !!! tip "Variables and parameters usage"
            Note that {#8abeff}run!(){/#8abeff} takes six arguments: the model type (used
            for dispatch), the ModelList, the status, the meteorology, the constants and
            any extra values.
            Then we can use variables from the status as inputs or outputs, model parameters
            from the ModelList (indexing by process, here using "$(process_name)" as the
            process name), and meteorology variables.
        """
        )
    )

    isinteractive() && verbose && print(p)

    return expr
end
