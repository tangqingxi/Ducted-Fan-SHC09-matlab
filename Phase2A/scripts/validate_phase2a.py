"""验证审计合同、示例与只读保护状态；不调用主仓库应用代码。"""
from pathlib import Path
import copy
import csv
import hashlib
import importlib.metadata
import json
import re
import subprocess
import sys
import tempfile

OUT=Path(__file__).resolve().parents[1]
AUDIT=OUT.parent
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')
sys.path.insert(0,str(Path(tempfile.gettempdir())/'aerognc-phase2a-jsonschema-4.23.0'))
from jsonschema import Draft202012Validator,FormatChecker


def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])


def semantic_errors(m):
    errors=[]
    artifacts={r['artifact_id']:r for r in m['artifacts']}
    run_ids={r['run_id'] for r in m['runs']}
    roots={r['root_id'] for r in m['roots']}
    if len(artifacts)!=len(m['artifacts']):errors.append('duplicate_artifact_id')
    if len(run_ids)!=len(m['runs']):errors.append('duplicate_run_id')
    if len(roots)!=len(m['roots']):errors.append('duplicate_root_id')
    refs=[m['protocol']['artifact_id'],m['models']['gnss']['protocol_artifact_id'],m['models']['estimator']['build_identity_artifact_id'],*m['engine']['source_lock_artifact_ids'],*m['acceptance_summary']['evidence_artifact_ids'],*m['provenance']['source_snapshot_artifact_ids'],*m['provenance']['execution_record_artifact_ids']]
    for r in m['runs']:
        refs.extend(x for x in [r['source_mat_artifact_id'],r['wtr_artifact_id']] if x)
        for check in r['acceptance_checks']:refs.extend(check['evidence_artifact_ids'])
    for event in m['events']:
        refs.extend(event['evidence_artifact_ids'])
        if any(r not in run_ids for r in event['resume_scope_run_ids']):errors.append('unknown_resumed_run')
    for kind in ['backup','restore']:refs.extend(m['storage'][kind]['evidence_artifact_ids'])
    if any(key not in artifacts for key in refs):errors.append('broken_artifact_reference')
    if any(r['locator']['root_id'] not in roots for r in artifacts.values()):errors.append('unknown_root')
    if any(r['run_id'] and r['run_id'] not in run_ids for r in artifacts.values()):errors.append('artifact_unknown_run')
    p=artifacts.get(m['protocol']['artifact_id'])
    if p and p['sha256']!=m['protocol']['sha256']:errors.append('protocol_hash_mismatch')
    if set(m['methods'])!={r['method'] for r in m['runs']}:errors.append('method_coverage')
    if set(m['seeds'])!={r['seed'] for r in m['runs']}:errors.append('seed_coverage')
    s=m['acceptance_summary'];passed=sum(r['acceptance_status']=='passed' for r in m['runs']);evaluated=sum(r['acceptance_status'] in {'passed','failed'} for r in m['runs'])
    if not 0<=s['passed_runs']<=s['evaluated_runs']<=len(m['runs']) or s['passed_runs']!=passed or s['evaluated_runs']!=evaluated:errors.append('acceptance_counts')
    if m['acceptance_status']=='passed' and passed!=len(m['runs']):errors.append('false_batch_pass')
    if m['record_kind']=='single_run' and m['run_id']!=m['runs'][0]['run_id']:errors.append('single_run_identity')
    for a in artifacts.values():
        path=a['locator']['path']
        if '\\' in path or any(p in {'.','..'} for p in path.split('/')) or path.startswith('/') or re.match(r'^[A-Za-z]:',path):errors.append('unsafe_relative_path')
    return errors


def main():
    schema=json.loads((OUT/'RESULTS_MANIFEST_SCHEMA.json').read_text(encoding='utf-8'))
    Draft202012Validator.check_schema(schema)
    validator=Draft202012Validator(schema,format_checker=FormatChecker())
    examples=[];loaded=[]
    for path in sorted((OUT/'examples').glob('*.json')):
        m=json.loads(path.read_text(encoding='utf-8'));loaded.append(m)
        errors=[e.message for e in validator.iter_errors(m)]+semantic_errors(m)
        examples.append(dict(path=path.relative_to(OUT).as_posix(),schema_and_semantic_errors=errors))
    if any(x['schema_and_semantic_errors'] for x in examples):
        print(json.dumps(examples,ensure_ascii=True,indent=2));raise RuntimeError('真实示例验证失败')
    tests=[]
    def reject(name,mutate):
        m=copy.deepcopy(loaded[0]);mutate(m)
        rejected=bool(list(validator.iter_errors(m)) or semantic_errors(m))
        tests.append(dict(case=name,expected='reject',passed=rejected))
    reject('bad_sha256',lambda m:m['artifacts'][0].update(sha256='bad'))
    reject('absolute_windows_path',lambda m:m['artifacts'][0]['locator'].update(path='C:/outside/file.mat'))
    reject('parent_traversal',lambda m:m['artifacts'][0]['locator'].update(path='../outside.mat'))
    reject('backslash_path',lambda m:m['artifacts'][0]['locator'].update(path='raw\\flight.mat'))
    reject('invalid_execution_status',lambda m:m.update(execution_status='passed'))
    reject('verified_backup_without_evidence',lambda m:m['storage']['backup'].update(status='verified'))
    reject('duplicate_run_identity',lambda m:m['runs'].append(copy.deepcopy(m['runs'][0])))
    reject('broken_artifact_reference',lambda m:m['engine'].update(source_lock_artifact_ids=['does_not_exist']))
    reject('false_performance_pass',lambda m:m.update(acceptance_status='passed'))
    reject('wrong_acceptance_count',lambda m:m['acceptance_summary'].update(passed_runs=15))
    m=copy.deepcopy(loaded[0]);m['study']='future_study';m['airframe']='future_airframe';m['engine']['id']='f'*64
    tests.append(dict(case='dynamic_study_airframe_engine',expected='accept_structure',passed=not list(validator.iter_errors(m)) and not semantic_errors(m)))
    baseline=json.loads((OUT/'evidence/PROTECTED_SOURCE_BASELINE.json').read_text(encoding='utf-8'))
    changes=[]
    for r in baseline:
        p=MAIN/r['path'];st=p.stat()
        if st.st_size!=r['size_bytes'] or st.st_mtime_ns!=r['mtime_ns']:changes.append(r['path'])
    old=json.loads((AUDIT/'Phase1/OUTPUT_MANIFEST.json').read_text(encoding='utf-8'))
    old_changes=[r['path'] for r in old['files'] if hashlib.sha256((AUDIT/'Phase1'/r['path']).read_bytes()).hexdigest()!=r['sha256']]
    mandatory=['PHASE2A_REPORT.md','BASELINE_FREEZE.md','BACKUP_PLAN.csv','RESULTS_MANIFEST_SCHEMA.json','RESULTS_MANIFEST_EXAMPLES.md','RESULTS_LIFECYCLE.md','RESULTS_MANAGER_SPEC.md','REMOTE_DELIVERY_INTEGRITY.md','PHASE2B_EXECUTION_PLAN.md','APPROVAL_REQUEST.md']
    missing=[p for p in mandatory if not (OUT/p).is_file()]
    broken=[];links=0
    for doc in OUT.rglob('*.md'):
        for link in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
            if '://' in link or link.startswith('#'):continue
            target=link.split('#',1)[0]
            if target in {'DELIVERY_MANIFEST.json','evidence/VALIDATION.json'}:continue
            links+=1
            if not (doc.parent/target).exists():broken.append(dict(file=doc.name,target=target))
    secrets=[];binary=[];oversized=[];non_lf=[]
    for p in OUT.rglob('*'):
        if not p.is_file():continue
        data=p.read_bytes()
        if b'\0' in data or p.suffix.lower() in {'.mat','.wtr','.exe','.dll','.zip','.bundle','.pyc'}:binary.append(p.relative_to(OUT).as_posix())
        if len(data)>10*1024*1024:oversized.append(p.relative_to(OUT).as_posix())
        if b'\r\n' in data:non_lf.append(p.relative_to(OUT).as_posix())
        for pattern in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[0-9A-Z]{16}',rb'-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----',rb'C:[/\\]Users[/\\][^/\\\s]+']:
            if re.search(pattern,data):secrets.append(p.relative_to(OUT).as_posix())
    summary=json.loads((OUT/'evidence/BACKUP_SUMMARY.json').read_text(encoding='utf-8'))
    current_head=git(MAIN,'rev-parse','HEAD').decode().strip();main_status=git(MAIN,'status','--porcelain').decode()
    value=dict(schema_dialect='2020-12',validator_version=importlib.metadata.version('jsonschema'),schema_valid=True,examples=examples,negative_and_dynamic_contract_checks=tests,protected_files_metadata_rechecked=len(baseline),protected_metadata_changes=changes,phase1_original_manifest_files_rechecked=len(old['files']),phase1_changes=old_changes,main_head=current_head,main_worktree_clean=not main_status,main_worktrees=git(MAIN,'worktree','list','--porcelain').decode(),required_missing=missing,local_links_checked=links,broken_links=broken,possible_credentials_or_personal_paths=sorted(set(secrets)),forbidden_binary_files=binary,files_over_10MiB=oversized,non_lf_files=non_lf,backup_and_restore_executed=False,source_code_or_simulation_executed=False,backup_plan_counts_match=summary['protected_files']==len(baseline),scope='合同与本地交付检查；源数据未复制，未执行manager或控制仿真。')
    value['passed']=all([all(r['passed'] for r in tests),not changes,not old_changes,current_head=='339d7b1a997de6ba350cef3207d8a5b7db3d838d',not main_status,not missing,not broken,not secrets,not binary,not oversized,not non_lf,value['backup_plan_counts_match']])
    (OUT/'evidence/VALIDATION.json').write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(value,ensure_ascii=True,indent=2))
    if not value['passed']:raise RuntimeError('Phase2A交付核验失败')


if __name__=='__main__':main()
