# WindTrace单飞行交付与界面迁移报告

日期：2026-11-02，Asia/Shanghai。工作目录 `E:/Ducted-Fan-SHC09-matlab`，分支 `WindTrace_merge`，基底 `2590949cce6b62cd9022e3ac9717a269d100cd30`。本轮不提交、不推送、不合并main；没有运行任何飞行仿真。

## 完成内容

实现单飞行 `windtrace.flight.v1`／`.wtr`：一次保存的PPID／hover飞行对应一个自包含交付物，控制分配方法为元数据字段；不依赖五方法bundle。内部控制源码、命名、参考、参数与冻结协议保持原样。完整实现包括：

- [MATLAB导出入口](analysis/export_windtrace_flight.m)：读取原日志，临时转换MATLAB string，调用Python导出；不调用仿真。
- [Python导出](tools/export_windtrace.py)及 `apps/windtrace/core/exporter.py`：生效参数、原时间轴、PX4风格topic、来源／执行／审计记录、成员SHA和FRD几何。
- `apps/windtrace/core/flight.py`：严格容器读取，不解压到外部目录；检查schema、成员、哈希、形状、时间、四元数和核心topic。
- [WindTrace应用](apps/windtrace/README.md)：多个独立.wtr选择、原生时间轴曲线、三维回放、真实／估计状态切换、只读参数搜索和完整值复制、来源／审计查看。
- [独立导出核验](tools/audit_windtrace.py)和新增测试；[格式契约](docs/interfaces/windtrace_flight_v1.md)固定命名、单位、坐标及参数来源规则。

没有拷贝旧study／bundle入口或修改冻结批驱动。本阶段交付支持“已有日志 → 一份.wtr”；未来新飞行包装入口在保存后自动调用导出器尚未接入。不能因此重跑旧实验。

## 保留原界面审美及飞机配色

首版集成曾误用常规标签页，用户指出失去原风格后，已改回原版布局和设计系统：52px顶栏、logo／面包屑／打开／重载／导出／帮助、左侧36px图标轨与220px浮动抽屉、底部可拖动曲线抽屉、48px常驻时间轴。默认三维区域占窗口高度88.89%，打开抽屉不会挤压视口或重置相机。无常驻大参数表或标签页。按用户后续要求，三维默认仅飞机与地面网格，不绘制真实／估计轨迹；参考轨迹默认关闭，可独立打开。显示状态仅有真实状态／估计状态两项，默认真实状态；主画面去掉英文Replay水印。网格保留原版灰度、1m／5m线距与淡出，提供独立开关。

新增参数列表从左抽屉“数据 → 查看飞行参数…”打开。沿用原shell/theme和方法配色，来源清单见 [IMPORT_PROVENANCE.json](apps/windtrace/IMPORT_PROVENANCE.json)。图标采用矢量，避免离屏字体缺字；Qt／VTK离屏截图显式合成，避免空白三维子窗口。

飞机材质已按源项目核对恢复：机身 `#2B2D31`、泡沫涵道白 `#FFFFFF`、转子／脚架 `#1A1B1D`、舵面 `#232529`，按原网格part编号映射，保留原明暗处理。去掉了首版误加的亮蓝舵面。方法颜色用于轨迹／标识，不给飞机换色。

源项目为 `E:/Ducted-Fan-SHC09-matlab-merge` 的 `merge/windtrace-v02@1bbdb51b278bc9ce8a50965a40808acae314c56b`，只读。复用其logo、GLB、几何来源JSON、解析器与shell/theme，保留许可与来源；没有覆盖当前控制器、模型、协议或交接文档。

## 三份真实日志验证

完整.wtr位于本机 `results/windtrace_integration_20261102_r1/deliveries/`。不是新飞行，也不是新的五方法正式批。

| 交付文件 | 原日志 | 时长 | 参数项 | topic | 状态／控制／PWM点数 |
|---|---|---:|---:|---:|---|
| nominal_DA_NS_s501.wtr | hover标称DA_NS s501 | 40s | 378 | 18 | 32001／16001／13321 |
| filter15_PCA_PREDICTIVE_s501.wtr | hover H15/H15预测PCA s501 | 40s | 378 | 18 | 32001／16001／13321 |
| ppid_DCA_s401.wtr | PPID八字DCA s401 | 52s | 315 | 18 | 41601／20801／17317 |

三份经MATLAB标准化导出的参数unknown均为0。滤波日志可搜索 `controller.indi_output_filter_hz`，看到生效15 Hz、父快照8 Hz及覆盖来源；cfg中保留的原值没有冒充生效plan值。大数组原值保存在包内MAT，用参数引用展开；无限阈值用显式special_float保存，不转0或未知。

DA_NS的execution=completed，原audit仍为failed；原失败原因继续显示，未更改旧status、completion或容差。独立导出审计验证的是格式转换一致性，不把原实验门禁失败改成通过。

独立核验中，估计／真值／参考位置、原舵角、原命令、PWM及时间轴最大差均为0；姿态由独立手写旋转矩阵公式核对，三份最大差分别约5.55e−16、5.55e−16、5.93e−16。INDI分量按坐标重排核对一致。所有实际controller参数与原日志保存的plan一致。

## 测试与证据保护

新增测试 **15/15通过**：原生多速率时钟、数据域分离、需求坐标转换、任意方法名、父参数覆盖、Inf／NaN和大数组保存、180°附近姿态、不覆盖、旧格式拒绝、哈希／成员／schema／时间／形状／四元数损坏拒绝、参数搜索与只读、多日志切换／曲线及抽屉布局。实际证据见 [轻量包](examples/windtrace_flight_20261102/README.md) 的JUnit与JSON。

离屏Qt／VTK核验三维可用、7个飞机部件actor、3个独立日志曲线、378项参数和2项匹配搜索结果；实际窗口曾短暂核对搜索生效值，随后关闭。按用户要求已释放Computer Use会话，最终截图与验证均使用后台离屏方式，无鼠标／键盘注入。

运行前保存1358项已有文件／代表原始日志SHA；结束核验1355项字节不变，已有文件中仅AGENTS.md、HANDOFF.md、README.md更新当前交接。原数值源码、冻结协议／锁、旧轻量包及三份原始MAT保持原样，main仍为9918d9d。没有更改旧回归失败或LitePhysicalBias门槛，也没有运行会写旧results/validation的项目测试。

新输出目录内保留早期导出／界面适配失败及中间版本；最终以deliveries目录和轻量包manifest为准，没有覆盖原始研究结果。完整真实.wtr约17–31MB／份，仅留results；Git候选轻量包只包含截图、审计摘要、清单和约0.37MB的明确标注为合成的格式样例，没有原始MAT或构建缓存。

## 使用与限制

依赖为Python3.13＋NumPy／SciPy／PySide6／PyVista／pyvistaqt／pyqtgraph。本机验证复用 `E:/Ducted-Fan-SHC09-app/.venv/Scripts/python.exe`，未修改其环境。启动、完整导出和新环境安装方式见 [应用README](apps/windtrace/README.md)。

```powershell
$env:WINDTRACE_PYTHON='E:\Ducted-Fan-SHC09-app\.venv\Scripts\python.exe'
.\apps\windtrace\run_app.cmd .\results\windtrace_integration_20261102_r1\deliveries\filter15_PCA_PREDICTIVE_s501.wtr
```

当前没有打包新EXE；旧F8字段适配尚未实施；未来新飞行包装入口的自动导出待接入。直接SciPy导出无法解析的MATLAB对象会显式标unknown，完整参数交接应使用MATLAB入口。未记录的原始传感器topic仍缺失，不从真值补造。

曲线允许并列打开不同场景，示例截图包含hover和八字，只用于验证加载能力，不构成同协议性能对比。三维几何为示意，FRD转换不代表实机标定。本次工作不改变滤波调参结论，也不授权新的15条正式飞行。

## 回放流畅度测量与优化

参考 [Gazebo Classic官方GUI教程](https://classic.gazebosim.org/tutorials?cat=guided_b&tut=guided_b2) 中以Scene为主、可控制可见性的布局思路，同时保留本项目原版机体取景。这里只借鉴呈现方式，没有引入Gazebo运行时。

本机RTX 5060 Laptop GPU，1360×900窗口、300帧后台同步渲染：优化前关闭／打开曲线的p50分别1.2765／11.08085ms，优化后1.3301／11.44995ms。单帧耗时没有下降，不能宣称渲染算力提升；曲线重绘仍明显更重。两次测量各自max均低于16.67ms，但不据此保证桌面60FPS。

已实施的节奏优化：关闭QtInteractor额外自动重绘，默认16ms精确定时并保留33ms节能档；隐藏曲线不刷新，播放时可见游标上限30Hz；游标不参与自动缩放，已校验有限的曲线跳过重复有限性扫描；播放位置按真实经过时间计算，避免整数滑块逐帧取整累计漂移。模型／几何／材质未降级。新增10秒多帧播放测试覆盖时间推进无累计漂移。

5秒真实Qt事件循环测试（同一优化后渲染器，比较刷新档位）：33ms档约30.22／30.34次更新每秒，16ms档约62.48／62.61次，分别为曲线关／开；16ms档帧间隔p95约17.17／17.20ms。隐藏曲线游标更新0次；打开时约21次／秒，符合上限30Hz。该结果是离屏事件循环／VTK更新节奏，不是桌面显示器实际呈现FPS，也不是对原旧版应用的完整性能对照。

原始逐帧数据与限制见轻量包的performance_before／after／playback.json；旧版曾卡顿的唯一根因没有被证明。

## 场景质感预览（未替换默认风格）

按用户讨论生成同一姿态／相机的原风格与柔光预览，见轻量包scene_original.png与scene_soft_light_preview.png。保留黑白飞机，尝试浅灰蓝背景、暖灰显示地面和柔和Phong光照，关闭舵面三角白边；不增加轨迹线或重型阴影。PBR尝试会把白色泡沫压暗，未采用。当前默认仍为原版简洁材质，柔光方案仅作视觉预览；未知材料特性不冒充实机标定。

新增文件未暂存。应用目录的局部.gitattributes固定文本LF，轻量包的局部.gitattributes保留证据原字节，避免Git换行转换破坏manifest。没有更改根属性或旧交付包。
