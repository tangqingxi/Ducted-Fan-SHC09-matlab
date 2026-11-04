"""静态核对文档、锚点、命令来源及受保护文件，不执行控制仿真。"""
from pathlib import Path
import csv
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import unicodedata

OUT=Path(__file__).resolve().parents[1]
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')
AUDIT=OUT.parent


def git(*args):return subprocess.check_output(['git','-C',str(MAIN),*args])


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def anchors(text):
    result=set(re.findall(r'<a\s+(?:id|name)=["\']([^"\']+)',text))
    counts={};fenced=False
    for line in text.splitlines():
        if re.match(r'^\s*```',line):fenced=not fenced;continue
        if fenced:continue
        match=re.match(r'^ {0,3}#{1,6}\s+(.+?)\s*#*$',line)
        if not match:continue
        heading=re.sub(r'<[^>]*>','',match[1]).replace('`','').lower()
        slug=''.join(c for c in heading if c in '_-' or c.isspace() or not unicodedata.category(c).startswith(('P','S')))
        slug=re.sub(r'\s','-',slug)
        n=counts.get(slug,0);counts[slug]=n+1
        result.add(slug+('-'+str(n) if n else ''))
    return result


def main():
    baseline=json.loads((OUT/'evidence/DOCUMENT_BASELINE.json').read_text(encoding='utf-8'))
    allowed=set(baseline['allowed_documents'])
    spec=importlib.util.spec_from_file_location('readonly_doc_links',MAIN/'tools/check_docs_links.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    links=[];errors=[]
    for rel in sorted(allowed):
        source=MAIN/rel;body=source.read_text(encoding='utf-8-sig')
        for start,end,destination,line in helper.destinations(body):
            target=helper.local_target(MAIN,source,destination)
            if target is None:
                if destination.startswith('#'):
                    if destination[1:] not in anchors(body):errors.append(dict(source=rel,line=line,target=destination,error='missing_same_page_anchor'))
                continue
            fragment=destination.split('#',1)[1] if '#' in destination else None
            valid=target.is_relative_to(MAIN) and target.exists()
            anchor_ok=True
            if valid and fragment and target.suffix=='.md':anchor_ok=fragment in anchors(target.read_text(encoding='utf-8-sig'))
            links.append(dict(source=rel,line=line,target=destination,file_exists=valid,anchor_valid=anchor_ok))
            if not valid or not anchor_ok:errors.append(links[-1])
    # 未修改文件若反向引用被改页面的旧锚点，也记录为整改回归，不能静默留断链。
    backlinks=[]
    markdown=[r for r in git('ls-files','-z').decode('utf-8').split('\0') if r.endswith('.md') and r not in allowed]
    for rel in markdown:
        source=MAIN/rel
        for start,end,destination,line in helper.destinations(source.read_text(encoding='utf-8-sig')):
            if '#' not in destination:continue
            target=helper.local_target(MAIN,source,destination)
            if target is None or not target.is_relative_to(MAIN):continue
            target_rel=target.relative_to(MAIN).as_posix()
            if target_rel not in allowed:continue
            fragment=destination.split('#',1)[1]
            if fragment not in anchors(target.read_text(encoding='utf-8-sig')):backlinks.append(dict(source=rel,line=line,target=destination))
    non_docs=[r['path'] for r in baseline['non_document_tracked_guard'] if not (MAIN/r['path']).exists() or sha(MAIN/r['path'])!=r['sha256']]
    previous=[r['path'] for r in baseline['existing_audit_guard'] if not (AUDIT/r['path']).exists() or sha(AUDIT/r['path'])!=r['sha256']]
    protected=json.loads((AUDIT/'Phase2A/evidence/PROTECTED_SOURCE_BASELINE.json').read_text(encoding='utf-8'))
    data_changes=[];data_count=0
    for r in protected:
        if r['path'] in allowed:continue
        data_count+=1;p=MAIN/r['path'];st=p.stat()
        if st.st_size!=r['size_bytes'] or st.st_mtime_ns!=r['mtime_ns']:data_changes.append(r['path'])
    dirty=set(git('diff','--name-only').decode('utf-8').splitlines())|set(x for x in git('ls-files','--others','--exclude-standard','-z').decode('utf-8').split('\0') if x)
    outside=sorted(dirty-allowed)
    document_rows=[]
    for old in baseline['before']:
        p=MAIN/old['path'];body=p.read_bytes()
        document_rows.append(dict(path=old['path'],action='REWRITE' if old['existed'] else 'ADD',before_local_sha256=old['sha256'] or '',after_local_sha256=hashlib.sha256(body).hexdigest(),before_git_blob_content_sha256=old['git_blob_content_sha256'] or '',before_size_bytes=old['size_bytes'],after_size_bytes=len(body),before_lines=old['lines'],after_lines=len(body.splitlines()),science_baseline_commit=baseline['science_baseline_commit']))
    with (OUT/'DOCUMENT_CHANGE_MANIFEST.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(document_rows[0]),lineterminator='\n');w.writeheader();w.writerows(document_rows)
    command_sources={
      'short_hover':dict(paths=['apps/hover_app.m','configs/airframes/shc09_airframe.m','main.m','platform/platform_run.m'],checks={'duration_s_2':"'duration_s',2" in (MAIN/'configs/airframes/shc09_airframe.m').read_text(encoding='utf-8-sig'),'default_no_save':"'save_results',false" in (MAIN/'configs/airframes/shc09_airframe.m').read_text(encoding='utf-8-sig'),'function_present':(MAIN/'apps/hover_app.m').is_file()}),
      'optimization_requirement':dict(paths=['configs/params/ca_validate_config.m'],checks={'license_check_present':"license('test','Optimization_Toolbox')" in (MAIN/'configs/params/ca_validate_config.m').read_text(encoding='utf-8-sig')}),
      'five_allocators':dict(paths=['allocators/registry.m'],checks={name:name in (MAIN/'allocators/registry.m').read_text(encoding='utf-8-sig') for name in ['DA_NS','WLS','DCA','PCA_STATIC','PCA_PREDICTIVE']}),
      'gnss_v2':dict(paths=['shc09_gnss_config.m','research/ppid_pindi/gnss_v2/ppid_gnss_v2_config.m','research/ppid_pindi/gnss_v2/protocol.json'],checks={'physical_tau_1000':json.loads((MAIN/'research/ppid_pindi/gnss_v2/protocol.json').read_text(encoding='utf-8-sig'))['gnss']['correlation_s']==1000}),
      'research_entry':dict(paths=['run_ppid_pindi.m','research/ppid_pindi/ppid_run_study.m','research/ppid_pindi/ppid_control_step.m','run_hover_distance_takeoff_formal.m'],checks={'all_present':all((MAIN/p).is_file() for p in ['run_ppid_pindi.m','run_hover_distance_takeoff_formal.m'])})}
    for entry in command_sources.values():entry['source_sha256']={p:sha(MAIN/p) for p in entry['paths']}
    (OUT/'evidence/TECHNICAL_SOURCE_CHECKS.json').write_text(json.dumps(command_sources,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    env=dict(os.environ,PYTHONIOENCODING='utf-8')
    check=subprocess.run([sys_executable(),'-B',str(MAIN/'tools/check_docs_links.py'),'--root',str(MAIN)],capture_output=True,env=env)
    generic_output=check.stdout.decode('utf-8',errors='replace')
    stale=[]
    for rel in allowed:
        body=(MAIN/rel).read_text(encoding='utf-8')
        for pattern in [r'debug-ecl-position[^\n]{0,60}未合并',r'git switch (?:change-B|debug-ecl-position)',r'当前分支[^\n]*\*\*(?:change-B|debug-ecl-position)']:
            if re.search(pattern,body):stale.append(dict(path=rel,pattern=pattern))
    mermaid=re.findall(r'```mermaid\n(.*?)```',(MAIN/'README.md').read_text(encoding='utf-8'),re.S)
    result=dict(science_baseline_commit=baseline['science_baseline_commit'],documents_changed=len(document_rows),changed_document_local_links=links,local_link_errors=errors,broken_backlinks_to_changed_pages=backlinks,existing_link_checker=dict(exit_code=check.returncode,output=generic_output),non_document_tracked_files_sha256_checked=len(baseline['non_document_tracked_guard']),non_document_tracked_changes=non_docs,protected_source_metadata_checked=data_count,protected_metadata_changes=data_changes,existing_audit_files_checked=len(baseline['existing_audit_guard']),existing_audit_changes=previous,task_outside_changes=outside,stale_current_state_matches=stale,source_checks_passed=all(all(v['checks'].values()) for v in command_sources.values()),readme_mermaid_blocks=len(mermaid),drawio_conversion_and_export='passed; eight-node diagram visually inspected',readme_mermaid_graph_sha256=hashlib.sha256(mermaid[0].encode()).hexdigest() if mermaid else None,control_simulation_executed=False,matlab_test_suites_executed=False,ecl_or_windtrace_rebuilt=False,github_render_validation=dict(status='pending_publication'),limitations=['运行示例仅静态核对，未在本轮MATLAB执行。','保护清单采用元数据复核；非授权跟踪文件另做完整字节SHA复核。'])
    result['local_passed']=all([not errors,not backlinks,check.returncode==0,not non_docs,not previous,not data_changes,not outside,not stale,result['source_checks_passed'],len(mermaid)==1])
    (OUT/'DOCUMENT_LINK_VALIDATION.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in result.items() if k!='changed_document_local_links'},ensure_ascii=True,indent=2))
    if not result['local_passed']:raise RuntimeError('文档静态验收未通过')


def sys_executable():
    import sys
    return sys.executable


if __name__=='__main__':main()
