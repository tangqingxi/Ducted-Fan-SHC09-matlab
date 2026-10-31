# CHANGELOG

## v0.5.0 — 2026-10-31

- lite内部连续注入GNSS位置/速度互补修正，统一0.1秒时间常数，保留原融合增益；不改共享控制器、物理、气动、五算法、旧协议或ideal估计器，无真值兜底。
- lite30/30、ideal30/30完成，M0/M2b四组均rankable；lite峰值5.4697°/5.4861°→3.7749°/3.7817°，饱和0%、估计RMS≤1.316°、气动越界0。5°/10%/2°及主窗不变。
- 修复CSV全空error_id被推断为数值时contains报错；status/error_message等文本缺失值归一化，空状态不补成完成，CacheMismatch/TopicAudit仍invalid。新增真实CSV往返回归。
- ideal30次全新运行，完整非耗时日志逐条与v0.4一致；当前引擎缓存重放60项生成180行summary、204行效应量、540行Pareto，额外正式仿真0次。
- CSV/比较器测试、lite主窗峰值回归、旧14/14、平台6/6、六组冻结基线通过。LitePhysicalBias仍按0.05°/s预期失败；默认ideal，lite experimental。
- lite主窗跟踪/位置差异小于种子波动，共同预测力矩与PWM活动存在可报告差异；不宣称所有方法两两可区分、显著性或全局最优。未复跑M4，未扩展其他功能。

[修复与诊断](docs/lite_comparison_fix.md) · [结果与波动](docs/lite_comparison_results.md) · [发布验证](docs/release_validation/v0.5.0/release_checks.json) · [收尾说明](docs/release_notes_v0.5.0.md)。发布后停止本轮开发。

## v0.4.0 — 2026-10-31

- 标准入口allocation_comparison_app：固定门禁、跨种子效应量、九种二维Pareto；可选工况/模式/方法/种子，支持缓存和失败记录继续。
- M4负载扫描30/30；lite无可比负载，按既定规则以M0/M2b作主比较。门槛保持五方法完整、主窗饱和≤10%、姿态峰值≤5°、气动越界0、lite估计RMS≤2°。
- 主比较60/60完成：本次复用35份、仅补跑25次；180行summary、204行effect_sizes、540行pareto。两个ideal工况rankable，两个lite工况stress，不生成stress候选排名。
- 效应量逐方法保留三种子均值/标准差/样本数；缺失或零池化方差比值NaN。通过门禁且比值≥1才标distinguishable，无p值、显著性或综合分数。
- 新门禁/比较测试、旧14/6、六组逐位基线、MVP/E3通过；LitePhysicalBias按预期失败。默认入口与压力入口缓存重放验证，不追加研究仿真。
- 默认ideal，lite仍experimental；tau/rate匹配，gyro/compute delay=0，无实机。物理、控制器、五算法、协议和估计器门槛不变；未做可视化、执行器真实化、lite v2或HIL。

[指南与结果](docs/allocation_comparison_guide.md) · [发布验证](docs/release_validation/v0.4.0/release_checks.json) · [收尾说明](docs/release_notes_v0.4.0.md)。完成发布后停止本轮开发。

## v0.3.0 — 2026-10-31

- E3估计反馈结构失配：M0/M2b/M4 × ideal/lite × 五方法，单组配对种子30/30全新完成；严格气动域error、健康检查及lite真值topic隔离保持不变。
- 固化分窗跟踪、名义分配残差、离线实际模型误差、PWM活动/饱和、估计指标及二维Pareto；90行汇总、810行Pareto、轻量CSV/PNG与可复现入口。
- M4/lite没有完整保留ideal的两组收敛图景，部分方法出现高饱和和大姿态退化；仍能区分闭环行为，不能视为估计噪声简单掩盖差异。
- M0/M2b主窗姿态微小差异在本次单种子下不能排名；分配/代价和实际模型误差保留信息。M4动态方法的PWM活动较高、共同残差较低，饱和率并不必然更高。无综合分数或全局最优主张。
- E3两秒M0/M2b烟雾增加独立重复：完整非耗时数值日志签名、汇总、Pareto精确一致，并核对共同参考/初态/噪声和图表。
- main fast-forward合并E3；发布前旧14/14、平台6/6、六组冻结基线、MVP、E3均通过。run_estimator_tests仍按预期在LitePhysicalBias失败，门槛未修改。

lite仍experimental，默认ideal；本轮未运行可选ECL。ECL旧版、真实/名义tau匹配、单种子、无实机标定及local results不入Git的限制不变。未做lite v2/ECL默认、执行器二阶/死区/延迟、参数不确定性、台架/悬停标定、完整多种子统计或HIL。

[详细结果](docs/e3_estimated_structural_mismatch.md) · [发布验证](docs/release_validation/v0.3.0/release_checks.json) · [收尾说明](docs/release_notes_v0.3.0.md)。v0.3.0发布后暂停工具开发，不再扩展本轮任务。

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
