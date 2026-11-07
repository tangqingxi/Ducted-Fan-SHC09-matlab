"""只读扫描仓库工作树；所有清单仅写入仓库外的本阶段交付目录。"""
from pathlib import Path
from collections import defaultdict,Counter
import csv
import datetime
import hashlib
import json
import os
import re
import subprocess
import time

ROOT=Path(r'E:\Ducted-Fan-SHC09-matlab')
OUT=Path(__file__).resolve().parents[1]
TOPS=set('allocators analysis apps archive compat configs docs drivers effectiveness examples experiments figures lib logs models modules platform research results tests third_party tools'.split())


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)


def write(name,rows,fields=None):
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields or list(rows[0]));w.writeheader();w.writerows(rows)


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def main():
    started=time.time();tracked=set(git('ls-files','-z').decode('utf-8').split('\0'))-{''}
    files=[];errors=[];special=[]
    def visit(folder):
        try:
            entries=list(os.scandir(folder))
        except OSError as e:
            errors.append(dict(path=str(folder),error=str(e)));return
        for e in entries:
            p=Path(e.path);rel=p.relative_to(ROOT).as_posix()
            if rel=='.git':
                special.append(dict(path=rel,reason='Git元数据，不属于工作树文件；不递归读取对象库'));continue
            try:
                st=e.stat(follow_symlinks=False)
                if e.is_symlink() or p.is_junction():
                    special.append(dict(path=rel,reason='链接或junction，不跟随到仓库外'))
                    files.append(dict(path=rel,size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,is_link=True));continue
                if e.is_dir(follow_symlinks=False):visit(p)
                elif e.is_file(follow_symlinks=False):files.append(dict(path=rel,size_bytes=st.st_size,mtime_ns=st.st_mtime_ns,is_link=False))
            except OSError as ex:errors.append(dict(path=rel,error=str(ex)))
    visit(ROOT);files.sort(key=lambda x:x['path'])
    filemap={r['path']:r for r in files}
    (OUT/'evidence/FILE_METADATA.json').write_text(json.dumps(files,ensure_ascii=False),encoding='utf-8')
    texts={};jsons={};code={}
    excluded=('.venv/','apps/windtrace/dist/','apps/windtrace/build/','third_party/','results/windtrace_')
    for row in files:
        rel=row['path'];p=ROOT/rel
        if row['is_link'] or rel.startswith(excluded) or '__pycache__/' in rel:continue
        suffix=p.suffix.lower()
        if suffix in {'.m','.py','.md','.json','.ps1','.cmd','.bat','.cpp','.h','.hpp','.toml','.spec'} and row['size_bytes']<4_000_000:
            try:text=p.read_text(encoding='utf-8-sig')
            except (OSError,UnicodeError):continue
            texts[rel]=text
            if suffix in {'.m','.py','.cpp','.h','.hpp','.ps1','.cmd','.spec'}:code[rel]=text
            if suffix=='.json':
                try:jsons[rel]=json.loads(text)
                except ValueError:pass
    (OUT/'evidence/JSON_PATHS.json').write_text(json.dumps(list(jsons),indent=2),encoding='utf-8')
    locks=defaultdict(set);lock_rows=[]
    for rel,value in jsons.items():
        lower=Path(rel).name.lower()
        if not any(k in lower for k in ('lock','source','manifest','numerical')):continue
        def walk(obj):
            if isinstance(obj,dict):
                path=obj.get('path');digest=obj.get('sha256') or obj.get('sha')
                if isinstance(path,str) and isinstance(digest,str) and len(digest)==64:
                    norm=path.replace('\\','/').removeprefix('./')
                    if norm.startswith(ROOT.as_posix()+'/'):norm=norm[len(ROOT.as_posix())+1:]
                    present=norm in filemap
                    kind='formal_lock' if 'formal_lock' in lower else 'source_lock' if 'lock' in lower else 'source_manifest'
                    lock_rows.append(dict(lock=rel,lock_type=kind,path=norm,sha256=digest,path_present=present))
                    if present and kind in {'formal_lock','source_lock'}:locks[norm].add(rel)
                for v in obj.values():walk(v)
            elif isinstance(obj,list):
                for v in obj:walk(v)
        walk(value)
    write('LOCK_REFERENCES.csv',lock_rows,['lock','lock_type','path','sha256','path_present'])
    bystem=defaultdict(list)
    for rel in code:
        if Path(rel).suffix in {'.m','.py'}:bystem[Path(rel).stem].append(rel)
    references=defaultdict(set);edges=[]
    for src,text in texts.items():
        if src.startswith(('results/','figures/','logs/')):continue
        names=set(re.findall(r'\b([A-Za-z]\w*)\s*\(',text))|set(re.findall(r'@([A-Za-z]\w*)',text))
        for name in names:
            for target in bystem.get(name,[]):
                if target==src:continue
                references[target].add(src)
                edges.append(dict(source=src,target=target,kind='static_call_or_handle_candidate',evidence=name,confidence='candidate_not_runtime_trace'))
        normalized=text.replace('\\','/')
        for target in re.findall(r'(?<!\w)((?:'+ '|'.join(sorted(TOPS))+r')/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+)',normalized):
            if target in filemap and target!=src:
                references[target].add(src);edges.append(dict(source=src,target=target,kind='explicit_path_literal',evidence=target,confidence='verified_literal_reference'))
    write('DEPENDENCY_EDGES.csv',edges,['source','target','kind','evidence','confidence'])
    categories={
        'allocators':('控制分配插件','src/allocation/plugins/'),'analysis':('离线分析与导出','analysis/'),
        'platform':('运行时/总线/调度/模块','src/runtime/'),'modules':('估计桥接与分配接口','src/modules/'),
        'models':('机体物理与冻结参考','airframes/'),'drivers':('执行器驱动','src/drivers/'),
        'lib':('公共数学与滤波','src/lib/'),'effectiveness':('控制效能插件','src/effectiveness/'),
        'configs':('公共参数/场景协议','configs/'),'experiments':('历史试验与协议驱动','studies/legacy_experiments/'),
        'research':('研究控制/场景/冻结来源','studies/'),'tests':('测试与冻结夹具','tests/'),
        'third_party':('第三方源码与许可','third_party/'),'compat':('历史兼容API','src/compat/'),
        'tools':('维护/导出/交付工具','tools/'),'docs':('工程文档与验证证据','docs/'),
        'examples':('轻量研究交付','examples/'),'figures':('派生图表与指标','results/_migration_pending/figures/'),
        'logs':('飞行容器与日志','results/_migration_pending/logs/'),'results':('本地实验/软件产物','results/_migration_pending/'),
        'apps':('应用与查看器','apps/'),'archive':('历史归档索引','archive/')}
    inventory=[];migration=[];totals=defaultdict(lambda:[0,0,0]);actions=Counter()
    for row in files:
        rel=row['path'];p=Path(rel);top=p.parts[0] if len(p.parts)>1 else '(root)';ext=p.suffix.lower() or '(none)'
        category,prefix=categories.get(top,('根目录入口/说明',''))
        retention='source_or_document';action='MOVE_CANDIDATE';risk='medium';phase='Phase3';purpose=category
        if top in categories:target=prefix+'/'.join(p.parts[1:])
        else:target=rel;action='KEEP';phase='Phase2';risk='low'
        if top=='.venv':
            category='本地Python运行环境';retention='rebuildable_after_dependency_capture';action='REVIEW_REQUIRED';target='(recreate .venv after dependency/version capture)';phase='Phase4';risk='high';purpose='迁入本机的Python依赖，不作项目源码迁移'
        elif '__pycache__' in p.parts or top=='.pytest_cache' or ext in {'.pyc','.tmp','.asv'}:
            category='缓存/临时文件';retention='conditional_disposable';action='DELETE_CANDIDATE';target='(none; candidate only)';phase='Phase4';risk='low';purpose='先排除独有失败证据/在用文件，再审批清理'
        elif rel.startswith('apps/windtrace/dist/'):
            category='当前Viewer运行包';retention='protect_installed_runtime';action='KEEP';target=rel;phase='Phase5';risk='high';purpose='当前EXE及依赖，快捷方式仍依赖此位置'
        elif rel.startswith('apps/windtrace/'):
            category='WindTrace独立仓库候选';retention='source_or_viewer_asset';action='MOVE_CANDIDATE';target='WindTrace/'+rel.removeprefix('apps/windtrace/');phase='Phase5';risk='high';purpose='拆分至独立仓库，再以固定提交submodule接入'
        elif top=='results' and p.parts[1].startswith(('windtrace_app_','windtrace_build_')):
            category='Viewer构建/回滚软件产物';retention='review_rollback_artifact';action='ARCHIVE_CANDIDATE';target='artifacts/windtrace/'+ '/'.join(p.parts[1:]);phase='Phase4';risk='high';purpose='构建和回滚备份，不应混入数值实验批次'
        elif top in {'results','logs','figures','examples'}:
            retention='retain_evidence_pending_batch_mapping';action='REVIEW_REQUIRED';phase='Phase4';risk='high';purpose='按RESULTS_BATCHES与实验身份映射后决定目标，不按前缀直接迁移'
        elif top=='third_party' or rel.startswith('models/shc09/reference/'):
            action='KEEP';target=rel;retention='frozen_third_party_or_reference';risk='high';phase='Phase3'
        elif re.fullmatch(r'codex-repo-\d+\.md',rel):
            category='历史Agent报告';retention='immutable_historical_report';action='ARCHIVE_CANDIDATE';target='docs/agent-reports/legacy/'+rel;phase='Phase6';risk='medium'
        if locks.get(rel):
            retention='frozen_source_or_evidence';risk='high';purpose+='；被既有来源锁引用'
        refs=sorted(references.get(rel,set()))
        inventory.append(dict(path=rel,size_bytes=row['size_bytes'],tracked=rel in tracked,file_type=ext,category=category,
            current_purpose=purpose,referenced_by=';'.join(refs),retention_class=retention,proposed_action=action,risk=risk,
            mtime_ns=row['mtime_ns'],source_locks=';'.join(sorted(locks.get(rel,set()))),reference_note='静态调用/文本候选，不表示已验证运行覆盖'))
        verification='检查引用/相对路径和Git追溯；保留原字节'
        if risk=='high':verification+='；验证来源锁/输入签名/冻结日志；必要时Phase2后另获授权再作数值回归'
        if category=='缓存/临时文件':verification='确认未被进程使用、无独有证据；删除清单人工审批'
        migration.append(dict(current_path=rel,target_path=target,category=category,action=action,
            dependency=';'.join(sorted(locks.get(rel,set()))) or ';'.join(refs[:15]) or 'unknown_or_no_static_reference',
            compatibility_risk=risk,verification_required=verification,execution_phase=phase,approval_required=action!='KEEP'))
        totals[top][0]+=1;totals[top][1]+=row['size_bytes'];totals[top][2]+=int(rel in tracked);actions[action]+=1
    write('FILE_INVENTORY.csv',inventory)
    write('MIGRATION_MATRIX.csv',migration)
    write('DIRECTORY_SUMMARY.csv',[dict(directory=k,files=v[0],size_bytes=v[1],tracked_files=v[2]) for k,v in sorted(totals.items(),key=lambda kv:-kv[1][1])])
    write('SCAN_ERRORS.csv',errors,['path','error']);write('SCAN_SCOPE_EXCLUSIONS.csv',special,['path','reason'])
    headings=[];reports=[];fingerprints=[]
    for rel,text in texts.items():
        if rel in {'README.md','AGENTS.md','HANDOFF.md','CHANGELOG.md'} or re.fullmatch(r'codex-repo-\d+\.md',rel):
            headings.append(dict(path=rel,headings=' | '.join(re.findall(r'^#{1,3} (.*)$',text,re.M)),sha256=sha(ROOT/rel)))
        if re.fullmatch(r'codex-repo-\d+\.md',rel):
            title=next((line.lstrip('# ').strip() for line in text.splitlines() if line.startswith('#')),'unknown')
            reports.append(dict(current_path=rel,title=title,size_bytes=filemap[rel]['size_bytes'],sha256=sha(ROOT/rel),
                target_path='docs/agent-reports/legacy/'+rel,action='ARCHIVE_CANDIDATE',content_policy='逐字节保留；仅在新索引增加当前结论/更正指向'))
        if rel in code and not rel.startswith(('docs/validation/','apps/windtrace/')):
            fingerprints.append(dict(path=rel,size_bytes=filemap[rel]['size_bytes'],sha256=sha(ROOT/rel)))
    write('ROOT_DOCUMENT_INDEX.csv',headings)
    write('AGENT_REPORT_MIGRATION.csv',sorted(reports,key=lambda x:int(re.search(r'\d+',x['current_path'])[0])))
    write('SOURCE_FINGERPRINTS.csv',fingerprints)
    summary=dict(scanned_files=len(files),bytes=sum(x['size_bytes'] for x in files),tracked_present=sum(x['path'] in tracked for x in files),
        tracked_total=len(tracked),tracked_missing=sorted(tracked-filemap.keys()),source_text_files=len(texts),code_files_scanned=len(code),
        static_edges=len(edges),locked_existing_files=len(locks),actions=dict(actions),errors=len(errors),elapsed_s=time.time()-started)
    (OUT/'evidence/SCAN_SUMMARY.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))


if __name__=='__main__':main()
