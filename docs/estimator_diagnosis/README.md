# Stage 6A 诊断证据

> 文档类型：证据。

`diagnosis.csv/json` 为 D0–D6 前十秒窗口；D4 另列三十秒窗口，因严格气动域门禁失败而缺失，见 `D4_failure.json`。D4 的十秒行复用已验证相同参考/随机流前缀的 D0，不冒称延长运行完成。

`D*_trace.csv` 保存任务时刻、加计模长偏差绝对值及有符号值、物理角速度范数、创新、估计与真实偏置；真实量仅离线评价。原始数值日志位于本地忽略目录 `results/estimator_diagnosis`，不提交大型 MAT 文件。预热十五秒不计指标窗；标准 kp=2、ki=.05，位置参数不变。D5 门控阈值 .1 m/s²、10°/s，在看到结果前固定，默认关闭。

`stageN_*` 为每阶段完整十四项旧测试、六项平台测试、六组冻结基线与预期估计器物理偏置失败记录。测试失败保留，不宣称 lite 验收通过。

最终解释见 [诊断报告](../history/estimator_diagnosis_report.md)。


## 指标与交叉验证字段

`ecl.csv/json` 为最终统一交叉表，`ecl_status.csv` 记录十个设计工况的完成/失败/组内停止状态。分组运行的中间文件在统一汇总后清理，以统一表为准。现有 ECL 门禁是初始化及导航健康检查，离线精度另行报告，不能称为已验收后端。

`metrics.csv/json` 含 E1/E2 × ideal/lite × 五方法 × whole/task/transient，共六十行。角加速度需求误差为 rad/s²；乘名义惯量后的指令/共同预测力矩误差另报 Nm。相关性列分别对应姿态、位置、偏置误差与共同预测残差、held-command 活动、姿态跟踪，常量序列缺失不填零。

`metric_effects.csv` 的分母是同指标 lite−ideal 整链位移 RMS，只是代理量；`metric_seed_effects.csv` 使用原 E1 三种子的方法内池化标准差。无多种子数据或零分母保留缺失，不做显著性结论。`metrics_generation_provenance.csv` 保留初次二十次补跑，`metrics_provenance.csv` 记录最新分析读取缓存，`metrics_replay_audit.json` 记录与原 seed=1 汇总共同字段完全相同。
