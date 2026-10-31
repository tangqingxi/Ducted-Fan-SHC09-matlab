# 仓库进度报告（VIZ v0.1）

> 生成时间：2026-10-31 19:24（Asia/Shanghai）
> 分支：`viz-replay`（基线 `main@e662e7d`）· 代码/tag 基线 `0f05690`（`viz-preview`）· 工作区干净
> 依据：`docs/viz_replay_plan_v0.1.md`（含 2026-10-31 19:01 的范围收缩提交 `a943cc5`）

## 一句话

在独立 worktree/分支上完成了「MATLAB `.mat` 飞行日志 → Rerun `.rrd` 3D 回放 + 3 条曲线」的
后处理管线。**M0–M4 全部完成并通过 §10 门禁**；数值代码零改动；`comparison-ready` 未触碰；
分支与 tag **尚未 push**（计划 §14 要求首次 push 前人工确认）。

## 状态总览

| 里程碑 | 状态 | 主要交付 |
|---|---|---|
| M0 环境与骨架 | ✅ | `.venv-viz`（scipy 1.18.1 / rerun-sdk 0.41.0 / numpy 2.5.4 / pytest 9.2.0）、`viz/` 骨架、Rerun 0.41 API 实测、`README` 的“API 备忘” |
| M1 读取/坐标/几何 | ✅ | `mat_io.py`（两种日志 + 时间基准三分支 + 校验）、`frames.py`（NED→ENU、ZYX→四元数）、`export_geometry.m` + `shc09_geometry.json`（SHA256） |
| M2 3D 场景 | ✅ | `scene.py`/`layers.py`：网格、参考/实际/估计轨迹、机体、涵道环、桨盘、六舵实际+命令、目标 ghost；2 s 与 20 s 各一份 `.rrd` + 截图 |
| M3 曲线/事件/manifest | ✅ | 3 组曲线（姿态误差、位置误差、六舵角）、饱和/气动越界事件、`manifest.json`；与 `control.csv` 抽 3 点对账 |
| M4 文档/示例/tag | ✅ | `docs/flight_replay.md`、根 README“可视化（可选）”、干净树复跑、tag `viz-preview` |

### 范围变化说明

会话中途计划文件被更新（提交 `a943cc5`）：v0.1 只保留 3 组曲线，PWM 事件、`solver_exitflag`、
residual 移到 v0.2，右侧时序视图减为 2 个，并新增 §7.1 开源参考清单。实现已按新范围收窄，
未保留被移出范围的 PWM/求解曲线层。

## 产物清单

```text
viz/
├─ README.md                      # 用法 + API 备忘 + 限制
├─ requirements.txt               # 固定版本
├─ replay.py                      # 启动器：python viz\replay.py --log ...
├─ shc09_viz/
│  ├─ cli.py                      # 参数、编排、blueprint（3D + 2 个时序视图）、viewer
│  ├─ mat_io.py                   # 两种输入 → FlightLog；时间基准三分支；读取校验
│  ├─ frames.py                   # NED/ENU、ZYX→R→quat、连续性、det 检查
│  ├─ geometry.py                 # 读 geometry.json 并校验 payload 哈希
│  ├─ scene.py                    # 静态世界 + 机体/涵道/桨盘/舵面命令 ghost
│  ├─ layers.py                   # 轨迹、机体/六舵动画、3 组曲线、事件
│  └─ manifest.py                 # 日志 SHA256、git、几何、版本、假设
├─ geometry/{shc09_geometry.json, export_geometry.m}
├─ tools/{make_fixture, check_frames}.m
├─ tools/{smoke_rerun, inspect_log, screenshot, check_curves_csv}.py
├─ tests/                         # 32 项，不依赖 MATLAB
└─ examples/flight_replay/        # 2 张 PNG（已提交）
```

本地（被 `.gitignore` 忽略、不进 Git）的验收产物：

- `results/viz_fixture_2s_DCA/replay.rrd` + `manifest.json`（1601 点，2 s）
- `results/viz/viz_20s_ideal_DCA/replay.rrd` + `manifest.json`（16001 点，20 s，带参考机动）
- `results/viz_fixture_2s_DCA/DCA/{log.mat, control.csv, pwm.csv}`
- `results/viz_20s_ideal_DCA/DCA/{log.mat, control.csv, pwm.csv}`
- `results/validation/m1_gate_matlab.log`、`m2_gate_matlab.log`

## 验收证据

```text
$ .\.venv-viz\Scripts\python.exe -m pytest viz\tests -q
32 passed in 5.02s

$ .\.venv-viz\Scripts\python.exe viz\replay.py --log results\viz_fixture_2s_DCA\DCA\log.mat \
    --out results\viz\viz_fixture_2s_DCA --rate 800
replay: platform log, method=DCA, n=1601, t=[0, 2.000]s, time_base=assumed_rate
replay: wrote ...\replay.rrd (1.67 MB) and manifest.json in 2.7s

$ .\.venv-viz\Scripts\python.exe viz\replay.py --log results\viz_20s_ideal_DCA\DCA\log.mat \
    --out results\viz\viz_20s_ideal_DCA --rate 800
replay: platform log, method=DCA, n=16001, t=[0, 20.000]s, time_base=assumed_rate
replay: wrote ...\replay.rrd (16.75 MB) and manifest.json in 25.1s

$ .\.venv-viz\Scripts\python.exe viz\tools\check_curves_csv.py \
    --log results\viz_20s_ideal_DCA\DCA\log.mat --control ...\control.csv
 index      t_s   vane_deg  pos_err_m  att_geo_deg csv_euler_note
     0    0.000   4.44e-15   0.00e+00     0.00e+00       0.00e+00
  8000   10.000   4.44e-15   2.78e-17     6.62e-12       1.16e-06
 16000   20.000   3.55e-15   5.55e-16     9.33e-09       3.64e-07
gate tolerance=1e-06: PASS

$ git diff --stat main -- '*.m' ':(exclude)viz/**'
（空）
```

- MATLAB 回归：**14/14 项目测试、6/6 平台测试、冻结基线 20 例全过**（exit 0）。
- 干净树复跑（`git archive HEAD` 解包到 `.tmp/clean`，不依赖 MATLAB）：`pytest` 32 passed，
  同一命令产出 `replay.rrd`（1.70 MB）+ `manifest.json`。
- manifest 记录：`git_sha=f36036c1`、`git_dirty=false`、`n=16001`、`time_base=assumed_rate`、
  几何哈希 `f94dc2cb5c2a…`；同输入两次生成除 `created_at` 外逐字段一致（有单测）。
- 截图：[2 s 悬停](viz/examples/flight_replay/2s_hover.png)、
  [20 s 参考机动](viz/examples/flight_replay/20s_reference_tracking.png)。

## 必须遵守的约定（接手者先看这两节）

1. **坐标**：导航 NED（z 向下），机体 x 左 / y 前 / z 下；ψ=0 时前向是**东**，不是北；
   显示用 **ENU**（det=+1，不是 HANDOFF §10 的 NEU）；四元数先做 `det`/正交检查，
   相邻帧符号连续化。数值裁决用 `viz/tools/check_frames.m`。
2. **时间基准**：`L.time_for_metrics` → `r.time_s` → `(0:n−1)/rate`（默认 800，`--rate` 可改，
   manifest 记 `assumed_rate` 并打警告）。任何情况下不重采样。
3. **几何是示意**：涵道 0.30/0.28 m、机体 0.18×0.18×0.35 m、桨盘 0.114 m 是面积等效半径；
   `shc09_geometry.json` 带 `assumed`，Python 不复制 l1/l2/P_cs。
4. **v0.1 只画 3 组曲线**；PWM/求解健康看同目录 `control.csv`/`pwm.csv`（PlotJuggler 直接拖入）。

## 提交记录（本分支在基线 `e662e7d` 之后）

```text
0f05690 docs: record final 2 s / 20 s replay sizes
f36036c docs: mark M4 complete and record clean-tree evidence
0998f38 viz: layer and end-to-end smoke tests; optional moving reference in fixture
0b95728 docs: add optional visualization section to root README
329d980 docs: flight replay conventions, limits and M0-M3 evidence
5f051d2 viz: verify the three curves against control.csv at three sample times
0f5ccf5 viz: 3D scene, vane animation and the three v0.1 curves
a943cc5 docs: scope viz v0.1 to 3D replay, add open-source reference list
b6b9aab viz: read both log shapes, NED/ENU frames and MATLAB-exported geometry
3d3620a viz: bootstrap M0 skeleton, pinned venv requirements and Rerun smoke
5f8e944 docs: add VIZ v0.1 replay plan
```

## 已知问题（均不阻塞 v0.1）

- 20 s 日志 t=10 s 处，CSV 的欧拉差角与回放曲线的测地旋转角相差 **1.16e-6 deg**（定义差，
  不是数据不一致）；姿态曲线本身用 MAT 的 `euler_rad/desired_euler_rad` 重算验证。
- MATLAB `string` 对象在 `-v7` 中是 MCOS opaque，`estimator_mode`/`plant_model` 在 manifest 中为
  `null`；`L.name`（char）仍可用于方法名校验。
- Rerun 0.41 的三维点球不透明，目标 ghost 用半径 0.15 m 的三圈线框球实现。
- Rerun viewer 需要可写 TEMP；本机系统 TEMP 不可写，`tools/screenshot.py` 把 `TEMP/TMP`
  指向仓库 `.tmp/`（已忽略）。
- `.rrd` 每次生成的字节数会随 Rerun 内部分块略变；manifest 不记录字节数，只记文件名。

## 下一步

```powershell
# 1) 人工确认后首次 push（分支 + tag）
git push -u origin viz-replay
git push origin viz-preview

# 2) 复核回放
.\.venv-viz\Scripts\python.exe viz\replay.py `
  --log results\viz_20s_ideal_DCA\DCA\log.mat `
  --out results\viz\viz_20s_ideal_DCA --rate 800 --viewer
```

v0.2 候选（不在本次范围）：PWM/求解健康曲线、多方法叠加、MP4/GIF、更真实的整机外形；
等 v0.4.0 有 tag 后再按计划 §14 `--no-ff` 合入 `main`。
