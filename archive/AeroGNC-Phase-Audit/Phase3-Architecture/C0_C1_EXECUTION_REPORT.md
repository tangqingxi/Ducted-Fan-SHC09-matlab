# Phase3 C0/C1 执行报告

日期：2026-11-05（Asia/Shanghai）。执行者：Codex（GPT-6）；dual-repo-agent-handoff 0.2.2。

本轮 C0/C1 的实现、静态检查、MATLAB 路径检查与唯一一次短例完成；DEV 已推送。**不启动 C2**。历史 engine 锁与本机重算值的对应关系尚未建立，是后续迁移前的来源核对门槛；不将本报告视为历史科研验收。

## Git 身份和范围

- DEV：`refactor/phase3-source`，`b2a287ceff34445bb7902890141be7a450d19de9`；远端同 SHA。
- 正确起点：`fdc933694db9c16a0d9ffcd6d9c391b052352d22`，main 保持此值。
- 科学基准：`339d7b1a997de6ba350cef3207d8a5b7db3d838d`。
- C0：`f3b01152b33c59ac890c5f907405a300f87da4f0`；文件为 docs/refactor/PHASE3_MAPPING.md、HANDOFF.md、README.md（末段过期指针最小修订）。
- C1：`b2a287ceff34445bb7902890141be7a450d19de9`；文件为 ca_setup.m、12份 src/README.md 占位、tools/check_phase3_paths.m、tools/check_phase3_static.py。
- 完整文件表：[git-changes](c0-c1/git-changes.txt)。共18文件，原文件仅3份变更；原 MATLAB 文件零移动，唯一修改 ca_setup。
- DEV 保留未跟踪 `.dsh-plugins/`；未暂存或删除。AUDIT 起点 main `dda650fb062a48900df10d14084b0861281ed012`，本轮仅 Phase3-Architecture 轻量证据及交接更新。发布 SHA 见提交历史及最终回复，避免自引用。

## 路径与骨架

建立 src/runtime/{logger,sim}、src/control、src/allocation、src/effectiveness、src/sensors、src/navigation/px4_ecl、src/drivers、src/lib、src/compat。共12份占位README；没有算法实现或软链接。

ca_setup 由自身位置确定根；保留原显式目录和注册表追加。每行旧、新路径顺序前置，后加入的目录优先；不存在的目录安全跳过。六个 allocators 顶层注册目录不变。效能旧目录可映射 src/effectiveness。全部直属 .m 先检查同名、再核对 MATLAB 实际解析；重复初始化稳定。新旧副本不靠优先级择一，报 ca_setup:DuplicateFunction。没有 genpath；未加入结果、冻结证据、第三方或备份目录。

平台链和四环链不合并。run_ppid_pindi 原有显式 research 路径保持原字节；检查器仅重现该上下文，不调用研究入口。C5 前仍须处理入口中的硬编码及 PPID 拆分路径，不宣称 C1 已完成全部迁移。

CSV 的 allocators/plugins 目标与方案正文/现有 registry 不一致，已在 DEV 映射登记；本轮遵用户指令保留顶层现状。src/allocation 是接口规划占位，CSV 当前接口落在 allocators/interface；C3 前统一计划，不静默改写历史 CSV。

## 验证结果

| 项目 | 状态 | 证据 |
|---|---|---|
| 静态目录、六分配器、效能factory、Git范围 | PASS | [static.json](c0-c1/static.json) |
| 原跟踪文件原始字节保护 | PASS：1,746项，仅3份预期文件变化 | [preservation.json](c0-c1/preservation.json) |
| 原 MATLAB 路径、算法、协议、来源锁保护 | PASS：零移动，除ca_setup外原m字节不变 | 同上 |
| MATLAB which -all | PASS：287个名字，包括关键模型与两条链入口 | [paths.json](c0-c1/paths.json) |
| 六分配器及2效能注册、14个句柄 | PASS | 同上 |
| 重复 ca_setup、路径优先级 | PASS：完整 path 字符串相同，全部活动实现解析到其实际文件 | 同上 |
| 新旧同名保护负例 | PASS：临时伪仓库 main.m/src/runtime/main.m 被拒绝，path不变 | [duplicate-guard.json](c0-c1/duplicate-guard.json) |
| 历史同名白名单 | PASS：两份 round5_components.m 在 docs/validation，均不入搜索路径 | static.json列精确路径；未删任一份 |
| Markdown本地链接 | PASS：既有工具90份/565链接/0断链；另查12份src README链接 | preservation.json |
| 单方法2秒hover短例 | PASS：无结果/图保存，非最优/回退/救援均0 | [smoke.json](c0-c1/smoke.json) |
| 历史结果保护 | PASS：73,292项文件集合、大小、mtime不变；来源锁另查SHA | [data-preservation.json](c0-c1/data-preservation.json) |
| 全套/正式/多种子试验 | NOT RUN：本轮明确禁止 | [执行记录](c0-c1/execution-attempts.json) |

MATLAB：25.2.0.2998904 (R2025b)，Optimization Toolbox许可证检查通过；干净batch会话 restoredefaultpath，无 savepath。烟测 rotation_rmse_deg=0.3634660226、最大PWM命令8.70182432度；仅说明本短例可运行，不外推科研/实飞验收。初次验证驱动的路径/函数名错误及修复已列执行记录；最终状态按保存的PASS证据报告，未隐瞒初次失败。

## 可复现命令

在 DEV 根目录使用 PowerShell：

```powershell
python tools/check_phase3_static.py --output "$env:TEMP/phase3-static.json"
python tools/check_docs_links.py
matlab -batch "restoredefaultpath; addpath(pwd); addpath(fullfile(pwd,'tools')); report=check_phase3_paths(pwd); disp(report.status)"
```

短例本轮已经执行一次，不应在接手时自动重跑；获准需运行时使用 README 的 ca_setup; r=hover_app("PCA_PREDICTIVE"); disp(r.metrics)。检查 shc09_airframe 的 duration_s=2、save_results=false、save_figures=false；本轮命令另外断言许可证与这些配置，结果仅写临时证据JSON。负例在临时目录复制ca_setup并创建两个空main函数，捕获指定错误码；未写DEV伪实现。

## engine 与来源身份

[identity.json](c0-c1/identity.json)分别登记原始文件SHA256、PPID逐文件来源和MATLAB engine，不把它们当作可互换口径。

- engine实现和覆盖目录原路径/字节均未变，因此 C1 前后 engine不变（前值基于覆盖集合一致性推定）；当前与快照规范化原生根路径的MATLAB实测均为 `ec1491ec96eae309cf227b1877a2e9c22db66c7779ee96497e04a1c7403b60ab`。
- ca_setup SHA256：`1e51810df05547603c76045f0e33f7bea2ec6b17ebfa495061ff35584c92a6bc` → `b7445ed2996c1298bbaffcfdba6a176dae9d04abb435689276a9f16a48baf2d6`。PPID逐文件来源身份因此改变；identity里的 before 清单由未变文件集合与本轮修改前raw SHA重建，明确不是原版MATLAB重新执行。
- 早期以正斜线根路径调用engine得到不同值，原因是原实现前缀擦除依赖分隔符；规范化后当前/快照一致。engine未改写。
- 历史正式锁仍含 d4c19f32… 与 c6403c02…，与规范化实测ec1491ec…不等。**历史锁一致性未建立**；不能将此写成历史复算通过，也不能重写锁。本轮只登记现象；C2前应核对历史执行版本、字节口径和MATLAB序列化环境。
- allocation_comparison_engine、ppid_source_manifest、历史锁、GNSS/ECL、控制器、气动与执行器代码均保持原字节。

## 备份与后续准入

快照只读核查11,144文件、5,006,551,294字节；没有重新复制5GB，也没有重新全量校验快照。此前完整SHA验证/恢复来自既有 Phase2B-Backup 与 Phase2B-Restore 证据；Phase3原manifest三文件已核验。D/E同物理磁盘，快照仅作逻辑回滚保护。

C2/W1需另获源码移动授权，定位历史engine锁对应关系，逐条核对W1实际文件映射、相对路径与来源清单，保存迁移前后raw SHA，修正当波来源覆盖并登记新engine（不能等C8才处理失配）。分配器CSV矛盾在C3前统一。C1路径机制已通过，无路径运行阻塞；历史身份核对和移动授权仍是C2门槛。回滚使用普通git revert C1/C0，不重写main，不触碰数据和用户未跟踪项。
