"""核对外部审计清单及源工作树，生成报告；不运行仓库代码或仿真。"""
from pathlib import Path
from collections import Counter, defaultdict
import csv
import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone

ROOT=Path('E:/Ducted-Fan-SHC09-matlab')
OUT=Path(__file__).resolve().parents[1]


def read(name):
    with (OUT/name).open(encoding='utf-8-sig',newline='') as f:
        return list(csv.DictReader(f))


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):
            h.update(b)
    return h.hexdigest()


def write(name,rows,fields):
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT).decode('utf-8')


def main():
    before=json.loads((OUT/'evidence/GIT_STATE_BEFORE.json').read_text(encoding='utf-8-sig'))
    after={cmd:git(*cmd.split()[1:]) for cmd in before['commands']}
    (OUT/'evidence/GIT_STATE_AFTER.json').write_text(json.dumps(after,ensure_ascii=False,indent=2),encoding='utf-8')
    initial={f['path']:f for f in json.loads((OUT/'evidence/FILE_METADATA.json').read_text(encoding='utf-8-sig'))}
    current={}
    errors=[]
    def visit(folder):
        try:
            entries=list(os.scandir(folder))
        except OSError as e:
            errors.append(str(e))
            return
        for e in entries:
            p=Path(e.path)
            rel=p.relative_to(ROOT).as_posix()
            if rel=='.git':
                continue
            st=e.stat(follow_symlinks=False)
            link=e.is_symlink() or p.is_junction()
            if e.is_dir(follow_symlinks=False) and not link:
                visit(p)
            else:
                current[rel]=dict(path=rel,size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,is_link=link)
    visit(ROOT)
    changes=[dict(path=k,before=initial.get(k),after=current.get(k)) for k in sorted(set(initial)|set(current)) if initial.get(k)!=current.get(k)]
    (OUT/'evidence/WORKTREE_METADATA_CHANGES.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8')
    inv=read('FILE_INVENTORY.csv')
    matrix=read('MIGRATION_MATRIX.csv')
    batches=read('RESULTS_BATCHES.csv')
    mats=read('MAT_METADATA.csv')
    wtrs=read('WTR_INDEX.csv')
    docs=read('ROOT_DOCUMENT_INDEX.csv')
    agent=read('AGENT_REPORT_MIGRATION.csv')
    fingerprints=read('SOURCE_FINGERPRINTS.csv')
    required={
        'FILE_INVENTORY.csv':'path size_bytes tracked file_type category current_purpose referenced_by retention_class proposed_action risk'.split(),
        'RESULTS_BATCHES.csv':'study batch_id protocol source_commit methods seeds duration_s execution_status acceptance_status retention_status raw_mat_available wtr_available metrics_available lock_available total_size_bytes related_paths recommended_action'.split(),
        'MIGRATION_MATRIX.csv':'current_path target_path category action dependency compatibility_risk verification_required execution_phase approval_required'.split(),
    }
    field_errors=[]
    for name,fields in required.items():
        rows=read(name)
        missing=set(fields)-rows[0].keys()
        if missing:
            field_errors.append(dict(file=name,missing=sorted(missing)))
    targets=defaultdict(list)
    for row in matrix:
        if row['action'] in {'MOVE_CANDIDATE','ARCHIVE_CANDIDATE'}:
            targets[row['target_path']].append(row['current_path'])
    collisions=[dict(target_path=k,current_paths=';'.join(v),count=len(v)) for k,v in targets.items() if len(v)>1]
    write('TARGET_COLLISIONS.csv',collisions,['target_path','current_paths','count'])
    source_changes=[r['path'] for r in fingerprints if sha(ROOT/r['path'])!=r['sha256']]
    document_changes=[r['path'] for r in docs if sha(ROOT/r['path'])!=r['sha256']]
    report_changes=[r['current_path'] for r in agent if sha(ROOT/r['current_path'])!=r['sha256']]
    # 大文件沿用已完成的全量SHA身份核验，末次检查只复核大小及mtime，避免反复读盘。
    protected=read('KEY_ARTIFACT_HASHES.csv')
    protected_meta_changes=[r['path'] for r in protected if initial.get(r['path'])!=current.get(r['path'])]
    metric_checks=[]
    for batch,report in [
        ('hover_distance_takeoff_formal_20261103_r1','docs/validation/hover_distance_takeoff_formal_20261103_r1/metrics.csv'),
        ('hover_distance_takeoff_formal_changeB_20261104_r1','docs/validation/shc09_b_frame_20261104/independent_audit_20261104/formal_metrics.csv')]:
        with (ROOT/report).open(encoding='utf-8-sig',newline='') as f:
            metrics=list(csv.DictReader(f))
        for item in metrics:
            source=f"results/{batch}/logs/{item['method']}_s{item['seed']}.mat"
            m=next(m for m in mats if m['path']==source)
            diff=abs(float(m['main_15_27_true_rmse_m'])-float(item['true_horizontal_rmse_m']))
            metric_checks.append(dict(batch_id=batch,method=item['method'],seed=item['seed'],source_mat=source,window='15<=t<27',recomputed_rmse_m=m['main_15_27_true_rmse_m'],saved_rmse_m=item['true_horizontal_rmse_m'],absolute_difference_m=diff,passed=diff<1e-10))
    write('FORMAL_METRIC_CROSSCHECK.csv',metric_checks,list(metric_checks[0]))
    val=dict(
        timestamp_utc=datetime.now(timezone.utc).isoformat(),
        git_state_identical=after==before['commands'],
        head=after['git rev-parse HEAD'].strip(),
        working_tree_clean=git('status','--porcelain')=='',
        metadata_files_before=len(initial),metadata_files_after=len(current),metadata_changes=len(changes),metadata_errors=errors,
        inventory_rows=len(inv),matrix_rows=len(matrix),inventory_covers_snapshot={r['path'] for r in inv}==set(initial),matrix_covers_snapshot={r['current_path'] for r in matrix}==set(initial),
        unique_inventory_paths=len({r['path'] for r in inv}),unique_matrix_paths=len({r['current_path'] for r in matrix}),required_column_errors=field_errors,
        invalid_actions=sorted({r['action'] for r in matrix}-{'KEEP','MOVE_CANDIDATE','ARCHIVE_CANDIDATE','DELETE_CANDIDATE','REVIEW_REQUIRED'}),
        source_fingerprint_checks=len(fingerprints),source_fingerprint_changes=source_changes,document_hash_checks=len(docs),document_hash_changes=document_changes,
        original_agent_reports=len(agent),original_agent_report_changes=report_changes,key_raw_mat_full_sha_computed=len(protected),key_raw_mat_final_metadata_changes=protected_meta_changes,
        wtr_count=len(wtrs),wtr_source_mat_matches=sum(bool(r['matched_raw_mat']) and not r['matched_raw_mat'].startswith('unknown') for r in wtrs),
        mat_metadata_rows=len(mats),mat_read_errors=sum(r['metadata_read_status']=='unknown' for r in mats),formal_metric_checks=len(metric_checks),formal_metric_checks_passed=sum(r['passed'] for r in metric_checks),formal_metric_max_absolute_diff_m=max(r['absolute_difference_m'] for r in metric_checks),
        proposed_target_collision_groups=len(collisions),actions=dict(Counter(r['action'] for r in matrix)),
        scope='工作树全量元数据前后比对；源码与文档选择性内容复核；33份重点MAT已完整SHA；不声称全盘内容hash或新仿真验证',
    )
    val['passed']=all([val['git_state_identical'],val['working_tree_clean'],not changes,not errors,val['inventory_covers_snapshot'],val['matrix_covers_snapshot'],not field_errors,not val['invalid_actions'],not source_changes,not document_changes,not report_changes,not protected_meta_changes,val['wtr_source_mat_matches']==33,val['mat_read_errors']==0,val['formal_metric_checks_passed']==30])
    (OUT/'AUDIT_VERIFICATION.json').write_text(json.dumps(val,ensure_ascii=False,indent=2),encoding='utf-8')
    summary=json.loads((OUT/'evidence/ENRICHED_SUMMARY.json').read_text())
    dirs=read('DIRECTORY_SUMMARY.csv')
    directory_table='\n'.join(f"| {r['directory']} | {int(r['files']):,} | {int(r['size_bytes'])/1e9:.6f} | {r['tracked_files']} |" for r in dirs[:12])
    role_table='\n'.join(f"| {key} | {count} |" for key,count in summary['roles'].items())
    action_table='\n'.join(f"| {key} | {count:,} |" for key,count in summary['actions'].items())
    important=[b for b in batches if b['record_role'] in {'historical_formal','changeB_formal','1000s_model_regression','precheck','changeB_precheck','50s_precheck','12s_diagnostic_A_B_C','12s_diagnostic_A_F','12s_G_and_alignment_replays','capacity_regression'}]
    key_table='\n'.join(f"| {b['batch_id']} | {b['duration_s']} | {b['gnss_correlation_s']} | {b['raw_L_ref_available_count']} | {b['wtr_count']} | {b['execution_status']} | {b['acceptance_status']} |" for b in important)
    report=f'''# AeroGNC-Sim Phase 1 正式审计报告

日期：2026-11-04。交付目录：`E:/AeroGNC-Phase-Audit/Phase1/`。仓库：`E:/Ducted-Fan-SHC09-matlab`。

**Phase 1只读审计完成。没有进入Phase 2，没有源码/参数/锁/历史报告修改，没有新仿真、迁移、清理、构建、提交、推送、合并、仓库更名或Submodule创建。** 最终完整性检查见[AUDIT_VERIFICATION.json](AUDIT_VERIFICATION.json)。

本文“事实”指本机文件、Git或已保存元数据已核实的内容；“推断”指静态分析关系；“建议”指未来设计，不代表已经授权或执行。

## 1. 当前Git与工作树

**事实：** 分支`debug-ecl-position`，HEAD为`339d7b1a997de6ba350cef3207d8a5b7db3d838d`，跟踪`origin/debug-ecl-position`，工作树干净。审计开始时通过只读ls-remote验证对应远端SHA相同。前后status、HEAD、branch -avv、remote -v、worktree list完全一致。

附件提到“三份README任务外修改尚未提交”，与实际状态不一致：当前HEAD就是Python环境路径文档提交，三份修改已在历史提交中；本轮没有为匹配旧描述回滚、暂存、提交或stash。

共有18个本地分支。`main=9918d9dba180f38a62c36f602e37993b87d0d38d`；`change-B=661a128f1bfeaa6484f1dca3f9dbc489bb1195bc`；当前诊断分支相对main有30个独有提交，main无独有提交。其他研究/历史分支不能因“落后”自动删除，详见[BRANCH_RELATIONS.csv](BRANCH_RELATIONS.csv)。

已存在另一工作树`C:/Users/32450/.codex/worktrees/controller-ppid-p-indi/Ducted-Fan-SHC09-matlab`，分支controller-ppid-p-indi、HEAD `7c5c9ab91fdb310c33d5bf08209e0302e540008f`；本轮仅记录Git元数据，没有递归扫描其内容。origin仍是原GitHub仓库。未来基准和整合分支须阶段2由用户决定。

## 2. 规模与扫描边界

**事实：** 工作树扫描96,300个文件，总计23,625,149,578字节（23.625 GB，十进制），其中1,743个Git跟踪文件全部在场。所有指定顶层目录及根文档/17份Agent报告已纳入。`.git`对象库排除，不跟随junction/symlink到外部；`.venv`和软件bundle纳入元数据规模，未执行其代码。扫描错误0。

| 目录 | 文件数 | GB（十进制） | tracked文件数 |
|---|---:|---:|---:|
{directory_table}

完整目录见[DIRECTORY_SUMMARY.csv](DIRECTORY_SUMMARY.csv)。读取2,249份文本，扫描468份代码形成7,157条静态引用候选；不是完整运行调用覆盖。大文件优先元数据；33份关键原MAT完成全量SHA。没有无意义地反复读取全部23.63 GB。

## 3. Results批次与核心证据

**事实：** [RESULTS_BATCHES.csv](RESULTS_BATCHES.csv)登记247条批次/集合记录，包含从复制回执恢复的179个历史批次身份。存在共享集合、软件构建及汇总，不等于247个互斥数值实验。行间字节数不能直接相加。构成如下：

| 登记角色 | 条数 |
|---|---:|
{role_table}

重点批次如下；原始L/ref数与全部MAT数不同。12秒诊断MAT中cfg可能仍声明55秒，实际窗口以保存时间轴及诊断协议为准。

| 批次 | 时长s | GNSS tau s | 原始L/ref数 | WTR数 | 执行状态 | 验收状态 |
|---|---|---|---:|---:|---|---|
{key_table}

两批正式均为五方法×501/502/503、15条55秒任务，**执行15/15完成，真实恢复0/15通过，估计恢复15/15通过**。两批共享协议ID`HOVER-DISTANCE-TAKEOFF-FORMAL-20261103-v1`，但engine/源码/输入身份不同，不能据ID合并。30份正式原MAT逐一匹配30份WTR；加三个预检，共33/33源MAT完整SHA匹配。

当前98份非构建数值MAT的元数据可读，62份具有L/ref并从已保存真值/参考数组独立复算水平RMSE/峰值。正式30条主任务窗口`15≤t<27`RMSE与原指标交叉检查全部通过，最大绝对差{val['formal_metric_max_absolute_diff_m']:.3g} m，见[FORMAL_METRIC_CROSSCHECK.csv](FORMAL_METRIC_CROSSCHECK.csv)。这属于只读统计复算，不是新仿真，也不证明完整源码重放已就绪。

历史批执行起点为`c381275775b2fe0191eddd663798157864e56780`；change-B批为`1737eee1a309e0fb1bfcf294293b38cc128b1b47`。这些是执行起点角色，不自动等于完整执行源码；冻结驱动、显式锁、MAT来源与工作记录必须一起保留。change-B独立审计的后续基准`f788076ea05d85c62cbeecdf8ba5bef165c3c84d`及当前change-B HEAD也不是该批执行起点。

历史正式批首条DA_NS完成后发生汇总累加器中断；独立续跑只补14条not_run，未重飞已成功条目，后续管理修复另存前后SHA与冻结驱动。`results/hover_distance_takeoff_formal_work_20261103_r1`等管理目录必须与原批关联保留，不能将它们当作无用临时目录。

重点关联已覆盖results原MAT及输入、logs/wtr、历史figures、docs/validation的CSV/PNG/PDF和锁；change-B图主要位于independent_audit目录，未捏造对称figures目录。具体存在性及路径见批次related_paths、FILE_INVENTORY和RUN_IDENTITIES。WTR本轮仅检查目录及manifest/parameters/geometry与源MAT身份，没有宣称所有内嵌flight.mat已独立读取验证。

## 4. GNSS/ECL状态与验收边界

**事实：** 1000 s新模型通过显式版本化入口加载，历史60 s协议/锁/Round 1–7保持原字节。水平每轴总sigma 2.1233045007 m、white 0.35 m、slow 2.0942592969 m；垂直总3.5 m、white 0.6 m、slow 3.4481879299 m；tau三轴1000 s，5 Hz、速度sigma0.08 m/s、延迟100 ms。旧入口仍为历史协议，不是错误待改。

新55 s回归单独位于`results/gnss_1000s_regression_20261104_r1`；协议/锁/图表位于`docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104`，没有WTR。44001状态样本、275次GNSS fresh、550次健康水平融合调用记录在既有证据中。

| 新1000 s回归，全程水平指标 | RMSE m | 其他关键量 |
|---|---:|---|
| 真实跟踪误差 | 0.7819362506 | 峰值1.6291431114；末端1.6164512785 m |
| 任务坐标EKF估计误差 | 0.7881592825 | 与真实飞机比较 |
| 原始世界坐标EKF误差 | 3.7523322801 | 含世界原点/偏置，不与任务坐标混用 |
| 控制器感知跟踪误差 | 0.0663786666 | 不能代替真实跟踪验收 |

原恢复窗[27,37)秒内最小真实水平误差0.4770444895 m，大于原0.2 m半径，满足半径样本0。**模型修正完成、数值执行完成，但真实恢复未通过；不能标记“诊断完成，待整合”或“全部验收通过”。**

历史Round 7完整固定偏置初始化G与零slow的B轨迹达到厘米级差别；F残余受静置历史/ECL收敛影响，不能直接归因恒定偏置。这不推翻旧55秒动态slow漂移机制判断。不同条件RMSE差不能当可加物理贡献。详细边界与加载链见[ARCHITECTURE_AUDIT.md](ARCHITECTURE_AUDIT.md)。

## 5. 数据治理与保留建议

优先保护两批正式30份原MAT、全部33份WTR、输入/协议/锁/执行管理记录，Round 1–7、新GNSS回归和17份历史报告；先确认独立备份，再批准路径迁移。当前外部审计目录只是索引和方案，不是原始结果备份。旧F8/PPID/hover/滤波不少仅剩轻量交付/复制回执，不承诺完整轨迹复算；失败实验仍保留诊断价值。

未来统一采用`results/<study>/<batch_id>/`，按execution_status、acceptance_status、retention_status独立管理，另记raw存在与可复算等级。管理工具默认原址只读/dry-run，以协议SHA、源码、输入签名、方法种子识别，不针对hover硬编码体系。详见[RESULTS_GOVERNANCE_PLAN.md](RESULTS_GOVERNANCE_PLAN.md)。

## 6. 架构、WindTrace与Agent报告

**事实：** 平台链与四环研究链不同，动态注册、分配器白名单ctx与compat仍活跃。源码路径属于来源身份，重排必须新建身份并保存旧锁/原布局，不更新旧锁冒充相同来源。详见架构报告与[DEPENDENCY_EDGES.csv](DEPENDENCY_EDGES.csv)。

**建议：** 主库保留SHC09 MAT导出、科学指标和物理坐标校验；WindTrace保留独立reader/回放/UI/资源与相关测试。writer与UI几何先解耦，合同版本及Submodule固定SHA，再建库。当前v1仍有SHC09七核心topic/六舵约束，不能宣称任意机型通用。旧native/b坐标文档偏差需后续澄清。桌面和开始菜单快捷方式均指向在用apps/windtrace/dist/WindTrace，必须整包备份并验证回退后才可切换。完整方案见[WINDTRACE_SPLIT_PLAN.md](WINDTRACE_SPLIT_PLAN.md)。

**建议：** 17份codex-repo原文与SHA全部保留，未来索引入docs/agent-reports/legacy；CURRENT持续更新同一任务，recent最多5个独立任务，MILESTONES汇总门禁与提交，AGENTS只保留稳定规则，HANDOFF只保留当前状态。迁移表及规则见[AGENT_REPORT_MIGRATION.csv](AGENT_REPORT_MIGRATION.csv)、[AGENT_REPORT_GOVERNANCE.md](AGENT_REPORT_GOVERNANCE.md)。

## 7. 逐文件迁移与精简候选

矩阵及文件索引各96,300行，覆盖全部扫描路径，action仅使用指定五种：

| action | 文件数 |
|---|---:|
{action_table}

117个删除候选限于缓存/临时类，仍需逐文件确认与批准；没有认定可删除的数值模块。68,524个归档候选主要来自历史软件构建/回滚和历史报告，不代表可立即删除或可释放同等唯一数据空间。1,183个迁移候选涉及源码、研究职责及已核实批次归属，冻结锁/路径兼容必须先解决。其余未知结果、环境等保留REVIEW_REQUIRED，不能自动补成功状态。

候选MOVE/ARCHIVE目标重复组：{len(collisions)}，见[TARGET_COLLISIONS.csv](TARGET_COLLISIONS.csv)。即使该项为0，也仍需检查目标既有文件、大小写、MAT内嵌路径与运行加载顺序。矩阵是逐文件建议，不是获批的批量操作脚本。职责目标树与六阶段依赖见[PLAN.md](PLAN.md)。

## 8. 阻塞、阶段2顺序及最终核验

阶段2前需用户确定数值基准/整合候选、原始数据独立备份位置与恢复标准、旧实验归档/删除范围、新验证预算。阶段5另需GitHub更名时机、WindTrace新库可见性/许可/接口发布方式及安装切换；正式删除和提交/推送/合并均需明确清单与授权。详见[RISKS_AND_APPROVALS.md](RISKS_AND_APPROVALS.md)。

推荐顺序：选择基准 → 保护原始证据和在用整包 → 逐文件备份校验及恢复抽查 → 原址登记manifest与三类状态 → 审核unknown与来源缺口 → 批准小批迁移及验证门槛。当前真实恢复失败是后续数值基准的已知状态，不是放宽判据的理由。

末次核验：工作树前后96,300路径、字节数和mtime一致，源码指纹{len(fingerprints)}项及文档指纹{len(docs)}项复核无变化，17份报告原文SHA一致；Git状态完全一致；CSV字段、全量路径覆盖和action枚举通过。33份关键MAT已做全量SHA后与WTR对应，末次以元数据确认未变；没有声称全盘内容hash。详细检查结果为`passed={val['passed']}`。

## 9. 交付导航

必需文件：[PLAN.md](PLAN.md)、[FILE_INVENTORY.csv](FILE_INVENTORY.csv)、[RESULTS_BATCHES.csv](RESULTS_BATCHES.csv)、[MIGRATION_MATRIX.csv](MIGRATION_MATRIX.csv)、[WINDTRACE_SPLIT_PLAN.md](WINDTRACE_SPLIT_PLAN.md)、[RISKS_AND_APPROVALS.md](RISKS_AND_APPROVALS.md)、本报告。

补充：架构、Results治理、Agent治理三份说明；目录规模、依赖候选、锁引用、MAT元数据、WTR身份、原始数据SHA、历史复制回执、分支关系、环境包及EXE索引；原始Git证据、范围/错误记录和只读审计脚本。交付文件hash索引见[OUTPUT_MANIFEST.json](OUTPUT_MANIFEST.json)。

Phase 1完成后停止；Phase 2及以后均未实施。
'''
    (OUT/'PHASE1_REPORT.md').write_text(report,encoding='utf-8')
    print(json.dumps(val,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
