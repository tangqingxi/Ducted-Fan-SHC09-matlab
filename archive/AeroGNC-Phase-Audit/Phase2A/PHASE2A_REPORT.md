# AeroGNC-Sim Phase2A交付报告

日期：2026-11-04（Asia/Shanghai）。范围：基准身份冻结、数据保护规划、Results Governance合同与实施设计、Phase1发布字节核验、Phase2B审批方案。

**重构起始基准固定为main@`339d7b1a997de6ba350cef3207d8a5b7db3d838d`。本阶段只在独立审计仓库写入设计与核验证据，没有修改MATLAB主仓库，没有复制原始数据、真实登记/迁移Results、运行仿真或执行Phase2B。**

## 1. 当前状态与历史修正

主仓库工作区干净，本地main/origin/main/远端main同SHA，远端仅main一个开发分支；实际只剩E盘一个Git worktree。controller-ppid-p-indi工作树及本地分支已经移除，不能继续沿用Phase1或Git-Convergence报告中“仍保留C盘工作树”的历史描述。旧报告保持原文，现场证据见[BASELINE_STATE.json](evidence/BASELINE_STATE.json)。

原change-B、Round 1–7、GNSS-GM-v2与当前WindTrace配套实现均包含于基准；没有重建或合并已删除的旧分支。来源锁、原生字节、两条运行链和路径指纹边界见[BASELINE_FREEZE.md](BASELINE_FREEZE.md)。

GNSS 1000 s单条55 s回归真实水平RMSE0.781936 m、峰值1.629143 m，恢复窗最小真实水平误差0.4770444895 m，大于原0.2 m半径。数值完成及融合执行不代表真实恢复通过。该问题已经作为[Issue #1：Backlog，暂缓，非重构阻塞](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)记录，用户决定不在当前任务处理；本轮不调参、不改算法、不放宽判据，也不要求先修复它才开展结构治理。

## 2. 数据保护清单与容量

复用Phase1的96,300文件索引，没有重新递归扫描全仓。定向stat选定保护项，并枚举当前/一个拟回退Viewer完整包确认成员集合；保护范围11,144项均存在且元数据与既有索引一致，没有发现新成员或变化。

| 内容 | 核实结果 |
|---|---:|
| 保护计划source_path去重文件数 | **11,144** |
| 原始字节总数 | **5,006,551,294** |
| 容量 | 5.006551294 GB / 4.662714241 GiB |
| P0优先保护 | 4036项 / 2,731,688,785字节 |
| P1随后保护 | 7108项 / 2,274,862,509字节 |
| 保留类别 | KEEP_ACTIVE 3240；KEEP_EVIDENCE 7427；REVIEW_REQUIRED 477 |
| 复用Phase1已核验SHA | 476项 |
| 复用Git-Convergence完整SHA并匹配元数据 | 8123项 |
| 本阶段定向完整SHA读取 | 2545项 |

清单覆盖30份正式原MAT、33份正式/预检WTR、三个预检的来源/协议/输入、原执行与管理性中断续跑记录、GNSS v2独立55 s、Round 1–7、历史锁与重要科学证据、17份Agent报告、源码原生字节、ECL构建身份、WindTrace在用整包及一个拟回退整包。不是只保存EXE便宣称保存了依赖。

主清单：[BACKUP_PLAN.csv](BACKUP_PLAN.csv)；范围和状态：[BACKUP_SUMMARY.json](evidence/BACKUP_SUMMARY.json)。SHA复用明确标metadata_matched_prior_full_hash，未谎称本轮全部重读，也未将备份/恢复状态标通过。所有行均PLANNED_NOT_COPIED；BACKUP_ROOT未指定。

另有66,141项历史Viewer构建/回退文件17,291,319,456字节列ARCHIVE_CANDIDATE、整个Python环境列REVIEW_REQUIRED等排除组，详见[BACKUP_SCOPE_EXCLUSIONS.csv](BACKUP_SCOPE_EXCLUSIONS.csv)。它们没有被删除，未计入当前5.007 GB独立备份容量；必要时另批扩展范围。38个缓存/临时类仅为本次排除范围内的DELETE_CANDIDATE，不是获批删除单。

一份完整副本加25%余量需6,258,189,118字节，建议每处独立存储至少8 GiB可用；建议两处独立副本合计预算至少12,516,378,235字节，另准备独立恢复scratch。不同故障域/物理设备或受控版本存储由用户指定；同一E盘两个文件夹及GitHub审计CSV/JSON不算独立原始数据备份。

## 3. Results管理最终设计

通用布局为`results/<study>/<batch_id>/`，另有_index和_scratch。批次内划分protocol、provenance、inputs、raw、metrics、figures、wtr、validation、management。study/airframe动态可扩展，批次/run/artifact身份不靠hover名称或文件前缀推导。

execution_status、acceptance_status、retention_status独立保存；备份及恢复另有证据状态。历史正式批可同时正确表达completed、failed、KEEP_EVIDENCE及真实恢复0/15。相同协议不同engine、新旧源码、不同GNSS版本分别登记；中断只补未运行项，不覆盖已完成或失败run。旧路径通过root/相对locator及_index映射，不回写原MAT或旧锁。

合同：[RESULTS_MANIFEST_SCHEMA.json](RESULTS_MANIFEST_SCHEMA.json)；两个真实证据示例及来源限制：[RESULTS_MANIFEST_EXAMPLES.md](RESULTS_MANIFEST_EXAMPLES.md)；状态/续跑/归档/回滚规则：[RESULTS_LIFECYCLE.md](RESULTS_LIFECYCLE.md)。示例保存在审计仓库，不是已执行原址登记。

下一阶段Manager接口定义inventory、validate、link、plan-migrate、plan-archive、verify-backup、report，默认只读/dry-run、显式root与output、拒绝覆盖、源/目的地hash分别核验、Windows/Linux路径约束、逐文件回滚与独立删除审批。详见[RESULTS_MANAGER_SPEC.md](RESULTS_MANAGER_SPEC.md)。本阶段未实现主库manager。

## 4. Phase1交付差异定论

针对旧OUTPUT_MANIFEST的49项，本地49项均匹配原始清单；远端13项逐字节相同、36项仅CRLF/LF差异，实际内容修改0。GitHub tree的OID/字节与fetch对象全部一致，两个正文样本也通过GitHub API核对。

本地工作SHA256、Git blob OID、blob正文SHA256和GitHub正文分别列出，不能互换。旧清单没有修改；建议新增版本化发布账本，等待批准。详见[REMOTE_DELIVERY_INTEGRITY.md](REMOTE_DELIVERY_INTEGRITY.md)及[逐文件CSV](evidence/PHASE1_REMOTE_INTEGRITY.csv)。

## 5. 验证、公开交付与停止边界

Draft2020-12 schema本身、两个真实manifest及11项负例/动态研究检查已验证；保护文件元数据、主仓库Git状态、Phase1原49项SHA、链接、敏感凭据/个人路径、非文本/大文件与LF规则纳入最终核验。结果见[evidence/VALIDATION.json](evidence/VALIDATION.json)。这些是审计合同检查，不能冒充备份恢复、GUI启动或科学性能验收。

本轮全部交付限定于Phase2A目录，未加入大型MAT/WTR/EXE或虚拟环境。交付文件清单及正文SHA见[DELIVERY_MANIFEST.json](DELIVERY_MANIFEST.json)，清单按设计不列自身；暂存时对其自身也单独核对工作字节与Git blob。原Phase1及Git-Convergence文件不变。

审计仓库从main@3dbd120开始，完成后以`docs(audit): complete AeroGNC Phase 2A`提交并普通推送至main。最终提交SHA、远端SHA一致性及GitHub全文件访问核验结果记录在本次交付回复，不向报告写入无法预先知道的自身提交SHA。

进入Phase2B前需批准：独立备份介质/root、11,144项保护范围/优先级、Viewer回退包选择、恢复抽查、实际登记权限、首批逐文件迁移/回滚单、额外构建包归档范围及后续主库写入/验证预算。基准选择与Issue暂缓决定不重复请求。见[APPROVAL_REQUEST.md](APPROVAL_REQUEST.md)和[PHASE2B_EXECUTION_PLAN.md](PHASE2B_EXECUTION_PLAN.md)。

完成Phase2A发布后停止等待审核，不执行复制、登记、移动、删除、源码重构、仓库更名或WindTrace拆分。
