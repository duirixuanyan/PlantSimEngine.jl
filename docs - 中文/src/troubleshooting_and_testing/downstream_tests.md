# 自动化测试：下游依赖检查

PlantSimEngine 是[在 Github 上开源](https://github.com/VirtualPlantLab/PlantSimEngine.jl)的，其它相关配套包也同样开源，如 [PlantGeom.jl](https://github.com/VEZY/PlantGeom.jl)、[PlantMeteo.jl](https://github.com/VEZY/PlantMeteo.jl)、[PlantBioPhysics.jl](https://github.com/VEZY/PlantBioPhysics.jl)、[MultiScaleTreeGraph.jl](https://github.com/VEZY/MultiScaleTreeGraph.jl) 和 [XPalm](https://github.com/PalmStudio/XPalm.jl)。

这些包都实现了很方便的 CI（持续集成）功能：自动化集成与下游测试。当某一个包发生更改时，系统会自动测试所有已知的下游依赖包，以确保没有引入破坏性的更改。

例如，PlantBioPhysics 依赖于 PlantSimEngine，因此集成测试会在 PlantSimEngine 发布新版本后，自动检测 PlantBioPhysics 的测试是否会意外失败。同时，下游测试中还包括基准性能测试，详情可见：[https://github.com/VirtualPlantLab/PlantSimEngine.jl/blob/main/test/downstream/test-plantbiophysics.jl]

如果您希望基于 PlantSimEngine 进行开发，也可以利用这一功能。只需告知我们您的包名（或在 Pull Request 中将其加入 CI 的 yml 文件），我们即可将其加入下游测试列表中，并在有破坏性更改时自动生成相关 PR 通知您。