# HANDOFF — v0.5 WIP：lite数值资格通过，新增回归失败后停止

- **Last updated:** 2026-10-31T21:46+08:00（Asia/Shanghai）。
- **当前分支：** `lite-comparison`，只保存在本地，未推送。
- **WIP代码/结果提交：** `ae99d5bc5d494234fc736a603cb27c777c9b62ac`（`wip: preserve lite first-round results and regression failure`）。
- **最新HANDOFF提交 / 当前HEAD：** 以 `git log -1` 为准，本文件单独以文档提交保存。
- **当前发布版本：** 仍为 `v0.4.0`；本地及远端main保持 `9594ce8460949ad22735c0817d4a06f98de5e3c4`。
- **v0.5.0：** 未打tag、未合并main、未推送。不要把本分支WIP当发布态。
- **工作区：** 文档提交后应干净；results/cache/archive仍保留本地，不入Git。没有遗留的本次MATLAB运行进程。

## 1. 停止原因：新增回归测试失败

用户硬停止条件为“任何状态不一致/测试破坏/需要放宽门禁：立即停止，不继续调参”。第一轮lite的30次已经全部完成且两工况均rankable，但新增 `test_lite_comparison_rankable` 从CSV导入全空error_id列后，在第16行重新计算comparability时失败：`allocation_comparability` 第31行的contains要求文本，第一个参数实际不是文本。

这是新增测试的导入类型处理遗漏。依据报错与CSV全空列，判断readtable将error_id推断为数值；停止后没有追加运行验证或修正测试，更没有改既有allocation_comparability/门禁。逐项数值门禁断言先于该调用，但整个新增测试必须记为失败。

该失败发生在ideal预检批次的首项测试，批次退出码1；**正式ideal 30次尚未开始**。已按要求停止，不继续第二轮调参，也不发布。保存的lite结果不作假，旧回归通过也不能代替新增测试或本轮ideal完整不变性验收。

[失败记录](docs/lite_comparison_validation/peak_regression_failure.json) · [错误转录](docs/lite_comparison_validation/peak_regression_failure.txt) · [修复与停止说明](docs/lite_comparison_fix.md)。

## 2. 初始状态与已完成项

本轮开始先读旧HANDOFF，确认main=9594ce8、v0.4.0剥离提交相同、工作区干净；pull --ff-only已是最新，再创建lite-comparison。开始时M0/M2b ideal为rankable、lite仅因主窗真实姿态峰值超过5°而stress。

1. 从原35/60暂停快照读取已完成M0/lite的log_key；M2b/lite原目录未运行，因此按旧HANDOFF读取v0.4完整恢复目录。离线诊断30条轨迹，分别定位whole/task峰值及完整角速度、姿态、参考、v_h/v_c、舵角/命令、饱和、偏置和邻域。
2. 在生产代码修改前写好[一页诊断](docs/lite_comparison_peak_diagnosis.md)。seed1五方法均在10.9s超限，GNSS离散位置/速度修正引起参考倾角单步约2.335°跳变；不是6s加载、16s卸载或偏置瞬时尖峰。实际加载2s，6s仅为主窗起点。
3. 第一轮统一候选：只把lite GNSS互补修正按0.1s连续注入，时间常数取5Hz周期的一半；下一次创新包含待注入量以避免重复计入。位置/速度原融合增益、Mahony kp/ki、原始测量噪声/偏置、物理和共享控制器均不改；有导航修正滞后代价，不宣称传递特性完全不变。
4. 第一轮正式lite **30/30全新完成，0 failed、0 not_run**。批次正常退出码0。两个工况均rankable；没有使用第二轮。
5. lite自身90行summary、2行comparability、102行effect_sizes、270行pareto、30行status/provenance和report全部落盘，并复制轻量证据；未生成本轮ideal或统一60次产品。

|工况|旧主窗峰值°|新主窗峰值°|新饱和最大%|新估计姿态RMS最大°|气动越界|数值资格|
|---|---:|---:|---:|---:|---:|---|
|M0/lite|5.469686|3.774890|0|1.314381|0|rankable|
|M2b/lite|5.486132|3.781685|0|1.315679|0|rankable|

门禁仍逐方法/种子主窗最坏值：5°/10%/2°/气动越界零，主窗仍[6,16]，20秒、负载0.6、原tanh和五算法不变。位置峰值仅报告。lite输入只有原始测量及公开常量，没有plant truth或ideal反馈兜底。

当前lite主窗的姿态、偏航、角速度、位置差异均小于池化种子波动；共同预测力矩与PWM步变的极差/池化比值约29.6～29.8及80.0～80.5，按规则可区分整组效应。饱和均零，比值NaN。rankable不代表五方法两两可区分，不宣称显著性或总排名。完整均值/标准差/样本数见CSV。

## 3. 代码范围与回归

生产修改仅三个允许文件：

- platform/modules/estimator/shc09_estimator_lite_module.m：GNSS待注入修正状态及每步连续注入。
- platform/modules/estimator/shc09_lite_params.m：公开白名单与正有限时间常数校验。
- configs/params/ca_realism_defaults.m：lite_gnss_correction_tau_s=0.1。

源码按LF写入；当前数值引擎为 `26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286`。文档、analysis新诊断及tests新测试不进入该引擎摘要。虽然共享控制器和ideal估计器未改，数值引擎摘要已改变，必须按用户要求重跑ideal 30次，不能直接复用v0.4指纹。

- test_allocation_comparability、test_allocation_comparison：通过边界、NaN、缺失种子、故障继续、缓存、独立重复与隔离等检查。
- run_project_tests(false)：14/14；run_platform_tests：6/6。
- test_platform_baseline：六组完整非耗时SHA与PWM逐位一致，最大差0。
- test_lite_gnss_output_continuity：通过修正总量、指数衰减及无真值topic检查。
- run_estimator_tests：仍只在既有 `shc09:LitePhysicalBias` 预期失败，约0.061°/s >0.05°/s；未放宽阈值。其余前序估计器检查通过。
- test_lite_comparison_rankable：**失败**，见停止原因；没有将它记作通过。

[回归断言记录](docs/lite_comparison_validation/iteration1/checks.json) · [冻结基线](docs/lite_comparison_validation/iteration1/baseline.csv) · [生产范围与源码SHA](docs/lite_comparison_validation/iteration1/source_scope.json)。回归批次断言全部完成后MATLAB在退出阶段挂起，闲置约6分钟后只清理本次工作进程；[退出记录](docs/lite_comparison_validation/iteration1/shutdown.json)明确该进程未正常退出，清理返回1，不冒充MATLAB正常退出0。此退出问题与随后新增测试的真实失败分别记录。

## 4. 路径与未运行项

|内容|路径|
|---|---|
|本轮lite完整日志/研究|results/allocation_comparison_allocation_comparison_lite_rankable/|
|本轮轻量证据|examples/lite_comparison_v050/lite_3seeds/|
|原峰值/邻域CSV|examples/lite_comparison_v050/diagnosis/|
|本地详细离线诊断|results/lite_peak_diagnosis_v050_detailed/|
|缓存|results/allocation_comparison_cache/|
|lite正常完成日志|archive_v050_iteration1_lite.log|
|旧回归及比较器日志|archive_v050_iteration1_regression.log|
|新增测试失败日志（ideal未开始）|archive_v050_ideal_invariance.log|
|已准备但未跑完的ideal驱动|results/v050_ideal_invariance_driver.m|
|未执行的统一产品驱动/说明脚本|results/v050_products_audit_driver.m、results/v050_evidence_summary.py|
|v0.4完整60次|results/allocation_comparison_allocation_comparison_research_resume/|
|v0.4原35/60快照|results/allocation_comparison_research_3seeds/|

所有旧结果保留，原暂停快照仍是35/60，不改成完成。完整MAT/cache/archive不入Git；克隆后轻量CSV和诊断/测试入口可供审查，原始日志仍需冷启动复现。provenance本机路径只用于定位证据。

**未完成：** 修正并通过新增主窗回归；ideal正式30次及其对v0.4逐位不变验证；统一60次产品与最终报告；v0.5 README/CHANGELOG/release notes；main合并、tag/push与远端SHA核验。现有README/CHANGELOG仍按真实已发布v0.4.0保留，没有提前宣称v0.5发布。

## 5. 恢复后下一步

须由用户恢复任务后再继续：

1. 先读本文件和失败记录，检查lite-comparison、干净工作区、main/tag仍为v0.4.0。不要把当前不在main误判成外部状态异常；此分支是本轮按指令创建并保留的WIP。
2. 只修正新增测试的CSV导入列类型（明确error_id等文本列），不改既有门禁或估计器。先对保存的30条lite结果跑该测试。纯测试导入修正不改变数值引擎时，不必重新仿真已完成lite30次。
3. 通过后全新跑ideal30次（use_cached=false），每条非耗时日志与v0.4完整恢复目录逐位核对。已有ignored驱动可供审查再使用；输出目录尚未创建。
4. ideal不变且rankable后重放当前引擎缓存形成统一60次产品，解释lite方法差异和种子波动；完成要求的测试与文档验收。任何新测试失败仍按用户停止规则处理。
5. 仅在完整验收通过后按原发布步骤合并main、单独更新发布态HANDOFF、打v0.5.0并显式push main/tag、核验远端SHA。不force push。

本轮生产迭代计数1/2；停止不是因为第二轮峰值仍超限，而是新增回归失败。没有依据继续盲调，也不能借已通过数值门禁跳过测试。

## 6. 当前引用核验与边界

```powershell
git status
git branch --show-current
git log --oneline -3
git rev-parse refs/heads/main
git rev-parse 'refs/tags/v0.4.0^{}'
git tag --list 'v0.5*'
git ls-remote origin refs/heads/main refs/tags/v0.5.0 'refs/tags/v0.5.0^{}'
```

应保持本地/远端main=9594ce8460949ad22735c0817d4a06f98de5e3c4，v0.4.0剥离提交同值，无v0.5.0引用。lite-comparison只含本地WIP和本次HANDOFF提交，未推送。

lite仍experimental，默认ideal，旧物理偏置门禁未修；真实/名义执行器tau与速率匹配，gyro/compute delay=0，无实机标定。M4本轮未跑，旧M4扫描只作v0.4历史证据，不推断本修复使M4通过。

不改物理、气动、五算法、共享控制器、ideal估计器、旧协议或5°/10%/2°/偏置0.05°/s门限；不真值兜底。不跑完整失配阶梯、E1/E2全量、M4新扫描、可视化、执行器真实化、lite v2或参数不确定性。不reset/clean、不删除旧证据、不重clone覆盖、不force push。禁止读写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。

每次结束、暂停、失败都更新HANDOFF并单独文档提交；自身HEAD使用实时git refs，避免自引用SHA。当前已触发硬停止条件，保存后停止，不继续工具开发。
