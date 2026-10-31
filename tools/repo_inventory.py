from pathlib import Path
import argparse,csv,hashlib,json,os,re,subprocess
from collections import defaultdict
from datetime import datetime,timezone
from urllib.parse import unquote

# 只盘点当前仓库，不访问外部工程；引用是保守的文本引用，不冒充完整调用图。
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs'
LOCAL=('archive','results','build','.tmp_matlab')
# 只允许两个版本化归档索引，实际日志和本地副本继续禁止暂存。
ARCHIVE_INDEX={'archive/README.md','archive/logs/README.md'}

def git(*args):
    return subprocess.check_output(['git','-c','core.quotepath=false',*args],cwd=ROOT).decode('utf-8')

def tracked():
    return sorted(x for x in git('ls-files','-z').split('\0') if x)

def write_csv(name,fields,rows):
    with (OUT/name).open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(rows)

def write_json(name,value):
    (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def category(path):
    if path in ARCHIVE_INDEX:return '文档/证据'
    if path.startswith(('tests/','platform/tests/')):return '测试/冻结'
    if path.startswith('docs/evidence/'):return '历史脚本/证据'
    if path.startswith(('docs/','examples/')):return '文档/证据'
    if path.startswith(('platform/','allocators/','effectiveness/','models/','drivers/','lib/','configs/')):return '核心运行'
    if path.startswith(('tools/','third_party/')):return '工具/第三方'
    if path.endswith('.m') or path.startswith(('modules/','compat/','analysis/','experiments/')):return '兼容/旧API及研究分析'
    return '工程元数据'

def active_dirs():
    s=(ROOT/'ca_setup.m').read_text(encoding='utf-8-sig')
    block=s.split('paths={',1)[1].split('};',1)[0]
    result={'.',*re.findall(r"'([^']+)'",block)}
    result.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'allocators').iterdir() if p.is_dir())
    return result

def collect():
    files=tracked();names={Path(f).stem for f in files if f.endswith('.m')};refs=defaultdict(set);texts={}
    for f in files:
        if Path(f).suffix.lower() in ('.m','.md','.py'):
            text=(ROOT/f).read_text(encoding='utf-8-sig',errors='replace');texts[f]=text
            for word in set(re.findall(r'[A-Za-z]\w*',text))&names:
                if Path(f).stem!=word:refs[word].add(f)
    last={};commit=''
    for line in git('log','--format=COMMIT:%H','--name-only','--no-renames').splitlines():
        if line.startswith('COMMIT:'):commit=line[7:]
        elif line and line not in last:last[line]=commit
    rows=[];byhash=defaultdict(list);same=defaultdict(list);adirs=active_dirs()
    for f in files:
        path=ROOT/f;parts=Path(f).parts;cat=category(f);stem=path.stem
        fixture=any(x in f for x in ('baseline/','fixtures/','legacy_reference/','/reference/'))
        test=f.startswith(('tests/','platform/tests/'));entry=(len(parts)==1 and f.endswith('.m') and stem.startswith(('main','plot_main','run_','build_')) or f.startswith('apps/') or f.startswith('tools/') or (f.startswith(('analysis/','experiments/')) and stem.startswith(('run_','plot_'))))
        ref=sorted(refs[stem]) if f.endswith('.m') else []
        decision='保留';rationale='当前工程或参考材料；不依据体积删除'
        if test or fixture:decision='冻结保留';rationale='测试/基线/参考，禁止清理'
        elif cat=='核心运行':rationale='活跃运行层；动态注册也可能产生调用'
        elif cat in ('文档/证据','历史脚本/证据'):decision='证据保留';rationale='支撑结论、文档或历史记录，不是全部都需运行'
        elif cat=='工具/第三方':rationale='工具或上游依赖/许可；禁止删除第三方'
        elif f.endswith('.m'):rationale='兼容入口或研究分析；保留外部调用能力'
        orphan=f.endswith('.m') and not ref and not entry and not fixture and not test
        if orphan:
            decision='上游保留，不迁移' if f.startswith('third_party/') else 'legacy候选，保留待审'
            rationale+='；无文本引用不等于无动态/外部调用'
        data=path.read_bytes();sha=hashlib.sha256(data).hexdigest();byhash[sha].append(f)
        if f.endswith('.m'):same[stem].append(f)
        rows.append(dict(path=f,size=len(data),tracked=1,category=cat,referenced_by_count=len(ref),last_commit=last.get(f,'new_in_index'),decision=decision,rationale=rationale,is_entry=int(bool(entry)),is_test=int(test),is_fixture=int(fixture),orphan_candidate=int(orphan),canonical=f,sha256=sha))
    duplicates=[]
    priority={'核心运行':0,'兼容/旧API及研究分析':1,'工具/第三方':2,'测试/冻结':3,'文档/证据':4,'历史脚本/证据':5,'工程元数据':6}
    index={r['path']:r for r in rows}
    for sha,group in byhash.items():
        if len(group)<2:continue
        canonical=min(group,key=lambda f:(priority[category(f)],f))
        for f in group:
            duplicates.append(dict(sha256=sha,path=f,canonical=canonical,decision='内容相同，保留上下文/许可/证据'))
            index[f]['canonical']=canonical
            if f!=canonical:index[f]['rationale']+='；精确重复副本，保留原上下文'
    collisions=[]
    for name,group in same.items():
        if len(group)<2:continue
        active=[f for f in group if Path(f).parent.as_posix() in adirs]
        collisions.append(dict(name=name,paths=group,active_paths=active,referenced_by=sorted(refs[name]),active_conflict=len(active)>1))
    local=[];local_m=[]
    for folder in LOCAL:
        groups=defaultdict(lambda:[0,0]);base=ROOT/folder
        if base.exists():
            for parent,dirs,fs in os.walk(base,followlinks=False):
                dirs[:]=[d for d in dirs if not Path(parent,d).is_symlink()]
                for name in fs:
                    path=Path(parent,name)
                    if path.is_symlink():continue
                    if path.relative_to(ROOT).as_posix() in files:continue
                    stat=path.stat();key=path.suffix.lower() or '[none]';groups[key][0]+=1;groups[key][1]+=stat.st_size
                    if key=='.m':local_m.append((path.relative_to(ROOT).as_posix(),hashlib.sha256(path.read_bytes()).hexdigest(),stat.st_size))
        for ext,(count,size) in sorted(groups.items()):local.append(dict(directory=folder,extension=ext,file_count=count,size=size,tracked=0,decision='本地历史/生成物，保留；不加入Git'))
    return files,rows,duplicates,collisions,local,refs,local_m

def generate():
    OUT.mkdir(exist_ok=True);files,rows,duplicates,collisions,local,refs,local_m=collect()
    write_csv('file_duplicates.csv',['sha256','path','canonical','decision'],duplicates)
    write_csv('file_orphan_candidates.csv',['path','category','decision','rationale'],[{k:r[k] for k in ('path','category','decision','rationale')} for r in rows if r['orphan_candidate']])
    write_csv('local_generated_inventory.csv',['directory','extension','file_count','size','tracked','decision'],local)
    write_json('function_collisions.json',collisions)
    canonical={r['sha256']:r['canonical'] for r in rows};local_groups=defaultdict(list)
    for path,sha,size in local_m:local_groups[sha].append((path,size))
    local_duplicates=[]
    for sha,group in sorted(local_groups.items()):
        target=canonical.get(sha,min(f for f,_ in group))
        for f,size in group:local_duplicates.append(dict(path=f,size=size,tracked=0,sha256=sha,canonical=target,matches_tracked=int(sha in canonical),decision='保留历史/生成副本；默认路径不使用，未加入Git'))
    write_csv('local_matlab_duplicates.csv',['path','size','tracked','sha256','canonical','matches_tracked','decision'],local_duplicates)
    directory_ext=defaultdict(lambda:[0,0])
    for r in rows:
        path=Path(r['path']);directory=path.parts[0] if len(path.parts)>1 else '[root]';key=(directory,path.suffix.lower() or '[none]');directory_ext[key][0]+=1;directory_ext[key][1]+=r['size']
    write_csv('tracked_directory_extensions.csv',['directory','extension','file_count','size'],[dict(directory=k[0],extension=k[1],file_count=v[0],size=v[1]) for k,v in sorted(directory_ext.items())])
    references=[dict(path=r['path'],referenced_by=sorted(refs[Path(r['path']).stem])) for r in rows if r['path'].endswith('.m')]
    write_json('matlab_references.json',references)
    totals=defaultdict(lambda:[0,0,0])
    for r in rows:
        a=totals[r['category']];a[0]+=1;a[1]+=r['size'];a[2]+=r['path'].endswith('.m')
    write_csv('file_category_summary.csv',['category','file_count','size','matlab_files','activity','action'],[dict(category=k,file_count=v[0],size=v[1],matlab_files=v[2],activity='核心活跃/兼容按需' if k in ('核心运行','兼容/旧API及研究分析') else '测试/历史/工具按职责',action='保留；明确用途与候选，不直接删除') for k,v in sorted(totals.items())])
    stats=dict(snapshot_commit=git('rev-parse','HEAD').strip(),generated_utc=datetime.now(timezone.utc).isoformat(),tracked_files=len(files),tracked_matlab_files=sum(f.endswith('.m') for f in files),local_matlab_files=sum(r['file_count'] for r in local if r['extension']=='.m'),local_unique_matlab_contents=len(local_groups),local_matlab_matches_tracked=sum(r['matches_tracked'] for r in local_duplicates),local_file_count=sum(r['file_count'] for r in local),local_bytes=sum(r['size'] for r in local),exact_duplicate_groups=len({r['sha256'] for r in duplicates}),same_name_groups=len(collisions),orphan_candidates=sum(r['orphan_candidate'] for r in rows),scope='Git index paths; last_commit as of snapshot_commit; local generated directories are aggregated and never staged')
    write_json('file_inventory_stats.json',stats)
    fields=list(rows[0])
    # 大小统计迭代到稳定，包含清单自身；哈希仍标识写出前的输入快照。
    for _ in range(6):
        for r in rows:r['size']=(ROOT/r['path']).stat().st_size
        totals=defaultdict(lambda:[0,0,0]);directory_ext=defaultdict(lambda:[0,0])
        for r in rows:
            a=totals[r['category']];a[0]+=1;a[1]+=r['size'];a[2]+=r['path'].endswith('.m')
            path=Path(r['path']);key=(path.parts[0] if len(path.parts)>1 else '[root]',path.suffix.lower() or '[none]');directory_ext[key][0]+=1;directory_ext[key][1]+=r['size']
        write_csv('file_category_summary.csv',['category','file_count','size','matlab_files','activity','action'],[dict(category=k,file_count=v[0],size=v[1],matlab_files=v[2],activity='核心活跃/兼容按需' if k in ('核心运行','兼容/旧API及研究分析') else '测试/历史/工具按职责',action='保留；明确用途与候选，不直接删除') for k,v in sorted(totals.items())])
        write_csv('tracked_directory_extensions.csv',['directory','extension','file_count','size'],[dict(directory=k[0],extension=k[1],file_count=v[0],size=v[1]) for k,v in sorted(directory_ext.items())])
        stats['tracked_bytes']=sum(r['size'] for r in rows);write_json('file_inventory_stats.json',stats)
        write_csv('file_inventory.csv',fields,rows)
        if all(r['size']==(ROOT/r['path']).stat().st_size for r in rows):break
    return stats

def check():
    files=set(tracked());rows=list(csv.DictReader((OUT/'file_inventory.csv').open(encoding='utf-8-sig')));covered={r['path'] for r in rows if r['tracked']=='1'}
    errors=[];warnings=[]
    if covered!=files:errors.append(dict(kind='inventory_coverage',missing=sorted(files-covered),extra=sorted(covered-files)))
    conflicts=json.loads((OUT/'function_collisions.json').read_text(encoding='utf-8'))
    for c in conflicts:
        if c['active_conflict']:errors.append(dict(kind='active_function_conflict',**c))
    manifest=OUT/'evidence/stage6a_manifest.json'
    if manifest.exists():
        for item in json.loads(manifest.read_text(encoding='utf-8')):
            data=(ROOT/item['canonical']).read_bytes();stem=Path(item['original']).stem
            restored=data.replace(('stage6a_'+stem+'(').encode(),(stem+'(').encode(),1)
            if hashlib.sha256(data).hexdigest()!=item['canonical_sha256'] or hashlib.sha256(restored).hexdigest()!=item['original_git_sha256']:errors.append(dict(kind='evidence_changed',path=item['canonical']))
            if hashlib.sha256((ROOT/item['original']).read_bytes()).hexdigest()!=item['wrapper_sha256']:errors.append(dict(kind='wrapper_changed',path=item['original']))
    temporary=[];large=[];links=0
    for f in sorted(files):
        path=ROOT/f
        if any(x in Path(f).parts for x in ('__pycache__','.pytest_cache','.ruff_cache')) or path.suffix.lower() in ('.pyc','.asv','.tmp','.log') or (f.split('/')[0] in LOCAL and f not in ARCHIVE_INDEX):temporary.append(f)
        if path.stat().st_size>5*1024**2:large.append(dict(path=f,size=path.stat().st_size,decision='固定证据/参考保留' if category(f) in ('测试/冻结','文档/证据','历史脚本/证据','工具/第三方','核心运行') else '待审'))
        if path.suffix.lower()!='.md' or f.startswith('third_party/'):continue
        text=path.read_text(encoding='utf-8-sig');text=re.sub(r'```.*?```','',text,flags=re.S)
        for raw in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',text):
            target=raw.strip().split(' "',1)[0].strip('<>')
            if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',target) or target.startswith('#'):continue
            name=unquote(target.split('#')[0]);destination=(path.parent/name).resolve();links+=1
            if not destination.is_relative_to(ROOT):warnings.append(dict(kind='external_local_reference_not_accessed',file=f,target=target));continue
            relative=destination.relative_to(ROOT).as_posix()
            if relative.split('/')[0] in LOCAL and relative not in ARCHIVE_INDEX:
                warnings.append(dict(kind='local_generated_link',file=f,target=target,exists=destination.exists()));continue
            if not destination.exists():errors.append(dict(kind='broken_link',file=f,target=target))
    if temporary:errors.append(dict(kind='tracked_temporary',paths=temporary))
    errors.extend(dict(kind='unreviewed_large_file',**r) for r in large if r['decision']=='待审')
    local_temporary=[]
    for base,dirs,names in os.walk(ROOT,followlinks=False):
        relative=Path(base).relative_to(ROOT)
        dirs[:]=[d for d in dirs if d!='.git' and d not in LOCAL and not Path(base,d).is_symlink()]
        for name in names:
            path=Path(base,name);f=path.relative_to(ROOT).as_posix()
            if f not in files and (path.suffix.lower() in ('.pyc','.asv','.tmp') or '__pycache__' in path.parts):local_temporary.append(f)
    report=dict(local_temporary_in_source=local_temporary,passed=not errors,inventory_paths=len(covered),local_links_checked=links,errors=errors,warnings=warnings,large_files=large,orphan_candidates='file_orphan_candidates.csv',conflict_policy='Only ca_setup active directories conflict; fixtures/third-party scripts remain listed, not deleted')
    write_json('repo_hygiene_checks.json',report)
    print(json.dumps(dict(passed=report['passed'],tracked=len(covered),links=links,errors=len(errors),warnings=len(warnings))))
    if errors:raise SystemExit(1)
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    if args.check:check()
    else:print(json.dumps(generate(),ensure_ascii=True))
