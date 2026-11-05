# 研究工作流与历史路线

本页帮助选择正确入口和证据，不是新增运行授权。当前状态只看[HANDOFF](../../HANDOFF.md)，运行环境见[快速开始](getting_started.md)。

## 先选研究路径

1. 确认问题属于平台控制链还是四环研究链，阅读[架构](architecture.md)。
2. 找到实际入口、协议、采样/评价窗口、种子与方法，再检查来源锁和已存结果。
3. 区分开发筛选、正式确认、短诊断和只读复算；先用已有证据回答，不能把开发结果当独立确认。
4. 如获准新运行，使用新协议/版本与唯一输出，冻结输入和来源；保留所有失败、管理异常及续跑范围。
5. 分别报告运行完成、数据/数值有效、科研验收与保留价值，原判据不随结果改变。

## 命令规模与执行边界

| 入口 | 源码定义的范围 | 阅读/执行注意 |
|---|---|---|
| ca_setup | 初始化MATLAB路径 | 不推进对象 |
| hover_app("PCA_PREDICTIVE") | 单方法2秒悬停 | 默认不落盘，不代表正式验证 |
| main("DCA") | 默认单方法30秒平台任务 | 默认配置会保存结果/图，与hover短例不同 |
| main_comparison | 默认五方法、各30秒 | 不是只运行一个短例 |
| mismatch_app | 默认M0/M2b配对2秒 | 会运行一组对照，不扩展成正式阶梯 |
| allocation_comparison_app / m4_load_sweep_app | 比较/筛选驱动 | 多工况、多方法和种子，调用前读配置，不当作安装检查 |
| run_ppid_pindi('pilot',...) | 原协议开发入口，52秒单方法任务 | 使用开发种子，不是两秒烟雾 |
| run_ppid_pindi('formal',...) | 原协议五方法×三正式种子、各52秒 | 受历史来源锁限制；当前源码不匹配时必须拒绝，不更新旧锁绕过 |
| run_hover_distance_takeoff_formal(...) | 先一条预检，再五方法×三种子、各55秒 | 旧60 s协议入口，不能用来宣称运行了GNSS v2；不重跑现存批 |
| shc09_gnss_config(seed,"f8"/"takeoff55") | 构造版本化配置、模型、参考和plan | 不运行闭环；不是新正式批驱动 |
| run_project_tests / run_platform_tests / test_platform_baseline | 多项测试/基线运行 | 可能推进对象、写results；只读文档任务不执行 |

命令参数以实际函数为准，省略号表示应先读入口签名，不是可直接复制执行的占位命令。

## 已有研究路线及证据

| 路线 | 阅读入口 | 边界 |
|---|---|---|
| 平台悬停与估计反馈比较 | [比较指南](allocation_comparison_guide.md)、[lite索引](lite/README.md) | M0/M2b/M4是舵效/失配工况，不是飞行模式；悬停门禁不用于后续F8 |
| 原平台F8与压力确认 | [F8协议](../reference/f8_protocol.md)、[F8轻量交付](../../examples/f8_comparison_20261101/README.md) | 开发筛选/确认分开，原始数据保留等级按现存清单理解 |
| 四环P–PID/P–INDI八字 | [研究说明](../../studies/ppid_pindi/README.md)、[52秒交付](../../examples/ppid_pindi_f8_20261101/README.md) | 独立控制器/传感器与宽松任务阈值，不是旧F8高精度验收 |
| 早期hover与滤波 | [原hover场景](../../studies/hover_distance/README.md)、[滤波场景](../../studies/hover_distance_filter_20261102/README.md) | 参数和停点按当时报告；不把lambda目标或恢复定义跨阶段移用 |
| 55秒起飞型与change-B | [原55秒证据](../validation/hover_distance_takeoff_formal_20261103_r1/README.md)、[change-B独立审计](../validation/shc09_b_frame_20261104/independent_audit_20261104/audit_report.md) | 两批各15/15运行完成，真实恢复0/15；不能只据估计恢复评价飞机 |
| ECL Round 1–7与GNSS v2 | [导航诊断摘要](../validation/shc09_b_frame_20261104/NAVIGATION_DIAGNOSIS_SUMMARY.md)、[1000 s回归](../validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/report.md) | 旧60 s与新1000 s分版本；诊断机制证据不等于55秒完整因果分解 |

上述研究README/报告中的旧分支名、未提交或“不push”是历史任务快照，不是当前main开发契约；原文保持不变以便追溯。

## 现行GNSS配置与历史入口

新模型入口构造配置的示例为：

```matlab
[cfg, model, ref, plan] = shc09_gnss_config(501,"takeoff55");
```

该调用选择三轴1000 s版本并校验冻结父协议，保持幅值、随机机制和延迟定义。它不启动仿真，也没有自动替换旧正式驱动使用的60 s配置。需要新批时应另立受批准的运行包装、来源锁和输出，不能把新模型结果加入旧批或重写父锁。

参数来源与边界在[传感器文档](../../studies/ppid_pindi/README.md#测量估计和任务坐标)，已知真实恢复限制在[Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)。该问题暂缓、非当前文档/Results治理阻塞；不在本阶段继续调参或追加仿真。

## 下一阶段

Results治理、原址登记及有限迁移按[Phase2B计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/main/Phase2A/PHASE2B_EXECUTION_PLAN.md)审批。原change-B后续研究可在主线继承已有来源与证据，但实验问题、方法、预算和验收需另行确定；不因历史分支已合入就视为授权扩批。
