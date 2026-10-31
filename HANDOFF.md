# HANDOFF — v0.5.0：估计反馈比较完成

- **Last updated:** 2026-10-31T22:29+08:00（Asia/Shanghai）。
- **当前分支：** main。
- **发布内容提交：** d0f8e79d7eac696f063aaa38a9e1b3be4a6ac75b，已由lite-comparison fast-forward合入main。
- **最新HANDOFF提交 / 当前HEAD：** 以git log -1为准，本文件单独提交 `docs: update handoff for v0.5.0`。
- **发布版本：** v0.5.0，estimated-feedback comparison。本文件随main及annotated tag交付。
- **发布引用核验：** 最终main、远端main及v0.5.0剥离提交必须一致，tag对象亦须一致；自身SHA不硬编码在自引用文件中，使用下方实时命令。只有推送后远端核验一致，才确认发布成功；失败停止，不force push。
- **工作区：** 提交后保持干净；完整结果/cache/archive仅在本地保留。没有本次MATLAB进程遗留。

## 1. 完成状态与引用

正式比较60/60完成，0 failed、0 not_run：M0/M2b×ideal/lite×五方法×seeds1:3，四个case/mode均rankable。第一轮lite30次全新结果保留，本次补ideal30次全新运行；ideal全部完整非耗时日志逐条与v0.4一致。统一产品重放当前引擎缓存60项，额外正式研究仿真0次。本轮完成后停止，不继续开发其他功能。

```powershell
git status
git branch --show-current
git log --oneline -4
git rev-parse refs/heads/main
git rev-parse refs/tags/v0.5.0
git rev-parse 'refs/tags/v0.5.0^{}'
git ls-remote --heads origin main
git ls-remote --tags origin v0.5.0 'v0.5.0^{}'
```

远端main等于本地main；远端tag对象及剥离提交等于对应本地引用，且剥离提交等于main。发布前远端main核对为9594ce8460949ad22735c0817d4a06f98de5e3c4，无v0.5.0；按显式main/tag两次推送交付。v0.4.0剥离提交仍9594ce8，所有旧分支/tag保留。本地lite-comparison停在d0f8e79，保留WIP到验收的历史，不推送非发布分支。

## 2. 结果与修复

固定20秒、负载0.6、主窗[6,16]。门禁仍逐方法/种子最坏值：主窗姿态峰值≤5°、饱和≤10%、lite估计姿态RMS≤2°、气动越界0，五方法及全部种子完成。位置峰值仅报告，未改变任何数值门禁、窗口或指标。

|工况|模式|主窗姿态峰值°|饱和最大%|估计姿态RMS最大°|气动越界|资格|
|---|---|---:|---:|---:|---:|---|
|M0|ideal|0.00526349|0|0|0|rankable|
|M2b|ideal|0.00523503|0|0|0|rankable|
|M0|lite|3.774890|0|1.314381|0|rankable|
|M2b|lite|3.781685|0|1.315679|0|rankable|

lite修复前峰值5.4697°/5.4861°，修复后3.7749°/3.7817°；原饱和2.1915%/2.0114%降至0%，估计RMS由1.4045°/1.4065°降至1.3144°/1.3157°。跨全部15条轨迹分别取最坏值，不用方法均值替代门禁。

修复前先离线诊断30轨迹并写一页记录。seed1五方法均在10.9s超限，GNSS离散位置/速度修正引起参考倾角约2.335°跳变；不是6s加载或16s卸载。只在lite内部按统一0.1s连续注入待修正量，下一次创新包含剩余量，原融合增益/噪声、Mahony kp/ki和共享控制器不变，无真值兜底。该处理有导航修正滞后代价，不声称传递特性完全不变；只有一轮生产修复，没有第二轮调参。

此前新增峰值回归因CSV全空error_id被推断为数值而停止，历史失败记录保持原样。用户恢复后，analysis/allocation_comparability.m在contains前把error_id转string、缺失置空，并统一status/error_message等文本表示；不填充完成状态。CacheMismatch/TopicAudit仍invalid，空status仍stress。CSV往返及保存的lite30次峰值回归现均通过。

[修复前诊断](docs/lite_comparison_peak_diagnosis.md) · [修复与CSV处理](docs/lite_comparison_fix.md) · [方法差异和种子波动](docs/lite_comparison_results.md) · [发布说明](docs/release_notes_v0.5.0.md)。

## 3. 哪些能区分

180行summary、4行comparability、204行effect_sizes、540行pareto，以及60项status/provenance全部齐备；两个模式分别报告。只有rankable上的几何非支配点才是候选，没有总分或全局排名。

lite主窗姿态、偏航、角速度和位置的方法差异小于池化种子波动；共同预测力矩残差的极差/池化比值M0/M2b约29.837/29.582，PWM步变约80.494/80.029，按既定规则可报告整组效应。饱和全零，比值NaN。动态方法名义残差更低、PWM活动更高；接近数值底限的预测残差不代表真实力矩误差零。rankable不是五方法两两可区分，不宣称显著性、实机优势或全局最优。

ideal主窗结论与v0.4相同：姿态、偏航、共同预测力矩、PWM活动可按规则区分，角速度仅M0、位置仅M2b超过种子波动；仍只解释三种子本批次效应。[当前统一报告](examples/lite_comparison_v050/comparison_3seeds/report.md)保留所有窗口、方法均值/标准差和九种二维轴。

## 4. 验证与已知失败

- test_allocation_comparability：CSV空error_id/error_message、显式NaN错误列、CacheMismatch/TopicAudit、空status拒绝，以及原边界/单个NaN/缺失种子/位置非门槛均通过。
- test_lite_comparison_rankable：完整三种子30条轨迹、固定负载/窗口、全部门禁和当前引擎身份通过；完整来源及轻量CSV均已检查。
- test_allocation_comparison：两秒40项、真实共同输入/噪声区别、独立重复、缓存、故障继续、fail_fast、列契约和隔离通过。
- run_project_tests(false) 14/14；run_platform_tests 6/6；test_platform_baseline六组完整非耗时SHA与PWM逐位一致，最大差0。
- ideal正式30/30新鲜运行且rankable，与v0.4完整非耗时日志逐条一致；统一60次产品与模式源结果的非耗时数值一致，lite十四个主窗主指标另由Python独立核算。
- run_estimator_tests仍只在shc09:LitePhysicalBias预期失败，约0.061°/s >0.05°/s；门限未放宽，其他前序估计器检查通过。lite继续experimental、默认ideal，不能据比较资格通过宣布完整估计器已验收。

本轮预检、ideal及产品MATLAB批次正常退出0。回归断言和验证文件全部写完后，MATLAB退出挂起；闲置约7分钟且CPU近乎不动后，只清理本次工作进程。清理后退出码1明确保留，未冒充正常退出0，未因此修改测试或数值门禁。[退出记录](docs/lite_comparison_validation/csv_resume/regression/shutdown.json)。

[发布总核验](docs/release_validation/v0.5.0/release_checks.json)包含源码SHA、数值引擎、结果计数、阈值快照和上述实际进程退出情况；[本轮回归断言](docs/lite_comparison_validation/csv_resume/regression/checks.json)、[CSV预检](docs/lite_comparison_validation/csv_resume/preflight.json)、[ideal逐位对照](docs/lite_comparison_validation/ideal/v040_vs_v050_exact.csv)、[产品核验](docs/lite_comparison_validation/products/checks.json)均保留。旧WIP失败/退出记录只作历史证据，不改写成当前通过。

## 5. 关键路径与复现

|内容|路径|
|---|---|
|lite完整30次|results/allocation_comparison_allocation_comparison_lite_rankable/|
|本次ideal完整30次|results/allocation_comparison_allocation_comparison_ideal_v050/|
|统一60次|results/allocation_comparison_v050_comparison_3seeds/|
|当前轻量证据|examples/lite_comparison_v050/comparison_3seeds/，另有lite_3seeds/ideal_3seeds/|
|前后峰值及邻域|examples/lite_comparison_v050/diagnosis/、diagnosis_after/|
|数值缓存|results/allocation_comparison_cache/|
|本轮运行日志|archive_v050_resume_preflight.log、archive_v050_resume_ideal.log、archive_v050_resume_regression.log、archive_v050_resume_products.log|
|v0.4完整60次|results/allocation_comparison_allocation_comparison_research_resume/|
|v0.4原35/60快照|results/allocation_comparison_research_3seeds/|

数值引擎26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286。本轮CSV修复不改变引擎，lite直接复用原30次；引擎不同于v0.4，故ideal全新重跑，不跨旧指纹混用缓存。lite原门禁源快照哈希保留，ideal/统一输出采用CSV修复后的源摘要；逐项数值阈值一致，源哈希不同不是放宽门槛。main合并后源码与已验收SHA逐字节核验相同。

```matlab
ca_setup;
s = allocation_comparison_app;
```

默认仍仅M0/M2b、ideal/lite、五方法、seeds1:3；无缓存时60次20秒，已有当前指纹缓存只补缺项。每次使用新output_tag、不覆盖旧目录。完整MAT/cache/archive不入Git，轻量CSV与入口可供克隆后冷启动复现。原35/60快照未改写，所有旧结果保留。

## 6. 边界与下一步

本轮完成后停止，下一步等待用户新指令，不继续开功能。M4没有复跑，v0.4扫描仅是历史证据，默认继续排除M4，不从M0/M2b改善推断M4已通过。真实/名义tau和速率仍匹配，gyro/compute delay=0，无实机标定；ECL旧版，本轮未做ECL交叉研究。

不改物理、气动、五算法、共享控制器、ideal估计器、旧协议或5°/10%/2°/气动越界/物理偏置0.05°/s门限；不真值兜底。不跑M4全量、完整失配阶梯、E1/E2全量；不做执行器/参数不确定性、可视化、lite v2或HIL。不reset/clean、删除旧证据、重clone覆盖或force push；不推送非发布分支。禁止读写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。

每次结束、暂停或失败均更新HANDOFF并单独文档提交；本文件按用户要求与main/tag发布，最终远端SHA以实时核验为准。
