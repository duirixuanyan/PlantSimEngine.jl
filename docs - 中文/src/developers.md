# 开发者指南

本页面面向希望为 PlantSimEngine 做出贡献的开发者，说明了在添加新代码时需要注意的各方面内容。

## 参与 PlantSimEngine 开发

开发流程与其他 Julia 包没有不同。请使用 git 克隆代码仓库：[https://github.com/VirtualPlantLab/PlantSimEngine.jl](https://github.com/VirtualPlantLab/PlantSimEngine.jl)。

在测试你的更改时，需要在环境中运行类似 `Pkg.develop("PlantSimEngine")` 的命令，以便使用你修改后的代码。

我们推荐使用 VSCode 作为 Julia 开发的集成开发环境（IDE）。开发过程中主要遵循官方文档的 [Julia 代码规范](https://docs.julialang.org/en/v1/manual/style-guide/)。

在完成必要的代码检查后（详见下方的 [PR 提交前检查清单](@ref)），即可创建 Pull Request；如有添加新内容的需求，也可申请加入贡献者名单。

本开发文档包含 [路线图](@ref)。已知问题与相关讨论可在[此处](https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues)查阅。部分内容已过期，部分为功能讨论，其余为真实缺陷或改进建议。

更多细节问题，欢迎在 Issue 页面中提出，或直接在你的 Pull Request 中说明。

## 快速指南

### 测试环境

PlantSimEngine 提供了多个开发者用的测试环境：

- `/PlantSimEngine/test`：用于检查代码是否存在回归问题。
- `/PlantSimEngine/test/downstream`：该文件夹包含了一些关于 PlantSimEngine、PlantBioPhysics 和 XPalm 的基准测试。它们会作为 Github Action 运行，以确保你的更改不会导致依赖 PlantSimEngine 的其它包出现性能下降。如果你希望在本地运行这些测试，需要能访问上述依赖包的版本。请注意，这与 Github Action 里进行集成检查、防止意外破坏性更改的步骤是分开的。
- `/PlantSimEngine/docs`：用于生成文档。文档生成过程会实际运行部分代码，部分 API 函数的文档中也会作为 `jldoctest` 实例进行测试。

### 运行标准测试集

只需在测试环境下执行 `/PlantSimEngine/test/runtests.jl` 即可运行标准测试集。请注意，如果要运行多线程测试，必须以多线程方式启动 Julia。

你还需要安装配套包 PlantMeteo 和 MultiScaleTreeGraph，以及其它 Julia 包，如 DataFrames、CSV、Documenter、Test、Aqua 和 Tables。

### 下游测试

在已正确添加 XPalm 和 PlantBioPhysics 后，可执行 `/PlantSimEngine/test/downstream/test/test-all-benchmarks.jl` 运行下游测试。你可能需要为本地运行这个脚本再安装某些包。

### 构建文档

在 `/PlantSimEngine/docs` 环境下，运行 `/PlantSimEngine/docs/make.jl` 来构建文档。这里可能需要用到在其它地方不强制要求的包（Documenter、CairoMakie、PlantGeom）。

### 编辑基准测试（benchmarks）

⁃ 如果你希望某个分支在每次提交后都自动运行基准测试，需要在 Github Action 的基准测试 yml 文件中声明该分支：[https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/.github/workflows/benchmarks_and_downstream.yml](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/.github/workflows/benchmarks_and_downstream.yml)，并把你的分支名添加到 `on: push:` 这一段中。
⁃ 你可以在这里查看基准测试结果：<https://virtualplantlab.github.io/PlantSimEngine.jl/dev/bench/index.html>。目前这些基准测试还在完善中，还没有经过充分验证。
⁃ 偶尔你可能需要更新或删除某个基准测试，这时需要手动到 **gh-pages** 分支下的 `dev/bench/index.html` 文件中删除对应内容。
⁃ 实际基准测试的列表是在 `test/downstream` 文件夹中维护的。

## 需要特别关注的事项

### 检查下游测试

⁃ 如果你的更改影响到了 API，那么可能会影响到依赖 PlantSimEngine 的其它包。部分基准测试会调用其它包，可以通过它们进行检测；此外有一个专门的 GitHub Action：[https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/.github/workflows/Integration.yml]，会运行其它下游包的测试。如果这个 Action 失败，通常说明引入了尚未在下游包中修正的破坏性更改。如果你本身预计是破坏性更改，且已正确设置了发布标签，则不会导致失败。
⁃ 请注意，这些测试流程（据我理解）并不会构建文档，因此不会覆盖到文档相关的问题。
⁃ API 的更改也可能影响下游包的文档和测试……

### 哪些文档页面可能会受更改影响

根据你的实际更改，不同的文档页面可能会受到影响。功能与 API 更改会影响常规对应部分，但有些不那么直观的后果需要留意：

⁃ 改进用户报错时，可能影响 **故障排查（Troubleshooting）** 页面。
⁃ 新增功能可能扩充 **技巧与绕过方法（Tips and workarounds）** 页面，以及“隐式约定”页面。
⁃ 部分实验性功能如需记录，可以在后续补充到专门的 **API** 页面。
⁃ 路线图中的 "**计划中的特性（Planned features）**" 页面需要同步更新。
⁃ 还有诸如 **致谢（Credits）**、**核心概念（Key Concepts）** 等其它页面。如果 API 用到了新的 Julia 语言特性或新语法，也应考虑更新 **Julia 入门** 页面。
⁃ 增加的新示例建议以 doctest 的形式补充。

### 预览文档

你可以通过如下链接预览与本 PR 相关的生成文档（假设能成功构建，通过 #128 举例）：[https://virtualplantlab.github.io/PlantSimEngine.jl/previews/PR128/](https://virtualplantlab.github.io/PlantSimEngine.jl/previews/PR128/)

## PR 提交前检查清单

⁃ 确认你的代码能正常运行  
⁃ 确保重要更改有测试覆盖，并为新增特性撰写了文档  
⁃ 在本地运行 PlantSimEngine 测试集，检查是否有报错  
⁃ 在 Github 上检查受影响的 issue，更新或评论相关 issue，或将其关联到 Pull Request  
⁃ 检查文档受影响的页面（roadmap 等，详见上文），并同步进行更新  
⁃ 构建 PSE 文档，并修复任何因更改导致失败的 doctest  
⁃ 提交你的更改，让 Github Actions 自动执行相关流程  
⁃ 查看 ‘CI’ GitHub Action 是否通过，出错请及时修复  
⁃ 检查下游测试和基准测试相关的 GitHub Actions：  
    - 如基准测试严重下降，请修正代码。在有需要时添加、更新或移除基准测试  
    - 如果集成测试/下游测试失败，请进一步排查原因  
    - 如果修改了 API，也需要检查下游包的文档影响  

完成上述检查后，一般就可以安全地提出合并请求了。

### 额外建议

⁃ 如果有新的已知问题或遗留 TODO，请将其写在 PR 评论或 issue 里，务必留下记录  
⁃ 最后，别忘了更新本页面和上述清单：如有新增文档页面，该页面也应加入需重点关注目录；如实现了内存分配追踪和类型稳定性检查功能，也请在此补充为发布前检查事项等。

### 其它补充建议

⁃ `/PlantSimEngine/test` 文件夹里包含了一些基础的辅助函数。其中有一个会输出模型列表、气象数据及输出变量向量，供部分测试作为测试库/矩阵，覆盖面较广。如果你编写了新模型、模型组合，或新增了气象数据，建议补充到测试库中。  
⁃ 新的下游包建议补充到集成和下游包注册表。  
⁃ 特殊的边界情况值得为其单独设置单元测试。新修复的 bug 也请尽量单独添加测试，即便修复本身很简单。

## 代码库值得注意的方面

### 自动模型生成

有一个特殊功能需要动态生成模型，以支持在多尺度模拟中向 `Status` 对象传递向量。未来还可能会有更多需要生成模型的功能。

当前的解决方案利用了 Julia 语言中较为脆弱的特性 `eval()`，此方法存在一些细节和坑点。你可以在[这里](https://arxiv.org/abs/2010.07516)或[这里](https://discourse.julialang.org/t/world-age-problem-explanation/9714/15)查看更多关于 world age 问题的讨论。

相关的实现文件为 `model_generation_from_status_vectors.jl`，其中有更多的注释说明。

需要特别留意的是，如果你调用了用 `eval()` 生成模型的函数，只有回到顶层作用域，这些更改才会对外可见。你可以参考 `tests/helper_functions.jl` 里的 `test_filtered_output_begin` 和 `test_filtered_output` 两个函数。前者会调用 `modellist_to_mapping`，该函数会临时生成一些模型，用于在 ModelList 和伪多尺度映射之间转换 status 向量。为了返回到全局作用域，将函数拆成了两段，这样 `eval()` 所做的更改才能在后续全局可用。后一个函数随后就可以使用这些生成的模型在新的映射上执行仿真并完成测试。

如果因为 `eval()` 出现相关问题，报错往往非常有指向性：比如报某个带有 UUID 后缀的临时模型在 Main 模块里找不到等。

也许有更好的方式可以避免这些问题，但目前采用的是该方案。调用该文件的函数时务必格外谨慎，注意是否有“函数被拆成两段”的注释。

### 天气/步长/状态组合

并非所有天气数据结构/天气数据量/状态向量大小的组合都在 PlantSimEngine 主体中被测试。一些更完整的组合被 PlantBioPhysics 和 XPalm 这两个包覆盖。未来建议逐步将这些测试结构纳入 PSE 测试集中，但在目前，调整 API 时强烈建议同时检查这两个下游包的测试情况。

### 测试库（test bank）

本页前面提到过测试库，但现有的测试库在天气数据、模型列表/映射及输出变量组合数量上仍有显著提升空间。

此外，关于内存分配追踪、类型稳定性等方面的测试，也值得进一步完善与记录。
