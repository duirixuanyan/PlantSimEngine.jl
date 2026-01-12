#using Pkg
#Pkg.develop("PlantSimEngine")

# 【核心步骤】
# 告诉 Julia：不要去 C 盘下载，直接用我本地上一级目录的代码！
# 这里的 ".." 指向 G:\GitHub\PlantSimEngine.jl
using Pkg
Pkg.develop(path="..") 

using PlantSimEngine
using PlantMeteo
using DataFrames, CSV
using Documenter
using CairoMakie

# ... 后续代码不变 ...

DocMeta.setdocmeta!(PlantSimEngine, :DocTestSetup, :(using PlantSimEngine, PlantMeteo, DataFrames, CSV, CairoMakie); recursive=true)

makedocs(;
    modules=[PlantSimEngine],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VirtualPlantLab", "PlantSimEngine.jl"),
    sitename="PlantSimEngine.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VirtualPlantLab.github.io/PlantSimEngine.jl",
        edit_link="main",
        assets=String[],
        size_threshold=500000
    ), pages=[
        "首页" => "index.md",
        "简介" => [
            "为什么选择 PlantSimEngine？" => "./introduction/why_plantsimengine.md",
            "为什么选择 Julia？" => "./introduction/why_julia.md",
        ],
        "前置条件" => [
            "PlantSimEngine 的安装与运行" => "./prerequisites/installing_plantsimengine.md",
            "关键概念" => "./prerequisites/key_concepts.md",
            "Julia 语言基础" => "./prerequisites/julia_basics.md",
        ],
        "分步教程 - 单尺度模拟" => [
            "详细的第一个模拟" => "./step_by_step/detailed_first_example.md",
            "模型耦合" => "./step_by_step/simple_model_coupling.md",
            "模型切换" => "./step_by_step/model_switching.md",
            "快速示例" => "./step_by_step/quick_and_dirty_examples.md",
            "实现一个过程" => "./step_by_step/implement_a_process.md",
            "实现一个模型" => "./step_by_step/implement_a_model.md",
            "并行化" => "./step_by_step/parallelization.md",
            "高级耦合与硬依赖" => "./step_by_step/advanced_coupling.md",
            "实现一个模型：补充说明" => "./step_by_step/implement_a_model_additional.md",           
        ],
        "模型执行" => "model_execution.md",
        "数据处理" => [
            "降低自由度" => "./working_with_data/reducing_dof.md",
            "拟合" => "./working_with_data/fitting.md",
            "输入类型" => "./working_with_data/inputs.md",
            "可视化输出与数据" => "./working_with_data/visualising_outputs.md",
            "浮点运算注意事项" => "./working_with_data/floating_point_accumulation_error.md",
        ],
        "多尺度建模" => [
            "多尺度建模考量" => "./multiscale/multiscale_considerations.md",
            "单尺度模型转换为多尺度" => "./multiscale/single_to_multiscale.md",
            "更多变量映射示例" => "./multiscale/multiscale.md",
            "循环依赖的处理" => "./multiscale/multiscale_cyclic.md",
            "多尺度耦合相关说明" => "./multiscale/multiscale_coupling.md",
            "构建简单植株" => [
                "简单植株模拟" => "./multiscale/multiscale_example_1.md",
                "拓展植株模拟" => "./multiscale/multiscale_example_2.md",
                "修复植株模拟中的错误" => "./multiscale/multiscale_example_3.md",
            ],
            "用 PlantGeom 可视化玩具植株" => "./multiscale/multiscale_example_4.md",
        ], 
        "故障排查与测试" => [
            "故障排查" => "./troubleshooting_and_testing/plantsimengine_and_julia_troubleshooting.md",
            "自动化测试" => "./troubleshooting_and_testing/downstream_tests.md",
            "技巧与常见问题" => "./troubleshooting_and_testing/tips_and_workarounds.md",
            "隐性约定" => "./troubleshooting_and_testing/implicit_contracts.md",
        ], 
        "API" => [
            "公共 API" => "./API/API_public.md",
            "示例模型" => "./API/API_examples.md",
            "内部 API" => "./API/API_private.md",
        ],
        "改进文档" => "documentation_improvement.md",
        "开发者指南" => "developers.md",
        "规划功能" => "planned_features.md",
    ]
)

deploydocs(;
    repo="github.com/VirtualPlantLab/PlantSimEngine.jl.git",
    devbranch="main",
    push_preview=true, # Visit https://VirtualPlantLab.github.io/PlantSimEngine.jl/previews/PR128 to visualize the preview of the PR #128
)
