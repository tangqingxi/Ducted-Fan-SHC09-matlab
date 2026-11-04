"""确认清洁过滤后blob身份不变，再刷新Git索引统计缓存，不暂存内容差异。"""
from pathlib import Path
import json
import subprocess

OUT=Path(__file__).resolve().parent
ROOT=Path('E:/Ducted-Fan-SHC09-matlab')


def run(*args):
    p=subprocess.run(['git',*args],cwd=ROOT,capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stderr.decode('utf-8',errors='replace'))
    return p.stdout


def main():
    plan=json.loads((OUT/'CHECKOUT_BYTE_RESTORATION_PLAN.json').read_text(encoding='utf-8'))
    before=run('ls-files','--stage','-z')
    index={}
    for item in before.decode('utf-8').split('\0'):
        if item:
            fields,path=item.split('\t',1)
            index[path]=fields.split()[1]
    run('diff','--cached','--quiet')
    checked=[]
    for item in plan:
        path=item['path']
        blob=run('hash-object',f'--path={path}',path).decode('ascii').strip()
        if blob!=index[path]:
            raise RuntimeError('发现实际Git内容差异，禁止刷新：'+path)
        checked.append(dict(path=path,unchanged_blob=blob))
    run('add','--renormalize','--',*[r['path'] for r in checked])
    after=run('ls-files','--stage','-z')
    if before!=after:
        raise RuntimeError('索引blob或模式发生变化')
    run('diff','--cached','--quiet')
    status=run('status','--porcelain=v1','--untracked-files=all').decode('utf-8')
    if status:
        raise RuntimeError('刷新后仍有工作区状态：'+status)
    record=dict(files_checked=checked,index_entries_identical=True,cached_diff_empty=True,working_tree_clean=True)
    (OUT/'INDEX_REFRESH_VERIFIED.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    final=json.loads((OUT/'final.json').read_text(encoding='utf-8'))
    final['primary']['status']=status
    (OUT/'final.json').write_text(json.dumps(final,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(files_checked=len(checked),index_entries_identical=True,cached_diff_empty=True,working_tree_clean=True)))


if __name__=='__main__':
    main()
