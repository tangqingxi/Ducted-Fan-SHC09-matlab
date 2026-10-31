# VIZ 分支 v0.1 计划 — SHC09 日志回放

> **交接文档 · 计划版本 v0.1 · 2026-10-31**
> 读者：接管 `E:\Ducted-Fan-SHC09-matlab` 的新 agent（也适合人类复核）
> 本计划所在分支：`viz-replay`，worktree `E:\Ducted-Fan-SHC09-viz`，从 `main` 开出
> 已核对基线：`main` = `e662e7d`（v0.3.0）；与 `comparison-ready`（v0.4 WIP）**互不阻塞**

---

## 0. 60 秒摘要

**你要做什么。** 在独立分支上做一条"仿真日志 → `.rrd` → Rerun 3D 回放"的后处理管线：读 MATLAB 已经存好的 `.mat`，生成可拖时间轴的 3D 场景 + 曲线。**不改任何数值代码**，不嵌入仿真循环，不做实时。

**你不在什么里。** v0.4 主比较（35/60 暂停）在 `comparison-ready`，不是你的任务。不要 switch、不要 merge、不要 clean、不要 rebase 那个分支。VIZ 从 `main`（v0.3.0）开，v0.4.0 发布前不合入 `main`。

**完成的定义。** 一条命令出可看的回放 + 两份真实日志证据 + 一套不依赖 MATLAB 的测试 + 一份写清坐标约定和限制的文档 + tag `viz-preview`。时间盒 **3.5–4 个工作日**，超出就砍功能，不要扩范围。

**最容易错的不是代码，是约定**：坐标系（NED 的 z 向下）、机体前向（`y` 前向，所以 ψ=0 指向**东**不是北）、时间基准（比较日志有、`platform_run` 日志没有）。这三条在 §6/§5.3 写死并有单测。

**别重复造轮子。** 渲染/时间轴/四元数/MAT 解析全部用现成库；只有 SHC09 的坐标、字段、六舵语义自己写。清单见 §7.1。

---

## 1. 现状事实（2026-10-31 18:45 实测，不要再猜）

| 项 | 值 |
|---|---|
| 主仓库 | `E:\Ducted-Fan-SHC09-matlab`，`origin` = github.com/tangqingxi/Ducted-Fan-SHC09-matlab |
| `main` / `origin/main` | `e662e7d`（v0.3.0，已发布） |
| `comparison-ready` | `ad70303`（v0.4 WIP：35/60 主比较、未打 tag、**不是发布态**） |
| VIZ worktree | `E:\Ducted-Fan-SHC09-viz`，分支 `viz-replay`，HEAD `e662e7d`，工作区干净 |
| MATLAB | `E:\Matlab\R2025b\bin\matlab.exe`（R2025b + Optimization Toolbox） |
| Python | `D:\app\python_manager\3.13.0\python.exe`（3.13.14，64 位） |
| 已装 Python 包 | `numpy`、`matplotlib`；**无** `scipy`、**无** `rerun` |
| pip / 索引 | pip 26.1.2，可访问 PyPI；`rerun-sdk` 最新 **0.41.0** |
| git | 2.51.1.windows.1；worktree 功能正常 |
| 控制 / PWM | 800 Hz / 333 Hz；`ref.time_s = 0:1/800:duration`，`n = 800·T + 1`（20 s → 16001） |
| 悬停预设 | 初始/参考位置 `[0,0,-10]` m（NED，高度 10 m），`position_hold`，`hold_90` |
| 现有真实日志 | 主 worktree 的 `results/`（4.45 GB、1956 文件，只读可用）；viz worktree 的 `results/` 目前为空 |
| 数据格式 | **只有 MAT（`-v7`）+ CSV/JSON**；全仓库无 `.ulg`/`.mcap`/`.rrd` |

---

## 2. 目标与非目标

**v0.1 目标（可判定）**

1. 一条命令：给定一个日志文件或一个输出目录，生成 `results/viz/<tag>/replay.rrd` + `manifest.json`。
2. 场景能看清：参考轨迹、实际轨迹、机体、涵道环、六舵、目标 ghost。
3. 曲线能对齐：姿态误差、位置误差、六舵（只 3 条；全量曲线走 CSV 兜底）。
4. 证据可复现：同一输入两次生成，除时间戳外 `manifest.json` 一致。
5. 文档写清：坐标约定、字段来源、已知限制、示例图。

**v0.1 非目标（写进 README，别偷偷做）**

- 实时渲染、嵌入 `ca_simulate` 循环、改变任何数值结果或随机序列。
- ULog / PX4 / Hawkeye / `pyulog` 路线；C++/Rust 扩展；Web 嵌入。
- 多机编队、多日志同步播放（v0.1 一次一个方法；多方法叠加放 v0.2）。
- MP4/GIF 录制（先用 Rerun 截图 PNG）。
- 实机外形/气动外形复现（几何只做**示意**，见 §6.6）。
- 用回放做方法排名、显著性、稳定性主张。

---

## 3. 红线（违反即回滚，不要"顺手"做）

1. **不改** MATLAB 数值路径：`platform/`、`models/`、`allocators/`、`analysis/`、`drivers/`、`configs/`、`apps/`、`main*.m`、`tests/` 的既有文件一律不动；新增只允许在 `viz/` 下。
2. **不动** `comparison-ready`：不 switch、不 merge、不 rebase、不 clean、不在主 worktree 写 `results/`。
3. **不读不写** `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`（平台 HANDOFF §8.5，本仓库遗留约束）。
4. **不进 Git**：`.venv-viz/`、`*.rrd`、`__pycache__/`、`results/`；示例只提交 PNG 和小 JSON。
5. **不夸大**：回放只证明"日志长这样"，不证明数字孪生、实机一致、实时性、统计显著性。
6. **不把 lite 的估计量当真值**，不把 M4/lite 的 stress 当方法排名（见平台 HANDOFF §7）。
7. **不修改 HANDOFF.md**（v0.1 期间），理由见 §14：它会和 `comparison-ready` 上的 HANDOFF 冲突。

---

## 4. 起点：第一天照抄

```powershell
# 0) worktree 已建好（本计划提交时已存在）。若需重建：
#    git -C E:\Ducted-Fan-SHC09-matlab worktree add E:\Ducted-Fan-SHC09-viz -b viz-replay main

cd E:\Ducted-Fan-SHC09-viz
git status -sb                 # 期望：## viz-replay，无改动
git log -1 --oneline           # 期望：e662e7d release: v0.3.0 notes

# 1) Python 环境（只在 worktree 内，不动全局 Python）
D:\app\python_manager\3.13.0\python.exe -m venv .venv-viz
.\.venv-viz\Scripts\python.exe -m pip install -U pip
.\.venv-viz\Scripts\python.exe -m pip install scipy "rerun-sdk==0.41.0" pytest
.\.venv-viz\Scripts\python.exe -c "import scipy, rerun, numpy; print(scipy.__version__, rerun.__version__, numpy.__version__)"
```

`.gitignore` 追加（放文件末尾，单独一段注释）：

```gitignore
# VIZ：本地环境与回放产物，不进 Git
.venv-viz/
*.rrd
viz/**/__pycache__/
```

MATLAB 侧夹具（**唯一需要 MATLAB 的 viz 动作**，只在 `viz/tools/` 新增文件）：

```matlab
cd E:\Ducted-Fan-SHC09-viz
ca_setup;
o = shc09_airframe();                       % 2 s、position_hold、-10 m、不保存
o.save_results = true;
o.output_tag   = "viz_fixture_2s_DCA";
r = main(3, o);                             % 3 = DCA；输出 results\viz_fixture_2s_DCA\DCA\log.mat
```

长日志（20 s，用于验收）：

```matlab
o = shc09_airframe("ideal"); o.duration_s = 20; o.save_results = true;
o.output_tag = "viz_20s_ideal_DCA"; r = main(3, o);
% lite 版本把 "ideal" 换成 "lite"：15 s 对准在仿真开始前的初始化里，日志 t=0 就是任务段，
% 不要把 warmup 当飞行段（见 §12 陷阱 7）。
```

---

## 5. 数据契约（已从源码核对，不用再翻代码）

### 5.1 两种输入，两种形状

| 类型 | 路径 | 变量 | 时间基准 | 用在哪 |
|---|---|---|---|---|
| **A 比较日志** | `results/<tag>/logs/<case>_<mode>_s<seed>_<METHOD>_<hash>.mat` | `L`、`c`、`r`、`audit`、`engine_fingerprint`、`log_key` | `L.time_for_metrics`（= `r.time_s`） | 正式证据、lite/多方法 |
| **B 平台日志** | `results/<tag>/<METHOD>/log.mat` | 仅 `log` | **没有时间向量**，需 `--rate` | 快速夹具、旧结果 |

- 类型 A 由 `analysis/allocation_comparison_run.m` 产生（保存时 `L.time_for_metrics = r.time_s`）。
- 类型 B 由 `platform/platform_run.m` 产生（只 `save(...,'log')`），旁边有 `control.csv` / `pwm.csv` 可做交叉校验。
- **不要**整体 `loadmat` `comparison.mat`：`results.implementation` 里内嵌了全仓库 `.m` 源码，文件巨大且与回放无关。只读 `logs/*.mat`，并用 `variable_names` 限定。

### 5.2 主要字段（`scipy.io.loadmat(..., variable_names=[...], squeeze_me=False)` 后是 `n×k` 或 `n×1`）

| MATLAB 字段 | 形状 | 单位 | 回放用途 |
|---|---|---|---|
| `L.position_ned_m` | n×3 | m | 实际轨迹 |
| `L.velocity_ned_m_s` | n×3 | m/s | 速度箭头（可选） |
| `L.position_reference_ned_m` | n×3 | m | 参考轨迹、ghost |
| `L.euler_rad` | n×3 | rad | 真实姿态（`[roll pitch yaw]`，ZYX） |
| `L.desired_euler_rad` | n×3 | rad | 姿态指令（可选箭头） |
| `L.measured_euler_rad` | n×3 | rad | 测量姿态（含噪声） |
| `L.rotation_error_rad` | n×1 | rad | 姿态误差曲线 |
| `L.command_rad` | n×6 | rad | 分配器输出（控制率） |
| `L.actual_delta_rad` | n×6 | rad | **真实舵偏，六舵默认显示这个** |
| `L.pwm_command_rad` | E×6 | rad | PWM 锁存命令（E≈333·T） |
| `L.pwm_update_time_s` | E×1 | s | PWM 事件时刻 |
| `L.pwm_end_actual_delta_rad` | E×6 | rad | 事件末端真实舵偏 |
| `L.pwm_end_prediction_error_rad` | E×6 | rad | 预测误差 |
| `L.table_extrapolated` | n×1 | bool | 气动越界事件 |
| `L.solver_exitflag` / `L.iterations` / `L.solve_time_s` | n×1 | — | 求解健康曲线（v0.2） |
| `L.motor_rad_s` / `L.exit_speed_m_s` | n×1 | rad/s、m/s | 转速/出口速度曲线（v0.2） |
| `L.duct_angle_rad` / `L.wing_angle_rad` | n×1 | rad | 迎角曲线（越界可见） |
| `L.estimated_position_ned_m` | n×3 | m | lite 估计轨迹（虚线） |
| `L.estimated_attitude_error_rad` | n×1 | rad | lite 估计误差 |
| `L.allocator_config_fields` / `L.name` / `L.estimator_mode` / `L.plant_model` | — | — | 标题与 manifest |

`c` 里有 `sample_hz`、`duration_s`、`output_tag`、`estimator_mode`；`r` 里有 `time_s`、`position_ned_m`、`euler_rad`。**类型 A 的 dt 从 `c.sample_hz` 或 `diff(r.time_s)` 取，不要写死。**

### 5.3 时间基准规则（按顺序，绝不静默插值）

1. `L.time_for_metrics` 存在 → 直接用；断言 `numel == n` 且单调。
2. 否则 `r.time_s` 存在 → 用；断言同上。
3. 否则用 `(0:n-1)/rate`，`rate` 默认 `800`，可由 `--rate` 覆盖；`manifest.json` 记 `time_base="assumed_rate"`、`rate=...`，并在 stderr 打一行警告。
4. 任何情况下都不做重采样；两条曲线的采样率不同（如 PWM 333 Hz）时，事件按各自时间戳打点，不做插值对齐。

### 5.4 读取校验（读的时候就失败，不要画到一半才崩）

- `n >= 2`；`L.position_ned_m.shape == (n,3)`；`L.actual_delta_rad.shape == (n,6)`。
- 时间单调递增、`t[0] ≈ 0`、`dt ≈ 1/800`（容差 1%）。
- 关键数组无 `NaN`（`pwm_end_*` 允许尾部 `NaN`，已在保存时截断到 `pwm_count`）。
- `c.methods` / `L.name` 与文件名中的方法名一致，不一致就报错（防止张冠李戴）。

---

## 6. 坐标与姿态（本计划最重要的部分）

### 6.1 模型事实

- 导航系 **NED**：x 北、y 东、z **向下**；重力 `+z`；推力沿机体 `-z`（向上）。
- 机体系：**x 左、y 前、z 下**（"机体前向为 y"）。六舵在机体 `xy` 平面六边形顶点，半径 `l1=0.267 m`，轴向偏移 `l2=0.066 m`。
- 欧拉角 `[roll pitch yaw]`，ZYX，旋转矩阵 `R_ned_body`（`lib/math/ca_euler_rotation.m` 的标准式）。
- 初始/参考高度 `-10 m`（NED）。

### 6.2 陷阱：ψ=0 时前向是**东**，不是北

`R(0,0,0)=I`，机体前向 `[0,1,0]` 映射到 NED `+y` = **东**。平台对称，物理上无影响，但任何"北向航向"的写法都会差 90°。**先用数值验证再写渲染代码**：

```matlab
% viz/tools/check_frames.m（新增，只读，不改任何东西）
addpath(genpath(fullfile(pwd,'lib','math')));
R = ca_euler_rotation([0 0 0]);      disp(R*[0;1;0]');   % 期望 [0 1 0] → NED +y（东）
R = ca_euler_rotation([0 0 pi/2]);   disp(R*[0;1;0]');   % 期望 [-1 0 0]
R = ca_euler_rotation([pi/2 0 0]);   disp(R*[0;0;-1]');  % 记录实际值，冻结为测试期望
```

### 6.3 显示系：用 **ENU**，不要用 HANDOFF §10 的 `[north, east, up]`

```text
p_enu = [E, N, -D]                    # x 东、y 北、z 上
A     = [[0,1,0],[1,0,0],[0,0,-1]]    # NED→ENU，det(A)=+1
R_enu_body = A @ R_ned_body
```

**为什么不用 `[north, east, up]`（NEU）**：NEU 相对 NED 是镜像（`det=-1`），姿态四元数无法用相似变换表示——用它会得到左右翻转、转向反号的场景，而且看起来"还挺正常"。ENU 是纯旋转，`det=+1`，可以安全地 `R_enu_body` 直接转四元数。**这是对旧 HANDOFF §10 的更正。**

自检：悬停 `R≈I` 时 `R_enu_body @ [0,0,-1] ≈ [0,0,1]`（推力向上）；`R_enu_body @ [0,1,0] = [1,0,0]`（前向 = 东）。

### 6.4 四元数

- 用 `scipy.spatial.transform.Rotation.from_matrix(R_enu_body).as_quat()`（`xyzw`）。
- 相邻帧做符号连续化：`if dot(q_k, q_{k-1}) < 0: q_k = -q_k`，否则 viewer 会闪。
- `R` 必须先过 `det>0` 检查（`abs(det-1) < 1e-9`），失败就抛出而不是静默修复。

### 6.5 六舵几何与动画

- 位置：`p_i = [l1*P_cs[0,i], l1*P_cs[1,i], l2]`，`P_cs` 见 `models/shc09/ca_shc09_parameters.m`（六个单位六边形顶点）。
- 动画：舵面绕**切向轴** `t_i = (-P2, P1, 0)` 旋转 `actual_delta_rad[:, i]`。这是**示意选择**（数值侧 `C` 是效能矩阵，不是严格的 `r×F`），写进 `geometry.json` 的 `assumptions` 字段。
- 命令叠加：`command_rad` 用半透明、同色系浅色，避免和真实舵偏混淆；两者差异大时（lite + PWM 保持）这是**信息**，不是 bug。
- 饱和：`|command| >= cm - 1e-6`（`cm = deg2rad(40)`），饱和舵标红加粗。

### 6.6 几何是示意，不要声称外形

`S = π·0.114²` 是桨盘**面积**等效半径（0.114 m），而舵环半径 `l1 = 0.267 m`，两者不是同一个几何量，仓库里没有整机外形尺寸。v0.1 画法：

- 涵道环半径 = `0.30 m`（外）/ `0.28 m`（内）——视觉选择；
- 桨盘圆 = `0.114 m`，标注"面积等效半径"；
- 六舵在 `0.267 m` 环上，轴向 `+0.066 m`；
- 机体用一个 0.18×0.18×0.35 m 的盒子（示意）。

`viz/geometry/shc09_geometry.json` 必须带 `"source": "ca_shc09_parameters"`、`"assumed": [...]`、`"generated_by"`、`"sha256"`，文档同步写"不声称与实机外形一致"。

---

## 7. 架构与文件

架构不自己发明：分层直接沿用 Rerun 官方示例的实体组织（静态世界 → 变换树 → 线/点 → 标量序列），加一个 CLI 和一份 manifest；差异化只在 SHC09 的坐标、字段和六舵语义。逐项对照见 §7.1。

```text
viz/
├─ README.md                      # 30 行：是什么、怎么跑、限制、API 备忘
├─ requirements.txt               # 固定版本：scipy / rerun-sdk / pytest / numpy
├─ replay.py                      # 10 行启动器：python viz\replay.py --log ...（免安装）
├─ shc09_viz/
│  ├─ __init__.py
│  ├─ cli.py                      # 参数解析、编排、退出码
│  ├─ mat_io.py                   # 两种输入 → FlightLog；时间基准；校验
│  ├─ frames.py                   # NED/ENU、ZYX→R→quat、连续化
│  ├─ geometry.py                 # 读 geometry.json，建环/盘/六舵/机体
│  ├─ scene.py                    # 静态世界：网格、原点、指北箭头
│  ├─ layers.py                   # 动态图层：轨迹/ghost/机体/舵/曲线/事件
│  └─ manifest.py                 # 哈希与清单
├─ geometry/
│  ├─ shc09_geometry.json         # 提交
│  └─ export_geometry.m           # MATLAB 生成器（唯一几何来源）
├─ tools/
│  ├─ make_fixture.m              # 生成 2 s 夹具（写 results/，不进 Git）
│  └─ check_frames.m              # §6.2 的数值验证
├─ tests/
│  ├─ conftest.py                 # 造合成 L（不依赖 MATLAB、不读大文件）
│  ├─ test_frames.py
│  ├─ test_mat_io.py
│  ├─ test_layers.py
│  └─ test_replay_smoke.py
└─ examples/flight_replay/        # 2 张 PNG + 命令，提交
```

**四个设计决定（v0.1 冻结，改动要写进本文档）**

- **D1 几何单一来源**：Python 不复制 `l1/l2/P_cs`，由 `export_geometry.m` 导出 JSON，提交 JSON；哈希写进 manifest。改了参数就重导出，测试会因哈希变化提醒你。
- **D2 图层独立可开关**：每个图层一个 Rerun entity 前缀（`/traj/actual`、`/vehicle/vanes`、`/signals/...`），viewer 里能单独勾选。
- **D3 时间统一用秒**，不做实时、不做播放速率控制（viewer 自带）。
- **D4 一张 `.rrd` 配一份 `manifest.json`**：日志路径 + SHA256、git SHA、几何哈希、Python/rerun/scipy 版本、n、时长、`time_base`、软件假设。同一输入的两次生成必须一致（除 `created_at`）。

### 7.1 可借鉴的开源项目（M0 先读，禁止重复造轮子）

**判据**：能用库解决的（渲染、时间轴、四元数、MAT 解析、截图）一律不自己写；能抄交互的（多视图联动、配色、信息层级）只抄设计不拷代码；只有 SHC09 领域语义自己写。

**表 A · 直接依赖（不自己实现）**

| 轮子 | 别写的代码 | 现成件 |
|---|---|---|
| MAT 读取 | 解析 v5/v7 二进制头 | `scipy.io.loadmat`（只有 v7.3 才需要 `h5py`） |
| 旋转数学 | 欧拉↔矩阵↔四元数、Slerp、连续性 | `scipy.spatial.transform.Rotation` |
| 3D 渲染 / 时间轴 / 曲线 / 布局 | 整个 viewer | `rerun-sdk` |
| 数值与测试 | — | `numpy`、`pytest` |

注：Rerun 官方只有 Python / C++ / Rust SDK，**没有 MATLAB SDK**；"MATLAB 存 MAT → Python 转 rrd"是唯一低成本路线，不要在 MATLAB 里找 rerun 客户端。

**表 B · 抄设计（看仓库，不引依赖）**

| 参考 | 借什么 | 不借什么 |
|---|---|---|
| [rerun examples/python/blueprint](https://github.com/rerun-io/rerun/blob/main/examples/python/blueprint/blueprint.py) | 多视图布局、视图 ID 复用、`Spatial3DView`/`TimeSeriesView` 组合 | 它的场景内容 |
| [rerun examples/python/any_scalar](https://github.com/rerun-io/rerun/tree/main/examples/python/any_scalar) | 标量序列 → 时间序列视图的最小写法；`AnnotationContext` 配色/标签 | 单通道 demo 结构 |
| [rerun examples/python/dna](https://github.com/rerun-io/rerun/tree/main/examples/python/dna) | `Transform3D` 父子层级（世界→机体→六舵）、`LineStrips3D` 线带 | 无物理含义的螺旋几何 |
| [facontidavide/PlotJuggler](https://github.com/facontidavide/PlotJuggler) | 拖时间轴全视图同步；**`control.csv`/`pwm.csv` 零代码看全量曲线**；4.x 的 `pj_scene3D` 是 3D+曲线联动的成熟范式 | GPLv3 代码 |
| [dfki-ric/pytransform3d](https://github.com/dfki-ric/pytransform3d) | 将来要画坐标轴/帧关系时直接用 | v0.1 不引依赖 |
| （可选）[foxglove/studio](https://github.com/foxglove/studio) | 3D panel + plots + 布局保存的 UX；Web 化路线图 | MCAP/ROS 绑定 |

**明确不进清单**：`pyulog`、PX4 Flight Review。本项目只有 MAT/CSV，**没有 ULog**；引进来只会让人误以为"还得转 ULog"。

**表 C · 不自己写**：渲染器（Open3D/PyVista/VTK）、播放器/时间轴、MAT 解析器、四元数库、曲线 UI、MATLAB 自绘 3D 动画（`flight_view_app` 在仓库里不存在）。

**表 D · 必须自己写**（没有第二个 SHC09 可抄）：坐标映射（NED→ENU、机体 x左/y前/z下、ψ=0→东）、字段契约（`L`/`r`/`c` 与时间基准三分支）、六舵语义（`P_cs`、l1/l2、切向铰链、command vs actual）。

**对照：参考 → 我们的模块**

| 参考 | 落到哪 |
|---|---|
| Rerun blueprint 示例 | `cli.py` 的 blueprint 构造、`scene.py` 的视图 ID |
| Rerun dna 示例 | `geometry.py` 的 `Transform3D` 树：`/world` → `/vehicle` → `/vehicle/vane/{i}` |
| Rerun any_scalar 示例 | `layers.py::scalars()`（v0.1 只 3 条曲线） |
| PlotJuggler | `docs/flight_replay.md` 的"曲线兜底"一节（不写代码） |

**许可**：`rerun`（Apache-2.0/MIT）、`scipy`（BSD-3）、`pytransform3d`（BSD-3）可用；`PlotJuggler`（GPLv3）只读交互。拷代码前查 LICENSE 并登记 `THIRD_PARTY_NOTICES.md`；只借鉴设计不登记，但文档写清来源。

---

## 8. 场景规格（v0.1 画这些，不多画）

| 元素 | Rerun entity | 表达 | 颜色 |
|---|---|---|---|
| 地面网格 | `/world/grid` | 1 m 网格线，10×10 m，z=0 | 深灰 |
| 原点/指北 | `/world/axes` `[N]` `[E]` | 箭头 | 白/灰 |
| 参考轨迹 | `/traj/reference` | 折线，2 px | 灰 (150,150,150) |
| 实际轨迹 | `/traj/actual` | 折线，3 px | 方法色 |
| 估计轨迹（lite） | `/traj/estimated` | 虚线/细线 | 青 (0,200,200) |
| 目标 ghost | `/target/ghost` | 半透明小球 r=0.15 m | 白 25% |
| 机体 | `/vehicle/body` | 盒子 + 三个短轴（x 左/y 前/z 下） | 中灰，轴 RGB |
| 涵道环 | `/vehicle/duct` | 圆环线（0.30/0.28） | 深灰 |
| 桨盘 | `/vehicle/fan` | 细圆（0.114） | 暗青 |
| 六舵 | `/vehicle/vane/{i}` | 小矩形，绕切向轴转 `actual_delta` | 按 `δ/cm` 蓝→红 |
| 六舵命令 | `/vehicle/vane_cmd/{i}` | 半透明叠加 | 同上，alpha 0.25 |
| 姿态误差 | `/signals/attitude_error` | 标量序列（v0.1 仅此 3 条曲线） | 橙 |
| 位置误差 | `/signals/position_error` | 标量序列 | 紫 |
| 六舵角 | `/signals/vane/{i}` | 标量序列 | 同舵色 |
| 饱和 | `/events/saturation` | 区间高亮 + 顶部标记 | 红 |
| 气动越界 | `/events/aero_extrapolation` | 标记（有则画） | 红 |

PWM 时刻、`pwm_command`、`solver_exitflag`、residual 曲线**移到 v0.2**；v0.1 的 PWM/求解信息看 `pwm.csv`（PlotJuggler 直接拖入），不搬进 `.rrd`。

方法配色固定：`DA_NS` 蓝、`WLS` 绿、`DCA` 橙、`PCA_STATIC` 紫、`PCA_PREDICTIVE` 红、`EXAMPLE_PINV` 棕。写进 `layers.py` 常量，别每处现编。

**Blueprint**：左 3D 视图 + 右侧 2 个时间序列视图（姿态/位置、六舵）。Rerun 0.4x 的 blueprint API 变动频繁，**M0 先用 20 行 smoke 脚本确认本机 0.41 的真实 API 名**（`Scalar` vs `Scalars`、`save` vs `RecordingStream.save`），再写模块；不确定就退化为"不设 blueprint，viewer 手工布局"，不阻塞验收。

---

## 9. 里程碑（时间盒 + 验收）

### M0 — 骨架、环境、API smoke（0.5 天）

- 建目录、`requirements.txt`（`rerun-sdk==0.41.0`、`scipy`、`pytest`、`numpy`）、`.gitignore`、`replay.py --help` 空壳。
- 20 行 smoke：建一个 `RecordingStream`、写 10 个点、存 `results/viz/smoke/smoke.rrd`、用 `rerun` CLI 打开一次。
- **30 分钟读官方示例**：`examples/python/blueprint`、`examples/python/any_scalar`、`examples/python/dna`；把实测可用的 API 名（`Scalar`/`Scalars`、`save`/`RecordingStream.save`、blueprint 类名）写进 `viz/README.md` 的"API 备忘"。同时跑 `rerun --help`，记下保存/截图参数（具体名以本机 `--help` 为准）。
- **验收**：`.rrd` 存在且 >1 KB；`python viz\replay.py --help` 有输出；`pytest --collect-only` 能跑；`viz/README.md` 有"API 备忘"段；`git status` 只有 `viz/` 新增。

### M1 — 读取、时间基准、坐标、几何（1 天）

- `mat_io.py`：两种输入、时间规则、校验、字段白名单。
- `frames.py`：ZYX→R→quat、NED→ENU、连续化、`det` 检查。
- `export_geometry.m` → `geometry/shc09_geometry.json`（含 sha256）。
- `tests/`：合成 `L`（1601 点、悬停、yaw=0），覆盖时间基准三分支。
- **验收**：`pytest viz/tests -q` 全绿；用 2 s 夹具打印 `n=1601, t∈[0,2], dt=0.00125`；同一日志两次 `export_geometry` 哈希一致；`check_frames.m` 的三个数值与测试期望一致。

### M2 — 3D 场景（1.5 天）

- `scene.py` + `layers.py`：§8 表的全部 3D 元素。
- 六舵按 `actual_delta_rad` 动画；命令半透明；饱和标红。
- **验收**：2 s 与 20 s 日志各出一张 `.rrd`；viewer 里拖时间轴，机体/舵连续无跳变；20 s 里能看到参考轨迹与实际的偏差；截图 ≥2 张进 `viz/examples/flight_replay/`。

### M3 — 曲线（只 3 条）、事件、manifest（0.5 天）

v0.1 **只做 3 条曲线**：姿态误差、位置误差、六舵角；再加饱和/越界两类事件 marker（几乎零成本）。PWM、`solver_exitflag`、residual 一律不做——它们已经在 `pwm.csv` / `control.csv` 里，用 PlotJuggler 直接拖入即可。

- `layers.py::scalars()`、事件标记、`manifest.json`。
- **验收**：3 条曲线抽 3 个时刻与 `control.csv` 对得上（容差 1e-6，注意 CSV 里角度是**度**）；同输入两次 manifest 除 `created_at` 外一致；`--rate` 分支有警告且被记录；文档里有"用 PlotJuggler 看全量曲线"的 3 行命令。

### M4 — 文档、示例、tag（0.5 天）

- `docs/flight_replay.md`：坐标约定表、用法、字段来源、限制、示例截图、与 `HANDOFF §10` 的差异、曲线兜底路径。
- `viz/README.md` 30 行；根 `README.md` 只加"可视化（可选）"一小节（这是 v0.1 唯一允许改的既有文件，且只加不删）。
- tag `viz-preview`；`docs/flight_replay.md` 顶部"状态"块写清已完成/未完成。
- **验收**：按文档从干净 worktree 跑通；`git diff main -- '*.m' ':(exclude)viz/**'` **为空**；14/6/基线回归全过。

**总预算 3.5–4.0 天（含 0.5 天缓冲）。** 超时就砍：先砍 lite 估计轨迹层，再砍 blueprint 布局，最后砍六舵命令半透明叠加；**不砍**的是 §6 的坐标单测、M3 的 3 条曲线和 §10 的回归门禁。

---

## 10. 验收清单（Definition of Done）

```powershell
cd E:\Ducted-Fan-SHC09-viz
# 1) 测试
.\.venv-viz\Scripts\python.exe -m pytest viz\tests -q
# 2) 一条命令出回放（headless，无 viewer 也应成功）
.\.venv-viz\Scripts\python.exe viz\replay.py `
  --log results\viz_20s_ideal_DCA\DCA\log.mat `
  --out results\viz\viz_20s_ideal_DCA --rate 800
# 3) 数值未变（关键门禁：只允许 viz/ 下新增）
git diff --stat main -- '*.m' ':(exclude)viz/**'
# 4) MATLAB 回归（在 viz worktree 里跑）
matlab -batch "cd('E:\Ducted-Fan-SHC09-viz'); ca_setup; run_project_tests(false); run_platform_tests; test_platform_baseline;"
```

- [ ] 一条命令、headless、无需 viewer 即可产出 `.rrd` + `manifest.json`
- [ ] 两份真实日志：2 s ideal、20 s ideal（或 lite）
- [ ] `pytest` ≥ 6 项，覆盖时间基准三分支、朝向、ENU 变换、舵位置、饱和判定、manifest 稳定性
- [ ] 3 条曲线 + 2 类事件；PWM/求解走 CSV 兜底且在文档里写清
- [ ] 14/14 项目测试、6/6 平台测试、冻结基线全过（未改数值，应全过；若不过就是越界了）
- [ ] `docs/flight_replay.md` 含约定表 + 限制 + 截图
- [ ] tag `viz-preview`，分支 `viz-replay` 已 push（可以要求人工确认后再 push）
- [ ] `manifest.json` 能回答：这是哪条日志、哪个 git 版本、哪份几何、什么时间基准

---

## 11. 风险与对策

| # | 风险 | 触发信号 | 对策 |
|---|---|---|---|
| R1 | `rerun-sdk` 0.41 没有 cp313 wheel | `pip install` 无匹配版本 | 先用 `--only-binary=:all:` 试；失败就换 `D:\app\python_manager\3.12*\python.exe` 建 venv，**不改全局 Python**，并把决定写进 README |
| R2 | 本机 GPU/驱动跑不起 viewer | `rerun` 启动报 Vulkan/DX12 | 验收降级为 `.rrd` 非空 + 官方截图参数（M0 验证）；PNG 用 `rerun` 自带截图，不用 matplotlib 重画 |
| R3 | 类型 B 日志无时间向量 | `L` 里找不到 `time_for_metrics`/`r` | `--rate` + manifest 记录；正式证据只用类型 A |
| R4 | 姿态镜像/转向反号 | 机身"右转左转"看着别扭 | §6.3 的 ENU + `det` 检查；`test_frames` 冻结 MATLAB 打印值 |
| R5 | 18 MB×N 日志内存/耗时 | 单文件 load 数秒、批量爆内存 | 只 `variable_names` 白名单；一次一个文件；不做全目录默认扫描 |
| R6 | 几何与实机不符被误读 | 读者问"这是实机尺寸吗" | §6.6 的 `assumed` 字段 + 文档 + 截图标注 |
| R7 | 范围蔓延到 v0.4 | 开始"顺便"修比较器 | 红线 §3；v0.1 只碰 `viz/` |
| R8 | 与 `comparison-ready` 冲突 | 想 switch 过去看日志 | 只读绝对路径，不切分支；需要新日志就在 viz worktree 自己跑 |
| R9 | 看示例看上头，把项目带成 Web/ROS 平台 | 开始讨论 MCAP、ROS bridge、浏览器部署 | §2 非目标；§7.1 只列"能落到 MAT/CSV 上"的参考 |

---

## 12. 陷阱清单（我从源码里核对出来的，逐条都踩过或差点踩）

1. **ψ=0 → 东**（§6.2）。写"航向"前先跑 `check_frames.m`。
2. **NEU 是镜像**（§6.3）。四元数必须从 `det=+1` 的旋转来。
3. **`platform_run` 的 `log.mat` 没有时间向量**（§5.3）。`L.time_for_metrics` 只在比较日志里有。
4. **`comparison.mat` 内嵌全仓库源码**，几十 MB，别整体 load。
5. **CSV 里角度是度、轴角是度/秒**（`ca_write_logs.m` 里 `rad2deg`）；MAT 里是弧度。对不上先怀疑单位。
6. **PWM 事件数 ≈ 333·T，不是 800·T**；`pwm_command_rad` 是锁存命令，不是控制率命令。
7. **lite 的 15 s 对准在仿真前**（`ca_prepare_experiment` 多生成 `warm` 个样本），日志 `t=0` 就是任务段，不要把 warmup 当飞行段。
8. **M4/lite 是 stress 演示**（96% 饱和、59° 姿态峰值），回放它会很"刺激"，但不能当失稳结论或方法排名。
9. **`results/` 已在 `.gitignore`**：`results/viz/` 天然被忽略；示例图要复制到 `viz/examples/` 才会进 Git。
10. **Rerun 0.4x API 改名频繁**，旧博客/旧示例里的 `Scalars`、`rr.save` 可能已经变了；以本机 `--help` 和 `dir(rr)` 为准，别照抄。

---

## 13. 与 HANDOFF §10（旧"v0.5 候选"）的差异

| 条目 | 旧计划 | 本计划 v0.1 | 原因 |
|---|---|---|---|
| 显示坐标 | `[north, east, up]` | **ENU** `[E,N,U]` | NEU 相对 NED 是镜像，四元数无法表示 |
| 几何来源 | "写成可复用模块" | **MATLAB 导出 JSON + sha256** | 避免 Python 复制常数、漂移无人发现 |
| 时间基准 | 未提 | **三分支规则 + `--rate`** | 类型 B 日志没有时间向量 |
| 备选方案 | MATLAB `flight_view_app` | **暂不提供**（该文件不存在） | grep 确认仓库无此文件，别照抄 |
| 产物 | 只有 `.rrd` | **`.rrd` + `manifest.json`** | 与仓库的证据/溯源风格一致 |
| 开源借鉴 | 未提 | **§7.1 固定清单**（Rerun 三示例、PlotJuggler、pytransform3d） | 防止重复造轮子，也防止被无关生态带偏 |
| 分支 | `viz-replay`，从 `main` | 同（已建） | 不把 v0.4 WIP 带进来 |
| 文档位置 | `docs/flight_replay.md` | 同，另加本计划文件 | — |

---

## 14. 交接与更新协议

- **状态写在哪**：`docs/flight_replay.md` 顶部"当前状态"块（日期、M0–M4 进度、下一命令、已知问题）。**v0.1 期间不编辑 `HANDOFF.md`**——它在 `comparison-ready` 上也有一份，双分支编辑必然冲突；等 v0.5.0 发布时再统一更新。
- **提交粒度**：`viz: ...` 前缀，一个里程碑 2–4 个 commit；`docs: ...` 单独提交。不要一个 commit 混 MATLAB/Python/文档。
- **push**：M1 通过后 `git push -u origin viz-replay`（新分支，首次 push 前跟人确认一次即可）。
- **合入**：等 v0.4.0 有 tag 后，`viz-replay` 再 `--no-ff` 合入 `main`，然后打 `v0.5.0`；合并前在合并结果上重跑 §10 的 4 条命令。
- **每次会话结束**必须写：进度、下一命令、失败/未运行项、证据路径。让下一个 agent 不用重新核对仓库。

---

## 15. 开放问题（需要人或上游决定，不要自己拍）

1. lite 的估计轨迹层要不要进 v0.1？（默认**进**，成本低、信息量大；但会让"真值/估计"混读，必须图例区分）
2. 要不要 MP4/GIF 给论文用？（默认**不要**，PNG 截图够；要视频放 v0.2）
3. 涵道环/机体外形要不要更真实？（需要实机尺寸；默认**不要**，保持示意并标注）
4. 分支是否直接叫 `viz-replay`，还是按版本 `viz/v0.1`？（默认 `viz-replay`，与仓库现有 `*-*` 命名一致）

---

## 16. 给新 agent 的开场指令（可直接粘贴）

> 接手 `E:\Ducted-Fan-SHC09-viz`（分支 `viz-replay`，基线 `main`@`e662e7d`）。先读 `docs/viz_replay_plan_v0.1.md` 的 §0–§6 和 §7.1，再读 `docs/flight_replay.md`（若已存在）。从 M0 开始（含 §9 M0 的 30 分钟示例阅读），按 §4 建 venv。**不要**碰 `comparison-ready`、不要改 `viz/` 外的 `.m`、不要引入 §7.1 之外的新依赖。每个里程碑结束跑 §10 的门禁，并把状态写进 `docs/flight_replay.md` 顶部。
