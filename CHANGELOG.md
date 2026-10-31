# CHANGELOG

## v0.2.0 — 2026-10-31

- PX4 式平台：总线、调度、参数视图、模块 topic、日志与统一入口。
- 五分配器插件：DA_NS、WLS、DCA、静态 PCA、预测 PCA；保持原物理、控制器、算法及协议。
- 估计器真实化与 Stage 6A 偏置诊断，独立 ECL 交叉验证。
- 估计反馈分配比较 MVP：分窗跟踪、分配、控制代价、估计指标和 Pareto 图/表，缓存优先，无综合得分。
- 仓库治理：全文件清单、目录地图、历史证据及兼容包装、保守清理。
- 治理 tag 更名为 repo-hygiene-pass，避免与同名分支歧义；保留所有其他历史分支/tag。

### 状态与已知限制

lite 仍 experimental，实际闭环偏置 .05°/s 门禁仍失败；默认 ideal，只作 oracle 与冻结回归。ECL 为归档旧版独立交叉验证，需要 JVM，未提升为默认。

结果只包含单/三种子方向与效应量，不能作显著性或实机优势主张；真实/名义 tau 仍匹配，无实机标定。local results/archive/build 不入 Git，版本仅携带轻量证据与可复现入口。未做 lite v2、执行器二阶/死区/延迟、参数不确定性、完整多种子统计或 HIL。

发布前在 main 上检查旧 14 项、平台 6 项、冻结六组逐位基线及 MVP 测试；run_estimator_tests 仍按预期在 LitePhysicalBias 停止。发布 tag 在检查通过后创建；远端发布状态另由 Git SHA 核验，不能仅凭本文件判断推送成功。
