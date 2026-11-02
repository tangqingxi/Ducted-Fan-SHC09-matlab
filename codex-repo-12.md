# WindTrace启动、加载与EXE更新报告

日期：2026-11-02（Asia/Shanghai）。工作目录E:/Ducted-Fan-SHC09-matlab，分支WindTrace_merge。已按用户此前允许覆盖旧版的授权完成修复、打包和原位更新，没有运行仿真或提交／push。

## 问题与依据

用户截图的分配器、种子和时间均为“—”，表明截图时没有成功载入飞行日志。此前首次无日志启动没有打开引导，无数据时仍能切换播放图标，容易让人以为程序卡住。这是界面缺陷；仅凭截图不能断言用户此前是否尝试打开过某个文件。

修复中进一步用普通Windows窗口验证，实际捕获 `QtInteractor has no attribute 'off_screen'`：独立离屏PyVista Plotter具有此属性，QtInteractor没有。旧加载入口未妥善显示这个异常；它会在三维准备阶段中断正常加载流程。此前报告11只检查“窗口能打开”和渲染对象存在，未充分检查交互加载异常，本轮补齐验证。

## 修复范围

- 首次启动显示居中的“打开一份飞行日志”及明确按钮，保留原主题、布局、机体配色和场景。
- 无日志时禁用播放、时间轴、曲线、重载和导出；空格与曲线快捷键也受保护。
- .wtr读取和校验在工作线程完成；显示加载提示，控件和VTK场景仍在主线程更新。没有把不确定时长伪装成完成百分比。
- 文件失败显示原因并可重选；读入失败保留已有飞行。打开另一日志会真正切到新日志；同run_id重载读取新内容。
- 成功打开记录本机最近文件和目录；下次普通启动自动恢复仍存在的日志。记录不进入.wtr，不改变控制参数。
- 视图使用自身明确的离屏模式标志，避免访问QtInteractor不存在的off_screen属性；首次布局完成后再居中打开提示。

主要源码为 [app.py](apps/windtrace/app.py)、[main_window.py](apps/windtrace/ui/main_window.py)、[view3d.py](apps/windtrace/ui/view3d.py)；新增 [加载回归测试](apps/windtrace/tests/test_loading.py)。文档同步到AGENTS、HANDOFF、README和应用README。

## 验证与安装

源码20/20通过，使用现有三份.wtr，零跳过。新增测试覆盖无数据保护、读取阻塞时Qt事件循环仍响应、坏文件恢复、切换新日志和最近文件恢复。未改数据导出契约。

最终EXE六项全部通过，启动工作目录为空，移除PYTHONHOME／PYTHONPATH／VIRTUAL_ENV，PATH限于Windows目录：

| 检查 | 结果 |
|---|---|
| 三份现有.wtr纯后台读取 | 3份成功，保留原执行／审计状态 |
| 无日志启动截图 | 打开入口可见，播放禁用 |
| 后台加载现有预测PCA日志 | 1份载入，提示关闭，播放启用，last_error为空，机体可见 |
| 只读参数搜索 | 总378项，INDI输出滤波字段匹配2项，表格只读 |
| 损坏.wtr | 原因可见，退出加载状态，播放禁用，无无声空白 |
| 普通Windows窗口 | 15.5秒机体与网格截图正常，last_error为空，自动关闭 |

普通窗口只短暂打开约5秒并自动关闭；没有调用Computer Use、鼠标或键盘注入。离屏与普通窗口截图均已目视核验。测试和异常证据在 `results/windtrace_startup_fix_20261102_r1/`；最终EXE验证在其中final_checks。build1捕获上述QtInteractor问题，保留原样未安装；build2是修复后的最终包。构建继续隔离PATH，防止原Poppler ICU DLL污染复现。

安装路径保持：`E:/Ducted-Fan-SHC09-app/dist/WindTrace/WindTrace.exe`。原桌面／开始菜单快捷方式继续使用。覆盖前旧v0.3保存在同级 `WindTrace_backup_20261102_startup_fix_r1`；更早v0.2备份 `WindTrace_backup_20261102_r4`仍在。

| EXE | SHA256 |
|---|---|
| 更新前v0.3 | bffac883cb3f425ffbc5a4a7d16b589bd2a44a03b94e4133ee2c05f6a9e6e25c |
| 本次更新 | 1fa91bfb57534904b935e25b6a95fcd8eccca0c4652184d9117572266be160c8 |

最终包 `results/windtrace_startup_fix_20261102_build2/dist/WindTrace/`，清单覆盖2435个载荷文件（599002714字节），另有package_manifest.json自身。安装工具逐文件SHA256检查复制，备份旧目录后替换；完整过程见build2/installation.json。EXE及_internal必须一起保留，重型构建和DLL不纳入Git。

## 使用与边界

重新双击原桌面“风迹 WindTrace”。首次点击“打开飞行日志…”，可选本机现有样例：

`E:/Ducted-Fan-SHC09-matlab/results/windtrace_integration_20261102_r1/deliveries/filter15_PCA_PREDICTIVE_s501.wtr`

该样例来自已有40秒日志，不是新仿真。以后正常启动会恢复最近成功打开且仍存在的日志。双击.wtr的Windows文件关联尚未注册，应从软件“打开”选择文件。

基底1358项SHA复核：1355项未变，已有文件差异只有AGENTS.md、HANDOFF.md、README.md。数值源码、旧协议／锁和抽查原日志不变；没有删除旧证据。HEAD仍为2590949cce6b62cd9022e3ac9717a269d100cd30，main仍为9918d9dba180f38a62c36f602e37993b87d0d38d，暂存区为空。当前验证范围为本机Windows及其GPU驱动。
