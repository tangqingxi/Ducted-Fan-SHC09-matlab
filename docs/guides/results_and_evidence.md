# 如何阅读结果与验证证据

先确定研究协议和运行路径，再读指标。结果目录名或报告中的“完成”不能代替验收定义；当前工作状态见[HANDOFF](../../HANDOFF.md)。

## 四个容易混淆的问题

| 问题 | 需要的证据 |
|---|---|
| 仿真有没有跑完 | status/completion、实际时间轴、方法/种子覆盖及失败记录 |
| 数值数据是否有效 | 有限状态、气动域、时序、来源锁、输入签名和日志完整性 |
| 科研性能是否通过 | 原先规定的评价域、窗口、阈值和逐run判定，真实/估计误差分别看 |
| 数据是否需要保留 | 独立证据价值、来源唯一性、失败诊断和复算能力，不由性能通过自动决定 |

例如两批55秒正式实验都15/15完成、估计恢复15/15，但真实恢复0/15。GNSS v2也完成一条55秒数值回归，真实恢复仍未通过。它们值得保留，不应删除失败记录或放宽阈值来使结果“通过”。

## 当前文件实际在哪里

原始MAT及输入通常在本机results/<原批次>/；部分WTR位于logs/wtr/<批次>/，图位于figures/<批次>/，来源锁和独立检查也可能在docs/validation/<任务>/或examples/<交付>/。同一研究跨目录是当前事实，不等于已经采用统一Results布局。

Git通常保存轻量CSV/JSON/PNG/PDF、协议、来源和报告，不保证包含原MAT/WTR/EXE。图、抽取轨迹或metrics.csv不能恢复完整原始日志。旧F8/PPID/hover的部分原始数据已经按历史任务清理；先查[Phase2A保护计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/BACKUP_PLAN.csv)与Phase1批次索引，不能按旧报告路径假定仍可回放，也不重新仿真“补回”。

## 重点研究入口

- [平台比较证据](allocation_comparison_guide.md)：rankable表示满足指定可比条件，不等于方法显著可分；M4压力场景不直接参与主排名。
- [四环八字交付](../../examples/ppid_pindi_f8_20261101/README.md)：15条52秒任务采用本协议宽松要求，不与旧F8门槛合并。
- [历史55秒正式批](../validation/hover_distance_takeoff_formal_20261103_r1/README.md)与[change-B审计](../validation/shc09_b_frame_20261104/independent_audit_20261104/audit_report.md)：执行版来源、管理性续跑、真实/感知误差和求解时序分别保存。
- [Round 7](../validation/shc09_b_frame_20261104/round7_fixed_bias_init_20261104/report.md)：完整固定偏置初始化及来源时刻校正；旧Round 6原统计保留，不覆盖错误记录。
- [GNSS v2回归](../validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/report.md)：1000 s独立版本；[Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)暂缓且非结构治理阻塞。

单个RMSE不能概括不同坐标/评价域。原始ECL世界坐标误差、扣除固定任务原点后的估计误差、真实跟踪误差和控制器感知误差都可能不同；不同条件RMSE标量差不能解释为严格可加物理贡献。三种子结果描述本批权衡，不宣称实机优势或所有工况最优。

## 已知测试限制

[PINDI拆分报告](../history/ENGINEERING_HISTORY.md)记录旧平台速率环两行修正后，旧行为兼容测试和逐位数值基线未通过。总需求代数相同可能有浮点末位差，受限PCA的优先级拆分变化还可能产生实际行为差异，两者不能混为一个容差问题。[lite结果](lite/results.md)中比较门禁通过也不代表独立物理偏置门禁通过。

这些是已保存限制，不表示本轮重新执行了测试。run_project_tests、run_platform_tests、test_platform_baseline等会运行实际对象/生成结果；本轮文档任务未执行它们，没有新增仿真、ECL构建或WindTrace构建，也不宣称当前全套测试通过。

## 来源、SHA与复算等级

记录执行起点commit、实际源码快照、engine、显式source_lock、协议完整SHA、输入签名与方法/种子。执行后修复管理代码时保留原驱动及前后差异；不能checkout当前main后替换旧锁来声称原批复现。

本机文件SHA256、Git blob OID和发布正文SHA256是不同口径。历史原始字节保持，文档的CRLF/LF发布差异另作记录。Phase2A已核对Phase1的49项交付：36项仅换行不同、13项逐字节相同，无实际内容修改；详见[远端完整性方案](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/REMOTE_DELIVERY_INTEGRITY.md)。

“指标可以读取”“可从保存L/ref复算”“具备精确执行源码重放条件”“已独立备份并恢复验证”分别说明，缺任何一项都不自动升级。独立审计仓库只保存轻量计划和证据，不是原始数据的备份设备。

## 未来治理

[Results合同与生命周期](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/RESULTS_LIFECYCLE.md)将execution、acceptance、retention分开，并设计results/<study>/<batch_id>及旧路径索引。当前仅设计，未实际迁移。先批准独立备份位置、保护范围及恢复验证，再登记、验证和逐文件审批迁移；删除另需明确范围。

17份根目录codex-repo报告保留原文；当前事实可从本页入口核对，旧首页和旧交接可在science baseline提交339d7b1a的Git历史中追溯。
