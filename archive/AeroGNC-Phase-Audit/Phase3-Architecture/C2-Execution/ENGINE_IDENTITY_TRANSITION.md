# C1 → C2 engine 身份映射

DEV C1：b2a287ceff34445bb7902890141be7a450d19de9。DEV C2：269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1。

| 身份 | MATLAB实测SHA256 |
|---|---|
| C1旧布局 | `ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab` |
| C2新布局（重复两次一致） | `19ce8d8136471d32f807de051183d3cca272233cb2b14d3e6fa988b0dfa89e63` |
| 冻结科学基准快照，使用扩展后的引擎读取旧布局 | `ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab` |

新旧值不同是路径参与序列化的预期结果；没有改算法、控制参数或历史锁。新目录仅加入src/runtime、src/control、src/navigation、src/sensors、src/drivers、src/lib；allocators/interface六个移动接口仍由顶层allocators递归覆盖。

[ENGINE_FILES_C1.json](ENGINE_FILES_C1.json)与[ENGINE_FILES_C2.json](ENGINE_FILES_C2.json)分别列旧/新121项文件的相对路径和raw SHA。按批准执行单映射69份m后，两个集合一一对应、每项原始字节一致，没有多计或漏计。仅63份m从旧目录覆盖转入src；其余6份接口继续在allocators覆盖中。cpp由独立SHA证据保护，不属于engine输入。

改动保留getByteStreamFromArray序列化算法及allocation_comparison_hash原字节（SHA256 `cfcec6ff7176d0b8e0d2c2b69b3cd517668ce7fc37724823c95f8f8e663fbceb`）。在MATLAB中独立构造同一121×2 cell并调用未变helper，结果精确等于新engine。两张MAT的canonical分支未改变，原始MAT均在受保护集合逐项验证。重复路径仅计一次；存在同名源码时显式报ca:EngineDuplicateSource，禁止新旧副本静默择一。

[ SOURCE_MANIFEST_DELTA.json ](SOURCE_MANIFEST_DELTA.json)另列PPID来源变化：文件集合不变，唯一显式文件SHA变化是analysis/allocation_comparison_engine.m；ca_setup、研究控制器和ECL二进制SHA均不变。旧ec不得写回任何历史锁。

历史d4c19f32…、c6403c02…、ec1491ec…的来源复现见[已验收Gate分析](../C2-Gate/ENGINE_PROVENANCE_ANALYSIS.md)。其历史锁保持原字节；本轮不重复历史飞行，不宣称同一engine能替代完整研究来源或ECL环境恢复。

独立检出70项移动文件的raw SHA全部一致。原项目未移动文件仍保留既有Git换行策略，本轮没有全仓重新规范化；历史工作树engine复现应使用这里的完整raw清单和旧快照，不能用归一化后的普通检出字节冒充原实验来源。本轮未额外声称跨MATLAB版本序列化或任意完整检出engine均相同。
