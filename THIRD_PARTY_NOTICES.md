# 来源与许可说明

- `third_party/PX4-ECL`：PX4官方ECL，固定提交`46dd05a9159817035dab6acebc33f8a3da69d3a7`，[上游](https://github.com/PX4/PX4-ECL)。原BSD-3-Clause许可证保留于其LICENSE。
- `third_party/PX4-Matrix`：官方ECL所用Matrix依赖，固定提交`f981cea2aebfc9cfd930dce73ba6d4d6681e99c1`，[上游](https://github.com/PX4/PX4-Matrix)。原许可证保留于其LICENSE。
- `third_party/source_manifest.json`记录所迁移依赖文件的SHA256，构建前逐文件校验，依赖源码未修改；未携带上游嵌套Git仓库、CI与独立测试目录。
- `models/shc09/reference`及气动表来自ICGNC_matlab2.0参考工程，原源码保留，SHA及来源标识见`docs/physical_reference.json`。
- `tests/legacy_reference`保存旧control_allocation工程的最小独立闭环校对器；该代码仅在回归测试临时加入路径，不参与生产分配器。原有注释原样保留，新增代码注释为中文。
- `tests/fixtures`中的紧凑历史输入及`examples/mismatch_round2`从原工程记录提取，不是新增独立试验。

本次工程迁移未替维护者选择自有代码的开源许可证，也不将第三方许可证扩展到所有模型、数据或自有代码。自有代码及参考数据的公开许可由维护者确定。
