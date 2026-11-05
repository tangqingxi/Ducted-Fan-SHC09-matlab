"""静态检查 Phase3 路径、注册表与源码保护，不冒充 MATLAB which。"""
import argparse
import collections
import hashlib
import json
import re
import subprocess
from pathlib import Path


def check(root, baseline):
    # 只使用 ca_setup 显式布局和注册目录，不递归扩展 MATLAB 搜索路径。
    setup = (root / 'ca_setup.m').read_text(encoding='utf-8-sig')
    block = setup.split('layouts = {', 1)[1].split('};', 1)[0]
    layouts = re.findall(r"'([^']*)'\s*,\s*'([^']*)'", block)
    directories = {'.'} | {p for row in layouts for p in row if p}
    registry = (root / 'allocators/registry.m').read_text(encoding='utf-8-sig')
    plugins = re.findall(r"entry\('([^']+)','([^']+)',@(\w+),@(\w+)\)", registry)
    assert len(plugins) == 6
    for _, directory, allocate, manifest in plugins:
        directories.add('allocators/' + directory)
        for name in (allocate, manifest):
            assert (root / 'allocators' / directory / (name + '.m')).is_file()
    effect = (root / 'effectiveness/effectiveness_registry.m').read_text(encoding='utf-8-sig')
    for directory in re.findall(r"'(effectiveness/[^']+)'", effect):
        candidate = directory if (root / directory).is_dir() else 'src/' + directory
        assert (root / candidate).is_dir()
        directories.add(candidate)
    for factory in re.findall(r'@(\w+)', effect):
        assert any((root / d / (factory + '.m')).is_file() for d in directories)
    active = collections.defaultdict(list)
    for directory in sorted(directories):
        assert not re.search(r'(^|/)(results|archive|third_party|reference)(/|$)|docs/validation', directory)
        for p in (root / directory).glob('*.m'):
            active[p.name.lower()].append(p.relative_to(root).as_posix())
    conflicts = {k: v for k, v in active.items() if len(v) > 1}
    assert not conflicts, conflicts
    # 全部历史同名文件单独列出；它们不自动进入搜索路径。
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    all_names = collections.defaultdict(list)
    for p in tracked:
        if p.endswith('.m'):
            all_names[Path(p).name.lower()].append(p)
    historical = {k: v for k, v in all_names.items() if len(v) > 1}
    # 两份旧诊断脚本属于冻结证据，明确保留且不加入搜索路径。
    whitelist = {'round5_components.m': [
        'docs/validation/shc09_b_frame_20261104/round5_gnss_slow_20261104/scripts/round5_components.m',
        'docs/validation/shc09_b_frame_20261104/round6_gnss_bias_drift_20261104/scripts/round5_components.m']}
    assert historical == whitelist, historical
    changes = subprocess.check_output(['git', 'diff', '--name-status', baseline, '--'], cwd=root).decode().splitlines()
    for line in changes:
        status, *paths = line.split('\t')
        assert not status.startswith(('D', 'R')), line
        assert not any(p.endswith('.m') and status != 'A' and p != 'ca_setup.m' for p in paths), line
        assert not any(p.endswith(('.mat', '.wtr')) or Path(p).name in ('formal_lock.json', 'source_lock.json') for p in paths), line
    return {'status': 'PASS', 'mode': 'STATIC_ONLY', 'baseline': baseline,
            'layouts': layouts, 'directories_present': sorted(d for d in directories if (root / d).is_dir()),
            'directories_absent_safely_skipped': sorted(d for d in directories if not (root / d).is_dir()),
            'allocator_count': len(plugins), 'active_conflicts': conflicts,
            'historical_duplicates_outside_search_path': historical, 'git_changes': changes,
            'ca_setup_raw_sha256': hashlib.sha256((root / 'ca_setup.m').read_bytes()).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--baseline', default='fdc933694db9c16a0d9ffcd6d9c391b052352d22')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = check(args.root, args.baseline)
    content = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(content, encoding='utf-8')
    print('PASS: static path, registry and protected-file scope checks')
