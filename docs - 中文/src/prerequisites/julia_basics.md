# Julia 入门指南

PlantSimEngine（以及其相关的包）是用 Julia 语言编写的。关于为何选择 Julia 的原因，这里有简要讨论：[为什么选择使用 Julia](@ref)。

Julia 是一门正在快速发展的编程语言，但在科研和数据科学领域还不是最广泛使用的。

如果你有 R、Python 或 Matlab 的编程背景，很多元素会让你感到熟悉，但 Julia 也有一些值得注意的差异。如果你是第一次接触这门语言，可能需要克服一些障碍，才能熟练使用它。

本页面着重列出与 PlantSimEngine 使用相关、最重要的 Julia 内容，并指向能够帮助你掌握这些基础知识的资源。

## 编程新手

本页面并非完整的 Julia 入门教程。如果你对编程完全不了解，建议先参考其它入门资源，例如 [这里](https://docs.julialang.org/en/v1/manual/getting-started/)。视频课程 [Julia Programming for Nervous Beginners（紧张新手的 Julia 编程）](https://www.youtube.com/playlist?list=PLP8iPy9hna6Qpx0MgGyElJ5qFlaIXYf1R) 也非常适合没有编程经验的人。

## 安装包与环境配置

关于 PlantSimEngine，你可以查阅我们文档中的相关页面:  
[PlantSimEngine 的安装与运行](@ref)

## 速查表（Cheatsheets）

你还可以在 [这里](https://palmstudio.github.io/Biophysics_database_palm/cheatsheets/) 找到一些速查表，以及一个[简短的入门笔记本](https://palmstudio.github.io/Biophysics_database_palm/basic_syntax/)和其[安装指南](https://palmstudio.github.io/Biophysics_database_palm/installation/)。

## 故障排查

我们有一个文档页面，列举了使用 PlantSimEngine 时常见的一些错误，若你遇到问题可以参考：[错误信息排查指南](@ref)。

如有更多关于 Julia 学习相关的问题，可以在 Discourse 论坛获得快速答复：[https://discourse.julialang.org](https://discourse.julialang.org)。

### 与其他语言的显著区别：

如果你希望将 Julia 与某一种特定语言比较，[显著区别部分](https://docs.julialang.org/en/v1/manual/noteworthy-differences/#Noteworthy-differences-from-Python) 可以为你提供简要概览。

（例如，Julia 的数组索引从 1 开始）

## 使用 PlantSimEngine 需掌握的 Julia 基本概念

以下是理解和高效使用 PlantSimEngine（除包管理之外）所需的 Julia 语言关键要点列表：

基本概念和构造：

- 变量、数组、函数、函数参数等基本概念
- 类型系统及自定义类型
- 字典（Dict）和 NamedTuple（具名元组）对象，这两者在代码中被广泛使用

与部分入门简介相比，Julia 官方手册对这些主题有更深入的解释，因此更适合作为参考工具，而不是初学入口。你也可以参考其他教程或课程，比如 [https://julia.quantecon.org/intro.html](https://julia.quantecon.org/intro.html) 的第一章、[Learn Julia the Hard Way](https://scls.gitbooks.io/ljthw/content/) 草稿的第 0-4,7 章，或交互式的 [Mathigon 课程](https://mathigon.org/course/programming-in-julia/introduction)。

还需关注的重要内容：

- 许多 API 函数使用了[关键字参数](https://docs.julialang.org/en/v1/manual/functions/#Keyword-Arguments)（kwargs）
- [类型提升（Type promotion）](https://docs.julialang.org/en/v1/manual/conversion-and-promotion/#Promotion)、[参数展开（splatting）](https://docs.julialang.org/en/v1/base/base/#...)、[广播（broadcasting）](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized)、以及[推导式（comprehensions）](https://docs.julialang.org/en/v1/manual/arrays/#man-comprehensions) 也是很有用的语法（但不是上手必需）

上述知识点在 [Julia Data Science 指南](https://juliadatascience.io/julia_basics) 中也有简要介绍，该资源同时关注 DataFrames.jl 的使用。

在使用 Julia 包时，进一步了解方法（methods）、参数化类型与类型系统也是十分值得的。