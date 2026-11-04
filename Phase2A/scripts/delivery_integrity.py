"""生成交付清单并核对暂存字节；发布后只读验证GitHub原始文件。"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import subprocess
import sys
import urllib.parse
import urllib.request

OUT=Path(__file__).resolve().parents[1]
AUDIT=OUT.parent
MANIFEST=OUT/'DELIVERY_MANIFEST.json'


def git(*args):
    return subprocess.check_output(['git','-C',str(AUDIT),*args])


def identity(body):
    return dict(size_bytes=len(body),sha256=hashlib.sha256(body).hexdigest(),git_blob_oid=hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest())


def prepare():
    if 'tangqingxi/AeroGNC-Phase-Audit' not in git('remote','get-url','origin').decode():
        raise RuntimeError('审计远端错误')
    if git('diff','--cached','--name-only'):
        raise RuntimeError('发现已暂存内容，先人工核实')
    entries=[]
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path!=MANIFEST:
            entries.append(dict(path=path.relative_to(OUT).as_posix(),**identity(path.read_bytes())))
    manifest=dict(schema_version='aerognc.audit.delivery.v1',scope='Phase2A_only',byte_domain='UTF8_no_BOM_LF;worktree_equals_staged_blob',baseline_commit='339d7b1a997de6ba350cef3207d8a5b7db3d838d',self_exclusion='DELIVERY_MANIFEST.json不列自身；暂存和远端验证仍单独校验该文件。',files=entries)
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    subprocess.check_call(['git','-C',str(AUDIT),'add','--','Phase2A/'])
    subprocess.check_call(['git','-C',str(AUDIT),'diff','--cached','--check'])
    names=git('diff','--cached','--name-only','-z').decode('utf-8').split('\0')
    if any(not p.startswith('Phase2A/') for p in names if p):raise RuntimeError('发现目录外暂存文件')
    checked=0
    for path in sorted(p for p in OUT.rglob('*') if p.is_file()):
        rel=path.relative_to(AUDIT).as_posix()
        body=path.read_bytes();staged=git('show',':'+rel)
        if body!=staged:raise RuntimeError('暂存发生字节转换：'+rel)
        checked+=1
    print(json.dumps(dict(manifest_entries=len(entries),staged_files_verified=checked,scope='Phase2A_only',all_worktree_bytes_equal_staged_blobs=True),ensure_ascii=True))


def remote():
    head=git('rev-parse','HEAD').decode().strip()
    server=git('ls-remote','origin','refs/heads/main').decode().split()[0]
    if head!=server:raise RuntimeError('本地与远端SHA不一致')
    files=[p for p in OUT.rglob('*') if p.is_file()]
    def verify(path):
        rel=path.relative_to(AUDIT).as_posix()
        expected=git('show',head+':'+rel)
        url='https://raw.githubusercontent.com/tangqingxi/AeroGNC-Phase-Audit/'+head+'/'+urllib.parse.quote(rel,safe='/')
        request=urllib.request.Request(url,headers={'User-Agent':'AeroGNC-Phase2A-Integrity'})
        with urllib.request.urlopen(request,timeout=45) as response:
            got=response.read()
            status=response.status
        if status!=200 or got!=expected:raise RuntimeError('GitHub实际字节不一致：'+rel)
        return dict(path=rel,http_status=status,**identity(got))
    with ThreadPoolExecutor(max_workers=6) as pool:
        results=list(pool.map(verify,files))
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
    by_path={r['path'].removeprefix('Phase2A/'):r for r in results}
    for item in manifest['files']:
        actual=by_path[item['path']]
        if any(actual[k]!=item[k] for k in ['sha256','size_bytes','git_blob_oid']):
            raise RuntimeError('远端文件不匹配交付清单：'+item['path'])
    print(json.dumps(dict(commit=head,remote_head=server,github_raw_files_verified=len(results),manifest_entries_verified=len(manifest['files']),total_published_bytes=sum(r['size_bytes'] for r in results),all_http_200_and_byte_identical=True,audit_worktree_clean=not git('status','--porcelain').strip(),files=results),ensure_ascii=True,indent=2))


if __name__=='__main__':
    {'prepare':prepare,'remote':remote}[sys.argv[1]]()
