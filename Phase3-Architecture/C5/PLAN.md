# C5/W4 研究代码迁移计划

日期：2026-11-05（Asia/Shanghai）。分支：`refactor/c5-research`，从 C4 `661eecc` 创建；验收后 fast-forward 集成到 `refactor/phase3-source`。

## Gate 结论

**PASS_WITH_PATCHES**。W4 共 83 项：75 MOVE、8 KEEP；无目标冲突、无缺失源。

- KEEP 的 8 项是 `protocol.json`/`formal_lock.json`：保留原 `research/` 路径和原字节；活动代码继续读取旧路径，历史锁不被覆盖。
- 30 个旧 `experiments/` 文件迁移到 `studies/legacy_experiments/`。
- 45 个研究代码/README 迁移到 `studies/<study>/`。
- 5 个公共模块迁移到 `src/control/ppid/`、`src/navigation/`、`src/sensors/`、`src/runtime/sim/`。
- 58 个文件内容保持不变（仅换行归一化）；17 个文件只做路径、来源登记或绝对根路径兼容补丁。

## 关键风险与处理

| 风险 | 处理 |
|---|---|
| 冻结协议/锁路径 | KEEP 原路径与原字节；代码读取旧路径 | 
| `ppid_source_manifest` 漏计公共模块 | 显式加入 studies、legacy_experiments 和 5 个公共模块 |
| Engine 的 `experiments/ca_mismatch_protocol` | 改指 `studies/legacy_experiments`，仍为 121 项 |
| `hdf_run` 固定 `E:\...` 根 | 改为 `isfolder(root)`，不改变运行参数 |
| 研究入口路径 | 根入口、hdtf/hdt/hd/hft/hdf 配置与来源清单改指 studies |
| 文档链接 | 当前文档已更新；2 条历史 validation 链接保留为冻结证据 |

## 验收基准

`check_phase3_paths`、`ppid_config`/`ppid_noise`、`ppid_source_manifest`、`hdtf_config(501)`、PPID 控制接口、2 秒平台 smoke、静态 C5 范围检查。不运行 55 秒正式批、五方法批、ECL 重建或全套测试。
