# SHC09 飞行日志回放（viz）

把 MATLAB 已经存好的 `.mat` 飞行日志转成 Rerun `.rrd` 3D 回放，**只做后处理**：
不改任何数值代码、不嵌入仿真循环、不做实时。数据契约与坐标约定见
`docs/viz_replay_plan_v0.1.md` §5–§6，完整说明见 `docs/flight_replay.md`。

## 安装与运行

```powershell
D:\app\python_manager\3.13.0\python.exe -m venv .venv-viz
.\.venv-viz\Scripts\python.exe -m pip install -r viz\requirements.txt

# 一条命令（headless，不需要 viewer）：
.\.venv-viz\Scripts\python.exe viz\replay.py `
  --log results\viz_20s_ideal_DCA\DCA\log.mat `
  --out results\viz\viz_20s_ideal_DCA --rate 800

# 看回放（可选）：
.\.venv-viz\Scripts\python.exe viz\replay.py --log ... --out ... --viewer
```

产物：`<out>\replay.rrd` + `<out>\manifest.json`（日志 SHA256、git SHA、几何哈希、
rerun/scipy 版本、`n`、时长、`time_base`）。

`--rate` 只对**没有时间向量**的平台日志（`results/<tag>/<METHOD>/log.mat`）生效；
比较日志（`logs/*.mat`）优先用 `L.time_for_metrics`。`assumed_rate` 会在 stderr 警告并写进 manifest。

## 显示约定（不要凭感觉改）

- 显示系 **ENU**（x 东、y 北、z 上），由 NED 经 det=+1 的旋转得到；不用 NEU（镜像）。
- 机体 **x 左、y 前、z 下**：ψ=0 时前向是**东**，不是北。
- 曲线角度单位是**度**，位置误差单位是 **m**；MAT 里是弧度，这里已换算。
- 几何是**示意**：涵道 0.30/0.28 m、桨盘面积等效半径 0.114 m、机体 0.18×0.18×0.35 m，
  不声称与实机外形一致（见 `geometry/shc09_geometry.json` 的 `assumed`）。

## API 备忘（rerun-sdk 0.41.0，本机实测，别照抄旧博客）

| 事项 | 0.41 的实际名字 |
|---|---|
| 标量 | `rr.Scalars(...)`（不是 `rr.Scalar`） |
| 保存 | `rec = rr.RecordingStream("shc09_viz"); rec.save(path)` |
| 时间轴 | `rec.set_time("time", duration=秒)`；`rr.set_time` 只作用于线程默认流，别混用 |
| 去掉 log_time | `rec.set_log_time_enabled(False)`；时间面板用 `rr.blueprint.TimePanel(timeline="time")` |
| 蓝图 | `rr.blueprint.{Blueprint,Horizontal,Vertical,Spatial3DView,TimeSeriesView,EyeControls3D,TimePanel}` + `rec.send_blueprint(bp)` |
| 截图 | `rerun <rrd> --screenshot-to out.png --window-size WxH`（见 `tools/screenshot.py`） |

Rerun 的 TEMP 目录必须可写；本沙箱里系统 TEMP 不可写，`tools/screenshot.py` 会把
`TEMP/TMP` 指到仓库内 `.tmp/`。0.41 的 `Points3D` 球体不透明，所以目标 ghost 用三圈线框球。

## 测试

```powershell
.\.venv-viz\Scripts\python.exe -m pytest viz\tests -q
```

## v0.1 非目标

实时渲染、ULog/PX4 路线、多方法叠加、MP4/GIF、真实外形、用回放做方法排名。
PWM 时刻与 `solver_exitflag` 曲线留到 v0.2；v0.1 用 `pwm.csv`/`control.csv` 直接看
（PlotJuggler 拖入即可，见 `docs/flight_replay.md`）。
