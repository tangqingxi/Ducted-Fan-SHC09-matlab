"""完善外部审计清单：实际与计划分开、补充轻量历史批次、生成文件级目标映射。"""
from pathlib import Path
from collections import defaultdict,Counter
import csv
import hashlib
import json
import re

ROOT=Path(r'E:\Ducted-Fan-SHC09-matlab')
OUT=Path(__file__).resolve().parents[1]
FILES=json.loads((OUT/'evidence/FILE_METADATA.json').read_text())
FM={r['path']:r for r in FILES}


def read(name):
    with (OUT/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))


def csvread(path):
    try:
        with (ROOT/path).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
    except (OSError,UnicodeError,csv.Error):return []


def jread(path):
    try:return json.loads((ROOT/path).read_text(encoding='utf-8-sig'))
    except (OSError,ValueError):return {}


def write(name,rows,fields=None):
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields or list(rows[0]));w.writeheader();w.writerows(rows)


def under(folder):
    return [p for p in FM if p.startswith(folder.rstrip('/')+'/')]


def main():
    batches=read('RESULTS_BATCHES.csv');mats=read('MAT_METADATA.csv');wtrs=read('WTR_INDEX.csv')
    hashes=read('KEY_ARTIFACT_HASHES.csv');extras=[]
    by_anchor={r['batch_id']:r for r in batches}
    for row in batches:
        folders=row['related_paths'].split(';');owned={p for folder in folders for p in under(folder)}
        actual=[m for m in mats if m['path'] in owned and m['has_L']=='True']
        actual_status=[]
        for p in owned:
            if Path(p).name in {'status.csv','metrics.csv','summary.csv','task_metrics.csv'}:actual_status.extend(csvread(p))
        methods={m['saved_method'] for m in actual if m['saved_method']!='unknown'}
        seeds={m['saved_seed'] for m in actual if m['saved_seed']!='unknown'}
        if not methods:methods={s['method'] for s in actual_status if s.get('method')}
        if not seeds:seeds={s['seed'] for s in actual_status if s.get('seed')}
        row['planned_methods']=row['methods'];row['planned_seeds']=row['seeds']
        row['methods']=';'.join(sorted(methods)) or 'unknown';row['seeds']=';'.join(sorted(seeds)) or 'unknown'
        row['observed_scope']='saved_L_metadata_or_existing_status_metrics;planned_values_separate'
        if row['record_role'] in {'audit_or_summary_collection','software_build_or_rollback'}:
            row['methods']=row['seeds']=row['duration_s']='unknown'
        if row['record_role']=='capacity_regression':row['duration_s']=';'.join(sorted({m['actual_last_time_s'] for m in actual if m['actual_last_time_s']!='unknown'}))
        if row['study']=='unknown' and row['batch_id']=='audit_changeB_20261104':
            row['study']='ecl_navigation';row['record_role']='round1_to4_saved_short_diagnostic';row['acceptance_status']='diagnostic_evidence_only;not_formal_task_acceptance'
        if row['study']=='unknown' and row['batch_id']=='windtrace_ui_20261103':row['study']='windtrace_artifacts';row['record_role']='software_ui_validation'
    # 预检按保存日志、源SHA与WTR关联，不能把共享协议中的五方法三种子当已执行。
    for w in wtrs:
        if not w['matched_raw_mat'].startswith('unknown'):continue
        source_dir={
            'final_precheck_20261103_r1':'hover_distance_takeoff_final_precheck_20261103_r1',
            'final_precheck_changeB_20261104_r1':'hover_distance_takeoff_final_precheck_changeB_20261104_r1',
            'precheck_20261103_r1':'hover_distance_takeoff_precheck_20261103_r1'}.get(Path(w['path']).parent.name)
        if not source_dir:continue
        candidates=[m['path'] for m in mats if m['path'].startswith('results/'+source_dir+'/') and Path(m['path']).name==w['source_filename']]
        for p in candidates:
            h=hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
            hashes.append(dict(path=p,sha256=h,size_bytes=FM[p]['size_bytes'],reason='precheck MAT identity cross-check against WTR source manifest'))
            if h==w['source_mat_sha256']:w['matched_raw_mat']=p
    write('WTR_INDEX.csv',wtrs);write('KEY_ARTIFACT_HASHES.csv',hashes)
    # 从保存的复制收据恢复旧批次身份，不只依赖归档文件夹名称。
    origins=defaultdict(list)
    for receipt in ['results/current_summaries/copied_files.json','results/f8_reference_20261101/copied_files.json']:
        data=jread(receipt)
        rows=data.get('files',[]) if isinstance(data,dict) else data
        if not isinstance(rows,list):continue
        for item in rows:
            if not isinstance(item,dict):continue
            source=str(item.get('source','')).replace('\\','/');dest=str(item.get('destination','')).replace('\\','/')
            if source.startswith('results/') and dest in FM and len(Path(source).parts)>2:
                origins[Path(source).parts[1]].append((source,dest,receipt,item.get('sha256','unknown')))
    identity_links=[]
    for batch,items in sorted(origins.items()):
        destinations=sorted({x[1] for x in items});owned=set(destinations)
        if batch in by_anchor:
            for source,dest,receipt,digest in items:identity_links.append(dict(batch_id=batch,source_historical_path=source,retained_destination=dest,receipt=receipt,recorded_sha256=digest))
            continue
        protocol_paths=[p for p in destinations if 'protocol' in Path(p).name and p.endswith('.json')]
        source_paths=[p for p in destinations if any(k in Path(p).name for k in ['sources','lock','status','provenance'])]
        csvrows=[]
        for p in destinations:
            if p.endswith('.csv') and Path(p).name in {'status.csv','task_metrics.csv','summary.csv','metrics.csv','trials.csv'}:csvrows.extend(csvread(p))
        methods=sorted({x['method'] for x in csvrows if x.get('method')});seeds=sorted({x['seed'] for x in csvrows if x.get('seed')})
        statuses=Counter(x['status'] for x in csvrows if x.get('status'))
        acceptance='unknown'
        if any('task_passed' in x for x in csvrows):
            passed=sum(str(x.get('task_passed','')).lower() in {'1','true'} for x in csvrows);n=sum('task_passed' in x for x in csvrows)
            acceptance=f'recorded_task_passed={passed}/{n};raw_currently_absent'
        duration=set();protocol_ids=[]
        for path in protocol_paths:
            obj=jread(path)
            if isinstance(obj,dict):
                if isinstance(obj.get('duration_s'),(int,float)):duration.add(str(obj['duration_s']))
                if obj.get('id'):protocol_ids.append(str(obj['id']))
        study='historical_study_owner_unknown'
        if any('ppid_pindi' in p for p in destinations):study='ppid_pindi'
        elif any('hover_distance' in p for p in destinations):study='hover_distance'
        elif any('f8_reference_20261101' in p for p in destinations):study='f8'
        row=dict(study=study,batch_id=batch,protocol=';'.join(protocol_paths) or 'unknown',source_commit='unknown',methods=';'.join(methods) or 'unknown',seeds=';'.join(seeds) or 'unknown',
                 duration_s=';'.join(sorted(duration)) or 'unknown',execution_status=';'.join(f'{k}={v}' for k,v in statuses.items()) or 'unknown',acceptance_status=acceptance,
                 retention_status='lightweight_only_copied_receipt;original_raw_absent_at_original_path',raw_mat_available='False',wtr_available='False',metrics_available=any(p.endswith('.csv') for p in destinations),
                 lock_available=any('lock' in Path(p).name for p in destinations),total_size_bytes=sum(FM[p]['size_bytes'] for p in owned),related_paths=';'.join(destinations),
                 recommended_action='保留收据/SHA/失败状态；仅剩轻量证据，不宣称可恢复原MAT或完整重放',record_role='historical_batch_recovered_from_copy_receipt',raw_mat_count=0,wtr_count=0,gnss_correlation_s='unknown',raw_L_ref_available_count=0,
                 independent_recompute='lightweight_metrics_only;raw_not_found_current_tree',commit_role_and_evidence='unknown;receipt retains original paths',identity_evidence=';'.join(sorted({x[2] for x in items})+source_paths),
                 planned_methods='unknown',planned_seeds='unknown',observed_scope='preserved_copy_receipt_and_existing_rows_only')
        batches.append(row);by_anchor[batch]=row
        for source,dest,receipt,digest in items:identity_links.append(dict(batch_id=batch,source_historical_path=source,retained_destination=dest,receipt=receipt,recorded_sha256=digest))
    write('HISTORICAL_BATCH_PATH_LINKS.csv',identity_links,['batch_id','source_historical_path','retained_destination','receipt','recorded_sha256'])
    write('RESULTS_BATCHES.csv',batches)
    # 单独列出实际30条正式飞行，避免批次聚合掩盖方法、种子和输入身份。
    identities=[]
    for w in wtrs:
        identities.append(dict(batch_id=Path(w['path']).parent.name,method=w['method'],seed=w['seed'],duration_s=w['duration_s'],scenario=w['scenario'],engine=w['engine'],input_signature=w['input_signature'],
             source_mat=w['matched_raw_mat'],source_mat_sha256=w['source_mat_sha256'],wtr=w['path'],gnss_correlation_s=w['gnss_correlation_s'],execution_status=w['execution_status'],acceptance_status='unknown_from_WTR_alone;see_batch_metrics'))
    write('RUN_IDENTITIES.csv',identities)
    # 记录当前层叠模型/控制职责的候选目标，冻结路径依然要求独立批准和回归。
    matrix=read('MIGRATION_MATRIX.csv')
    for row in matrix:
        path=row['current_path']
        if path.startswith('platform/modules/'):
            rest=path.removeprefix('platform/modules/');kind=rest.split('/')[0]
            group='src/sensors/' if kind=='sensors' else 'src/navigation/' if kind=='estimator' else 'src/allocation/interface/' if kind=='control_allocator' else 'src/control/'
            row['target_path']=group+rest
        elif path.startswith('modules/state_estimator/px4_ecl/'):
            row['target_path']='src/navigation/px4_ecl/'+path.removeprefix('modules/state_estimator/px4_ecl/')
        elif path.startswith('modules/control_allocator/'):
            row['target_path']='src/allocation/interface/'+path.removeprefix('modules/control_allocator/')
        elif path in {'research/ppid_pindi/ppid_control_step.m','research/ppid_pindi/ppid_simulate.m','research/ppid_pindi/ppid_noise.m','research/ppid_pindi/ppid_sensor_step.m','research/ppid_pindi/ppid_estimator_init.m'}:
            group={'ppid_control_step.m':'src/control/ppid/','ppid_simulate.m':'src/runtime/sim/','ppid_noise.m':'src/sensors/','ppid_sensor_step.m':'src/sensors/','ppid_estimator_init.m':'src/navigation/'}[Path(path).name]
            row['target_path']=group+Path(path).name;row['compatibility_risk']='high';row['verification_required']+='；旧源码路径以冻结快照保留，不把搬迁后的新fingerprint追认为旧引擎'
        if row['action']=='REVIEW_REQUIRED' and path.startswith(('results/','logs/','figures/','examples/')):
            anchors=[b for b in batches if b['record_role'] in {'historical_formal','changeB_formal','1000s_model_regression','precheck','changeB_precheck','50s_precheck','12s_diagnostic_A_B_C','12s_diagnostic_A_F','12s_G_and_alignment_replays'} and any(path.startswith(k.rstrip('/')+'/') for k in b['related_paths'].split(';'))]
            if len(anchors)==1:
                b=anchors[0];old_anchor=next(k for k in b['related_paths'].split(';') if path.startswith(k.rstrip('/')+'/'))
                role='raw' if old_anchor.startswith('results/') else 'wtr' if old_anchor.startswith('logs/') else 'figures' if old_anchor.startswith('figures/') else 'evidence'
                row['target_path']=f"results/{b['study']}/{b['batch_id']}/{role}/"+path[len(old_anchor.rstrip('/'))+1:]
                row['action']='MOVE_CANDIDATE'
    write('MIGRATION_MATRIX.csv',matrix)
    # 清单中的实验文件分类也同步到已核实的批次关联，不改动仓库文件。
    inv=read('FILE_INVENTORY.csv');by_mig={m['current_path']:m for m in matrix};rawset={m['path'] for m in mats if m['has_L']=='True'}
    for row in inv:
        if row['path'] in rawset:row['category']='原始实验MAT';row['retention_class']='protect_unique_raw_run'
        if row['path'].endswith('.wtr') and row['path'].startswith('logs/wtr/'):
            row['category']='单飞行自包含WTR';row['retention_class']='protect_delivery_container'
        row['proposed_action']=by_mig[row['path']]['action']
    write('FILE_INVENTORY.csv',inv)
    summary=dict(records=len(batches),roles=dict(Counter(r['record_role'] for r in batches)),run_identities=len(identities),wtr_source_mat_hash_matches=sum(not w['matched_raw_mat'].startswith('unknown') for w in wtrs),
                 raw_runs_with_saved_L=sum(m['has_L']=='True' for m in mats),raw_runs_with_L_ref_recomputed=sum(m['metrics_recomputed_from_L_ref']=='True' for m in mats),historical_receipt_batches=sum(r['record_role']=='historical_batch_recovered_from_copy_receipt' for r in batches),
                 actions=dict(Counter(m['action'] for m in matrix)))
    (OUT/'evidence/ENRICHED_SUMMARY.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))


if __name__=='__main__':main()
