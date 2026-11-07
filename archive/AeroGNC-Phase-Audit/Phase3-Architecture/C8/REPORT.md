# C8/W7 源码来源身份与兼容性报告

日期：2026-11-07（Asia/Shanghai）。执行者：DeepSeek Harness / deepseek-flash；dual-repo-agent-handoff 0.2.2。

状态：**PASS_WITH_DEFERRED**。当前来源覆盖和历史锁映射完成；历史 ECL 二进制仍 **UNRESOLVED**；C9/W8 未执行；55 秒 HDT、五方法批、ECL 重建 NOT RUN。

## 1. C1–C8 engine 转换

完整逐行表见 [C8_ENGINE_TRANSITIONS.csv](C8_ENGINE_TRANSITIONS.csv)。摘要：

| 阶段 | DEV 提交 | Engine | 文件变化 | 字节/内容 | 原因 | 证据 |
|---|---|---|---|---|---|---|
| C1 | `b2a287c` | `ec1491ec` | 121 engine 文件 | 基线 | 旧布局 | C2-Gate |
| C2 | `269564d` | `19ce8d81` | 69 m + 1 cpp | 70/70 raw equal | 路径参与序列化 | C2-Execution |
| C3 | `9d8f8ae` | `481bd57c` | 5 | 5/5 raw equal | 5 个效能路径 | C3-Execution |
| C4 | `661eecc` | `fb7cf780` | 8 | 7 raw equal；1 路径补丁 | 模型/动力学迁移 | C4-Execution |
| C5 | `a572f37` | `696da7e6` | 75 迁移/8 KEEP | 58 CRLF-normalized；17 补丁 | W4 研究迁移 | C5/REPORT |
| C6 | `400f6b2` | `696da7e6` | 0 engine 文件 | 0 | 工具/文档整理 | C6/REPORT |
| C7 | `9173261` | `b922c32b` | 1 compat 迁移 | 1/1 raw equal | 旧 `compat` 退出 engine | C7/REPORT |
| C8 | `d422cb3` | `61fb8ceb` | 0 移动 | 0 | 将 `src/compat` 纳入 engine，清理旧声明 | [C8_MATLAB_RESULTS.json](C8_MATLAB_RESULTS.json) |

C2 的路径差异、C3/C4 的路径补丁和 C5 的 17 项补丁均没有改变控制/估计数值算法；C7/C8 是 engine 覆盖变化，不修改兼容函数内容（raw SHA `d96e70b2…`）。

## 2. 历史正式锁与当前源码

`research/ppid_pindi/formal_lock.json` 保持原字节：engine `ad9f9104…`、49 项、ECL `e9bee1e5…`。逐项映射见 [C8_LOCK_MAPPING.csv](C8_LOCK_MAPPING.csv)：

| 分类 | 数量 |
|---|---:|
| EXACT | 4 |
| PATH_ONLY_EQUIVALENT | 36 |
| CONTENT_CHANGED | 9 |
| MISSING | 0 |
| UNRESOLVED（文件项） | 0 |

9 个原始字节改变项的细分：

- **仅换行**（3）：`ppid_config`、`ppid_estimator_init`、`configs/f8_pressure_protocol_v2.json`；规范化后与 C4 内容一致，不是数值算法改动。
- **路径/来源登记**（6）：`ppid_simulate`（C5 simulation_source 路径）、`ppid_source_manifest`（C5/C8 登记）、`run_figure8_lite_comparison`（C5 路径）、`ca_setup`（C4/C5/C7/C8 路径管理）、`run_ppid_pindi`（C5 路径）、`analysis/allocation_comparison_engine`（C4/C5/C7/C8 目录覆盖）。
- 没有发现控制律、估计器、传感器、分配器、协议数值或 ECL 内容的改变。

历史实验身份继续按 C2-Gate 保留：

| 历史实验 | Engine | 结论 |
|---|---|---|
| 原正式批 | `d4c19f32…` | 原始执行版本，显式 70/70 来源可恢复；不是当前 engine |
| change-B 正式批 | `c6403c02…` | 原始执行版本，显式 70/70 来源可恢复；不是当前 engine |
| C1 工程基线 | `ec1491ec…` | 早于 C2 的工程身份；不是当前 engine |
| C8 当前源码 | `61fb8ceb…` | 当前覆盖修复后的身份；不得写回旧锁 |

历史 formal_lock 的 engine 和 49 项文件按原字节保留；当前 C8 engine 与历史 lock 不相等是事实，不是待修改错误。

## 3. ECL 身份

| 对象 | SHA256 | 状态 |
|---|---|---|
| 当前 `build/px4_ecl/px4_ecl_bridge.exe` | `a68d4884…` | 现存 |
| `build_manifest.executable_sha256` | `a3f01863…` | 与当前 EXE 不一致 |
| 历史 formal_lock ECL | `e9bee1e5…` | 二进制不存在，UNRESOLVED |
| C2 历史候选 | `a3f01863…` | 不存在，UNRESOLVED |

未重建、未替换、未修改 `build_manifest.json` 或任何锁。当前 EXE 的 a68d 是现存对象，不是历史锁 e9bee/a3f 的替代品。

## 4. 当前覆盖修复

- **Engine**：`analysis/allocation_comparison_engine.m` 将 `compat` 改为 `src/compat`；`ca_complete_allocation` 参与 `ca_allocate` 的预测舵角、公共残差和优先级诊断字段，属于当前数值结果的来源，不能漏计。
- **PPID manifest**：53 文件，两次生成一致、无重复；新增 `src/compat/ca_complete_allocation.m`、`shc09_gnss_config.m`、`studies/ppid_pindi/gnss_v2/ppid_gnss_v2_config.m`、`research/ppid_pindi/gnss_v2/protocol.json`。完整清单见 [C8_SOURCE_MANIFEST.json](C8_SOURCE_MANIFEST.json)。
- **GNSS v2**：协议读取改为 `root/research/ppid_pindi/gnss_v2/protocol.json`。`shc09_gnss_config(9301,"f8")` 与 `(501,"takeoff55")` 均通过，`tau=1000 s`、5 Hz、延迟 0.1 s，父协议 SHA 断言保持。
- **来源继承**：`hd_sources`、`hdt_sources`、`hdtf_sources` 分别 11/11/10 文件；父 manifest 变更可传递。
- **C7 文档引用**：`NAVIGATION_DIAGNOSIS_SUMMARY` 与 GNSS report 指向 `studies/ppid_pindi/README.md`；hover/PPID 完整报告指向 `eb40ef8` 的 `codex-repo-17/16.md` Git permalink。原报告不恢复到根目录。

## 5. 验证

| 检查 | 结果 |
|---|---|
| `ca_setup` / `check_phase3_paths` | PASS：287 名字、6 分配器、2 效能、14 句柄 |
| `allocation_comparison_engine` | 两次一致：`61fb8ceb…` |
| `ppid_source_manifest` | 两次一致：53 文件、无重复 |
| `ca_complete_allocation` | 唯一解析到 `src/compat` |
| GNSS f8/takeoff55 | PASS：41601/44001 点，tau=1000 s、5 Hz、0.1 s |
| `hd/hdt/hdtf_sources` | 11/11/10 文件 |
| MATLAB 针对性测试 | `test_bus`、`test_plugin_conformance`、`test_topic_chain` 全部 PASS |
| C5/C6 静态 | PASS |
| 文档链接 | `check_docs_links` 0；`check_platform_docs` 0 |
| 历史锁/原始数据 | 未修改；`git diff` 无锁/MAT/WTR |

未运行完整 MATLAB 测试套件、55 秒 HDT、五方法批、ECL 重建。

## 6. Git 与结论

- DEV 分支：`refactor/phase3-source`；C8 源码提交 `a6976a0…`；最终 DEV HEAD `d422cb34e495fbe786395d9586694fe4ef6f88df`，已推送。
- main：`1c851a5…`，未改；远端仍为两个分支。
- 未创建备份/整仓副本；未修改历史实验来源或 Results。
- **PASS_WITH_DEFERRED**：当前来源覆盖、历史锁映射、GNSS 路径和文档验证完成；历史 ECL `a3f/e9bee` 的不可得状态已准确登记为 UNRESOLVED，不能据此宣称完整历史 ECL 环境恢复。

C9/W8 可开始只读收尾 Gate：首页、交接、兼容余量和剩余来源边界；不自动执行 C9。
