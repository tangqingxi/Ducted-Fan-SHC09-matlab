# Phase3 C3/W2 执行报告

日期：2026-11-05（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。状态：**C3/W2 工程迁移执行与获准验证 PASS；C4 未执行**。这是工程迁移验收，不是新的控制仿真、ECL 恢复或历史科研结果重算。

## 精确 Git 状态

- DEV 起点：`269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`，分支 `refactor/phase3-source`。
- C3 提交：`9d8f8aec7d3b8316f5ae99cba45f422e74cc984c`，已普通推送，远端 refs/heads/refactor/phase3-source 同 SHA；提交树 `eecbfded7bb7c21f3dc5734a8fa6351ccfcd3591`。
- DEV main：`fdc933694db9c16a0d9ffcd6d9c391b052352d22`，未合并、未改名；科学基准仍 `339d7b1a997de6ba350cef3207d8a5b7db3d838d`。
- DEV 工作区：仅既有 `.dsh-plugins/` 未跟踪（8 文件，保留）；无任务外暂存或未暂存修改。
- AUDIT 起点：`51889c134741c913b0c5e15a11b4a4ce63de28ae`；本报告、清单和交接随 AUDIT 新提交发布，发布 SHA 由 Git 历史和最终回复给出，不自引用。
- 本轮未执行 C4、未移动模型/研究目录、未合并 main、未改仓库名。

## 授权与最终范围

依据 [APPROVAL_REQUEST.md](../C3-Gate/APPROVAL_REQUEST.md) 的完整批准范围和 [W2_RESOLVED_PLAN.csv](../C3-Gate/W2_RESOLVED_PLAN.csv)（SHA256 `e2a63faf87830338df97e172e95a1b3036c33c1a5e5832244565f929529a7e4f`）：

- 五条 MOVE：`effectiveness_for_model.m`、`effectiveness_registry.m`、`hover_linear_effectiveness.m`、`shc09_6vane_effectiveness.m`、`shc09_nominal_effectiveness.m` 按执行单 `git mv` 到 `src/effectiveness` 对应位置；源 raw 字节保持不变。
- 原 W2 的 33 项分配器文件全部 KEEP；顶层 `allocators/registry.m`、六算法/包装/句柄、`allocators/interface` 均未改；没有创建 `allocators/plugins`，`src/allocation` 仍只保留规划 README。
- 三份配套：`analysis/allocation_comparison_engine.m` 仅新增 `"src/effectiveness"` 显式覆盖；`tools/check_phase3_static.py` 精确改为 C2 基准/W2 执行单/MOVE5/KEEP33/DEFER1/三配套；`effectiveness/README.md` 仅改第 5、16 行两处链接。
- `effectiveness/README.md` 作为 DEFER 文件保留原位；`src/effectiveness/README.md` 占位文件保持原字节，未被覆盖。
- 未改 `ca_setup.m`、registry 返回字段、`ppid_source_manifest.m`、`allocation_comparison_hash.m`、历史锁、协议、MAT/WTR、EXE 或 build_manifest。

## 实际改动

C3 提交共 8 个路径：5 个重命名（100% 相似度）+ 3 个配套修改；`115 insertions(+), 61 deletions(-)`，其中大部分是静态检查器按新规则重写。

| 源 | 目标 | raw SHA256 |
|---|---|---|
| `effectiveness/effectiveness_for_model.m` | `src/effectiveness/effectiveness_for_model.m` | `16534021978e4760b33401f35c726a8d3ec1ca7a47f697bde9dc887ade907407` |
| `effectiveness/effectiveness_registry.m` | `src/effectiveness/effectiveness_registry.m` | `1ffdc738f0d85a733625068fb71c55ddd435387aabe44db8b0da902e8bd66605` |
| `effectiveness/hover_linear/hover_linear_effectiveness.m` | `src/effectiveness/hover_linear/hover_linear_effectiveness.m` | `c888a6a61ea09d74fad9d169a1e5ea8bc214fc67c16fb63c97ab3b23806e2623` |
| `effectiveness/shc09_6vane/shc09_6vane_effectiveness.m` | `src/effectiveness/shc09_6vane/shc09_6vane_effectiveness.m` | `1bb7f60ccfc951455e95f85602415d1250bdc31330b460fc10727e1309015c38` |
| `effectiveness/shc09_nominal_effectiveness.m` | `src/effectiveness/shc09_nominal_effectiveness.m` | `8aa22110d05702d47567e96252371b4ccc97f284034398c785b5aa1e4002df66` |

三份配套的新 raw SHA：

- `analysis/allocation_comparison_engine.m`：`9463ed3ac3ebc7924fdeb4ab6e196774f5d4a4709cc70eb4be3d28894d9fe8c5`（C2 为 `e53fff0da2f16e2e86edb09051c4b8ad947f3136a5c8f7d9c3b716d429d43cd3`）。
- `effectiveness/README.md`：`68c75d2615616070d7a130f7d2f9f1da5500aaf054228780c3000f303970bf33`（C2 为 `d20238198253c0105a95618912aea364c11d3a1775ce4f4ace4b52293b513c5f`，反向替换两链接后匹配）。
- `tools/check_phase3_static.py`：`8246bfe0c4c74125fdbd5435f9381641f5d6031fa137dec28beb93d30b4a9e8c`。

## 验证结果

| 检查 | 结果 | 证据与口径 |
|---|---|---|
| 执行单身份与计数 | PASS：39 行 = KEEP33/MOVE5/DEFER1；5 目标互异 | [STATIC_VERIFICATION.json](STATIC_VERIFICATION.json) |
| 源/目标 raw 字节 | PASS：5/5 源存在且 raw 等于执行单；5 目标迁移后存在且 raw 不变；旧源不存在 | [MOVED_FILES_VERIFICATION.csv](MOVED_FILES_VERIFICATION.csv) |
| 静态范围与保护 | PASS：C2 清单 1,761 项；三配套外 1,758 项 raw 校验；仅 5 D/5 A/3 M；无任务外未跟踪文件（`.dsh-plugins/` 除外） | [STATIC_VERIFICATION.json](STATIC_VERIFICATION.json)、[C2 清单](C2_TRACKED_RAW_SHA256.json) |
| MATLAB 路径与句柄 | PASS：287 名字、6 分配器、2 效能、14 句柄、重复 `ca_setup` 路径稳定；五函数 `which -all` 唯一且等于五个目标 | [PATH_RESOLUTION_VERIFICATION.json](PATH_RESOLUTION_VERIFICATION.json)、[MATLAB_C3_RESULT.json](MATLAB_C3_RESULT.json) |
| engine | PASS：C3 `481bd57c…`；121 项；五路径改变、五 raw 不变；其余 116 项路径/raw 不变；无重名 | [ENGINE_FILES_C3.json](ENGINE_FILES_C3.json)、[ENGINE_IDENTITY_TRANSITION.md](ENGINE_IDENTITY_TRANSITION.md) |
| PPID 显式来源 | PASS：49 文件集合不变；唯一显式 SHA 变化为 engine 实现文件；`px4_ecl_bridge.exe` 仍为 `a68d4884…` | [SOURCE_MANIFEST_DELTA.json](SOURCE_MANIFEST_DELTA.json) |
| 受保护文件 | PASS：73,393 文件、20.1 GiB（21,610,310,966 字节）；前后 canonical SHA256 均为 `848d4efc8bb7d85c6baad5a33e0ccb36632da7278b1b0f27fc384ce681bcf5ca` | [PROTECTED_FILES_VERIFICATION.json](PROTECTED_FILES_VERIFICATION.json) |
| Git blob/树/独立检出 | PASS：候选树=提交树 `eecbfded…`；五目标 blob raw 与三配套一致；独立 worktree 五移动+三配套 PASS；全树 raw 在普通检出下受既有换行过滤影响，见诊断 | [GIT_BLOB_AND_CHECKOUT_VERIFICATION.json](GIT_BLOB_AND_CHECKOUT_VERIFICATION.json)、[FAILED_CHECKS.json](FAILED_CHECKS.json) |
| 回滚演练 | PASS：独立 worktree 普通 `revert --no-commit` 后 index tree 回到 C2 树 `ab3771cf…`；五源恢复、五目标消失、三配套回 C2 raw；真实 DEV 未回滚 | [ROLLBACK_DRY_RUN.json](ROLLBACK_DRY_RUN.json) |
| 文档链接 | PASS：常规工具 90 份 Markdown/565 链接/0 断链；`effectiveness/README.md` 三条本地链接均存在 | [DOC_LINK_VERIFICATION.json](DOC_LINK_VERIFICATION.json) |
| 控制仿真/ECL/全套测试 | NOT RUN：不在本轮授权范围 | 本报告“限制” |

MATLAB 环境：`25.2.0.2998904 (R2025b)`；未调用控制算法、未推进工厂对象、未持久修改路径。

## engine 与来源身份

- C2 engine：`19ce8d8136471d32f807de051183d3cca272233cb2b14d3e6fa988b0dfa89e63`。
- C3 engine：`481bd57cc57a7abe0180094d0846dfe5fe20c0548b269814023eb7af65837d05`。
- 两者均 121 项；C3 只替换五份效能文件路径，raw 字节不变；其余 116 项不变。差异来自路径参与序列化，是预期来源身份变化，不能据此宣称历史正式批可由 C3 engine 复现。
- `analysis/allocation_comparison_engine.m` 的反向删除 `,"src/effectiveness"` 后与 C2 原字节一致；静态工具对此做了断言。
- 历史 `a3f…` ECL 二进制恢复仍 UNRESOLVED；当前 `a68d…`、历史 `build_manifest`、正式锁和原始数据均未改。

## 受保护文件与 Git 检出

受保护根：`results`、`logs`、`figures`、`docs/validation`、`build/px4_ecl`，共 73,393 文件、21,610,310,966 字节（约 20.1 GiB）。本轮在 C3 前后各做一次全量 raw SHA256 映射，前后逐项相同；canonical hash 为 `848d4efc8bb7d85c6baad5a33e0ccb36632da7278b1b0f27fc384ce681bcf5ca`。C2 记录的 `a73ae04…` 采用其脚本的路径前缀/序列化口径，公开证据无法逐一复原该口径，故不能直接比较数值；本报告以本轮自洽的 before/after 相等为准，文件数、根集合与 C2 一致。

Git 验证分三层：索引候选树（`git checkout-index`，不加工作树过滤器）1,761 项全 raw PASS；提交树与候选树相同；独立 `git worktree` 检出后五移动+三配套 PASS。普通 worktree 的全树 raw 比对在 `.gitattributes` 处出现差异：提交 blob 的 raw 为 `4855d5ec…`，普通检出为 `d166d70b…`，原因是既有 `* text=auto` 与 `core.autocrlf=true`；这不是 C3 源码变化，已在 [FAILED_CHECKS.json](FAILED_CHECKS.json) 记录为非阻塞诊断，未为通过检查而修改换行策略。

## 限制与未运行项

- 未运行任何控制仿真、2 秒短例、52/55 秒、多方法/多种子、ECL 构建/运行或全套测试；不能把静态、路径和 engine PASS 当作飞行/科研验收。
- 历史 ECL 二进制 `a3f…` 恢复仍 UNRESOLVED；当前 `a68d…` 与历史 `build_manifest` 保持原字节，本轮未重建、未追改锁。
- DEV `HANDOFF.md` 仍写“仅 C0/C1、不移动 .m”，`docs/refactor/PHASE3_MAPPING.md` 仍把 allocators 指向 `allocators/plugins`，均与本轮 C2/C3 现状或 ADR-C3-W2-v1 冲突。因 C3 执行单绑定 `269564d`，本轮未修改这两份文档；需在后续独立文档任务中最小修正并重新绑定后续执行单。
- 快照/备份只在 D/E 同物理盘提供逻辑回滚保护；不是独立容灾。
- `.dsh-plugins/` 8 个未跟踪文件保持原状；未清理任何失败项或半成品。

## 复现命令

在 DEV 根运行：

```powershell
python tools/check_phase3_static.py --plan E:/AeroGNC-Phase-Audit/Phase3-Architecture/C3-Gate/W2_RESOLVED_PLAN.csv --inventory E:/AeroGNC-Phase-Audit/Phase3-Architecture/C3-Execution/C2_TRACKED_RAW_SHA256.json
python tools/check_docs_links.py
matlab -batch "restoredefaultpath; addpath(pwd); addpath(fullfile(pwd,'tools')); report=check_phase3_paths(pwd); disp(report.status)"
```

MATLAB 五函数定向断言、C3 engine 和 PPID manifest 见 [MATLAB_C3_RESULT.json](MATLAB_C3_RESULT.json)；Git 树/独立检出命令见 [GIT_BLOB_AND_CHECKOUT_VERIFICATION.json](GIT_BLOB_AND_CHECKOUT_VERIFICATION.json)。

## 下一步

C3 已完成并推送；不自动进入 C4、不移动 `models`/研究目录、不合并 main。下一项应在用户另行授权后，只读准备 C4/W3（`models` → `airframes`）Gate；同时另开文档任务修正上述两份 DEV 文档漂移。
