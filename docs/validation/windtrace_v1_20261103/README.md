# WindTrace v1.0 验证记录（2026-11-03）

本目录保存 WindTrace v1.0 的界面／相机更新与离屏核验证据。应用源码在 `apps/windtrace/`，本次**没有**修改 `.wtr` 契约、控制、估计、分配、仿真或任何数值结果。

## 交付内容

| 项 | 说明 |
|---|---|
| 相机模式 | 跟随（默认）／自由／追尾／环绕／总览／机体特写；鼠标拖动自动切自由 |
| 内置预设 | 演示 · 发布镜头／对比 · 固定机位／特写 · 舵面；镜头用 Hermite 速度连续过渡，每镜独立 FOV |
| 转子与舵面 | 舵面按日志 ±40° 旋转并恢复近黑；螺旋桨做显示用 2 转/秒自转（可关，日志无 RPM） |
| 坐标系 | 日志与运镜脚本按 **NED**（x 北、y 东、z 下）存储/求值；显示层可在 NED 与 **ENU**（x 东、y 北、z 上）间切换，默认 NED |
| 机体系 | 可选显示：x 红右、y 绿下、z 蓝下；相对FRD绕z转90°（x=+y_FRD，y=−x_FRD，z=+z_FRD），右手系，随位姿平移/旋转；纯显示 |
| 分析叠加 | 地面投影、参考点与误差线、HUD 的 NED z 与 Δx/Δy/Δz；只影响画面 |
| 运镜脚本 | `windtrace.camera.v1`，按任务时间求值；格式见 [契约](../../interfaces/windtrace_camera_v1.md)，示例在 `apps/windtrace/assets/cameras/` |
| 贴地显示 | 按机体网格最低点抬升（当前示意模型 0.235 m），只影响画面；场景抽屉与帮助对话框均有说明 |
| 视觉 | 浅灰画布、白卡片、明确描边、蓝色选中；三维浅灰地面、黑色 5 m 主线与彩色坐标轴；补齐复选框／输入框／表格／列表／滚动条样式 |
| 欢迎页 | 启动不再自动恢复；列出最近 8 条，单击选中、双击打开；失效路径灰显提示，旧 `recent_file` 自动迁移 |
| 单飞行窗口 | 一个窗口只保留一份 `.wtr`；比较不同方法时开多个 WindTrace 窗口，各自用“对比 · 固定机位”并对齐时刻 |

## 截图

| 文件 | 内容 |
|---|---|
| `before_t0.png` | 更新前：t=0 脚架穿入地面，网格几乎不可见 |
| `after_t0_drawer.png` | 更新后：脚架贴地、NED HUD，场景抽屉含相机模式与贴地说明 |
| `welcome_recent.png` | 欢迎页最近日志（含一条“文件不存在”） |
| `closeup_t20.png` | 舵面特写预设（t≈20 s） |
| `preset_compare_t20.png` | 对比预设：NED 参考误差线与 HUD 的 Δx/Δy/Δz（t≈20 s） |
| `world_enu_t20.png` | 同一个对比镜头切到 ENU 显示（轴名 E/N/U，z 为正） |
| `body_frame_closeup.png` | 机体特写中打开机体系（x红右、y绿下、z蓝下） |
| `showcase_t20.png` | 发布演示 preset（t≈20 s 的固定机位段） |

截图均由离屏 Qt + VTK 生成，没有占用桌面鼠标；不启动仿真。

## 核验

- `python -m pytest apps/windtrace/tests -q`：**58 passed**（需要 `WINDTRACE_TEST_FLIGHTS` 提供真实 `.wtr`）。
- `python tools/check_docs_links.py`：79 份文档、573 个本地链接、0 断链。
- `contrast.json`：正文／次要文字／参考线与描边全部达标（文本 ≥4.5:1，主文字 ≥7:1，参考线/描边 ≥3:1）；浅灰地面上黑色 5 m 主线近处有效约 4.4:1、远处约 2.3:1，1 m 细线更淡（40–65% 透明度）。
- 已安装 EXE 五阶段离屏检查：6／14／21／32／52 s 全部返回 0，`view3d_available=true`、`ground_lift_m≈0.2352`、无错误。
- 构建与安装：`apps/windtrace/dist/WindTrace/WindTrace.exe`，SHA256 与字节数见 `checks.json`；桌面快捷方式仍指向该路径。

## 复现命令

```powershell
$env:WINDTRACE_TEST_FLIGHTS='E:\...\PCA_PREDICTIVE_s501.wtr;E:\...\DCA_s501.wtr;E:\...\DA_NS_s501.wtr'
E:\Ducted-Fan-SHC09-app\.venv\Scripts\python.exe -m pytest apps/windtrace/tests -q
python tools\check_docs_links.py
```

离屏截图示例（工作目录 `apps/windtrace`，一次一个 `.wtr`）：

```powershell
python app.py <flight.wtr> --screenshot out.png --time 20 --camera-preset showcase
python app.py <flight.wtr> --screenshot welcome.png --drawer
```

## 边界与已知限制

- 相机、NED 显示、贴地与叠加都是**显示层**：不改日志位置、姿态、指标或评价；不能据此声称飞行效果变化。
- NED 的 z 在空中为负（例如悬停 z≈−10 m），ENU 的 z 为正；HUD 随世界系切换，运镜脚本始终按 NED 解释。
- 机体显示是与图中vane编号一致的右手系（x左/y前/z下），不是FLU；MATLAB导出的几何/数据仍是FRD（x前、y右、z下），Viewer只改显示轴。
- 抬升量随加载日志的几何计算（当前 0.235 m）；换模型时数值会变，场景抽屉显示实际值。
- 运镜脚本只描述相机；不含关键帧录制、自动剪辑或多机位切换。
- 本机 PowerShell 5.1 直接执行 `build_app.ps1` 时会因 UTF-8 无 BOM 的中文注释解析失败；本次用等价参数直接调用 PyInstaller，脚本未改。用 PowerShell 7 执行不受影响。
- 本次未提交、未 push、未打 tag；`dist/` 仍由 `.gitignore` 排除。
