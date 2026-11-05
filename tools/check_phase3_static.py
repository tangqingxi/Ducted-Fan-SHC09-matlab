"""静态检查 Phase3 C4/W3 路径、注册表与源码保护，不冒充 MATLAB which。"""
import argparse
import collections
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path


BASELINE = 'b60080f811a969e00eaefb0dc56e419b6cf4d4ea'
C4_PLAN_SHA256 = 'b6234a6b2606e04fd1372fb86023d4bd4e358e9653f508e6e731764c3a8a050e'
PARAM_OLD_SHA256 = '9a12a7acbc100a345a4e8b5e80177ce2c737a1758250218713dd8920ef6af610'
PARAM_NEW_SHA256 = '5e560065f9392a07ea9c25e07398b9066b7472a6d7b8a2c9d8a9566f21331050'
COMPANIONS = {
    '.gitattributes',
    'ca_setup.m',
    'analysis/allocation_comparison_engine.m',
    'tools/check_phase3_static.py',
    'HANDOFF.md',
    'plan.md',
    'docs/repository_map.md',
    'docs/refactor/PHASE3_MAPPING.md',
    'docs/guides/architecture.md',
    'effectiveness/README.md',
}
CRLF_TARGETS = {
    'airframes/shc09/ca_model.m',
    'airframes/shc09/ca_shc09_parameters.m',
    'dynamics/shc09/plant/ca_plant_init.m',
    'dynamics/shc09/plant/ca_plant_step.m',
    'dynamics/shc09/nonlinear_6dof/ca_shc09_aerodynamics.m',
    'dynamics/shc09/hover_reduced_order/ca_model_hover.m',
}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args]).decode('utf-8')


def check(root, baseline, plan_file, inventory_file):
    assert baseline == BASELINE, '只允许核对已冻结的 C4 迁移基准。'
    assert sha256(plan_file) == C4_PLAN_SHA256, 'C4 逐文件映射身份不匹配。'
    rows = list(csv.DictReader(plan_file.open(encoding='utf-8', newline='')))
    assert len(rows) == 17
    moves = {row['old_path']: row['target_path'] for row in rows if row['action'] == 'MOVE'}
    keeps = {row['old_path'] for row in rows if row['action'] == 'KEEP'}
    assert len(moves) == 8 and len(set(moves.values())) == 8
    assert len(keeps) == 9
    inventory = json.loads(inventory_file.read_text(encoding='utf-8'))
    assert len(inventory) == 1762
    baseline_paths = set(git(root, 'ls-tree', '-r', '--name-only', baseline).splitlines())
    assert set(inventory) == baseline_paths, 'C4 迁移前 raw 清单必须完整。'

    # 8 个活动文件：7 个纯移动逐字节不变；参数文件只允许冻结 reference 路径补丁。
    for source, target in moves.items():
        row = next(r for r in rows if r['old_path'] == source)
        assert inventory[source] == row['raw_sha256'], source
        assert not (root / source).exists(), source
        assert (root / target).is_file(), target
        actual = sha256(root / target)
        if source == 'models/shc09/ca_shc09_parameters.m':
            assert actual == PARAM_NEW_SHA256, target
            text = (root / target).read_text(encoding='utf-8-sig')
            assert "root=fileparts(fileparts(folder));" in text
            assert "reference=fullfile(root,'models','shc09','reference');" in text
            assert "d=load(fullfile(reference,'duct_raw.mat'));" in text
            assert "w=load(fullfile(reference,'wing_raw.mat'));" in text
            assert "fullfile(folder,'reference'" not in text
        else:
            assert actual == row['raw_sha256'], target

    # 8 个冻结 reference 与原场景预设必须原位、原字节。
    for row in rows:
        if row['action'] != 'KEEP':
            continue
        path = row['old_path']
        assert (root / path).is_file(), path
        assert sha256(root / path) == inventory[path], path

    # 配套文件之外，C2/C3 既有文件必须保持字节；移动文件按目标路径核对。
    for source, expected in inventory.items():
        if source in COMPANIONS or source in moves:
            continue
        assert (root / source).is_file(), source
        assert sha256(root / source) == expected, source

    # 精确 -text 规则只作用于 6 个 CRLF 目标，禁止全仓 renormalize。
    attributes = (root / '.gitattributes').read_text(encoding='utf-8')
    for target in CRLF_TARGETS:
        assert f'/{target} -text' in attributes, target
        attr = git(root, 'check-attr', 'text', '--', target).strip()
        assert attr.endswith('unset'), attr

    # Git 变更集合必须恰好是 8 删、8 增、10 个已批准配套修改。
    changes = git(root, 'diff', '--no-renames', '--name-status', baseline, '--').splitlines()
    actual_diff = {line.split('\t')[1]: line.split('\t')[0] for line in changes}
    expected_diff = {source: 'D' for source in moves}
    expected_diff.update({target: 'A' for target in moves.values()})
    expected_diff.update({path: 'M' for path in COMPANIONS})
    assert actual_diff == expected_diff, '变更集合超出 C4 批准范围或缺少配套修订。'
    expected_paths = (baseline_paths - set(moves)) | set(moves.values())
    tracked_paths = {p for p in git(root, 'ls-files', '-z').split('\0') if p}
    assert tracked_paths == expected_paths, 'Git 索引中存在未批准的路径变化。'
    others = [p for p in git(root, 'ls-files', '--others', '--exclude-standard', '-z').split('\0') if p]
    assert not others or all(p.startswith('.dsh-plugins/') for p in others), '发现任务外未跟踪文件。'

    # ca_setup 显式布局：新旧机型路径、C4 dynamics 与 reference adapter 路径必须存在且唯一。
    setup = (root / 'ca_setup.m').read_text(encoding='utf-8-sig')
    block = setup.split('layouts = {', 1)[1].split('};', 1)[0]
    layouts = re.findall(r"'([^']*)'\s*,\s*'([^']*)'", block)
    layout_dirs = {p for row in layouts for p in row if p}
    for required in ('airframes/shc09', 'dynamics/shc09/plant',
                     'dynamics/shc09/nonlinear_6dof',
                     'dynamics/shc09/hover_reduced_order', 'src/control/reference'):
        assert required in layout_dirs and (root / required).is_dir(), required
    registry = (root / 'allocators/registry.m').read_text(encoding='utf-8-sig')
    plugins = re.findall(r"entry\('([^']+)','([^']+)',@(\w+),@(\w+)\)", registry)
    assert len(plugins) == 6
    effect = (root / 'src/effectiveness/effectiveness_registry.m').read_text(encoding='utf-8-sig')
    assert len(re.findall(r'@(\w+)', effect)) == 2, '效能工厂数量必须保持 2。'
    for directory in re.findall(r"'(effectiveness/[^']+)'", effect):
        migrated = root / 'src' / directory
        original = root / directory
        assert migrated.is_dir() or original.is_dir(), directory
        layout_dirs.add(('src/' + directory) if migrated.is_dir() else directory)
    for factory in re.findall(r'@(\w+)', effect):
        assert any((root / d / (factory + '.m')).is_file() for d in layout_dirs | {'.'}), factory

    # Engine：C4 前 121 项按执行单映射后仍为 121 项，8 条路径改变、无漏计/重复。
    engine = (root / 'analysis/allocation_comparison_engine.m').read_text(encoding='utf-8')
    engine_folders = re.findall(r'"([^"\n]+)"', engine.split('folders=[', 1)[1].split('];', 1)[0])
    engine_paths = {p.relative_to(root).as_posix() for d in engine_folders
                    for p in (root / d).rglob('*.m')}
    engine_paths.add('experiments/ca_mismatch_protocol.m')
    baseline_engine = git(root, 'show', f'{baseline}:analysis/allocation_comparison_engine.m')
    baseline_folders = re.findall(
        r'"([^"\n]+)"', baseline_engine.split('folders=[', 1)[1].split('];', 1)[0])
    old_engine = {p for p in inventory
                  if p.endswith('.m') and any(p.startswith(d + '/') for d in baseline_folders)}
    old_engine.add('experiments/ca_mismatch_protocol.m')
    expected_engine = {moves.get(p, p) for p in old_engine}
    assert len(old_engine) == 121, len(old_engine)
    assert engine_paths == expected_engine, 'engine 集合必须与 C4 映射逐项一致。'
    assert len(engine_paths) == 121, len(engine_paths)
    moved_matlab = {t for s, t in moves.items() if s.endswith('.m')}
    assert len(moved_matlab) == 8 and moved_matlab <= engine_paths

    return {
        'status': 'PASS', 'mode': 'STATIC_ONLY', 'baseline': baseline,
        'plan_sha256': C4_PLAN_SHA256,
        'inventory_sha256': sha256(inventory_file),
        'operations': {'MOVE': 8, 'KEEP': 9},
        'raw_bytes_verified': len(inventory) - len(COMPANIONS) - 8,
        'engine_file_count': len(engine_paths),
        'engine_paths_changed': len(moved_matlab),
        'parameter_old_sha256': PARAM_OLD_SHA256,
        'parameter_new_sha256': PARAM_NEW_SHA256,
        'ca_setup_raw_sha256': sha256(root / 'ca_setup.m'),
        'tool_sha256': sha256(Path(__file__).resolve()),
        'git_changes': changes,
        'crlf_targets': sorted(CRLF_TARGETS),
        'layouts': layouts,
        'allocator_count': len(plugins), 'effect_count': 2,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--baseline', default=BASELINE)
    parser.add_argument('--plan', type=Path, required=True, help='已冻结且 SHA 固定的 C4 映射。')
    parser.add_argument('--inventory', type=Path, required=True, help='C4 迁移前完整 raw SHA 清单。')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = check(args.root, args.baseline, args.plan, args.inventory)
    content = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        with args.output.open('w', encoding='utf-8', newline='\n') as handle:
            handle.write(content)
            handle.write('\n')
    print('PASS: static C4 path, registry and protected-file scope checks')
