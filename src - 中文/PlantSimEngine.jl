module PlantSimEngine

# 用于数据格式化:
import DataFrames
import Tables
import DataAPI

import CSV # 用于通过 variables() 读取 csv 文件

# 用于依赖图结构:
import AbstractTrees
import Term
import Markdown

# 用于多线程并行计算:
import FLoops: @floop, @init, ThreadedEx, SequentialEx, DistributedEx

# 用于兼容 MTG（多尺度树图）:
import MultiScaleTreeGraph
import MultiScaleTreeGraph: symbol, node_id

# 用于计算平均值:
import Statistics

# 在通过状态向量生成模型时避免命名冲突
import SHA: sha1

using PlantMeteo

# 非初始化变量 + PreviousTimeStep（上一时刻变量）:
include("variables_wrappers.jl")

# 文档模板:
include("doc_templates/mtg-related.jl")

# 模型结构体:
include("Abstract_model_structs.jl")

# 仿真行（状态）:
include("component_models/Status.jl")
include("component_models/RefVector.jl")

# 仿真表（时步表，来自 PlantMeteo）:
include("component_models/TimeStepTable.jl")

# 声明依赖图:
include("dependencies/dependency_graph.jl")

# 模型列表:
include("component_models/ModelList.jl")
include("mtg/MultiScaleModel.jl")

# 状态的 getter/setter 方法:
include("component_models/get_status.jl")

# 转换为 DataFrame（数据表）:
include("dataframe.jl")

# 计算模型依赖关系:
include("dependencies/soft_dependencies.jl")
include("dependencies/hard_dependencies.jl")
include("dependencies/traversal.jl")
include("dependencies/is_graph_cyclic.jl")
include("dependencies/printing.jl")
include("dependencies/dependencies.jl")
include("dependencies/get_model_in_dependency_graph.jl")

# MTG 兼容性相关:
include("mtg/GraphSimulation.jl")
include("mtg/mapping/getters.jl")
include("mtg/mapping/mapping.jl")
include("mtg/mapping/compute_mapping.jl")
include("mtg/mapping/reverse_mapping.jl")
include("mtg/initialisation.jl")
include("mtg/save_results.jl")
include("mtg/add_organ.jl")

# 模型评估 (统计量):
include("evaluation/statistics.jl")

# 特征（Traits）
include("traits/table_traits.jl")
include("traits/parallel_traits.jl")

# 过程相关:
include("processes/model_initialisation.jl")
include("processes/models_inputs_outputs.jl")
include("processes/process_generation.jl")
include("checks/dimensions.jl")

# 仿真主入口:
include("run.jl")

# 拟合函数
include("evaluation/fit.jl")

# 初始化映射工具函数
include("mtg/mapping/model_generation_from_status_vectors.jl")

# 示例
include("examples_import.jl")

export PreviousTimeStep
export AbstractModel
export ModelList, MultiScaleModel
export RMSE, NRMSE, EF, dr
export Status, TimeStepTable, status
export init_status!
export add_organ!
export @process, process
export to_initialize, is_initialized, init_variables, dep
export inputs, outputs, variables, convert_outputs
export run!
export fit

# 重导出 PlantMeteo 主要函数:
export Atmosphere, TimeStepTable, Constants, Weather

# 重导出 FLoops 执行器（多线程/分布式）:
export SequentialEx, ThreadedEx, DistributedEx
end
