# F8阶段Git提交前审查报告

日期：2026-11-01（Asia/Shanghai）

仓库：`E:\Ducted-Fan-SHC09-matlab`

本文保存本轮提交前审查回复。下文Git状态、文件数量及建议清单均为本报告新增之前的审查快照。本报告由用户随后明确要求新增；落盘后工作区额外增加未跟踪文件`codex-repo-3.md`，未暂存或提交。

## 1. 审查结论

提交前审查完成。**发现两项需要先处理的问题，暂不建议直接提交。** 审查期间仅做只读检查，未修改、暂存或提交任何文件。

## 2. 两项提交前问题

### 2.1 交付包的字节哈希与Git换行规则冲突

[.gitattributes](.gitattributes)启用了文本规范化，JSON、Python、Markdown还明确使用LF。实测Git入库过滤会改变交付包中**78个文件**的字节，其中**77个属于manifest校验范围**。

因此，当前目录验收通过，不代表提交后重新检出仍能通过。特别是显式`eol=lf`的文件，在本机重新检出也会变化。

建议经批准后增加仅针对本交付包的规则：

```gitattributes
/examples/f8_comparison_20261101/** -text
```

这与仓库已有的冻结来源保留原字节做法一致，不涉及原始实验。

### 2.2 归档补丁存在格式所需的空白行

当前`git diff --check`返回**0**，但它不包含未跟踪文件。对新增文本逐个执行等效检查后，只有以下文件出现告警：

```text
examples/f8_comparison_20261101/reproducibility/plotting_changes.patch
```

具体为12处空白上下文行，以及文件末尾空行。这些来自统一差异格式，不是Python源码错误；直接纳入Git后会触发空白检查。

建议保留补丁原字节，并增加精确例外：

```gitattributes
/examples/f8_comparison_20261101/reproducibility/plotting_changes.patch -whitespace
```

**上述规则尚未写入文件。**

## 3. 其他审查结果

| 检查 | 结果 |
|---|---|
| 三份文档最终差异 | 主要事实纠偏、结论边界和交付入口一致 |
| 三个Python工具 | 语法解析通过；交付内源码副本与当前工具字节一致 |
| 交付文件 | 172个，30,154,354字节 |
| manifest | 171条产物记录，无重复、缺失或额外文件 |
| 文件哈希 | 全部匹配 |
| 汇总与配对 | 70行汇总、294行配对复算通过 |
| 图像 | 30组PNG/PDF检查通过 |
| 原始结果 | 280个文件匹配此前来源快照 |
| 冻结源码 | 20文件锁匹配；207项数值来源快照匹配 |
| 文档链接 | 64份Markdown、443个本地链接，0断链 |
| 文件名冲突 | 未发现大小写或Unicode规范化冲突 |
| 路径 | 未发现越界、符号链接或文件/目录冲突；新增路径最长绝对长度126字符 |

待提交范围内没有原始`.mat`、完整`tracks/geometry`、`results`临时构建目录、Python缓存、日志或临时文件。

交付内的`finish_f8_confirmation_rerun.m.txt`是明确归档的驱动文本；`priority_trace.csv`是优先级轻量证据，均不是误混入的原始仿真日志。

## 4. 准确的Git状态

审查时当前为`f8-research`：

```text
HEAD  7c5c9ab91fdb310c33d5bf08209e0302e540008f
main  9918d9dba180f38a62c36f602e37993b87d0d38d
```

审查时`git status --short`：

```text
 M AGENTS.md
 M HANDOFF.md
 M README.md
 M tools/plot_f8_comparison.py
?? codex-repo-1.md
?? codex-repo-2.md
?? examples/f8_comparison_20261101/
?? tools/f8_delivery_audit.py
?? tools/package_f8_results.py
?? tools/requirements-f8-delivery.txt
```

暂存区为空。展开目录后，审查时共**181个候选文件：4个已跟踪修改、177个未跟踪文件**。

实际`git diff --stat`为：

```text
 AGENTS.md                   | 172 ++++++-----
 HANDOFF.md                  | 675 ++++++++++++++++++++++++++++++++++++++------
 README.md                   |   6 +-
 tools/plot_f8_comparison.py |  79 ++++--
 4 files changed, 732 insertions(+), 200 deletions(-)
```

此统计不包含未跟踪文件。HANDOFF的大幅差异也包含接手时已经存在的未提交交接内容。

## 5. 分组提交建议与实际清单

建议解决上述两项属性问题后，按以下顺序分三组提交。以下清单为原审查回复中的建议，尚未执行。

### 第一组：后处理工具与交付文件属性

```text
.gitattributes                         # 待批准修正，目前尚未修改
tools/plot_f8_comparison.py
tools/package_f8_results.py
tools/f8_delivery_audit.py
tools/requirements-f8-delivery.txt
```

建议提交说明：`tools: finalize F8 plotting, packaging and delivery audits`

### 第二组：正式轻量交付包，共172个文件

准确逐文件集合是：

- [artifact_manifest.json](examples/f8_comparison_20261101/artifact_manifest.json)自身；
- 该文件`artifacts`中逐项列出的**171个实际路径**，本轮已全部核对。

目录分布如下，不包含任何目录外文件：

| 相对交付包根目录 | 文件数 |
|---|---:|
| README.md、artifact_manifest.json | 2 |
| F8PR-Y60-F075/ | 44 |
| F8-R/ | 34 |
| F8-D/ | 35 |
| development_screen/ | 28 |
| partial_batch/ | 5 |
| audit/ | 13 |
| reproducibility/ | 11 |
| **合计** | **172** |

建议提交说明：`results: deliver frozen F8 comparison figures and evidence`

### 第三组：交接文档和审查报告

```text
AGENTS.md
HANDOFF.md
README.md
codex-repo-1.md
codex-repo-2.md
```

建议提交说明：`docs: correct F8 conclusions and finalize handoff`

`codex-repo-1.md`保留历史，关于λ的范围错误由`codex-repo-2.md`明确更正，两份报告建议一起保留。

若批准新增上述`.gitattributes`修正，原审查计划提交范围将由181个文件变为**182个文件**。审查结束时没有修改文件，没有执行merge、暂存、提交或push；`main`、`f8-research`和冻结实验保持原状。现停止，等待批准。

## 6. 本报告落盘后的数量说明

本报告是审查结束后按用户要求单独新增的文件，不属于上文审查时的181个文件快照。将本报告一并纳入第三组后，当前候选文件总数为182个；若随后批准修改`.gitattributes`，计划提交总数为183个。交付包本身仍为172个文件，manifest不变。

没有因保存本报告而修复属性规则、重新构建交付包或改变任何既有文件。
