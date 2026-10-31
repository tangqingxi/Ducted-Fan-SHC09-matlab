# 仓库地图

`ca_setup` 只加入显式运行目录和注册插件，不使用全树 genpath。本地 archive/results 的副本不等于当前依赖。

```text
configs/comparison/         比较工况的选择元数据，不改物理/控制预设
apps/                       活跃用户入口，含标准分配比较、估计反馈比较 MVP 与 E3
platform/                   活跃总线、调度、模块、仿真和日志
allocators/ effectiveness/  活跃分配插件和名义效能
models/ drivers/ lib/ configs/ 活跃模型、执行器、数学和参数
modules/ compat/            兼容桥接/旧 API，部分仍为运行依赖
analysis/ experiments/      活跃分析与研究入口，逐文件保留兼容性
main_*.m plot_main_*.m      对外兼容入口，不能按“未引用”删除
tests/ platform/tests/      测试、冻结基线和参考
examples/ docs/             版本化示例、文档及结论证据
examples/e3_estimated_mismatch/ E3 轻量 CSV、Pareto 与时域图
examples/allocation_comparison/ M4扫描与完整三种子CSV/报告
docs/release_validation/   发布前回归证据
docs/evidence/stage6a/      四个一次性实现，原入口包装按需调用
tools/ third_party/         工程工具与上游归档依赖
archive/ results/ build/ .tmp_matlab/ 本地历史/生成物，忽略、不进 Git
```

| 我想找什么 | 去哪里 | 状态 |
|---|---|---|
| 标准多种子分配比较 | [比较指南](allocation_comparison_guide.md) | 活跃，先过门禁再读效应量 |
| 一次比较估计反馈五方法 | [MVP 入口说明](estimated_allocation_comparison.md) | 活跃 |
| 估计反馈结构失配 | [E3 设计与结果](e3_estimated_structural_mismatch.md) | 活跃研究入口 |
| 控制链/消息定义 | [模块说明](../platform/modules/README.md) | 活跃职责文档 |
| 分配算法 | [插件目录](../allocators/README.md) | 活跃，不改算法 |
| 物理/效能 | models/shc09、effectiveness | 活跃；参考/fixtures 冻结 |
| 偏置诊断依据 | [Stage6A 报告](estimator_diagnosis_report.md) | 历史证据，非当前依赖 |
| 所有 tracked 文件决策 | [file_inventory.csv](file_inventory.csv) | 本轮快照 |
| 同名函数/调用者 | [冲突清单](function_collisions.json)、[引用清单](matlab_references.json) | 文本静态分析 |
| 本地几千个 MATLAB 副本 | [生成目录统计](local_generated_inventory.csv) | 本地历史/生成，不是全都活跃 |

modules/compat/analysis 并非“全是废弃文件”：ECL 桥接、兼容函数与 MVP 指标行计算仍会被调用。没有文本引用也可能是动态注册、测试选择器或外部用户调用；孤儿仅列为待审 archive 候选。

[Stage6A 实现移动清单](evidence/stage6a_manifest.json) · [tracked 分类统计](file_category_summary.csv) · [本地重复内容](local_matlab_duplicates.csv)。旧 reports/validation/migration manifest 均为历史证据，不是 ca_setup 的运行依赖；新的活跃 MVP 指标行函数保留在 analysis。
