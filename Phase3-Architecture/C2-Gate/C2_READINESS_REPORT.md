# C2/W1 源码迁移最终准入报告

日期：2026-11-05（Asia/Shanghai）。执行者Codex；采用dual-repo-agent-handoff 0.2.2核验既有证据。本轮为任务级Gate，仅交付用户指定六件审计文件，未改既有HANDOFF、manifest、Phase1/Phase3历史矩阵或DEV。

**准入结论：READY_WITH_CONDITIONS；实际执行授权PENDING。** 历史engine来源门槛已RESOLVED；70项清单无覆盖冲突。C2必须包含engine覆盖、ECL构建路径、移动感知静态检查、七份raw字节保存这四项配套修订，详见[审批请求](APPROVAL_REQUEST.md)。本结论不自动授权移动。

## 核查基准

| 仓库 | 分支／HEAD | 状态 |
|---|---|---|
| DEV | refactor/phase3-source / `b2a287ceff34445bb7902890141be7a450d19de9` | 远端同SHA；只读；仅既有.dsh-plugins未跟踪 |
| DEV main | `fdc933694db9c16a0d9ffcd6d9c391b052352d22` | 未改变、未合并 |
| AUDIT起点 | main / `82afe2417bd3c9d7ba7a1d900c2969c9f350a710` | 起点与远端一致；本轮仅新增C2-Gate六文件 |

AUDIT本轮发布提交SHA由Git历史与最终回复提供，避免自引用。科学基准仍339d7b1a997de6ba350cef3207d8a5b7db3d838d。本轮未运行控制仿真、未搬代码、未调用ECL进程或构建。

## 五项完成条件答复

| 问题 | 结论 | 证据 |
|---|---|---|
| 历史engine能否对应真实执行来源 | 是，d4与c640原字节重建后MATLAB复算均精确匹配；ec由后续单份诊断源码变化解释并复现 | [ENGINE_PROVENANCE_ANALYSIS](ENGINE_PROVENANCE_ANALYSIS.md) |
| 70项是否都有源、目标、SHA | 是，69m+1cpp全部源存在，完整raw SHA256；另9KEEP与2DEFER_W6明确登记 | [W1_RESOLVED_PLAN.csv](W1_RESOLVED_PLAN.csv) |
| 有无覆盖/路径冲突 | 70目标均缺失，大小写归一唯一；2README冲突通过延期规避；69函数新父目录全在ca_setup映射；迁移后which尚未执行 | [风险](PATH_AND_DEPENDENCY_RISKS.md) |
| C2风险与回滚 | engine覆盖漏计、cpp构建路径、静态工具误报、7份CRLF保存/回滚；普通revert加必要逐文件raw恢复；70份快照源已核验 | [回滚验证](ROLLBACK_AND_VALIDATION_PLAN.md) |
| 是否建议批准 | 建议有条件批准审批请求中的完整范围，四项配套必须随C2完成；当前不执行 | [审批请求](APPROVAL_REQUEST.md) |

## 本轮实测与未执行

- 静态：81源存在；MOVE70、KEEP9、DEFER_W6两README；70目标无文件/父路径覆盖冲突，69m新目录覆盖，重名虚拟扫描无活动冲突。
- 当前MATLAB路径：R2025b，287名字which -all、6分配器/2效能/14句柄及重复ca_setup均PASS。只查解析与文件，不调用控制链或类构造器。
- engine：当前重复2次、快照、两个历史启动/交付重建目录共12种字节布局、单文件替换及分隔符误用实验；均为哈希与来源读取，不是控制仿真。完整观测见来源报告。
- 显式研究来源：两批各70/70 SHA匹配；原批执行driver恢复来自冻结副本，而非事后修复版。
- 历史ECL二进制恢复UNRESOLVED：旧锁a3f…，当前/快照a68d…，现存build_manifest仍是旧值；已搜索的桥接exe中未找到旧二进制。此项不属于engine哈希输入，限制历史运行环境恢复结论；C2不得改exe或追改旧元数据。
- Git字节：7份MOVE源码raw与旧blob仅CRLF/LF不同，必须在C2发布及回滚验证中单列。快照70/70对应源raw SHA通过；没有复制或修改快照。
- 既有C0/C1证据manifest：13文件校验PASS。本轮六件交付使用下表SHA及精确Git提交校验，不冒称旧manifest覆盖新Gate。
- NOT RUN：迁移后MATLAB、迁移后engine、独立检出目标、C2回滚演练；因为尚未执行C2。控制仿真、ECL运行/重建、全套测试均NOT RUN且不在本轮授权范围。

本轮验证过程中，首次verify_evidence调用误用相对manifest路径被拒绝；改为完整AUDIT内路径后PASS。临时MATLAB脚本名more与内置命令同名出现提示，仅临时驱动名，不在项目path；全部保存的来源计算正常完成。这些工具调用问题没有修改DEV或历史锁。

## 交付字节清单

下表对其余五件文件计算raw SHA256；本报告本身由发布提交保护，不自列哈希。六文件统一UTF-8无BOM、LF；继承阶段现有.gitattributes，不改属性文件。

| 文件 | raw SHA256 |
|---|---|
| [ENGINE_PROVENANCE_ANALYSIS.md](ENGINE_PROVENANCE_ANALYSIS.md) | `3ade4064ad20bbe4995ffc439842ccb397f4ca35aec7e66d04e1158a73c9f6c6` |
| [W1_RESOLVED_PLAN.csv](W1_RESOLVED_PLAN.csv) | `ee0df3e88a46e95ac09f7825d4603de4ceef1cd3393d6aec499337a205b6bedf` |
| [PATH_AND_DEPENDENCY_RISKS.md](PATH_AND_DEPENDENCY_RISKS.md) | `3917e3666b4ead8a54fb37d00a186fbb837aef2f1008bdea3cc2a55f22980903` |
| [ROLLBACK_AND_VALIDATION_PLAN.md](ROLLBACK_AND_VALIDATION_PLAN.md) | `216a9774bb2d824241d5348f2cd27c31e3aaf78b84124efa145f2f1b9cefb36d` |
| [APPROVAL_REQUEST.md](APPROVAL_REQUEST.md) | `3a1fc0069958b0ffae766eedbe1eda2ec52e458acd9e19f954cda35257253e0a` |

## 下一项具体工作

等待用户审批APPROVAL_REQUEST中的完整C2范围。获批后从固定C1 HEAD重新核验执行单及目标，按回滚验证方案完成70项移动及四项配套修订；未获批则保持DEV原状。本轮完成后停止，不自行C2、C3或合并main。
