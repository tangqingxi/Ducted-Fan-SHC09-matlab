# Phase3 C2/W1 执行报告

日期：2026-11-05（Asia/Shanghai）。执行者Codex；dual-repo-agent-handoff 0.2.2。状态：**C2执行与获准验证PASS；C3未执行**。这是工程迁移验收，不是新的控制仿真或历史科研结果重算。

## 精确Git状态

- DEV起点b2a287ceff34445bb7902890141be7a450d19de9，分支refactor/phase3-source；本轮独立提交`269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`，已正常推送，远端SHA核对一致。
- DEV main仍fdc933694db9c16a0d9ffcd6d9c391b052352d22；科学基准仍339d7b1a997de6ba350cef3207d8a5b7db3d838d。
- DEV工作区仅既有.dsh-plugins未跟踪，其完整文件集合与raw SHA未变；无任务外文件暂存。
- AUDIT起点main@f235e845cdb8c9a5a40ce581dc95a1d390ce4c44；本阶段只新增C2-Execution轻量证据。AUDIT发布SHA由Git历史及最终回复提供，不自引用。

## 授权与最终范围

依据固定Gate执行单（raw SHA ee0df3e88a46e95ac09f7825d4603de4ceef1cd3393d6aec499337a205b6bedf）：MOVE70（69m+1cpp）全部git mv；KEEP9、DEFER_W6两README全部保留原位与原始SHA。

四项配套为engine显式覆盖、ECL构建源路径、严格迁移静态检查器、七个精确目标-text规则。首次Markdown检查发现docs/reference/f8_protocol.md:72的一处旧路径链接，已暂停并取得用户明确补充授权；最终仅替换该链接到src/control/position_control/ca_f8_position_control.m。静态检查器要求反向替换后整份文档raw SHA等于C1记录，其他协议文字与参数不变。总计70项重命名及5份原位文件修改（四配套+授权链接），一个C2提交；未修改其他DEV文档。

## 验证结果

| 检查 | 状态与结果 | 证据 |
|---|---|---|
| 源/目标、字节与保留项 | PASS：70目标存在、旧源不存在；70/70raw一致；KEEP9+DEFER2原字节一致 | [MOVED_FILES_VERIFICATION.csv](MOVED_FILES_VERIFICATION.csv) |
| 静态精确范围 | PASS：固定C1/执行单SHA、精确70删除/70新增、四配套及单链接；原字节保护；拒绝错误基准和被改执行单 | [STATIC_VERIFICATION.json](STATIC_VERIFICATION.json)、[负例](STATIC_NEGATIVE_CHECKS.json) |
| MATLAB路径 | PASS：69移动函数which -all均唯一且等于预期新路径；全部287名字通过；重复初始化稳定 | [PATH_RESOLUTION_VERIFICATION.json](PATH_RESOLUTION_VERIFICATION.json) |
| 注册与句柄 | PASS：6分配器、2效能插件、14句柄；未调用控制器或ECL构造器 | 同上 |
| engine来源 | PASS：121项集合双射、69移动m全覆盖、原字节不变；独立cell序列化核对及重复计算一致 | [身份映射](ENGINE_IDENTITY_TRANSITION.md) |
| PPID显式来源 | PASS：集合不变；仅engine实现文件SHA变化，engine身份另变；旧锁不改 | [SOURCE_MANIFEST_DELTA.json](SOURCE_MANIFEST_DELTA.json) |
| ECL构建路径 | PASS_STATIC_ONLY：AST仅一项cpp路径替换，参数/依赖/输出位置不变，cpp原SHA不变；exe与历史manifest不变 | [ECL_BUILD_PATH_CHECK.json](ECL_BUILD_PATH_CHECK.json) |
| Git发布字节 | PASS：提交前候选树70blob及独立检出通过；提交树等于候选树；提交后git show及精确commit独立checkout70/70一致，包括7CRLF | [GIT_BLOB_AND_CHECKOUT_VERIFICATION.json](GIT_BLOB_AND_CHECKOUT_VERIFICATION.json) |
| 受保护文件 | PASS：73,393项文件集合与逐文件raw SHA相同，含MAT/WTR/正式数据/锁/协议/指标/exe/build_manifest | [PROTECTED_FILES_VERIFICATION.json](PROTECTED_FILES_VERIFICATION.json) |
| Markdown/Git空白 | PASS：90份Markdown、565本地链接、0断链；暂存diff --check通过 | 单处补充授权修复及Git审查 |
| 回滚准备 | PASS：独立检出普通revert得到C1树，七份raw恢复后70/70源SHA一致；DEV未回滚 | [ROLLBACK_READINESS.md](ROLLBACK_READINESS.md) |

MATLAB环境25.2.0.2998904 (R2025b)。只有路径、句柄文件和来源哈希计算；没有savepath，没有永久path修改。C1旧engine `ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab`；C2新engine `19ce8d8136471d32f807de051183d3cca272233cb2b14d3e6fa988b0dfa89e63`。差异来自路径及排序参与原序列化，是预期来源身份变化。

## 七份CRLF与遇到的问题

新增精确-text并附whitespace=cr-at-eol规则，只作用七目标；其余全局换行策略不变、UTF-8无BOM。最初git mv已把旧LF blob放进索引，普通git add复用stat缓存，候选blob核查失败且阻止提交；只对这七个精确目标执行git add --renormalize强制重新读取，使-text保存raw字节，随后全部blob/检出验证PASS。**没有执行全仓renormalize**。Git重命名相似度七份低于100%来自旧blob LF与新blob CRLF的科学字节保存，工作树迁移raw未变。见[索引诊断](INDEX_FILTER_DIAGNOSTIC.json)。

初次文档检查失败、用户补充授权与修复见[FAILED_CHECKS.json](FAILED_CHECKS.json)；保留了当时的[Git状态](CURRENT_GIT_STATUS.txt)，该状态不是最终工作区快照。提交后的PowerShell rev-parse组合命令把未引号的HEAD^{tree}误解析为脚本块；随后用结构化Python子进程精确核对commit/tree成功，没有重写或补做DEV提交。

## 复现命令与证据口径

在DEV根运行：

```powershell
python tools/check_phase3_static.py --plan E:/AeroGNC-Phase-Audit/Phase3-Architecture/C2-Gate/W1_RESOLVED_PLAN.csv --inventory E:/AeroGNC-Phase-Audit/Phase3-Architecture/C2-Execution/C1_TRACKED_RAW_SHA256.json
python tools/check_docs_links.py
matlab -batch "restoredefaultpath; addpath(pwd); addpath(fullfile(pwd,'tools')); report=check_phase3_paths(pwd); disp(report.status)"
```

还须以执行单逐个断言69函数which等于目标路径，本轮结果已保存。静态工具固定基准C1，仅用于C2验收；后续C3需单独修订执行单与检查规则，不能简单允许任意移动。原始raw SHA、Git blob内容SHA、Git OID与MATLAB聚合engine分列，不混用。

## 剩余限制与下一阶段

历史正式锁记录的ECL exe a3f01863…尚未恢复，UNRESOLVED；当前exe a68d4884…保持原字节，历史build_manifest仍记录旧身份。本轮未重建、运行ECL，也未追改元数据；不能宣称历史ECL环境恢复。

NOT RUN：2秒短例、52/55秒、任何新控制仿真、多方法/多种子、全套测试、ECL构建/运行、真实DEV回滚后的MATLAB检查。未用静态PASS替代这些运行验收。

C2已提供C3的新工程基线，但**尚不具备直接执行C3的完整条件**：必须先统一W2原CSV中allocators/plugins与顶层registry现状的矛盾，形成当前树的精确W2单，核查src/effectiveness的engine覆盖及插件路径，并另获C3授权。不得因C2通过自动迁移效能、分配器、模型或研究目录，不合并main、不更名仓库。D/E快照只提供逻辑回滚保护，不是独立容灾。
