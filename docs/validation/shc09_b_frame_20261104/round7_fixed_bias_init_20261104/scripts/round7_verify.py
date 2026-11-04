"""复核历史保护清单、独立重算指标和三条新输入，不启动任何仿真。"""
from pathlib import Path
import csv
import hashlib
import json
import difflib
import subprocess
import numpy as np
from scipy.io import loadmat

ROOT=Path(__file__).resolve().parents[5]
DOC=Path(__file__).resolve().parents[1]
OUT=ROOT/'results/round7_changeB_20261104'


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
    return h.hexdigest()


def verify():
    protected=json.loads((DOC/'protected_before.json').read_text())
    for item in protected:
        p=ROOT/item['path']
        assert p.stat().st_size==item['bytes'] and sha(p)==item['sha256'],item['path']
    with (DOC/'summary_corrected.csv').open() as f: summary=list(csv.DictReader(f))
    with (DOC/'gnss_source_aligned_samples.csv').open() as f: samples=list(csv.DictReader(f))
    with (DOC/'alignment_gnss_samples.csv').open() as f: static_samples=list(csv.DictReader(f))
    max_metric_error=0.
    checks=[]
    for seed in (501,502,503):
        G=loadmat(OUT/f'G_s{seed}.mat',simplify_cells=True)
        comp=G['comp'];slow0=comp['slow_m'][int(comp['warmup_samples'])]
        assert np.array_equal(G['experiment']['navigation']['gnss_position_m'],comp['white_m']+slow0)
        for cond in ('A','F','B','G'):
            folder=OUT if cond=='G' else ROOT/f"results/round{5 if cond=='B' else 6}_changeB_20261104"
            D=loadmat(folder/f'{cond}_s{seed}.mat',simplify_cells=True)
            assert np.array_equal(D['comp']['white_m'],comp['white_m'])
            assert np.array_equal(D['comp']['slow_m'],comp['slow_m'])
            L=D['L'];r=next(x for x in summary if int(x['seed'])==seed and x['condition']==cond)
            error=L['position'][:,:2]-D['ref']['position_ned_m'][:,:2]
            rmse=np.sqrt(np.mean(np.sum(error**2,axis=1)))
            delta=abs(rmse-float(r['true_h_rmse_m']));assert delta<1e-12
            max_metric_error=max(max_metric_error,delta)
            I=loadmat(OUT/f'init_{cond}_s{seed}.mat',simplify_cells=True)
            assert np.array_equal(I['origin'],L['navigation_origin_offset'])
            static_rows=[x for x in static_samples if int(x['seed'])==seed and x['condition']==cond]
            assert len(static_rows)==150
            for sr in static_rows:
                k=int(sr['receive_global_index'])-1;source=int(sr['source_global_index'])-1
                assert source==k-80 and source%160==0
                for axis,j in [('n',0),('e',1),('d',2)]:
                    expected_slow=0. if cond=='B' else slow0[j] if cond=='G' else comp['slow_m'][source,j]
                    assert abs(float(sr[f'slow_{axis}'])-expected_slow)<1e-12
                    assert abs(float(sr[f'white_{axis}'])-comp['white_m'][source,j])<1e-12
                    observed=I['I']['gnss'][k,j]
                    expected=float(D['cfg']['initial_position_ned_m'][j])+float(D['cfg']['gnss_position_bias_m'][j])+expected_slow+comp['white_m'][source,j]
                    assert abs(observed-expected)<1e-12
            rows=[x for x in samples if int(x['seed'])==seed and x['condition']==cond]
            assert len(rows)==60
            for row in rows:
                recv=int(row['receive_mission_index'])-1
                source=recv-80
                for axis,j in [('n',0),('e',1),('d',2)]:
                    assert abs(float(row[f'source_truth_{axis}'])-L['position'][source,j])<1e-12
                    assert abs(float(row[f'error_{axis}'])-(L['gnss_position'][recv,j]-L['position'][source,j]))<1e-12
            checks.append({'seed':seed,'condition':cond,'origin_replay_exact':True,'white_sequence_exact':True,'fresh_sources_checked':len(rows)})
        A=loadmat(OUT/f'init_A_s{seed}.mat',simplify_cells=True)['I']
        F=loadmat(OUT/f'init_F_s{seed}.mat',simplify_cells=True)['I']
        for key in A:assert np.array_equal(A[key],F[key],equal_nan=True),key
    log=(OUT/'execution.log').read_text(encoding='utf-8',errors='replace')
    assert log.count('ROUND7_NEW_CLOSED_LOOP')==3 and 'ROUND7_ALL_RUNS_DONE' in log
    assert len(list(OUT.glob('G_s*.mat')))==3 and len(list(OUT.glob('init_*.mat')))==12
    origin_source=(ROOT/'research/ppid_pindi/ppid_estimator_init.m').read_text(encoding='utf-8')
    logging_source=(DOC/'scripts/round7_init.m').read_text(encoding='utf-8')
    (DOC/'initializer_logging_only.diff').write_text(''.join(difflib.unified_diff(origin_source.splitlines(True),logging_source.splitlines(True),fromfile='production/ppid_estimator_init.m',tofile='diagnostic/round7_init.m')),encoding='utf-8')
    manifest=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(OUT.glob('*.mat'))]
    (DOC/'local_mat_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    result={'protected_files_unchanged':len(protected),'protected_bytes':sum(x['bytes'] for x in protected),
            'new_closed_loop_runs':3,'stationary_alignment_replays':12,'gnss_samples_verified':len(samples),
            'static_gnss_samples_verified':len(static_samples),
            'maximum_independent_metric_error_m':max_metric_error,'A_F_alignment_arrays_exact':True,
            'formal_results_and_sources_changed':False,'checks':checks}
    (DOC/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='checks'}))


if __name__=='__main__':verify()
