> **最新模型与收尾状态（2026-11-04）**：已新增GNSS-GM-v2版本协议，N/E/D相关时间统一1000 s；保留旧60 s协议、锁及Round1–7。单条55秒回归44001点，550次实际水平位置融合healthy，来源对齐残差≤9.44e−16 m，原数值预检通过。真实水平RMSE0.781936 m、峰值1.629143 m、末偏移1.616451 m；局部EKF误差RMSE0.788159 m、感知跟踪RMSE0.066379 m，原真实恢复标准未通过。因此**模型修正完成，但不满足“诊断完成，待整合”条件**，停止等待审核。见[完整模型与回归报告](gnss_1000s_model_20261104/report.md)及[现行参数文档](../../history/ENGINEERING_HISTORY.md)。以下内容为Round1–7历史证据。

> **Round 7更正与交付（优先于下方Round 1–6历史结论）**：完整静置及任务期均恒定slow0的G组与零slow的B组接近，真实RMSE为0.074502/0.136847/0.084531 m。F与G的末端位置向量差为1.082477/0.908408/0.250614 m，主要反映初始化历史与随后状态收敛的闭环影响，不能以F−B标量RMSE差认定固定偏置的独立物理贡献。GNSS统计已按实际来源索引校正；历史55秒slow变化机制判断不变，未重跑55秒、未实施修复。详见[Round 7报告](round7_fixed_bias_init_20261104/report.md)。下方是本轮启动前历史记录，7669566为启动基准；本轮交付SHA由git查询。

# SHC09 change-B / PX4-ECL 导航诊断当前状态

更新时间：2026-11-04（Asia/Shanghai）

本文是导航诊断的当前入口摘要。详细证据在各轮目录；本页不替代正式协议、锁或历史报告。

## 1. 当前 Git 状态

| 项 | 值 |
|---|---|
| 工作树 | `E:/Ducted-Fan-SHC09-matlab` |
| 当前分支 | `debug-ecl-position` |
| 当前 HEAD | 本轮启动基准 `b1cf139b40992f9b7420a21b996b6d00d09a4013`；本地交付提交以git查询 |
| 远端同名分支 | `origin/debug-ecl-position`保留本轮启动b1cf139；本轮未自动推送 |
| 诊断基线 | `change-B` = `661a128f1bfeaa6484f1dca3f9dbc489bb1195bc` |
| `change-B` / `origin/change-B` | `661a128f1bfeaa6484f1dca3f9dbc489bb1195bc` |
| `main` / `origin/main` | `9918d9dba180f38a62c36f602e37993b87d0d38d`（未推进） |
| 合并状态 | 诊断分支**未合并**到 `change-B` 或 `main` |

## 2. 正式 change-B 批

目录：`results/hover_distance_takeoff_formal_changeB_20261104_r1/`

- 15/15 完成，0 运行失败，15 个 `.wtr`，全部 `data_valid`；
- 真实恢复：**0/15**；
- 估计恢复：**15/15**；
- 估计水平 RMSE 约 **0.16–0.19 m**；
- 真实水平 RMSE 约 **1.95 m**，真实最大偏移约 **6.9 m**；
- 独立审计：`docs/validation/shc09_b_frame_20261104/independent_audit_20261104/`。

关键含义：控制器认为已经恢复，但真实 NED 状态没有恢复。不能仅用“估计恢复 15/15”宣称任务通过。

## 3. 诊断链条与结论

### Round 1–2：坐标与融合链

- 真实 NED、GNSS 延迟采样、ECL bridge world NED、`navigation_origin_offset`、控制器局部估计已分开；
- ECL 局部水平位置与已接受的 GPS 观测分离；
- `navigation_origin_offset` 只去掉初始固定偏移，t=0 估计接近参考不能证明后续导航正确。

详细：[ecl_position_diagnosis_20261104](ecl_position_diagnosis_20261104/report.md)

### Round 3：GPS 融合确实执行

- `fuseHorizontalPosition()` 实际调用；
- 样本：`P≈0.2106 m²`，`R≈4.5084 m²`，`K≈0.0446`；
- 单次修正 north +0.083 m、east −0.049 m，符合 `-K·innov`；
- 12 s 累计约 north +0.920 m、east −2.452 m；
- 输出预测器与融合状态差约 0.1 m，不是主要偏差源；
- 无噪声开环误差约 0.02 m，有噪声约 2 m。

### Round 4：GNSS 模型与协方差

- 正式 PPID 使用 `ppid_noise` 的 **slow(60 s)+white(0.35 m)**；
- `ca_navigation_random` 的独立总噪声模型确实不符合协议，但正式 55 s 被 `ppid_noise` 覆盖；
- A–E 开环：B 去掉 GNSS 位置噪声后误差 0.115 m；D 去掉 IMU 噪声几乎不变；C 低报 hacc 反而更差；E 独立总噪声误差 0.665 m；
- 低 Kalman gain 是 `P/R` 比例和“相关误差被当白噪声”一致性问题，不是 `fuse()` 未执行。

### Round 5：慢变误差闭环因果

3 seeds × A/B/C，12 s，PCA_PREDICTIVE：

| 条件 | 真实水平 RMSE（均值） | 12 s 末误差（均值） |
|---|---:|---:|
| A 正式 slow+white | 1.064 m | 1.777 m |
| B 去掉 slow，只留 white | 0.095 m | 0.148 m |
| C 去掉全部 GNSS 位置噪声 | 0.061 m | 0.116 m |

- 去掉 slow 后真实 RMSE 下降 **86.8%–94.5%**，末误差下降 **89.3%–93.8%**；
- 三个 seed 一致；
- 慢变误差通过 ECL 位置估计进入控制反馈；控制器感知误差约 0.17 m，真实误差约 2.23 m。

详细：[round5_gnss_slow_20261104](round5_gnss_slow_20261104/report.md)

### Round 6：初始偏置 vs 任务期动态漂移

3 seeds × A/F，12 s；F 将任务期 slow 冻结为任务首值，白噪声不变：

| seed | A 真实 RMSE | F 真实 RMSE | B 真实 RMSE |
|---:|---:|---:|---:|
| 501 | 1.335 | 0.747 | 0.074 |
| 502 | 1.239 | 0.771 | 0.131 |
| 503 | 0.616 | 0.252 | 0.081 |

- F 仍漂移：**初始固定 GNSS slow 偏置本身就会造成显著真实偏移**；
- A−F 为任务期动态增量贡献：0.588/0.468/0.364 m RMSE；
- F−B 为初始固定偏置贡献：0.673/0.641/0.171 m RMSE；
- 两者都重要，seed 间比例不同。

历史 55 s 只读分析（同正式 change-B MAT）：

| seed | 最大真实偏移 | 时间 | ECL 误差 | 感知误差 | cos(Δslow, ECL) |
|---:|---:|---:|---:|---:|---:|
| 501 | 6.655 m | 54.06 s | 6.621 m | 0.066 m | +0.994 |
| 502 | 2.969 m | 34.53 s | 2.947 m | 0.074 m | +0.869 |
| 503 | 6.873 m | 54.68 s | 6.832 m | 0.045 m | +0.996 |

历史数据在时间、幅值、方向上与 slow 变化高度一致，但属于观察性证据，不能单独证明 55 s 反事实。

详细：[round6_gnss_bias_drift_20261104](round6_gnss_bias_drift_20261104/report.md)

## 4. Round 1–6历史判断（Round 7及本次模型验证已补充边界）

1. **不是 GPS 融合没有执行**；融合和输出传播均已验证。
2. **主要机制是 GNSS 慢变位置误差进入 ECL 位置估计，再进入控制反馈**；包括初始固定偏置和任务期动态增量。
3. **ECL 的 P/R 与相关 GNSS 误差统计不一致**是使修正偏小的关键条件；不能仅凭 `K≈0.045` 说 ECL 参数错误，也不能把低报 hacc 当修复。
4. **正式 55 s 的 6.9 m 尚未被完全因果解释**；12 s 对照和 55 s 观察性证据支持上述方向，但正式 55 s 反事实仍需新协议/锁。
5. 当前**没有实施修复**，没有修改 ECL 数值、B/J、控制器、分配器或正式参数。

## 5. 不能宣称

- 不能宣称“估计恢复 15/15”等于真实恢复；
- 不能宣称 B/C 的短时改善已经证明正式 55 s 修复；
- 不能把低报 `hacc` 得到的改善称为正确修复；
- 不能把 `ca_navigation_random` 的独立白噪声模型当作正式 55 s 实际噪声；
- 不能把 12 s 结论直接外推到 55 s 的 6.9 m 最大值；
- 不能把诊断分支的日志/接口改动当成正式 ECL 算法变更。

## 6. 证据索引

```text
docs/validation/shc09_b_frame_20261104/
├── independent_audit_20261104/
├── ecl_position_diagnosis_20261104/      # Round 1-4
├── round5_gnss_slow_20261104/            # A/B/C
└── round6_gnss_bias_drift_20261104/      # A/F + 历史 55 s

results/hover_distance_takeoff_formal_changeB_20261104_r1/
results/round5_changeB_20261104/
results/round6_changeB_20261104/
results/audit_changeB_20261104/
```

## 7. 下一步

1. 审核 Round 5/6 结论及诊断分支；
2. 若要修复，先提出**最小、可回退**的 ECL/配置方案，并明确它改变的是哪一层；
3. 若要验证正式 55 s 反事实，必须另立协议、另立输出目录和锁，不覆盖现有 15/15 正式结果；
4. 不自动合并 `main`、不自动运行 55 s、不自动改正式参数。
