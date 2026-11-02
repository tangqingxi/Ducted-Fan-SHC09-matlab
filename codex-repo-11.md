# WindTrace EXE打包与原位更新报告

日期：2026-11-02（Asia/Shanghai）。分支仍为WindTrace_merge。本轮按用户授权打包，并覆盖旧版安装位置；未运行仿真、未暂存、提交、打tag或push，main未修改。

## 已完成安装

现在可直接双击桌面或开始菜单的“风迹 WindTrace”。现有快捷方式保持原样，指向：

`E:/Ducted-Fan-SHC09-app/dist/WindTrace/WindTrace.exe`

旧版完整目录保留于：

`E:/Ducted-Fan-SHC09-app/dist/WindTrace_backup_20261102_r4/`

新版为Windows x64单目录应用，Python、Qt、VTK等运行依赖随_internal目录分发。需要保留整个WindTrace目录，不能只搬exe。共2436个文件，清单覆盖其中2435个文件，约599 MB；安装前已逐文件SHA256校验复制结果。

| 程序 | SHA256 |
|---|---|
| 旧版EXE | c673f8e44adea171b030dea58a803f780957ffafea6749d5ccf4c6088bbe69d0 |
| 新版EXE | bffac883cb3f425ffbc5a4a7d16b589bd2a44a03b94e4133ee2c05f6a9e6e25c |

当前功能为单飞行.wtr、原版抽屉布局和黑白机体、地面网格开关、可选参考轨迹、真实／估计状态切换、只读参数搜索和曲线。柔光材质仍为此前讨论的预览，没有擅自改为默认。

## 打包与验证

使用已有Python 3.13环境、PyInstaller 6.22.3构建，无须为最终用户另外安装Python。构建入口为 [build_app.ps1](apps/windtrace/build_app.ps1) 和 [WindTrace.spec](apps/windtrace/WindTrace.spec)；安全原位替换工具为 [install_windtrace.ps1](tools/install_windtrace.ps1)。安装工具先复制到新暂存目录并校验，再备份移动旧版，最后替换，不删除旧安装。

源码测试16/16通过，增加了相机跟随平移、保持观察方向、关闭跟随及裁剪面有效性回归。打包EXE六项检查通过：三份.wtr读取、三维截图、参数搜索截图、多日志曲线、无日志空窗口、正常Windows窗口。参数表378项，搜索生效INDI滤波字段得到生效值与父值2行，表格只读；真实／估计两个选项、网格默认开、参考轨迹默认关均保留。

验证从空工作目录启动，移除了PYTHONHOME／PYTHONPATH／VIRTUAL_ENV并将PATH缩到Windows目录，确认不是依赖源码目录或开发虚拟环境才能启动。正常窗口短暂显示并自动关闭，没有鼠标／键盘注入。安装后从原安装位置再次读取.wtr通过，桌面快捷方式目标存在；旧版备份EXE的SHA与安装前一致。

最终构建、包内清单、过程日志、截图、安装报告和安装后校验均在本机 `results/windtrace_packaging_20261102_r4/`。重型EXE／DLL／构建缓存不进Git。当前只在本机Windows 11及其GPU驱动验证，没有宣称跨机器完整兼容。

## 已解决的打包／回放问题

1. r1构建误从外部Poppler路径收集了ICU78的同名icuuc.dll；它缺少Qt6Core需要的20个未加版本后缀符号，导致QtCore导入失败。构建脚本现在仅向收集器提供Python与Windows路径，避免外部PATH污染，未改系统环境。
2. r2/r3窗口检查发现位移会让近景相机丢失机体；新增默认开启的“跟随机体”，只跟随平移，保留观察方向，并可关闭。
3. 相机移动时，VTK会基于尚未移动的旧网格自动重算裁剪面；现在在全部位姿更新后统一恢复裁剪范围，正常窗口15.5秒截图已确认飞机可见。

前几次构建和失败诊断保留在独立r1–r3目录，没有覆盖旧实验或删除失败证据。最终使用r4。

## 交接边界

新增打包入口、安装工具、图标资源和后台报告／截图验证选项；更新了相机显示逻辑及相应测试。控制器、分配器、传感器、估计器、参考、协议／锁和原始实验数据未改。EXE启动后用“打开”选择现有.wtr，不支持旧五方法bundle；没有改变Windows文件关联。

后续开发仍在E盘主仓库；安装目录是程序交付，不代替源码仓库。报告10中“尚无EXE”是此前阶段快照，当前以本报告和HANDOFF为准。
