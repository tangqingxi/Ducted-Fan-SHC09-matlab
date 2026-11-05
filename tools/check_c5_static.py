"""静态检查 C5/W4 研究代码迁移范围与路径，不冒充 MATLAB which。"""
import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path


BASELINE = '661eecc97d29a56e4ba1857abb6f5a6364ef1946'
MAPPING_SHA256 = '00ab9cb69d555b532beae6ad3acb9ff6cdefde55664fc7e8e95611c7352a2354'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args]).decode('utf-8')


def norm(data):
    return data.replace(b'\r\n', b'\n')


def check(root, mapping):
    assert sha(mapping) == MAPPING_SHA256, 'C5 映射身份不匹配。'
    rows = list(csv.DictReader(mapping.open(encoding='utf-8', newline='')))
    assert len(rows) == 83
    moves = [r for r in rows if r['action'] == 'MOVE']
    keeps = [r for r in rows if r['action'] == 'KEEP']
    assert len(moves) == 75 and len(keeps) == 8
    for row in moves:
        source, target = root / row['old_path'], root / row['target_path']
        assert target.is_file(), target
        assert not source.exists(), source
        if row['subtype'] == 'MOVE':
            assert norm(target.read_bytes()) == norm(git(root, 'show', f'{BASELINE}:{row["old_path"]}').encode()), target
    for row in keeps:
        assert (root / row['old_path']).is_file(), row['old_path']
        assert sha(root / row['old_path']) == sha(root / row['old_path']), row['old_path']
        assert norm((root / row['old_path']).read_bytes()) == norm(git(root, 'show', f'{BASELINE}:{row["old_path"]}').encode()), row['old_path']

    setup = (root / 'ca_setup.m').read_text(encoding='utf-8-sig')
    for required in ('src/control/ppid', 'src/navigation', 'src/sensors',
                     'src/runtime/sim', 'studies/ppid_pindi',
                     'studies/legacy_experiments'):
        assert required in setup or required in setup.replace("'", ''), required
    engine = (root / 'analysis/allocation_comparison_engine.m').read_text(encoding='utf-8')
    assert "'studies','legacy_experiments','ca_mismatch_protocol.m'" in engine or \
           'studies/legacy_experiments/ca_mismatch_protocol.m' in engine
    manifest = (root / 'studies/ppid_pindi/ppid_source_manifest.m').read_text(encoding='utf-8-sig')
    for required in ('studies', 'legacy_experiments', 'control', 'navigation',
                     'sensors', 'runtime', 'ppid_estimator_init.m',
                     'ppid_noise.m', 'ppid_sensor_step.m', 'ppid_simulate.m'):
        assert required in manifest, required
    active = [p for p in (root / 'studies').rglob('*.m')]
    active += [p for p in (root / 'src').rglob('*.m')]
    active += [p for p in (root / 'tests').rglob('*.m')]
    active += [p for p in (root / 'tools').rglob('*.m')]
    active += [p for p in (root / 'analysis').rglob('*.m')]
    active += [p for p in root.glob('*.m')]
    offenders = []
    for p in active:
        for line_no, line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(), 1):
            if 'research/' in line or 'experiments/' in line:
                if 'protocol.json' in line or 'formal_lock.json' in line:
                    continue
                offenders.append(f'{p.relative_to(root)}:{line_no}:{line.strip()[:120]}')
    assert not offenders, offenders
    others = [p for p in git(root, 'ls-files', '--others', '--exclude-standard', '-z').split('\0')
              if p and not p.startswith('.dsh-plugins/')]
    assert not others, others
    return {'status': 'PASS', 'baseline': BASELINE, 'mapping_sha256': MAPPING_SHA256,
            'moves': len(moves), 'keeps': len(keeps),
            'protocol_lock_keep': [r['old_path'] for r in keeps],
            'active_path_files': len(active), 'offenders': offenders}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--mapping', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = check(args.root, args.mapping)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(text + '\n', encoding='utf-8', newline='\n')
    print('PASS: C5 static research-code scope checks')
