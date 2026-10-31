# 平台可用：比较分配器

## v0.5.0当前结果：估计反馈可比较

M0/M2b×ideal/lite×五方法×seeds1:3共60/60完成，四组均rankable。lite主窗峰值由5.4697°/5.4861°降至3.7749°/3.7817°，饱和均0%、估计姿态RMS≤1.316°、气动越界0。修复只平滑lite GNSS观测修正，不放宽任何门禁；CSV空错误列的读回问题已修复，CacheMismatch/TopicAudit仍判invalid。

ideal30次全新运行，完整非耗时日志与v0.4逐条一致。lite跟踪/位置的方法均值差小于种子波动，共同预测力矩及PWM活动超过既定效应量规则；rankable不是五方法两两可区分或显著性。M4本轮未复跑，默认仍排除；下方M4和旧主比较为v0.4历史证据。

[当前完整报告](../examples/lite_comparison_v050/comparison_3seeds/report.md) · [lite差异与波动](lite_comparison_results.md) · [修复说明](lite_comparison_fix.md) · [v0.5验证](release_validation/v0.5.0/release_checks.json)。lite仍experimental，默认ideal，物理偏置0.05°/s门禁仍预期失败。

## 扫描前固定的门禁

v0.4引入比较能力时不改数值模型、控制器、五分配算法、旧协议或估计器增益/偏置门禁。门禁于2026-10-31、M4负载扫描开始前写入本文及 allocation_comparability：每 case/mode 五方法及全部请求种子完成；主窗每一条轨迹的饱和率≤10%、最大真实姿态误差≤5°、气动越界=0；lite每条轨迹的估计姿态RMS≤2°。跨方法和种子取最坏值，不用平均值放宽。最大位置误差仅报告，不增加位置阈值。姿态峰值使用原日志rotation_error_rad对应的旋转角误差主窗最大值，不是RMSE或单个欧拉轴；位置峰值为NED误差向量范数的最大值。

这些是预定义的比较资格门槛：限制严重约束和大角退化、保留近悬停比较区间，不是飞行安全认证、稳定性或统计显著性。通过标rankable；数值退化或五方法/种子不足标stress，不排名；气动域、数据非有限或缓存/真值隔离审计失败标invalid。普通失败保留stress及未完成数量，气动域失败明确invalid；均不造数。两秒烟雾不替代正式20秒，始终不排名。

固定20秒load_hold、2秒加载/16秒卸载/0.5秒过渡，whole/task/transient=[0,20]/[6,16]/[0,6]。M0/M2b负载0.6；M4固定tanh/28°，先扫描0.4/0.5/0.6、ideal/lite、五方法、seed=1共30次。最低0.4仍失败则明确无可比M4，主比较仅M0/M2b；否则选两模式均通过的最高负载，三种子主比较还要再过同一门禁。0.6保留压力参考，case/mode资格分别报告；不能将其lite压力结果包装成排名。扫描仅评价门禁，不看方法排名。

```matlab
ca_setup;
sweep = m4_load_sweep_app;
```

## v0.4历史M4扫描决定（v0.5未复跑）

30/30全新运行完成，六个负载/模式组均五方法完成，无失败或气动越界。lite在三个负载下均未通过，故v0.4的lite下没有可比M4负载；v0.4主比较只用M0/M2b 0.6、ideal/lite、各三个种子，共60次。它是预定义退路，不是因耗时削减种子或挑选通过的方法。

|负载|模式|主窗饱和最大%|姿态峰值°|位置峰值m|估计姿态RMS°|门禁|
|---|---|---:|---:|---:|---:|---|
|0.4|ideal|0|0.00467399|8.28376e-05|0|rankable|
|0.4|lite|0.780546|5.5376|0.469967|1.40396|stress|
|0.5|ideal|0|0.00576764|8.51131e-05|0|rankable|
|0.5|lite|2.55179|5.68469|0.469559|1.40786|stress|
|0.6|ideal|0|0.913732|0.00113344|0|rankable|
|0.6|lite|96.1273|59.3215|4.3615|6.66541|stress|

40%/50%的lite主要是约5.5°的峰值超限，不能直接称为失稳；60%则出现96.13%最坏饱和、59.32°姿态峰值及6.665°估计RMS，是明显压力演示。ideal三个负载单种子均过物理门禁，但扫描只评价资格，没有方法排名或跨种子结论。门禁没有临时改成姿态RMS，也未放宽5°阈值。

[扫描可比性](../examples/allocation_comparison/m4_load_sweep/comparability.csv) · [扫描报告](../examples/allocation_comparison/m4_load_sweep/report.md) · [扫描前门禁记录](../examples/allocation_comparison/m4_load_sweep/predefined_gates.json) · [已版本化比较选择](../configs/comparison/m4_selection.json)。选择文件只决定研究工况，不改物理/控制/估计预设；克隆仓库后无需本地扫描日志即可运行默认命令。可重新扫描核验，结果仍写新目录。

三种子主比较60/60已完成，详细资格和效应量见下节。默认ideal，lite仍experimental，偏置门禁仍失败；真实/名义tau匹配，无实机标定。本轮不增加MAT→Rerun、执行器真实化或lite v2。

## v0.4历史主比较结果（60/60完成）

本次在新目录 `results/allocation_comparison_allocation_comparison_research_resume` 完成60/60：复用原35份日志，仅新运行缺少的25次，0失败、0未运行。原105行分窗指标逐项保持一致。每case/mode均为五方法×seeds 1:3；20秒、0.6负载与固定三个窗口不变。原35/60目录保留为暂停快照，不能据旧目录判断当前完成度。

|工况|模式|资格|主窗饱和最大%|姿态峰值°|位置峰值m|估计姿态RMS°|原因|
|---|---|---|---:|---:|---:|---:|---|
|M0|ideal|rankable|0|0.00526349|9.7767e-05|0|全部预定义门禁通过；不是统计排名|
|M0|lite|stress|2.19153|5.46969|0.469231|1.4045|主窗姿态峰值超过5度|
|M2b|ideal|rankable|0|0.00523503|0.000835175|0|全部预定义门禁通过；不是统计排名|
|M2b|lite|stress|2.01141|5.48613|0.46914|1.40651|主窗姿态峰值超过5度|

### 哪些方法差异超过种子波动

下表只列通过门禁的ideal主窗，数值为“方法均值极差/方法内池化种子标准差”；≥1标distinguishable。零池化方差保留NaN，不生成无限大效应。所有窗口、逐方法均值/标准差/样本数见完整效应量CSV。

|指标|M0比值|M0标记|M2b比值|M2b标记|
|---|---:|---|---:|---|
|姿态RMS（°）|2.09189|distinguishable|2.19237|distinguishable|
|偏航RMS（°）|1.15576|distinguishable|1.44549|distinguishable|
|角速度RMS（°/s）|1.03331|distinguishable|0.862777|not_distinguishable|
|共同预测力矩残差（Nm）|129.379|distinguishable|122.118|distinguishable|
|PWM步变RMS（°）|113.759|distinguishable|107.49|distinguishable|
|饱和（%）|NaN|not_distinguishable|NaN|not_distinguishable|
|位置RMS（m）|0.138784|not_distinguishable|5.99227|distinguishable|

M0主窗角速度比值仅1.033，刚越过规则边界；M2b角速度0.863未过，位置5.992则超过波动。绝对误差与极差同时保留：ideal主窗偏航约0.001°，不能仅凭比值把微小数值差异提升为实际飞行收益。上述14个主指标效应量已用独立Python计算核对。

lite的M0/M2b虽然全部配对运行完成，各自主窗姿态峰值5.470°/5.486°超过预定5°，因此均为stress，不排名。这里“stress”指未满足本次比较门禁，不能直接等同失稳；not_distinguishable在这些行表示资格被拒绝，不是断言所有方法差异都小于噪声。其原始均值、种子波动和几何非支配点仍保留。

### 代价与力矩的权衡

两个ideal主窗的静态PCA共同预测力矩误差约0.00109Nm、PWM步变约0.0402°；DCA约0.000723～0.000724Nm、步变0.625～0.680°；预测PCA名义共同残差约6×10⁻¹⁷Nm、步变约0.692°。动态方法降低名义残差的同时增加PWM活动；tau匹配使预测残差接近数值底限，不能把它当实际力矩零误差或实机优势。M2b的DCA主窗偏航均值0.001062°还略高于静态0.001033°，不存在所有指标一致改善。

“PWM步变—共同力矩”数值候选集在两个ideal主窗均为WLS、DCA、预测PCA；其他两轴的集合另见Pareto表，不形成总排名。lite所有pareto_candidate/pareto_efficient均false，统一stress_not_ranking；M4/lite扫描也不提供排名。

[完整报告](../examples/allocation_comparison/main_3seeds/report.md) · [可比性](../examples/allocation_comparison/main_3seeds/comparability.csv) · [效应量](../examples/allocation_comparison/main_3seeds/effect_sizes.csv) · [Pareto](../examples/allocation_comparison/main_3seeds/pareto.csv) · [发布验证](release_validation/v0.4.0/release_checks.json)。共180行summary、204行效应量、540行Pareto；没有综合分数。三种子仍只能描述本批次效应，不作p值、显著性、全局排名或实机结论。

默认命令的60项均命中缓存；summary排除墙钟列simulation_elapsed_s后与显式恢复逐项一致，comparability/effect_sizes/pareto完全一致；M4六成压力入口另重放10项，lite仍为stress，单种子归一化比值全部NaN，未新增研究仿真。所有新运行lite均核验真值topic缺席；复用项继承已保存的隔离审计，不声称重新拥有旧topic历史。

## 一条命令与参数

使用MATLAB R2025b、Optimization Toolbox及默认JVM；比较缓存的摘要核验需要JVM，不加-nojvm。本入口不调用ECL，也不增加外部可视化依赖。

```matlab
ca_setup; s = allocation_comparison_app;
% 可按子集补跑，五方法完整覆盖才有五方法比较资格。
s = allocation_comparison_app('cases',["M0","M2b"],'modes','lite','seeds',1:3);
% 显式的M4六成压力参考；每个模式仍分别按固定门禁评价。
stress = allocation_comparison_app('cases','M4','m4_load',0.6,'seeds',1:3);
```

默认cases=auto依据版本化扫描选择，modes=[ideal,lite]、methods为原五方法、seeds=1:3。m4_load可显式选扫描过的0.4/0.5/0.6；M0/M2b始终0.6。methods可选子集，但未覆盖五方法时不产生五方法排名资格。smoke_test=true仅两秒M0/M2b，三个窗口均[0,2]、不作正式研究结论。

use_cached=true优先复用本入口缓存；reuse_from可指定本仓库results内某次输出的logs，缺项再查缓存或新鲜运行。每项都核对完整配置/参考、数值引擎摘要（包括冻结气动表内容身份）和lite隔离审计。源错配记录invalid失败，不静默重跑伪装成功。缓存文件写入results/allocation_comparison_cache，配置/数值引擎改变则使用不同键；不改旧缓存，不提交日志。中断后使用新output_tag重启同一命令即可仅补缺项；out禁止覆盖。status/provenance逐项更新，fail_fast=false继续其余项，true把后项留作not_run。

## 输出与效应量

summary逐种子、方法、case/mode/负载/窗口保留原MVP指标，并补姿态/位置峰值。comparability每case/mode一行，跨全部请求种子取最坏值，包含完成五方法数量、失败与未运行数及原因；rankable并不是统计排名。

effect_sizes每case/mode/window/metric一行：mean_方法、std_方法、n_方法逐项保留；方法均值极差除以方法内池化种子标准差，池化按(n−1)加权。五方法均覆盖全部请求种子才计算跨方法极差/比值；单种子、缺失、零池化方差的比值NaN，不能造无限大效应。原生方法标准差可以为0，零池化方差另有标志。只有比值≥1且rankable才标distinguishable，其余not_distinguishable；stress的该标记表示资格被拒绝，不是证明所有差异都小于噪声。等于1按预定义公式通过，不是p值、置信区间或显著性。三种子只描述本组效应，不能证明普适或实机优势。

pareto沿用MVP九种最小化二维轴：PWM步变/总变差/饱和，对偏航/角速度/共同预测力矩。点为种子均值；pareto_candidate与pareto_efficient只在rankable且数值非支配时为true。stress/invalid均为false且标stress_not_ranking/invalid_not_ranking；numeric_non_dominated仅保留几何诊断。不同两轴集合不同，无单一综合分数。本任务不新增可视化，默认CSV与Markdown即可完成比较；MVP已有图中黑圈同样不是显著性。

跟踪与估计误差的度/m单位沿用MVP；PWM为等效舵角，不是脉宽微秒。common_residual及allocation demand为rad/s²，共同预测力矩经名义J换算Nm；实际力矩模型误差是另一个离线量。native residual原生目标不同，仅在summary保留诊断，不列入跨方法效应量或Pareto。lite真值仅生成测量与离线评价，不发布truth topic或反馈兜底。

## 门禁实现的边界核验

扫描前冻结的10%/5°/2°及五方法完成规则未改变。实现复核补齐逐项非有限值拒绝和每方法全部请求种子的覆盖检查；这是既有规则的防护，不按实测结果改阈值。人工测试覆盖等号边界、单个NaN、缺失一个种子和位置仅报告；正式扫描已按最终实现重新核对，六组分类及数值完全一致；原始扫描记录未覆盖。
