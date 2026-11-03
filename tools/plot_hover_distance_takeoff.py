"""只读一条50秒起飞日志，交付四张快看图及单飞行容器清单；不重飞。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
import numpy as np
from scipy.io import loadmat

from audit_windtrace import audit


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def scalar(value):
    try:
        number = float(value)
        return number if np.isfinite(number) else None
    except ValueError:
        return value


def write_json(path, data):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2, allow_nan=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tag')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    batch = root / 'results' / ('hover_distance_takeoff_precheck_' + args.tag)
    delivery = root / 'logs/wtr' / ('precheck_' + args.tag)
    output = root / 'figures' / ('hover_distance_takeoff_precheck_' + args.tag)
    assert not output.exists(), '拒绝覆盖旧图目录'
    source = batch / 'logs/PCA_PREDICTIVE_s501.mat'
    wtr = delivery / 'PCA_PREDICTIVE_s501.wtr'
    assert source.is_file() and wtr.is_file()
    report = audit(source, wtr)
    write_json(delivery / 'independent_audit.json', report)
    data = loadmat(source, simplify_cells=True)
    L, ref = data['L'], data['ref']
    t = np.asarray(L['time_s']); assert len(t) == 40001 and t[-1] == 50
    with (batch / 'metrics.csv').open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    assert len(rows) == 1
    metrics = {key: scalar(value) for key, value in rows[0].items()}
    p = json.loads((batch / 'takeoff_protocol.json').read_text(encoding='utf-8-sig'))
    font = Path('C:/Windows/Fonts/msyh.ttc')
    if font.is_file():
        font_manager.fontManager.addfont(str(font))
        plt.rcParams['font.family'] = font_manager.FontProperties(fname=str(font)).get_name()
    plt.rcParams.update({'axes.unicode_minus': False, 'font.size': 11, 'pdf.fonttype': 42})
    (output / 'main').mkdir(parents=True); (output / 'tables').mkdir()
    shutil.copyfile(batch / 'metrics.csv', output / 'tables/metrics.csv')
    step = np.arange(0, len(t), 8)

    def plot(name, ylabel, curves, allocation=False):
        fig, ax = plt.subplots(figsize=(10.5, 4.2), constrained_layout=True)
        ax.axvspan(12, 24, color='#f3ddd5', alpha=.55, label='滚转扰动主窗 12–24 s')
        indices = np.flatnonzero(L['control_updated']) if allocation else step
        for values, label, color, style in curves:
            ax.plot(t[indices], np.asarray(values)[indices], label=label, color=color, linestyle=style, linewidth=1.2)
        if allocation:
            for mode, marker, color, label in [(1, 'x', '#ba3434', '高优先级回退'), (2, '|', '#4b5563', '工程兜底')]:
                ix = indices[np.asarray(L['mode'])[indices] == mode]
                if len(ix): ax.scatter(t[ix], np.zeros(len(ix)), marker=marker, color=color, s=18, label=label)
            ax.set_ylim(-.08, 1.08)
        ax.set(xlabel='时间 / s', ylabel=ylabel, xlim=(0, 50))
        ax.grid(alpha=.2); ax.legend(loc='best', ncol=2, fontsize=9)
        for extension in ['png', 'pdf']:
            path = output / 'main' / (name + '.' + extension)
            fig.savefig(path, dpi=180)
        plt.close(fig)

    plot('01_altitude', '高度 / m', [(-ref['position_ned_m'][:, 2], '规划高度', '#222222', '--'),
         (-L['position'][:, 2], '真值高度', '#2878b5', '-'), (-L['estimated_position'][:, 2], '估计高度', '#d98435', '-')])
    plot('02_roll', '滚转 / °', [(np.rad2deg(L['euler'][:, 0]), '真值滚转', '#2878b5', '-'),
         (np.rad2deg(L['estimated_euler'][:, 0]), '估计滚转', '#d98435', '-'), (np.zeros(len(t)), '规划滚转', '#222222', '--')])
    plot('03_yaw_rate', '机体偏航角速度 / (°/s)', [(np.rad2deg(ref['omega_body_rad_s'][:, 2]), '规划角速度', '#222222', '--'),
         (np.rad2deg(L['omega'][:, 2]), '真值角速度', '#2878b5', '-'), (np.rad2deg(L['measured_omega'][:, 2]), '反馈角速度', '#d98435', '-')])
    normal = np.where(np.asarray(L['mode']) == 0, np.asarray(L['lambda']), np.nan)
    plot('04_lambda', '正常模式缩放 λ', [(normal, '正常模式 λ', '#7660a9', '-')], allocation=True)
    # 以独立计算的800Hz／400Hz统计核对表格；图显示降采样不能改变指标。
    q = (t >= 12) & (t < 24); qc = q & np.asarray(L['control_updated'], bool)
    error = L['position'] - ref['position_ned_m']
    independent = {'true_horizontal_rmse_m': float(np.sqrt(np.mean(np.sum(error[q, :2]**2, axis=1)))),
                   'true_roll_rmse_deg': float(np.rad2deg(np.sqrt(np.mean(L['euler'][q, 0]**2)))),
                   'true_yaw_rate_rmse_deg_s': float(np.rad2deg(np.sqrt(np.mean((L['omega'][q, 2]-ref['omega_body_rad_s'][q, 2])**2)))),
                   'lambda_scaled_duty': float(np.mean((L['mode'][qc] == 0) & np.isfinite(L['lambda'][qc]) & (L['lambda'][qc] < 1-1e-6)))}
    differences = {key: abs(value - metrics[key]) for key, value in independent.items()}
    assert max(differences.values()) < 1e-9, differences
    replay = json.loads((delivery / 'replay_summary.json').read_text(encoding='utf-8'))
    assert replay['passed'] and len(replay['stages']) == 4
    manifest = {'schema': 'windtrace.precheck-delivery.v1', 'batch': batch.name, 'method': 'PCA_PREDICTIVE', 'seed': 501,
                'filter_hz': {'h1_alpha': 15, 'h2_delta_feedback': 15},
                'condition': {'duration_s': 50, 'takeoff_s': 8, 'roll_load_fraction': .85, 'yaw_rate_peak_deg_s': 280,
                              'roll_frequency_hz': .5, 'yaw_frequency_hz': .75, 'main_window_s': [12, 24], 'recovery_window_s': [24, 34]},
                'file': wtr.name, 'bytes': wtr.stat().st_size, 'sha256': sha(wtr),
                'source_mat': source.relative_to(root).as_posix(), 'source_mat_sha256': sha(source), 'metrics': metrics,
                'independent_audit': 'independent_audit.json', 'replay_summary': 'replay_summary.json',
                'figures': output.relative_to(root).as_posix(), 'simulation_calls': 1, 'formal_batch_launched': False}
    write_json(delivery / 'manifest.json', manifest)
    write_json(output / 'plot_checks.json', {'source_mat_sha256': sha(source), 'wtr_sha256': sha(wtr),
               'state_plot_hz': 100, 'lambda_plot_hz': 400, 'metric_recomputation_errors': differences,
               'scientific_states_resampled_for_metrics': False, 'figure_pairs': 4})
    passed = bool(metrics['precheck_passed'])
    lines = ['# 起飞型hover_distance单条预检快看', '',
             f'批次：{batch.name}；seed501，PCA_PREDICTIVE，15/15Hz；工程预检通过：{passed}。', '',
             '本次只飞一条50秒，不是五方法比较或泛化确认。地面坐标起始、悬停转速配平，无接地／解锁／地效模型。', '',
             f'源MAT：`{source.relative_to(root).as_posix()}`；SHA256：`{sha(source)}`。',
             f'首要交付物：`{wtr.relative_to(root).as_posix()}`，其manifest记录配置、指标、字节数、SHA与来源。', '',
             '0–8秒五次爬升，8–10秒偏航起振，12–24秒滚转扰动，24–34秒恢复，尾部保持高度、48–50秒收转。',
             'main只含高度、滚转、偏航角速度及正常模式λ四组PNG/PDF；浅色阴影为12–24秒。没有十二状态附录。',
             'tables/metrics.csv为800Hz状态与400Hz事件指标；状态图100Hz，λ图400Hz，未平移或拟合轨迹。', '',
             '## 起飞与主窗指标', '',
             '| 指标 | 估计／反馈 | 真值 |', '|---|---:|---:|']
    for title, key in [('8秒高度 m', 'altitude_at_8s_m'), ('8秒垂速 NED m/s', 'vertical_speed_at_8s_m_s'),
                       ('10–12秒高度RMS m', 'settle_height_rmse_m'), ('10–12秒垂速RMS m/s', 'settle_vertical_speed_rmse_m_s'),
                       ('主窗水平RMS m', 'horizontal_rmse_m'), ('主窗滚转RMS °', 'roll_rmse_deg'), ('主窗偏航速率RMS °/s', 'yaw_rate_rmse_deg_s')]:
        lines.append(f'|{title}|{metrics["estimated_"+key]:.8g}|{metrics["true_"+key]:.8g}|')
    lines += ['', f'正常缩放占空比：{100*metrics["lambda_scaled_duty"]:.6g}%；λ_min={metrics["normal_lambda_min"]:.8g}，时刻{metrics["lambda_min_time_s"]:.6g}s；mode1={100*metrics["mode1_duty"]:.6g}%。',
              f'最大真值倾角：{metrics["actual_tilt_peak_deg"]:.8g}°；推力指令峰值比：{metrics["thrust_fraction_peak"]:.8g}。',
              f'全程实际舵速RMS：{metrics["actual_servo_rate_rms_deg_s"]:.8g}°/s；总行程：{metrics["actual_servo_travel_deg"]:.8g}°。', '',
              '## 复现命令与保护', '', '```matlab',
              f"run_hover_distance_takeoff('{args.tag}'); % 已存在批次会拒绝；不要重飞本条", '```', '```powershell',
              f'python tools/plot_hover_distance_takeoff.py {args.tag}', '```', '',
              'MATLAB入口需预先设置WINDTRACE_PYTHON。结果、容器、图目录均拒绝覆盖；失败保留，不调参重试。',
              '工程起飞／稳定判断值写于飞前takeoff_protocol.json，并非修改旧协议。是否进入正式批由用户另行决定。']
    (output / 'README.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    (delivery / 'README.md').write_text('# 单飞行首要交付物\n\n'+
        f'PCA_PREDICTIVE，seed501，50s，15/15Hz。文件：{wtr.name}。\n\n'+
        'manifest.json记录实际配置、指标、bytes、SHA256及源MAT。independent_audit.json逐字段核对源日志；replay_summary.json包含起飞／悬停／扰动／恢复四个离屏三维检查。\n\n'+
        f'快看图和指标表独立存放：`{output.relative_to(root).as_posix()}`。容器默认不入Git，manifest和本说明可纳入Git。不得覆盖本次交付；新运行必须新tag。\n', encoding='utf-8')
    print('TAKEOFF_DELIVERY', 'PASS' if passed else 'FAILED_PRECHECK', str(output), flush=True)


if __name__ == '__main__':
    main()
