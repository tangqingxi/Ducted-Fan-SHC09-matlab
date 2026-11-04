# WindTrace 独立仓库与接口拆分方案

当前为只读审计。目标仓库名称已经确定为`tangqingxi/WindTrace`，未来主仓库名为`tangqingxi/AeroGNC-Sim`；当前均未创建、重命名或添加Submodule。

## 1. 已核实的Viewer功能

`apps/windtrace/`含单飞行WTR读取与校验、Qt界面、PyVista/VTK三维显示、机体几何与舵面/旋翼显示、NED/ENU世界坐标切换、回放与时间轴、相机跟随/预设/运镜脚本、贴地显示、主题、只读参数页、欢迎页与最近日志。Viewer读取已有日志；其自身不应承担仿真或科研验收判定。

当前`core/flight.py`与UI分层已有基础，但`core/exporter.py`混合了SHC09导出、来源指纹及Viewer几何调用，不能整目录复制后即认为完成解耦。

## 2. 当前跨仓库依赖

| 文件 | 已核实依赖 | 建议归属 |
|---|---|---|
| `analysis/export_windtrace_flight.m` | 读取保存的L/cfg/model/ref/plan/spec/signature/checks/metrics，转换MATLAB数据并调用Python导出；非仿真入口 | AeroGNC-Sim的SHC09离线适配层 |
| `tools/export_windtrace.py` | 将apps/windtrace加入sys.path，导入`core.exporter.export_flight` | 主库CLI；改为主库headless writer入口 |
| `tools/audit_windtrace.py` | 直接导入Viewer的`core.flight.digest/read_flight` | 主库科研审计；改为独立合同校验依赖或公开reader API |
| `tools/deliver_hover_takeoff_formal.py` | 导入audit及core.flight；绑定批次路径、参考比较、科学指标、WTR交付 | 主库study交付层；通用目录接口另行抽出 |
| `tools/check_hover_takeoff_replay.py` | 主库场景断言、Viewer UI与固定EXE路径交叉 | 拆成主库语义检查及Viewer回放冒烟检查 |
| `tools/benchmark_windtrace*.py` | 加入Viewer源码路径，使用其回放/显示实现 | Viewer性能测试；主库仅提供冻结fixture |
| `core/exporter.py` | 使用`Path(__file__).resolve().parents[3]`推导主库根；指纹包含`analysis/export_windtrace_flight.m`；导入visual_geometry | SHC09 writer移回主库；公开格式编码器独立，不依赖主库相对层级 |
| `core/visual_geometry.py` | `attach_meshes`导入`ui.glb_model`并使用GLB与六舵铰链 | 空机型几何构建由airframe离线适配；Viewer保留呈现与资源 |
| `tools/install_windtrace.ps1` | 以package_manifest校验staging，备份旧安装并替换，报告shortcuts_changed=false | 安装交付责任需在阶段5确认；保留现有保护逻辑，不在Phase1执行 |

**推断：** 直接把现有apps/windtrace变成独立仓库，会使parents[3]根推导、主库MATLAB来源指纹及测试夹具失效；还会保留writer→UI耦合。必须先在主库完成接口拆分，再接入Submodule。

## 3. 建议的目标责任

```text
AeroGNC-Sim
├── analysis/                       # 科学指标、方法比较、真实/估计误差
├── tools/exporters/windtrace/       # SHC09 MAT→合同，参数及来源语义
├── airframes/shc09/                # 坐标与离线几何构建
├── tests/                         # SHC09导出、物理坐标与原MAT关联
└── apps/windtrace/                 # 固定commit的Submodule

WindTrace
├── core/                          # 公共reader、合同校验、回放数据
├── ui/
├── assets/
├── tests/                         # reader、UI、回放与打包
└── docs/                          # 格式支持范围、构建和使用
```

建议将headless格式校验/编码建立为有版本的第一方纯接口包或发布工件，具体发布方式由阶段5审批确定。主库writer不得从Submodule UI导入实现，Viewer不得依赖主库存在。纯合同层只能定义容器/单位/形状/完整性，不应含SHC09控制器或性能门禁。若reader以独立公开库发布，也应固定版本/制品SHA；禁止靠sys.path碰巧导入另一份`core`。

## 4. 数据合同及兼容性

**已核实：** 当前33份交付均为ZIP格式`windtrace.flight.v1`，四个成员：`manifest.json`、`parameters.json`、`flight.mat`、`geometry.json`。清单声明成员字节数和SHA，记录source MAT SHA、输入签名、engine、方法/种子与run_id；单飞行身份不依赖方法文件名唯一。

当前reader保留原生时钟域，验证维度、时间、姿态与合同；拒绝重复成员、路径异常、缺失/额外成员及超限成员（单成员512 MiB上限），在内存读取而非解压到文件。几何采用FRD；四元数为Hamilton wxyz、FRD到NED。控制分配与PWM有不同原生采样域，不能为了显示重新解释科研指标或把真实量与估计量合并。

当前v1校验有7个核心topic及6舵面等SHC09约束。**它不是已经支持任意飞行器的通用合同。** 泛化geometry/topic需要新schema版本及明确兼容路线；不应静默改变v1含义。旧`.wtr.mat`或`windtrace.study.v1`不是当前单飞行reader的承诺支持格式；未来兼容声明必须列出实际格式。

**已核实的文档偏差：** exporter按`model.coordinate_frame`及ref.frame区分旧native与b坐标，向量/四元数转换分支不同；`docs/interfaces/windtrace_flight_v1.md`仍含单一固定C转换描述。阶段5应补充逐版本坐标说明和黄金用例，不能据现有文档概述重写历史WTR。

建议保留33份真实交付的只读兼容测试集合，并制作最小、可发布的黄金fixture，覆盖旧native与b坐标、近180°姿态、原生时钟域、NaN lambda等已允许值、错误hash与重复成员。测试目标包括旧reader读旧数据、新reader读旧数据、主库新writer写v1经独立reader读；新字段需按版本规则处理。当前审计未运行reader/GUI兼容测试，故不作已通过声明。

## 5. 测试归属

当前Viewer测试目录13个Python文件，包含conftest及12个测试文件。

| 当前测试 | 建议去向及拆分 |
|---|---|
| `test_flight.py::test_roundtrip_native_clocks_and_domains` | 主库验证SHC09 writer/原MAT时钟；Viewer以预生成fixture验证读取，不导入writer |
| `test_effective_parameters_and_unknown_defaults` | 主库验证参数提取；Viewer另测只读展示与unknown显示 |
| `test_frd_attitude_and_geometry`、`test_near_180_quaternion` | SHC09坐标与固定铰链断言留主库；通用四元数读取/显示测试留Viewer |
| `test_no_overwrite_or_legacy_bundle` | writer拒绝覆盖及导出格式约束留主库；reader不支持格式声明留Viewer |
| `test_invalid_contract`、`test_duplicate_member_rejected` | 通用reader合同拒绝测试迁Viewer/纯合同层 |
| camera_follow/presets/script、ground_offset、gui、loading、parameter_values、playback、rotor_overlays、theme_contrast、world_frame | Viewer；主库只保留冻结数据语义及必要端到端接线检查 |
| `conftest.py` | 拆为主库生成器fixture与Viewer预制WTR fixture，去除Viewer测试依赖主库writer |

主库MATLAB测试、控制器/分配器/传感器/ECL测试和正式研究验收均留主库。不能把真实恢复验收变成Viewer读文件成功。

## 6. Windows安装与现有快捷方式保护

已只读核查两个指定快捷方式：桌面`风迹 WindTrace.lnk`和开始菜单同名快捷方式，均指向：

`E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe`

工作目录为该WindTrace文件夹。当前安装必须在原位保护。仓库内发现44份WindTrace.exe、16种EXE SHA；该统计不证明完整运行包相同。`build_app.ps1`拒绝既有输出；`WindTrace.spec`收集assets、主题、许可及运行依赖。`tools/install_windtrace.ps1`已有复制校验、备份及部分失败回退逻辑；这些脚本本轮均未执行，也未重写快捷方式。

建议更名GitHub时先保持本地`E:/Ducted-Fan-SHC09-matlab`目录不变。阶段5先备份在用完整安装、package_manifest、许可、快捷方式目标与工作目录；验证独立构建的完整文件清单及回放，再批准切换。含在用dist的非空apps/windtrace不能直接以Submodule强行替换。应在批准的隔离工作区完成转换，并提供独立、稳定安装路径或保留原入口，验证后再切换快捷方式；保留可启动回退整包。

## 7. 两仓库版本锁与实施门槛

建议同时记录：主库commit、Submodule固定commit（不追踪浮动main）、格式schema版本、writer版本/源码SHA、公开reader/合同包版本、构建工具与依赖版本、黄金fixture SHA及兼容测试结果。接口变更先发合同变更与兼容矩阵，再更新Submodule指针。双方CI不得循环拉取并执行对方未固定的分支。

实施依赖阶段2基准/备份、阶段3边界稳定、用户批准新库可见性及Git操作。需要单独审查代码与GLB/图标/第三方运行库许可。当前仓库中的LICENSE与THIRD_PARTY_NOTICES存在，但不能据此自动推定所有素材允许独立公开发布。完成旧数据兼容、headless导出、单独clone/build、安装回退验证后才有条件申请拆分提交。
