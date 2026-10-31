# 仓库文件治理报告

## 全都有用吗？

不是每个本地 .m 都属于活跃运行链。Git tracked 源码只是其中一部分；archive/results 的隔离镜像、历史脚本和运行产物造成大量本地副本。测试、参考、基线与报告证据有保存价值，不需要每次运行；兼容入口与动态注册代码不能按文本“未引用”直接删除。

本轮采取保守整理：核心、控制器、五分配算法、物理、测试、fixtures、baseline、examples、第三方和全部结论证据保留。精确重复保留 canonical 标记与上下文，不直接删兼容层；未引用条目标为 legacy 候选待审，不删除。四个一次性诊断入口已迁移到版本化 docs/evidence，保留原路径包装；不会放进被忽略的 archive 导致证据丢失。

## 统计与方法

以 [清单统计](file_inventory_stats.json) 的 snapshot_commit 和 generated_utc 为准。file_inventory 覆盖 Git 索引全部文件；每个 tracked .m 给出大小、最后提交、文本引用文件数和入口/测试/fixture 标志。生成目录单独聚合目录/扩展/数量/大小，不加入 Git。

[分类统计](file_category_summary.csv) · [精确重复](file_duplicates.csv) · [同名与调用者](function_collisions.json) · [未引用候选](file_orphan_candidates.csv) · [全文件决策](file_inventory.csv)。canonical 仅代表内容身份，不代表不同包的许可、测试或证据上下文可删除。

引用统计扫描 tracked .m/.md/.py 的标识符和文字，不是完备 MATLAB 调用图；注释/文档提及也计入。排除自身，调用者清单完整保留；动态句柄、外部入口等限制让“零引用”不能自动成为删除依据。同名按 MATLAB 文件查找名分组，ca_setup 的显式活动目录内重名才算运行冲突；其他副本照列。

## 决策与风险

- 删除：1 个本轮生成的 Python 字节码缓存；重建命令及 SHA 见 [清理清单](repo_hygiene_cleanup.json)。核心/测试/研究证据删除数为 0，大目录未清空，本地结果/历史/编译程序仍保留。
- 保留：所有核心、兼容入口、冻结材料、CSV/JSON/MAT、第三方及许可。
- 移动：四个 Stage6A 一次性实现，原路径保留四个兼容包装，见 [manifest](evidence/stage6a_manifest.json) 与 [历史实现说明](evidence/stage6a/README.md)。只有首个函数声明加 stage6a_ 前缀；还原后与 MVP tag 的 Git blob 逐字节相同。
- 孤儿：仅保留待审 archive 候选，没有以无引用推断无用。
- 历史：旧平台/Stage5/6A 报告、migration/copy manifest 作为历史记录在 docs 索引标注，不改旧结论。

检查分级：tracked 临时文件、活动路径重名、当前仓库内坏链接和未覆盖文件会失败；大文件逐项列出处理意见。忽略目录的结果链接作为本地生成引用单列，不能假称其随 Git 发布；不访问外部本地工程，也不联网验证 URL。

## 重复生成与验收

```text
python tools/repo_inventory.py
python tools/repo_inventory.py --check
```

```matlab
ca_setup; addpath('tools'); check_repo_hygiene;
```

迁移后新鲜 MVP 契约测试、旧十四项、平台六项及六组逐位基线全部通过，物理偏置仍为 LitePhysicalBias 预期失败，见 [验收记录](repo_hygiene_validation/phaseB_regression.json)。最终治理检查包含清单覆盖、四个包装/实现哈希、活动函数名、链接、大文件、临时文件和孤儿清单。lite 偏置门禁仍失败，默认 ideal 不变；不实现 lite v2、ECL 默认、执行器真实化、参数不确定性、完整阶梯或 HIL。不 push，不改变旧分支，分类型提交，最终 tag repo-hygiene。


## 逐类决策与快照

<!-- GOVERNANCE_STATS -->
截至本轮快照：tracked **603** 个文件，其中 **299** 个 .m；四个本地目录 **11271** 个文件、**2308642650** 字节，其中 **5174** 个 .m。

本地 MATLAB 只有 **373** 种独立字节内容，**4855** 份匹配 tracked 内容；tracked 精确重复 **5** 组，同名文件组 **0**，未引用候选 **22**。

| 类别 | 文件数 | .m 数 | 大小（字节） | 活跃与动作 |
|---|---:|---:|---:|---|
| 兼容/旧API及研究分析 | 87 | 86 | 192052 | 核心活跃/兼容按需；保留并索引 |
| 历史脚本/证据 | 6 | 4 | 20228 | 测试/历史/工具按职责；保留并索引 |
| 工具/第三方 | 182 | 65 | 1849599 | 测试/历史/工具按职责；保留并索引 |
| 工程元数据 | 4 | 0 | 18990 | 测试/历史/工具按职责；保留并索引 |
| 文档/证据 | 112 | 0 | 17454814 | 测试/历史/工具按职责；保留并索引 |
| 核心运行 | 118 | 106 | 175592 | 核心活跃/兼容按需；保留并索引 |
| 测试/冻结 | 94 | 38 | 1045102 | 测试/历史/工具按职责；保留并索引 |
<!-- GOVERNANCE_STATS_END -->

初始 5463 个本地 .m = 起点 289 个 tracked + 5174 个忽略目录副本。当前 tracked .m 增加来自 MVP、治理工具与四个版本化历史实现；原路径仍保留包装，目标是厘清职责而非压低文件数。

[目录/扩展统计](tracked_directory_extensions.csv) 记录 tracked 文件数与字节数；[本地扩展统计](local_generated_inventory.csv) 单独统计四个忽略目录；[本地 MATLAB 内容比对](local_matlab_duplicates.csv) 为全部本地 .m 给出 SHA、canonical 与是否匹配 tracked 内容。清单及哈希按生成时快照解释；自描述 CSV 的哈希取写出前输入快照，不能把它当自身内容的密码学固定点。所有 .m 的 last_commit 是 snapshot_commit 之前最后一次 Git 修改，不把历史报告日期当成当前依赖版本。

没有把可执行文件、缓存日志或大型结果加入 Git；只版本化盘点元数据。未把“第三方没有本项目调用”解释成可删除上游源码，未把重复验证表删掉。22 个零文本引用条目只是保留待审，其中第三方按上游上下文保留；完整理由见逐文件清单。

## 剩余风险与停止

静态引用不能识别所有动态调用和外部用户；本地目录统计随后续运行增长，快照不是永久占用量。既有 MATLAB JVM 批处理退出停留仍可能发生；本轮只在完整结果写出、CPU停止增长并核对命令行后清理本轮闲置进程，不把退出停留当成数值失败或已修复。未验证远端 URL 的网络可达性。

Phase A tag estimated-comparison-mvp 单独冻结 MVP；Phase B 在 repo-hygiene 分支分盘点、历史实现保留、文档/忽略规则收尾三个提交。最终提交消息为 repo hygiene: inventory, map, and conservative cleanup，最终 tag repo-hygiene。不改写历史，不 push，不继续后续估计器或物理研究。
