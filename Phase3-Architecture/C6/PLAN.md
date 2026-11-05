# C6/W5 Gate 计划

日期：2026-11-05。分支：`refactor/c6-toolchain`，从 C5 `a572f37` 创建。

## Gate 结果

**PASS_WITH_DEFERRED**。W5 223 项：KEEP 215、PATCH 1、DEFER 7、MOVE 0。原计划 223 项目标路径与原路径相同，未为了差异而移动。

## 决策

- KEEP：大部分 tests/analysis/tools/apps 的路径与职责合理。
- PATCH：`tools/repo_inventory.py` 的 `active_dirs` 仍解析旧 `ca_setup` `paths={`；改为当前 `layouts = {`，不改变输出契约。
- DEFER：历史批处理/旧固定路径基线工具（`verify_platform_sources`、C4 static、旧 package/平台阶段脚本、旧 inventory 门禁、`check_platform_docs`）不作为 C6 活动门禁；不运行、不改写历史基线。
- 文档修复：AGENTS 的 main 分支表述、repository_map 的 C5 后布局、AUDIT 顶层入口指针。

## 验收

Python 工具语法/入口、C5/C6 静态、文档链接、MATLAB 路径/注册、Apps `which`、PPID 配置与 manifest、2 秒平台 smoke、WindTrace 既有 WTR 只读解析。不运行 55 秒正式批、五方法批、ECL 重建或会写 Results 的全套测试。
