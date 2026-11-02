# 风迹 WindTrace：单飞行日志

本分支将WindTrace的模型资产与GLB解析代码适配到 `windtrace.flight.v1`。一次运行一个 `.wtr`，控制分配方法仅是元数据；可以同时打开任意数量的独立日志叠加曲线。新入口只接受.wtr，不接受旧MAT／五方法bundle。

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
python app.py flight1.wtr flight2.wtr
python app.py --smoke flight1.wtr
python app.py flight1.wtr --screenshot preview.png --time 15.5
```

`--smoke`纯后台校验；`--screenshot`默认离屏执行，不占桌面。界面沿用原版52px顶栏、左侧浮动抽屉、底部曲线抽屉、48px时间轴，默认三维占约89%高度。左侧“显示 → 显示状态”可切换真实状态／估计状态：前者按实际位置与姿态，后者按机载估计器认为的位置与姿态移动。默认真实状态，机体显示随之切换，参考轨迹由“场景 → 显示参考轨迹”开关控制，默认关闭；不绘制实际／估计轨迹；不把规划姿态作为第三种飞机状态。该选择只影响显示，不修改控制参数或日志。Tab切换左抽屉，C切换曲线，Space播放，Esc收起。三维当前显示选中飞行；曲线按共同字段叠加已打开的独立飞行，保留各自时间轴，不插值对齐，也不提供排名。主画面不显示英文调试／审计说明。地面网格沿用原版1m细线／5m主线和远处淡出，世界ENU高度0，默认开启，可在“场景”关闭；保留机体视角与总览视图。流畅／节能回放分别使用16ms／33ms计时档，曲线游标独立限频，隐藏曲线不刷新。

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

运行测试需另安装pytest。真实日志GUI测试由 `WINDTRACE_TEST_FLIGHTS` 提供三个路径（本机路径分隔符分隔，顺序：15Hz预测PCA／标称DA_NS／PPID DCA）；未提供时该项明确skip，其余格式测试仍可运行。测试使用离屏Qt；不移动鼠标，不回写日志。

来源与许可见 [IMPORT_PROVENANCE.json](IMPORT_PROVENANCE.json)、[LICENSE](LICENSE) 和 [第三方说明](THIRD_PARTY_NOTICES.md)。模型是示意资产，舵面轴及比例不等于实机标定；参考姿态模式无执行器参考，故不展示推造的参考舵面动作。

## Windows可执行包

安装位置：`E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe`。源码、打包入口与运行包统一归属本项目的apps/windtrace目录。现有桌面／开始菜单快捷方式已更新，不需要命令行或另装Python；不要将exe与_internal目录拆开。dist由本目录.gitignore排除，源码与轻量证据进入Git，EXE／DLL不进入Git。旧E盘独立应用目录及其备份保留作回滚，不再是快捷方式的目标；开发验证使用的外部虚拟环境只是本机构建工具，新运行包不依赖它。

重新构建使用 `build_app.ps1 -PythonExecutable <python.exe> -OutputDirectory <全新目录>`，spec随源码保存；构建过程隔离PATH，避免收进其他工具的同名DLL。打包后的--smoke配合--report可落盘校验，--screenshot支持--panel parameters/curves与--search字段。

默认“跟随机体”只平移相机，不跟随飞机偏航，保留观察方向；总览视图会关闭跟随，回到机体视角会重新开启。

旋转／平移／缩放时，裁剪范围覆盖地面网格，拉远时自动扩展；网格不参与机体取景边界，不会把默认机体视角拉得很远。网格仍可开关；朝向天空等看不到地面的位置时，不会伪造屏幕网格。打开卡片固定420逻辑像素宽、高度随内容变化，主按钮44逻辑像素内容高，去掉多余底部留白。最新验证和迁入apps路径记录见 [报告13](../../codex-repo-13.md)。

首次无日志启动会显示“打开一份飞行日志”，此时播放、时间轴、曲线和导出不可用。点击中央按钮或右上角“打开”选择.wtr；文件读取与校验在后台进行，界面显示加载提示，失败则显示原因并允许重新选择。成功打开会记住最近日志和目录，下次正常启动自动恢复最近仍存在的日志。新打开的日志会成为当前三维显示对象。最近记录是本机查看器设置，不写进.wtr或仿真参数。

本机现有样例：`E:/Ducted-Fan-SHC09-matlab/results/windtrace_integration_20261102_r1/deliveries/filter15_PCA_PREDICTIVE_s501.wtr`。它来自已有40秒飞行日志，无须重飞。修复与更新记录见 [报告12](../../codex-repo-12.md)。开发验证可用 `--settings-file <独立.ini>` 隔离最近文件记录；离屏截图默认不恢复／改写用户最近文件。
