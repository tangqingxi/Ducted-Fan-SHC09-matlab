# HANDOFF — SHC09 MATLAB 平台（v0.4.0完成）

- **Last updated:** 2026-10-31 20:20（Asia/Shanghai）
- **当前分支：** `main`
- **本轮完成提交：** `d38526c0b3d93f4aced2846bb675d33e6c290785`（comparison完成内容）
- **最新HANDOFF提交 / 当前HEAD：** 以 `git log -1` 为准；本文件按要求单独提交 `docs: update handoff`。
- **发布版本：** `v0.4.0`，comparison-ready平台。
- **发布引用核验：** 本地main、远端main、v0.4.0剥离提交应一致；最终SHA使用下列实时命令查询，不在自引用文件内硬编码自身SHA。推送成功只有在远端核验一致后才能确认。
- **工作区：** 提交后保持干净；results/cache仍在本地且不入Git。

## 1. 当前状态与发布引用

本轮完成，已没有待补的主比较项。M4扫描30/30；M0/M2b三种子主比较60/60，0失败、0未运行。完成内容已fast-forward合入main，发布引用为v0.4.0；本文件随main和发布tag交付。发布后停止本轮开发。

```powershell
git status
git branch --show-current
git log --oneline -3
git rev-parse refs/heads/main
git rev-parse 'refs/tags/v0.4.0^{}'
git ls-remote origin refs/heads/main refs/tags/v0.4.0 'refs/tags/v0.4.0^{}'
```

最终核验要求：远端main等于本地main，远端tag对象及剥离提交均等于本地对应引用，main等于v0.4.0剥离提交。若缺少任一远端引用或SHA不符，不得仅凭本文声称推送成功；停止报告，不force push。

原基准为 `e662e7d`（v0.3.0）。本次开始状态已核对：comparison-ready本地/远端均为 `cb9c59b`、工作区干净、主比较35/60。原远端comparison-ready仍保留 `cb9c59b` 的WIP快照；本轮不推送非发布分支，后续使用main或v0.4.0，不把旧WIP当当前发布态。本地comparison-ready保留完成内容提交，所有旧分支/tag保留。

## 2. 本次完成

- 恢复前逐一核对35份日志的引擎身份、配置、参考、键及lite隔离审计，全部通过。
- 新输出 `results/allocation_comparison_allocation_comparison_research_resume/`：60/60完成；35次复用、25次新运行，恰好补齐M2b/ideal seeds2–3的10次和M2b/lite seeds1–3的15次。原105行分窗指标逐项一致，未重复计入种子。
- 完整产品：180行summary、4行comparability、204行effect_sizes、540行pareto，以及60行status/provenance和report。
- 默认入口重放60项，分窗非耗时数值、可比性、效应量与Pareto均与恢复结果一致；M4六成压力入口重放10项，lite保持stress且无候选排名。两次核验新增正式仿真0次。
- M4扫描按最终门禁重算，六组分类和数值完全一致；14个ideal主窗主指标效应量经独立计算核对。
- README、指南、CHANGELOG、v0.4.0收尾说明及轻量证据已更新，文件清单/链接检查通过。

原 `results/allocation_comparison_research_3seeds/` 仍是35/60暂停快照，作为历史证据保留；不要据它判断当前完成度，也不要把它的25个not_run改写成completed。完整结果应读取上述新目录。

## 3. 哪些可以比较

预定义门槛未改变：五方法及所有请求种子完成，主窗任一方法/种子饱和≤10%、姿态峰值≤5°、气动越界0，lite姿态估计RMS≤2°。位置峰值只报告；缺失种子、非有限值、审计失败按规则拒绝。

- M0/ideal、M2b/ideal：rankable；可按指标比较种子均值与波动。
- M0/lite、M2b/lite：均完整运行，但姿态峰值5.4697°/5.4861°超过5°，因此stress，不参与候选排名；不能将stress直接等同失稳或断言方法没有差异。
- M4/lite：0.4/0.5峰值5.5376°/5.6847°已超门槛；0.6最坏饱和96.13%、姿态峰值59.32°、估计RMS6.665°。没有可比负载，未进入主排名，未改tanh或门禁强行通过。
- M4/ideal三个扫描负载均过物理门禁，但扫描只有单种子且只评价资格，不提供方法排名。

主窗效应量：两个ideal工况的姿态、偏航、共同预测力矩和PWM步变均达到极差/池化波动≥1；角速度仅M0通过，位置仅M2b通过；饱和零方差比值NaN。M0角速度仅1.033，不能提升为显著性。动态方法的低名义残差伴随较高PWM活动，候选集依赖两轴，没有总分或全局最优。

[指南与完整解释](docs/allocation_comparison_guide.md) · [完整轻量报告](examples/allocation_comparison/main_3seeds/report.md) · [v0.4.0收尾](docs/release_notes_v0.4.0.md)。

## 4. 发布回归

本轮在 `cb9c59bbcf569f83f10a136777c319f0e4a8e7e8` 的运行代码上执行，之后只有文档、证据与清单更新：

- test_allocation_comparability：边界、单个NaN、缺失种子、位置非阈值通过。
- test_allocation_comparison：两秒M0/M2b、两种子、ideal/lite、五方法；共同输入、真实噪声种子区别、独立重跑、缓存复用、故障继续、fail_fast未运行、空表列契约、stress不排名均通过。
- 旧14/14、平台6/6通过；六组冻结基线非耗时SHA与PWM逐位一致。
- MVP与E3契约测试通过；没有重跑E1/E2全量或完整六工况阶梯。
- run_estimator_tests仍按预期在 `shc09:LitePhysicalBias` 失败，偏置约0.061°/s >0.05°/s；未修改门限。
- 恢复、回归、输出核验三批MATLAB进程退出码均0。

[发布验证总记录](docs/release_validation/v0.4.0/release_checks.json)。本轮完整回归为 `docs/estimator_diagnosis/release_v040_complete_*`；旧 `release_v040_*` 四份是暂停前的局部历史记录，未删除或冒充新验收。

## 5. 关键路径

|内容|路径|
|---|---|
|完整主比较|`results/allocation_comparison_allocation_comparison_research_resume/`|
|原暂停快照（35/60）|`results/allocation_comparison_research_3seeds/`|
|缓存|`results/allocation_comparison_cache/`|
|主比较轻量证据|`examples/allocation_comparison/main_3seeds/`|
|M4扫描及选择|`results/m4_load_sweep_research_seed1/`、`configs/comparison/m4_selection.json`|
|M4轻量证据|`examples/allocation_comparison/m4_load_sweep/`|
|默认/压力重放核验路径|见 `docs/release_validation/v0.4.0/release_checks.json`|
|恢复日志|`archive_v040_resume_complete.log`|
|完整发布回归日志|`archive_v040_complete_release_tests.log`|
|最终输出核验日志|`archive_v040_final_output_audit.log`|

results/build/archive/cache不入Git，全部旧研究结果保留。provenance中的本机路径用于定位原始证据，克隆仓库无需这些文件即可冷启动复现。

## 6. 使用与边界

```matlab
ca_setup;
s = allocation_comparison_app;
```

默认两工况、ideal/lite、五方法、seeds1:3。无缓存时会运行60次20秒仿真，已有缓存只补缺项；读取s.output_dir定位结果。两秒smoke_test只是契约验证，不替代正式研究；每次新output_tag禁止覆盖已有目录。本轮没有剩余项，不应继续补跑原暂停计划。

lite仍experimental，默认ideal；偏置门禁失败未修。真实/名义tau均30ms、速率600°/s匹配；gyro/compute delay为0，求解耗时只记录。ECL是旧版归档核心，本轮没有ECL E3。M4扫描单种子、主比较三种子，只做方向和效应量，不做p值、显著性、实机优势或全局排名。

本轮未做可视化、执行器真实化、lite v2、参数不确定性、台架/悬停标定或HIL，不继续开启新研究。

## 7. 不要做

1. 不改物理、控制器、五算法、旧协议、估计器增益/偏置门禁，不用真值兜底。
2. 不放宽可比性阈值，不把stress的Pareto包装成排名，不伪造失败或缺失数据。
3. 不reset/clean，不删除results/archive/examples/docs证据，不从main重新clone覆盖本地结果。
4. 不force push，不删除旧分支/tag，不推送非发布分支。
5. 不读写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。
6. 不运行完整30次失配阶梯或E1/E2全量重跑；本轮已经完成并停止。

## 8. 以后长任务的更新协议

每次结束、暂停或失败都更新本文件：Client时间（Asia/Shanghai）、当前分支、提交/tag、远端引用核验、完成/失败/未运行项、结果与缓存路径、具体下一步及边界。单独提交 `docs: update handoff`；未发布时留在工作分支，发布时随main推送。自身HEAD使用实时refs，避免写死自引用SHA。
