# WindTrace 独立化执行报告（Standalone-W1）

日期：2026-11-07（Asia/Shanghai）。执行：DeepSeek Harness Agent。
范围：只做 WindTrace 独立化（建仓、迁移、环境、测试、EXE），不进入 AeroGNC-Sim 新项目，不动 C9。

## 1. 来源

| 项 | 值 |
|---|---|
| 源仓库 | <https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab> |
| 源分支 / 提交 | `refactor/phase3-source` / `d422cb34e495fbe786395d9586694fe4ef6f88df` |
| 源目录 | `apps/windtrace/` |
| 只读操作 | 仅读取；未修改、未合并、未清理源仓库 |

## 2. 新仓库

| 项 | 值 |
|---|---|
| 仓库 | <https://github.com/tangqingxi/WindTrace>（Public，非 Fork，无 submodule） |
| 默认分支 | `main` |
| 初始提交 | `053c7a1932f76e0846efe8abd01d3df4b8925569` |
| 最终提交 | `a809b590a029d11d98faba3dfc1dd87c83f3e6f7`（远端 HEAD 已核对一致） |
| 文件数 | 56（`.gitignore` 排除 `.venv`、`build`、`dist`、`screenshots`、缓存） |

## 3. 本地构建位置

| 项 | 路径 |
|---|---|
| 工作区 | `E:\WindTrace` |
| 独立环境 | `E:\WindTrace\.venv`（Python 3.13.14，不引用旧仓库 `.venv`） |
| EXE | `E:\WindTrace\dist\WindTrace\WindTrace.exe` |
| EXE 大小 / SHA256 | 22,445,203 B / `eec87ae69ff880cb66ab4167522e51ae3a9694a5fd106a760acbb7e68f7b3896` |
| 打包目录 | 2,443 文件 / 600.5 MB（含 `_internal`） |
| 旧 EXE | `E:\Ducted-Fan-SHC09-matlab\apps\windtrace\dist\WindTrace\WindTrace.exe` 保留未动（22,466,946 B） |

## 4. 迁移内容

`app.py`、`core/flight.py`、`ui/`（主窗口、三维视图、相机语言、运镜、主题、shell、GLB 解析）、
`assets/`（logo、运镜示例、几何来源 JSON）、`ui/assets/SHC09.glb`、`tests/`、
`docs/`（WTR v1 与运镜 v1 契约）、`WindTrace.spec`、`build_app.ps1`、`run_app.cmd`、
`requirements.txt`，新增 `requirements-dev.txt`、`README.md`、`IMPORT_PROVENANCE.json`（重写）、
`docs/migration_provenance.md`、`LICENSE`（追加 WindTrace 版权行）、`THIRD_PARTY_NOTICES.md`（改写为独立范围）。

## 5. 剔除内容（数据生产端，留在源工程）

- `core/exporter.py`（MATLAB 日志 → `.wtr` 转换器）
- `core/visual_geometry.py`（仅 exporter 调用，等价逻辑并入 `tests/wtr_builder.py`）
- 未迁入：`analysis/export_windtrace_flight.m`、`tools/export_windtrace.py`、`tools/audit_windtrace.py`

## 6. 已消除的跨仓依赖

| 原依赖 | 处理 |
|---|---|
| `core/exporter.py` 中 `parents[3]` 指向 MATLAB 仓库根 | 随 exporter 移除 |
| exporter 内 `analysis/export_windtrace_flight.m` 源码哈希 | 随 exporter 移除 |
| README 内 `../../docs/...`、`apps/windtrace/tests`、旧 `.venv` 绝对路径 | README 重写 |
| `assets/cameras/README.md`、`ui/camera.py` 的 `docs/interfaces/...` | 改为仓内 `docs/windtrace_camera_v1.md` |
| 运镜文档指向 `apps/windtrace/assets/cameras/` | 改为仓内 `assets/cameras/` |
| 测试经 `core.exporter.export_flight` 生成样本 | 改为 `tests/wtr_builder.py` 直接按契约写容器 |
| 用户设置 `QSettings('SHC09','WindTrace')` | 故意保持不变，升级后最近记录与相机设置继续有效 |

独立克隆（临时目录）验证：`git clone` 后无需源仓库、无需 MATLAB 即可 `--smoke` 与运行全部测试。

## 7. 测试结果

环境：Python 3.13.14 / numpy 2.5.4 / scipy 1.18.1 / PySide6 6.12.0 / pyvista 0.49.2 / vtk 9.7.2 / pyqtgraph 0.14.0。

| 场景 | 结果 |
|---|---|
| 无外部数据（夹具容器 + 离屏 Qt） | 51 passed, 20 skipped（真实日志用例明确 skip） |
| 提供两份真实历史 `.wtr`（PCA_PREDICTIVE_s501、DA_NS_s501，55 s 正式批） | **71 passed** |
| 迁移前源测试数 | 58（迁移后增加契约/CLI/夹具界面覆盖，未删除失败用例） |
| 真实 WTR 读取 | `short_b.wtr`（2 s，b 系，execution=incomplete）、`synthetic_contract_demo.wtr`（0.01 s）、正式批 55 s：全部读取成功，时间轴/位姿/参数/几何正常 |
| 非法容器 | 哈希不符、额外成员、schema 错误、时间非递增、形状不符、四元数未归一化、未声明字段/topic、时间戳不符、重复成员、非 `.wtr` 后缀：均报 `FlightError` |
| 功能等价（迁移 A/B） | 旧源码 vs 新源码，5 个场景（默认视图、showcase 预设、ENU、参数面板、曲线抽屉）逐像素比对：最大差 1 LSB，差异像素 ≤63/1,224,000；参数面板 0 差异 |

## 8. EXE 构建结果

- 构建：`build_app.ps1 -Force`（PyInstaller 6.22.3，单目录、`console=False`），耗时约 2 分钟。
- `--smoke`：从 `C:\` 工作目录读取 55 s 正式批与两份小样本，退出码 0，摘要正确。
- 截图：从 `C:\Windows` 启动，3D / 参数面板 / 曲线抽屉 / ENU+analysis 预设四种截图均正常。
- GUI：经桌面快捷方式启动，窗口标题「风迹 WindTrace」，加载真实 WTR 后正常关闭（退出码 0）。
- 源码与 EXE 在同一设置下的截图逐像素一致（最大差 1 LSB）。
- 修复的缺陷：`--smoke` 遇到非法容器时，窗口版 EXE 因未捕获异常弹出阻塞对话框（历史缺陷）。
  现改为输出 `WindTrace: <原因>` 并以退出码 2 结束；修复范围仅 `app.py` 的错误处理分支，不影响正常渲染路径。

## 9. 历史工程保护结果

| 项 | 结果 |
|---|---|
| 源仓库 refs | 43 条与迁移前快照完全一致 |
| HEAD / `main` / `refactor/phase3-source` | `d422cb3…` / `1c851a5…` / `d422cb3…`，均未变 |
| 历史数据 | 126 份 `.wtr`/`.mat`/锁/来源 JSON，SHA256 全部未变 |
| 工作区状态 | 与迁移前一致（仍为迁移前既有的 `examples/f8_comparison_20261101` 删除状态，本轮未触碰） |
| 旧 EXE | 保留（22,466,946 B，时间戳 2026-11-03 20:10:55） |
| 用户设置 | 最近记录 3 条、相机预设保留；`scene/world_frame` 已复位为迁移前的 `NED` |

快捷方式（桌面、开始菜单）已指向 `E:\WindTrace\dist\WindTrace\WindTrace.exe`，工作目录 `E:\WindTrace\dist\WindTrace`，启动验证通过；旧 EXE 作为回退保留。

## 10. 未解决问题与限制

1. **真实历史样本来源**：`logs/wtr/**` 为源仓库未跟踪数据，按本轮要求未上传（仓库不含 `.wtr`）。
   真实兼容验收使用的是本机现有的这些历史文件，克隆端只跑夹具测试。
2. **VTK 版本未固定**：`requirements.txt` 未 pin `vtk`，本次安装为 9.7.2（旧环境 9.7.1），
   A/B 渲染差 1 LSB。若需逐位复现构建，建议后续补 pin。
3. **离屏首帧偶发空场景**：首次离屏截图出现一次空三维画面（网格可见、机体不可见），
   随后同参数在源码与 EXE 下各复现多次均正常，未能复现，未归因于本次迁移；已记录待观察。
4. **`--screenshot` + 非法文件**：退化为截图错误界面并以 0 退出（历史行为，未改），
   检测非法容器请用 `--smoke`（现为非零退出）。
5. **GUI 验证深度**：桌面会话内以进程/窗口标题/正常关闭为准，未进行人工交互级（鼠标拖动、
   相机菜单逐项点击）验收；相关逻辑由 `test_camera_*`、`test_world_frame` 等离屏用例覆盖。
6. 未上传 EXE 到 Release（本轮不要求）；`dist` 与 `.venv` 均未进入 Git。
