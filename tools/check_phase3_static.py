"""静态检查 Phase3 路径、注册表与源码保护，不冒充 MATLAB which。"""
import argparse
import collections
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path


BASELINE = 'b2a287ceff34445bb7902890141be7a450d19de9'
PLAN_SHA256 = 'ee0df3e88a46e95ac09f7825d4603de4ceef1cd3393d6aec499337a205b6bedf'
LINK_DOCUMENT = 'docs/reference/f8_protocol.md'
OLD_LINK = b'../../platform/modules/position_control/ca_f8_position_control.m'
NEW_LINK = b'../../src/control/position_control/ca_f8_position_control.m'
COMPANIONS = {'.gitattributes', 'analysis/allocation_comparison_engine.m',
              'tools/build_px4_ecl.py', 'tools/check_phase3_static.py'}


def check(root, baseline, plan_file, inventory_file):
    assert baseline == BASELINE, '只允许核对已批准的C1基准。'
    assert hashlib.sha256(plan_file.read_bytes()).hexdigest() == PLAN_SHA256, '执行单身份不匹配。'
    rows = list(csv.DictReader(plan_file.open(encoding='utf-8')))
    assert collections.Counter(row['operation'] for row in rows) == {'MOVE': 70, 'KEEP': 9, 'DEFER_W6': 2}
    moves = {row['source_path']: row['target_path'] for row in rows if row['operation'] == 'MOVE'}
    assert len(moves) == 70 and len(set(moves.values())) == 70
    inventory = json.loads(inventory_file.read_text(encoding='utf-8'))
    baseline_paths = set(subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', baseline], cwd=root).decode().splitlines())
    assert set(inventory) == baseline_paths, '基准原始字节清单必须完整。'
    for row in rows:
        source, target = row['source_path'], row['target_path']
        assert inventory[source] == row['source_sha256']
        actual = target if row['operation'] == 'MOVE' else source
        assert (root / actual).is_file() and hashlib.sha256((root / actual).read_bytes()).hexdigest() == row['source_sha256'], actual
        if row['operation'] == 'MOVE':
            assert not (root / source).exists(), source
    # 独立补充授权仅允许此文档的一处链接替换，反向替换后必须匹配原raw SHA。
    document = (root / LINK_DOCUMENT).read_bytes()
    assert document.count(NEW_LINK) == 1 and OLD_LINK not in document
    assert hashlib.sha256(document.replace(NEW_LINK, OLD_LINK, 1)).hexdigest() == inventory[LINK_DOCUMENT]
    # 除四份配套文件及精确链接修复，所有基准文件都必须保持原始字节。
    for source, expected in inventory.items():
        if source in COMPANIONS or source == LINK_DOCUMENT:
            continue
        actual = moves.get(source, source)
        assert (root / actual).is_file() and hashlib.sha256((root / actual).read_bytes()).hexdigest() == expected, actual
    expected_paths = (baseline_paths - set(moves)) | set(moves.values())
    tracked_paths = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().strip('\0').split('\0'))
    assert tracked_paths == expected_paths, 'Git索引中存在未批准的路径变化。'
    others = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=root).decode().strip('\0')
    assert not others or all(p.startswith('.dsh-plugins/') for p in others.split('\0')), '发现任务外未跟踪文件。'

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
    # 禁用重命名归并后，精确检查70删除、70新增、四份配套修改及一处链接修复。
    changes = subprocess.check_output(
        ['git', 'diff', '--no-renames', '--name-status', baseline, '--'], cwd=root).decode().splitlines()
    actual_diff = {line.split('\t')[1]: line.split('\t')[0] for line in changes}
    expected_diff = {source: 'D' for source in moves}
    expected_diff.update({target: 'A' for target in moves.values()})
    expected_diff.update({p: 'M' for p in COMPANIONS})
    expected_diff[LINK_DOCUMENT] = 'M'
    assert actual_diff == expected_diff, '变更集合超出批准范围或缺少配套修订。'
    # 新引擎集合必须恰好等于旧集合逐项映射，不能漏计或引入额外源码。
    engine = (root / 'analysis/allocation_comparison_engine.m').read_text(encoding='utf-8')
    engine_folders = re.findall(r'"([^"\n]+)"', engine.split('folders=[', 1)[1].split('];', 1)[0])
    engine_paths = {p.relative_to(root).as_posix() for d in engine_folders for p in (root / d).rglob('*.m')}
    engine_paths.add('experiments/ca_mismatch_protocol.m')
    old_folders = {'platform', 'allocators', 'effectiveness', 'models', 'drivers', 'lib', 'configs', 'modules', 'compat'}
    old_engine = {p for p in inventory if p.endswith('.m') and p.split('/')[0] in old_folders}
    old_engine.add('experiments/ca_mismatch_protocol.m')
    assert engine_paths == {moves.get(p, p) for p in old_engine}
    moved_matlab = {target for source, target in moves.items() if source.endswith('.m')}
    assert len(moved_matlab) == 69 and moved_matlab <= engine_paths
    return {'status': 'PASS', 'mode': 'STATIC_ONLY', 'baseline': baseline,
            'plan_sha256': PLAN_SHA256, 'operations': {'MOVE': 70, 'KEEP': 9, 'DEFER_W6': 2},
            'raw_bytes_verified': len(inventory) - len(COMPANIONS) - 1,
            'engine_file_count': len(engine_paths), 'engine_moved_matlab_covered': len(moved_matlab),
            'layouts': layouts, 'directories_present': sorted(d for d in directories if (root / d).is_dir()),
            'directories_absent_safely_skipped': sorted(d for d in directories if not (root / d).is_dir()),
            'allocator_count': len(plugins), 'active_conflicts': conflicts,
            'historical_duplicates_outside_search_path': historical, 'git_changes': changes,
            'ca_setup_raw_sha256': hashlib.sha256((root / 'ca_setup.m').read_bytes()).hexdigest()}



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--plan', type=Path, required=True, help='已批准且SHA固定的W1执行单。')
    parser.add_argument('--inventory', type=Path, required=True, help='完整C1原始字节SHA清单。')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = check(args.root, args.baseline, args.plan, args.inventory)
    content = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(content, encoding='utf-8')
    print('PASS: static path, registry and protected-file scope checks')
