"""记录文档整改前的字节身份，保护其他跟踪文件与既有审计交付。"""
from pathlib import Path
import hashlib
import json
import subprocess

OUT=Path(__file__).resolve().parents[1]
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')
AUDIT=OUT.parent
ALLOW=['README.md','AGENTS.md','HANDOFF.md','WORKSPACE_MIGRATION.md','docs/README.md','docs/repository_map.md','docs/guides/architecture.md','docs/guides/getting_started.md','docs/guides/research_workflows.md','docs/guides/results_and_evidence.md']


def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args])


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
    return h.hexdigest()


def main():
    if git(MAIN,'status','--porcelain').strip() or git(AUDIT,'diff','--name-only').strip():raise RuntimeError('存在任务外修改')
    base=git(MAIN,'rev-parse','HEAD').decode().strip()
    if base!='339d7b1a997de6ba350cef3207d8a5b7db3d838d':raise RuntimeError('文档前基准不符合指令')
    before=[]
    for rel in ALLOW:
        p=MAIN/rel
        if p.exists():
            body=p.read_bytes();blob=git(MAIN,'show',base+':'+rel)
            before.append(dict(path=rel,existed=True,size_bytes=len(body),sha256=hashlib.sha256(body).hexdigest(),git_blob_content_sha256=hashlib.sha256(blob).hexdigest(),lines=len(body.splitlines())))
        else:before.append(dict(path=rel,existed=False,size_bytes=0,sha256=None,git_blob_content_sha256=None,lines=0))
    tracked=[r for r in git(MAIN,'ls-files','-z').decode('utf-8').split('\0') if r and r not in ALLOW]
    protected=[dict(path=rel,size_bytes=(MAIN/rel).stat().st_size,sha256=sha(MAIN/rel)) for rel in tracked]
    old_audit=[]
    for directory in ['Phase1','Phase2A','Git-Convergence-20261104']:
        for p in sorted((AUDIT/directory).rglob('*')):
            if p.is_file():old_audit.append(dict(path=p.relative_to(AUDIT).as_posix(),sha256=sha(p)))
    result=dict(science_baseline_commit=base,audit_baseline_commit=git(AUDIT,'rev-parse','HEAD').decode().strip(),main_status_before=git(MAIN,'status','--short','--branch').decode(),worktrees=git(MAIN,'worktree','list','--porcelain').decode(),allowed_documents=ALLOW,before=before,non_document_tracked_guard=protected,existing_audit_guard=old_audit)
    target=OUT/'evidence/DOCUMENT_BASELINE.json'
    if target.exists():raise RuntimeError('不覆盖开工快照')
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(documents=len(before),tracked_files_protected=len(protected),existing_audit_files_protected=len(old_audit),science_baseline_commit=base)))


if __name__=='__main__':main()
