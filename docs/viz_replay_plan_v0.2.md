# VIZ v0.2 计划 — 多方法并排 + 汇总指标 + 数字可追溯

> 版本：v0.2 计划（2026-10-31）· 分支 `viz-replay` · 基线 tag `viz-v0.1.1`
> 依据：`docs/viz_replay_plan_v0.1.md`、`docs/flight_replay.md`、`repo.md`
> 本文件先于实现冻结；门禁与指标定义**先定后算**，看到结果后不放宽。

## 1. 范围

**A 多方法并排（必做）**

```powershell
python viz\replay.py --study <results目录> --case M0 --mode lite --seed 1 --out <目录>
```

- 在 `<study>\logs\` 下按 `<case>_<mode>_s<seed>_<METHOD>_<hash>.mat` 精确解析；
- 方法集合固定：`DA_NS`、`WLS`、`DCA`、`PCA_STATIC`、`PCA_PREDICTIVE`；
- 少于 2 条、同方法多 hash、混 case/mode/seed 一律**非零退出**，不猜、不挑；
- `--log` 单日志模式的命令行行为与 manifest 结构保持 v0.1.1（只允许新增字段，不改旧字段）。

**B 三条汇总指标（必做，定义见 §3）**

- 每方法：`saturation_percent`、`pwm_total_variation_deg`、`solve_time_p95_ms`；
- 窗口默认 `task`，`--window whole` 可切全窗；窗口与定义来源写进 manifest；
- 数值以 Rerun 标量记录（在窗口末端各一个点），并写入 manifest 与生成式文档。

**C 数字可追溯（必做）**

- `viz\tools\summarize_study.py` 读 `summary.csv` + `comparability.csv` + `status.csv`，
  生成 `docs\evidence\viz_numbers.md`（方法覆盖、饱和率、姿态峰值、位置峰值、估计 RMS、
  状态、来源文件 + SHA256 + git SHA）；
- `docs\flight_replay.md` 只引用生成物，不再手写百分比。

## 2. 非目标（本版不碰）

跨种子叠加、跨 case 叠加、方法排名/评分/归一化排序、Pareto 选优、视频、真实外形、
ECL/PX4 路线、与 v0.4 发布流程相关的任何动作。

## 3. 指标精确定义与窗口（先定后算）

记 `e` 为窗口内 PWM 事件索引（`pwm_update_time_s`，含端点），`q` 为窗口内采样索引
（`time_for_metrics`，含端点），`δ_deg = rad2deg(pwm_command_rad)`，`cm=40°`。

| 指标 | 定义 | 来源 |
|---|---|---|
| `saturation_percent` | `100 · mean(any(|δ_deg[e,:]| ≥ cm − 1e-5, axis=1))`，按 **PWM 事件**计，不是 800 Hz 控制帧 | `analysis/ca_metrics.m` 的 `position_saturation_percent` / `analysis/ca_mismatch_metrics.m` 的 `saturation_percent`（同 1e-5 容差） |
| `pwm_total_variation_deg` | `Σ_{e=2..E} Σ_{i=1..6} |δ_deg[e,i] − δ_deg[e−1,i]|`（窗口内相邻 PWM 事件） | `analysis/estimator_feedback_metrics_row.m:17` 的 `command_total_variation_deg`（Pareto 轴） |
| `solve_time_p95_ms` | `1000 · percentile(solve_time_s[q], 95)`，线性插值 | 本计划定义；项目既有指标用 mean/median，P95 是本版新增口径，manifest 记 `definition_source` |

- **窗口命名**：`task`（默认）取 `summary.csv` 中同一 `case/mode` 行的 `window_start_s`/`window_end_s`
  （本项目为 `[6,16] s`）；`summary.csv` 缺失时回退 `[6,16]` 并在 manifest 记
  `window.source="default_task"`。
- `--window whole` 取 `[0, duration]`（`duration = L.time_for_metrics[-1]`），`source="whole"`。
- 超出日志时长：`end = min(end, duration)`，manifest 记 `clamped=true` 与原始窗口；
  `start > duration` 视为错误（非零退出）。
- 不做重采样；PWM 事件与采样点各用各的时间戳。

## 4. 视图判据

- **并排**：同一 `time` 时间轴，同一 `case/mode/seed` 下所有方法轨迹同时可见；颜色只表示身份
  （方法色沿用 v0.1 常量），**不按好坏着色**。
- **机体**：默认只显示“当前方法”的机体与六舵；其余方法机体已记录但蓝图默认
  `EntityBehavior(visible=False)`，可在 viewer 里手动打开。当前方法由 `--active` 指定，
  默认 `DCA`；不存在时报错。
- **状态**：读 `<study>\comparability.csv`，按 `(case, mode)` 取 `comparability` 原样显示
  （`rankable`/`stress`/`invalid`/`unknown`），旁注“原样引用，非本工具计算”；
  文件或行缺失 → `unknown`，不崩、不猜。
- **排名判据（一律不做）**：任何跨方法的排序、打分、归一化、Pareto 选优、颜色/大小编码优劣；
  文档只允许并列陈述数值。

## 5. 验收门禁

1. `pytest viz\tests -q` 全绿，含 v0.1.1 的 41 项，总数 ≥ 50；
2. `git diff --stat main -- '*.m' ':(exclude)viz/**'` 为空；
3. `--log` 单日志输出（`.rrd` 结构、manifest 字段）与 v0.1.1 一致，只允许新增字段；
4. 混 case/mode/seed、同方法多 hash、方法不足，均非零退出且有测试；
5. 5 方法并排：记录 `.rrd` 体积与生成耗时；**>200 MB 或 >5 分钟**则把“五机身”降级为
   “轨迹叠加 + 单机体”，并在文档写明；
6. `docs/flight_replay.md` 不含手写百分比（由 `viz_numbers.md` 生成），数字可追溯；
7. 不改 `viz/` 外 `.m`、不碰 `comparison-ready`、不 push、不移动旧 tag。

## 6. 交付物

- `viz/shc09_viz/study.py`（发现/解析/校验/指标）、`cli.py` 多日志分支、`layers.py` 多方法图层；
- `manifest.json` 多日志字段：每个日志路径 + SHA256、case/mode/seed、方法、窗口、
  三指标定义与数值、comparability 状态与来源；
- `viz/tools/summarize_study.py` + `docs/evidence/viz_numbers.md`；
- 测试 41 → ≥50；tag `viz-v0.2.0`。
