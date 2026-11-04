"""只读记录工作树与数据完整性；Git分支变更由外部明确命令执行。"""
from pathlib import Path
import csv
import hashlib
import json
import os
import subprocess
import sys
import time

OUT=Path(__file__).resolve().parent
ROOT=Path('E:/Ducted-Fan-SHC09-matlab')
OTHER=Path('C:/Users/32450/.codex/worktrees/controller-ppid-p-indi/Ducted-Fan-SHC09-matlab')
TARGET='339d7b1a997de6ba350cef3207d8a5b7db3d838d'


def git(root,*args):
    return subprocess.check_output(['git','-C',str(root),*args]).decode('utf-8')


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(4*1024*1024),b''):
            h.update(b)
    return h.hexdigest()


def snapshot(stage):
    dest=OUT/f'{stage}.json'
    if dest.exists():
        raise RuntimeError('拒绝覆盖既有核验记录')
    data={}
    for label,root in [('primary',ROOT),('controller',OTHER)]:
        tracked=set(git(root,'ls-files','-z').split('\0'))-{''}
        state=dict(root=root.as_posix(),head=git(root,'rev-parse','HEAD').strip(),branch=git(root,'branch','--show-current').strip(),status=git(root,'status','--porcelain=v1','--untracked-files=all'),files=[])
        seen_bytes=0
        last=time.monotonic()
        def visit(folder):
            nonlocal seen_bytes,last
            for e in sorted(os.scandir(folder),key=lambda x:x.name):
                p=Path(e.path)
                rel=p.relative_to(root).as_posix()
                if rel=='.git':
                    continue
                st=e.stat(follow_symlinks=False)
                is_link=e.is_symlink() or p.is_junction()
                if e.is_dir(follow_symlinks=False) and not is_link:
                    visit(p)
                else:
                    item=dict(path=rel,size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,is_link=is_link)
                    needs_hash=not is_link and (rel in tracked or rel.split('/')[0] in {'results','logs','figures','examples','research','docs'} or p.suffix.lower() in {'.mat','.wtr','.exe'} or (label=='controller' and not rel.startswith(('.venv/','build/'))))
                    if needs_hash:
                        item['sha256']=sha(p)
                        seen_bytes+=st.st_size
                    state['files'].append(item)
                    if time.monotonic()-last>15:
                        print(json.dumps(dict(stage=stage,worktree=label,files=len(state['files']),hashed_gb=round(seen_bytes/1e9,3))),flush=True)
                        last=time.monotonic()
        visit(root)
        state['hashed_files']=sum('sha256' in f for f in state['files'])
        state['hashed_bytes']=seen_bytes
        data[label]=state
        print(json.dumps(dict(stage=stage,worktree=label,files=len(state['files']),hashed_files=state['hashed_files'],hashed_bytes=seen_bytes)),flush=True)
    data['git']=dict(branches=git(ROOT,'branch','-avv'),worktrees=git(ROOT,'worktree','list','--porcelain'),remotes=git(ROOT,'remote','-v'),remote_heads=git(ROOT,'ls-remote','--heads','origin'),remote_default=git(ROOT,'ls-remote','--symref','origin','HEAD'),remote_tags=git(ROOT,'ls-remote','--tags','origin'))
    dest.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')


def compare():
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    after=json.loads((OUT/('final.json' if (OUT/'final.json').exists() else 'after.json')).read_text(encoding='utf-8'))
    report={}
    for label in ['primary','controller']:
        a={r['path']:r for r in before[label]['files']}
        b={r['path']:r for r in after[label]['files']}
        changed=[p for p in sorted(set(a)|set(b)) if a.get(p)!=b.get(p)]
        content_changes=[p for p in sorted(set(a)|set(b)) if p not in a or p not in b or any(a[p].get(k)!=b[p].get(k) for k in ['size_bytes','is_link','sha256'])]
        protected_changes=[p for p in changed if p.split('/')[0] in {'results','logs'} or Path(p).suffix.lower() in {'.mat','.wtr','.exe'}]
        report[label]=dict(files=len(b),hashed_files=after[label]['hashed_files'],hashed_bytes=after[label]['hashed_bytes'],metadata_changed_files=changed,content_changed_files=content_changes,protected_data_metadata_changes=protected_changes,status_unchanged=before[label]['status']==after[label]['status'],head=after[label]['head'],branch=after[label]['branch'],status=after[label]['status'])
    branch_rows=[]
    for ref in git(ROOT,'for-each-ref','--format=%(refname)','refs/heads').splitlines():
        line=ref.removeprefix('refs/heads/')
        count=int(git(ROOT,'rev-list','--count',f'main..{ref}').strip())
        branch_rows.append(dict(branch=line,head=git(ROOT,'rev-parse',ref).strip(),commits_not_in_main=count,action='KEEP_LOCAL',reason='存在工作树修改或独有提交时保护；已合入本地分支本次亦保留，未执行本地清理'))
    with (OUT/'LOCAL_BRANCH_REVIEW.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(branch_rows[0]))
        writer.writeheader()
        writer.writerows(branch_rows)
    original_viz=git(ROOT,'rev-parse','refs/heads/viz-replay').strip()
    report['remote_heads']=after['git']['remote_heads']
    report['remote_default']=after['git']['remote_default']
    report['remote_archive_tag']=git(ROOT,'ls-remote','--tags','origin','refs/tags/archive/viz-replay-20261104').strip()
    report['archive_expected_head']=original_viz
    report['target_head']=TARGET
    live_metadata_changes=[]
    for label in ['primary','controller']:
        root=ROOT if label=='primary' else OTHER
        for item in after[label]['files']:
            st=(root/item['path']).stat(follow_symlinks=False)
            if st.st_size!=item['size_bytes'] or st.st_mtime_ns!=item['mtime_ns']:
                live_metadata_changes.append(f"{label}:{item['path']}")
    report['final_live_metadata_changes']=live_metadata_changes
    def parse_refs(value):
        return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in value.splitlines()}
    old_tags=parse_refs(before['git']['remote_tags'])
    new_tags=parse_refs(after['git']['remote_tags'])
    report['preexisting_remote_tags_unchanged']=all(new_tags.get(k)==v for k,v in old_tags.items())
    report['remote_tags']={k.removeprefix('refs/tags/'):v for k,v in new_tags.items() if not k.endswith('^{}')}
    report['remote_tag_count']=len(report['remote_tags'])
    preserved=[]
    for line in before['git']['branches'].splitlines():
        parts=line.lstrip('*+ ').split()
        if len(parts)<2 or parts[0].startswith('remotes/') or parts[0]=='main':
            continue
        actual=git(ROOT,'rev-parse',f'refs/heads/{parts[0]}').strip()
        preserved.append(dict(branch=parts[0],before_abbreviated_head=parts[1],after_head=actual,unchanged=actual.startswith(parts[1])))
    report['local_branches_preserved']=preserved
    history_paths=['research/ppid_pindi/gnss_v2/protocol.json','shc09_gnss_config.m','docs/validation/shc09_b_frame_20261104/NAVIGATION_DIAGNOSIS_SUMMARY.md','docs/validation/shc09_b_frame_20261104/gnss_1000s_model_20261104/report.md']
    report['main_history_paths_present']={p:subprocess.run(['git','-C',str(ROOT),'cat-file','-e',f'main:{p}'],capture_output=True).returncode==0 for p in history_paths}
    report['passed']=all([not report['primary']['content_changed_files'],not report['primary']['protected_data_metadata_changes'],not report['controller']['metadata_changed_files'],report['controller']['status_unchanged'],report['primary']['status']=='',report['primary']['head']==TARGET,report['primary']['branch']=='main',after['git']['remote_heads'].strip()==f'{TARGET}\trefs/heads/main',f'ref: refs/heads/main\tHEAD' in after['git']['remote_default'],report['remote_archive_tag']==f'{original_viz}\trefs/tags/archive/viz-replay-20261104',report['preexisting_remote_tags_unchanged'],all(p['unchanged'] for p in preserved),all(report['main_history_paths_present'].values()),not live_metadata_changes])
    (OUT/'VERIFICATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    compact={k:({x:(len(y) if isinstance(y,list) else y) for x,y in v.items() if x!='status'} if isinstance(v,dict) and k in {'primary','controller'} else v) for k,v in report.items() if k!='local_branches_preserved'}
    print(json.dumps(compact,ensure_ascii=True,indent=2))


if __name__=='__main__':
    if sys.argv[1] in {'before','after'}:
        snapshot(sys.argv[1])
    elif sys.argv[1]=='compare':
        compare()
