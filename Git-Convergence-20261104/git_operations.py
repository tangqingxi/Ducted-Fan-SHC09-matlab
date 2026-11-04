"""按用户明确授权执行归档、指定远端分支删除和本地主线快进。"""
from pathlib import Path
import json
import subprocess
import sys

ROOT=Path('E:/Ducted-Fan-SHC09-matlab')
OUT=Path(__file__).resolve().parent
TARGET='339d7b1a997de6ba350cef3207d8a5b7db3d838d'
TAG='archive/viz-replay-20261104'
DELETE=['WindTrace_merge','comparison-ready','f8-research','hover_distance','px4-log-view','viz-replay','debug-ecl-position','change-B']


def run(*args):
    p=subprocess.run(['git','-C',str(ROOT),*args],capture_output=True,text=True,encoding='utf-8')
    entry=dict(args=list(args),exit_code=p.returncode,stdout=p.stdout,stderr=p.stderr)
    with (OUT/'operations.jsonl').open('a',encoding='utf-8') as f:
        f.write(json.dumps(entry,ensure_ascii=False)+'\n')
    print(json.dumps(entry,ensure_ascii=True),flush=True)
    if p.returncode:
        raise RuntimeError('Git命令失败，停止后续变更')
    return p.stdout.strip()


def refs(text):
    return dict(line.split('\t',1)[::-1] for line in text.splitlines() if '\t' in line)


def guard():
    if run('status','--porcelain=v1','--untracked-files=all'):
        raise RuntimeError('当前工作树不干净，禁止继续')
    default=run('ls-remote','--symref','origin','HEAD')
    if f'ref: refs/heads/main\tHEAD' not in default or f'{TARGET}\tHEAD' not in default:
        raise RuntimeError('远端默认分支或HEAD不符合指定基准')
    if run('rev-parse','origin/main')!=TARGET:
        raise RuntimeError('origin/main不符合指定基准')


def archive():
    guard()
    baseline=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    original=refs(baseline['git']['remote_heads'])['refs/heads/viz-replay']
    if run('rev-parse','origin/viz-replay')!=original:
        raise RuntimeError('viz-replay来源与基线不同')
    if refs(run('ls-remote','--heads','origin')).get('refs/heads/viz-replay')!=original:
        raise RuntimeError('远端viz-replay在检查期间发生变化')
    local=run('tag','--list',TAG)
    if local:
        if run('rev-parse',f'refs/tags/{TAG}')!=original:
            raise RuntimeError('既有同名Tag指向不同，禁止覆盖')
    else:
        run('tag',TAG,'origin/viz-replay')
    remote=refs(run('ls-remote','--tags','origin',f'refs/tags/{TAG}'))
    if remote and remote.get(f'refs/tags/{TAG}')!=original:
        raise RuntimeError('远端同名Tag不同，禁止覆盖')
    run('push','origin',f'refs/tags/{TAG}:refs/tags/{TAG}')
    actual=refs(run('ls-remote','--tags','origin',f'refs/tags/{TAG}'))
    if actual.get(f'refs/tags/{TAG}')!=original:
        raise RuntimeError('远端归档Tag核验失败，禁止删除分支')
    (OUT/'archive_verified.json').write_text(json.dumps(dict(tag=TAG,source_branch='viz-replay',source_head=original,remote_tag_sha=actual[f'refs/tags/{TAG}'],verified=True),indent=2),encoding='utf-8')


def delete():
    guard()
    proof=json.loads((OUT/'archive_verified.json').read_text(encoding='utf-8'))
    if refs(run('ls-remote','--tags','origin',f'refs/tags/{TAG}')).get(f'refs/tags/{TAG}')!=proof['source_head']:
        raise RuntimeError('归档Tag当前不可用，禁止删除')
    before=refs(json.loads((OUT/'before.json').read_text(encoding='utf-8'))['git']['remote_heads'])
    for branch in DELETE:
        if branch=='main':
            raise RuntimeError('禁止删除main')
        head=before[f'refs/heads/{branch}']
        if branch!='viz-replay':
            run('merge-base','--is-ancestor',head,TARGET)
        elif head!=proof['source_head']:
            raise RuntimeError('归档源分支身份错误')
        if refs(run('ls-remote','--heads','origin',f'refs/heads/{branch}')).get(f'refs/heads/{branch}')!=head:
            raise RuntimeError('远端分支已变化，停止删除')
        run('push','origin','--delete',branch)
    final=refs(run('ls-remote','--heads','origin'))
    if final!={'refs/heads/main':TARGET}:
        raise RuntimeError('远端最终分支未达到预期')
    (OUT/'deletion_verified.json').write_text(json.dumps(dict(deleted_branches=DELETE,remote_heads=final),indent=2),encoding='utf-8')


def switch():
    guard()
    run('merge-base','--is-ancestor','main','origin/main')
    run('switch','main')
    run('fetch','origin','--prune')
    if run('rev-parse','origin/main')!=TARGET:
        raise RuntimeError('fetch后origin/main发生变化，停止')
    run('merge','--ff-only','origin/main')
    if run('rev-parse','HEAD')!=TARGET or run('status','--porcelain=v1','--untracked-files=all'):
        raise RuntimeError('本地主线最终状态错误')


if __name__=='__main__':
    {'archive':archive,'delete':delete,'switch':switch}[sys.argv[1]]()
