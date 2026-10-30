from pathlib import Path
import argparse
import shutil

# 每个阶段在仓库内隔离目录验证，避免旧results和build被测试覆盖。
parser = argparse.ArgumentParser()
parser.add_argument('label')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
workspace = root / 'archive/platform_refactor' / (args.label + '_workspace')
assert not workspace.exists(), '验证目录已存在，请使用新的阶段标签。'
blocked = {'archive', 'results', 'build', '.git', '__pycache__', '.tmp_matlab'}
for source in root.rglob('*'):
    relative = source.relative_to(root)
    if not source.is_file() or any(part in blocked for part in relative.parts):
        continue
    destination = workspace / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
if (root / 'build/px4_ecl/px4_ecl_bridge.exe').is_file():
    shutil.copytree(root / 'build/px4_ecl', workspace / 'build/px4_ecl')
path = lambda value: str(value).replace('\\', '/')
script = f"""% 阶段回归只使用当前E盘仓库内的隔离副本。
restoredefaultpath;cd('{path(workspace)}');ca_setup();
report=run_project_tests(false);
assert(height(report)==14 && all(report.passed),'旧测试未全部通过。');
if exist('run_platform_tests','file'),platform_report=run_platform_tests();end
if isfile(fullfile(pwd,'tests','baseline','numeric_baseline.mat'))
    baseline_report=test_platform_baseline();
end
base=struct('duration_s',0.2,'flight_mode',\"position_hold\",'initial_position_ned_m',[0;0;-10], ...
 'position_reference_ned_m',[0;0;-10],'aero_low_speed_model',\"hold_90\",'aero_extrapolation_policy',\"error\", ...
 'show_figures',false,'save_figures',false,'save_results',false);
for flag=1:5,result=main(flag,base);end
save(fullfile(pwd,'results','validation','stage_checks.mat'),'report');
fprintf('阶段{args.label}回归和五入口烟雾通过。\\n');
"""
driver = root / 'archive/platform_refactor' / (args.label + '_checks.m')
driver.write_text(script, encoding='utf-8')
print(driver)
