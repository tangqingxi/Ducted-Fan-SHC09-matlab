import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

# 依赖源码以固定版本随仓库提供，用逐文件校验替代嵌套Git仓库。
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description='校验并编译官方ECL独立进程接口。')
parser.add_argument('--verify-only', action='store_true')
parser.add_argument('--compiler', help='C++编译器路径；也可设置CXX环境变量。')
args = parser.parse_args()
dependencies = json.loads((root / 'third_party/source_manifest.json').read_text(encoding='utf-8'))
for dependency in dependencies:
    for relative, expected in dependency['files'].items():
        path = root / 'third_party' / dependency['directory'] / relative
        assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected, f'依赖源码校验失败：{path}'
print('固定版本ECL及Matrix源码校验通过。')
if args.verify_only:
    raise SystemExit(0)
compiler = args.compiler or os.environ.get('CXX') or shutil.which('g++')
if not compiler or not (Path(compiler).is_file() or shutil.which(compiler)):
    raise SystemExit('找不到g++；请将编译器加入PATH，或设置CXX，或传入--compiler。')
out = root / 'build/px4_ecl'
out.mkdir(parents=True, exist_ok=True)
ecl = Path('third_party/PX4-ECL')
sources = [str(ecl / relative) for relative in sorted(dependencies[0]['files'])
           if relative.startswith('EKF/') and relative.count('/') == 1 and relative.endswith('.cpp')]
sources += [str(ecl / 'geo/geo.cpp'), str(ecl / 'geo_lookup/geo_mag_declination.cpp'),
            'src/navigation/px4_ecl/px4_ecl_bridge.cpp']
# MATLAB接口当前使用Windows可执行文件名，其他平台基础仿真不需要此桥接。
command = [compiler, '-std=c++14', '-O2', '-fno-associative-math', '-DECL_STANDALONE',
           '-Ithird_party/PX4-ECL', '-Ithird_party/PX4-Matrix', *sources,
           '-o', 'build/px4_ecl/px4_ecl_bridge.exe', '-static-libgcc', '-static-libstdc++']
result = subprocess.run(command, cwd=root, text=True, capture_output=True)
(out / 'build_stdout.txt').write_text(result.stdout, encoding='utf-8')
(out / 'build_stderr.txt').write_text(result.stderr, encoding='utf-8')
if result.returncode:
    print(result.stderr)
    raise SystemExit(result.returncode)
manifest = {'dependencies': [{key: dependency[key] for key in ['directory', 'commit', 'repository', 'license']} for dependency in dependencies],
            'compiler': compiler, 'compile_arguments': command,
            'bridge_sha256': hashlib.sha256((root / sources[-1]).read_bytes()).hexdigest(),
            'executable_sha256': hashlib.sha256((out / 'px4_ecl_bridge.exe').read_bytes()).hexdigest()}
(out / 'build_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('官方ECL桥接构建完成：', out / 'px4_ecl_bridge.exe')
