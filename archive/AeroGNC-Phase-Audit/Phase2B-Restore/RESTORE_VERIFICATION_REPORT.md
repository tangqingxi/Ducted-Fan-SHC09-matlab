# Phase 2B 恢复验证报告

日期：2026-11-05（Asia/Shanghai）。
执行者：DeepSeek Agent。
恢复区：`D:\AeroGNC-Restore-Test\restore_20261105T021954`（位于备份目录 `D:\AeroGNC-Backup` **之外**，独立标识）。
运行标识：`restore_20261105T021954`。

## 1. 结论

| 项目 | 结果 |
|---|---|
| 检查项 | 11 |
| 通过 | **11** |
| 失败 | **0** |
| NOT RUN | **0** |
| 恢复并逐文件重算 SHA256 的文件 | 2,584 |
| 是否改写原始数据 | **否** |
| 是否重新生成旧数据 | **否** |

**结论：备份快照不仅字节正确，而且可被实际读取与解析；MAT 时间轴、WTR 容器、协议/锁、GNSS 指标、WindTrace 运行包均恢复到可用状态。**

## 2. 测试矩阵与结果

| 编号 | 对象 | 数量 | 方法 | 结果 |
|---|---|---:|---|---|
| G1 | 两批正式实验原 MAT | 30 | 恢复 + SHA256 + `scipy.io.loadmat` 只读加载 + 时间轴/指标断言 | **PASS 30/30** |
| G2 | 正式/预检 WTR + `short_b.wtr` | 34 | 恢复 + SHA256 + WindTrace `core.flight.read_flight` 容器解析 | **PASS 34/34** |
| G3a | 预检批（results 11 项） | 11 | 恢复 + SHA256 + JSON/MAT 解析 | **PASS 11/11** |
| G3b | 最终预检批 | 10 | 同上 | **PASS 10/10** |
| G3c | change-B 最终预检批 | 10 | 同上 | **PASS 10/10** |
| G4 | GNSS v2 回归（results + docs/validation） | 25 | 恢复 + SHA256 + CSV/JSON/MAT 解析 + 指标复读 | **PASS 25/25** |
| G5 | 17 份历史 Agent 报告 | 17 | 恢复 + SHA256 + UTF-8 解码 + 长度下限 | **PASS 17/17** |
| G6 | 两批正式批的 metrics/status/completion | 6 | 恢复 + SHA256 + 结构解析 | **PASS 2/2 批** |
| G7a | WindTrace 运行包文件 | 2,441 | 恢复 + 逐文件 SHA256 | **PASS 2,441/2,441** |
| G7b | WindTrace 隔离 smoke | 1 | 恢复后的 `WindTrace.exe --smoke <恢复的 .wtr>` | **PASS（退出码 0）** |

## 3. 关键语义检查（不是"能打开就算过"）

### 3.1 正式 MAT

对 30 份逐份断言：

- 顶层变量包含 `L`、`ref`、`metrics`、`checks`；
- `ref.time_s` 样本数 44,001，起点 0 s、终点 55 s、严格单调；
- `metrics.completed_55s == 1`；
- `metrics.true_horizontal_rmse_m` 为有限值。

### 3.2 WTR

用主仓库自带的 `apps/windtrace/core/flight.py:read_flight` 解析。该函数本身就会校验：容器成员集合恰为 `manifest.json / parameters.json / flight.mat / geometry.json`、逐成员 SHA256 与字节数、`topics` 结构、参数 schema 与数组引用完整性。34 份全部通过。

### 3.3 预检协议与来源锁

| 批次 | protocol_id | engine（前 16 位） |
|---|---|---|
| `precheck_20261103_r1` | `HOVER-DISTANCE-TAKEOFF-PRECHECK-20261103-v1` | `d4c19f329e92fb6b` |
| `final_precheck_20261103_r1` | `HOVER-DISTANCE-TAKEOFF-FORMAL-20261103-v1` | `d4c19f329e92fb6b` |
| `final_precheck_changeB_20261104_r1` | `HOVER-DISTANCE-TAKEOFF-FORMAL-20261103-v1` | `c6403c02379bb719` |

三个预检的 `source_lock.json` 均可解析且含 `engine`；两个最终预检共享同一 protocol id，但 **change-B 的 engine 与原始批不同**——这与既有审计结论一致，说明它们是不同执行来源，不能合并为同一批。

### 3.4 GNSS 回归

`navigation_metrics.csv` 中 `window=whole_0_55`、`error_type=true_tracking` 的水平 RMSE 读出为 **0.7819362505614169 m**，与 Phase 2A 记录值逐位一致；`acceptance_status` 仍为 **failed**（恢复窗最小水平误差 0.4770444895 m > 0.2 m）。恢复测试**不改变**该结论。

### 3.5 WindTrace 隔离启动

- 使用**恢复后**的 `WindTrace.exe`，不是在用安装；
- 使用**恢复后**的 `.wtr`（`final_precheck_20261103_r1/PCA_PREDICTIVE_s501.wtr`）；
- `USERPROFILE` / `HOME` / `TEMP` 全部指向恢复区内的临时目录，`QT_QPA_PLATFORM=offscreen`；
- 以 `--smoke` 运行（该模式只校验容器并输出摘要，不启动 GUI）。

输出摘要：`run_id=PCA_PREDICTIVE_s501_9bd473ea0bf56809`，`topics=18`，`parameters=469`，`duration_s=55.0`，`execution.status=completed`，退出码 0。

## 4. 明确 NOT RUN 的项目

| 项目 | 原因 | 影响 |
|---|---|---|
| MATLAB 解释执行/数值复算 | 本机无 MATLAB | 未验证 MATLAB 层面的可执行性；只验证了 MAT 容器与变量结构 |
| GUI 交互式回放（窗口、3D、曲线截图） | 无受控显示环境，且可能写入用户配置 | 未验证图形渲染与交互；`--smoke` 只覆盖数据路径 |
| 逐帧数值等价复算 | 需要重跑仿真，本轮禁止 | 恢复验证不等同于"结果可复现" |
| 33 份 WTR 的逐拍数值比对 | 同上 | 只验证容器完整性与 schema，不验证物理数值 |

这些项目**不得**在后续汇报中被表述为"已通过"。

## 5. 边界与安全

- 恢复区在 `D:\AeroGNC-Restore-Test\`，**不在**备份目录内，也未触碰 `E:` 主工作树；
- 恢复后未对任何恢复文件做修改；
- 未重新生成任何旧 MAT/WTR；
- 未覆盖在用 WindTrace 安装、快捷方式或正式配置。

## 6. 可复核入口

| 文件 | 内容 |
|---|---|
| `restore_results.json` | 11 项检查的逐条状态与说明 |
| 恢复区 | `D:\AeroGNC-Restore-Test\restore_20261105T021954\`（2,584 个文件 + 隔离 profile 临时目录） |
| 脚本 | `D:\AeroGNC-Backup\_work\scripts\restore_test.py` |
