```@meta
CurrentModule = PlantSimEngine
```

```@setup readme
using PlantSimEngine, PlantMeteo, DataFrames, CSV

# 导入 `Examples` 子模块中定义的示例:
using PlantSimEngine.Examples

# 导入示例气象数据：
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 定义模型：
model = ModelList(
    ToyLAIModel(),
    status=(TT_cu=1.0:2000.0,), # 将累积的有效积温作为输入传递给模型
)

out = run!(model)

# 定义用于耦合的模型列表：
model2 = ModelList(
    ToyLAIModel(),
    Beer(0.6),
    status=(TT_cu=cumsum(meteo_day[:, :TT]),),  # 将累积有效积温作为输入传递给 `ToyLAIModel`，这也可以通过其他模型来实现
)
out2 = run!(model2, meteo_day)

```

# PlantSimEngine

[![构建状态](https://github.com/VirtualPlantLab/PlantSimEngine.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/VirtualPlantLab/PlantSimEngine.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![覆盖率](https://codecov.io/gh/VirtualPlantLab/PlantSimEngine.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/VirtualPlantLab/PlantSimEngine.jl)
[![ColPrac: 社区包协作实践贡献者指南](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![Aqua 质量保证](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![DOI](https://zenodo.org/badge/571659510.svg)](https://zenodo.org/badge/latestdoi/571659510)
[![JOSS](https://joss.theoj.org/papers/137e3e6c2ddc349bec39e06bb04e4e09/status.svg)](https://joss.theoj.org/papers/137e3e6c2ddc349bec39e06bb04e4e09)

```@contents
Pages = ["index.md"]
Depth = 5
```

## 概述

`PlantSimEngine` 是一个专为构建土壤-植株-大气连续体模型而设计的综合性框架。它为在任何尺度上**原型设计、评估、测试和部署**植物/作物模型提供了所需的一切，极大地强调了性能和效率，让您能专注于模型的构建与完善。

**为什么选择 PlantSimEngine？**

- **简单性**：极大减少代码量，专注于模型逻辑，其余交给框架自动处理。
- **模块化**：每个模型组件都可独立开发、测试与改进。可通过复用高质量的预构建模块，灵活组装复杂仿真。
- **标准化**：具有清晰且可执行的规范，保证所有模型都遵循最佳实践。如此一来，模型可在整个生态系统内无缝协作。
- **性能优化**：无需重复造轮子。低层的繁琐任务全部交由 PlantSimEngine 负责，您的模型能享受到底层框架的每一次优化和性能提升。以 Julia 的高性能保证高效的原型迭代与模型运行。

## 独特特性

### 自动耦合模型

**无缝集成**：PlantSimEngine 充分利用 Julia 多重分派的强大能力，能够自动计算模型间的依赖图，研究人员无需编写复杂的连接代码或手动处理依赖关系，即可便捷实现模型耦合。

**直观的多尺度支持**：框架能够自然支持不同空间尺度（从细胞器到生态系统）的模型间耦合，仅需极小的工作量，即可维护不同尺度间的状态一致性。

### 灵活且精细可控

**轻松切换模型组件**：通过简洁直观的语法，用户可在不更改模型底层代码的情况下切换不同的组件，实现不同假设与模型版本之间的快速对比，极大加速科学发现过程。

## 集成“电池”——开箱即用的功能

- **自动化管理**：自动处理输入、输出、时间步长、对象及依赖关系。
- **迭代开发**：拥有内建约束，避免错误，同时具备合理默认值，加快模型的交互式原型设计。
- **自由度管理**：可固定变量为常数或观测值，也可针对具体过程采用简化模型以降低整体复杂度。
- **高速计算**：已在复杂模型中实现了百纳秒级的性能表现（见此[基准测试脚本](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/benchmark.jl)）。
- **并行与分布式计算**：借助 [Floops.jl](https://juliafolds.github.io/FLoops.jl/stable/)，对象、时间步或独立过程均可自动支持串行、多线程或分布式计算。
- **无缝扩展**：支持对象、时间步和 [多尺度树结构](https://github.com/VEZY/MultiScaleTreeGraph.jl)的高效计算方法。
- **自由组合**：输入可以是任意类型，包括 [Unitful](https://github.com/PainterQubits/Unitful.jl) 用于单位传播，以及 [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) 用于测量误差传播。

## 性能表现

PlantSimEngine 在植物建模任务中展现了令人瞩目的性能表现。例如在一台 M1 MacBook Pro 上：

- 一个叶面积指数（LAI）玩具模型，以逐日时间步模拟全年，仅耗时 260 微秒（约为每一天 688 纳秒）
- 同一个模型与光截获模型耦合后，所需时间为 275 微秒（每一天约为 756 纳秒）

这些基准测试表明，其性能已媲美 Fortran 或 C 等编译型语言，远超多数解释型语言的典型实现。例如，基于 PlantSimEngine 实现生态生理学模型的 PlantBiophysics.jl，被测得运行速度可比其它科学计算语言中的等价实现快 38,000 倍。

## 问题反馈

如果有任何疑问或建议，欢迎[提交 issue](https://github.com/VirtualPlantLab/PlantSimEngine.jl/issues)或在 [discourse 讨论区](https://fspm.discourse.group/c/software/virtual-plant-lab)咨询。

## 安装方法

要安装本包，请在 Julia REPL 中按下 `]` 进入包管理模式，然后输入下列命令：

```julia
add PlantSimEngine
```

要使用本包，只需在 Julia REPL 输入下列命令：

```julia
using PlantSimEngine
```

## 使用示例

本包设计为易于上手，并帮助用户在实现、耦合和模拟模型过程中减少出错。

### 简单示例

以下是一个简单的模型示例，模拟了植物的生长过程，采用了指数生长模型：

```@example readme
# ] add PlantSimEngine
using PlantSimEngine

# 导入 `Examples` 子模块中定义的示例
using PlantSimEngine.Examples

# 定义模型：
model = ModelList(
    ToyLAIModel(),
    status=(TT_cu=1.0:2000.0,), # 以积温作为模型输入
)

out = run!(model) # 运行模型并获取输出
```

> **注意**  
> `ToyLAIModel` 可以在[示例文件夹](https://github.com/VirtualPlantLab/PlantSimEngine.jl/tree/main/examples)中找到，是一个简单的指数生长模型。这里只作为演示使用，实际上你可以使用任意符合 PlantSimEngine 接口的模型。

当然，你也可以很方便地绘制输出结果：

```@example readme
# ] add CairoMakie
using CairoMakie

lines(out[:TT_cu], out[:LAI], color=:green, axis=(ylabel="LAI (m² m⁻²)", xlabel="Cumulated growing degree days since sowing (°C)"))
```

### 模型耦合

模型的耦合由本包自动完成，基于各模型之间的依赖图实现。要耦合多个模型，只需将它们添加到 `ModelList` 中即可。例如，下面将 `ToyLAIModel` 与基于比尔定律（Beer's law）的光截获模型进行耦合：

```@example readme
# ] add PlantSimEngine, DataFrames, CSV
using PlantSimEngine, PlantMeteo, DataFrames, CSV

# 导入 `Examples` 子模块中定义的示例
using PlantSimEngine.Examples

# 导入示例气象数据：
meteo_day = CSV.read(joinpath(pkgdir(PlantSimEngine), "examples/meteo_day.csv"), DataFrame, header=18)

# 定义用于耦合的模型列表：
model2 = ModelList(
    ToyLAIModel(),
    Beer(0.6),
    status=(TT_cu=cumsum(meteo_day[:, :TT]),),  # 将累计生长积温作为 ToyLAIModel 的输入，也可以通过其他模型完成
)

# 运行模拟：
out2 = run!(model2, meteo_day)
```

`ModelList` 会通过自动计算模型之间的依赖图来实现模型的耦合。最终的依赖图如下所示：

```
╭──── Dependency graph ──────────────────────────────────────────╮
│  ╭──── LAI_Dynamic ─────────────────────────────────────────╮  │
│  │  ╭──── Main model ────────╮                              │  │
│  │  │  Process: LAI_Dynamic  │                              │  │
│  │  │  Model: ToyLAIModel    │                              │  │
│  │  │  Dep: nothing          │                              │  │
│  │  ╰────────────────────────╯                              │  │
│  │                  │  ╭──── Soft-coupled model ─────────╮  │  │
│  │                  │  │  Process: light_interception    │  │  │
│  │                  └──│  Model: Beer                    │  │  │
│  │                     │  Dep: (LAI_Dynamic = (:LAI,),)  │  │  │
│  │                     ╰─────────────────────────────────╯  │  │
│  ╰──────────────────────────────────────────────────────────╯  │
╰────────────────────────────────────────────────────────────────╯
```

我们可以通过变量名索引输出结果来绘制模拟结果（如 `out2[:LAI]`）：

```@example readme
using CairoMakie

fig = Figure(resolution=(800, 600))
ax = Axis(fig[1, 1], ylabel="LAI (m² m⁻²)")
lines!(ax, out2[:TT_cu], out2[:LAI], color=:mediumseagreen)

ax2 = Axis(fig[2, 1], xlabel="Cumulated growing degree days since sowing (°C)", ylabel="aPPFD (mol m⁻² d⁻¹)")
lines!(ax2, out2[:TT_cu], out2[:aPPFD], color=:firebrick1)

fig
```

### 多尺度的建模

> 更多细节请参见[多尺度建模](#multi-scale-modeling)章节。

本包设计高度可扩展，可方便地对不同尺度下的模型进行模拟。例如，可以在叶片尺度模拟模型，再与其他尺度（如节间、植株、土壤、场景等）下的模型进行耦合。下面这个例子展示了一个使用不同尺度下子模型来模拟植物生长的简单模型：

```@example readme
mapping = Dict(
    "Scene" => ToyDegreeDaysCumulModel(),
    "Plant" => (
        MultiScaleModel(
            model=ToyLAIModel(),
            mapped_variables=[
                :TT_cu => "Scene",
            ],
        ),
        Beer(0.6),
        MultiScaleModel(
            model=ToyAssimModel(),
            mapped_variables=[:soil_water_content => "Soil"],
        ),
        MultiScaleModel(
            model=ToyCAllocationModel(),
            mapped_variables=[
                :carbon_demand => ["Leaf", "Internode"],
                :carbon_allocation => ["Leaf", "Internode"]
            ],
        ),
        MultiScaleModel(
            model=ToyPlantRmModel(),
            mapped_variables=[:Rm_organs => ["Leaf" => :Rm, "Internode" => :Rm],],
        ),
    ),
    "Internode" => (
        MultiScaleModel(
            model=ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            mapped_variables=[:TT => "Scene",],
        ),
        MultiScaleModel(
            model=ToyInternodeEmergence(TT_emergence=20.0),
            mapped_variables=[:TT_cu => "Scene"],
        ),
        ToyMaintenanceRespirationModel(1.5, 0.06, 25.0, 0.6, 0.004),
        Status(carbon_biomass=1.0)
    ),
    "Leaf" => (
        MultiScaleModel(
            model=ToyCDemandModel(optimal_biomass=10.0, development_duration=200.0),
            mapped_variables=[:TT => "Scene",],
        ),
        ToyMaintenanceRespirationModel(2.1, 0.06, 25.0, 1.0, 0.025),
        Status(carbon_biomass=1.0)
    ),
    "Soil" => (
        ToySoilWaterModel(),
    ),
);
nothing # hide
```

我们可以从包中导入一个示例植物：

```@example readme
mtg = import_mtg_example()
```

创建一个虚拟气象数据：

```@example readme
meteo = Weather(
    [
    Atmosphere(T=20.0, Wind=1.0, Rh=0.65, Ri_PAR_f=300.0),
    Atmosphere(T=25.0, Wind=0.5, Rh=0.8, Ri_PAR_f=500.0)
]
);
nothing # hide
```

然后运行模拟：

```@example readme
out_vars = Dict(
    "Scene" => (:TT_cu,),
    "Plant" => (:carbon_allocation, :carbon_assimilation, :soil_water_content, :aPPFD, :TT_cu, :LAI),
    "Leaf" => (:carbon_demand, :carbon_allocation),
    "Internode" => (:carbon_demand, :carbon_allocation),
    "Soil" => (:soil_water_content,),
)

out = run!(mtg, mapping, meteo, tracked_outputs=out_vars, executor=SequentialEx());
nothing # hide
```

然后我们可以提取输出，并针对每个层级将其转换为 `DataFrame` 并进行排序：

```@example readme
using DataFrames
df_dict = convert_outputs(out, DataFrame)
sort!(df_dict["Leaf"], [:timestep, :node])
```

多尺度模拟的一个示例输出可以在 PlantBiophysics.jl 的文档中看到：

![植物生长模拟](www/image.png)

## 领域现状

PlantSimEngine 是最前沿的植物模拟软件，相比 OpenAlea、STICS、APSIM 或 DSSAT 等已有工具具备显著优势。

PlantSimEngine 基于 Julia 编程语言，带来了如下好处：

- 与编译型语言相比，原型开发更加快速、便捷
- 性能显著优于典型的解释型语言
- 无需将模型转换到其他编译型语言

Julia 的特性赋予 PlantSimEngine 以下能力：

- 多重分派，自动计算模型依赖图
- 类型稳定性，优化运行性能
- 与 MultiScaleTreeGraph.jl 等强大工具无缝兼容，支持多尺度计算

PlantSimEngine 的实现大大简化了模型开发流程，可以自动管理：

- 通过自动依赖图计算实现模型耦合
- 时间步长与并行化
- 输入与输出变量
- 支持多种用于模拟的对象类型（如向量、字典、多尺度树图等）

## 使用 PlantSimEngine 的项目

以下项目已经应用了 PlantSimEngine：

- [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl)
- [XPalm](https://github.com/PalmStudio/XPalm.jl)

## 让它成为你的工具

本包的开发旨在让任何人都能轻松地实现植物/作物建模，并可凭借 MIT 许可证免费自由地使用。

如果你开发了相关工具但尚未在此列表中，请提交 PR 或与我联系，我们会很高兴地添加你的项目！😃
