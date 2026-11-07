# C6/W5 工具、应用、测试、分析整合报告

日期：2026-11-05（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**C6/W5 工程整合 PASS_WITH_DEFERRED；C7/W6 未执行；55 秒 HDT 正式复现 NOT RUN。**

## 1. Gate 结论

W5 共 **223 项**，逐项结论：

| 结论 | 数量 |
|---|---:|
| KEEP | 215 |
| PATCH | 1 |
| DEFER | 7 |
| MOVE | 0 |

原计划 223 项目标路径与原路径相同，未为了形成差异而移动文件。多数 KEEP 属于正常结果；1 个当前工具路径修复，7 个历史/旧基线工具 DEFER 并记录原因。

## 2. 实际修改

| 文件 | 修改 |
|---|---|
| `AGENTS.md` | 将“远端 main 唯一开发分支”改为稳定 main + `refactor/phase3-source` 集成分支 + 每阶段开发分支；补充 Git 恢复、Results/未跟踪数据边界；平台/四环入口路径更新到 `src/` |
| `docs/repository_map.md` | 更新为 C5/W4 后实际布局；区分已实现 `src/airframes/dynamics/studies`、兼容目录、冻结 reference、未来 Results Manager/WindTrace 独立仓库/更名 |
| `tools/repo_inventory.py` | PATCH：`active_dirs` 从旧 `paths={` 解析改为当前 `layouts = {`；目录分类改用 `src/airframes/dynamics/studies` |
| `tools/check_c6_static.py` | 新增轻量 C6 范围/工作流检查器 |
| `docs/refactor/PHASE3_MAPPING.md`、`plan.md`、`HANDOFF.md` | C5/C6 状态与下一阶段指针更新 |

未修改控制器、分配器、估计器、模型、正式指标、协议、来源锁、MAT/WTR 或 ECL。

## 3. 工程验证

| 项目 | 结果 |
|---|---|
| C6 静态范围 | PASS：223 行、215 KEEP/1 PATCH/7 DEFER/0 MOVE，目标全部存在 |
| C5 静态检查 | PASS（C6 检查器纳入跟踪后） |
| Python 工具语法 | 31/31 通过 |
| 当前文档链接 | 90 份/565 链接；仅 2 条历史 validation 旧 `research/ppid_pindi/README.md` 链接，保留为冻结证据 |
| MATLAB 路径 | PASS：287 名字、6 分配器、2 效能、14 句柄 |
| MATLAB 单元/集成 | 7/7 PASS：bus、scheduler、params、plugin conformance、topic chain、SHC09 physics、sensor model |
| Apps | 24/24 W5 入口可由 `which` 解析；未启动 GUI 全流程 |
| PPID | 41,601 点配置；manifest 49 文件，engine `696da7e6…` |
| 平台 smoke | 2 秒 DA_NS PASS，数值有限 |
| WindTrace | 既有 `.wtr` 只读解析 PASS（18 topics、446 parameters、FRD）；pytest 38 passed / 20 skipped |
| Results | 未修改 results/MAT/WTR/协议/锁/ECL；未运行会写 Results 的全套测试 |

### DEFER 及已知限制

- `verify_platform_sources.py`：固定 pre-C2 `drivers/actuators` 基线，当前返回预期失败；未改写旧基线。
- `check_phase3_static.py`（非 W5）：C4 范围检查器，已被 C5/C6 检查器取代。
- `package_f8_results.py`、`package_ppid_pindi.py`、`package_hover_distance.py`：历史批处理打包器；不拿新源码冒充旧批。
- `platform_stage_checks.py`：历史平台阶段脚本，未作为当前门禁。
- `check_repo_hygiene.m`：依赖 C5 前的 `docs/file_inventory.csv`；未重新生成，避免覆盖历史治理证据。
- `check_platform_docs.py`：扫描到根目录 `codex-repo-*` 的历史断链；按任务约定交 C7 归档处理。
- 未运行完整 MATLAB 测试套件、55 秒 HDT、五方法批、ECL 重建、WindTrace GUI 全流程。

## 4. Git 与存储

- DEV 开发分支：`refactor/c6-toolchain`；C6 源码提交 `100061cae7e3c76c9293f8c443213d0175c91a0a`。
- **DEV 最终 HEAD：`400f6b2a1fa972792cf361c3d563ac79b86a4251`**，已 fast-forward 到 `refactor/phase3-source`，已推送。
- main 仍 `fdc933694db9c16a0d9ffcd6d9c391b052352d22`；未修改。
- 未创建完整备份或 Restore-Test；`D:\AeroGNC-Backup`、`D:\AeroGNC-Restore-Test` 保持删除状态。
- 原始科研数据、协议/锁、ECL 未修改。

## 5. C6 结论与下一步

C6 的核心工具、Apps、测试、Analysis 和 WindTrace 只读接口通过；历史/旧基线工具按 DEFER 记录，不被描述为已通过。**C6 不实施 Results Manager，不改 WTR 契约，不进入 C7。**

C7/W6 可开始**只读**准备：文档整理、兼容层、`codex-repo-*` 归档、仓库导航、过期接口清理与历史来源引用；进入 C7 前需独立授权。55 秒 HDT 仍需在 C7–C9 与 Results 治理后单独授权，C6 的通过不构成科研验收。
