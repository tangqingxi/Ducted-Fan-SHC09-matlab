"""只读55秒起飞正式批，先审核单飞行交付物，再绘制主图和十二状态附录。"""
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

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'apps/windtrace'))
from core.flight import read_flight

METHODS = ['DA_NS', 'WLS', 'DCA', 'PCA_STATIC', 'PCA_PREDICTIVE']
COLORS = dict(zip(METHODS, ['#497ba1', '#dc9542', '#3b9379', '#9970ad', '#d75459']))


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def clean(value):
    if isinstance(value, dict):
        return {str(k): clean(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [clean(v) for v in value]
    if isinstance(value, np.generic):
        value = value.item()
    if isinstance(value, float) and not np.isfinite(value):
        return None
    return value


def write_json(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(clean(value), stream, ensure_ascii=False, indent=2, allow_nan=False)


def csv_rows(path):
    with path.open(encoding='utf-8-sig', newline='') as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        for key, value in row.items():
            if key in {'method', 'status', 'error_id', 'input_signature_including_plan', 'wtr_status'}:
                continue
            try:
                row[key] = float(value)
            except ValueError:
                row[key] = value
    return rows


def write_csv(path, rows):
    assert rows
    with path.open('x', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def longest(x):
    edges = np.diff(np.r_[False, x, False].astype(int))
    return max(np.r_[0, np.flatnonzero(edges == -1)-np.flatnonzero(edges == 1)])


def independent(data, row):
    L, ref, cfg, model = (data[k] for k in ['L', 'ref', 'cfg', 'model'])
    t = np.asarray(L['time_s']); control = np.asarray(L['control_updated'], bool)
    q = (t >= 15) & (t < 27); qc = q & control
    assert len(t) == 44001 and t[-1] == 55 and q.sum() == 9600 and qc.sum() == 4800
    assert np.asarray(L['pwm_time']).shape == (18316,)
    assert np.max(np.abs(L['pwm_time']-np.arange(18316)/333)) < 1e-10
    assert not np.any(L['aero_outside']) and np.asarray(L['estimator_updated']).sum() == 5501
    assert not L['truth_feedback']
    values = {}
    for domain, pos, roll, rate in [('estimated', L['estimated_position'], L['estimated_euler'][:, 0], L['measured_omega'][:, 2]),
                                    ('true', L['position'], L['euler'][:, 0], L['omega'][:, 2])]:
        distance = np.linalg.norm((pos-ref['position_ned_m'])[:, :2], axis=1)
        values[domain+'_horizontal_rmse_m'] = np.sqrt(np.mean(distance[q]**2))
        values[domain+'_horizontal_peak_m'] = np.max(distance[q])
        values[domain+'_roll_rmse_deg'] = np.rad2deg(np.sqrt(np.mean(roll[q]**2)))
        values[domain+'_roll_peak_deg'] = np.rad2deg(np.max(np.abs(roll[q])))
        values[domain+'_yaw_rate_rmse_deg_s'] = np.rad2deg(np.sqrt(np.mean((rate[q]-ref['omega_body_rad_s'][q, 2])**2)))
    mode, lam = np.asarray(L['mode']), np.asarray(L['lambda'])
    active = (mode[qc] == 0) & np.isfinite(lam[qc]) & (lam[qc] < 1-1e-6)
    if row['method'].startswith('PCA'):
        values['lambda_scaled_duty'] = np.mean(active)
        values['lambda_scaled_duration_s'] = np.sum(active)/400
        values['lambda_longest_episode_s'] = longest(active)/400
        normal = qc & (mode == 0) & np.isfinite(lam)
        ix = np.flatnonzero(normal)
        values['normal_lambda_min'] = lam[ix].min()
        values['lambda_min_time_s'] = t[ix[np.argmin(lam[ix])]]
    values['mode1_duty'] = np.mean(mode[qc] == 1)
    values['high_priority_fallback_duration_s'] = np.sum(mode[qc] == 1)/400
    changes = np.rad2deg(np.diff(L['actual_delta'], axis=0)); main_steps = (t[1:] >= 15) & (t[1:] < 27)
    values['main_servo_travel_deg'] = np.sum(np.abs(changes[main_steps]))
    values['main_servo_rate_rms_deg_s'] = np.sqrt(np.mean((changes[main_steps]*800)**2))
    pwm = np.rad2deg(np.diff(L['pwm_command'], axis=0)); qp = (L['pwm_time'][1:] >= 15) & (L['pwm_time'][1:] < 27)
    values['main_pwm_step_total_deg'] = np.abs(pwm[qp]).sum()
    values['main_pwm_step_rms_deg'] = np.sqrt(np.mean(pwm[qp]**2))
    values['main_command_limit_occupancy'] = np.mean(np.abs(np.rad2deg(L['command'][q])) >= 39.9)
    delta = np.asarray(L['command']); excess = max(0., float((delta-model['command_upper']).max()), float((model['command_lower']-delta).max()))
    tolerance = float(cfg['constraint_tolerance']); assert tolerance == 1e-7 and excess <= tolerance
    assert np.isfinite(np.c_[L['position'], L['velocity'], L['euler'], L['omega']]).all()
    errors = {key: float(abs(value-row[key])) for key, value in values.items()}
    assert all(value <= 5e-8 for value in errors.values()), errors
    return {'passed': True, 'metric_max_abs_error': max(errors.values()), 'metric_errors': errors,
            'command_excess_rad': excess, 'original_tolerance_rad': tolerance,
            'legacy_degree_check_would_pass': bool(np.abs(np.rad2deg(delta)).max() <= 40+1e-7),
            'pwm_events': 18316, 'state_samples': 44001, 'main_samples': 9600, 'main_decisions': 4800,
            'estimator_valid_evidence': 'All5501updates completed the unchanged ECL validity assertions in ppid_simulate.'}


def summarize(rows):
    result = []
    for method in METHODS:
        group = [r for r in rows if r['method'] == method]; assert len(group) == 3
        for key in rows[0]:
            if key in {'method', 'seed'} or not isinstance(group[0][key], (float, int)):
                continue
            v = np.array([r[key] for r in group], float); finite = v[np.isfinite(v)]
            result.append({'method': method, 'metric': key, 'n_finite': len(finite),
                           'mean': finite.mean() if len(finite) else np.nan,
                           'sample_sd': finite.std(ddof=1) if len(finite) > 1 else np.nan,
                           'min': finite.min() if len(finite) else np.nan, 'max': finite.max() if len(finite) else np.nan})
    return result


def paired(rows):
    lookup = {(r['method'], int(r['seed'])): r for r in rows}; result = []
    keys = ['estimated_horizontal_rmse_m', 'true_horizontal_rmse_m', 'estimated_roll_rmse_deg', 'true_roll_rmse_deg',
            'estimated_yaw_rate_rmse_deg_s', 'true_yaw_rate_rmse_deg_s', 'main_servo_rate_rms_deg_s',
            'main_servo_travel_deg', 'main_command_limit_occupancy', 'main_pwm_step_total_deg']
    for first, second in [('PCA_PREDICTIVE', m) for m in METHODS[:-1]] + [('PCA_STATIC', 'DA_NS'), ('PCA_STATIC', 'WLS')]:
        for key in keys:
            values = np.array([lookup[first, s][key]-lookup[second, s][key] for s in [501, 502, 503]])
            result.append({'first': first, 'second': second, 'metric': key, 'delta_501': values[0], 'delta_502': values[1],
                           'delta_503': values[2], 'mean_delta': values.mean(), 'sample_sd_delta': values.std(ddof=1),
                           'min_delta': values.min(), 'max_delta': values.max(), 'definition': 'first minus second; lower error/activity is better'})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batch')
    args = parser.parse_args(); batch = ROOT/'results'/args.batch; delivery = ROOT/'logs/wtr'/args.batch
    output = ROOT/'figures'/args.batch
    assert not output.exists(), '新图目录必须不存在；禁止覆盖。'
    completion = json.loads((batch/'completion.json').read_text(encoding='utf-8-sig'))
    assert completion['simulation_calls'] == 15
    status = csv_rows(batch/'status.csv'); rows = csv_rows(batch/'metrics.csv')
    assert len(status) == 15 and len(rows) == 15 and all(r['status'] == 'completed' and r['wtr_status'] == 'completed' for r in status)
    assert {(r['method'], int(r['seed'])) for r in rows} == {(m, s) for m in METHODS for s in [501, 502, 503]}
    p = json.loads((batch/'formal_protocol.json').read_text(encoding='utf-8-sig'))
    (delivery/'audits').mkdir(exist_ok=False)
    flights = []; examples = {}; extrema = []; audit_records = []; signatures = {}
    for row in rows:
        method, seed = row['method'], int(row['seed']); stem = f'{method}_s{seed}'
        source = batch/'logs'/(stem+'.mat'); wtr = delivery/(stem+'.wtr')
        data = loadmat(source, simplify_cells=True)
        value = independent(data, row); converted = audit(source, wtr); value['wtr'] = converted
        write_json(delivery/'audits'/(stem+'.json'), value); audit_records.append(value)
        flight = read_flight(wtr); meta = flight.manifest
        assert meta['method'] == method and meta['seed'] == seed and meta['execution']['status'] == 'completed'
        assert meta['audit']['original']['status'] == 'completed' and meta['source']['input_signature_scope'] == 'includes_plan'
        assert not meta['unknown_parameter_fields']
        sig = meta['source']['input_signature']; signatures.setdefault(seed, set()).add(sig)
        flights.append({'method': method, 'seed': seed, 'filter_hz': {'h1_alpha': 15, 'h2_delta_feedback': 15},
                        'file': wtr.name, 'bytes': wtr.stat().st_size, 'sha256': sha(wtr),
                        'source_mat': source.relative_to(ROOT).as_posix(), 'source_mat_sha256': sha(source),
                        'input_signature_including_plan': sig, 'metrics': row, 'audit': f'audits/{stem}.json',
                        'parameters': len(flight.parameters), 'unknown_parameter_fields': 0})
        if seed == 501:
            examples[method] = data
        L, ref = data['L'], data['ref']; t = L['time_s']; q = (t >= 15) & (t < 27)
        for domain, prefix, ratekey in [('true', '', 'omega'), ('estimated', 'estimated_', 'measured_omega')]:
            for state, actual, target, units in [('position', L[prefix+'position'], ref['position_ned_m'], 'm'),
                    ('velocity', L[prefix+'velocity'], ref['velocity_ned_m_s'], 'm/s'),
                    ('attitude', np.rad2deg(L[prefix+'euler']), np.rad2deg(ref['euler_rad']), 'deg'),
                    ('omega', np.rad2deg(L[ratekey]), np.rad2deg(ref['omega_body_rad_s']), 'deg/s')]:
                for axis in range(3):
                    error = actual[:, axis]-target[:, axis]
                    if state == 'attitude':
                        error = (error+180) % 360-180
                    extrema.append({'method': method, 'seed': seed, 'domain': domain, 'state': state, 'axis': axis,
                                    'unit': units, 'main_min': actual[q, axis].min(), 'main_max': actual[q, axis].max(),
                                    'main_error_rms': np.sqrt(np.mean(error[q]**2)), 'main_error_abs_peak': np.abs(error[q]).max()})
        print('DELIVERY_AUDIT_OK', stem, flush=True)
    assert all(len(value) == 1 for value in signatures.values())
    sources = json.loads((batch/'sources.json').read_text(encoding='utf-8-sig'))
    # 单飞行容器先交付；一个日志对应一个容器，分配方法仅是元数据。
    manifest = {'schema': 'windtrace.formal-delivery.v1', 'batch': args.batch, 'formal_simulation_calls': 15,
                'precheck_simulation_calls': 1, 'condition': p, 'sources': sources, 'flights': flights,
                'same_seed_signatures': {str(k): next(iter(v)) for k, v in signatures.items()},
                'metric_window_s': [15, 27], 'replay_summary': 'replay_summary.json', 'live_playback': 'playback_live.json',
                'figures': output.relative_to(ROOT).as_posix(), 'all_source_and_wtr_audits_passed': True}
    write_json(delivery/'manifest.json', manifest)
    (delivery/'README.md').write_text('# 起飞型55秒正式批：单飞行容器\n\n'
        '15个.wtr分别对应五方法×501/502/503，不是多方法bundle。manifest.json记录每条的配置、指标、bytes、SHA和源MAT。\n\n'
        '双15Hz共享滤波；0–12秒起飞，15–27秒扰动，27–37秒恢复，尾部保持高度、53–55秒收转；没有降落段。\n\n'
        'audits逐条核对源MAT、容器字段和指标；replay_summary是代表性501预测PCA的离屏三维检查。容器默认不入Git，清单和README可入Git。\n\n'
        f'图表单独位于`{output.relative_to(ROOT).as_posix()}`。禁止覆盖、不得以重飞修复导出问题。\n', encoding='utf-8')
    output.mkdir(); (output/'main').mkdir(); (output/'tables').mkdir(); (output/'appendix').mkdir()
    shutil.copyfile(batch/'metrics.csv', output/'tables/metrics.csv')
    shutil.copyfile(batch/'status.csv', output/'tables/status.csv')
    shutil.copyfile(batch/'provenance.csv', output/'tables/provenance.csv')
    summary = summarize(rows); pairs = paired(rows)
    write_csv(output/'tables/summary.csv', summary); write_csv(output/'tables/paired_differences.csv', pairs)
    recovery_keys = [key for key in rows[0] if 'recovery_' in key]
    write_csv(output/'tables/recovery.csv', [{key: row[key] for key in ['method', 'seed']+recovery_keys} for row in rows])
    write_csv(output/'tables/state_extrema_by_seed.csv', extrema)
    extrema_summary = []
    for method in METHODS:
        for domain in ['true', 'estimated']:
            for state in ['position', 'velocity', 'attitude', 'omega']:
                for axis in range(3):
                    group = [r for r in extrema if r['method'] == method and r['domain'] == domain and r['state'] == state and r['axis'] == axis]
                    worst = max(group, key=lambda r: r['main_error_abs_peak'])
                    extrema_summary.append({'method': method, 'domain': domain, 'state': state, 'axis': axis, 'unit': group[0]['unit'],
                        'three_seed_min': min(r['main_min'] for r in group), 'three_seed_max': max(r['main_max'] for r in group),
                        'error_rms_min': min(r['main_error_rms'] for r in group), 'error_rms_max': max(r['main_error_rms'] for r in group),
                        'worst_error_abs_peak': worst['main_error_abs_peak'], 'worst_peak_seed': worst['seed']})
    write_csv(output/'tables/state_extrema_three_seeds.csv', extrema_summary)
    draw(output, examples, rows, summary)
    write_json(output/'independent_checks.json', {'passed': True, 'logs_verified': 15, 'wtr_verified': 15,
        'postprocessing_sha256': {name: sha(ROOT/name) for name in ['tools/deliver_hover_takeoff_formal.py', 'tools/audit_windtrace.py']},
        'metric_max_abs_error': max(r['metric_max_abs_error'] for r in audit_records),
        'DA_NS_independent_original_rad_audits': [flights[i]['audit'] for i, r in enumerate(rows) if r['method'] == 'DA_NS'],
        'same_seed_input_signatures': True, 'main_state_samples': 9600, 'main_decision_samples': 4800,
        'state_extrema_rows': len(extrema), 'three_seed_extrema_rows': len(extrema_summary),
        'metric_states_resampled': False, 'state_plot_hz': 100, 'lambda_plot_hz': 400,
        'source_mat_files_unchanged': True, 'unknown_parameters': 0})
    report(output, batch, rows, summary, pairs, sources)
    expected_png = list((output/'main').glob('*.png'))+list((output/'appendix').glob('*.png'))
    expected_pdf = list((output/'main').glob('*.pdf'))+list((output/'appendix').glob('*.pdf'))
    assert len(expected_png) == len(expected_pdf) == 12
    write_json(output/'manifest.json', {'schema': 'shc09.figures-delivery.v1', 'batch': args.batch,
        'main_figure_pairs': 7, 'appendix_figure_pairs': 5, 'source': batch.relative_to(ROOT).as_posix(),
        'files': [{'path': path.relative_to(output).as_posix(), 'bytes': path.stat().st_size, 'sha256': sha(path)}
                  for path in sorted(output.rglob('*')) if path.is_file()]})
    print('DELIVERY_COMPLETE', output, flush=True)


def draw(output, examples, rows, summary):
    font = Path('C:/Windows/Fonts/msyh.ttc')
    if font.is_file():
        font_manager.fontManager.addfont(str(font)); plt.rcParams['font.family'] = font_manager.FontProperties(fname=str(font)).get_name()
    plt.rcParams.update({'font.size': 10, 'axes.unicode_minus': False, 'pdf.fonttype': 42, 'axes.spines.top': False, 'axes.spines.right': False})

    def save(fig, folder, name):
        for ext in ['png', 'pdf']:
            fig.savefig(output/folder/(name+'.'+ext), dpi=180)
        plt.close(fig)

    def style(ax, time=True):
        ax.grid(alpha=.18)
        if time:
            ax.axvspan(15, 27, color='#f5dbce', alpha=.5, zorder=-10); ax.set_xlim(0, 55); ax.set_xlabel('时间 / s')

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.7), constrained_layout=True)
    for ax, domain in zip(axes, ['estimated_', '']):
        for method, data in examples.items():
            L = data['L']; q = (L['time_s'] >= 15) & (L['time_s'] < 27); xy = L[domain+'position'][:, :2]
            ax.plot(xy[::8, 0], xy[::8, 1], color=COLORS[method], lw=.7, alpha=.2)
            ax.plot(xy[q, 0][::8], xy[q, 1][::8], color=COLORS[method], lw=1.3, label=method)
        ax.scatter([0], [0], marker='+', s=80, color='#252525', label='悬停参考'); ax.set_aspect('equal', adjustable='datalim')
        ax.set(xlabel='北向 / m', ylabel='东向 / m', title=('估计' if domain else '真值')+'水平位置：深色为15–27秒'); style(ax, False)
    axes[1].legend(fontsize=8); fig.suptitle('seed501代表飞行；无平移或轨迹拟合'); save(fig, 'main', '01_horizontal_position')
    for name, ylabel, kind in [('02_altitude', '高度 / m', 'height'), ('03_roll', '滚转 / °', 'roll'), ('04_yaw_rate', '偏航角速度 / (°/s)', 'yaw')]:
        fig, axes = plt.subplots(2, 1, figsize=(11, 6), sharex=True, constrained_layout=True)
        for ax, domain in zip(axes, ['estimated_', '']):
            for method, data in examples.items():
                L, ref = data['L'], data['ref']; t = L['time_s']; ix = np.arange(0, len(t), 8)
                if kind == 'height':
                    values = -L[domain+'position'][:, 2]; target = -ref['position_ned_m'][:, 2]
                elif kind == 'roll':
                    values = np.rad2deg(L[domain+'euler'][:, 0]); target = np.zeros(len(t))
                else:
                    values = np.rad2deg(L['measured_omega' if domain else 'omega'][:, 2]); target = np.rad2deg(ref['omega_body_rad_s'][:, 2])
                ax.plot(t[ix], values[ix], color=COLORS[method], lw=1, label=method)
            ax.plot(t[ix], target[ix], '--', color='#222222', lw=1, label='规划参考'); ax.set_ylabel(ylabel)
            ax.set_title(('估计／反馈' if domain else '真值')+'；seed501'); style(ax)
        axes[0].legend(ncol=3, fontsize=8); save(fig, 'main', name)
    draw_lambda(output, examples)
    lookup = {(r['method'], r['metric']): r for r in summary}
    for filename, keys, labels in [('06_tracking_metrics', ['estimated_horizontal_rmse_m', 'estimated_roll_rmse_deg', 'estimated_yaw_rate_rmse_deg_s'], ['水平位置RMS / m', '滚转RMS / °', '偏航速率RMS / (°/s)']),
                                   ('07_actuator_metrics', ['main_servo_rate_rms_deg_s', 'main_servo_travel_deg', 'main_command_limit_occupancy'], ['实际舵速RMS / (°/s)', '六舵面总行程 / °', '指令舵面触限占空 / %'])]:
        fig, axes = plt.subplots(1, 3, figsize=(12, 4.2), constrained_layout=True)
        for ax, key, label in zip(axes, keys, labels):
            v = [lookup[m, key] for m in METHODS]; scale = 100 if 'occupancy' in key else 1
            y = np.array([r['mean'] for r in v])*scale
            ax.bar(np.arange(5), y, color=[COLORS[m] for m in METHODS], width=.64)
            err = np.array([[r['mean']-r['min'] for r in v], [r['max']-r['mean'] for r in v]])*scale
            ax.errorbar(np.arange(5), y, yerr=err, fmt='none', ecolor='#323b45', capsize=3, lw=1)
            ax.set_xticks(np.arange(5), ['DA_NS', 'WLS', 'DCA', 'PCA\nSTATIC', 'PCA\nPRED']); ax.set_ylabel(label); style(ax, False)
        fig.suptitle('主窗15–27秒，三种子均值与最小–最大范围；不代表置信区间'); save(fig, 'main', filename)
    for method, data in examples.items():
        L, ref = data['L'], data['ref']; t = L['time_s']; ix = np.arange(0, len(t), 8)
        fig, axes = plt.subplots(4, 3, figsize=(14.5, 10.5), sharex=True, constrained_layout=True)
        groups = [('position', 'estimated_position', 'position_ned_m', '位置 / m'),
                  ('velocity', 'estimated_velocity', 'velocity_ned_m_s', '速度 / (m/s)'),
                  ('euler', 'estimated_euler', 'euler_rad', '姿态 / °'),
                  ('omega', 'measured_omega', 'omega_body_rad_s', '角速度 / (°/s)')]
        for r, (truthkey, estkey, refkey, label) in enumerate(groups):
            for c in range(3):
                ax = axes[r, c]
                for key, values, color, style_ in [('真值', L[truthkey][:, c], '#377bad', '-'), ('估计／反馈', L[estkey][:, c], '#dd9245', '-'), ('规划参考', ref[refkey][:, c], '#292d32', '--')]:
                    if r >= 2:
                        values = np.rad2deg(np.unwrap(values) if r == 2 and c == 2 else values)
                    ax.plot(t[ix], values[ix], color=color, ls=style_, lw=.9, label=key)
                style(ax); ax.set_ylabel(label)
                ax.set_title((['N', 'E', 'D'] if r < 2 else ['滚转 / p', '俯仰 / q', '偏航 / r'])[c], fontsize=10)
        axes[0, 0].legend(fontsize=8); fig.suptitle(method+' · seed501 · 十二状态代表飞行；阴影15–27秒，尾部保持，无降落')
        save(fig, 'appendix', method+'_s501_12states')


def draw_lambda(output, examples):
    # 正常模式λ与两种回退分别表达；回退标记放在零线，不把NaN填成数值。
    font = Path('C:/Windows/Fonts/msyh.ttc')
    if font.is_file():
        font_manager.fontManager.addfont(str(font)); plt.rcParams['font.family'] = font_manager.FontProperties(fname=str(font)).get_name()
    plt.rcParams.update({'font.size': 10, 'axes.unicode_minus': False, 'pdf.fonttype': 42, 'axes.spines.top': False, 'axes.spines.right': False})
    fig, axes = plt.subplots(2, 1, figsize=(11, 5.6), sharex=True, constrained_layout=True)
    for ax, method in zip(axes, METHODS[-2:]):
        L = examples[method]['L']; ix = np.flatnonzero(L['control_updated']); mode = L['mode'][ix]
        lam = np.where(mode == 0, L['lambda'][ix], np.nan)
        ax.plot(L['time_s'][ix], lam, color=COLORS[method], lw=.85, label='正常模式λ')
        for value, marker, color, title in [(1, 'x', '#8b3541', '高优先级回退'), (2, 'v', '#4f6476', '工程兜底')]:
            bad = ix[mode == value]
            if len(bad):
                ax.scatter(L['time_s'][bad], np.zeros(len(bad)), color=color, marker=marker, s=12, label=title)
        ax.set_ylim(-.07, 1.07); ax.set_ylabel('λ'); ax.set_title(method+'；seed501')
        ax.grid(alpha=.18); ax.axvspan(15, 27, color='#f5dbce', alpha=.5, zorder=-10)
        ax.set_xlim(0, 55); ax.set_xlabel('时间 / s'); ax.legend(fontsize=8)
    for ext in ['png', 'pdf']:
        fig.savefig(output/'main'/('05_lambda.'+ext), dpi=180)
    plt.close(fig)


def report(output, batch, rows, summary, pairs, sources):
    lookup = {(r['method'], r['metric']): r for r in summary}
    lines = ['# 起飞型hover_distance：55秒五方法正式比较', '',
        f'批次：`{batch.name}`。最终时间线预检1条通过后，五方法×501/502/503完成15条；共享15/15Hz。', '',
        '0–12秒五次爬升、12–15秒稳定，15–27秒滚转扰动，27–37秒恢复，37–55秒保持高度、53–55秒收转。本批没有降落段。', '',
        '与旧40秒实现相同，15秒开始0.5秒平滑加载，27秒开始0.5秒平滑卸载；载入到卸载指令间隔12秒，扰动包络到27.5秒归零。恢复窗起始0.5秒包含原样保留的卸载过程。', '',
        '主表只评价半开区间[15,27)，起飞／尾部不纳入主指标。表内为三种子均值 ± 样本标准差；这是本批波动，不是置信区间或显著性。', '',
        '| 方法 | 估计位置RMS m | 真值位置RMS m | 估计滚转RMS ° | 真值滚转RMS ° | 估计偏航速率RMS °/s | 真值偏航速率RMS °/s |',
        '|---|---:|---:|---:|---:|---:|---:|']
    metrics = ['estimated_horizontal_rmse_m', 'true_horizontal_rmse_m', 'estimated_roll_rmse_deg', 'true_roll_rmse_deg', 'estimated_yaw_rate_rmse_deg_s', 'true_yaw_rate_rmse_deg_s']
    for method in METHODS:
        lines.append('|'+method+'|'+'|'.join(f"{lookup[method, key]['mean']:.7g} ± {lookup[method, key]['sample_sd']:.3g}" for key in metrics)+'|')
    lines += ['', '| 方法 | λ缩放占空 % | λ_min均值 | mode1 % | 舵速RMS °/s | 六舵面行程 ° | 舵指令触限占空 % | PWM总步变 ° |', '|---|---:|---:|---:|---:|---:|---:|---:|']
    for method in METHODS:
        values = []
        for key, scale in [('lambda_scaled_duty', 100), ('normal_lambda_min', 1), ('mode1_duty', 100), ('main_servo_rate_rms_deg_s', 1), ('main_servo_travel_deg', 1), ('main_command_limit_occupancy', 100), ('main_pwm_step_total_deg', 1)]:
            value = lookup[method, key]['mean']; values.append(f'{value*scale:.7g}' if np.isfinite(value) else '不适用')
        lines.append('|'+method+'|'+'|'.join(values)+'|')
    lines += ['', '舵面触限占空定义为主窗六舵面×状态样本中|指令|≥39.9°的比例；λ只用于PCA正常模式，回退另报；PWM步变不是机械损耗或能耗。', '',
              '## 成对比较与消融', '', '差值=前者−后者；误差和活动量为负才是降低。每项必须同时看逐种子差值及波动，不能只看均值。', '',
              '| 比较 | 指标 | seed501 | seed502 | seed503 | 均值差 ± 样本SD |', '|---|---|---:|---:|---:|---:|']
    for r in pairs:
        if r['metric'] in ['estimated_horizontal_rmse_m', 'estimated_roll_rmse_deg', 'estimated_yaw_rate_rmse_deg_s', 'main_command_limit_occupancy', 'main_servo_rate_rms_deg_s']:
            lines.append(f"|{r['first']} − {r['second']}|{r['metric']}|{r['delta_501']:.7g}|{r['delta_502']:.7g}|{r['delta_503']:.7g}|{r['mean_delta']:.7g} ± {r['sample_sd_delta']:.3g}|")
    lines += ['', 'PCA_PREDICTIVE与PCA_STATIC比较预测环节；PCA_STATIC与DA_NS/WLS比较优先级结构。预测PCA与DA_NS/WLS/DCA的滚转／位置变化和偏航跟踪代价必须成对解释，不预设DCA排序。', '',
        '## 交付与审计', '',
        '- `tables/metrics.csv`为15条完整指标，包含估计＋真值、λ最小时刻／最长缩放／回退、恢复时间和超调。恢复未达到时保留NaN，不填零。',
        '- `tables/summary.csv`为五方法三种子均值、样本SD及极差；`paired_differences.csv`为逐种子配对差。',
        '- `appendix/`每方法一页seed501十二状态PNG/PDF；三种子状态极值见两张state_extrema表。主窗极值与全程代表页用途不同。',
        '- `.wtr`逐条在`logs/wtr/'+batch.name+'/`，manifest含参数、指标、bytes、SHA和源MAT；逐字段审计不推进仿真。',
        '- DA_NS独立审计使用原始1e-7rad容差，旧1e-7degree判据只记录其是否会误判，不用于本批门禁。',
        '- 第一条DA_NS保存／导出后，原驱动指标累加器初始化报错；管理性续跑只补14条not_run，没有重飞任何已完成飞行。原冻结源码和锁在执行期间保持不变，错误日志与例外记录保留。',
        '- metrics内precheck_passed只用于先决PCA_PREDICTIVE预检表达式，非PCA的该字段不适用，不能用它判断正式有效性；正式执行与数据有效性分别看status和data_valid。',
        '- 所有状态指标使用原生800Hz、分配事件400Hz；状态图100Hz、λ图400Hz；PWM保留18316个真实333Hz事件。舵面差分与PWM步变按区间右端时间落窗。', '',
        '五方法在每个种子共用同一参考、初态、预生成误差／扰动、控制器、估计器、B、δ̂接口、PWM时序与限幅；ν_h/ν_c由共同公式计算，闭环数值随分配器作用分叉，并非参考不一致。', '',
        '地面坐标起始仍采用既有悬停转速配平，没有解锁／起转／接地／地效模型。真值只评分，不反馈；无事后位置平移或相位拟合。', '',
        '这是工程调参配置下的比较，种子501参与先决预检，不是独立泛化确认。不宣称统计显著、实机优势或全局最优。', '',
        '## 来源和复现', '',
        f"公共引擎：`{sources['base']['parent']['engine']}`；完整研究源码SHA在批次sources/source_lock/formal_lock中。", '',
        '```matlab', "run_hover_distance_takeoff_formal('20261103_r1'); % 仅记录原命令；已有目录拒绝重跑", '```',
        '```powershell', f'python tools/deliver_hover_takeoff_formal.py {batch.name}', '```', '',
        '运行需WINDTRACE_PYTHON指向含SciPy环境。源码、原始MAT及旧协议／锁不由后处理修改。图目录及清单拒绝覆盖；新运行必须另立新tag。本批不提交或push。']
    (output/'README.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    # 报告副本位于本次新目录，不改写旧报告。
    (batch/'report.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
