# C5/W4 研究代码架构迁移报告

日期：2026-11-05（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**C5/W4 工程迁移与 MATLAB 工程验证 PASS；C6/W5 未执行；55 秒历史复现 NOT RUN**。

## 1. 结论

- 83 项 W4 中 75 项迁移、8 项冻结协议/锁 KEEP；30 个旧实验进入 `studies/legacy_experiments/`，45 个研究代码/README 进入 `studies/<study>/`，5 个公共模块进入 `src/control/ppid`、`src/navigation`、`src/sensors`、`src/runtime/sim`。
- 58 个文件内容保持一致（仅换行归一化）；17 个文件只做路径/来源登记/绝对根路径兼容补丁；未改控制律、估计器、传感器、分配器、协议参数或随机流。
- MATLAB 工程接口、PPID 配置/来源登记、55 秒配置构造和 2 秒平台 smoke 通过；未运行正式研究批。
- 原 `D:\AeroGNC-Backup` 与 `D:\AeroGNC-Restore-Test` 已核对后删除，释放 7,255,868,457 字节；未创建新备份。

## 2. 最终结构

```text
src/control/ppid/ppid_control_step.m
src/navigation/ppid_estimator_init.m
src/sensors/ppid_noise.m, ppid_sensor_step.m
src/runtime/sim/ppid_simulate.m

studies/ppid_pindi/                 config/evaluate/freeze/run/source manifest/README
studies/ppid_pindi/gnss_v2/         gnss_v2 config
studies/hover_distance*/            各 hover/takeoff/capacity/recovery 研究
studies/legacy_experiments/         30 个旧 experiments 驱动与协议辅助
research/                           仅保留 8 个冻结 protocol/formal_lock
```

`ca_setup` 保留显式路径管理；新增公共模块路径已由既有/显式目录覆盖。`ppid_source_manifest` 显式包含 studies 代码、旧实验和 5 个公共模块。`analysis/allocation_comparison_engine.m` 的 mismatch protocol 路径改到 `studies/legacy_experiments`，仍为 121 项。

## 3. 验证

| 检查 | 结果 |
|---|---|
| C5 静态范围 | PASS：83 映射、75 MOVE、8 KEEP、旧路径不存在、协议/锁原字节、无活动 `research/`/`experiments/` 代码引用 |
| MATLAB 路径 | PASS：287 名字、6 分配器、2 效能、14 句柄；公共模块唯一解析 |
| PPID 配置/噪声 | PASS：41601 点参考；配置和噪声构造成功 |
| PPID Source Manifest | PASS：49 文件；engine `696da7e6…`；包含 studies + 公共模块 |
| HDTF 55 秒配置 | PASS：44001 点、55 秒、18316 PWM；未运行正式批 |
| PPID 控制接口 | PASS：`v_h`/`v_c`/电机有限 |
| 平台 smoke | PASS：2 秒 DA_NS，数值有限 |
| 内容一致性 | 58 个纯迁移内容一致；17 个仅路径/登记补丁 |
| MATLAB 语法 | PASS：83 个变更 `.m` 无解析错误 |
| 文档链接 | 90 份/565 链接；2 条历史 validation 旧 research README 链接保留，当前文档无新增断链 |
| Git/集成 | PASS：C5 分支 fast-forward 到 `refactor/phase3-source`；main 未改 |

**NOT RUN**：完整 PPID 52 秒闭环、55 秒 HDT 正式批、五方法正式批、ECL 构建/运行、全套测试。C5 工程验收不等同于 55 秒科研复现。

## 4. Git

- C5 开发分支：`refactor/c5-research`。
- C5 源码提交：`6d25f0e6aa02caa445adb5cd7b72cd1c377be248`；集成提交 `ae66fb6…`；最终 DEV HEAD `a33d4867ad6ad9042d3da3c2c198360c865f0b3b`，已推送。
- `refactor/c5-research` 与 `refactor/phase3-source` 同 SHA；main 仍 `fdc9336…`。
- 工作区仅 `.dsh-plugins/` 未跟踪；没有提交未授权文件。

## 5. D 盘清理

| 目录 | 清理前 | 处理 |
|---|---:|---|
| `D:\AeroGNC-Backup` | 11,231 文件 / 5,108,555,722 字节 | 删除 |
| `D:\AeroGNC-Restore-Test` | 2,584 文件 / 2,147,312,735 字节 | 删除 |

- 167 份备份 MAT/WTR、72 份 restore MAT/WTR 与当前 DEV 路径同大小且 SHA256 全部一致；5 份 pilot 副本哈希一致；101 个 ECL 文件与当前一致；无重解析点。释放 7,255,868,457 字节。
- 未发现唯一原始 MAT/WTR/ECL；源码由 Git 提交/当前工作树保存。未创建新备份或 Restore-Test，DEV/AUDIT/原始科研数据未受影响。

## 6. 限制与下一阶段

- 冻结协议/锁仍在 `research/` 原路径；当前代码显式读取旧路径，历史锁未被改写。
- 2 条历史 validation 链接仍指向旧 `research/ppid_pindi/README.md`，属于冻结证据，未改写。
- `hdf_run` 的绝对根断言已改为 `isfolder(root)`；未运行其正式批。
- **C6/W5 尚不具备直接执行条件**：需单独 Gate 检查 tools/apps/tests/analysis/WindTrace/Results 接口、硬编码路径和来源身份。
- 55 秒 HDT 复现仍需 C6–C9 与 Results 整理后单独授权运行；本轮未运行。
