"""单条55秒回归的来源对齐、融合记录、误差指标及历史完整性检查。"""
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[5]
DOC=Path(__file__).resolve().parents[1]
OUT=ROOT/'results/gnss_1000s_regression_20261104_r1'


def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def table(name,rows):
    with (DOC/name).open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)


def main():
    data=loadmat(OUT/'PCA_PREDICTIVE_s501.mat',simplify_cells=True)
    L,ref,cfg,plan,comp=(data[k] for k in ('L','ref','cfg','plan','comp'))
    t=L['time_s'];fs=float(cfg['sample_hz']);warm=int(comp['warmup_samples'])
    execution=(OUT/'execution.log').read_text(encoding='utf-8',errors='replace')
    assert execution.count('GNSS1000_SINGLE_REGRESSION_START')==1 and 'GNSS1000_REGRESSION_DONE' in execution
    assert len(t)==44001 and t[-1]==55 and plan['sensors']['gnss_correlation_s']==1000
    assert np.all(L['gps_active']) and np.all(L['position_valid']) and np.all(L['origin_valid'])
    assert np.isfinite(L['position']).all() and not np.any(L['aero_outside'])
    assert not bool(L['truth_feedback'])
    indices=np.flatnonzero(L['gnss_fresh']);assert len(indices)==275
    delay=round(fs*float(cfg['gnss_delay_s']));assert delay==80
    source_global=warm+indices+1-delay
    source_mission=source_global-warm
    stride=round(fs/float(cfg['gnss_hz']));assert stride==160
    assert np.array_equal(np.flatnonzero((warm+np.arange(len(t))-delay)%stride==0),indices)
    truth_source=L['position'][source_mission-1]
    slow=comp['slow_m'][source_global-1];white=comp['white_m'][source_global-1]
    observed=L['gnss_position'][indices]
    residual=observed-truth_source-cfg['gnss_position_bias_m']-slow-white
    assert np.max(np.abs(residual))<1e-12
    rows=[]
    for j,k in enumerate(indices):
        r=dict(receive_time_s=t[k],receive_mission_index=int(k+1),source_time_s=(source_mission[j]-1)/fs,
               source_global_index=int(source_global[j]),source_mission_index=int(source_mission[j]))
        for name,values in [('truth',truth_source),('slow',slow),('white',white),('observation',observed),('closure',residual)]:
            r.update({f'{name}_{a}':float(values[j,i]) for i,a in enumerate('ned')})
        rows.append(r)
    table('gnss_source_alignment.csv',rows)
    errors={'true_tracking':L['position']-ref['position_ned_m'],
            'local_ekf_error':L['estimated_position']-L['position'],
            'raw_ekf_error':L['raw_navigation_position']-L['position'],
            'perceived_tracking':L['estimated_position']-ref['position_ned_m']}
    assert np.max(np.abs(L['raw_navigation_position']-L['navigation_origin_offset']-L['estimated_position']))<1e-12
    rows=[]
    for window,mask in [('whole_0_55',t>=0),('main_15_27',(t>=15)&(t<27)),('recovery_27_37',(t>=27)&(t<37)),('tail_45_55',t>=45)]:
        for name,error in errors.items():
            e=error[mask];h=np.linalg.norm(e[:,:2],axis=1);norm3=np.linalg.norm(e,axis=1)
            rows.append(dict(window=window,error_type=name,samples=len(e),horizontal_rmse_m=float(np.sqrt(np.mean(h*h))),
                             horizontal_peak_m=float(np.max(h)),position_3d_rmse_m=float(np.sqrt(np.mean(norm3**2))),
                             position_3d_peak_m=float(np.max(norm3)),vertical_rmse_m=float(np.sqrt(np.mean(e[:,2]**2))),
                             final_horizontal_error_m=float(h[-1])))
    table('navigation_metrics.csv',rows)
    scene=loadmat(OUT/'metrics.mat',simplify_cells=True)['metrics']
    for etype,key in [('true_tracking','true_horizontal_rmse_m'),('perceived_tracking','estimated_horizontal_rmse_m')]:
        new=next(r['horizontal_rmse_m'] for r in rows if r['window']=='main_15_27' and r['error_type']==etype)
        assert abs(new-float(scene[key]))<1e-12
    noise=json.loads((DOC/'noise_checks.json').read_text())
    table('gnss_parameters.csv',[dict(axis=axis,total_sigma_m=noise['sigma_total_m'][i],white_sigma_m=noise['sigma_white_m'][i],
          slow_sigma_m=noise['sigma_slow_m'][i],drive_sigma_m=noise['sigma_drive_m'][i],tau_s=1000,
          gnss_hz=5,velocity_sigma_m_s=.08,delay_s=.1) for i,axis in enumerate('NED')])
    # 既有桥接的只读诊断记录提供实际融合调用，避免仅以gps_active标志代替融合证据。
    fusion=[]
    for line in (OUT/'ecl_bridge_stderr.txt').read_text(errors='replace').splitlines():
        if line.startswith('FUSEDBG '):
            fields={k:float(v) for k,v in re.findall(r'(\w+)=([^ ]+)',line)}
            if fields['imu_t']>=31000000:fusion.append(fields)
    assert fusion and any(r['obs']==3 and r['healthy']==1 for r in fusion) and any(r['obs']==4 and r['healthy']==1 for r in fusion)
    table('mission_horizontal_fusion.csv',fusion)
    protected=json.loads((DOC/'protected_before.json').read_text())
    for item in protected:
        p=ROOT/item['path'];assert p.stat().st_size==item['bytes'] and sha(p)==item['sha256'],item['path']
    lock=json.loads((DOC/'source_lock.json').read_text())
    for item in lock['new_files']+lock['base_sources']['files']:
        assert sha(ROOT/item['path'].replace('\\','/'))==item['sha256'],item['path']
    assert sha(ROOT/'build/px4_ecl/px4_ecl_bridge.exe')==lock['base_sources']['ekf_executable_sha256']
    checks=json.loads((DOC/'original_scene_checks.json').read_text())
    numerical_pass=bool(checks['data_valid'] and checks['precheck_passed'])
    recovery_pass=not bool(scene['true_recovery_not_reached'])
    result=dict(protected_files_unchanged=len(protected),protected_bytes=sum(x['bytes'] for x in protected),
                versioned_protocol_loaded=True,original_numeric_sources_unchanged=True,new_closed_loop_runs=1,
                full_55s_complete=True,state_samples=len(t),pwm_events=len(L['pwm_time']),gnss_fresh_samples=len(indices),
                gnss_source_alignment_max_abs_m=float(np.max(np.abs(residual))),
                gps_active_all=bool(np.all(L['gps_active'])),position_feedback_valid_all=True,
                actual_hpos_fusion_calls=len(fusion),healthy_hpos_fusion_calls=sum(r['healthy']==1 for r in fusion),
                numerical_and_original_precheck_passed=numerical_pass,original_true_recovery_passed=recovery_pass,
                original_estimated_recovery_passed=not bool(scene['estimated_recovery_not_reached']),
                ready_for_integration=numerical_pass and recovery_pass,
                status='diagnosis_complete_ready_for_integration' if numerical_pass and recovery_pass else 'model_corrected_closeout_blocked_by_true_recovery',
                note='No additional parameter experiments, threshold changes or reruns authorized.')
    (DOC/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    shutil.copyfile(OUT/'execution.log',DOC/'execution.txt')
    fig,axes=plt.subplots(3,1,figsize=(12,10),sharex=True,layout='constrained')
    for key,label in [('true_tracking','True tracking'),('perceived_tracking','Controller perceived tracking'),('local_ekf_error','Local EKF error')]:
        axes[0].plot(t,np.linalg.norm(errors[key][:,:2],axis=1),label=label)
    axes[0].set_ylabel('Horizontal error norm (m)');axes[0].legend()
    for j,axis in enumerate(['North','East']):
        axes[1].plot(t,errors['true_tracking'][:,j],label=f'True {axis}')
        axes[1].plot(t,errors['local_ekf_error'][:,j],ls='--',label=f'Local EKF error {axis}')
    axes[1].set_ylabel('Horizontal component (m)');axes[1].legend(ncol=2)
    axes[2].plot(t,errors['true_tracking'][:,2],label='True tracking Down')
    axes[2].plot(t,errors['perceived_tracking'][:,2],label='Perceived tracking Down')
    axes[2].set_ylabel('Vertical error (m)');axes[2].legend();axes[2].set_xlabel('Mission time (s)')
    for ax in axes:ax.grid(alpha=.3);ax.axvspan(15,27,alpha=.08,color='grey');ax.axvspan(27,37,alpha=.05,color='green')
    fig.suptitle('GNSS GM v2: tau=1000 s, PCA_PREDICTIVE, seed 501, one 55 s regression')
    fig.savefig(DOC/'navigation_regression.png',dpi=150);plt.close(fig)
    (DOC/'local_results_manifest.json').write_text(json.dumps([dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='analysis.log'],indent=2),encoding='utf-8')
    print(json.dumps(result))
    print(json.dumps(rows))


if __name__=='__main__':main()
