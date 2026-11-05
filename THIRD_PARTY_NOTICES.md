# 来源与许可说明

> 文档类型：参考。

- `third_party/PX4-ECL`：PX4官方ECL，固定提交`46dd05a9159817035dab6acebc33f8a3da69d3a7`，[上游](https://github.com/PX4/PX4-ECL)。原BSD-3-Clause许可证保留于其LICENSE。
- `third_party/PX4-Matrix`：官方ECL所用Matrix依赖，固定提交`f981cea2aebfc9cfd930dce73ba6d4d6681e99c1`，[上游](https://github.com/PX4/PX4-Matrix)。原许可证保留于其LICENSE。
- `third_party/source_manifest.json`记录所迁移依赖文件的SHA256，构建前逐文件校验，依赖源码未修改；未携带上游嵌套Git仓库、CI与独立测试目录。
- `models/shc09/reference`及气动表来自ICGNC_matlab2.0参考工程，原源码保留，SHA及来源标识见`docs/physical_reference.json`。
- `tests/legacy_reference`保存旧control_allocation工程的最小独立闭环校对器；该代码仅在回归测试临时加入路径，不参与生产分配器。原有注释原样保留，新增代码注释为中文。
- `tests/fixtures`中的紧凑历史输入及`examples/mismatch_round2`从原工程记录提取，不是新增独立试验。

本仓库自有代码及文档采用根目录的 [MIT 许可证](LICENSE)。第三方代码、参考模型、参考数据及其他来源资产保留各自的版权和许可声明；根目录 MIT 许可证不重新授予这些资产的权利。来源尚未明确公开许可的参考文件，不因新增本许可证而视为已获得 MIT 授权。WindTrace 的既有许可证和来源说明继续保留。
