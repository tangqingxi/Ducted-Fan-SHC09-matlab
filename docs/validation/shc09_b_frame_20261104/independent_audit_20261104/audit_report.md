# SHC09 change-B 正式结果独立补充审计

- 审计对象：`change-B`，正式基准 `f788076ea05d85c62cbeecdf8ba5bef165c3c84d`
- 审计方式：只读加载已有正式 MAT / metrics / status / `.wtr`，不运行新的 55 秒仿真
- 原始指标：未覆盖
- 审计输出：本目录 CSV / PNG；新增“对齐后”解释只作为补充，不改原始 `metrics.csv`

## 0. 先给结论

1. 新批 **15/15 完成，0 失败，15 个 WTR 导出，所有 `data_valid=1`**；起飞预检通过。
2. **估计状态恢复 15/15 成功，真实状态恢复 0/15 成功**，旧正式批也是真实 0/15、估计 15/15。
3. 真实/估计差异的主要证据不是“比较时用了两个不同原点”，而是：`navigation_origin_offset` 在 t=0 去掉了一个 **1.66–3.82 m 的初始 ECL 偏移** 后，ECL 的局部位置估计仍长期贴近参考/零，而真实 NED 位置持续漂移到 1.5–6.9 m。控制器跟踪的是这个局部估计，真实机体则偏离参考。
4. 五种算法都出现过大于 2.5 ms 的求解调用；**DCA seed501 的 67.4925 ms 发生在 t=0 第一次控制调用**，不是 15–27 s 主窗的算法稳态。主窗 DCA 最大 1.7275 ms、0 次超 2.5 ms。
5. 仿真未把 `solve_time_s` 接入 PWM 调度/预测时域，因此**不模拟计算超时造成的控制延迟**。不能把“仿真完成”解释为“实时性通过”。
6. 旧报告中“DCA 最大 4.42 ms”是主窗统计口径，不是全局最大值；全局最大值是 67.4925 ms。该处口径已纠正。

---

## 1. 任务一：真实状态与估计状态恢复差异

### 1.1 `navigation_origin_offset` 定义

`research/ppid_pindi/ppid_simulate.m:7`：

```matlab
navigation_origin_offset=nav.estimate.position-ref.position_ned_m(1,:)';
```

控制反馈使用局部位置（`:36`）：

```matlab
fb=struct('position',estimate.position-navigation_origin_offset, ...)
```

日志保存（`:48-49`）：

```matlab
L.raw_navigation_position(k,:)=estimate.position';
L.estimated_position(k,:)=(estimate.position-navigation_origin_offset)';
```

所以：

```text
raw_navigation_position = ECL 原始 NED 位置（其自身原点）
estimated_position      = raw - (raw(0) - ref(0))
                        = 以任务起点为原点的控制用局部位置
true position           = state.position（NED 真值）
reference               = ref.position_ned_m（NED）
```

`hdtf_metrics.m:69-70` 对 `estimated` 和 `true` 使用同一个误差定义：

```matlab
error=pos-ref.position_ned_m; distance=vecnorm(error(:,1:2),2,2)
```

`hdtf_metrics.m:79-85` 的恢复判据也相同，只是 `pos` 分别取 `L.estimated_position` 和 `L.position`。

### 1.2 每个种子的初始偏移

新批 15 条按 seed 分组，同一 seed 在不同分配器下偏移相同：

| seed | offset_x / m | offset_y / m | offset_z / m | 水平模长 / m |
|---:|---:|---:|---:|---:|
| 501 | −2.103127 | +3.187778 | −0.500772 | 3.819 |
| 502 | +1.134819 | −1.500724 | −4.247643 | 1.882 |
| 503 | −1.561669 | −0.566906 | −2.278187 | 1.661 |

完整逐方法表见 `navigation_origin_offsets.csv`。  
旧批同 seed 的偏移略不同（例如 501 为 `[-2.1018, 3.1941, -0.5008]`），但恢复结论相同。

### 1.3 关键时刻的真实/估计/原始误差

新批在所有 15 条上的范围（水平模长，m）：

| t / s | true 误差 | estimated 局部误差 | raw ECL 误差 |
|---:|---:|---:|---:|
| 0 | 0 | 0.001–0.003 | 1.66–3.82 |
| 12 | 1.465–2.232 | 0.019–0.173 | 1.756–3.701 |
| 15 | 1.158–2.750 | 0.095–0.219 | 1.519–3.782 |
| 27 | 2.123–3.484 | 0.066–0.321 | 1.354–3.815 |
| 37 | 2.705–5.294 | 0.096–0.303 | 1.641–3.723 |
| 55 | 1.535–6.866 | 0.079–0.226 | 1.717–3.977 |

单条代表（PCA_PREDICTIVE seed501）：

| t / s | true NED 水平误差 | estimated 局部水平误差 | raw ECL 水平误差 |
|---:|---:|---:|---:|
| 0 | 0 | 0.003 | 3.816 |
| 12 | 2.232 | 0.173 | 3.701 |
| 15 | 2.750 | 0.095 | 3.781 |
| 27 | 2.357 | 0.068 | 3.804 |
| 37 | 3.656 | 0.102 | 3.717 |
| 55 | 6.583 | 0.158 | 3.975 |

完整表见 `position_error_samples.csv`。

### 1.4 恢复判据复核

按原 `hdtf_metrics` 的 recovery 判据（位置 0.20 m、速度 0.20 m/s、roll 2°、保持 0.5 s）独立重算：

| 批次 | 真实恢复失败 | 估计恢复失败 |
|---|---:|---:|
| 新 change-B（15 条） | **15/15** | **0/15** |
| 旧 hover_distance（15 条） | **15/15** | **0/15** |

完整表见 `recovery_recheck.csv`。

补充：正式 `metrics.csv` 的水平 RMSE 均值：

| 方法 | estimated 水平 RMSE / m | true 水平 RMSE / m |
|---|---:|---:|
| WLS | 0.1942 | 1.9524 |
| DA_NS | 0.1841 | 1.9536 |
| PCA_STATIC | 0.1750 | 1.9543 |
| PCA_PREDICTIVE | 0.1595 | 1.9589 |
| DCA | 0.1587 | 1.9598 |

旧批对应 estimated 约 0.168–0.204 m、true 约 1.944–1.950 m；新旧均表现为估计误差小、真实误差大。

### 1.5 根因判断

有证据支持的部分：

- `navigation_origin_offset` 是**有意为之的局部原点对齐**，不是随意错误；它使估计局部位置在 t=0 回到参考起点（估计误差约 0.001–0.003 m）。
- 但偏移消除后，`estimated_position` 仍长期贴近 0/参考（0.02–0.32 m），而真实 NED 位置持续漂移（12 s 已 1.5–2.2 m，55 s 可达 6.9 m）。
- 因此，**不是单纯的原点定义问题，也不是简单的 b/FRD 坐标变换问题**。固定坐标变换会产生一个常量偏移，而这里 ECL 原始位置大致停在其自身原点附近（raw 水平误差 1.66–3.98 m，变化很小），真实机体却远离参考。
- 控制器输入是 `estimated_position`（局部），控制器据此保持“位置为零”；真实状态偏离，说明 ECL 的局部位置估计没有反映真实 NED 位移，控制闭环跟踪的是估计轨迹而不是真实轨迹。
- 旧批同样真实 0/15、估计 15/15，说明该现象不是本次 b 系/J 修改引入的。

尚不能由现有日志证明的部分：

- 偏移在 seed 之间变化很大（1.66–3.82 m），说明 ECL 的初始位置本身依赖 seed/滤波器初始化；但仅凭日志不能区分是 ECL 原点策略、GNSS/惯导融合偏差、姿态/速度投影还是桥接帧设置。
- 需要 ECL 内部 origin/融合状态或对照仿真才能定量归因；本篇只报告可复现证据，不把“原点偏移”单独当作全部根因。

### 1.6 为什么“估计恢复成功”不能等同于“真实恢复成功”

- `estimated_recovery` 是控制器看到的局部估计是否回到参考；
- `true_recovery` 是真实 NED 状态是否回到参考；
- 两者在 t=0 同一原点，但在本批中 ECL 局部位置与真实 NED 明显分离；
- 因此 15/15 估计恢复只说明**控制器内部闭环看起来成立**，不说明真实机体恢复。正式验收必须同时看真实指标。

---

## 2. 任务二：控制分配计算时间

### 2.1 统计口径

- 数据：`L.solve_time_s`，只在 `L.control_updated=true` 的 400 Hz 控制调用上统计；
- 每方法 3 个 seed，共 66,003 次调用；
- 2.5 ms 对应 400 Hz 周期；
- 启动 `<15 s`，主窗 `15–27 s`，后段 `≥27 s`。

完整逐 seed 表：`solve_time_stats.csv`；合并表：`solve_time_pooled.csv`。

### 2.2 合并统计

| 方法 | 平均 / ms | P50 | P95 | P99 | P99.9 | 最大 | >2.5 ms 次数 | 比例 | 最大时刻 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| DA_NS | 1.654 | 1.612 | 1.955 | 2.271 | 2.893 | 36.5546 | 246 | 0.373% | 0 s |
| WLS | 0.348 | 0.338 | 0.425 | 0.531 | 0.705 | 32.3760 | 5 | 0.0076% | 0 s |
| DCA | 0.964 | 0.936 | 1.155 | 1.340 | 1.657 | **67.4925** | 12 | 0.018% | 0 s |
| PCA_STATIC | 0.568 | 0.550 | 0.702 | 0.840 | 1.115 | 18.5934 | 5 | 0.0076% | 0 s |
| PCA_PREDICTIVE | 0.946 | 0.911 | 1.115 | 1.349 | 5.311 | 22.1403 | 205 | 0.311% | 15.27 s |

主窗（15–27 s）：

| 方法 | 主窗平均 / ms | 主窗最大 / ms | 主窗 >2.5 ms 次数 |
|---|---:|---:|---:|
| DA_NS | 1.665 | 12.1435 | 73 |
| WLS | 0.355 | 10.3441 | 1 |
| DCA | 0.966 | 1.9088 | **0** |
| PCA_STATIC | 0.564 | 1.6172 | **0** |
| PCA_PREDICTIVE | 0.987 | 22.1403 | 197 |

启动段（<15 s）最大：DA_NS 36.5546、WLS 32.3760、DCA 67.4925、PCA_STATIC 18.5934、PCA_PRED 12.5973 ms。

### 2.3 DCA seed501 的 67.4925 ms

`dca_s501_peak_context.csv`：

```text
time_s     solve_ms   control_index
0          67.4925    1
0.0025      4.9086    2
0.005       3.7916    3
0.0075      3.3016    4
0.01       23.2802    5
0.0125      2.2166    6
```

该峰值发生在 **t=0 的第一次控制调用**。同一 seed 的主窗最大为 1.7275 ms，主窗 >2.5 ms 次数为 0。  
因此有证据把 67.4925 ms 归为**首次调用/优化器初始化/运行时抖动**，不能归为 15–27 s 主窗的稳态算法计算。日志没有内部计时，无法把首次调用的各组成部分精确拆分。

### 2.4 是否进入 PWM 调度或预测时域

`ppid_simulate.m:42-46`：

```matlab
timing=ca_pwm_timing(t,allocator_cfg,held); timer=tic;
[pending,info]=ca_allocate(...);
solve=toc(timer);
...
if abs(scheduler.next_pwm_time()-t)<1e-10,latch(t);end
```

- `solve_time_s` 只做日志；
- `ca_pwm_timing` 在分配之前按仿真时间调用，不使用 `solve`；
- `latch` 按 `scheduler.next_pwm_time()` 和 `t` 对齐，不把计算耗时加入保持时间/预测时域；
- 因此**当前仿真未模拟计算超时造成的控制延迟**；实时性不能由仿真完成状态证明。

### 2.5 对上一份报告的口径修正

上一份正式报告写 DCA“最大 4.42 ms”，那是主窗/某单次统计口径，不是全局最大。  
全局最大是 **67.4925 ms（seed501，t=0 首次调用）**；主窗最大是 **1.9088 ms**（三 seed 合并），seed501 主窗为 1.7275 ms。两者必须分开报告。

---

## 3. 任务三：报告口径修正

必须分开以下状态：

| 口径 | 本批结果 |
|---|---|
| 正式仿真完成 | **15/15 completed，0 failed，15 WTR** |
| 数据有效、未发散 | **全部 data_valid=1；aero_domain_failures=0；finite_states=1** |
| 起飞预检通过 | **通过**（altitude12≈9.93996 m，settle_vz≈0.01082 m/s，lambda_duty≈0.13479，lambda_min≈0.16411） |
| 估计状态恢复成功 | **15/15 成功** |
| 真实状态恢复成功 | **0/15 成功** |
| 控制分配实时性 | **未证明**；五种算法均有 >2.5 ms 调用；DCA 主窗 0 次，PCA_PRED 主窗 197 次；仿真未建模超时延迟 |

保留的实际结果：

- DCA 在三个 seed 的滚转跟踪（1.2936° vs 其余 1.35–2.95°）和 yaw rate（2.8932°/s vs 2.89–27.89°/s）上较优；
- 但 DCA 的 67.4925 ms 首次调用和主窗 1.9088 ms 最大值不满足“所有实时性门槛”；
- 不能宣称“全部性能门槛通过”，也不能用估计恢复替代真实恢复。

---

## 4. 审计文件

```text
docs/validation/shc09_b_frame_20261104/independent_audit_20261104/
├── audit_report.md
├── navigation_origin_offsets.csv
├── position_error_samples.csv
├── recovery_recheck.csv
├── solve_time_stats.csv
├── solve_time_pooled.csv
├── dca_s501_peak_context.csv
├── error_curve_downsampled.csv
├── formal_metrics.csv
├── formal_allocation_summary.csv
├── error_curves_pca_s501.png
├── navigation_origin_offsets.png
└── solve_time_stats.png
```

原始正式结果目录、锁、MAT、WTR、metrics 均未修改。

---

## 5. 残余风险

1. ECL 局部位置与真实 NED 分离的**内部根因**尚未定位到具体 ECL origin/融合环节；当前只证明不是单纯的比较原点/固定坐标变换问题。
2. `solve_time_s` 只测 `ca_allocate` 外层 `tic/toc`，无法拆分首次调用的 MATLAB/优化器初始化占比。
3. 仿真没有计算超时延迟模型；实时性只能做调用耗时统计，不能从闭环结果推断。
4. 旧/新对比同时包含 J 修正和 b 系参考转换，不能把差异单独归因于 J。
5. Viewer 截图来自源码运行，不是重新打包后的安装包；安装包实时性/标签验收仍需单独重建。
