"""读取已有协议、来源、MAT元数据和WTR清单；不运行仿真或导出程序。"""
from pathlib import Path
from collections import defaultdict,Counter
import csv
import hashlib
import json
import re
import subprocess
import zipfile
import numpy as np
from scipy.io import loadmat,whosmat

ROOT=Path(r'E:\Ducted-Fan-SHC09-matlab')
OUT=Path(__file__).resolve().parents[1]
FILES=json.loads((OUT/'evidence/FILE_METADATA.json').read_text())
FM={r['path']:r for r in FILES}
HASHES={}


def sha(rel):
    if rel not in HASHES:
        h=hashlib.sha256()
        with (ROOT/rel).open('rb') as f:
            for b in iter(lambda:f.read(1048576),b''):h.update(b)
        HASHES[rel]=h.hexdigest()
    return HASHES[rel]


def write(name,rows,fields=None):
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields or list(rows[0]));w.writeheader();w.writerows(rows)


def jread(rel):
    try:return json.loads((ROOT/rel).read_text(encoding='utf-8-sig'))
    except (ValueError,OSError):return {}


def cread(rel):
    try:
        with (ROOT/rel).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
    except (OSError,UnicodeError,csv.Error):return []


def paths_under(prefix):
    return [p for p in FM if p==prefix or p.startswith(prefix.rstrip('/')+'/')]


def scalar(x):
    if x is None:return 'unknown'
    if isinstance(x,(str,int,float,bool)):return x
    if isinstance(x,np.generic):return x.item()
    if isinstance(x,np.ndarray) and x.size==1 and x.dtype.names is None:
        try:return scalar(x.item())
        except ValueError:return 'unknown'
    return 'unknown'


def get(d,*keys):
    for k in keys:
        if not isinstance(d,dict):return None
        d=d.get(k)
    return d


def main():
    mats={};matrows=[];wtrs=[];wtr_detail={}
    for rel in FM:
        if not rel.startswith('results/') or '/windtrace_' in rel or not rel.endswith('.mat'):continue
        try:
            try:
                variables=whosmat(ROOT/rel);names=[v[0] for v in variables]
            except Exception:
                names=[]
            d=loadmat(ROOT/rel,simplify_cells=True,variable_names=['cfg','plan','spec','seed','cond','metrics','checks','signature'])
            raw=loadmat(ROOT/rel,simplify_cells=True,variable_names=['L','ref'])
            names=list(dict.fromkeys(names+[k for k in d if not k.startswith('__')]+[k for k in raw if not k.startswith('__')]))
            log=raw.get('L',{});reference=raw.get('ref',{})
            ts=np.asarray(log.get('time_s',[])).reshape(-1) if isinstance(log,dict) else np.array([])
            can_recompute=isinstance(log,dict) and isinstance(reference,dict) and 'position' in log and 'position_ned_m' in reference
            rmse='unknown';peak='unknown';main_rmse='unknown'
            if can_recompute:
                error=np.asarray(log['position'])[:,:2]-np.asarray(reference['position_ned_m'])[:,:2]
                distance=np.linalg.norm(error,axis=1);rmse=float(np.sqrt(np.mean(distance**2)));peak=float(np.max(distance))
                if len(ts)==len(distance) and ts[-1]>=27:
                    q=(ts>=15)&(ts<27);main_rmse=float(np.sqrt(np.mean(distance[q]**2)))
            item=dict(path=rel,size_bytes=FM[rel]['size_bytes'],variables=';'.join(names),
                      saved_seed=scalar(d.get('seed') or get(d,'cfg','navigation_seed')),
                      configured_duration_s=scalar(get(d,'cfg','duration_s')),
                      gnss_correlation_s=scalar(get(d,'plan','sensors','gnss_correlation_s')),
                      gnss_model_id=scalar(get(d,'plan','gnss_model','id')),plan_id=scalar(get(d,'plan','id')),
                      condition=scalar(d.get('cond')),has_L='L' in names,has_ref='ref' in names,
                      metadata_read_status='saved_metadata_and_raw_identity_read_only',note='只读已有L/ref识别实际执行窗口及复算误差，不运行对象积分',
                      saved_method=scalar(log.get('name')) if isinstance(log,dict) else 'unknown',actual_last_time_s=float(ts[-1]) if len(ts) else 'unknown',
                      actual_state_samples=len(ts),metrics_recomputed_from_L_ref=can_recompute,true_horizontal_rmse_m=rmse,true_horizontal_peak_m=peak,main_15_27_true_rmse_m=main_rmse)
            mats[rel]=item
        except Exception as e:
            item=dict(path=rel,size_bytes=FM[rel]['size_bytes'],variables='unknown',saved_seed='unknown',configured_duration_s='unknown',
                      gnss_correlation_s='unknown',gnss_model_id='unknown',plan_id='unknown',condition='unknown',has_L='unknown',has_ref='unknown',metadata_read_status='unknown',note=str(e),
                      saved_method='unknown',actual_last_time_s='unknown',actual_state_samples=0,metrics_recomputed_from_L_ref=False,true_horizontal_rmse_m='unknown',true_horizontal_peak_m='unknown',main_15_27_true_rmse_m='unknown')
            mats[rel]=item
        matrows.append(item)
    write('MAT_METADATA.csv',matrows)
    # 只对重点正式飞行原始MAT做完整SHA，用于与WTR源身份交叉验证。
    primary=['hover_distance_takeoff_formal_20261103_r1','hover_distance_takeoff_formal_changeB_20261104_r1']
    raw_by_name=defaultdict(list)
    for rel,item in mats.items():
        if any(rel.startswith('results/'+b+'/logs/') for b in primary) and item['has_L'] is True:
            raw_by_name[Path(rel).name].append(rel);sha(rel)
    for rel in FM:
        if not rel.startswith('logs/wtr/') or not rel.endswith('.wtr'):continue
        try:
            with zipfile.ZipFile(ROOT/rel) as z:
                m=json.loads(z.read('manifest.json'));g=json.loads(z.read('geometry.json'))
                params=json.loads(z.read('parameters.json'))
                tau=next((x.get('value') for x in params.get('entries',[]) if x.get('path','').endswith('gnss_correlation_s')),'unknown')
                members=z.namelist()
            source=m.get('source',{});hashvalue=source.get('log_sha256','unknown');filename=source.get('filename','unknown')
            matches=[p for p in raw_by_name.get(filename,[]) if HASHES[p]==hashvalue]
            row=dict(path=rel,schema=m.get('schema','unknown'),run_id=m.get('run_id','unknown'),method=m.get('method','unknown'),seed=m.get('seed','unknown'),
                     scenario=m.get('scenario','unknown'),duration_s=m.get('duration_s','unknown'),execution_status=get(m,'execution','status') or 'unknown',
                     source_filename=filename,source_mat_sha256=hashvalue,matched_raw_mat=';'.join(matches) or 'unknown_not_primary_mat_hash_checked',
                     engine=source.get('engine','unknown'),input_signature=source.get('input_signature','unknown'),
                     gnss_correlation_s=tau,geometry_frame=g.get('frame','unknown'),zip_members=';'.join(members),
                     size_bytes=FM[rel]['size_bytes'],inspection_scope='manifest/parameters/geometry only; flight.mat member not loaded')
            wtr_detail[rel]=m
        except Exception as e:
            row=dict(path=rel,schema='unknown',run_id='unknown',method='unknown',seed='unknown',scenario='unknown',duration_s='unknown',execution_status='unknown',
                     source_filename='unknown',source_mat_sha256='unknown',matched_raw_mat='unknown',engine='unknown',input_signature='unknown',gnss_correlation_s='unknown',geometry_frame='unknown',zip_members='unknown',size_bytes=FM[rel]['size_bytes'],inspection_scope=str(e))
        wtrs.append(row)
    write('WTR_INDEX.csv',wtrs)
    (OUT/'evidence/WTR_METADATA_SUMMARY.json').write_text(json.dumps(wtrs,indent=2,ensure_ascii=False),encoding='utf-8')
    batch_rows=[];known_related=set();batch_map={}
    special={
      'hover_distance_takeoff_formal_20261103_r1':dict(study='hover_distance_takeoff_formal',role='historical_formal',related=['logs/wtr/hover_distance_takeoff_formal_20261103_r1','figures/hover_distance_takeoff_formal_20261103_r1','docs/validation/hover_distance_takeoff_formal_20261103_r1'],work='results/hover_distance_takeoff_formal_work_20261103_r1'),
      'hover_distance_takeoff_formal_changeB_20261104_r1':dict(study='hover_distance_takeoff_formal',role='changeB_formal',related=['logs/wtr/hover_distance_takeoff_formal_changeB_20261104_r1','docs/validation/shc09_b_frame_20261104/formal_changeB_20261104_r1','docs/validation/shc09_b_frame_20261104/independent_audit_20261104'],work='results/hover_distance_takeoff_formal_work_changeB_20261104_r1'),
      'hover_distance_takeoff_final_precheck_20261103_r1':dict(study='hover_distance_takeoff_formal',role='precheck',related=['logs/wtr/final_precheck_20261103_r1']),
      'hover_distance_takeoff_final_precheck_changeB_20261104_r1':dict(study='hover_distance_takeoff_formal',role='changeB_precheck',related=['logs/wtr/final_precheck_changeB_20261104_r1','docs/validation/shc09_b_frame_20261104/precheck_changeB_20261104_r1']),
      'hover_distance_takeoff_precheck_20261103_r1':dict(study='hover_distance_takeoff',role='50s_precheck',related=['logs/wtr/precheck_20261103_r1','figures/hover_distance_takeoff_precheck_20261103_r1']),
      'gnss_1000s_regression_20261104_r1':dict(study='ecl_navigation',role='1000s_model_regression',related=['docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104']),
      'round5_changeB_20261104':dict(study='ecl_navigation',role='12s_diagnostic_A_B_C',related=['docs/validation/shc09_b_frame_20261104/round5_gnss_slow_20261104']),
      'round6_changeB_20261104':dict(study='ecl_navigation',role='12s_diagnostic_A_F',related=['docs/validation/shc09_b_frame_20261104/round6_gnss_bias_drift_20261104']),
      'round7_changeB_20261104':dict(study='ecl_navigation',role='12s_G_and_alignment_replays',related=['docs/validation/shc09_b_frame_20261104/round7_fixed_bias_init_20261104']),
      'ppid_capacity_fix_20261103_r1':dict(study='ppid_capacity',role='capacity_regression',related=['docs/validation/ppid_capacity_fix_20261103']),
      'f8_reference_20261101':dict(study='f8',role='retained_lightweight_reference',related=['examples/f8_comparison_20261101']),
    }
    anchors=sorted({ '/'.join(Path(p).parts[:2]) for p in FM if p.startswith('results/') and len(Path(p).parts)>2 })
    # 将仍存在但原始results已清理的轻量研究交付单独列出，不假装其MAT仍然存在。
    extras=sorted({'/'.join(Path(p).parts[:2]) for p in FM if p.startswith('examples/') and len(Path(p).parts)>2 and not p.startswith('examples/f8_comparison_20261101/')})
    for anchor in anchors+extras:
        batch=Path(anchor).name;spec=special.get(batch,{})
        role=spec.get('role','unknown');study=spec.get('study','unknown')
        if batch.startswith(('windtrace_app_','windtrace_build_')):role='software_build_or_rollback';study='windtrace_artifacts'
        elif batch in {'current_summaries','validation','f8_work_20261101','cleanup_20261104'}:role='audit_or_summary_collection'
        elif 'formal_work' in batch or batch.endswith('_work_20261103_r1'):role='execution_management_evidence';study='hover_distance_takeoff_formal'
        related=[anchor]+[p for p in spec.get('related',[]) if paths_under(p)]
        owned=set(p for folder in related for p in paths_under(folder));known_related.update(related)
        ownm=[mats[p] for p in owned if p in mats];raw=[m for m in ownm if m['has_L'] is True];ownw=[x for x in wtrs if x['path'] in owned]
        completion=jread(anchor+'/completion.json');status=cread(anchor+'/status.csv');metrics=cread(anchor+'/metrics.csv')
        if not metrics:
            metrics=next((cread(p) for p in sorted(owned) if p.endswith('/tables/metrics.csv') or p.endswith('/original_scene_metrics.csv')),[])
        protocols=[p for p in owned if p.endswith(('/formal_protocol.json','/protocol.json','/regression_protocol.json')) or p.endswith('_conditions.json')]
        saved_protocols=[(p,jread(p)) for p in protocols]
        durations=set();methods=set();seeds=set();taus=set();commits=set();commit_evidence=[]
        for p,m in saved_protocols:
            for key in ('duration_s',):
                value=m.get(key)
                if isinstance(value,(int,float)):durations.add(value)
            for key in ('methods',):
                if isinstance(m.get(key),list):methods.update(str(v) for v in m[key])
            if isinstance(m.get('method'),str):methods.add(m['method'])
            for key in ('seeds','formal_seeds'):
                if isinstance(m.get(key),list):seeds.update(str(v) for v in m[key])
            if isinstance(m.get('seed'),(int,float)):seeds.add(str(m['seed']))
            if 'base_commit' in m:commits.add(m['base_commit']);commit_evidence.append(p+':base_commit (baseline, not automatically exact execution source)')
        for m in ownm:
            if m['gnss_correlation_s']!='unknown':taus.add(str(m['gnss_correlation_s']))
            if m['saved_seed']!='unknown':seeds.add(str(m['saved_seed']))
            if m['saved_method']!='unknown':methods.add(str(m['saved_method']))
        for row in status+metrics:
            if row.get('method'):methods.add(row['method'])
            if row.get('seed'):seeds.add(row['seed'])
        for w in ownw:
            methods.add(str(w['method']));seeds.add(str(w['seed']));durations.add(w['duration_s'])
        work=spec.get('work',anchor)
        for p in paths_under(work):
            if not p.endswith('.json') or not any(k in Path(p).name for k in ('git','start')):continue
            m=jread(p);head=m.get('head') or m.get('HEAD')
            if isinstance(head,str) and re.fullmatch('[0-9a-f]{40}',head):commits.add(head);commit_evidence.append(p+':head (execution start)')
        if role=='12s_G_and_alignment_replays':durations={12};methods={'PCA_PREDICTIVE'};seeds={'501','502','503'}
        if role=='1000s_model_regression':
            methods={'PCA_PREDICTIVE'};seeds={'501'};durations={55};taus={'1000'}
        if completion.get('completed') is not None:
            execution=f"completed={completion.get('completed')};failed={completion.get('failed','unknown')};requested={completion.get('requested','unknown')}"
        elif status:
            execution=';'.join(f'{k}={v}' for k,v in Counter(r.get('status','unknown') for r in status).items())
        elif role=='1000s_model_regression':
            v=jread(next(p for p in owned if p.endswith('/verification.json')));execution='completed_55s_single_run' if v.get('full_55s_complete') else 'unknown'
        elif role=='software_build_or_rollback':execution='not_applicable_software_artifact'
        elif role.startswith('12s_'):execution='saved_raw_'+str(len(raw))+';see_execution_log_for_run_vs_alignment_split'
        else:execution='unknown'
        if metrics and all('true_recovery_not_reached' in r for r in metrics):
            nr=sum(str(r['true_recovery_not_reached']).lower() in {'1','true'} for r in metrics)
            acceptance=f'true_recovery_failed={nr}/{len(metrics)};execution_completion_is_separate'
        elif role=='1000s_model_regression':acceptance='true_recovery_failed;ready_for_integration=false'
        elif role.startswith('12s_'):acceptance='diagnostic_evidence_only;task_recovery_acceptance_not_defined'
        elif role=='software_build_or_rollback':acceptance='unknown_software_validation_per_snapshot'
        else:acceptance='unknown'
        if not durations and raw:
            values={str(m['actual_last_time_s']) for m in raw if m['actual_last_time_s']!='unknown'}
            if len(values)==1 and not role.startswith('12s_'):durations=set(values)
        if anchor.startswith('examples/'):
            role='lightweight_delivery_without_raw_in_this_folder'
            study=study if study!='unknown' else batch
        if study=='unknown' and protocols:
            study='protocol_defined_study_pending_owner_label'
        locked=[p for p in owned if p.endswith('.json') and 'lock' in Path(p).name]
        metrics_paths=[p for p in owned if p.endswith('.csv') and any(k in Path(p).name for k in ('metrics','summary','recovery','status'))]
        retention='retain_raw_and_all_provenance' if raw else 'retain_lightweight_evidence;raw_missing_or_not_applicable'
        if role=='software_build_or_rollback':retention='review_rollback_need;not_numeric_experiment'
        action='保留；Phase4按已验证身份迁入results/<study>/<batch_id>；源锁/历史相对路径单独解决'
        if not raw and role!='software_build_or_rollback':action='保留轻量证据；核查原始日志是否已按历史清理清单删除，不能承诺完整复算'
        if role=='software_build_or_rollback':action='先确认当前EXE和独立回滚备份；候选归档至软件artifacts，未授权删除'
        row=dict(study=study,batch_id=batch,protocol=';'.join(sorted(protocols)) or 'unknown',source_commit=';'.join(sorted(commits)) or 'unknown',
                 methods=';'.join(sorted(methods)) or 'unknown',seeds=';'.join(sorted(seeds)) or 'unknown',duration_s=';'.join(sorted(str(x) for x in durations)) or 'unknown',
                 execution_status=execution,acceptance_status=acceptance,retention_status=retention,raw_mat_available=bool(raw),wtr_available=bool(ownw),
                 metrics_available=bool(metrics_paths),lock_available=bool(locked),total_size_bytes=sum(FM[p]['size_bytes'] for p in owned),
                 related_paths=';'.join(related),recommended_action=action,record_role=role,raw_mat_count=len(raw),wtr_count=len(ownw),
                 gnss_correlation_s=';'.join(sorted(taus)) or 'unknown',raw_L_ref_available_count=sum(m['has_ref'] is True for m in raw),
                 independent_recompute='saved_L_and_ref_available;historical_source_replay_requires_resolution' if raw and all(m['has_ref'] is True for m in raw) else 'unknown_or_lightweight_only',
                 commit_role_and_evidence=';'.join(commit_evidence) or 'unknown',identity_evidence=';'.join(sorted(set(protocols+locked+[p for p in owned if p.endswith(('/status.csv','/provenance.csv'))]))) or 'unknown')
        batch_rows.append(row);batch_map[batch]=related
    # 未被主批次覆盖的验证证据也纳入索引，明确它们不是新的完整飞行批次。
    for anchor in sorted({'/'.join(Path(p).parts[:3]) for p in FM if p.startswith('docs/validation/') and len(Path(p).parts)>3}):
        if any(anchor==k or anchor.startswith(k+'/') for k in known_related):continue
        if anchor=='docs/validation/shc09_b_frame_20261104':
            candidates=sorted({'/'.join(Path(p).parts[:4]) for p in paths_under(anchor) if len(Path(p).parts)>4})
        else:candidates=[anchor]
        for folder in candidates:
            if folder in known_related:continue
            owned=paths_under(folder)
            batch_rows.append(dict(study='validation_evidence',batch_id=Path(folder).name,protocol='unknown',source_commit='unknown',methods='unknown',seeds='unknown',duration_s='unknown',execution_status='unknown;read_only_evidence_collection',acceptance_status='unknown;read_report',retention_status='retain_diagnostic_evidence',raw_mat_available=False,wtr_available=False,metrics_available=any(p.endswith('.csv') for p in owned),lock_available=any('lock' in Path(p).name for p in owned),total_size_bytes=sum(FM[p]['size_bytes'] for p in owned),related_paths=folder,recommended_action='保留并绑定对应研究；不由验证目录名称推断新飞行',record_role='validation_collection',raw_mat_count=0,wtr_count=0,gnss_correlation_s='unknown',raw_L_ref_available_count=0,independent_recompute='unknown',commit_role_and_evidence='unknown',identity_evidence=';'.join(p for p in owned if p.endswith('.md') or 'protocol' in Path(p).name)))
    write('RESULTS_BATCHES.csv',batch_rows)
    (OUT/'evidence/BATCH_ASSOCIATIONS.json').write_text(json.dumps(batch_map,indent=2),encoding='utf-8')
    write('KEY_ARTIFACT_HASHES.csv',[dict(path=p,sha256=h,size_bytes=FM[p]['size_bytes'],reason='primary formal MAT identity cross-check against WTR source manifest') for p,h in sorted(HASHES.items())],['path','sha256','size_bytes','reason'])
    summary=dict(records=len(batch_rows),roles=dict(Counter(r['record_role'] for r in batch_rows)),mat_metadata_files=len(matrows),
                 wtr_manifests_inspected=len(wtrs),primary_mat_hashes=len(HASHES),primary_wtr_mat_matches=sum(bool(w['matched_raw_mat'].startswith('results/hover_distance_takeoff_formal')) for w in wtrs),
                 primary_formal_rows=[r for r in batch_rows if r['record_role'] in {'historical_formal','changeB_formal','1000s_model_regression'}])
    (OUT/'evidence/RESULTS_SUMMARY.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps({k:v for k,v in summary.items() if k!='primary_formal_rows'}))


if __name__=='__main__':main()
