# PlantSimEngine 的安装与运行

```@contents
Pages = ["installing_plantsimengine.md"]
Depth = 3
```

本页旨在帮助不太熟悉 Julia 的新手用户。如果你已经很了解 Julia，安装 PlantSimEngine 将会非常简单，你可以[直接跳到下一节](#step_by_step)，或者阅读 PlantSimEngine 的[关键概念](@ref)。

## 安装 Julia

Julia 的直接下载链接在[这里](https://julialang.org/downloads/)，更多安装说明可参见[官方手册](https://docs.julialang.org/en/v1/manual/installation/)。

## 安装 VSCode

你可以直接使用 REPL（命令行），但如果打算编写较为复杂的软件，推荐使用 IDE。PlantSimEngine 的开发推荐使用 VSCode，你可以按照[本页面的指引](https://code.visualstudio.com/docs/setup/setup-overview)安装 VSCode。关于在 VSCode 中使用 Julia 的说明可参见[这里](https://code.visualstudio.com/docs/languages/julia)。

## 安装 PlantSimEngine 及其依赖项

### Julia 环境

Julia 的包管理依赖于 Pkg.jl。你可以在[官方文档](https://pkgdocs.julialang.org/v1/)中详细了解其使用方法及 Julia 环境的管理。

如果本页内容对你来说尚不够详细，[本教程](https://jkrumbiegel.com/pages/2022-08-26-pkg-introduction/)会更深入地介绍 Julia 环境的使用细节。

### 运行 Julia 环境

当你的环境设置完成后，可以打开命令行并输入 `julia`。这将启动 Julia，你将在命令行看到 `julia>` 的提示符。

从这个提示符下，你可以输入 `?` 进入帮助模式，然后输入你想了解的函数或语言特性名称来获取相关帮助信息。

你也可以在 Julia 会话中通过输入 `pwd()` 查看你当前所在的目录。

在 Julia 中，环境和依赖的管理由名为 Pkg 的包负责，它自带于 Julia 的基础安装。你可以像使用其他包一样调用 Pkg 的功能，或通过输入 `]` 进入 Pkg 模式。此时，提示符会从 `julia>` 变为类似 `(@v1.11)` pkg>，表示你当前所处的环境（比如默认的 julia 环境，我们不建议将其过度膨胀）。

在 Pkg 模式下，你可以通过输入 `activate 路径/到/环境` 来选择或创建一个环境。

随后，可通过输入 `add 包名` 来添加已注册在 Julia 全局仓库中的包，输入 `remove 包名` 来删除包。输入 `status` 或 `st` 可以显示当前环境下已安装的包。需要更新某些包时（其名称旁会出现 `^` 符号），可以输入 `update` 或 `up` 进行更新。

如果你在本地编辑/开发一个包，或者直接使用本地包，可以输入 `develop 路径/到/包源码/` （或简写为 `dev 路径/到/包/源码`），这样环境将使用该本地版本，而不是注册表中的版本。

输入 `instantiate` 会根据环境的 manifest 文件（如果有）自动下载所有声明的依赖包。

举例来说，PlantSimEngine 在开发时有一个 test 文件夹用于测试。如果要运行测试，你需要依次输入 `]` 进入 Pkg 模式，再输入 `activate ../path/to/PlantSimEngine/test` 激活测试环境，之后再输入 `instantiate` 来安装依赖包，这样就可以运行测试脚本了。

因此，要使用 PlantSimEngine，可以进入 Pkg 模式（`]`），选择一个环境文件夹，并通过 `activate ../path/to/your_environment` 激活该环境，再用 `add PlantSimEngine` 添加 PlantSimEngine，最后用 `instantiate` 下载相关依赖。

### 伴随包

在大部分示例中，你还需安装 `PlantMeteo`。对于部分多尺度模拟，还需安装 `MultiScaleTreeGraph`。

一些气象数据的示例会用到 `CSV` 包，一些输出数据的处理则会用到 `DataFrames` 包。

### 使用示例模型

示例模型被作为 PlantSimEngine 的一个子模块导出，不属于主 API。可以通过以下代码引用：

```julia
using PlantSimEngine.Examples
```

## 运行测试仿真

假设你已经配置好了环境，并正确地将 `PlantMeteo` 与 `PlantSimEngine` 添加进该环境，并通过 `instantiate` 下载好了全部依赖包。你就可以在 REPL 中逐行输入以下代码进行测试：

```@example mypkg
using PlantSimEngine, PlantMeteo
using PlantSimEngine.Examples
meteo = Atmosphere(T = 20.0, Wind = 1.0, Rh = 0.65, Ri_PAR_f = 500.0)
leaf = ModelList(Beer(0.5), status = (LAI = 2.0,))
out_sim = run!(leaf, meteo)
```

## 在 VSCode 中使用环境

有详细文档介绍如何在 VSCode 中结合 Julia 的环境使用，其中包括了如何在 VSCode 管理环境的说明：[https://www.julia-vscode.org/docs/stable/userguide/env/](https://www.julia-vscode.org/docs/stable/userguide/env/)