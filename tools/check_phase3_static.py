"""静态检查 Phase3 C3/W2 路径、注册表与源码保护，不冒充 MATLAB which。"""
import argparse
import collections
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path


BASELINE = '269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1'
PLAN_SHA256 = 'e2a63faf87830338df97e172e95a1b3036c33c1a5e5832244565f929529a7e4f'
COMPANIONS = {
    'analysis/allocation_comparison_engine.m',
    'tools/check_phase3_static.py',
    'effectiveness/README.md',
}
README = 'effectiveness/README.md'
OLD_LINKS = (b'(effectiveness_registry.m)', b'(../drivers/actuators)')
NEW_LINKS = (b'(../src/effectiveness/effectiveness_registry.m)', b'(../src/drivers/actuators)')


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check(root, baseline, plan_file, inventory_file):
    assert baseline == BASELINE, '只允许核对已固定的 C2 基准。'
    assert hashlib.sha256(plan_file.read_bytes()).hexdigest() == PLAN_SHA256, '执行单身份不匹配。'
    rows = list(csv.DictReader(plan_file.open(encoding='utf-8-sig', newline='')))
    assert collections.Counter(row['operation'] for row in rows) == {'MOVE': 5, 'KEEP': 33, 'DEFER': 1}
    moves = {row['source_path']: row['target_path'] for row in rows if row['operation'] == 'MOVE'}
    assert len(moves) == 5 and len(set(moves.values())) == 5
    inventory = json.loads(inventory_file.read_text(encoding='utf-8'))
    assert len(inventory) == 1761, 'C2 原始字节清单条目数不符。'
    baseline_paths = set(subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', baseline], cwd=root).decode().splitlines())
    assert set(inventory) == baseline_paths, 'C2 原始字节清单必须完整。'

    # 逐项核对 W2 执行单：MOVE 目标必须存在且字节等于源；KEEP 原位；DEFER README 只允许两链接变化。
    for row in rows:
        source, target = row['source_path'], row['target_path']
        assert inventory[source] == row['raw_sha256'], source
        operation = row['operation']
        if operation == 'MOVE':
            assert not (root / source).exists(), source
            assert (root / target).is_file(), target
            assert sha256(root / target) == row['raw_sha256'], target
        elif operation == 'KEEP':
            assert target == source, source
            assert (root / source).is_file(), source
            assert sha256(root / source) == inventory[source], source
        elif operation == 'DEFER':
            assert source == target == README, source
            document = (root / README).read_bytes()
            reverted = document
            for old, new in zip(OLD_LINKS, NEW_LINKS):
                assert document.count(new) == 1, new
                assert old not in document, old
                reverted = reverted.replace(new, old)
            assert hashlib.sha256(reverted).hexdigest() == inventory[README]
        else:
            raise AssertionError('未批准的操作：%s' % operation)

    # 三份配套文件之外，所有 C2 跟踪文件必须保持原始字节；MOVE 文件按目标路径核对。
    for source, expected in inventory.items():
        if source in COMPANIONS:
            continue
        actual = moves.get(source, source)
        assert (root / actual).is_file(), actual
        assert sha256(root / actual) == expected, actual

    # engine 配套只允许新增 src/effectiveness 显式覆盖，反向删除后必须等于 C2 原字节。
    engine = (root / 'analysis/allocation_comparison_engine.m').read_text(encoding='utf-8')
    engine_baseline = subprocess.check_output(
        ['git', 'show', f'{baseline}:analysis/allocation_comparison_engine.m'], cwd=root).decode('utf-8')
    assert engine.replace(',"src/effectiveness"', '', 1) == engine_baseline, 'engine 配套改动超出批准范围。'
    assert engine.count('"src/effectiveness"') == 1

    # 只允许 5 删除、5 新增、3 修改；其他路径变化一律拒绝。
    changes = subprocess.check_output(
        ['git', 'diff', '--no-renames', '--name-status', baseline, '--'], cwd=root).decode().splitlines()
    actual_diff = {line.split('\t')[1]: line.split('\t')[0] for line in changes}
    expected_diff = {source: 'D' for source in moves}
    expected_diff.update({target: 'A' for target in moves.values()})
    expected_diff.update({path: 'M' for path in COMPANIONS})
    assert actual_diff == expected_diff, '变更集合超出批准范围或缺少配套修订。'
    expected_paths = (baseline_paths - set(moves)) | set(moves.values())
    tracked_paths = {p for p in subprocess.check_output(
        ['git', 'ls-files', '-z'], cwd=root).decode().split('\0') if p}
    assert tracked_paths == expected_paths, 'Git 索引中存在未批准的路径变化。'
    others = [p for p in subprocess.check_output(
        ['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=root).decode().split('\0') if p]
    assert not others or all(p.startswith('.dsh-plugins/') for p in others), '发现任务外未跟踪文件。'

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
    # 效能注册表按唯一实际路径读取；工厂优先新目录，旧目录存在也不能掩盖新实现。
    candidates = [root / 'src/effectiveness/effectiveness_registry.m',
                  root / 'effectiveness/effectiveness_registry.m']
    existing = [p for p in candidates if p.is_file()]
    assert len(existing) == 1, '效能注册表必须只有一个实际路径。'
    effect_registry_path = existing[0].relative_to(root).as_posix()
    effect = existing[0].read_text(encoding='utf-8-sig')
    for directory in re.findall(r"'(effectiveness/[^']+)'", effect):
        migrated = root / 'src' / directory
        original = root / directory
        assert migrated.is_dir() or original.is_dir(), directory
        directories.add(('src/' + directory) if migrated.is_dir() else directory)
    for factory in re.findall(r'@(\w+)', effect):
        assert any((root / d / (factory + '.m')).is_file() for d in directories), factory
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

    # engine 集合必须等于 C2 集合按 W2 执行单逐项映射，不计漏、不多计。
    engine_folders = re.findall(r'"([^"\n]+)"', engine.split('folders=[', 1)[1].split('];', 1)[0])
    engine_paths = {p.relative_to(root).as_posix() for d in engine_folders for p in (root / d).rglob('*.m')}
    engine_paths.add('experiments/ca_mismatch_protocol.m')
    baseline_folders = re.findall(
        r'"([^"\n]+)"', engine_baseline.split('folders=[', 1)[1].split('];', 1)[0])
    old_engine = {p for p in inventory
                  if p.endswith('.m') and any(p.startswith(d + '/') for d in baseline_folders)}
    old_engine.add('experiments/ca_mismatch_protocol.m')
    expected_engine = {moves.get(p, p) for p in old_engine}
    assert len(old_engine) == 121, len(old_engine)
    assert engine_paths == expected_engine, 'engine 集合必须与 C2 逐项映射一致。'
    moved_matlab = {target for source, target in moves.items() if source.endswith('.m')}
    assert len(moved_matlab) == 5 and moved_matlab <= engine_paths
    assert len(engine_paths) == 121, len(engine_paths)
    return {'status': 'PASS', 'mode': 'STATIC_ONLY', 'baseline': baseline,
            'plan_sha256': PLAN_SHA256,
            'inventory_sha256': hashlib.sha256(inventory_file.read_bytes()).hexdigest(),
            'operations': {'MOVE': 5, 'KEEP': 33, 'DEFER': 1},
            'raw_bytes_verified': len(inventory) - len(COMPANIONS),
            'engine_file_count': len(engine_paths),
            'engine_moved_matlab_covered': len(moved_matlab),
            'effectiveness_registry_path': effect_registry_path,
            'readme_reverted_sha256': inventory[README],
            'tool_sha256': sha256(Path(__file__).resolve()),
            'ca_setup_raw_sha256': sha256(root / 'ca_setup.m'),
            'git_changes': changes,
            'layouts': layouts,
            'directories_present': sorted(d for d in directories if (root / d).is_dir()),
            'directories_absent_safely_skipped': sorted(d for d in directories if not (root / d).is_dir()),
            'allocator_count': len(plugins), 'active_conflicts': conflicts,
            'historical_duplicates_outside_search_path': historical}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--plan', type=Path, required=True, help='已批准且SHA固定的W2执行单。')
    parser.add_argument('--inventory', type=Path, required=True, help='完整C2原始字节SHA清单。')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = check(args.root, args.baseline, args.plan, args.inventory)
    content = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        with args.output.open('w', encoding='utf-8', newline='\n') as handle:
            handle.write(content)
            handle.write('\n')
    print('PASS: static path, registry and protected-file scope checks')
