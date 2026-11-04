"""复用Phase1索引定向核验、制定备份计划；不修改或复制主仓库数据。"""
from pathlib import Path
from collections import Counter,defaultdict
import base64
import csv
import hashlib
import json
import os
import subprocess

AUDIT=Path(__file__).resolve().parents[2]
OUT=AUDIT/'Phase2A'
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')
BASE='339d7b1a997de6ba350cef3207d8a5b7db3d838d'


def csvread(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))


def csvwrite(path,rows,fields=None):
    with path.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields or list(rows[0]),lineterminator='\n')
        w.writeheader();w.writerows(rows)


def dump(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')


def git(root,*args):
    return subprocess.check_output(['git','-C',str(root),*args])


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def main():
    inventory=csvread(AUDIT/'Phase1/FILE_INVENTORY.csv')
    batches=csvread(AUDIT/'Phase1/RESULTS_BATCHES.csv')
    files={r['path']:r for r in inventory}
    tracked=set(git(MAIN,'ls-files','-z').decode('utf-8').split('\0'))-{''}
    if git(MAIN,'rev-parse','HEAD').decode().strip()!=BASE or git(MAIN,'status','--porcelain'):
        raise RuntimeError('主仓库不是指定干净基准')
    state=dict(baseline=BASE,matlab_branch=git(MAIN,'branch','--show-current').decode().strip(),matlab_status=git(MAIN,'status','--short','--branch').decode(),remote=git(MAIN,'remote','-v').decode(),remote_heads=git(MAIN,'ls-remote','--heads','origin').decode(),remote_default=git(MAIN,'ls-remote','--symref','origin','HEAD').decode(),worktrees=git(MAIN,'worktree','list','--porcelain').decode(),controller_branch_present=bool(git(MAIN,'branch','--list','controller-ppid-p-indi').strip()),controller_worktree_present=(Path.home()/'.codex/worktrees/controller-ppid-p-indi/Ducted-Fan-SHC09-matlab').exists(),audit_start_head=git(AUDIT,'rev-parse','HEAD').decode().strip(),audit_status_before=git(AUDIT,'status','--short','--branch').decode(),audit_remote=git(AUDIT,'remote','-v').decode(),tracked_main_files=len(tracked))
    dump(OUT/'evidence/BASELINE_STATE.json',state)
    previous=json.loads((AUDIT/'Git-Convergence-20261104/final.json').read_text(encoding='utf-8'))
    cache={r['path']:r for r in previous['primary']['files']}
    p1hash={r['path']:r['sha256'] for r in csvread(AUDIT/'Phase1/KEY_ARTIFACT_HASHES.csv')}
    p1hash.update({r['path']:r['sha256'] for r in csvread(AUDIT/'Phase1/SOURCE_FINGERPRINTS.csv')})
    p1hash.update({r['path']:r['sha256'] for r in csvread(AUDIT/'Phase1/ROOT_DOCUMENT_INDEX.csv')})
    p1hash.update({r['path']:r['sha256'] for r in csvread(AUDIT/'Phase1/WINDTRACE_EXECUTABLES.csv')})
    software=[r['related_paths'] for r in batches if r['record_role']=='software_build_or_rollback']
    rollback='results/windtrace_app_v1.0_r14_backup'
    active='apps/windtrace/dist/WindTrace'
    roles={r['record_role'] for r in batches}
    anchors=[]
    for b in batches:
        if b['record_role'] in {'historical_formal','changeB_formal','1000s_model_regression','precheck','changeB_precheck','50s_precheck','execution_management_evidence','12s_diagnostic_A_B_C','12s_diagnostic_A_F','12s_G_and_alignment_replays','round1_to4_saved_short_diagnostic','capacity_regression'}:
            for prefix in b['related_paths'].split(';'):
                anchors.append((prefix,b['study'],b['batch_id'],b['record_role']))
    selected={}
    excluded=[]
    for path,r in files.items():
        sw=next((p for p in software if path.startswith(p+'/')),None)
        if path in tracked or path.startswith(('logs/','build/px4_ecl/')) or path.startswith(active+'/') or path.startswith(rollback+'/') or (path.startswith('results/') and not sw) or ('/' not in path and Path(path).suffix in {'.log','.txt'}):
            if '/__pycache__/' not in path and not path.endswith(('.pyc','.tmp','.asv')):
                selected[path]=r
                continue
        excluded.append((path,r,sw))
    # 仅枚举两个必要运行包，补捉Phase1后新文件；不递归重扫全仓。
    new_paths=[]
    for prefix in [active,rollback]:
        for folder,dirs,names in os.walk(MAIN/prefix,followlinks=False):
            if Path(folder).is_junction():raise RuntimeError('运行包含junction')
            for name in names:
                p=Path(folder)/name
                if p.is_symlink():raise RuntimeError('运行包含符号链接')
                rel=p.relative_to(MAIN).as_posix()
                if rel not in selected:
                    st=p.stat()
                    selected[rel]=dict(path=rel,size_bytes=str(st.st_size),mtime_ns=str(st.st_mtime_ns),tracked='False')
                    new_paths.append(rel)
    plan=[];metadata=[];missing=[];changed=[]
    for path,r in sorted(selected.items()):
        p=MAIN/path
        if not p.exists():
            missing.append(path)
            continue
        st=p.stat()
        old=cache.get(path,{})
        match=old.get('size_bytes')==st.st_size and old.get('mtime_ns')==st.st_mtime_ns
        original_match=int(r['size_bytes'])==st.st_size and int(r.get('mtime_ns',0))==st.st_mtime_ns
        if match and path in p1hash:
            digest=p1hash[path];origin='Phase1_verified_sha256';status='metadata_matched_prior_full_hash'
            if old.get('sha256') and old['sha256']!=digest:raise RuntimeError('历史哈希记录互相矛盾：'+path)
        elif match and old.get('sha256'):
            digest=old['sha256'];origin='Git-Convergence_final_full_sha256';status='metadata_matched_prior_full_hash'
        else:
            digest=sha(p);origin='Phase2A_targeted_full_sha256';status='current_bytes_hashed'
        if not original_match:changed.append(path)
        assoc=sorted((x for x in anchors if path==x[0] or path.startswith(x[0]+'/')),key=lambda x:len(x[0]),reverse=True)
        if path.startswith(active+'/'):
            study='windtrace';batch='installed_current';retention='KEEP_ACTIVE';priority='P0';restore='REQUIRED: entire_package_hash_then_isolated_launch_and_old_wtr'
        elif path.startswith(rollback+'/'):
            study='windtrace';batch='rollback_r14_candidate';retention='KEEP_EVIDENCE';priority='P1';restore='REQUIRED: whole_package_hash_and_isolated_launch;not_yet_tested'
        elif assoc:
            _,study,batch,role=assoc[0];retention='KEEP_EVIDENCE';priority='P0';restore='REQUIRED: exact_hash_and_role_specific_readonly_open'
        elif path.startswith(('results/current_summaries/','results/f8_reference_20261101/','examples/')):
            study='historical_evidence';batch=path.split('/')[1];retention='KEEP_EVIDENCE';priority='P1';restore='REQUIRED: hashes_and_receipt_index_resolution;raw_may_be_missing'
        elif path.startswith(('docs/','figures/','logs/')) or Path(path).name.startswith('codex-repo-'):
            study='provenance';batch='baseline_339d7b1a';retention='KEEP_EVIDENCE';priority='P0';restore='REQUIRED: exact_hash_and_links'
        elif path.startswith('results/'):
            study='unclassified_existing_evidence';batch=path.split('/')[1];retention='REVIEW_REQUIRED';priority='P1';restore='REQUIRED: ownership_review_before_migration;no_performance_success_inferred'
        else:
            study='baseline_source';batch='baseline_339d7b1a';retention='KEEP_ACTIVE';priority='P0';restore='REQUIRED: native_bytes_paths_source_locks_and_toolchain_identity'
        plan.append(dict(source_path=path,size_bytes=st.st_size,sha256=digest,study=study,batch_id=batch,retention_class=retention,backup_priority=priority,proposed_backup_target='${BACKUP_ROOT}/AeroGNC-Sim/339d7b1a/snapshot/'+path,verification_required='REQUIRED: destination_full_SHA256_and_source_stability;not_executed',restore_test_required=restore,sha256_provenance=origin,current_verification=status,tracked_in_matlab=path in tracked,backup_status='PLANNED_NOT_COPIED',approval_status='PENDING_BACKUP_LOCATION_AND_SCOPE'))
        metadata.append(dict(path=path,size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,sha256=digest,sha256_provenance=origin))
    if missing:raise RuntimeError('保护范围有缺失文件：'+str(missing))
    csvwrite(OUT/'BACKUP_PLAN.csv',plan)
    dump(OUT/'evidence/PROTECTED_SOURCE_BASELINE.json',metadata)
    exclusion_groups=defaultdict(lambda:dict(files=0,size_bytes=0))
    for path,r,sw in excluded:
        key='OTHER_WINDTRACE_BUILD_OR_ROLLBACK' if sw else 'PYTHON_ENVIRONMENT' if path.startswith('.venv/') else 'CACHE_OR_TEMP' if '/__pycache__/' in path or path.endswith(('.pyc','.tmp','.asv')) else 'OTHER_NOT_IN_PROTECTED_SCOPE'
        exclusion_groups[key]['files']+=1;exclusion_groups[key]['size_bytes']+=int(r['size_bytes'])
    rows=[dict(group=k,retention_class='ARCHIVE_CANDIDATE' if k=='OTHER_WINDTRACE_BUILD_OR_ROLLBACK' else 'DELETE_CANDIDATE' if k=='CACHE_OR_TEMP' else 'REVIEW_REQUIRED',**v,action='NO_COPY_MOVE_OR_DELETE_IN_PHASE2A') for k,v in exclusion_groups.items()]
    csvwrite(OUT/'BACKUP_SCOPE_EXCLUSIONS.csv',rows)
    total=sum(r['size_bytes'] for r in plan)
    counts=Counter(r['retention_class'] for r in plan)
    by_priority={p:dict(files=sum(r['backup_priority']==p for r in plan),bytes=sum(r['size_bytes'] for r in plan if r['backup_priority']==p)) for p in ['P0','P1']}
    wtr=csvread(AUDIT/'Phase1/WTR_INDEX.csv');key=csvread(AUDIT/'Phase1/KEY_ARTIFACT_HASHES.csv')
    paths={r['source_path'] for r in plan}
    summary=dict(protected_files=len(plan),protected_bytes=total,protected_GB=total/1e9,protected_GiB=total/2**30,one_copy_with_25pct_headroom_bytes=(total*125+99)//100,two_independent_copies_with_25pct_headroom_bytes=(total*250+99)//100,retention_classes=dict(counts),priority=by_priority,new_bundle_paths=new_paths,phase1_metadata_drift=changed,missing_protected_paths=missing,hash_provenance=dict(Counter(r['sha256_provenance'] for r in plan)),formal_and_precheck_wtr_count=len(wtr),formal_and_precheck_wtr_in_plan=sum(r['path'] in paths for r in wtr),formal_raw_mat_count=sum('/hover_distance_takeoff_formal_' in r['path'] and '/logs/' in r['path'] for r in key),all_33_key_mat_in_plan=sum(r['path'] in paths for r in key),archive_candidate_scope=rows,backup_executed=False,restore_test_executed=False,root_alias='MATLAB_ROOT=E:/Ducted-Fan-SHC09-matlab',scope='Phase1 inventory reused; stat selected files and enumerate current+one_rollback packages only')
    dump(OUT/'evidence/BACKUP_SUMMARY.json',summary)
    # Phase1原清单、工作文件、远端Git blob、GitHub API分别核对，绝不改写旧清单。
    manifest=json.loads((AUDIT/'Phase1/OUTPUT_MANIFEST.json').read_text(encoding='utf-8'))
    remote=json.loads((OUT/'evidence/AUDIT_REMOTE_SAMPLES.json').read_text(encoding='utf-8'))
    tree={r['path']:r for r in remote['samples'][0]['tree'] if r['type']=='blob'}
    refs=git(AUDIT,'ls-tree','-r','origin/main').decode('utf-8').splitlines()
    git_tree={line.split('\t',1)[1]:line.split()[2] for line in refs}
    integrity=[]
    for entry in manifest['files']:
        path='Phase1/'+entry['path'];local=(AUDIT/path).read_bytes()
        oid=git_tree[path];blob=git(AUDIT,'cat-file','blob',oid)
        computed=hashlib.sha1(b'blob '+str(len(blob)).encode()+b'\0'+blob).hexdigest()
        compare='identical_bytes' if local==blob else 'line_endings_only' if local.replace(b'\r\n',b'\n')==blob.replace(b'\r\n',b'\n') else 'actual_content_change'
        integrity.append(dict(path=path,original_manifest_size_bytes=entry['size_bytes'],original_manifest_sha256=entry['sha256'],local_size_bytes=len(local),local_sha256=hashlib.sha256(local).hexdigest(),local_matches_original_manifest=hashlib.sha256(local).hexdigest()==entry['sha256'],git_blob_oid=oid,git_blob_size_bytes=len(blob),git_blob_content_sha256=hashlib.sha256(blob).hexdigest(),github_tree_oid=tree[path]['sha'],github_tree_size_bytes=tree[path]['size'],git_object_oid_verified=computed==oid,github_matches_fetched_blob=tree[path]['sha']==oid and tree[path]['size']==len(blob),local_vs_remote=compare,local_crlf_count=local.count(b'\r\n'),remote_crlf_count=blob.count(b'\r\n')))
    csvwrite(OUT/'evidence/PHASE1_REMOTE_INTEGRITY.csv',integrity)
    samples=[]
    for item in remote['samples'][1:]:
        body=base64.b64decode(item['content']);blob=git(AUDIT,'cat-file','blob',item['sha'])
        samples.append(dict(path=item['path'],api_git_blob_oid=item['sha'],api_size_bytes=len(body),api_content_sha256=hashlib.sha256(body).hexdigest(),matches_fetched_git_blob=body==blob))
    dump(OUT/'evidence/PHASE1_INTEGRITY_SUMMARY.json',dict(audit_ref=remote['ref'],files=len(integrity),local_vs_remote=dict(Counter(r['local_vs_remote'] for r in integrity)),local_matches_original_manifest=sum(r['local_matches_original_manifest'] for r in integrity),remote_matches_original_manifest=sum(r['git_blob_content_sha256']==r['original_manifest_sha256'] for r in integrity),all_github_tree_matches=all(r['github_matches_fetched_blob'] for r in integrity),all_git_object_ids_verified=all(r['git_object_oid_verified'] for r in integrity),github_api_content_samples=samples,old_manifest_modified=False))
    print(json.dumps(summary,ensure_ascii=True,indent=2))


if __name__=='__main__':main()
