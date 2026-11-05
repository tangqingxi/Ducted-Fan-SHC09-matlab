# C3 文档链接影响及精确修复单

本轮只读解析全部152份Git跟踪Markdown（含当前文档和历史证据），按文件相对位置解析本地Markdown链接。只发现一处直接指向五份MOVE源码的链接；另发现同一README的C2既有目录链接依赖本机残留空目录。完整扫描结果见[FILE_AND_LINK_ANALYSIS.json](FILE_AND_LINK_ANALYSIS.json)。

## 下一轮最小文档修改白名单

| 文件 | 行 | 原链接目标 | 获批后新链接目标 | 原因 |
|---|---:|---|---|---|
| effectiveness/README.md | 5 | effectiveness_registry.m | ../src/effectiveness/effectiveness_registry.m | 注册表迁移后旧目标不再存在 |
| effectiveness/README.md | 16 | ../drivers/actuators | ../src/drivers/actuators | C2已迁移驱动，旧目录仅本机残留，Git树无对应文件 |

原文档raw SHA256：`d20238198253c0105a95618912aea364c11d3a1775ce4f4ace4b52293b513c5f`。在内存中仅替换两处Markdown链接目标的候选raw SHA256：`68c75d2615616070d7a130f7d2f9f1da5500aaf054228780c3000f303970bf33`。下一轮必须逐字节匹配该候选，或反向替换后匹配原SHA；不修改正文语义、参数、协议、其余链接或代码示例。本轮没有写回文档。

README在W2执行单标为DEFER：**文件不迁移**，target_path记录原位。下一轮只有显式批准上述两处链接修复后，才允许其内容SHA改变；不能把DEFER理解为允许覆盖目标README。

## 保留与冲突处置

src/effectiveness/README.md是C1占位文件，raw SHA256 `5d3f0a558cc381a0b55a5d69828eb56e2949bea1d17989e158efbe2158453361`。它保持原位与原字节，禁止以effectiveness/README整体替换、复制覆盖或本轮顺带合并。其C1占位文字属于先前阶段说明；C3实施状态以执行报告及保留的详细效能说明为准，后续W6再单独授权整理文案。

旧README的../models/shc09链接仍指向当前有效模型路径，无需修改。docs/guides/platform_plugin_guide.md指向effectiveness/README.md，该文档保留原位，因此无需跟随迁移。其他当前Markdown、历史协议与冻结证据没有新的直接源码链接修复项，不批量替换内联代码路径或历史来源记录。固定历史提交URL不因当前源码移动而失效。

现有tools/check_docs_links.py只扫描指定首页及docs/examples，共90份，并不包含effectiveness/README。当前运行结果为0断链不能代替本次全152份跟踪Markdown的针对性审查。下一轮不必扩大工具修改范围，可在临时验证脚本中额外解析该README并按候选Git树核验目标，避免本机残留空目录造成假PASS。
