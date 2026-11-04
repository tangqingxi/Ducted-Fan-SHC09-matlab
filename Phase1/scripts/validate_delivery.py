"""检查外部交付链接并生成最终哈希清单，不改动源仓库。"""
from pathlib import Path
import hashlib
import json
import re

OUT=Path(__file__).resolve().parents[1]


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda:f.read(1048576),b''):
            h.update(data)
    return h.hexdigest()


def main():
    mandatory=['PLAN.md','FILE_INVENTORY.csv','RESULTS_BATCHES.csv','MIGRATION_MATRIX.csv','WINDTRACE_SPLIT_PLAN.md','RISKS_AND_APPROVALS.md','PHASE1_REPORT.md']
    missing=[n for n in mandatory if not (OUT/n).is_file()]
    broken=[]
    links=0
    for doc in OUT.glob('*.md'):
        for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8-sig')):
            if '://' in target or target.startswith('#'):
                continue
            links+=1
            dest=target.split('#',1)[0]
            if dest=='OUTPUT_MANIFEST.json':
                continue
            if not (doc.parent/dest).exists():
                broken.append(dict(document=doc.name,target=target))
    verify=json.loads((OUT/'AUDIT_VERIFICATION.json').read_text(encoding='utf-8'))
    result=dict(required_files=mandatory,missing_files=missing,markdown_file_links_checked=links,broken_links=broken,source_audit_passed=verify['passed'],passed=not missing and not broken and verify['passed'])
    (OUT/'DELIVERY_VERIFICATION.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    # 清单排除自身以避免自引用哈希；其余交付与审计脚本全部登记。
    entries=[]
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.name!='OUTPUT_MANIFEST.json':
            entries.append(dict(path=path.relative_to(OUT).as_posix(),size_bytes=path.stat().st_size,sha256=sha(path)))
    manifest=dict(schema='aerognc.phase1.audit.delivery.v1',repository='E:/Ducted-Fan-SHC09-matlab',head=verify['head'],phase='Phase1',root=OUT.as_posix(),audit_only=True,files=entries)
    (OUT/'OUTPUT_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(**result,delivery_files=len(entries)+1,total_delivery_bytes=sum(r['size_bytes'] for r in entries)),ensure_ascii=True))


if __name__=='__main__':
    main()
