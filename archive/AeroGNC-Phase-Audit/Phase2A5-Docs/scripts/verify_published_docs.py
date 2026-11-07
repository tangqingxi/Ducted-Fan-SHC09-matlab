"""核对GitHub已发布文档字节、服务器Markdown及Mermaid声明，不运行浏览器脚本。"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import html
import json
import re
import subprocess
import urllib.parse
import urllib.request

OUT=Path(__file__).resolve().parents[1]
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')


def git(*args):return subprocess.check_output(['git','-C',str(MAIN),*args])


def main():
    baseline=json.loads((OUT/'evidence/DOCUMENT_BASELINE.json').read_text(encoding='utf-8'))
    validation=json.loads((OUT/'DOCUMENT_LINK_VALIDATION.json').read_text(encoding='utf-8'))
    head=git('rev-parse','HEAD').decode().strip()
    server=git('ls-remote','origin','refs/heads/main').decode().split()[0]
    if head!=server:raise RuntimeError('主仓库远端未同步')
    paths=baseline['allowed_documents']
    changed=git('diff','--name-only',baseline['science_baseline_commit'],head).decode().splitlines()
    if set(changed)!=set(paths):raise RuntimeError('主提交差异超出10份文档')
    remote_tree=json.loads((OUT/'evidence/GITHUB_MAIN_TREE.json').read_text(encoding='utf-8'))
    indexed={r['path']:r for r in remote_tree['documents']}
    def verify(rel):
        url='https://raw.githubusercontent.com/tangqingxi/Ducted-Fan-SHC09-matlab/'+head+'/'+urllib.parse.quote(rel,safe='/')
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'AeroGNC-Docs-ReadOnly'}),timeout=30) as response:
            body=response.read();status=response.status
        expected=git('show',head+':'+rel)
        oid=hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()
        if status!=200 or body!=expected or body!=(MAIN/rel).read_bytes() or indexed[rel]['sha']!=oid or indexed[rel]['size']!=len(body):raise RuntimeError('发布字节不一致：'+rel)
        return dict(path=rel,http_status=status,size_bytes=len(body),sha256=hashlib.sha256(body).hexdigest(),git_blob_oid=oid)
    with ThreadPoolExecutor(max_workers=5) as pool:records=list(pool.map(verify,paths))
    rendered=(OUT/'evidence/GITHUB_README_RENDERED.html').read_text(encoding='utf-8')
    graph=re.search(r'```mermaid\n(.*?)```',(MAIN/'README.md').read_text(encoding='utf-8'),re.S).group(1)
    server_graph=re.search(r'<pre lang="mermaid"[^>]*>(.*?)</pre>',rendered,re.S)
    html_checks=dict(server_markdown_article='class="markdown-body' in rendered,project_heading='SHC09 MATLAB 仿真与控制分配研究平台' in rendered,heading_count=len(re.findall(r'<h[12]\b',rendered)),table_count=rendered.count('<table>'),mermaid_enrichment_container=bool(re.search(r'data-type="mermaid"',rendered)),mermaid_source_preserved=server_graph is not None and html.unescape(server_graph.group(1)).strip()==graph.strip(),parser_error_message='Unable to render rich display' in rendered or 'Syntax error in text' in rendered)
    if not all([html_checks['server_markdown_article'],html_checks['project_heading'],html_checks['mermaid_enrichment_container'],html_checks['mermaid_source_preserved'],not html_checks['parser_error_message']]):raise RuntimeError('服务器Markdown核验失败')
    publication=dict(science_baseline_commit=baseline['science_baseline_commit'],documentation_update_commit=head,current_main_commit=head,remote_main_commit=server,documents_verified=records,main_commit_only_authorized_markdown=True,github_server_markdown=html_checks,browser_visual_validation=dict(status='unavailable_tool_timeout',attempts=['in_app_createBrowserTab timed_out','in_app_getTab timed_out','edge_createBrowserTab timed_out'],limitation='未直接观察GitHub客户端动态SVG；服务器已识别Mermaid容器，原始代码一致，draw.io转换/图像另已验收。'),control_simulation_executed=False)
    (OUT/'evidence/PUBLISHED_MAIN_VERIFICATION.json').write_text(json.dumps(publication,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    validation['documentation_update_commit']=head
    validation['current_main_commit']=head
    validation['github_render_validation']=dict(status='server_markdown_and_diagram_source_verified',client_visual_status='unavailable_tool_timeout',published_document_count=len(records),main_remote_sha_matches=True,server_checks=html_checks)
    validation['limitations'].append('浏览器自动化连续超时；未直接截图确认GitHub客户端SVG，已核对服务器HTML与Mermaid来源并用draw.io转换/查看图像。')
    (OUT/'DOCUMENT_LINK_VALIDATION.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    path=OUT/'DOCUMENT_CHANGE_MANIFEST.csv'
    with path.open(encoding='utf-8',newline='') as f:rows=list(csv.DictReader(f))
    for row in rows:
        row['documentation_update_commit']=head;row['current_main_commit']=head
        row['after_git_blob_oid']=indexed[row['path']]['sha']
    with path.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
    print(json.dumps(dict(main_head=head,remote_main_sha=server,documents_verified=len(records),server_markdown=html_checks,browser_client_visual='unavailable_tool_timeout'),ensure_ascii=True,indent=2))


if __name__=='__main__':main()
