"""只读核对旧数值源码、旧锁与保留交付物；不删除、暂存或提交。"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def capture():
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode('utf-8').split('\0')
    paths = {ROOT/p for p in tracked if p and Path(p).suffix.lower() in {'.m', '.json', '.mat'}}
    for folder in ['results/f8_work_20261101', 'results/f8_reference_20261101', 'results/current_summaries']:
        for path in (ROOT/folder).rglob('*.json'):
            if 'lock' in path.name or 'numerical_sources' in path.name:
                paths.add(path)
    for folder in ['results/hover_distance_takeoff_precheck_20261103_r1', 'logs/wtr/precheck_20261103_r1']:
        paths.update(p for p in (ROOT/folder).rglob('*') if p.is_file())
    paths.add(ROOT/'apps/windtrace/dist/WindTrace/WindTrace.exe')
    assert all(p.is_file() for p in paths)
    assert not git('diff', '--cached', '--name-only')
    return {'head': git('rev-parse', 'HEAD'), 'main': git('rev-parse', 'main'),
            'branch': git('branch', '--show-current'), 'index_empty': True,
            'files': {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['capture', 'verify'])
    parser.add_argument('baseline', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.mode == 'capture':
        args.baseline.parent.mkdir(parents=True, exist_ok=True)
        value = capture()
        with args.baseline.open('x', encoding='utf-8') as stream:
            json.dump(value, stream, indent=2, ensure_ascii=False)
        print('PROTECTED_BEFORE', len(value['files']), value['branch'], flush=True)
    else:
        old = json.loads(args.baseline.read_text(encoding='utf-8'))
        mismatches = [name for name, digest in old['files'].items() if not (ROOT/name).is_file() or sha(ROOT/name) != digest]
        assert not mismatches, mismatches
        assert git('rev-parse', 'HEAD') == old['head'] and git('rev-parse', 'main') == old['main']
        assert git('branch', '--show-current') == 'hover_distance' and not git('diff', '--cached', '--name-only')
        value = {'passed': True, 'protected_files_unchanged': len(old['files']), 'head_and_main_unchanged': True,
                 'index_empty': True, 'commit_push_performed': False}
        assert args.report
        with args.report.open('x', encoding='utf-8') as stream:
            json.dump(value, stream, indent=2)
        print('PROTECTION_PASS', len(old['files']), flush=True)


if __name__ == '__main__':
    main()
