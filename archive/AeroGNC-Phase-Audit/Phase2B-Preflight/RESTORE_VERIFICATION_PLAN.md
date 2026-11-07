# 恢复验证方案（设计，未执行）

日期：2026-11-05（Asia/Shanghai）。
状态：**设计稿。本轮未复制、未恢复、未启动任何软件包。** 所有 `backup`/`restore` 状态仍为 `not_executed`。

## 1. 原则

1. **目的地必须逐文件完整读取**。复制成功、大小相同、mtime 相同、缓存命中都不能替代对目的地字节的 SHA256 重算。
2. **验证基准独立于复制工具**。比对目标取自 `Phase2A/BACKUP_PLAN.csv` 的 `sha256` 列，而不是取复制工具自己生成的清单——否则工具的错误会被自己的日志"证实"。
3. **恢复写入独立 scratch**。不得恢复到主工作树、不得覆盖在用 WindTrace 安装、不得改写任何冻结文件。
4. **恢复测试不产生新的科学结论**。只读加载 MAT、只读解析 WTR、隔离启动 Viewer；**不重跑仿真**。
5. **任何不满足即失败**。不允许"部分通过"或"抽样通过即视为全量通过"的表述。

## 2. 验证等级

| 等级 | 含义 | 允许的使用场景 |
|---|---|---|
| `source_cached` | 源端 SHA 来自历史可信记录，本轮未重读 | 仅用于**源端**，且必须记录 provenance |
| `dest_full_sha256` | 目的地每个文件重新读到字节并计算 SHA256 | **目的地唯一可接受等级** |
| `restored_and_parsed` | 从备份恢复到 scratch 后再次校验，并完成语义解析 | 抽查集合必须达到此等级 |
| `restored_and_launched` | 软件包恢复后隔离启动并打开样例 | WindTrace 整包必须达到此等级 |

本方案要求：**11,144 项全部达到 `dest_full_sha256`；抽查集合全部达到 `restored_and_parsed`；两个 Viewer 整包达到 `restored_and_launched`。**

## 3. 恢复抽查矩阵

### 3.1 全量覆盖（不做抽样）

| 集合 | 数量 | 字节量级 | 方法 |
|---|---:|---|---|
| 两批正式实验原 MAT | 30（15 + 15） | ≈ 620 MB | 逐字节 SHA + 只读 `load` 检查 `L`/`ref`/时间轴维度 |
| 预检原 MAT | 3 | ≈ 58 MB | 同上 |
| 正式与预检 WTR | 33 | ≈ 760 MB | 逐字节 SHA + 独立 reader 解析 schema 与原生时钟 |
| 预检的输入 / 协议 / 锁 | 3 组（各含 `seed501.mat`、`*_protocol.json`、`source_lock.json`、`sources.json`） | ≈ 30 MB | 逐字节 SHA + JSON 解析 + 协议 id/时长复核 |
| GNSS v2 单条回归 | `results/gnss_1000s_regression_20261104_r1` 6 项 + `docs/validation/.../gnss_1000s_model_20261104` 19 项 | ≈ 39 MB | 逐字节 SHA + 报告中的 0.781936 m / 1.629143 m / 0.4770444895 m 三值与 `navigation_metrics.csv` 对齐（只读比对，不重算） |
| 17 份历史 Agent 报告 | 17 | ≈ 200 KB | 逐字节 SHA（报告是文本，可完整覆盖） |
| 每轮 ECL 诊断（Round 5–7 及在册 Round 1–4 证据） | 至少每轮 1 个代表文件完整恢复 | — | 逐字节 SHA + 至少 1 个 JSON/CSV 解析成功 |

> 30 份正式 MAT、33 份 WTR、3 组预检输入/锁的**数量本身有限**，因此不设抽样比例——**全部抽查**。

### 3.2 分层抽样（P1 大集合）

对无法全量语义解析的大集合，按"每 study × 每 batch 至少 2 个文件、且必须包含该批次体积最大的文件与最小的文件"抽样，并保证：

| 要求 | 说明 |
|---|---|
| 每个 `batch_id` 至少 1 项达到 `restored_and_parsed` | 避免整批只验了字节没验结构 |
| 每个 `study` 至少 1 项为 JSON/CSV 并解析成功 | 防止只抽到大二进制 |
| `REVIEW_REQUIRED` 的 477 项至少覆盖 10% | 这些身份未定，优先确认"能恢复"而不是"是什么" |
| `current_summaries`（3,386 项 / 1.47 GB）至少 20 项 | 它是 `historical_evidence` 的最大集合 |

抽样清单在**恢复执行前**由审批人确认，不允许执行者事后挑选"容易通过的样本"。

### 3.3 软件包（必须整包，不能抽 EXE）

| 包 | 位置 | 要求 |
|---|---|---|
| WindTrace 在用整包 | `apps/windtrace/`（2,516 项 / ≈ 601 MB） | 整包恢复到 scratch，逐文件 SHA，**隔离启动**，打开一份**来自备份**的旧 WTR |
| WindTrace 拟回退包 r14 | `results/windtrace_app_v1.0_r14_backup/`（2,441 项 / ≈ 599 MB） | 整包恢复，逐文件 SHA，隔离启动；**该包从未做过启动验证**，此为首次 |

约束：

- 同一 EXE 的 SHA 相同**不能**推定 DLL/资源/主题/许可相同——必须整包比对。
- 启动测试使用独立工作目录与独立配置，**不得**改写现有安装、快捷方式、注册表之外的关联或用户数据。
- 启动失败按**失败**记录，不降级为"环境问题"绕过。

## 4. 各文件类型的验证方法

| 类型 | 字节校验 | 语义校验 | 禁止动作 |
|---|---|---|---|
| `.mat`（MAT 日志/输入） | SHA256 | 只读 `load`，检查 `L`、`ref`、时间轴长度与有限值；与 `metrics.mat`/`metrics.csv` 的样本数一致性 | 不积分对象、不调用 `ppid_simulate`、不重写 MAT |
| `.wtr` | SHA256 | 独立 reader 解析头部 schema 与原生时钟；与 `manifest.json` 的 `bytes`/`sha256` 字段交叉核对 | 不重新导出、不"修正"时钟 |
| `.json`（协议/锁/来源） | SHA256 | `json.load` 成功；`id`、`duration_s`、方法/种子集合与文件名一致；锁内 `sha256` 字段与实际来源文件一致 | **不改写锁内路径**，不"更新"旧 SHA |
| `.csv`（指标/状态） | SHA256 | 表头与行数可解析；不重算指标 | 不填充缺失指标、不补零 |
| `.md`（报告） | SHA256 | 存在且可解码 | 不改写历史结论 |
| `.exe`/`.dll` 包 | SHA256（逐文件） | 隔离启动 | 不覆盖在用安装、不删旧包 |
| `.png`/`.pdf`（图） | SHA256 | 可解码 | 不重新绘图替代原件 |

## 5. scratch 与隔离要求

| 项目 | 要求 |
|---|---|
| 路径 | 独立空目录，例如 `<RESTORE_SCRATCH>/verify_<timestamp>/`，**不得位于**主工作树内 |
| 容量 | 全量恢复需 ≥ 5,006,551,294 字节，建议 ≥ 6 GiB |
| 命名 | 恢复目录内含 `restore_run_id`、起止时间、操作者、工具版本 |
| 源保护 | 恢复过程对主工作树、`BACKUP_ROOT` 均为只读；仅写 scratch |
| 清理 | 验证通过后 scratch 可保留一个周期用于复核；**清理需单独批准**，不得与"恢复验证通过"同时宣布 |
| 并发 | 同一时刻只允许一个恢复任务写同一 scratch；单写者锁 |

## 6. 验收判定

| 检查 | 通过条件 | 失败处理 |
|---|---|---|
| 目的地成员集合 | 与计划 11,144 项路径集合**完全相等**（不多不少） | 立即停止后续批次，保留不完整目标 |
| 目的地逐文件 SHA | 11,144/11,144 等于计划 `sha256` | 该项标 `failed`；整批不得标 `verified` |
| 源稳定性 | 复制前后 `size` + `mtime` 未变，且未被并发修改 | 该文件重做；连续 3 项失败则暂停整批 |
| 恢复后可解析 | 抽查集合 100% 通过 | 标记该批次 `restore: failed`，不得进入登记 |
| Viewer 启动 | 两个整包均能隔离启动并打开备份内的旧 WTR | 该包 `restore: failed`；不得据此清理任何构建包 |
| 算术一致性 | 恢复集合字节数 = 计划子集合计 | 说明成员缺失，回到成员集合检查 |

**任何一项失败，`storage.state` 不得为 `backed_up_verified`。** 按 `RESULTS_LIFECYCLE.md`，备份与恢复分别有独立状态，一项通过不自动升级另一项。

## 7. 记录格式（供后续 Manager `verify-backup` 使用）

每次验证输出一份机读记录，字段至少包含：

```text
verify_run_id, started_at, finished_at, operator, tool_version
backup_root_id, medium_identity, restore_scratch_path
planned_members, actual_members, missing[], extra[]
bytes_planned, bytes_actual
sha256_mismatches[]  (path, expected, actual)
source_stability_failures[]
sampled_restores[]   (path, level, parse_result, detail)
bundle_launch_tests[] (bundle, launched, opened_wtr, result, detail)
verdict              PASS | FAIL
```

`verdict` 为 `PASS` 需要同时满足：成员集合相等、11,144 项 SHA 全等、抽查全部 `restored_and_parsed`、两个整包 `restored_and_launched`。

## 8. 本方案不能证明什么

- 不能证明**科学结论正确**（恢复成功只说明字节与结构完整）。
- 不能证明 **WindTrace 在目标机器上长期可用**（只做一次隔离启动）。
- 不能证明 **GNSS/ECL 真实恢复问题已解决**（Issue #1 仍为已知失败，恢复测试不涉及控制仿真）。
- 不能替代**原址登记**：`restored_and_parsed` 不等于 `manifest.json` 已建立。
- 未执行前，不得出现"已验证备份""已恢复"这类表述。
