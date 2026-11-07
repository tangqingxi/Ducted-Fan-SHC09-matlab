# C8/W7 来源身份与兼容性收敛计划

日期：2026-11-07。执行分支：`refactor/phase3-source`（不新建阶段分支）。

## 目标

1. 解释 C1–C7 每次 engine 变化：路径序列化、文件迁移、内容补丁或覆盖遗漏。
2. 将历史 `formal_lock.json` 的 49 项来源逐项映射到当前源码，分类 `EXACT/PATH_ONLY_EQUIVALENT/CONTENT_CHANGED/MISSING/UNRESOLVED`。
3. 修复当前 engine 与 `ppid_source_manifest` 的覆盖遗漏：
   - `src/compat/ca_complete_allocation.m` 纳入 engine；
   - 移除旧空 `compat` 声明；
   - 登记 `src/compat`、`shc09_gnss_config.m`、GNSS v2 config/protocol。
4. 修复 GNSS v2 协议路径：配置在 `studies/ppid_pindi/gnss_v2/`，协议在 `research/ppid_pindi/gnss_v2/protocol.json`。
5. 修正 C7 遗留的 4 处 validation 文档引用。
6. 验证 engine 两次一致、manifest 两次一致、GNSS 配置构造、来源继承和文档链接。

## 保护边界

- 不修改历史 `formal_lock.json`/`source_lock.json`/`protocol.json`/MAT/WTR/结果。
- 不改控制、估计、物理模型或 GNSS 数值参数。
- 不重建 ECL；历史 `a3f…`/`e9bee…` 二进制不可得时标 `UNRESOLVED`。
- 不运行 55 秒 HDT、五方法正式批、多种子/参数扫描或 Results Manager。

## 验收

- C1–C8 engine 转换表可追溯，路径与内容变化分开。
- 历史锁 49 项有分类；无 MISSING/UNRESOLVED 的文件项（ECL 单独 UNRESOLVED）。
- 当前 engine 两次稳定，覆盖 `src/compat`；PPID manifest 53 文件、无重复。
- `shc09_gnss_config` 的 f8/takeoff55 配置构造通过，tau=1000 s、5 Hz、延迟 0.1 s。
- C5/C6 静态、当前文档链接、MATLAB 针对性测试通过。
- 不修改历史锁/原始数据；DEV/AUDIT 可独立恢复。
