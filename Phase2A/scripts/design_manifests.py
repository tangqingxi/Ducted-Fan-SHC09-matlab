"""生成Results合同设计和两个真实证据示例，仅写入审计仓库。"""
from pathlib import Path
import csv
import json

OUT=Path(__file__).resolve().parents[1]
AUDIT=OUT.parent
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')


def dump(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')


def rows(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))


def obj(properties,required=None):
    return dict(type='object',properties=properties,required=required if required is not None else list(properties),additionalProperties=False)


def arr(items,minimum=0):return dict(type='array',items=items,minItems=minimum)
def ref(name):return {'$ref':'#/$defs/'+name}
def enum(*values):return dict(type='string',enum=list(values))


def main():
    text=dict(type='string',minLength=1)
    optional_text=dict(type=['string','null'],minLength=1)
    sha=dict(type='string',pattern='^[a-f0-9]{64}$')
    commit=dict(type=['string','null'],pattern='^[a-f0-9]{40}$')
    identity=dict(type='string',pattern='^[a-zA-Z0-9][a-zA-Z0-9_.-]*$')
    path=dict(type='string',pattern=r'^(?!/)(?![A-Za-z]:)(?!.*\\)(?!.*(?:^|/)\.\.(?:/|$))[^\x00]+$')
    execution=enum('planned','running','interrupted','completed','partial','failed','unknown')
    acceptance=enum('not_evaluated','passed','failed','partial','not_applicable','unknown')
    retention=enum('KEEP_ACTIVE','KEEP_EVIDENCE','ARCHIVE_CANDIDATE','DELETE_CANDIDATE','REVIEW_REQUIRED')
    defs={
        'locator':obj(dict(root_id=identity,path=path)),
        'duration':obj(dict(planned_s=dict(type=['number','null'],minimum=0),observed_s=dict(type=['number','null'],minimum=0))),
        'artifact':obj(dict(artifact_id=identity,role=text,locator=ref('locator'),size_bytes=dict(type=['integer','null'],minimum=0),sha256=dict(type=['string','null'],pattern='^[a-f0-9]{64}$'),availability=enum('present','archived','missing','unknown'),hash_verification=enum('current_bytes_hashed','metadata_matched_prior_full_hash','not_verified'),git_tracking=enum('tracked','local_only','unknown'),run_id=optional_text,legacy_locations=arr(ref('locator')))),
        'check':obj(dict(criterion=text,status=acceptance,evidence_artifact_ids=arr(identity,1),note=text)),
        'run':obj(dict(run_id=identity,method=identity,seed=dict(type='integer',minimum=0),execution_status=execution,acceptance_status=acceptance,simulation_duration=ref('duration'),input_signature=dict(type=['string','null'],pattern='^[a-f0-9]{64}$'),source_mat_artifact_id=optional_text,wtr_artifact_id=optional_text,attempt=dict(type='integer',minimum=1),supersedes_run_id=optional_text,acceptance_checks=arr(ref('check')))),
        'storage_evidence':obj(dict(status=enum('not_executed','partial','verified','failed','unknown'),evidence_artifact_ids=arr(identity))),
        'event':obj(dict(sequence=dict(type='integer',minimum=1),event=enum('planned','started','saved','interrupted','resumed','completed','failed','analysis_only_fix','registered'),run_id=optional_text,occurred_at=dict(type=['string','null'],format='date-time'),evidence_artifact_ids=arr(identity,1),resume_scope_run_ids=arr(identity),note=text)),
    }
    for name in ['artifact']:
        defs[name]['allOf']=[]
        defs[name]['allOf'].append({'if':{'properties':{'hash_verification':{'enum':['current_bytes_hashed','metadata_matched_prior_full_hash']}},'required':['hash_verification']},'then':{'properties':{'sha256':sha,'size_bytes':{'type':'integer','minimum':0}}}})
    defs['storage_evidence']['allOf']=[{'if':{'properties':{'status':{'const':'verified'}},'required':['status']},'then':{'properties':{'evidence_artifact_ids':{'minItems':1}}}}]
    root_props=dict(schema_version={'const':'aerognc.results.batch.v1'},record_kind=enum('batch','single_run'),study=identity,airframe=identity,batch_id=identity,run_id=optional_text,source_commit=commit,source_commit_role=enum('execution_start','baseline_not_exact_execution','exact_clean_execution','unknown'),engine=obj(dict(id=dict(type=['string','null'],pattern='^[a-f0-9]{64}$'),source_lock_artifact_ids=arr(identity,1),scope_note=text)),protocol=obj(dict(id=text,artifact_id=identity,sha256=sha)),input_signature=dict(type=['string','null'],pattern='^[a-f0-9]{64}$'),methods=dict(type='array',items=identity,minItems=1,uniqueItems=True),seeds=dict(type='array',items=dict(type='integer',minimum=0),minItems=1,uniqueItems=True),simulation_duration=ref('duration'),models=obj(dict(gnss=obj(dict(id=text,correlation_s=dict(type='number',exclusiveMinimum=0),protocol_artifact_id=identity)),estimator=obj(dict(id=text,build_identity_artifact_id=identity)))),execution_status=execution,acceptance_status=acceptance,retention_status=retention,acceptance_summary=obj(dict(criterion=text,passed_runs=dict(type='integer',minimum=0),evaluated_runs=dict(type='integer',minimum=0),evidence_artifact_ids=arr(identity,1),original_thresholds_preserved=dict(type='boolean'),note=text)),roots=arr(obj(dict(root_id=identity,location_template=text,kind=enum('local','archive','repository'),read_only=dict(type='boolean'))),1),runs=arr(ref('run'),1),artifacts=arr(ref('artifact'),1),events=arr(ref('event')),provenance=obj(dict(baseline_commit=commit,source_dirty_state=enum('clean','dirty','unknown'),source_snapshot_artifact_ids=arr(identity),execution_record_artifact_ids=arr(identity,1),registration_phase=enum('DESIGN_EXAMPLE_ONLY','REGISTERED'),limitations=arr(text))),storage=obj(dict(state=enum('local_only','backed_up_verified','archived_verified','deletion_approved','deleted','unknown'),backup=ref('storage_evidence'),restore=ref('storage_evidence'),archives=arr(obj(dict(archive_id=identity,root_id=identity,manifest_artifact_id=identity,verified=dict(type='boolean')))))),extensions=dict(type='object'))
    estimator=root_props['models']['properties']['estimator']
    estimator['properties']['identity_scope']=enum('execution_verified','current_snapshot_only','unknown')
    estimator['required'].append('identity_scope')
    schema=obj(root_props)
    schema.update({'$schema':'https://json-schema.org/draft/2020-12/schema','$id':'https://tangqingxi.github.io/AeroGNC-Phase-Audit/schemas/aerognc-results-batch-v1.json','title':'AeroGNC Results批次登记合同v1（设计稿）','description':'仅定义数据合同；不能代替物理文件、算术一致性、审批或科研验收检查。$id是逻辑标识，不宣称已部署该网址。','$defs':defs,'allOf':[{'if':{'properties':{'record_kind':{'const':'single_run'}},'required':['record_kind']},'then':{'properties':{'run_id':identity,'runs':{'maxItems':1}}},'else':{'properties':{'run_id':{'type':'null'}}}},{'if':{'properties':{'storage':{'properties':{'state':{'const':'backed_up_verified'}}}},'required':['storage']},'then':{'properties':{'storage':{'properties':{'backup':{'properties':{'status':{'const':'verified'}}}}}}}},{'if':{'properties':{'storage':{'properties':{'state':{'const':'archived_verified'}}}},'required':['storage']},'then':{'properties':{'storage':{'properties':{'backup':{'properties':{'status':{'const':'verified'}}},'restore':{'properties':{'status':{'const':'verified'}}},'archives':{'minItems':1}}}}}}]})
    dump(OUT/'RESULTS_MANIFEST_SCHEMA.json',schema)
    plan={r['source_path']:r for r in rows(OUT/'BACKUP_PLAN.csv')}
    identities=rows(AUDIT/'Phase1/WTR_INDEX.csv')
    artifacts=[]
    def artifact(path,role,run_id=None):
        key='a'+str(len(artifacts)+1)
        r=plan[path]
        artifacts.append(dict(artifact_id=key,role=role,locator=dict(root_id='matlab_original',path=path),size_bytes=int(r['size_bytes']),sha256=r['sha256'],availability='present',hash_verification=r['current_verification'],git_tracking='tracked' if r['tracked_in_matlab']=='True' else 'local_only',run_id=run_id,legacy_locations=[]))
        return key
    def build_common(batch,gnss_tau,source,kind,engine,protocol_path,protocol_id):
        protocol_id_ref=artifact(protocol_path,'protocol')
        gnss_path='research/ppid_pindi/gnss_v2/protocol.json' if gnss_tau==1000 else 'research/ppid_pindi/protocol.json'
        gnss_ref=artifact(gnss_path,'gnss_protocol')
        estimator_ref=artifact('build/px4_ecl/build_manifest.json','estimator_build_identity')
        return dict(schema_version='aerognc.results.batch.v1',record_kind=kind,study='hover_distance_takeoff_formal',airframe='shc09',batch_id=batch,run_id=None,source_commit=source,source_commit_role='execution_start' if gnss_tau==60 else 'baseline_not_exact_execution',engine=dict(id=engine,source_lock_artifact_ids=[],scope_note='共同engine不完整覆盖research；必须同时保留显式来源锁及执行版快照。'),protocol=dict(id=protocol_id,artifact_id=protocol_id_ref,sha256=plan[protocol_path]['sha256']),input_signature=None,methods=[],seeds=[],simulation_duration=dict(planned_s=55,observed_s=55),models=dict(gnss=dict(id='SHC09-GNSS-GM-v2-1000s' if gnss_tau==1000 else 'legacy_slow_white_60s',correlation_s=gnss_tau,protocol_artifact_id=gnss_ref),estimator=dict(id='PX4-ECL_archived_bridge',build_identity_artifact_id=estimator_ref)),execution_status='completed',acceptance_status='failed',retention_status='KEEP_EVIDENCE',acceptance_summary={},roots=[dict(root_id='matlab_original',location_template='${MATLAB_ROOT}',kind='local',read_only=True)],runs=[],artifacts=artifacts,events=[],provenance=dict(baseline_commit='339d7b1a997de6ba350cef3207d8a5b7db3d838d',source_dirty_state='unknown',source_snapshot_artifact_ids=[],execution_record_artifact_ids=[],registration_phase='DESIGN_EXAMPLE_ONLY',limitations=['这是审计仓库中的设计示例，尚未写入原Results。','当前文件哈希身份与历史执行源码身份分别记录；运行起点commit不自动证明精确执行来源。']),storage=dict(state='local_only',backup=dict(status='not_executed',evidence_artifact_ids=[]),restore=dict(status='not_executed',evidence_artifact_ids=[]),archives=[]),extensions={})
    batch='hover_distance_takeoff_formal_20261103_r1'
    selected=[r for r in identities if r['path'].startswith('logs/wtr/'+batch+'/')]
    m=build_common(batch,60,'c381275775b2fe0191eddd663798157864e56780','batch',selected[0]['engine'],'results/'+batch+'/formal_protocol.json','HOVER-DISTANCE-TAKEOFF-FORMAL-20261103-v1')
    m['models']['estimator']['identity_scope']='current_snapshot_only'
    lock=artifact('results/'+batch+'/source_lock.json','source_lock');m['engine']['source_lock_artifact_ids']=[lock]
    metrics=artifact('results/'+batch+'/metrics.csv','metrics')
    completion=artifact('results/'+batch+'/completion.json','execution_completion')
    management=artifact('docs/validation/hover_distance_takeoff_formal_20261103_r1/summary_recovery_exception.json','management_interruption')
    frozen=artifact('docs/validation/hover_distance_takeoff_formal_20261103_r1/hdtf_run.frozen.m','execution_source_snapshot')
    m['provenance']['source_snapshot_artifact_ids']=[frozen]
    m['provenance']['execution_record_artifact_ids']=[completion,management]
    for r in selected:
        run=r['run_id'];raw=artifact(r['matched_raw_mat'],'raw_mat',run);wtr=artifact(r['path'],'single_flight_wtr',run)
        m['runs'].append(dict(run_id=run,method=r['method'],seed=int(float(r['seed'])),execution_status='completed',acceptance_status='failed',simulation_duration=dict(planned_s=55,observed_s=55),input_signature=r['input_signature'],source_mat_artifact_id=raw,wtr_artifact_id=wtr,attempt=1,supersedes_run_id=None,acceptance_checks=[dict(criterion='original_true_recovery',status='failed',evidence_artifact_ids=[metrics],note='原始真实恢复判据未达到；估计恢复不能替代。')]))
    m['methods']=sorted({r['method'] for r in m['runs']});m['seeds']=sorted({r['seed'] for r in m['runs']})
    m['acceptance_summary']=dict(criterion='original_true_recovery',passed_runs=0,evaluated_runs=15,evidence_artifact_ids=[metrics],original_thresholds_preserved=True,note='15/15执行完成、真实恢复0/15通过、估计恢复15/15通过；独立保留。')
    resumed=[r['run_id'] for r in m['runs'] if not (r['method']=='DA_NS' and r['seed']==501)]
    m['events']=[dict(sequence=1,event='interrupted',run_id=None,occurred_at=None,evidence_artifact_ids=[management],resume_scope_run_ids=[],note='首条已保存，汇总累加器中断；不是15条物理仿真失败。'),dict(sequence=2,event='resumed',run_id=None,occurred_at=None,evidence_artifact_ids=[completion],resume_scope_run_ids=resumed,note='只补14个not_run，未重飞已完成项。'),dict(sequence=3,event='completed',run_id=None,occurred_at=None,evidence_artifact_ids=[completion],resume_scope_run_ids=[],note='15次飞行完成；精确事件时间未知，保留null。')]
    dump(OUT/'examples/legacy_60s_formal.manifest.json',m)
    artifacts=[]
    batch='gnss_1000s_regression_20261104_r1';base='docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/'
    lock_json=json.loads((MAIN/(base+'source_lock.json')).read_text(encoding='utf-8-sig'))
    m=build_common(batch,1000,'b1cf139b40992f9b7420a21b996b6d00d09a4013','single_run',lock_json['base_sources']['engine'],base+'regression_protocol.json','GNSS-GM-1000s-regression-v1')
    m['models']['estimator']['identity_scope']='current_snapshot_only'
    m['study']='gnss_model_regression'
    lock=artifact(base+'source_lock.json','source_lock');m['engine']['source_lock_artifact_ids']=[lock]
    raw_path='results/'+batch+'/PCA_PREDICTIVE_s501.mat';run='PCA_PREDICTIVE_s501_'+plan[raw_path]['sha256'][:16];raw=artifact(raw_path,'raw_mat',run)
    metrics=artifact(base+'navigation_metrics.csv','metrics');recovery=artifact(base+'recovery_diagnostics.json','acceptance_evidence');execution=artifact(base+'verification.json','numerical_checks')
    m['run_id']=run;m['methods']=['PCA_PREDICTIVE'];m['seeds']=[501]
    m['runs']=[dict(run_id=run,method='PCA_PREDICTIVE',seed=501,execution_status='completed',acceptance_status='failed',simulation_duration=dict(planned_s=55,observed_s=55),input_signature=None,source_mat_artifact_id=raw,wtr_artifact_id=None,attempt=1,supersedes_run_id=None,acceptance_checks=[dict(criterion='original_true_recovery',status='failed',evidence_artifact_ids=[recovery],note='恢复窗最小真实水平误差0.4770444895m，大于原0.2m半径。')])]
    m['acceptance_summary']=dict(criterion='original_true_recovery',passed_runs=0,evaluated_runs=1,evidence_artifact_ids=[recovery],original_thresholds_preserved=True,note='数值预检及GNSS融合完成，但真实恢复未通过；Issue #1暂缓，非本次重构阻塞。')
    m['provenance']['execution_record_artifact_ids']=[execution]
    m['provenance']['limitations']+=['input_signature未由本轮读取MAT提取，显式保留null，不从其他批次复制。','source_commit是回归启动基准；GNSS v2交付提交为ae03d6b1941939efe9b8f5fc0afd4c016e80ea21。']
    m['events']=[dict(sequence=1,event='completed',run_id=run,occurred_at=None,evidence_artifact_ids=[execution],resume_scope_run_ids=[],note='读取已有55秒回归证据；本阶段未运行仿真。')]
    m['extensions']=dict(issue_url='https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1',true_horizontal_rmse_m=0.7819362505614169,local_ekf_horizontal_error_rmse_m=0.788159282535954,perceived_horizontal_rmse_m=0.06637866656721061)
    dump(OUT/'examples/gnss_v2_1000s_single.manifest.json',m)
    print('已生成schema及两个真实证据示例')


if __name__=='__main__':main()
