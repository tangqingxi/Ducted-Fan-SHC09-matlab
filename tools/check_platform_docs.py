from pathlib import Path
import argparse,re,json
from urllib.parse import unquote
# 仅检查仓库内文档链接，不联网、不访问外部工程。
r=Path(__file__).resolve().parents[1]
blocked={'archive','results','third_party','.git','build'}
files=[p for p in r.rglob('*.md') if not any(x in blocked for x in p.relative_to(r).parts)]
errors=[];count=0
for p in files:
 s=p.read_text(encoding='utf-8-sig')
 for raw in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',s):
  target=raw.strip().split(' "',1)[0].strip('<>')
  if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',target) or target.startswith('#'):continue
  path=unquote(target.split('#',1)[0]);count+=1
  if not (p.parent/path).exists():errors.append({'file':str(p.relative_to(r)),'link':target})
readme=(r/'README.md').read_text(encoding='utf-8')
if re.search(r'(?i)\bC:',readme):errors.append({'file':'README.md','error':'含禁用的旧盘符路径'})
report={'markdown_files':len(files),'relative_links_checked':count,'readme_lines':len(readme.splitlines()),'broken_links':errors,'passed':not errors}
print(json.dumps(report,ensure_ascii=False,indent=2))
parser=argparse.ArgumentParser();parser.add_argument('--output');args=parser.parse_args()
if args.output:
 destination=(r/args.output).resolve();assert destination.is_relative_to(r)
 destination.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert not errors,'文档相对链接检查失败。'
