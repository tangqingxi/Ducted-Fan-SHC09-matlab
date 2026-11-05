# C2-Gate 历史 engine 来源分析

日期：2026-11-05（Asia/Shanghai）。状态：**RESOLVED（本轮可复核的来源范围）**。仅解释来源身份，不重跑飞行，不改变历史失败结论。

## 结论与实际执行版本

| 来源 | 启动记录中的 Git HEAD | 实际执行源码身份 | 复算与锁 |
|---|---|---|---|
| 原正式批 | `c381275775b2fe0191eddd663798157864e56780`，hover_distance | HEAD加当时未提交研究源码；显式70项逐SHA可恢复；engine覆盖120个m及2个MAT | 完全相等：d4c19f32… |
| change-B正式批 | `1737eee1a309e0fb1bfcf294293b38cc128b1b47`，change-B | HEAD加当时未提交研究配置/驱动；显式70项逐SHA可恢复；engine覆盖121个m及2个MAT | 完全相等：c6403c02… |
| 当前C1／科学基准快照 | `b2a287ceff34445bb7902890141be7a450d19de9`／`339d7b1a997de6ba350cef3207d8a5b7db3d838d`快照 | engine集合121个m；ca_setup不在engine内；PPID显式来源另包含ca_setup | 当前重复两次、快照一致：ec1491ec… |

启动记录路径分别为 DEV results/hover_distance_takeoff_formal_work_20261103_r1/git_start.json 与 results/hover_distance_takeoff_formal_work_changeB_20261104_r1/git_start.json。不能把启动HEAD等同于完整执行树：源文件在运行前已修改或新增，随后才提交。
原批交付提交 `cef7c0e106f738bac8e132a410e486931700f88a`，change-B交付提交 `f788076ea05d85c62cbeecdf8ba5bef165c3c84d`。原批当前驱动已做事后管理修复，真实执行版保存在 docs/validation/hover_distance_takeoff_formal_20261103_r1/hdtf_run.frozen.m，raw SHA256=`4182f981f8bd898ff7e2eaa8656a4bbef329e5348eeb91cc76e79d4302f0ddab`。post_batch_management_fix.json与patch说明修复发生在16次运行之后，不追认为执行版。

## 完整哈希计算方法

1. 按固定目录 platform、allocators、effectiveness、models、drivers、lib、configs、modules、compat，各递归读取所有 `.m`；额外加入 experiments/ca_mismatch_protocol.m，再按MATLAB字符串排序。
2. 构造 N×2 cell：第一列是 `erase(完整路径,string(root)+filesep)`，第二列为 `fread(fid,Inf,'*uint8')` 得到的原始字节列向量。
3. `allocation_comparison_hash(parts)`先调用MATLAB `getByteStreamFromArray(parts)`，再计算SHA256。不是文本拼接或各文件SHA的简单拼接；cell尺寸、顺序、字符串类型、数组类型/形状与序列化口径均参与。
4. 对 models/shc09/reference/duct_raw.mat 与 wing_raw.mat 分别计算原始字节SHA256；等于源码内canonical两个值时直接使用第3步值，否则对 `{parts,observed}`再序列化求SHA256。
5. 本轮两MAT均等于canonical（完整值见下方观测JSON）；未触发附加分支。engine不包括ca_setup、analysis实现本身、research或`.cpp`；PPID显式清单与ECL二进制SHA补充这些来源边界，不能用engine代替全项目来源锁。

源码方法在三个历史时期相同；本轮未改实现。当前raw SHA256：
- [analysis/allocation_comparison_engine.m](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/b2a287ceff34445bb7902890141be7a450d19de9/analysis/allocation_comparison_engine.m)：`c9d131e97dd1f9268b17099c73c148fcd53709b6a8fe9c04f7b69be556e5ecb6`。
- [analysis/allocation_comparison_hash.m](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/b2a287ceff34445bb7902890141be7a450d19de9/analysis/allocation_comparison_hash.m)：`cfcec6ff7176d0b8e0d2c2b69b3cd517668ce7fc37724823c95f8f8e663fbceb`。

## 按原字节复现与差异解释

原正式批用 DEV docs/validation/hover_distance_takeoff_formal_20261103_r1/protected_before.json 的files映射核验完整覆盖集合。由原启动/交付提交取Git blob，逐文件选择原blob或LF→CRLF候选，**仅当候选SHA精确等于历史保护清单时才接受**；120份m和2份MAT全部匹配。放入临时历史目录，原engine函数计算得到完整d4c锁值。相同内容分别位于启动和交付临时目录，规范化根路径下结果相同，验证了根目录可搬移。

change-B由1737eee…／f788076…取同一覆盖集合；其中122项（含两MAT）与当前保留字节在换行规范化后语义相同，使用当前保留原字节；唯一旧版 shc09_navigation_sensors.m 使用历史Git原字节。临时目录整体复算与原c640锁**完全相等**。这里的换行规范化只用于选择候选，最终哈希读取的是未规范化的实际候选字节；聚合锁相等核验了该组合。未把“语义相同”单独当成原字节通过依据。

原批→change-B：机体模型、坐标接口、导航初始化/仿真等7个原有文件改变，并新增 models/shc09/ca_reference_to_b.m；这些内容变化属于既有b-frame研究历史。current与原批相比另有后续诊断文件变化，详见下方差异表。

change-B→当前ec：**engine覆盖集合相同，仅 platform/sim/shc09_navigation_sensors.m 一份文件改变**。提交 `2367a23c9dfbc11c3e1d4d43a44bc7e87aabd88b` 把observation返回结构增加gps_velocity字段。把change-B临时来源中的这一份文件替换为当前原字节后，engine精确变为ec1491ec…；这是实测因果检查，不是仅凭提交说明推断。

DEV docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/source_lock.json 的 base_sources.engine 已记录同一ec值，说明该值早于C1，GNSS回归曾采用该身份；这不意味着1000s参数本身造成engine差异。C1只改ca_setup，导致PPID显式文件SHA变化，未造成engine改变。

## 路径、换行和序列化实验

Windows规范化根使用ca_setup返回的反斜线路径。root若传正斜线，而fullfile/dir产生反斜线完整路径，`erase(root+filesep)`不能移除前缀，绝对路径残留进摘要：当前得到d21865ae…，快照得到10cdee70…。规范化后两者均ec1491ec…，故该误用的两值不是新科学来源，应标为根路径表示造成的不同哈希输入。

历史Git blob通常是LF，工作树含保留CRLF；统一用Git blob或把全部文件转CRLF均不能复现旧锁。此处严格区分Git对象OID、Git blob内容SHA256、本机raw SHA256及MATLAB聚合engine。不能为让结果相同而改旧锁、旧数据或统一历史字节。

本轮所有复算均为MATLAB R2025b 25.2.0.2998904，没有用Python冒充engine。Python仅取Git字节、筛选SHA候选和生成表。验证范围限于此MATLAB/Windows环境；未承诺跨MATLAB版本getByteStream序列化兼容，也未做轨迹逐帧复算。

## 可复核观测

以下是本轮MATLAB保存JSON中的完整观测字段。`matched_bytes`是临时历史重建，不是对DEV的移动或修订；临时文件不提交AUDIT。

```json
{
  "matlab": "25.2.0.2998904 (R2025b)",
  "engines": {
    "current": "ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab",
    "current_repeat": "ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab",
    "snapshot": "ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab",
    "original_start_git_bytes": "86a39d2241d3d7b6c5d6814b7149e1ceb1f812aab530889f73efd09336ba8ec9",
    "original_start_crlf": "949d063b3d628833625769186a4e82b3037b3bfdcc0239a31f0d150421f8940f",
    "original_start_matched_bytes": "d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750",
    "original_delivery_git_bytes": "86a39d2241d3d7b6c5d6814b7149e1ceb1f812aab530889f73efd09336ba8ec9",
    "original_delivery_crlf": "949d063b3d628833625769186a4e82b3037b3bfdcc0239a31f0d150421f8940f",
    "original_delivery_matched_bytes": "d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750",
    "changeB_start_git_bytes": "7f0b349708c003e72c853c7facefa3eea32eef94c91fc48e4c5c69e7fa2705ff",
    "changeB_start_crlf": "5735fb6ead290196e20c7b29cf44a9fc781bea752e5f2d9726c677ac55bd4f73",
    "changeB_start_matched_bytes": "c6403c02379bb719f5775d681b8849c6a5b5f9bb99c44e1b02b71130ce7b9d07",
    "changeB_delivery_git_bytes": "7f0b349708c003e72c853c7facefa3eea32eef94c91fc48e4c5c69e7fa2705ff",
    "changeB_delivery_crlf": "5735fb6ead290196e20c7b29cf44a9fc781bea752e5f2d9726c677ac55bd4f73",
    "changeB_delivery_matched_bytes": "c6403c02379bb719f5775d681b8849c6a5b5f9bb99c44e1b02b71130ce7b9d07",
    "current_forward_root": "d21865aedab477e15a459bbaf8c51b62e7c22f1dde60648922aa3f0a005e5fa2",
    "snapshot_forward_root": "10cdee7028fb19c94be35d05f07e0109888296b792710528ac051a75a6881e09",
    "changeB_plus_one_observation_file": "ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab"
  },
  "binary_sha256": "a68d48847f154809f546cea66cc6a4235921d4d3d79fe25081d28508b5f12ba3",
  "table_sha256": [
    "a5140eea72b98021433af2b1cb3b94b3660700eb84834751c102f07cf1831d2a",
    "299bbd2b6b6e0a60bc463bce89ddd240bb933c498d0bab2b331a8f54e98d15b2"
  ]
}
```

## 当前与历史engine集合的逐项差异

### original_start

历史m数量：120；新增路径：models/shc09/ca_reference_to_b.m。

| 路径 | 历史raw SHA256 | 当前raw SHA256 |
|---|---|---|
| `platform/sim/ca_navigation_init.m` | `1612627ac11a0de83aac398194af90e5140ce3933aa25f30b7d949ade72a36e1` | `be699e844a4ff09b46de9dbd1c75c863824e967da20226826a8e08f6f13677fb` |
| `platform/sim/ca_simulate.m` | `a9d25f02819b8ef0fb78dfd500ee56dfeee7e49e98a1b9ffc7da50fa0f4fdb5e` | `f67024a8d317aa3ffa314e318f2495356a6784b51eac256027251192810183c6` |
| `platform/sim/shc09_navigation_sensors.m` | `99d9f2d28feb4c5af186646e1e7ba211001e7fcdc289e3157b53482851df71e4` | `d47b57b45306d46be9de8abce847d0f9c9f13e8da5bce36ea735cb0aa445ae88` |
| `models/shc09/ca_model.m` | `84df08e029c94aa5a73310bd963ae2f721dbef5370f3cbffea2d71f2f2176c41` | `d843ce6c92983e020422bd43f404a70bb130e7ee70f9d4d1bcdfb0615826ee1b` |
| `models/shc09/ca_model_hover.m` | `ab4017ec9527496251ea5ca3fec879cf2f05d511a53a4dfd79928d334217fd50` | `40aaf4aa5e6a5ddd9391fca57c4497a82f0631cfe46366786c8a4213678c6f04` |
| `models/shc09/ca_plant_init.m` | `b38888cfd05dc8ab71d1913552d2dae56ba4e881f205d00bf678addc30708187` | `a891883087f2f98941836cc30ea0f4b0348a4e5aed08e725b592986a91bcd752` |
| `models/shc09/ca_plant_outputs.m` | `a9ff21ef6cdd7bbf898f8e73769663e518539d0f02db99dbc34fbbc3deee45e7` | `ae3de35175d263cae9ec60503dcbf30f0e0aaf68065bff5a3cf724eabd66f328` |
| `models/shc09/ca_shc09_parameters.m` | `2d00ee331b0492918ef92a49dff4c8e0849d1dcd69ed47a5263f5fc9e7d29ec7` | `9a12a7acbc100a345a4e8b5e80177ce2c737a1758250218713dd8920ef6af610` |
### changeB_start

历史m数量：121；新增路径：无。

| 路径 | 历史raw SHA256 | 当前raw SHA256 |
|---|---|---|
| `platform/sim/shc09_navigation_sensors.m` | `99d9f2d28feb4c5af186646e1e7ba211001e7fcdc289e3157b53482851df71e4` | `d47b57b45306d46be9de8abce847d0f9c9f13e8da5bce36ea735cb0aa445ae88` |

## 显式研究来源核对（两批各70/70）

逐层展开source_lock中的path/sha256，以路径和raw SHA校验当前保留文件、启动/交付Git blob的原字节及LF→CRLF候选、原批冻结driver；没有符合SHA的条目必须UNRESOLVED。本轮两组显式path/sha256项各70/70找到精确匹配，这两组文件列表内没有UNRESOLVED条目；列表之外的exe单独判定。engine覆盖与显式70是两个不同集合，不能混用计数。ECL二进制另以raw SHA核对：两锁均记录a3f01863525b1cb8f6c54cc2b5ea46e1b1bc0858685febdd74b13986b78a26b2，当前及科学基准快照均为a68d48847f154809f546cea66cc6a4235921d4d3d79fe25081d28508b5f12ba3。当前build/px4_ecl/build_manifest.json仍记a3f旧值，属于现存元数据与文件身份不一致。已搜索DEV build/results/archive、备份及恢复区按px4桥接文件名匹配的exe，未找到a3f对应旧二进制；其恢复状态明确为UNRESOLVED。二进制不参与公共engine，所以这不推翻d4/c640/ec的复现；也不能据engine相等宣称历史ECL执行环境已完全恢复。本轮不重建、不修改manifest或锁；C2只保护当前a68d原字节。

下表为不在启动提交中的覆盖项；其余项可由启动提交原字节或严格匹配的CRLF候选取得。显式70项的权威完整列表保留在原source_lock，本报告不改写任何旧锁。

| 批次 | 路径 | raw SHA256 | 可恢复来源 |
|---|---|---|---|
| original | `research/ppid_pindi/ppid_simulate.m` | `bcced6b660466465e28ed62d6d1529b56dffddde0a43777e86e2018891468fb3` | cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `research/hover_distance_takeoff_formal_20261103/hdtf_config.m` | `463cf2a5657db93db22bd2420084cb85de476e494198e69c38dcb22e04196db1` | cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `research/hover_distance_takeoff_formal_20261103/hdtf_metrics.m` | `5d103927bda18691afc483b81c2365d36e86d6fde5802725d787a0eb63522647` | C1原始工作树；cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `research/hover_distance_takeoff_formal_20261103/hdtf_run.m` | `4182f981f8bd898ff7e2eaa8656a4bbef329e5348eeb91cc76e79d4302f0ddab` | 冻结执行版:docs/validation/hover_distance_takeoff_formal_20261103_r1/hdtf_run.frozen.m |
| original | `research/hover_distance_takeoff_formal_20261103/hdtf_sources.m` | `23e45c3ef5b866e342e99aa444e89f7eed21895b6b942e036054df1442c48039` | C1原始工作树；cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `research/hover_distance_takeoff_formal_20261103/protocol.json` | `c3b0dce57c6ccb02c036a9d53b28a2fd2fb7dedfd5d7e0b32ad7d1fe4cd83341` | C1原始工作树；cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `research/hover_distance_takeoff_20261103/hdt_reference.m` | `716996e9a29ae8bea116badb1976a7fce132724be3c91eb254b28bbcf7ccc539` | C1原始工作树；cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| original | `run_hover_distance_takeoff_formal.m` | `a25afde100380173f83377f223475aa70b9a36645cccfe1147516ba9bd0502a4` | C1原始工作树；cef7c0e106f738bac8e132a410e486931700f88a:Git原字节 |
| changeB | `research/hover_distance/hd_config.m` | `3e32688885c9d95cb6ff9656df7a2a612cb974ed24abad7a52dff214712d716c` | C1原始工作树；f788076ea05d85c62cbeecdf8ba5bef165c3c84d:Git原字节 |
| changeB | `research/hover_distance_takeoff_formal_20261103/hdtf_config.m` | `d836ae1275cabadb5bec1d23e47f44aa4c8866b99a412a4b5fbc170bb43ce7bc` | C1原始工作树；f788076ea05d85c62cbeecdf8ba5bef165c3c84d:Git原字节 |
| changeB | `research/hover_distance_takeoff_formal_20261103/hdtf_run.m` | `2f5b9ecc330197e7d6a9213915fc55026da115c6d9dba63c2105e24402daacc6` | C1原始工作树；f788076ea05d85c62cbeecdf8ba5bef165c3c84d:Git原字节 |

## 重现步骤

1. 只读读取上述git_start、source_lock、原批protected_before、frozen driver及post_batch_management_fix。
2. 在仓库外临时目录用git show读取启动/交付提交的engine固定目录m、mismatch protocol和两MAT。原批按历史保护SHA逐文件选原blob/CRLF候选；change-B按上述保留字节和唯一旧版文件构造，不执行任何历史控制源码。
3. 在干净MATLAB会话中添加当前analysis目录；以反斜线绝对根调用未改动的allocation_comparison_engine，核对上方完整值。原始和交付两个临时目录都应分别得到相同d4/c640。
4. 只在临时change-B目录替换shc09_navigation_sensors.m为当前字节，再算应得到ec。DEV与快照规范化根下重复计算应同为ec；正斜线误用应得到记录的不同值。
5. 所有显式70逐文件SHA及两MAT和exe分别核验，不运行控制器、仿真、ECL进程或构建脚本。历史锁只读。
