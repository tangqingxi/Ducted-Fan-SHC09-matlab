# 仓库文件治理报告

## 全都有用吗？

不是每个本地 .m 都属于活跃运行链。Git tracked 源码只是其中一部分；archive/results 的隔离镜像、历史脚本和运行产物造成大量本地副本。测试、参考、基线与报告证据有保存价值，不需要每次运行；兼容入口与动态注册代码不能按文本“未引用”直接删除。

本轮采取保守整理：核心、控制器、五分配算法、物理、测试、fixtures、baseline、examples、第三方和全部结论证据保留。精确重复保留 canonical 标记与上下文，不直接删兼容层；未引用条目标为 legacy 候选待审，不删除。一次性诊断入口将单独迁移到版本化 docs/evidence，保留原路径包装；不会放进被忽略的 archive 导致证据丢失。

## 统计与方法

以 [清单统计](file_inventory_stats.json) 的 snapshot_commit 和 generated_utc 为准。file_inventory 覆盖 Git 索引全部文件；每个 tracked .m 给出大小、最后提交、文本引用文件数和入口/测试/fixture 标志。生成目录单独聚合目录/扩展/数量/大小，不加入 Git。

[分类统计](file_category_summary.csv) · [精确重复](file_duplicates.csv) · [同名与调用者](function_collisions.json) · [未引用候选](file_orphan_candidates.csv) · [全文件决策](file_inventory.csv)。canonical 仅代表内容身份，不代表不同包的许可、测试或证据上下文可删除。

引用统计扫描 tracked .m/.md/.py 的标识符和文字，不是完备 MATLAB 调用图；注释/文档提及也计入。排除自身，调用者清单完整保留；动态句柄、外部入口等限制让“零引用”不能自动成为删除依据。同名按 MATLAB 文件查找名分组，ca_setup 的显式活动目录内重名才算运行冲突；其他副本照列。

## 决策与风险

- 删除：0。没有确认安全收益的大目录不清空；本地结果/历史/编译程序仍保留，后续可按来源重建再清理缓存。
- 保留：所有核心、兼容入口、冻结材料、CSV/JSON/MAT、第三方及许可。
- 移动：计划四个 Stage6A 一次性入口，随后更新 manifest 和验证记录。
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

最后代码整理后运行新 MVP 契约测试、旧十四项、平台六项及逐位基线。lite 偏置门禁仍失败，默认 ideal 不变；不实现 lite v2、ECL 默认、执行器真实化、参数不确定性、完整阶梯或 HIL。不 push，不改变旧分支，分类型提交，最终 tag repo-hygiene。
