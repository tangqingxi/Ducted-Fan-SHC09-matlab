# v0.3.0 收尾说明

2026-10-31。v0.2.0固化平台、五插件、估计器诊断、估计反馈比较MVP和仓库治理；v0.3.0增加E3结构失配证据。完成本次发布后暂停工具开发，不再开启新长任务。

## 已达成

PX4式职责分层、五种冻结分配器插件、估计器真实化/Stage6A诊断与独立ECL交叉验证、估计反馈比较MVP、E3分窗/Pareto和保守文件治理均已归档。E3正式30/30全新运行，未重跑完整六工况阶梯，未更改物理、控制器、五算法、旧协议或估计器门槛。

M0/M2b主窗姿态细微差别在本次单种子下不可排名，实际模型误差及分配/控制代价仍有信息；M4/lite未完整保持ideal的两组收敛图景，出现高饱和与大姿态退化。残差、PWM活动、饱和和跟踪之间有不同二维权衡，没有全局最优或统计显著性/实机结论。见 [E3报告](e3_estimated_structural_mismatch.md) 与 [轻量证据](../examples/e3_estimated_mismatch/README.md)。

## 尚未做

- lite v2，或将lite/ECL提升为默认。
- 执行器二阶、死区、额外传输延迟及参数不确定性研究。
- 台架/悬停实机标定、完整多种子统计与HIL。

这些事项不纳入本版本继续开发；需要以后另定版本和范围。

## 已知限制

lite物理闭环偏置约0.0610°/s，仍未通过0.05°/s门禁；默认ideal仅为oracle及回归基准，lite仍experimental。ECL为旧版归档核心，本轮E3未运行可选ECL。真实/名义tau均30ms匹配；无实机标定，E3仅单组配对种子。M4/lite的大幅摆动说明本基准的门禁通过不等于控制质量验收。

local results/archive/build不入Git，全部历史/新研究结果保留本地，本轮未清理。Git只携带源码、冻结基线、文档及轻量证据；旧报告结论没有改写。

## 发布验证

main由E3分支fast-forward到 `aa373e5598d8e06a627f877de020db12098d6b40` 后完成最终运行回归：旧14/14、平台6/6、六组完整非耗时SHA与PWM冻结基线、MVP及E3通过，MATLAB退出码0；估计器仅按预期在 `shc09:LitePhysicalBias` 失败。E3测试独立重跑两秒M0/M2b的ideal/lite，核对完整非耗时日志、汇总、Pareto、共同输入、topic隔离与图表。后续提交仅更新版本说明、验证记录与文件清单，不修改运行逻辑。

[v0.2.0验证](release_validation/v0.2.0/release_checks.json) · [E3阶段验证](release_validation/e3/e3_checks.json) · [v0.3.0发布验证](release_validation/v0.3.0/release_checks.json) · [CHANGELOG](../CHANGELOG.md)。tag与远端SHA在推送后单独核验，不仅凭本说明判断推送成功。
