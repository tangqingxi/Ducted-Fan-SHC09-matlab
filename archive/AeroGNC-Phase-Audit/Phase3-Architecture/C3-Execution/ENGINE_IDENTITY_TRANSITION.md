# C2 → C3 engine 身份映射

DEV C2：`269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1`。DEV C3：`9d8f8aec7d3b8316f5ae99cba45f422e74cc984c`。

| 身份 | MATLAB 实测 SHA256 |
|---|---|
| C2 布局 | `19ce8d8136471d32f807de051183d3cca272233cb2b14d3e6fa988b0dfa89e63` |
| C3 布局 | `481bd57cc57a7abe0180094d0846dfe5fe20c0548b269814023eb7af65837d05` |

C2 与 C3 engine 均为 121 项。C3 只把五份效能源码的路径按 W2 执行单替换，五份 raw SHA 不变；其余 116 项路径与 raw SHA 不变，没有多计或漏计。C2 清单见 [ENGINE_FILES_C2.json](../C2-Execution/ENGINE_FILES_C2.json)，C3 清单见 [ENGINE_FILES_C3.json](ENGINE_FILES_C3.json)。

engine 实现文件 `analysis/allocation_comparison_engine.m` 的 raw SHA 由 `e53fff0da2f16e2e86edb09051c4b8ad947f3136a5c8f7d9c3b716d429d43cd3` 变为 `9463ed3ac3ebc7924fdeb4ab6e196774f5d4a4709cc70eb4be3d28894d9fe8c5`；变化仅为在 folders 中新增 `"src/effectiveness"`，反向删除该字符串后与 C2 原字节一致。`allocation_comparison_hash.m`、序列化算法和同名拒绝逻辑未改。

PPID 显式来源的文件集合不变（49 项）；唯一显式文件 SHA 变化是上述 engine 实现文件，见 [SOURCE_MANIFEST_DELTA.json](SOURCE_MANIFEST_DELTA.json)。`ca_setup.m`、`allocators/registry.m`、研究控制器、协议、锁和 ECL 二进制均未改；`px4_ecl_bridge.exe` 仍为 `a68d48847f154809f546cea66cc6a4235921d4d3d79fe25081d28508b5f12ba3`。历史 ECL 二进制 `a3f…` 恢复仍为 UNRESOLVED。

新旧聚合 engine 不同是路径参与序列化的预期结果；不能把 C3 engine 或 C3 源码身份回写到任何历史正式批或历史锁。
