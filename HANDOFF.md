# HANDOFF — 仓库结构与导航整理完成（未合并）

> 文档类型：当前。

- **Last updated:** 2026-11-01T00:11+08:00（Asia/Shanghai）。
- **当前分支：** repo-structure，基于px4-log-view的d8809fc，不是从main重新分支。
- **发布基线：** main/远端main仍3fc46c0247fea6e82c95e38721f56fa256bf3b72，v0.5.0剥离提交相同。
- **工具基线：** 本地/远端px4-log-view仍d8809fc399a34f20d28fd1916a24d932c1f96225；上一轮PX4日志工具已推送但未合并main。
- **本轮提交：** 9bb43d7（入口移动）、d1f1503（文档与README）、eca40af（链接检查器）；本文件单独提交 `docs: update handoff for repository structure`，最新HEAD用git log -1查询。
- **状态：** 本轮只提交本地repo-structure；未合并main、未tag、未push。提交后工作区干净，没有本次MATLAB进程遗留。完成后停止。

## 1. 从哪里读

先看[简短README](README.md)，再看[按任务组织的文档导航](docs/README.md)。目录职责看[仓库地图](docs/repository_map.md)，历史结论看[历史索引](docs/history/README.md)。本文件用于当前状态与下一步，不再堆放历史报告正文。

## 2. 本轮完成

1. 用git mv移动17个入口：main_comparison到apps；两个main_realistic入口到apps/experimental；14个旧main_*/plot_main_*到apps/legacy。函数名和源文件字节完全保留。ca_setup只增加这两个显式路径，未改运行算式。
2. 用git mv移动25份文档：8份指南（含3份lite）、4份参考、10份历史、3份发布说明。相对链接统一修正，文档标明当前/参考/历史/证据；13份历史/发布报告除链接目标和分类标签外正文逐字保持。
3. 新建docs/guides/lite/README.md、docs/history/README.md；docs/README按八类读者任务组织。根README为132行直白中文，保留一次运行、模式选择、目录地图、边界及已知限制。
4. 原根目录54个archive_*.log移到archive/logs，逐一SHA256验证不变，没有删除或覆盖。新增[归档说明](archive/README.md)和[分主题日志索引](archive/logs/README.md)。Git只追踪这两个索引，实际日志与历史副本仍忽略。
5. 新增tools/check_docs_links.py，标准库检查本地链接、图片和引用式链接，报告文件及行号，遇断链非零退出；跳过网络、邮件和纯锚点，不探测仓库外目标。新工具正反用例验证通过。
6. 同步目录地图、索引、文件清单和既有治理检查的两个归档索引例外；实际日志仍禁止被清单检查当作可提交文件。

本轮根目录非隐藏文件仅保留README、HANDOFF、CHANGELOG、THIRD_PARTY_NOTICES及ca_setup/main/shc09_run/三个测试入口/ECL构建入口；.gitignore和.gitattributes继续保留。完整移动清单与源文件SHA见[结构验证](docs/validation/repository_structure/structure_checks.json)。

## 3. 新目录层次

```text
apps/
  main_comparison.m
  experimental/     两个非理想研究入口
  legacy/           旧研究与重绘入口，名称保留
  其他现行app       保留原位置

docs/
  README.md
  repository_map.md
  guides/
    lite/           README、fix、peak_diagnosis、results
  reference/
  history/
  releases/
  evidence/         原目录不移动
  各验证目录及CSV/JSON清单

archive/
  README.md
  logs/README.md    真实日志仅本机保留
```

platform/models/allocators/configs/effectiveness/drivers/lib/modules/compat没有移动；其中仅文档引用和用途标签按需更新，所有数值源码不变。results、third_party、docs/evidence未搬迁或删除。build与.tmp_matlab保留，地图标注生成、可删，但本轮没有删除。

## 4. 测试和路径

本轮MATLAB验证正常退出0：

- run_project_tests(false)：14/14。
- run_platform_tests：6/6。
- test_platform_baseline：六组完整非耗时SHA、数值指标及PWM逐位一致，最大差0。
- test_px4_log_export：通过；两秒实际日志1601行，q往返误差约2.6185e-16，CSV时间精确往返、原输入不变。
- 数值引擎仍26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286。

旧入口which结果：

```text
main_mismatch_ladder -> apps/legacy/main_mismatch_ladder.m
main_candidate_screen -> apps/legacy/main_candidate_screen.m
plot_main_comparison -> apps/legacy/plot_main_comparison.m
main_comparison -> apps/main_comparison.m
```

链接检查命令：

```powershell
python tools/check_docs_links.py
python tools/repo_inventory.py --check
```

最终要求断链0；治理检查通过且无活动函数冲突。检查器反例确认缺文件、缺图片、未定义引用及仓库外路径均有行号并非零退出，不把反例失败当项目回归失败。

[MATLAB结果](docs/validation/repository_structure/checks.json) · [14项](docs/validation/repository_structure/project_tests.csv) · [6项](docs/validation/repository_structure/platform_tests.csv) · [基线](docs/validation/repository_structure/baseline.csv) · [which路径](docs/validation/repository_structure/entry_points.csv) · [检查器自测](docs/validation/repository_structure/link_checker_selftest.json)。

## 5. 结果与日志位置

本轮验证日志直接写入archive/logs/repo_structure_validation.log，不再放根目录。旧日志名称保持；此前JSON证据内的根日志路径是生成时快照，可按同名在新日志索引中查找，不改写旧JSON记录或历史结论。

本轮PX4导出仍是本地results/px4_log_export_20261031_235551_207/smoke/px4_log.csv和px4.mat。它仅来自2秒测试，不是重跑主比较。更早的正式结果和缓存全部保留，当前60/60发布证据见[发布验证](docs/release_validation/v0.5.0/release_checks.json)与[当前轻量报告](examples/lite_comparison_v050/comparison_3seeds/report.md)。

v0.5.0状态不变：M0/M2b的ideal/lite均rankable；lite仍experimental、默认ideal、LitePhysicalBias按0.05°/s仍为已知预期失败。本轮没有重新评价偏置、重跑60次、E1/E2或M4全量。

## 6. 核验与停止边界

```powershell
git status
git branch --show-current
git log --oneline -4
git rev-parse refs/heads/main
git rev-parse refs/heads/px4-log-view
git ls-remote origin refs/heads/main refs/heads/px4-log-view
```

当前应在repo-structure且干净；main/远端main保持3fc46c0，px4-log-view本地/远端保持d8809fc。未经用户明确新指令，不合并main、不tag、不push，不开始其他功能。本轮完成后停止，下一步等待用户新任务。

不改物理、控制器、五算法、估计器、模块接口或门禁；不移动数值目录，不删除archive/results/third_party/docs/evidence，不git clean/reset，不force push。不读取或写入 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。以后每次结束、暂停或失败，继续更新HANDOFF并单独文档提交。
