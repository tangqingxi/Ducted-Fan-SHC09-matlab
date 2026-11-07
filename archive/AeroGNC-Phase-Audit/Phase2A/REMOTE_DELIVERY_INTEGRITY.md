# Phase1远端交付完整性与后续核验方案

## 本次核实结论

核对审计仓库远端提交`3dbd1207bca0ca15c22a13ec4c0b2734b8f7e630`，覆盖Phase1 OUTPUT_MANIFEST列出的49个文件（旧清单按设计不列自身）。**49个本地文件全部匹配原清单SHA；远端13个逐字节相同，36个仅CRLF/LF差异，实际内容差异0。** 不是49个文件均在远端损坏，也不能把本地SHA和远端SHA混用。

GitHub递归tree返回的49项OID与大小全部匹配fetch取得的对象；逐对象重新计算Git blob OID也全部一致。另通过GitHub文件API直接读取PLAN.md与PHASE1_REPORT.md的完整base64内容，解码后与对应Git blob逐字节相同。不是仅凭网页渲染正常便认定内容一致。

详细证据：[逐文件对照CSV](evidence/PHASE1_REMOTE_INTEGRITY.csv)、[核验汇总](evidence/PHASE1_INTEGRITY_SUMMARY.json)、[GitHub API/tree样本](evidence/AUDIT_REMOTE_SAMPLES.json)。本轮没有修改Phase1原清单、原始文档或旧证据。

## 四种身份及不能互换的数值

| 对象 | 度量 | 用途 |
|---|---|---|
| 本地工作文件 | 原始字节数、SHA256、换行计数 | 原OUTPUT_MANIFEST承诺的本机产物身份 |
| Git blob OID | 当前仓库为SHA1对象ID，覆盖`blob <长度>\0`头及内容 | Git存储身份；不能直接与文件SHA256比较 |
| Git blob正文 | 字节数、正文SHA256 | 实际提交/发布的字节身份 |
| GitHub API/raw文件 | 解码后的实际正文、API给出的OID/大小 | 验证平台交付与远端Git对象一致 |

例如AGENT_REPORT_MIGRATION.csv本地4517字节，blob为4499字节，18个CRLF转换为LF；规范化后正文完全一致。PLAN.md的GitHub API正文5233字节，SHA256为`633dca8db2c5cf7d5b1be8bad99c38cc003d5d5b5209c04fc3250b4ffc2393f7`，对应blob OID为`b40e6d8f3bebf20b7b5ca73f244b64793a0676b8`。两种hash算法及输入范围不同，不存在相等要求。

Git的text/eol与autocrlf可使工作树文本和提交正文采用不同换行，具体规则以属性优先级为准，见[Git官方gitattributes文档](https://git-scm.com/docs/gitattributes)。本次不是凭配置推测：已对每个不同文件实际比较`CRLF→LF`后的字节。该归一化只用于解释文本差异，绝不用于放宽MAT/WTR/EXE或来源锁的原始字节验收。

## 历史清单的修订建议，尚未执行

保留原OUTPUT_MANIFEST作为local_worktree_bytes_v1，另新增版本化发布账本，字段包含path、source_local_size/SHA256、git_blob_oid及algorithm、published_size/SHA256、normalization、verified_ref和证据。禁止直接用远端数值覆盖旧清单，禁止重新签署旧本地工件为另一种字节身份。是否正式修订历史交付格式等待用户审批。

Phase2A新增作用域内的.gitattributes只规定本阶段文本LF，不向Phase1或主仓库应用规则，也不做renormalize历史文件。新文件以UTF-8无BOM/LF生成；提交前比较工作文件与暂存blob的字节及SHA256，有差异即暂停，不静默接受。

## Phase2A交付核验流程

1. 本地：校验schema及示例、清单字段/计数、相对链接、主仓库保护状态和敏感内容；生成DELIVERY_MANIFEST列工作文件size/SHA256，明确排除自身，避免自引用。
2. 暂存：只`git add -- Phase2A/`；检查缓存diff与范围；逐文件核对工作字节=暂存blob正文，计算OID与正文SHA256，不引入旧目录变更。
3. 发布：普通commit并push origin HEAD:main，不强推；核实本地、远端SHA相同。
4. GitHub：读取固定提交的递归tree，逐项比较全部Phase2A文件OID/大小；通过已固定SHA获取原始blob正文，按DELIVERY_MANIFEST核对；直接检查主要报告/Schema/示例的API内容及全部相对链接目标。超出API单文件限制的清单采用tree OID与Git协议对象的完整字节证明，不截断后比较hash。

最终交付回复记录实际提交SHA、GitHub报告链接和发布核验结果。本文件随交付提交，不写自身未来SHA。推送后若发现实际内容不一致，停止交付并追加可追溯修订提交，不修改旧提交。
