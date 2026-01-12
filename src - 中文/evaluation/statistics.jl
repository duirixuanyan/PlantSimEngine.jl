
"""
    RMSE(obs,sim)

返回观测值 `obs` 和模拟值 `sim` 之间的均方根误差（Root Mean Squared Error）。

值越接近0越好。

# 示例

```@example
using PlantSimEngine

obs = [1.0, 2.0, 3.0]
sim = [1.1, 2.1, 3.1]

RMSE(obs, sim)
```
"""
function RMSE(obs, sim)
    return sqrt(sum((obs .- sim) .^ 2) / length(obs))
end

"""
    NRMSE(obs,sim)

返回观测值 `obs` 和模拟值 `sim` 之间的归一化均方根误差（Normalized Root Mean Squared Error）。
归一化方法是除以观测值的范围（最大值-最小值）。

# 示例

```@example
using PlantSimEngine

obs = [1.0, 2.0, 3.0]
sim = [1.1, 2.1, 3.1]

NRMSE(obs, sim)
```
"""
function NRMSE(obs, sim)
    return sqrt(sum((obs .- sim) .^ 2) / length(obs)) / (findmax(obs)[1] - findmin(obs)[1])
end

"""
    EF(obs,sim)

使用NSE（Nash-Sutcliffe效率）模型，返回观测值 `obs` 和模拟值 `sim` 之间的效率系数（Efficiency Factor）。
更多信息见 https://en.wikipedia.org/wiki/Nash%E2%80%93Sutcliffe_model_efficiency_coefficient 。

值越接近1越好。

# 示例

```@example
using PlantSimEngine

obs = [1.0, 2.0, 3.0]
sim = [1.1, 2.1, 3.1]

EF(obs, sim)
```
"""
function EF(obs, sim)
    SSres = sum((obs - sim) .^ 2)
    SStot = sum((obs .- Statistics.mean(obs)) .^ 2)
    return 1 - SSres / SStot
end

"""
    dr(obs,sim)

返回Willmott提出的改进一致性指数dᵣ。
参考：Willmot et al. 2011. A refined index of model performance. https://rmets.onlinelibrary.wiley.com/doi/10.1002/joc.2419

值越接近1越好。

# 示例

```@example
using PlantSimEngine

obs = [1.0, 2.0, 3.0]
sim = [1.1, 2.1, 3.1]

dr(obs, sim)
```
"""
function dr(obs, sim)
    a = sum(abs.(obs .- sim))
    b = 2 * sum(abs.(obs .- Statistics.mean(obs)))
    return 0 + (1 - a / b) * (a <= b) + (b / a - 1) * (a > b)
end
