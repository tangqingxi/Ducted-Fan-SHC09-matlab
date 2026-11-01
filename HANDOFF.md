# HANDOFF — F8研究已按用户要求暂停

> 暂停断点：2026-11-01 17:21（Asia/Shanghai），用户明确指令“先暂停”。已停止本次MATLAB进程；不自动恢复、不启动后续测试或绘图打包。

- 基础F8正式批次30/30完成：F8-R任务15/15通过，F8-D任务5/15通过；完整30条与两场景图表保留在`results/f8_v1_formal_20261101_frozen_3seeds`。
- F8-P-v2开发筛选已9次全部尝试：6完成、3气动表越界失败，失败记录完整保留；唯一入选为`F8PR-Y60-F075`。开发seed9002预测PCA相对WLS航向RMS降低49.06%、水平RMS增加1.77%、实际主窗舵速RMS增加2.60%、总行程增加3.10%，但PWM步变约6.88倍；不是独立确认结论。该组开发主窗λ仍为1，不能宣称受限优先级保护。
- 开发目录`results/f8_pressure_screen_20261101_Rbase_v2_bounded_yaw`；6条完整MAT的输入和主要指标已独立核验，5条PCA已导出lambda/beta/模式统计及开发图。更强候选未通过和越界数据全部保留。
- 独立确认目录`results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds`：仅DA_NS/seed201完整完成并通过全部任务要求（水平RMS0.330156m、航向RMS1.18017°）；WLS/seed201运行中被用户暂停打断，未冒充完成。CSV当前1 completed、14 not_run；应另识别其中1次中断尝试，不把其当模型运行失败或完整轨迹。
- 确认日志`archive/logs/f8_confirmation_20261101.log`。原`finish_f8_study.m`因把开发候选失败当整批停止而退出；后续仅修正确认前置流程检查，允许未选中候选保留failed，但所选候选仍须3开发方法完整、确认仍须15/15完整。精确单行差异见`results/f8_work_20261101/development_failure_guard_correction.json`；数值参考、模拟器、评价指标、门槛及选择条件没有改变。
- 当前冻结快照为`results/f8_work_20261101/numerical_sources_before_confirmation.json`（20文件）；引擎仍为`e8d0c32c3faee85b60dee14c6fc653f3e1155a10630b3b3a352ba933942603f8`。旧压力前快照保留，唯流程检查的差异单独记录。
- `results/f8_work_20261101/pipeline_complete.json`尚不存在；`examples/f8_comparison_20261101`尚未生成。不得宣称确认15/15、PCA优势已重复或研究全部完成。
- 恢复必须等待用户明确指令；先核对源码摘要、已有DA_NS完整日志和状态，再实现不覆盖已有目录的断点续跑。直接重跑`finish_f8_confirmation.m`会因目录已存在被拒绝，不应删除结果、伪造缓存或改换保留种子。
- 当前工作未提交、未tag、未push；暂停不改变已有远端或v0.5.0标签。

## 暂停前研究记录

> 当前补充：2026-11-01；以下“目录整理交接”保留为历史快照，当前研究状态以本节为准。

- 当前main与origin/main均为 `9918d9dba180f38a62c36f602e37993b87d0d38d`（目录整理已按后续用户指令push）；v0.5.0仍剥离到 `3fc46c0247fea6e82c95e38721f56fa256bf3b72`。
- 八字、优先级审计、lite动态修复和F8新增文件均为当前未提交工作；没有把本次修改合并发布、打tag或push。
- 用户纠正了近悬停门禁套用于八字的实验设计：旧原始数据和CSV标签保留，但不再用5°/10%判动态任务资格，不再据此选42秒候选。
- 用户允许借鉴PX4增加平滑轨迹前馈。当前[F8-v1协议](docs/reference/f8_protocol.md)独立声明参考、前馈、包线、跟踪要求与机制激励；[机器配置](configs/f8_protocol_v1.json)在正式F8仿真前写定，变更需另立版本。
- F8显式开启速度/加速度及名义几何角速度/角加速度前馈；旧位置控制函数和旧默认路径保留，反馈增益未改。lite的GNSS速度辅助也由新任务显式开启，旧默认关闭。
- F8-R与F8-D均为3/1.5m水平半幅，周期20/10秒，配平高度10m；yaw分别20°sinφ与35°sinφ+8°sin3φ；正式保留种子101–103，五方法、每场景15条，共30条。
- 用户已明确允许开始正式八字测试并寻找PCA有利场景。基础批次`results/f8_v1_formal_20261101_frozen_3seeds`已30/30完成，0运行失败；F8-R任务15/15通过，F8-D为5/15通过，其余10条因高度RMS超过0.20m未通过。两组均未达到完整优先级激励/几何条件，不把完成数量当任务通过数量。
- 基础日志：`archive/logs/f8_formal_20261101_frozen_3seeds.log`。后处理`results/f8_work_20261101/finish_f8_study.m`已核验30条完整MAT、1440条十二状态指标并抽查36个独立LP快照；两个基础场景各8组PNG/PDF已生成。不要重复启动同一批次。
- 压力v2正在运行，日志`archive/logs/f8_research_postrun_20261101.log`；输出`results/f8_pressure_screen_20261101_Rbase_v2_bounded_yaw`。截至16:57为1/9：F8PR-Y60-F075、WLS、seed9002通过全部任务要求，水平RMS0.277m、航向RMS1.249°；PCA尚待比较，不能提前宣称胜出。
- F8-R前两个种子的静态PCA与DA_NS/WLS接近数值一致，运动窗λ=1；预测PCA的跟踪差异很小，但全程PWM步变RMS明显更大，不能提前宣称PCA胜出。
- F8-D首个种子的多方法高度RMS约0.228m未通过0.20m；离线分解显示来流/静态推力映射向下缺口约0.225m/s²，高度估计均值偏差仅约1.5cm。完整基础30条仍保留，不据此改控制器或门槛。
- 原[F8-P-v1预案](docs/reference/f8_pressure_protocol.md)尚未执行；根据上述公共高度瓶颈，另立[F8-P-v2有限偏航协议](docs/reference/f8_pressure_protocol_v2.md)，位置改用已15/15通过的F8-R，并以真实舵速/总行程评价代价，不把PWM步变当实际运动。此为公开记录的自适应设计，不追认预注册。
- 若基础两组都没有达到完整优先级激励/几何条件，再执行v2：开发种子9002、三个固定候选×WLS/静态/预测=9条；只有满足先验收益与实际运动代价条件才确认单一候选，五方法×201–203=15条。没有有希望候选就停止；原F8门槛不改，保留全部不利结果。v1压力预案不再额外运行。
- 之前种子9001、WLS、8秒smoke完成1/1，接线和包线通过，但截短主窗高度RMS0.2023386m超过先验0.20m；它不计正式验收，未据此改门槛。
- 最新回归14/14、平台6/6、冻结基线6组逐位一致；解析参考、前馈消费、约束和新门禁语义单元测试通过。证据见[F8验证记录](docs/validation/f8_protocol_v1/report.md)。旧LitePhysicalBias 0.05°/s预期失败未放宽，本次不宣称解决。
- 用户补充的70%是遥控器杆量，对应2100gf悬停；不能直接当推力/转速百分比。模型静态推力上界41.70816N，理想保高倾角60.4736°，10%余量后56.7987°；F8另限制45°，不是实机极限证明。
- 用户提供的[DuctedFanUAV-Autopilot核查](docs/reference/ductedfan_autopilot_reference.md)固定到df-main的2e53639；已核对专用八字、前馈、SHC09推力映射、时延与PCA前置条件，未克隆/编译该外部工程。
- 完整原气动模型冻结力扫描4544组合；域外组合只记录NaN，没有外推改表。45°部分来流方向不在模型域，不能据静态上界作实机保证。
- 当前工作完成后用`test_f8_comparison_results`、`f8_allocation_diagnostics`核对完整日志，再用`tools/plot_f8_comparison.py`绘图。基础比较实际调用的轨迹/控制器/物理及引擎保持不变。未执行的压力辅助代码仅增加v2接口；20个源码与协议的启动前摘要另存`results/f8_work_20261101/numerical_sources_before_pressure_v2.json`，后处理在首次压力轨迹前核对，不得混入参数更改。

## 目录整理交接的历史快照

> 文档类型：当前。

- **Last updated:** 2026-11-01T09:07+08:00（Asia/Shanghai）。
- **当前分支：** main，已本地ff合入repo-structure，未push。
- **已验证源码HEAD：** f2f96d5144750de11ea5527e114365793f4e484e（repo-structure上运行验证时的HEAD）。
- **验证提交 / repo-structure分支：** 9c42c02783b34a056abcfc46cad8de415091dda2，`docs: validate v0.5 numerics after repository structure`；该分支保留，未删除。
- **当前main最终HEAD：** 以git log -1或git rev-parse refs/heads/main为准；本文件另提交 `docs: update handoff after structure merge`。
- **发布标签：** v0.5.0仍剥离到3fc46c0247fea6e82c95e38721f56fa256bf3b72，annotated tag对象0b238275cbe01ee26c51758e3d923468c06c2d21。没有创建或移动任何tag。
- **远端：** origin/main仍3fc46c0；本轮未push、未force push，所有合并与新验证记录只在本地。
- **工作区：** 最终文档提交后应干净；没有本次MATLAB进程遗留。本轮完成后停止。

## 1. 这次为什么验证

目录整理移动了入口、文档并更新README。本轮在repo-structure上验证它没有改变v0.5数值；只有所有比较和测试通过后才执行本地ff合并。main现在包含PX4日志视图、目录导航、f2f96d5的README更新和本次验证记录，没有新增算法或研究功能。

入口和文档的布局见[仓库地图](docs/repository_map.md)，阅读入口见[文档导航](docs/README.md)。历史整理记录保留在[结构验证目录](docs/validation/repository_structure/)，本次新增的是[合并前数值验证报告](docs/release_validation/repository_structure/report.md)。

## 2. A段：60/60及逐项比较

基准：results/allocation_comparison_v050_comparison_3seeds。
新输出：results/allocation_comparison_structure_validation，使用新目录，没有覆盖旧结果。入口自动添加allocation_comparison_前缀，因此output_tag用structure_validation以生成任务指定目录，其他仿真参数未变。

- M0/M2b×ideal/lite×五方法×seeds1:3，正式60/60完成，失败0、未运行0。
- provenance.loaded为真60条，全部来自reuse_from基准日志；新跑正式轨迹0条，没有伪造缓存命中。
- 四组comparability均rankable。
- summary只排除simulation_elapsed_s，其余字段全部精确一致；未排除任何其他数值列。
- comparability、effect_sizes、pareto、status逐行逐项一致，status完成计数也一致。
- MATLAB以isequaln比较，Python另外逐单元比较CSV原始字段字符串；不排序、不设容差、不四舍五入。differences.csv为0行。

[release_checks.json](docs/release_validation/repository_structure/release_checks.json)包含全部要求字段；[report.md](docs/release_validation/repository_structure/report.md)为19行说明；[differences.csv](docs/release_validation/repository_structure/differences.csv)及[源码/原始CSV审计](docs/release_validation/repository_structure/source_and_csv_audit.json)保留具体证据。记录中的head_commit=f2f96d5、main_commit=3fc46c0表示A段验证时的源码和基线，不是最终文档提交的自引用SHA。

## 3. A段：新旧测试、入口和链接

- test_allocation_comparability通过：原数值边界、缺失种子、NaN、CSV空错误列与审计错误等检查。
- test_allocation_comparison通过：两秒40项、独立重复、共同输入、缓存和故障处理；人工失败夹具不冒充正式研究失败。
- run_project_tests(false) 14/14，run_platform_tests 6/6。
- test_platform_baseline六组完整非耗时日志SHA、数值与PWM逐位一致，最大差0。
- test_px4_log_export通过，原log不变、四元数与CSV往返正常。
- which main_mismatch_ladder/main_candidate_screen/plot_main_comparison解析到apps/legacy；main_comparison解析到apps。
- python tools/check_docs_links.py：0断链。

LitePhysicalBias另用既有12秒物理协议新鲜复测，再调用原测试的0.05°/s断言，仍按预期失败：bias RMS=0.060980606944452245°/s，末值=0.058320335015275976°/s。独立进程重抛shc09:LitePhysicalBias，按预期退出1；比较与其余测试进程正常退出0。没有放宽或修复门限。

[测试汇总](docs/release_validation/repository_structure/tests/checks.json) · [14项](docs/release_validation/repository_structure/tests/project_tests.csv) · [6项](docs/release_validation/repository_structure/tests/platform_tests.csv) · [冻结基线](docs/release_validation/repository_structure/tests/baseline.csv) · [入口路径](docs/release_validation/repository_structure/tests/entry_points.csv) · [偏置复测](docs/release_validation/repository_structure/physical_bias.json)。

## 4. B段：本地ff合并及后核验

A段通过后，在repo-structure提交验证记录并确认工作区干净；随后git switch main、git pull --ff-only --no-tags、git merge --ff-only repo-structure，main从3fc46c0 fast-forward到9c42c02。没有创建新tag、push或删除分支。

合并后再次检查213个运行文件的规范化代码对象，全部与验证分支一致；数值核心文件原始字节未变。Git按既有eol=lf属性将11个入口文件从CRLF物化为LF，只有换行表示变化，未手工改写代码，详见[合并后源码审计](docs/release_validation/repository_structure/post_merge_source_audit.json)。A段也记录了既有ca_mismatch_protocol工作区CRLF与Git对象LF的表示差异，未修改该文件。

合并后独立MATLAB快检正常退出0：数值引擎仍26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286，四个入口仍解析到预期apps路径；该快检新增仿真0次。[合并后引擎/路径记录](docs/release_validation/repository_structure/post_merge_checks.json)。这些核对没有放宽A段的数值比较精度。

## 5. 本地证据位置

- 正式分支输出：results/allocation_comparison_structure_validation/，包含60条复用日志及五种产品CSV。
- 本次验证文档：docs/release_validation/repository_structure/。
- 比较日志：archive/logs/structure_v050_compare.log。
- 新旧测试日志：archive/logs/structure_v050_tests.log。
- 物理偏置预期失败日志：archive/logs/structure_v050_physical_bias.log。
- 合并后快检日志：archive/logs/structure_post_merge_check.log。

所有旧正式数据、缓存和归档日志保留，没有覆盖或删除。完整MAT/cache仍不入Git。当前发布版本仍v0.5.0，默认ideal，lite仍experimental且物理偏置门禁未过；本地目录整理的数值已通过本次验证，不表示发布了新版本。

## 6. 实时引用与停止

```powershell
git status
git branch --show-current
git log --oneline -4
git rev-parse refs/heads/main
git rev-parse refs/heads/repo-structure
git rev-parse refs/tags/v0.5.0
git rev-parse 'refs/tags/v0.5.0^{}'
git ls-remote --heads origin main
```

应为本地main已包含repo-structure并领先origin/main；repo-structure保留9c42c02；v0.5.0剥离提交和远端main仍3fc46c0。当前main完整SHA用实时refs核验，不写死到自引用文件里。本轮没有push、force push、新建或移动tag。

本轮完成后停止，下一步等待用户指令；不自行发布或继续开发。不改物理、气动、控制器、五分配器、估计器、阈值，不跑E1/E2、M4全量、完整失配阶梯或参数不确定性。不git clean/reset，不删除repo-structure，不读写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。
