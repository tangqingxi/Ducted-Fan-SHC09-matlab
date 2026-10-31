# VIZ v0.2.1 计划 — 多方法信号层 + 汇总表

> 版本：v0.2.1（2026-10-31）· 分支 `viz-replay` · 基线 tag `viz-v0.2.0`
> 依据：`docs/flight_replay.md` §12、`docs/viz_replay_plan_v0.2.md`、`repo.md`
> 先冻结本文件，再改代码；门禁见 §4。

## 1. 问题（读代码确认，不靠猜）

- `cli.py::_run_multi` 从未调用 `layers.log_signals`，多方法模式没有任何信号曲线；
- 三条窗口汇总指标被各 log 一个 `Scalars`（时间钉在窗口末端），却用三个
  `TimeSeriesView` 显示——单点画不出曲线，面板只剩图例和坐标轴。

## 2. 范围

**T1 多方法信号层**

- `layers.log_signals(rec, log, method=None)`：单日志路径不变
  （`/signals/attitude_error_deg`、`/signals/position_error_m`、`/signals/vane/{1..6}`）；
  多方法写 `/signals/<METHOD>/attitude_error_deg`、`/position_error_m`、`/vane/{1..6}`。
- 每个方法在系列实体上**静态** log 一次
  `rr.SeriesLines(colors=[method_color(m)], names=[m])`；颜色只表示身份。
- 舵曲线只记 `--active` 的 6 条；姿态/位置曲线 5 方法全记。
- 事件按方法分开：`/events/<METHOD>/saturation`（该帧饱和舵数）、
  `/events/<METHOD>/aero_extrapolation`；单日志保持 `/events/saturation`、
  `/events/aero_extrapolation`。
- 代价控制：先估算 5×(2+6 only active)×16001 的 .rrd 增量；若超过 v0.2 记录的
  19.86 MB 的 1.5 倍（≈29.8 MB），对非 active 方法按 stride 抽稀，并把每个实体的
  stride 写进 manifest（不静默抽稀）。

**T2 汇总值改成表**

- 蓝图删除 3 个 `TimeSeriesView`，新增 `rr.TextDocument`（Markdown 表）+
  `rr.blueprint.TextDocumentView`：`| method | saturation % | PWM total variation (deg) |
  solve time P95 (ms) | status |`，表头注明“status 原样引用 comparability.csv，非本工具计算”。
- `/metrics/...` 标量保持原样（机器可读、manifest 为准），只是不进蓝图。
- 可选 `--metric-lines`（默认关）：把窗口值在窗口起止各 log 一次连成水平线，
  文档写明“常量参考线，不是时间信号”。
- 蓝图：左 3D（轨迹 + active 机体）｜右：姿态+位置一图、active 舵角一图、饱和事件一图、
  汇总表；时间轴范围由窗口 `[start,end]` 决定（`VisibleTimeRange` + `TimeRangeBoundary.absolute`）。

**T3 文档**

- `docs/flight_replay.md` 五处同步（§1、§3 表、§8 标题/说明、§10 末条、§12.2）；
- `repo.md` 追加 v0.2.1 段（问题、改法、证据、下一命令）。

## 3. 非目标

排名/评分/排序、逐帧 PWM 曲线、跨种子/跨 case 叠加、视频、真实外形、ECL、
与 v0.4 发布流程相关的动作；不改 `viz/` 外 `.m`；不 push。

## 4. 验收门禁

1. `pytest viz\tests -q` 全绿（53 → ≥60），新增：
   `test_multi_logs_signal_series`、`test_single_paths_unchanged`、
   `test_vane_series_active_only`、`test_metric_table_markdown`、`test_blueprint_smoke`；
2. `git diff --stat main -- '*.m' ':(exclude)viz/**'` 为空（相对基线 `e662e7d` 复核）；
3. 单日志 `.rrd` 的 entity 路径与 v0.2.0 完全一致（`rerun rrd print -v` 对比，写进证据）；
4. 多方法 `.rrd` 能查到 5 个方法的 `/signals/<M>/attitude_error_deg`；体积/耗时记录进文档；
5. 颜色只表示身份；不排名、不打分、不排序方法；
6. tag `viz-v0.2.1`（`viz-v0.2.0`、`viz-v0.1.1`、`viz-preview` 保留不动）。

## 5. 实测 API（rerun-sdk 0.41.0）

- `rr.SeriesLines(colors=[rgb], names=[name], widths=...)`，建议 `static=True`，数据仍用 `rr.Scalars`；
- `rr.blueprint.TextDocumentView(origin=...)` 可用；
- `rr.blueprint.VisibleTimeRange(timeline="time", range=rr.blueprint.TimeRange(
  start=rr.blueprint.TimeRangeBoundary.absolute(seconds=a),
  end=rr.blueprint.TimeRangeBoundary.absolute(seconds=b)))`。
