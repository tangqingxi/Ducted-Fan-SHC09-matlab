"""检查本阶段审计交付及历史保护，暂存目录限定为Phase2A5-Docs。"""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import subprocess

OUT=Path(__file__).resolve().parents[1]
AUDIT=OUT.parent
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')


def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def main():
    baseline=json.loads((OUT/'evidence/DOCUMENT_BASELINE.json').read_text(encoding='utf-8'))
    required=['DOCUMENTATION_REFACTOR_REPORT.md','DOCUMENT_CHANGE_MANIFEST.csv','DOCUMENT_LINK_VALIDATION.json','BEFORE_AFTER_SUMMARY.md']
    if any(not (OUT/p).exists() for p in required):raise RuntimeError('缺少必需交付')
    old_changes=[r['path'] for r in baseline['existing_audit_guard'] if sha(AUDIT/r['path'])!=r['sha256']]
    source_changes=[r['path'] for r in baseline['non_document_tracked_guard'] if sha(MAIN/r['path'])!=r['sha256']]
    protected=json.loads((AUDIT/'Phase2A/evidence/PROTECTED_SOURCE_BASELINE.json').read_text(encoding='utf-8'))
    allowed=set(baseline['allowed_documents']);data_changes=[]
    for r in protected:
        if r['path'] in allowed:continue
        st=(MAIN/r['path']).stat()
        if st.st_size!=r['size_bytes'] or st.st_mtime_ns!=r['mtime_ns']:data_changes.append(r['path'])
    spec=importlib.util.spec_from_file_location('docs_link_readonly',MAIN/'tools/check_docs_links.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    bad_links=[];local_links=0
    for doc in OUT.rglob('*.md'):
        for start,end,value,line in helper.destinations(doc.read_text(encoding='utf-8')):
            target=helper.local_target(AUDIT,doc,value)
            if target is None:continue
            local_links+=1
            if not target.is_relative_to(AUDIT) or not target.exists():bad_links.append(dict(file=doc.name,line=line,target=value))
    suspicious=[];oversized=[];forbidden=[]
    for p in OUT.rglob('*'):
        if not p.is_file():continue
        data=p.read_bytes()
        if len(data)>5*1024*1024:oversized.append(p.relative_to(OUT).as_posix())
        if p.suffix.lower() in {'.mat','.wtr','.exe','.dll','.zip','.bundle','.pyc'}:forbidden.append(p.name)
        if p.suffix.lower()=='.png':continue
        for pattern in [rb'gh[pousr]_[A-Za-z0-9]{20,}',rb'github_pat_[A-Za-z0-9_]{20,}',rb'AKIA[0-9A-Z]{16}',rb'-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----',rb'C:[/\\]Users[/\\][^/\\\s]+']:
            if re.search(pattern,data):suspicious.append(p.relative_to(OUT).as_posix())
    head=git(MAIN,'rev-parse','HEAD').decode().strip()
    status=git(MAIN,'status','--porcelain').decode()
    check=dict(main_documentation_commit=head,main_worktree_status=status,existing_audit_changes=old_changes,non_document_source_changes=source_changes,protected_metadata_changes=data_changes,audit_local_links=local_links,broken_links=bad_links,possible_secrets_or_personal_paths=sorted(set(suspicious)),oversized_files=oversized,forbidden_raw_data_files=forbidden,main_documentation_only=set(git(MAIN,'diff','--name-only',baseline['science_baseline_commit'],head).decode().splitlines())==allowed)
    check['passed']=all([head=='d464ab5ad5b368a5eb5876e53696aa7c607733f1',not status,not old_changes,not source_changes,not data_changes,not bad_links,not suspicious,not oversized,not forbidden,check['main_documentation_only']])
    (OUT/'evidence/LOCAL_DELIVERY_CHECK.json').write_text(json.dumps(check,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    if not check['passed']:
        print(json.dumps(check,ensure_ascii=True,indent=2));raise RuntimeError('阶段交付检查未通过')
    manifest=[]
    for p in sorted(OUT.rglob('*')):
        if p.is_file() and p.name!='DELIVERY_MANIFEST.json':manifest.append(dict(path=p.relative_to(OUT).as_posix(),size_bytes=p.stat().st_size,sha256=sha(p)))
    (OUT/'DELIVERY_MANIFEST.json').write_text(json.dumps(dict(schema='aerognc.docs.audit.delivery.v1',main_documentation_commit=head,science_baseline_commit=baseline['science_baseline_commit'],files=manifest,self_exclusion='本清单不列自身；暂存和远端仍独立核对自身。'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    if git(AUDIT,'diff','--cached','--name-only').strip():raise RuntimeError('审计仓库已有暂存内容，停止')
    subprocess.check_call(['git','-C',str(AUDIT),'add','--','Phase2A5-Docs/'])
    subprocess.check_call(['git','-C',str(AUDIT),'diff','--cached','--check'])
    staged=git(AUDIT,'diff','--cached','--name-only','-z').decode('utf-8').split('\0')
    if any(p and not p.startswith('Phase2A5-Docs/') for p in staged):raise RuntimeError('审计暂存越界')
    for rel in filter(None,staged):
        if (AUDIT/rel).read_bytes()!=git(AUDIT,'show',':'+rel):raise RuntimeError('新交付暂存字节不一致：'+rel)
    print(json.dumps(dict(**check,staged_files=len([p for p in staged if p]),manifest_entries=len(manifest)),ensure_ascii=True,indent=2))


if __name__=='__main__':main()
