# 仓库地图

> 文档类型：当前。

按“活跃代码 / 文档 / 历史 / 生成目录”找文件。ca_setup只加入显式源码路径和注册插件，不把整个仓库加进路径。

## 一、活跃代码与入口

```text
根目录/                    main、shc09_run、ca_setup、测试及可选ECL构建入口
apps/main_comparison.m     常用五方法比较入口
apps/*.m                   悬停、标准分配比较和其他现行应用入口
apps/experimental/         main_realistic、main_realistic_comparison
apps/legacy/               旧main_*研究入口与plot_main_*重绘入口
platform/                  总线、调度、模块、仿真和日志
models/                    SHC09物理、参数和不加入运行路径的参考数据
allocators/                五分配器与接口示例
configs/                   参数、预设、比较选择
analysis/ experiments/     离线分析与固定研究协议
modules/ compat/           仍被调用的桥接和兼容API
lib/ drivers/ effectiveness/ 数学、执行器与名义效能
third_party/               归档上游源码及许可，可选桥接构建仍需使用
```

本轮只移动17个对外入口，未移动或修改数值代码目录。旧函数名通过ca_setup仍能解析，main、mismatch_app等按名称调用保持兼容。没有文本引用不等于无动态调用，不按“孤儿”直接删文件。

## 二、文档与版本化说明

```text
docs/README.md             按读者任务导航
docs/repository_map.md     本地图
docs/guides/               当前架构、插件、比较、PX4日志指南
docs/guides/lite/          lite修复、峰值诊断、结果及阅读顺序
docs/reference/            物理与算法依据
examples/                  可分发轻量结果，按生成版本理解
tests/ platform/tests/     测试、冻结基线、夹具；不随文档整理改阈值
```

先读[文档导航](README.md)。常用：[比较指南](guides/allocation_comparison_guide.md)、[lite](guides/lite/README.md)、[PX4日志](guides/px4_log_map.md)、[架构](guides/architecture.md)。盘点CSV、JSON迁移快照留原路径以兼容既有工具，源文件清单见[file_inventory.csv](file_inventory.csv)。

## 三、历史与证据

```text
docs/history/              历史报告，保留原结论，不是当前依赖
docs/releases/             按版本保存发布说明
docs/evidence/             原一次性实现、包装与来源证据，本轮不移动
docs/*validation*/         按任务保留的验证CSV/JSON与记录
docs/estimator_diagnosis/  冻结诊断数据
archive/                   本机历史副本，不参与当前构建
archive/logs/              从根目录归档的运行日志
```

[历史索引](history/README.md)解释每份报告用途；[归档说明](../archive/README.md)与[日志索引](../archive/logs/README.md)按主题定位旧记录。archive只提交两个README索引，日志和历史副本仍忽略；第三方、证据和已有结果不删除。

## 四、本地生成目录

|目录|性质|处理边界|
|---|---|---|
|results/|正式研究结果、缓存、烟雾测试输出|不入Git，保留旧证据，本轮不移动或删除|
|build/|桥接等编译产物|生成、可删；删除后需要重新构建，本轮保留|
|.tmp_matlab/|临时MATLAB生成工作区|生成、可删；本轮保留|
|archive/|本地历史副本和日志|不当运行依赖，不因重复就删除|

[分类统计](file_category_summary.csv)、[函数冲突](function_collisions.json)和[本地生成统计](local_generated_inventory.csv)是清单快照，不是运行目录列表。历史migration/copy manifest中的旧路径按当时布局理解；当前状态与下一步只看[HANDOFF](../HANDOFF.md)。
