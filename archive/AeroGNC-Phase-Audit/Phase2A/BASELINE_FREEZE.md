# AeroGNC-Sim重构起始基准冻结

记录日期：2026-11-04（Asia/Shanghai）。本次用户已选择基准，不再将“选择哪个分支”列为待审批事项。

| 项目 | 现场核实结果 |
|---|---|
| 主仓库 | `E:/Ducted-Fan-SHC09-matlab`；GitHub仍为`tangqingxi/Ducted-Fan-SHC09-matlab` |
| 重构起始提交 | **`339d7b1a997de6ba350cef3207d8a5b7db3d838d`** |
| 当前分支及状态 | 本地main、origin/main及远端main同SHA；工作区干净 |
| 远端开发分支 | 仅main；默认分支仍为main；不重建或合并已删除分支 |
| 实际worktree | 仅E盘主工作树；controller-ppid-p-indi工作树及对应本地分支已移除 |
| 审计仓库起点 | `3dbd1207bca0ca15c22a13ec4c0b2734b8f7e630`，main与origin/main同步 |

完整只读命令结果见[evidence/BASELINE_STATE.json](evidence/BASELINE_STATE.json)。Phase1及Git分支收敛报告关于C盘worktree仍存在的文字是当时快照，本文件记录最新状态；旧文件不回写。此前用户要求删除的Worktree-Cleanup目录不作为任何原始科研数据的现存备份依据。

## 历史来源与明确边界

- 原change-B研究/审计保存点：`661a128f1bfeaa6484f1dca3f9dbc489bb1195bc`；已包含于冻结main。
- Round 6交付：`766956655dc499d59bac9d5d3dbae76639106dde`；Round 7交付：`b1cf139b40992f9b7420a21b996b6d00d09a4013`。
- GNSS-GM-v2交付：`ae03d6b1941939efe9b8f5fc0afd4c016e80ea21`；最新339d7b1为后续环境路径文档提交。
- 原正式批执行起点为`c381275775b2fe0191eddd663798157864e56780`，change-B正式批执行起点为`1737eee1a309e0fb1bfcf294293b38cc128b1b47`。执行起点、冻结源码、管理修复版与交付提交是不同角色，不能仅checkout一个commit便宣称精确重放旧批。
- 当前WindTrace配套源码与在用安装包属于该工作树现状。EXE完整包及回退包均列入保护计划，尚未做独立备份或启动恢复测试。

## 当前入口与来源锁

| 使用范围 | 入口与加载链 | 必须保留的来源依据 |
|---|---|---|
| 平台链 | `main.m → apps/main_comparison.m → shc09_run → platform_run → sim_driver → platform/sim/ca_simulate` | 显式ca_setup路径、注册表、平台实现捕获与engine |
| 共用四环研究 | `run_ppid_pindi.m`及`research/ppid_pindi/` | 父protocol、formal_lock、ppid_source_manifest；旧批禁止追加/覆盖 |
| 历史55秒正式批 | `run_hover_distance_takeoff_formal.m`与hdtf配置 | 每批formal_protocol/source_lock/formal_lock、执行版冻结驱动、输入与管理事件 |
| 新GNSS模型 | `shc09_gnss_config → gnss_v2/ppid_gnss_v2_config → 原配置加载与父SHA校验 → 原ppid_noise/ppid_simulate/ECL` | `research/ppid_pindi/gnss_v2/protocol.json`及GNSS独立回归source_lock |
| ECL桥接 | MATLAB CaPx4Ecl调用外部px4_ecl_bridge.exe | build_manifest、二进制、third_party来源、初始化/时钟协议 |

当前版本化入口使用三轴1000 s物理相关时间；旧协议及旧入口仍保存60 s历史含义。两条控制运行链不合并；不得通过本轮修改旧协议或默认入口来“统一版本”。

`analysis/allocation_comparison_engine.m`对源码路径及字节建立身份；显式ppid来源锁另覆盖研究实现，二者不能互相替代。目录移动可能改变engine、实现捕获范围、相对路径与MATLAB函数解析，即使算法文本相同也不能改写旧锁。未来必须建立旧路径/新路径/内容SHA/新旧engine映射，保存旧源码原布局。

## 运行完成与科研验收

两批历史60 s正式批均15/15执行完成，但真实恢复均0/15通过、估计恢复15/15通过。1000 s单条55 s回归完成，GNSS融合正常；真实水平RMSE0.781936 m、峰值1.629143 m，原真实恢复仍失败。

该限制已由用户明确列入[Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)，**暂缓处理，非本次结构重构阻塞**。本轮不修复、不调参、不新增仿真，也不把失败改为通过。Issue状态及决定的只读记录见[evidence/REMOTE_CONTEXT.json](evidence/REMOTE_CONTEXT.json)。

后续结构等价性门槛是：原始文件及来源身份保护、路径/接口/时钟语义保持、同输入同参数的输出等价；科研性能门槛仍保留原阈值和已知失败。两者独立报告。未来数值运行范围需另行批准，Phase2A没有执行MATLAB、ECL、控制仿真或GUI构建。

本次冻结只记录SHA和保护依据，没有创建主仓库分支/Tag、提交或推送。
