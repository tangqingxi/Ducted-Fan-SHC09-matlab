# v0.4.0：comparison-ready

2026-10-31（Asia/Shanghai）。本版本交付标准比较入口、预定义可比性门禁、跨种子效应量和二维Pareto；发布后停止本轮开发。

## 完成范围

`ca_setup; s=allocation_comparison_app;` 默认根据版本化M4选择运行M0/M2b、ideal/lite、五方法、seeds 1:3。支持子集、缓存、断点补跑、失败继续及完整失败/未运行记录。输出summary、comparability、effect_sizes、pareto、status、provenance和报告，不给综合排名。

M4扫描30/30完成：lite在0.4/0.5的姿态峰值5.538°/5.685°已超5°；0.6达到96.13%饱和、59.32°姿态峰值及6.665°估计RMS。因此没有选出可比M4负载，按预定义退路仅以M0/M2b作三种子主比较，没有调整tanh、协议或门槛。

主比较60/60完成，0失败、0未运行。本次仅补25次（M2b/ideal seeds2–3及M2b/lite seeds1–3），原35份日志复用，原105行指标不变。完整输出180行summary、4行comparability、204行effect_sizes、540行pareto。M0/M2b的ideal均rankable；lite均因姿态峰值5.470°/5.486°为stress。

ideal主窗的姿态、偏航、共同力矩和PWM步变差异均超过本批种子波动；角速度仅M0过规则，位置仅M2b过规则，饱和零方差比值NaN。绝对偏航误差约0.001°，效应量不代表实际飞行收益。共同残差下降与更高PWM活动形成权衡，候选集取决于两轴，无单一最优；stress不会生成排名候选。

## 验证

运行代码在 `cb9c59bbcf569f83f10a136777c319f0e4a8e7e8` 上验证，本轮没有修改apps/analysis/tests或数值引擎。v0.4门禁与比较测试、旧14/14、平台6/6、六组冻结基线、MVP、E3均通过，MATLAB退出码0。`run_estimator_tests`仍仅按预期在 `shc09:LitePhysicalBias` 失败。

默认入口重放60项且产品与显式恢复相同；M4压力入口重放10项、lite仍不排名，新增研究仿真0次。扫描按最终门禁重算完全一致；14个主指标效应量经独立计算核对。原暂停目录保留，完整主结果位于本地 `results/allocation_comparison_allocation_comparison_research_resume`。

[发布验证](release_validation/v0.4.0/release_checks.json) · [指南与五个读者问题的证据](allocation_comparison_guide.md) · [完整轻量报告](../examples/allocation_comparison/main_3seeds/report.md)。tag和远端SHA在推送后单独核验，不能只凭本说明判断推送成功。

## 边界与未做

lite仍experimental、默认ideal，偏置约0.061°/s仍高于0.05°/s门槛。M4负载扫描仅单种子，主比较仅三种子；不作p值、显著性、实机优势或全局排名。真实/名义tau均30ms，速率限制600°/s匹配；gyro/compute delay为0，求解耗时只记录。ECL为归档旧版，本轮未运行ECL E3。

本轮未做可视化、执行器二阶/死区/延迟真实化、lite v2、参数不确定性、台架/悬停标定、完整多种子统计或HIL。物理、控制器、五算法、旧协议及估计器增益/偏置门槛均未改。结果/cache/build/archive不入Git，不清理或删除旧证据；发布后不再扩展本轮范围。
