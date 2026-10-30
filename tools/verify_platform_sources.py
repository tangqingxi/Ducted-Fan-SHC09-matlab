from pathlib import Path
import hashlib
import json

# 固定路径原件及可搬迁算法均按原字节验证，不依赖父工程。
root = Path(__file__).resolve().parents[1]
records = json.loads((root / 'tests/baseline/protected_sources.json').read_text(encoding='utf-8'))
for item in records:
    if item['category'] == 'fixed_path':
        paths = [root / item['path']]
    else:
        paths = [p for p in root.rglob(item['name']) if not any(x in {'results', 'archive', 'third_party', 'legacy_reference'} for x in p.relative_to(root).parts)]
    assert len(paths) == 1 and paths[0].is_file(), item['path']
    assert hashlib.sha256(paths[0].read_bytes()).hexdigest() == item['sha256'], item['path']
original = root / 'archive/platform_refactor/original_results.json'
if original.is_file():
    for item in json.loads(original.read_text(encoding='utf-8')):
        p = root / item['path']
        assert p.is_file() and p.stat().st_size == item['bytes'] and p.stat().st_mtime_ns == item['mtime_ns'], item['path']
print('固定物理、算法、协议、参考/夹具及既有结果保护检查通过。')
