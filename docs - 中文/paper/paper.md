---
title: "PlantSimEngine：一个用于土壤-植物-大气系统的仿真引擎"
tags:
  - Julia
  - 农学
  - 作物
  - FSPM
  - 功能-结构植物建模
  - 植物
  - 建模
authors:
  - name: Rémi Vezy
    orcid: 0000-0002-0808-1461
    affiliation: "1, 2" # (Multiple affiliations must be quoted)
affiliations:
 - name: CIRAD, UMR AMAP, F-34398 Montpellier, France.
   index: 1
 - name: AMAP, Univ Montpellier, CIRAD, CNRS, INRAE, IRD, Montpellier, France.
   index: 2
date: 02 May 2023
bibliography: paper.bib
---

# 摘要

`PlantSimEngine` 提供了一个用于模拟和建模植物-土壤-大气系统的高层次建模接口，重点关注易用性与计算效率。该工具旨在帮助研究人员和实际工作者在无需深入了解复杂计算机技术细节的情况下，跨多尺度便捷地原型设计、实现和评估植物或作物模型。本包为过程声明和关联模型的实现建立了统一的框架，主要功能包括但不限于：

- 轻松定义新过程，例如光截获、光合作用、生长、土壤水分传输等；
- 快速、交互式地原型设计模型，借助约束防止出错，同时采用合理的默认值，避免加重模型开发负担；
- 自动管理输入输出变量、时间步、对象及通过依赖图耦合的模型；
- 无需修改任何代码即可方便切换不同模型，只需通过简单语法为每个过程指定所用模型；
- 通过固定变量、传递观测值，或为特定过程使用更简单的模型来减少自由度；
- 高速计算性能：一个模型、两个耦合模型的模拟仅需百分之一纳秒，或在 [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl) [@vezy_vezyplantbiophysicsjl_2023) 中实现完整叶片能量平衡（详见[基准测试脚本](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/benchmark.jl)）；
- 支持即开即用的顺序、并行（多线程）和分布式（多进程）对象、时间步及独立过程运算（得益于 [Floops.jl](https://juliafolds.github.io/FLoops.jl/stable/)）；
- 易于扩展，支持对对象、时间步、甚至 [Multi-Scale Tree Graphs](https://github.com/VEZY/MultiScaleTreeGraph.jl) [@vezy_multiscaletreegraphjl_2023] 的计算；
- 良好的可组合性，支持各种类型的输入，例如用于单位传播的 [Unitful](https://github.com/PainterQubits/Unitful.jl) ，或用于误差传播的 [MonteCarloMeasurements.jl](https://github.com/baggepinnen/MonteCarloMeasurements.jl) [@carlson_montecarlomeasurementsjl_2020]。

# 需求说明

在科学领域，对强大高效的植物-土壤-大气系统仿真建模工具的需求日益增长。此类模型往往由农学家、植物或土壤科学家开发，而他们通常不熟悉如计算性能、并行化、时间步和对象管理等计算机科学细节。

为了便于快速原型开发，模型常采用解释型语言实现，但这类语言运行缓慢；而为追求高性能，部分模型则以编译型语言开发，却导致原型开发周期变长。此外，模型开发本质上是一个迭代且耗时的过程，需要反复假设检验、多版本模型切换比较，并辅以单元测试和集成测试保证实现与集成的正确性。

整个流程繁琐易错，耗时耗力。因此，科研和生产领域亟需一种工具，支持便捷无障碍地原型设计、实现及评估各尺度的植物或作物模型，同时免去技术细节负担。

PlantSimEngine 正是为此需求而生，通过为过程声明和模型实现提供灵活且易用的仿真框架。该包着重解决模型仿真中的关键问题，包括新过程的易于定义、模型的快速交互原型开发、输入输出变量流的自动管理和无需更改底层代码即可灵活切换不同模型。此外，本包支持将模型强制拟合观测数据以减少模型自由度，以及高速计算、优良的可扩展性和良好的可组装性，非常适用于功能-结构植物模型（FSPM）与作物模型的开发。例如，在M1 MacBook Pro 14上以每日时间步模拟一年叶面积玩具模型仅需260微秒（即每日日历步688纳秒），与基于比尔-朗伯定律实现的光截获模型耦合后仅需275微秒（即每日756纳秒）（详见[基准测试脚本](https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/examples/benchmark.jl)），显示出 PlantSimEngine 在多模型下的卓越扩展性。该性能与用如 Fortran 或 C 这类编译型语言开发的包相当，远超任何解释型语言实现。

PlantSimEngine 各项创新特性的设计初衷，是让用户能够精准地建模、预测与分析复杂过程行为，从而提升决策能力并优化过程设计。

# 领域现状

PlantSimEngine 是一款先进的植物模拟软件，相较于现有的工具如 OpenAlea [@pradal_openalea_2008]、STICS [@brisson_stics_1998]、APSIM [@brown_plant_2014; @holzworth_apsim_2014] 及 DSSAT [@jones_dssat_2003]，在功能和设计模式上具有显著优势或创新。

PlantSimEngine 采用 Julia 编程语言，相较于传统的编译型语言（如 STICS、APSIM、DSSAT），可更快速、便捷地进行模型原型开发，同时其运行性能远超常见解释型语言（例如 OpenAlea 中使用的 Python），且无需将原型代码重写为编译型语言。例如，基于 PlantSimEngine.jl 实现生态生理模型的 Julia 包 PlantBiophysics.jl，其性能[比 R 语言中 plantecophys 包的同模型实现快 38649 倍](https://vezy.github.io/PlantBiophysics-paper/notebooks_performance_Fig5_PlantBiophysics_performance/) [@duursma_plantecophys_2015]。

本软件诸多令人瞩目的特性主要得益于 Julia 语言。Julia 是一种高级、高性能且动态的编程语言，在众多科学领域，尤其是生物学领域得到了广泛应用 [@roesch_julia_2023]。Julia 社区近年来推出了许多优秀工具，例如 Cropbox.jl [@yun_cropbox_2022] 和 CliMA Land [@wang_testing_2021]。

Cropbox.jl 是一个声明式作物建模框架，其目标和 PlantSimEngine 类似，旨在通过屏蔽底层模拟细节，简化模型定义流程。二者在 land surface models (LSM)、作物模型、功能-结构植物模型（FSPM）等多尺度应用场景均可胜任，但实现策略上有所不同。

Cropbox.jl 通过自定义面向作物建模的领域特定语言（DSL），为模型定义提供了直观方式。而 PlantSimEngine 则将高效为核心，确保从一开始便能实现高性能计算和良好扩展性。这一目标通过诸如类型稳定性、预分配内存等技术措施实现。类型稳定性确保在计算过程中变量始终保持一致类型，从而大幅提升执行效率。此外，PlantSimEngine 与 MultiScaleTreeGraph.jl [@vezy_multiscaletreegraphjl_2023] 的良好兼容性进一步增强了其可扩展性，便于开展多尺度计算。MultiScaleTreeGraph.jl 可高效表达和分析层级结构，为 PlantSimEngine 无缝处理跨多尺度复杂系统提供了强大支持。

CliMA Land 是新一代的大尺度土壤-植物-大气连续体（Soil-Plant-Atmosphere Continuum, SPAC）陆面模型。PlantSimEngine 中一项值得 CliMA Land 借鉴的亮点，是模型耦合的易用性，包括硬耦合与软耦合模型的概念，以及依赖关系图的自动推导与计算。

PlantSimEngine 具备模型依赖关系图的自动推算及统一的 API，用户可在无需更改底层代码的情况下切换不同模型。这对于复杂土壤-植物-大气模型开发者而言，是相较于 CliMA Land 及其他工具的巨大优势。此前 OpenAlea 实现了针对软依赖（即通过输入/输出变量耦合的独立模型）依赖图的组件化管理，接近 PlantSimEngine 的依赖管理思路，但缺乏对硬依赖支持——即模型之间通过显式代码直接调用。PlantSimEngine 利用 Julia 的多重派发机制，在编译时即可自动推导出完整依赖图，包括硬依赖。此外，PlantSimEngine 还提供简洁、通用的 API，用于定义模型及子模型的校准方法，实现自动化模型校准。

除此之外，PlantSimEngine 支持通过固定变量、传递观测值或为特定过程使用更简化模型，以减少自由度，使植物模拟更加灵活、易用。

PlantSimEngine 的工作方式自动管理模型耦合、时间步、并行优化、输入输出变量，以及仿真对象的类型（向量、字典、多尺度树图等），极大地简化了模型开发流程。

# 应用实例

PlantSimEngine 已被以下软件包采用：

- [PlantBiophysics.jl](https://github.com/VEZY/PlantBiophysics.jl)：用于植物的生物物理过程模拟，如光合作用、热量、水汽及 CO₂ 的传导，潜热与显热通量、净辐射及温度等

- [XPalm.jl](https://github.com/PalmStudio/XPalm.jl)：油棕实验性作物模型

# 参考文献
