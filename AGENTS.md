# Agent开发操作契约

本文件维护稳定工程约束。项目介绍见[README](README.md)，当前阶段、实际HEAD和待办见[HANDOFF](HANDOFF.md)，历史实验结论见对应协议与报告。不要继续在本文件顶部叠加任务公告或逐轮实验日志。

## 1. 项目边界与阅读顺序

当前平台面向SHC09六舵面涵道无人机，使用MATLAB研究控制、控制分配、执行器和状态估计。AeroGNC-Sim多机型结构尚未实施；本项目不是PX4 SITL、完整EKF2飞控，也没有已完成的实机标定/实飞验收。

接手时依次阅读：本文件 → HANDOFF → [架构](docs/guides/architecture.md)和[研究工作流](docs/guides/research_workflows.md) → 具体入口、配置、协议、来源锁与最新证据。不能凭目录名或旧报告的“当前”判断现场状态。

| 代码范围 | 先检查的入口/接口 |
|---|---|
| 平台链 | main、shc09_run、src/runtime/platform_run、src/runtime/sim/ca_simulate |
| 四环研究 | run_ppid_pindi、src/runtime/sim/ppid_simulate与src/control/ppid/ppid_control_step |
| 分配 | allocators/registry、shc09_allocator_dispatch、ca_allocator_config、effectiveness |
| 传感器/导航 | ppid_noise、shc09_navigation_sensors、ppid_estimator_init、CaPx4Ecl与桥接构建身份 |
| 指标/来源 | 对应研究metrics、analysis/allocation_comparison_engine、ppid_source_manifest及批次锁 |
| 回放 | apps/windtrace、analysis/export_windtrace_flight及.wtr合同 |

平台链与四环研究链不同；不能把一条路径的修复、参数、时钟或验收移植到另一条而不说明。精确路径见[仓库地图](docs/repository_map.md)。

## 2. 开工与Git

`main` 是稳定基线；`refactor/phase3-source` 是当前重构集成分支。每阶段允许在独立开发分支完成，验收后集成；禁止强推、无授权修改 `main` 或重写已发布历史。开工核对 status、HEAD、remote、集成/开发分支和全部 worktree；历史本地分支不等于当前开发入口，不重建已删除远端分支。发现非本任务修改时保留原状，停止可能覆盖它们的操作并报告，不执行 reset、restore、clean 或 stash 来制造干净状态。

源码以 Git 分支、提交和远端仓库恢复，默认不创建完整源码备份或 Restore-Test 副本。Results 和未跟踪的原始科研数据不受 Git 自动保护，清理或迁移仍需明确范围。

按本轮明确授权的仓库、分支和范围提交/推送；已有授权不重复询问。不把其他任务的授权扩展成新增仿真、调参、删除或数据迁移权限。不得强推、重写已发布历史或自动合并无关开发线。

提交前审查diff、暂存范围、敏感信息和验证结果；推送后核对远端SHA与工作区。区分science_baseline_commit、documentation_update_commit和current_main_commit，不改写旧实验来源来追认新HEAD。

## 3. 数值和信息边界

估计反馈模式中，真实状态只供物理推进、传感器生成和离线评价；估计器接收测量，控制器接收估计反馈，分配器只接收白名单名义模型、名义执行器状态和时序。不得传完整真实cfg/model、真舵角、真实偏置或扰动给插件。ideal的理想参考必须明确标注，不能冒充实际导航能力。

不擅自更改控制增益、GNSS/ECL、气动、执行器、随机流、坐标或PWM时序。新增/修复数值行为先确认具体调用链与任务授权；保持各方法可用信息规则一致，但不强求闭环分叉后的需求数值相同。

显式注册表、兼容包装和函数句柄属于真实依赖。不能因静态搜索“无引用”或目录看似重复就删除代码。白名单隔离是工程接口，不是MATLAB安全沙箱。

## 4. 冻结来源、协议与原始数据

历史协议、formal_lock/source_lock、原始MAT/WTR、输入、已保存指标和验收报告保持原字节。改数值源码会改变科学来源；移动路径也可能改变engine。engine不覆盖所有研究/后处理代码，必须同时看显式来源清单和执行版快照。

需要新数值行为时使用新协议/版本、新来源记录和独立输出，保留旧锁与旧结论；禁止更新旧锁、阈值或缓存身份来让新代码冒充旧批。管理性修复也需保留执行版、精确diff及前后SHA，不能把修复后的源码认作旧执行版。

SHA必须声明字节口径：本地原始文件SHA256、Git blob OID和发布正文SHA256不可互换。受锁原始字节不以CRLF/LF归一化放行；文档发布的换行差异可另作双口径记录。目录/源码重构按旧路径、新路径、内容SHA与engine建立映射，不能重写原MAT内的历史路径。

codex-repo历史报告按来源证据管理，移动/删除需结合原始证据和Git追溯审查；既有examples/validation不用于更新任务状态。原始数据备份位置、恢复验证和Results迁移按[审计方案](https://github.com/tangqingxi/AeroGNC-Phase-Audit/tree/main/Phase2A)单独批准。轻量Git证据不是大型原始日志的备份。

## 5. 运行、输出和权限

用户要求运行一个明确短例时，授权限于该例；任务若明确禁止仿真，就只静态核对。README中的命令是使用说明，不自动构成批量运行授权。新增参数扫描、种子扩展、52/55秒研究批、ECL/WindTrace重建、原始数据删除/搬迁需明确范围。

复用现存结果优先于重跑。新增运行使用唯一output_tag，不设置overwrite_results=true覆盖正式目录；中断先核实已保存状态、hash、输入与来源，只补获准的未运行项。失败、半成品和管理异常保留，不能删失败项后宣称全批通过。

运行和报告分别说明execution、acceptance及retention；数值有限、估计跟踪良好、容器可读都不能替代真实跟踪验收。rankable不等于方法可分或统计显著；单批三个种子不支持实机优势或全局最优断言。缺失/不适用指标不填零，lambda缺失不填1，不同条件RMSE差不作为严格可加物理贡献。

本地results通常未跟踪，Git提交不保护其原始数据。清理先明确用户要删除的具体范围；如果要求保留证据，先确认可信副本；如果明确不要某项，不擅自替用户追加大规模备份。删除/递归移动前核实绝对路径与根边界，避免作用于另一工作树或整个磁盘。

## 6. 环境、路径与代码规范

- **新增或修改代码的注释全部使用中文。** 保持接口、单位和坐标明确，不为了修文档改源码。
- ca_setup只加入显式源码及注册目录；禁止用genpath把results、archive、冻结证据、第三方参考全部放入搜索路径。
- 执行命令显式指定实际仓库根目录；不要假设旧C盘路径、其他worktree或个人环境仍存在。Windows使用结构化参数/LiteralPath，Linux注意大小写与路径分隔符。
- MATLAB基础例需要Optimization Toolbox；已保存验证环境见运行指南。ECL的JVM/外部二进制、Python和编译器，以及WindTrace开发依赖分别核对，不擅自重建或迁移环境。
- 当前桥接接口包含Windows `.exe`路径约定，不宣称跨平台直接等价。不得通过环境/换行“修复”悄悄改变冻结来源SHA。

## 7. 验证与交付

按变化选择检查：文档用链接、锚点、入口/配置静态核对及GitHub渲染；数值变更用获准的针对性验证与来源保护；数据迁移用逐文件hash、解析及恢复验证。检查通过后不无故扩大或重复实验。

run_project_tests、run_platform_tests和test_platform_baseline等可能实际推进对象或写results；在只读/文档任务中不执行。现存旧行为兼容/逐位基线和lite物理偏置测试有已知失败，详见[证据指南](docs/guides/results_and_evidence.md)，不能写“全套测试已通过”或放宽门槛来关单。

报告区分本轮实测、历史复述、推断及未验证项，给出输出路径、提交/推送结果与剩余限制。只做本轮授权工作，不自动进入下一阶段。

## 8. 文档职责

README服务首次访问者；docs/guides解释使用与架构；HANDOFF维护当前阶段和待办；协议与validation保留研究证据；独立审计仓库保存阶段计划和核验。当前问题用HANDOFF/Issues链接，不在各文件重复维护长进度表。历史正文通过固定提交和原报告追溯，不因更新首页而回写历史结论。

## 9. 交接与文档更新

任务级与交接级分开处理，避免每个任务都重写交接文档：

- **任务级（默认）**：完成即提交/推送并报告精确SHA与测试结果，**不重写**`HANDOFF.md`或阶段报告；仅当文档已与事实矛盾（如改了其中提到的文件或路径）时才做最小修正。
- **交接级**（满足任一）：用户明确要求交接、收工或换agent；阶段被验收或驳回；会话结束但仍有未完成工作；下一位agent不靠本次对话无法继续。此时更新审计仓库`AeroGNC-Phase-Audit`对应阶段的`REPORT`、`evidence-manifest.json`与`HANDOFF.md`，记录DEV分支、完整SHA、是否已推送、已验证与未完成项，以及一个可执行的具体下一步（禁止`TODO`/`...`占位）。
- **交接自检**：运行`python %USERPROFILE%\.dsh\skills\dual-repo-agent-handoff\scripts\check_handoff.py <DEV> <AUDIT> --phase <阶段>`。handoff中的SHA必须存在于DEV且等于HEAD（祖先提交给警告），`REPORT`与manifest必须存在且证据hash校验通过，下一步任务不得为占位符；不通过不算交接完成。
- 写完handoff**不等于验收通过**：验收仍以证据、执行命令和测试结果为准。
- 本仓库`HANDOFF.md`只维护当前阶段指针、待办与阻塞项；阶段正文、证据清单和交接细节写入审计仓库，不在此重复。

