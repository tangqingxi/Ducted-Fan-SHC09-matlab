# Phase3 C4/W3 执行报告

日期：2026-11-05（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**C4/W3 设计冻结、源码迁移与 MATLAB 工程验收 PASS；Hover-Distance-Takeoff 55 秒复现 NOT RUN；C5/W4 未执行**。本报告只覆盖架构迁移与工程验证，不是新的控制仿真、ECL 恢复或历史科研结论。

## 1. 阶段状态

| Phase | 内容 | 状态 |
|---|---|---|
| A | 设计成果冻结、plan.md 入库 | PASS：DEV `b60080f…`；AUDIT 设计 `4c49a9a…`，Adapter 路径修订 `fc4df3b…` |
| B | 迁移前 Preflight | PASS：[C4_PREFLIGHT.json](C4_PREFLIGHT.json) |
| C | 8 文件迁移 | PASS：DEV 源码提交 `d21b49f…`；7 纯移动 + 1 路径补丁 |
| D | 配套修复与文档 | PASS：DEV 文档/交接提交 `661eecc…` |
| E | 静态、MATLAB、模型、engine、smoke | PASS；E5 只做 2 秒非正式 smoke |
| F | 独立审计与回滚演练 | PASS（回滚 raw 有检出过滤诊断） |
| G | plan.md 与 DEV HANDOFF | PASS：C4 标记完成，55 秒复现未开始 |
| H | Git 提交/推送 | PASS：DEV 已推送；AUDIT 执行证据随本报告提交 |

## 2. 固定身份与最终目录

- DEV 分支：`refactor/phase3-source`；最终 HEAD `661eecc97d29a56e4ba1857abb6f5a6364ef1946`，远端同 SHA；main 仍 `fdc933694db9c16a0d9ffcd6d9c391b052352d22`。
- C4 设计冻结基线：DEV `b60080f811a969e00eaefb0dc56e419b6cf4d4ea`；AUDIT 设计 `4c49a9ae2742b3805eba54babb97a20900ebbb9c`，路径修订 `fc4df3b715c6f7f337ae2346c96abfb234393dfb`。
- C4 源码提交：`d21b49fc01aa36d70637991916ad485a9b4653a8`；最终树 `e34c3e42a3faf817ce941dcbf0809b243dadaaa3`。
- 工作区：仅既有 `.dsh-plugins/` 未跟踪（8 文件）；无任务外修改。

最终活动目录：

```text
airframes/shc09/                 ca_model.m, ca_shc09_parameters.m
dynamics/shc09/plant/            ca_plant_init.m, ca_plant_step.m, ca_plant_outputs.m
dynamics/shc09/nonlinear_6dof/   ca_shc09_aerodynamics.m
dynamics/shc09/hover_reduced_order/ ca_model_hover.m
src/control/frame/               ca_reference_to_b.m（Adapter）
models/shc09/reference/          8 个冻结文件 KEEP 原位
configs/airframes/shc09_airframe.m  KEEP；Scenario 预设，改名 DEFER
```

`ca_reference_to_b` 原设计目标 `src/control/reference` 被 `check_phase3_paths` 的 `/reference/` 冻结路径规则拒绝；AUDIT 设计修订 `fc4df3b` 改为 `src/control/frame`，职责和内容不变。这是执行期发现的路径兼容修正，不是算法修改。

## 3. 迁移结果

8 个活动文件：

| 原路径 | 新路径 | 结果 |
|---|---|---|
| `models/shc09/ca_model.m` | `airframes/shc09/ca_model.m` | raw 不变 |
| `models/shc09/ca_shc09_parameters.m` | `airframes/shc09/ca_shc09_parameters.m` | 仅 reference 定位补丁 |
| `models/shc09/ca_plant_init.m` | `dynamics/shc09/plant/ca_plant_init.m` | raw 不变 |
| `models/shc09/ca_plant_step.m` | `dynamics/shc09/plant/ca_plant_step.m` | raw 不变 |
| `models/shc09/ca_plant_outputs.m` | `dynamics/shc09/plant/ca_plant_outputs.m` | raw 不变 |
| `models/shc09/ca_shc09_aerodynamics.m` | `dynamics/shc09/nonlinear_6dof/ca_shc09_aerodynamics.m` | raw 不变 |
| `models/shc09/ca_model_hover.m` | `dynamics/shc09/hover_reduced_order/ca_model_hover.m` | raw 不变 |
| `models/shc09/ca_reference_to_b.m` | `src/control/frame/ca_reference_to_b.m` | raw 不变 |

- 7 个纯移动 raw SHA 与迁移前完全一致；旧路径不存在；Git 重命名追踪保留。
- `ca_shc09_parameters`：old `9a12a7ac…` → new `5e560065…`；只把 `fullfile(folder,'reference',...)` 改为从仓库根定位 `models/shc09/reference`，不复制、不移动、不修改 MAT、spline、常数、坐标或限幅。
- 8 个冻结 reference 文件原位、原字节；raw SHA 与 `docs/physical_reference.json` 全部一致。
- 6 个 CRLF 目标使用精确 `-text` 规则，未执行全仓 renormalize；`ca_plant_outputs` 与 Adapter 为 LF，无需规则。
- 配套修改：`ca_setup.m` 增加 dynamics/frame 显式路径；engine 增加 `airframes`/`dynamics`；静态检查器改为 C4 范围；当前文档更新；历史锁、旧 baseline、MAT/WTR/EXE 未改。详见 [C4_SUPPORT_CHANGES.csv](../C4-Design/C4_SUPPORT_CHANGES.csv)。

## 4. 工程验证

| 检查 | 结果 | 证据 |
|---|---|---|
| Preflight | PASS：8 源 raw、8 reference、8 目标不存在、MATLAB 当前路径、ca_setup、engine、protected | [C4_PREFLIGHT.json](C4_PREFLIGHT.json) |
| 静态范围 | PASS：1,762 项迁移前清单；8 MOVE、9 KEEP；1744 项 raw 校验；engine 121；仅批准变更 | [STATIC_VERIFICATION_C4.json](STATIC_VERIFICATION_C4.json) |
| MATLAB 路径/句柄 | PASS：287 名字、6 分配器、2 效能、14 句柄；8 函数唯一解析到目标 | [MATLAB_POST_MIGRATION.json](MATLAB_POST_MIGRATION.json) |
| 模型一致性 | PASS：six_dof/hover 模型、状态、输出、单步、参考适配、参数逐字段等于迁移前 | [MODEL_EQUIVALENCE.json](MODEL_EQUIVALENCE.json) |
| Engine | PASS：`481bd57c…` → `fb7cf780…`；121 项，8 条路径改变；无漏计/重复 | [ENGINE_FILES_C4.json](ENGINE_FILES_C4.json) |
| Source Manifest | PASS：49 文件集合不变；仅 `ca_setup.m` 与 engine 实现 SHA 变化；EKF EXE `a68d…` 不变 | [SOURCE_MANIFEST_DELTA_C4.json](SOURCE_MANIFEST_DELTA_C4.json) |
| 受保护文件 | PASS：73,393 文件/20.1 GiB；前后 canonical `848d4efc…` 相同 | [PROTECTED_FILES_VERIFICATION_C4.json](PROTECTED_FILES_VERIFICATION_C4.json) |
| Git/独立检出/回滚 | PASS：提交树、8 目标 raw、reference、独立 checkout MATLAB；revert tree 等于 base | [GIT_AND_ROLLBACK_VERIFICATION.json](GIT_AND_ROLLBACK_VERIFICATION.json) |
| 短时 smoke | PASS：2 秒 DA_NS，T=2，数值有限，`elapsed_s=8.05` | [SMOKE_TEST.json](SMOKE_TEST.json) |
| 历史 55 秒复现 | NOT RUN：只建立兼容基础 | 本报告 |

- 当前 engine 121 项包含 6 个 reference 历史 `.m` 和 8 个活动 `.m`；迁移后仍 121。
- 2 秒 smoke 不是 55 秒正式研究批，不能据此宣布历史复现通过。
- 未运行五方法 × 三种子正式批、ECL 构建/运行或全套测试。

## 5. 失败、诊断与限制

- `check_phase3_paths` 拒绝 `/reference/` 路径：Adapter 设计目标由 `src/control/reference` 修订为 `src/control/frame`，AUDIT `fc4df3b`；修订后 287 名字 PASS。
- Smoke 的第一次/第二次/第三次脚本分别误用 `log.time_s`、`numel` 矩阵、`table2array` cell 列；这些是验证脚本错误，最终 2 秒 smoke PASS，源码未因此修改。
- 回滚树 `dc2ba059…` 等于 `b60080f` 树；旧路径内容通过 Git 对象核对一致。移除 C4 `-text` 规则后，普通检出会把六份 CRLF 旧路径按 LF 呈现，属于检出过滤，不是回滚内容变化。
- `tests/baseline/protected_sources.json` 是 C2 前 fixed_path 基线，当前已在 `drivers/actuators` 失败；未作为 C4 门禁，也未修改旧 baseline。
- HDT 55 秒、五方法正式批、ECL、全套测试均 NOT RUN；历史 ECL `a3f…` 仍 UNRESOLVED。

## 6. C5/W4 初步结论

**C5/W4 尚未 READY，不能直接执行。** 本轮只完成 C4；C5 需要单独 Gate，至少解决：

- research/experiments 两条链的入口、协议、来源锁和 engine 覆盖；
- 研究代码中硬编码路径、`ppid_source_manifest` 显式文件集合及历史锁映射；
- 研究目录拆分不能改变控制器/估计器/协议数值行为；
- `.wtr`/Results 与历史证据的只读边界；
- 需要重新绑定 C5 版本化执行单和独立回滚方案。

## 7. Git 与下一阶段

- DEV：`661eecc…` 已推送；`main` 未改；工作区仅 `.dsh-plugins/`。
- AUDIT：设计冻结 `4c49a9a` / `fc4df3b`；本执行报告与证据随本次 AUDIT 提交发布，发布 SHA 见最终回复。
- 下一步：用户/管理员审查本报告；如批准，另立 C5/W4 Gate 只读准备。C4 完成后不自动执行 C5、不自动跑 55 秒正式批、不合并 main。
