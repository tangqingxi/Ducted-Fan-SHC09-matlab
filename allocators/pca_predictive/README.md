# 响应预测PCA

已接入`ca_pca_predictive.m`和`ca_priority_core.m`，保留等待、完整保持周期、保守速率约束及补偿优先。lambda和beta分别记录正常跟踪与回退补偿比例。方法标识为`PCA_PREDICTIVE`。

`predictive_restore_mode="minimum_change"`为新默认：借鉴Härkegård的历史输入次级目标，在保持第一阶段预测效果和相同边界的条件下，最小化相对当前已保持命令的二范数距离。求解器为从第一阶段可行解启动的活动集法；本轮不加新的稳态偏好权重。每次恢复的退出标志、迭代数和效果误差另列日志。

`predictive_restore_mode="legacy_norm"`调用相邻`pca_static/ca_restore.m`，保留原绝对舵角范数恢复。缺少新字段的旧配置继续使用该模式；静态PCA始终采用原恢复，不随该开关变化。

参考：O. Härkegård, “Dynamic Control Allocation Using Constrained Quadratic Programming,” Journal of Guidance, Control, and Dynamics, 27(6), 1028–1034, 2004, DOI: 10.2514/1.11607。本项目将其历史命令次级目标接在自身优先级预测分配之后，并非整篇方法复现。
