"""按执行前SHA精确恢复Git切换导致的文本换行与mtime，不改变任何Git对象。"""
from pathlib import Path
import hashlib
import itertools
import json
import os
import re
import subprocess
import sys

OUT=Path(__file__).resolve().parent
ROOT=Path('E:/Ducted-Fan-SHC09-matlab')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    after=json.loads((OUT/'after.json').read_text(encoding='utf-8'))
    original={r['path']:r for r in before['primary']['files']}
    checked={r['path']:r for r in after['primary']['files']}
    proof=json.loads((OUT/'VERIFICATION.json').read_text(encoding='utf-8'))
    plan=[]
    restored={}
    unmatched=[]
    for rel in proof['primary']['content_changed_files']:
        current=(ROOT/rel).read_bytes()
        if digest(current)!=checked[rel]['sha256']:
            raise RuntimeError('发现核验后外部修改，停止：'+rel)
        candidates={
            'LF转CRLF':current.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'),
            'CRLF转LF':current.replace(b'\r\n',b'\n'),
        }
        matches=[(kind,data) for kind,data in candidates.items() if digest(data)==original[rel]['sha256']]
        if not matches:
            lines=current.replace(b'\r\n',b'\n').splitlines(keepends=True)
            count=original[rel]['size_bytes']-len(current)+current.count(b'\r\n')
            indices=[i for i,line in enumerate(lines) if line.endswith(b'\n')]
            blank=[i for i in indices if not lines[i].strip()]
            choices=[]
            if count==1:
                choices.extend((i,) for i in indices)
            elif count>1:
                choices.extend(tuple(indices[i:i+count]) for i in range(len(indices)-count+1))
                commits=subprocess.check_output(['git','-C',str(ROOT),'log','--format=%H','--',rel]).decode('utf-8').splitlines()
                boundaries=set(indices[:5]+indices[-5:])
                for commit in commits:
                    historical=subprocess.check_output(['git','-C',str(ROOT),'show',f'{commit}:{rel}'])
                    historical_lines=historical.splitlines(keepends=True)
                    common=0
                    for old,new in zip(historical_lines,lines):
                        if old!=new:
                            break
                        common+=1
                    for boundary in [common,len(historical_lines)]:
                        boundaries.update(i for i in range(boundary-5,boundary+5) if i in indices)
                choices.extend(itertools.combinations(sorted(boundaries),count))
                choices.extend(itertools.combinations(blank,count))
            offsets=[m.start() for m in re.finditer(b'\n',current)]
            for selected in choices:
                parts=[]
                start=0
                for index in selected:
                    offset=offsets[index]
                    parts.extend([current[start:offset],b'\r'])
                    start=offset
                parts.append(current[start:])
                candidate=b''.join(parts)
                if digest(candidate)==original[rel]['sha256']:
                    matches=[('混合换行精确SHA重建',candidate)]
                    break
        if len(matches)!=1:
            unmatched.append(dict(path=rel,before_bytes=original[rel]['size_bytes'],after_bytes=len(current),lf=current.count(b'\n'),crlf=current.count(b'\r\n'),needed_original_crlf=original[rel]['size_bytes']-len(current)+current.count(b'\r\n')))
            continue
        kind,data=matches[0]
        plan.append(dict(path=rel,operation=kind,before_sha256=original[rel]['sha256'],checkout_sha256=checked[rel]['sha256'],restored_sha256=digest(data),bytes=len(data)))
        restored[rel]=data
    (OUT/'CHECKOUT_BYTE_RESTORATION_PLAN.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(plan_files=len(plan),all_exact_original_sha=not unmatched,unmatched=unmatched,mode=sys.argv[1]),ensure_ascii=True),flush=True)
    if sys.argv[1]!='apply':
        return
    if unmatched:
        raise RuntimeError('有文件无法精确重建，禁止写入')
    status=subprocess.check_output(['git','-C',str(ROOT),'status','--porcelain=v1','--untracked-files=all'])
    if status:
        raise RuntimeError('工作区已出现修改，停止恢复')
    tracked=set(subprocess.check_output(['git','-C',str(ROOT),'ls-files','-z']).decode('utf-8').split('\0'))
    changed=proof['primary']['metadata_changed_files']
    if any(p not in tracked for p in changed):
        raise RuntimeError('存在未跟踪文件变化，不作自动恢复')
    for rel in changed:
        p=ROOT/rel
        st=p.stat()
        if st.st_mtime_ns!=checked[rel]['mtime_ns'] or st.st_size!=checked[rel]['size_bytes']:
            raise RuntimeError('存在核验后元数据变化，停止：'+rel)
    for rel,data in restored.items():
        p=ROOT/rel
        if digest(p.read_bytes())!=checked[rel]['sha256']:
            raise RuntimeError('写前SHA变化，停止：'+rel)
        p.write_bytes(data)
        if digest(p.read_bytes())!=original[rel]['sha256']:
            raise RuntimeError('恢复SHA错误：'+rel)
    # 仅恢复已确认由本次checkout改写的受跟踪文件时间戳。
    for rel in changed:
        p=ROOT/rel
        os.utime(p,ns=(p.stat().st_atime_ns,original[rel]['mtime_ns']))
    final=after
    final_files={r['path']:r for r in final['primary']['files']}
    for rel in changed:
        p=ROOT/rel
        st=p.stat()
        if digest(p.read_bytes())!=original[rel]['sha256']:
            raise RuntimeError('最终源文件SHA不同：'+rel)
        final_files[rel].update(size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,sha256=original[rel]['sha256'])
    final['primary']['hashed_bytes']=sum(r['size_bytes'] for r in final['primary']['files'] if 'sha256' in r)
    final['primary']['status']=subprocess.check_output(['git','-C',str(ROOT),'status','--porcelain=v1','--untracked-files=all']).decode('utf-8')
    final['checkout_restoration']=dict(exact_byte_restored=len(plan),mtime_restored=len(changed),large_data_sha_source='after.json完整复核；恢复仅限994份tracked源码/文档/已跟踪资产，逐项重读并匹配原SHA')
    (OUT/'final.json').write_text(json.dumps(final,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(final['checkout_restoration'],ensure_ascii=True),flush=True)


if __name__=='__main__':
    main()
