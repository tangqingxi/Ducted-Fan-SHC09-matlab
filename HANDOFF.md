# HANDOFF — repo-structure数值验证通过，已本地合入main

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
