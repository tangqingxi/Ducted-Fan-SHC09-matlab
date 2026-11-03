# 风迹 WindTrace：单飞行日志

v1.0 增加相机模式与可导入的运镜脚本、示意模型按几何底点贴地、浅色分层界面，并把“最近日志列表、双击打开”做成欢迎页默认行为。一次运行只打开一个 `.wtr`，控制分配方法仅是元数据；需要比较不同方法时再开一个 WindTrace 窗口，各窗口用同一相机预设和相同时刻。三维世界系默认 **NED**，可在“场景 → 世界坐标系”切到 **ENU**；机体坐标系开关默认关闭，打开后按手绘图：x红向右、y绿向下、z蓝穿入纸面（下）；即FRD绕z转90°（x=+y_FRD，y=−x_FRD，z=+z_FRD），右手系，仅显示。新入口只接受.wtr，不接受旧MAT／五方法bundle。

内部控制代码保持项目命名。PX4风格映射在离线导出层完成，Viewer显示topic.field、单位和数据域；这不是ULog，不承诺PX4二进制兼容。

## 环境与启动

Python 3.13，依赖见 [requirements.txt](requirements.txt)。首次在本目录创建独立环境并安装：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\run_app.cmd E:\path\flight.wtr
```

也可以设置进程环境变量 `WINDTRACE_PYTHON` 指向已有兼容环境，再运行run_app.cmd。当前开发验证使用本机已存在的 `E:/Ducted-Fan-SHC09-app/.venv/Scripts/python.exe`，没有修改该环境。普通系统python未必有依赖。普通使用已完成EXE打包并安装到本项目apps/windtrace/dist下，双击桌面“风迹 WindTrace”即可；此EXE不依赖上述开发环境，详见 [报告13](../../codex-repo-13.md)。

```powershell
python app.py flight1.wtr
python app.py --smoke flight1.wtr
python app.py flight1.wtr --screenshot preview.png --time 15.5
python app.py flight1.wtr --screenshot orbit.png --time 20 --camera-mode orbit
python app.py flight1.wtr --screenshot mix.png --time 20 --camera-preset showcase
python app.py flight1.wtr --screenshot compare.png --time 20 --camera-preset analysis
```

`--smoke`纯后台校验；`--screenshot`默认离屏执行，不占桌面；`--drawer`把左侧抽屉展开到截图里；`--camera-mode`/`--camera-preset`/`--camera-file`用于复现某个相机状态；`--world-frame NED|ENU` 与 `--body-frame` 可复现世界系/机体系显示。界面沿用原版52px顶栏、左侧浮动抽屉、底部曲线抽屉、48px时间轴，默认三维占约89%高度。左侧“显示 → 显示状态”可切换真实状态／估计状态：前者按实际位置与姿态，后者按机载估计器认为的位置与姿态移动。默认真实状态，机体显示随之切换，参考轨迹由“场景 → 显示参考轨迹”开关控制，默认关闭；不绘制实际／估计轨迹；不把规划姿态作为第三种飞机状态。该选择只影响显示，不修改控制参数或日志。Tab切换左抽屉，C切换曲线，Space播放，Esc收起。三维与曲线都只显示当前窗口的这一份飞行；曲线保留原生时间轴，不插值对齐，也不提供排名。主画面不显示英文调试／审计说明。地面网格为1m细线／5m主线，世界采用NED（x北、y东、z下），地面为z=0、空中为负，默认开启，可在“场景”关闭。流畅／节能回放分别使用16ms／33ms计时档，曲线游标独立限频，隐藏曲线不刷新。

左侧抽屉“数据 → 查看飞行参数…”打开只读表，按完整路径、值、单位或来源搜索。点击行查看／复制完整值；大数组通过包内MAT引用展开，既不截断原值也不读取磁盘默认配置。有效控制参数以 `controller.*`列出，父快照在 `scenario.parent_controller.*`；两者不同就显示覆盖来源。未能恢复的字段显式为unknown，未知单位不猜测。

## 从已有日志导出

完整恢复MATLAB string推荐从MATLAB调用独立后处理入口：

```matlab
addpath('analysis');
export_windtrace_flight('results/<tag>/logs/<method>_s501.mat', ...
    'results/<new_delivery_tag>/flight.wtr', 'path/to/python.exe');
```

该函数只读保存的L/cfg/model/ref/plan等，临时转换MATLAB字符串，不启动仿真。新输出不得已存在。暂支持PPID／hover原生日志；旧F8日志需另写旧字段适配，不能直接用旧bundle导出器替代。

直接Python导出命令为 `python tools/export_windtrace.py source.mat new.wtr`（仓库根目录执行）。SciPy不能解析的MATLAB对象会标unknown；不能把这种降级输出当成完整参数交接。MATLAB入口导出的三份真实样例均unknown=0。

当前没有给冻结批驱动补自动导出钩子。新飞行包装入口应在一次保存日志完成后调用export_windtrace_flight，失败记录继续保留；不要重跑旧实验来生成新格式。

## 格式与验证

[格式契约](../../docs/interfaces/windtrace_flight_v1.md) · [本次交付报告](../../codex-repo-10.md) · [轻量验收证据](../../examples/windtrace_flight_20261102/README.md)

```powershell
python -m pytest apps/windtrace/tests -q
python tools/audit_windtrace.py source.mat flight.wtr new_audit.json
```

运行测试需另安装pytest（当前 58 项）。真实日志GUI测试由 `WINDTRACE_TEST_FLIGHTS` 提供三个路径（本机路径分隔符分隔；测试不依赖顺序，滑块与时间断言按各自 `duration_s` 计算）；未提供时该项明确skip，其余格式测试仍可运行。测试使用离屏Qt；不移动鼠标，不回写日志。

来源与许可见 [IMPORT_PROVENANCE.json](IMPORT_PROVENANCE.json)、[LICENSE](LICENSE) 和 [第三方说明](THIRD_PARTY_NOTICES.md)。模型是示意资产，舵面轴及比例不等于实机标定；参考姿态模式无执行器参考，故不展示推造的参考舵面动作。

## 欢迎页与最近日志

无文件启动时始终停在欢迎页，即使本机有历史记录也不自动读取。卡片列出最近 8 条日志：文件名、方法／种子／时长、路径；**单击选中、双击打开**（回车同样可打开）。失效路径会灰显并标注“文件不存在”，双击只给出“已移动或删除”的提示，不静默换文件、不自动删除；右键可“从列表移除”或清空。成功打开后写入本机 QSettings 的 `recent_files`，旧的单条 `recent_file` 会自动迁移。

命令行显式传入 `.wtr` 是用户主动选定，仍然直接打开。播放、时间轴、曲线与导出在未加载时保持禁用。最近记录只是查看器设置，不写进 `.wtr` 或仿真参数。

## 视觉与可读性

v1.0 起界面分三层：浅灰画布、白色卡片、明确描边；选中态用蓝色填充或淡蓝底，复选框、输入框、表格、列表和滚动条都有显式样式。三维场景用浅灰渐变背景、黑色 5 m 主线（40–65% 透明度）＋浅灰 1 m 细线与彩色坐标轴；地面退到背景层，黑色舵面恢复原色，无人机保持黑白主体。“导出 PNG”改为安静的 ghost 按钮，主色只留给欢迎页主按钮。

正文与次要文字在卡片上的对比度不低于 4.5:1（主文字不低于 7:1），参考线与模型描边对三维背景不低于 3:1，地面网格作为背景层只要求可辨（约 1.2:1）；`tests/test_theme_contrast.py` 会计算这些比值，改动色板时先跑它。

**转子与舵面**：舵面按 `shc09_vanes` 的 ±40° 日志角度绕各自铰链轴旋转，颜色为近黑；螺旋桨做**显示用**自转（名义 2 转/秒，可在“场景”关闭），日志没有 RPM 字段，因此不声称真实转速。

## Windows可执行包

安装位置：`E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe`。源码、打包入口与运行包统一归属本项目的apps/windtrace目录。现有桌面／开始菜单快捷方式已更新，不需要命令行或另装Python；不要将exe与_internal目录拆开。dist由本目录.gitignore排除，源码与轻量证据进入Git，EXE／DLL不进入Git。旧E盘独立应用目录及其备份保留作回滚，不再是快捷方式的目标；开发验证使用的外部虚拟环境只是本机构建工具，新运行包不依赖它。

重新构建使用 `build_app.ps1 -PythonExecutable <python.exe> -OutputDirectory <全新目录>`，spec随源码保存；构建过程隔离PATH，避免收进其他工具的同名DLL。打包后的--smoke配合--report可落盘校验，--screenshot支持--panel parameters/curves、--drawer、--camera-mode、--camera-preset 与 --camera-file。v1.0 的源码变更不改 `.wtr` 契约，旧容器仍可直接打开。

## 相机模式与运镜

“场景 → 相机模式”是一个下拉选择，默认“跟随”。相机只改变观察方式，不参与控制、估计或评价。

| 模式 | 具体行为 | 什么时候用 |
|---|---|---|
| 跟随（默认） | 保持你当前的观察角度，只随机体平移；鼠标拖动只改角度，不改跟随 | 一般回放 |
| 自由视角 | 相机完全手动，播放时程序不动相机 | 细看某一段 |
| 追尾 | 机体后上方固定偏移，随机体偏航转动 | 看航向、偏航 |
| 环绕 | 以机体为中心固定半径与仰角，可匀速扫过 | 看姿态、滚转 |
| 总览 | 按整段航迹包围盒取景，固定机位；飞机在画面里移动 | 全程一览 |
| 机体特写 | 三分之四视角特写，随机体平移；取景按真实网格包围盒 | 看舵面、细节 |
| 演示 · 发布镜头 | 0–12 s 环绕升降、12–15 s 阻尼追尾、15–27 s 扰动固定机位、27–37 s 恢复、37–55 s 收尾 | 产品展示 |
| 对比 · 固定机位 | 0–12 s 宽幅爬升、12–55 s 固定高 3/4 机位，时间口径一致 | 多窗口并排比较 |
| 特写 · 舵面 | 低角度跟随特写，看涵道与六舵面动作 | 执行器细节 |
| 导入运镜 | 按任务时间执行脚本，镜头可分段组合上述行为 | 自定义出片 |

鼠标在三维里拖动或滚轮缩放会立即切到“自由视角”，避免脚本和鼠标抢镜头；重新选择某个模式或运镜即可恢复。

“导入运镜…”读取 `windtrace.camera.v1` JSON，按**任务时间**求值，与回放倍速无关；拖动时间轴会立即跳到该时刻的镜头，不在拖动过程中做动画。镜头之间可以用 `transition_s` 平滑过渡，也可以硬切。格式、字段和校验规则见 [运镜格式契约](../../docs/interfaces/windtrace_camera_v1.md)，可直接打开的示例在 [assets/cameras](assets/cameras/README.md)（发布演示、对比分析、舵面特写、全程环绕、总览到特写）。

运镜编排建议（不是硬性门槛）：单镜头不短于约 2.5–3 秒，任意 15 秒内不超过 4–5 次镜头变化；起飞段用环绕/升降，滚转与扰动段用固定机位，偏航段用阻尼追尾；结尾回全景并停留约 0.8 秒。镜头切换用 Hermite 速度连续过渡（默认 1.2 秒），手动切换模式也有约 0.65 秒缓动；拖动鼠标会立即取消并切自由。

**多窗口对比**：一个窗口只保留一份飞行。需要比较 DA_NS／WLS 等方法时，再启动一个 WindTrace，打开另一份 `.wtr`，两边选“对比 · 固定机位”并把时间轴拨到同一秒。相机与时间不在窗口间自动同步，这是刻意保留的只读边界；不做跨窗口联动，也不在一窗口内叠加多方法。

**世界系**：日志和运镜脚本都按 NED（x北、y东、z下）存储/求值；显示层可在 NED 与 ENU（x东、y北、z上）之间切换。切换只改变画面与 HUD 的轴名/符号，不写回日志，也不改变相机脚本的 NED 坐标。机体系按手绘图画在机体上：x 红向右、y 绿向下、z 蓝向下（穿入纸面）；相对FRD是绕z转90°（x=+y_FRD，y=−x_FRD，z=+z_FRD），右手系。只影响画面，不改MATLAB数值。

## 显示约定

示意模型按几何底点贴地：加载日志后从机体网格现算最低点（当前 55 秒批次的示意模型为 **+0.235 m**），把机体、舵面和相机目标整体抬到地面之上。t=0 时脚架正好落在 NED z=0 的网格上，不再穿模；空中高度以负 z 表示。

这个抬升**只影响画面**：日志里的位置、姿态、指标和评价窗口都不变，也不写回 `.wtr`。数值在“场景”抽屉底部以灰字显示（“机体底点贴地：+0.235 m（仅显示，不改变日志数值）”），换模型时会随几何自动变化；“帮助”对话框里也有一句原则说明。

打开卡片固定 420 逻辑像素宽、高度随内容变化，主按钮 44 逻辑像素内容高。旋转／平移／缩放时裁剪范围覆盖地面网格，拉远时自动扩展；网格不参与机体取景边界，不会把默认机体视角拉得很远。“地面投影”从机体向地面画垂线和落点环；“参考误差线”在当前参考点画标记并连到机体中心，HUD 同步显示 `z` 与 `Δx/Δy/Δz`；两者都是显示层，不改日志或评价。

本机现有样例：`logs/wtr/hover_distance_takeoff_formal_20261103_r1/PCA_PREDICTIVE_s501.wtr`（55 秒正式批）与 `logs/wtr/precheck_20261103_r1/PCA_PREDICTIVE_s501.wtr`（50 秒预检），都来自已有飞行，无须重飞。开发验证可用 `--settings-file <独立.ini>` 隔离最近文件与相机设置；离屏截图默认不恢复／改写用户最近文件。
