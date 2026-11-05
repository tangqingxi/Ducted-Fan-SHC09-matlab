# Phase 3 源码映射与实施边界

日期：2026-11-05。开发分支 `refactor/phase3-source`，起点 `origin/main` = `fdc933694db9c16a0d9ffcd6d9c391b052352d22`。
科学基准固定为 `339d7b1a997de6ba350cef3207d8a5b7db3d838d`，不是当前 main。

权威依据：[阶段方案](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/dda650fb062a48900df10d14084b0861281ed012/Phase3-Architecture/PHASE3_ARCHITECTURE_REPORT.md)、[逐文件计划](https://github.com/tangqingxi/AeroGNC-Phase-Audit/blob/dda650fb062a48900df10d14084b0861281ed012/Phase3-Architecture/MIGRATION_PLAN.csv)。本文按原计划登记映射，不授权实际移动。

## 提交与波次

| 提交 | 波次 | 工作与本轮状态 |
|---|---|---|
| C0 | 准备 | 本文、阶段指针、备份在位核查 |
| C1 | 准备 | src 占位、显式双布局路径、重复函数检查；没有源码迁移 |
| C2 | W1 | runtime/control、drivers/lib、分配接口与导航桥接；未实施 |
| C3 | W2 | 效能插件；allocators 顶层注册；未实施 |
| C4 | W3 | models → airframes；未实施 |
| C5 | W4 | research/experiments → studies 及拆分的通用模块；未实施 |
| C6 | W5 | tests/tools/apps/analysis；未实施 |
| C7 | W6 | 文档与 compat；未实施 |
| C8 | 汇总 | 新旧 engine 和来源身份登记；未实施 |
| C9 | 收尾 | 首页与交接；未实施 |

## 目标结构

```text
src/{runtime/{logger,sim,msg,params,scheduler,tests},control,
     allocation,effectiveness,sensors,navigation/px4_ecl,drivers,lib,compat}
airframes/shc09/
allocators/{registry.m,interface/,da_ns/,wls/,dca/,pca_static/,pca_predictive/,example_pinv/}
configs/ studies/ analysis/ tools/ apps/ results/ artifacts/ docs/ tests/ third_party/
```

`src/allocation` 仅为接口规划预留，当前逐文件计划将 ca_allocate 等接口放入 `allocators/interface`。算法插件保持顶层 `allocators/`。C1 的 README 均为占位说明，不代表实现完成；不建 Windows compat 软链接。

## 计划内目录映射

下表直接汇总 CSV 中 MATLAB 条目的父目录；KEEP 路径不加入搜索路径。拆分的研究模块不得据目录名合并控制器。

| 旧目录 | 计划新目录 |
|---|---|
| `allocators` | `allocators/plugins` |
| `allocators/da_ns` | `allocators/plugins/da_ns` |
| `allocators/dca` | `allocators/plugins/dca` |
| `allocators/example_pinv` | `allocators/plugins/example_pinv` |
| `allocators/pca_predictive` | `allocators/plugins/pca_predictive` |
| `allocators/pca_static` | `allocators/plugins/pca_static` |
| `allocators/wls` | `allocators/plugins/wls` |
| `compat` | `src/compat` |
| `drivers/actuators` | `src/drivers/actuators` |
| `effectiveness` | `src/effectiveness` |
| `effectiveness/hover_linear` | `src/effectiveness/hover_linear` |
| `effectiveness/shc09_6vane` | `src/effectiveness/shc09_6vane` |
| `experiments` | `studies/legacy_experiments` |
| `lib/filters` | `src/lib/filters` |
| `lib/math` | `src/lib/math` |
| `models/shc09` | `airframes/shc09` |
| `modules/control_allocator` | `allocators/interface` |
| `modules/state_estimator/px4_ecl` | `src/navigation/px4_ecl` |
| `platform` | `src/runtime` |
| `platform/logger` | `src/runtime/logger` |
| `platform/modules/actuator_output` | `src/control/actuator_output` |
| `platform/modules/attitude_control` | `src/control/attitude_control` |
| `platform/modules/commander` | `src/control/commander` |
| `platform/modules/control_allocator` | `allocators/interface/control_allocator` |
| `platform/modules/estimator` | `src/navigation/estimator` |
| `platform/modules/position_control` | `src/control/position_control` |
| `platform/modules/rate_control` | `src/control/rate_control` |
| `platform/modules/sensors` | `src/sensors/sensors` |
| `platform/msg` | `src/runtime/msg` |
| `platform/params` | `src/runtime/params` |
| `platform/scheduler` | `src/runtime/scheduler` |
| `platform/sim` | `src/runtime/sim` |
| `platform/tests` | `src/runtime/tests` |
| `research/hover_distance` | `studies/hover_distance` |
| `research/hover_distance_filter_20261102` | `studies/hover_distance_filter_20261102` |
| `research/hover_distance_formal_20261102` | `studies/hover_distance_formal_20261102` |
| `research/hover_distance_takeoff_20261103` | `studies/hover_distance_takeoff_20261103` |
| `research/hover_distance_takeoff_formal_20261103` | `studies/hover_distance_takeoff_formal_20261103` |
| `research/hover_distance_takeoff_formal_recovery_20261103` | `studies/hover_distance_takeoff_formal_recovery_20261103` |
| `research/ppid_capacity_fix_20261103` | `studies/ppid_capacity_fix_20261103` |
| `research/ppid_pindi` | `src/control/ppid` |
| `research/ppid_pindi` | `src/navigation` |
| `research/ppid_pindi` | `src/runtime/sim` |
| `research/ppid_pindi` | `src/sensors` |
| `research/ppid_pindi` | `studies/ppid_pindi` |
| `research/ppid_pindi/gnss_v2` | `studies/ppid_pindi/gnss_v2` |

## 计划矛盾及保留决策

CSV 将 registry 和算法目录映射为 `allocators/plugins/*`，而方案正文称插件原地、registry 不变；现有 registry 的 directory 固定为 `allocators/<method>`。本轮依用户明确要求保留现有顶层注册和六个目录，未改 CSV、未创建 plugins 搜索路径。C3 前必须统一这项计划矛盾；不得静默迁移。
CSV 将部分 PPID 文件拆入 src/control/ppid、src/navigation、src/sensors 和 src/runtime/sim；C5 需按逐文件表核查，而不能只整体改名 studies。
冻结 reference 的 KEEP 决策优先于目标树概述，不把 reference 加入搜索路径。

## 搜索路径与函数身份

根目录由 ca_setup 自身绝对路径确定。保留原显式白名单与注册表追加机制，按原顺序逐项 addpath('-begin')，因而最后添加的目录优先；每项依次登记旧路径和计划新路径。不存在的目录跳过。新旧同时存在且含同名实现时立即报错，不能靠路径顺序静默选择。
平台链 main/shc09_run → platform_run 与四环链 run_ppid_pindi → research/ppid_pindi 独立保留。研究目录仍由研究入口显式添加；检查工具按该上下文检查 PPID，不执行研究入口。
仅显式列出的源码目录可进入路径；results、archive、docs/validation、冻结参考、备份、第三方均不自动加入。运行时以 MATLAB which -all 为准；静态扫描仅描述候选文件。
重复函数白名单：搜索路径内不豁免；搜索路径外 tests/legacy_reference 与 models/shc09/reference 的历史同名实现可保留，必须在报告中列出，不能据此删除历史实现。

## 来源与回滚

快照 `D:/AeroGNC-Backup/AeroGNC-Sim/339d7b1a/snapshot` 本轮只读核查为 11,144 文件、5,006,551,294 字节；此前 SHA 验证和恢复证据见审计仓库 Phase2B-Backup 与 Phase2B-Restore。本轮不复制或改写快照；D/E 同物理磁盘，仅作逻辑回滚保护。
原 MATLAB 文件不移动；唯一现有源码变更为 ca_setup。engine 只覆盖其固定目录及 mismatch protocol，预计 C1 不变，须以 MATLAB 实测和覆盖文件字节核查确认。PPID 显式来源清单含 ca_setup，其 SHA 与来源身份会变化；历史锁仍指原始源码，绝不追认到新版本。engine、source manifest 实现、MAT/WTR、协议、锁和历史指标原字节保留。
分别提交 C0/C1，回滚使用普通 git revert，禁止 reset/clean/强推。回滚前保留用户未跟踪项，不操作历史数据。尚未移动文件时不需恢复快照。

## C2 启动门槛

先核对已推送 C0/C1 的静态与 MATLAB 路径验证、六分配器及效能句柄、重复调用稳定性、engine/来源登记与回滚方式。MATLAB 未运行或 FAIL 时不能宣称运行验收完成。C2 还需用户单独授权 W1 文件移动；逐文件复核相对路径、来源身份和迁移前后 SHA；不能等 C8 才处理当波的 engine 失配。本轮在 C1 停止，不自动进入 C2。
