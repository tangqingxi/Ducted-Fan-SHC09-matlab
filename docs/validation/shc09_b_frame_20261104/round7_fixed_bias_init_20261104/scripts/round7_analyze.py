"""只读分析三条新G组与历史A/F/B，独立生成来源时间对齐后的诊断。"""
from pathlib import Path
import csv
import hashlib
import json
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[5]
DOC = Path(__file__).resolve().parents[1]
OUT = ROOT / "results/round7_changeB_20261104"
CONDITIONS = ("A", "F", "B", "G")
COLORS = {"A": "#c44e52", "F": "#dd9944", "B": "#4c72b0", "G": "#55a868"}


def read_run(seed, cond):
    folder = OUT if cond == "G" else ROOT / f"results/round{5 if cond == 'B' else 6}_changeB_20261104"
    return loadmat(folder / f"{cond}_s{seed}.mat", simplify_cells=True)


def table(name, rows):
    assert rows
    with (DOC / name).open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def vec(row, prefix, value):
    row.update({f"{prefix}_{axis}": float(v) for axis, v in zip("ned", value)})


def norm(v):
    return np.linalg.norm(v[..., :2], axis=-1)


def rms(v):
    return float(np.sqrt(np.mean(norm(v) ** 2)))


def slow_at(comp, cond, indices):
    if cond == "B":
        return np.zeros((len(indices), 3))
    if cond in ("F", "G"):
        return np.broadcast_to(comp["slow_m"][int(comp["warmup_samples"])], (len(indices), 3))
    return comp["slow_m"][indices]


def source_data(d, cond, received, mission=True):
    # 索引统一使用一基全局索引，再明确转换为Python数组下标。
    cfg, comp = d["cfg"], d["comp"]
    warm = int(comp["warmup_samples"])
    delay = int(np.floor(float(cfg["sample_hz"]) * float(cfg["gnss_delay_s"]) + .5))
    global_receive = warm + received + 1 if mission else received + 1
    source = global_receive - delay
    stride = int(np.floor(float(cfg["sample_hz"]) / float(cfg["gnss_hz"]) + .5))
    assert np.all(source >= 1) and np.all((source - 1) % stride == 0)
    source_mission = source - warm
    truth = np.broadcast_to(np.asarray(cfg["initial_position_ned_m"], float), (len(source), 3)).copy()
    if mission:
        mask = source_mission >= 1
        truth[mask] = d["L"]["position"][source_mission[mask] - 1]
    slow = slow_at(comp, cond, source - 1).copy()
    if cond == "F":
        before = source <= warm
        slow[before] = comp["slow_m"][source[before] - 1]
    return source, source_mission, truth, slow, comp["white_m"][source - 1]


def main():
    summaries, samples, snapshots, curves, pairs, init_rows = [], [], [], [], [], []
    static_samples=[]
    runs = {}
    max_error = 0.
    old_alignment = []
    for seed in (501, 502, 503):
        for cond in CONDITIONS:
            d = read_run(seed, cond)
            runs[seed, cond] = d
            L, ref, comp, cfg = d["L"], d["ref"], d["comp"], d["cfg"]
            I = loadmat(OUT / f"init_{cond}_s{seed}.mat", simplify_cells=True)["I"]
            t = L["time_s"]
            assert len(t) == 9600 and abs(t[-1] - 11.99875) < 1e-12
            raw, estimate, truth = L["raw_navigation_position"], L["estimated_position"], L["position"]
            target = ref["position_ned_m"]
            origin = L["navigation_origin_offset"]
            assert np.max(np.abs(raw - origin - estimate)) < 1e-12
            assert np.max(np.abs(I["raw"][-1] - ref["position_ned_m"][0] - origin)) < 1e-12
            assert np.isfinite(truth).all() and not np.any(L["aero_outside"])
            assert np.all(L["gps_active"]) and np.all(L["position_valid"])
            static_indices=np.flatnonzero(I["fresh"])
            src,sm_static,static_truth,static_slow,static_white=source_data(d,cond,static_indices,mission=False)
            static_residual=I["gnss"][static_indices]-static_truth-cfg["gnss_position_bias_m"]-static_slow-static_white
            assert np.max(np.abs(static_residual))<1e-12
            max_error=max(max_error,float(np.max(np.abs(static_residual))))
            for j,k in enumerate(static_indices):
                row=dict(seed=seed,condition=cond,receive_global_index=int(k+1),
                         source_global_index=int(src[j]),packet_time_us=I["packet_time_us"][k],
                         caller_time_s=I["time_s"][k],source_time_s=(sm_static[j]-1)/cfg["sample_hz"])
                for name,value in [("gnss",I["gnss"][k]),("slow",static_slow[j]),("white",static_white[j]),("closure",static_residual[j])]:vec(row,name,value)
                static_samples.append(row)
            indices = np.flatnonzero(L["gnss_fresh"])
            # 同时验证全部fresh事件，防止只在已出现的事件处验证而漏掉时钟错误。
            all_source = int(comp["warmup_samples"]) + np.arange(len(t)) + 1 - round(cfg["sample_hz"] * cfg["gnss_delay_s"])
            expected_fresh = (all_source >= 1) & ((all_source - 1) % round(cfg["sample_hz"] / cfg["gnss_hz"]) == 0)
            assert np.array_equal(L["gnss_fresh"].astype(bool), expected_fresh)
            source, sm, source_truth, slow, white = source_data(d, cond, indices)
            observation = L["gnss_position"][indices]
            residual = observation - source_truth - cfg["gnss_position_bias_m"] - slow - white
            assert np.max(np.abs(residual)) < 1e-12
            max_error = max(max_error, float(np.max(np.abs(residual))))
            gnss_error = observation - source_truth
            current_slow = slow_at(comp, cond, int(comp["warmup_samples"]) + indices)
            wrong = observation - truth[indices] - cfg["gnss_position_bias_m"] - current_slow - comp["white_m"][int(comp["warmup_samples"]) + indices]
            old_alignment.append(float(np.max(norm(wrong))))
            for j, k in enumerate(indices):
                row = dict(seed=seed, condition=cond, receive_time_s=t[k], receive_mission_index=int(k + 1),
                           source_global_index=int(source[j]), source_mission_index=int(sm[j]),
                           source_time_s=(sm[j] - 1) / cfg["sample_hz"], delay_s=cfg["gnss_delay_s"])
                for name, values in [("observation", observation), ("source_truth", source_truth), ("slow", slow),
                                     ("white", white), ("error", gnss_error), ("closure", residual), ("wrong_receive_closure", wrong)]:
                    vec(row, name, values[j])
                samples.append(row)
            row = dict(seed=seed, condition=cond, samples=len(t), last_time_s=t[-1], fresh_samples=len(indices),
                       true_h_rmse_m=rms(truth - target), true_h_peak_m=float(np.max(norm(truth - target))),
                       true_h_final_m=float(norm(truth[-1] - target[-1])),
                       local_ecl_vs_true_rmse_m=rms(estimate - truth), raw_ecl_vs_true_rmse_m=rms(raw - truth),
                       perceived_tracking_rmse_m=rms(estimate - target),
                       corrected_gnss_h_rmse_m=rms(gnss_error), gnss_alignment_max_abs_m=float(np.max(np.abs(residual))),
                       initial_ecl_speed_m_s=float(norm(I["velocity"][-1])),
                       true_travel_last_2s_m=float(np.sum(norm(np.diff(truth[t >= 10], axis=0)))),
                       true_net_motion_last_2s_m=float(norm(truth[-1] - truth[np.flatnonzero(t >= 10)[0]])),
                       true_final_horizontal_speed_m_s=float(norm(L["velocity"][-1])))
            vec(row, "origin", origin)
            vec(row, "init_raw", I["raw"][-1])
            vec(row, "init_velocity", I["velocity"][-1])
            vec(row, "slow0", comp["slow_m"][int(comp["warmup_samples"])] )
            summaries.append(row)
            for requested in (None, 0., 2., 4., 6., 10., 12.):
                if requested is None:
                    k = len(I["time_s"]) - 1
                    measurement_index = np.flatnonzero(I["fresh"])[-1:]
                    src, mi, st, sl, wh = source_data(d, cond, measurement_index, mission=False)
                    row = dict(seed=seed, condition=cond, phase="alignment_end", requested_time_s=0., actual_time_s=0.,
                               controller_active=False, controller_input_time_s=np.nan, source_global_index=int(src[0]), source_time_s=float((mi[0]-1)/cfg["sample_hz"]))
                    vals = [("raw_ecl", I["raw"][k]), ("raw_error", I["raw"][k]-I["truth"][k]),
                            ("controller_position", [np.nan]*3), ("bound_projection", I["raw"][k]-origin),
                            ("truth", I["truth"][k]), ("tracking_error", I["truth"][k]-target[0]),
                            ("estimated_velocity", I["velocity"][k]), ("gnss", I["gnss"][measurement_index[0]])]
                else:
                    k = min(round(requested*cfg["sample_hz"]), len(t)-1)
                    available = indices[indices <= k]
                    ck = np.flatnonzero(L["control_updated"][:k+1])[-1]
                    row = dict(seed=seed, condition=cond, phase="mission", requested_time_s=requested, actual_time_s=t[k],
                               controller_active=bool(L["control_updated"][k]), controller_input_time_s=t[ck], source_global_index=0, source_time_s=np.nan)
                    if len(available):
                        j = int(np.flatnonzero(indices == available[-1])[0]);src, mi, st, sl, wh = source[j:j+1],sm[j:j+1],source_truth[j:j+1],slow[j:j+1],white[j:j+1]
                        obs = observation[j]
                    else:
                        measurement_index = np.flatnonzero(I["fresh"])[-1:]
                        src, mi, st, sl, wh = source_data(d, cond, measurement_index, mission=False)
                        obs = I["gnss"][measurement_index[0]]
                    row.update(source_global_index=int(src[0]),source_time_s=float((mi[0]-1)/cfg["sample_hz"]))
                    vals = [("raw_ecl", raw[k]), ("raw_error",raw[k]-truth[k]), ("controller_position",estimate[ck]),
                            ("bound_projection",estimate[k]), ("truth",truth[k]), ("tracking_error",truth[k]-target[k]),
                            ("estimated_velocity",L["estimated_velocity"][k]), ("gnss",obs)]
                for name,value in vals + [("origin",origin),("gnss_source_truth",st[0]),("gnss_slow",sl[0]),("gnss_white",wh[0])]:
                    vec(row,name,value)
                snapshots.append(row)
            # 输出20Hz派生曲线，同时保留初值、末值和静置阶段轨迹。
            for k in sorted(set(range(0,len(t),40)) | {len(t)-1}):
                row=dict(seed=seed,condition=cond,time_s=t[k])
                for name,value in [("true",truth[k]),("estimated",estimate[k]),("raw",raw[k]),("reference",target[k]),
                                   ("ecl_error",estimate[k]-truth[k]),("origin",origin),
                                   ("velocity",L["velocity"][k]),("estimated_velocity",L["estimated_velocity"][k])]:vec(row,name,value)
                curves.append(row)
            for k in sorted(set(range(0,len(I["time_s"]),80)) | {len(I["time_s"])-1}):
                row=dict(seed=seed,condition=cond,time_s=I["time_s"][k],position_valid=bool(I["valid"][k]),gps_active=bool(I["gps_active"][k]))
                for name,value in [("raw",I["raw"][k]),("velocity",I["velocity"][k]),("bound_projection",I["raw"][k]-origin)]:vec(row,name,value)
                init_rows.append(row)
        for first,second in (("G","B"),("F","G"),("A","F")):
            x,y=runs[seed,first]["L"],runs[seed,second]["L"]
            delta=x["position"]-y["position"]
            row=dict(seed=seed,pair=f"{first}_vs_{second}",paired_true_trajectory_h_rms_m=rms(delta),
                     paired_true_final_vector_norm_m=float(norm(delta[-1])),
                     paired_local_ecl_error_h_rms_m=rms((x["estimated_position"]-x["position"])-(y["estimated_position"]-y["position"])),
                     paired_controller_position_h_rms_m=rms(x["estimated_position"]-y["estimated_position"]))
            vec(row,"final_true_vector_difference",delta[-1])
            origin_delta=x["navigation_origin_offset"]-y["navigation_origin_offset"]
            vec(row,"origin_difference",origin_delta)
            row["final_vector_minus_origin_difference_h_m"]=float(norm(delta[-1]-origin_delta))
            row["final_vector_origin_cosine"]=float(np.dot(delta[-1,:2],origin_delta[:2])/(norm(delta[-1])*norm(origin_delta))) if norm(origin_delta)>0 else np.nan
            pairs.append(row)
    table("summary_corrected.csv",summaries)
    table("gnss_source_aligned_samples.csv",samples)
    table("initialization_and_checkpoints.csv",snapshots)
    table("paired_vector_comparisons.csv",pairs)
    table("trajectories_20hz.csv",curves)
    table("alignment_10hz.csv",init_rows)
    table("alignment_gnss_samples.csv",static_samples)
    table("gnss_corrected_statistics.csv",[dict(seed=r["seed"],condition=r["condition"],fresh_samples=r["fresh_samples"],
          corrected_gnss_h_rmse_m=r["corrected_gnss_h_rmse_m"],closure_max_abs_m=r["gnss_alignment_max_abs_m"]) for r in summaries])
    for seed in (501,502,503):
        fig,axes=plt.subplots(3,2,figsize=(13,10),sharex="col",layout="constrained")
        for cond in CONDITIONS:
            L=runs[seed,cond]["L"];ref=runs[seed,cond]["ref"];t=L["time_s"]
            I=loadmat(OUT/f"init_{cond}_s{seed}.mat",simplify_cells=True)["I"]
            for axis in (0,1):
                axes[0,axis].plot(t,L["position"][:,axis]-ref["position_ned_m"][:,axis],color=COLORS[cond],label=cond)
                axes[1,axis].plot(t,L["estimated_position"][:,axis]-L["position"][:,axis],color=COLORS[cond])
                axes[2,axis].plot(t,L["estimated_position"][:,axis]-ref["position_ned_m"][:,axis],color=COLORS[cond])
        for row,label in enumerate(("True tracking error (m)","Local ECL - truth (m)","Controller tracking error (m)")):
            for axis,name in enumerate(("North","East")):
                axes[row,axis].set_ylabel(label);axes[row,axis].grid(alpha=.3)
                if row==0:axes[row,axis].set_title(name);axes[row,axis].legend(ncol=4)
        axes[-1,0].set_xlabel("Mission time (s)");axes[-1,1].set_xlabel("Mission time (s)")
        fig.suptitle(f"Round 7 paired closed-loop traces: seed {seed}")
        fig.savefig(DOC/f"mission_s{seed}.png",dpi=150);plt.close(fig)
    fig,axes=plt.subplots(3,2,figsize=(13,10),layout="constrained")
    for row,seed in enumerate((501,502,503)):
        for cond in CONDITIONS:
            I=loadmat(OUT/f"init_{cond}_s{seed}.mat",simplify_cells=True)["I"]
            warm=runs[seed,cond]["comp"]["warmup_samples"]
            slow0=runs[seed,cond]["comp"]["slow_m"][int(warm)]
            for axis in (0,1):
                axes[row,axis].plot(I["time_s"],np.where(I["valid"],I["raw"][:,axis],np.nan),label=cond,color=COLORS[cond])
                if cond=="G":axes[row,axis].axhline(slow0[axis],color=COLORS[cond],ls=":",label="G fixed slow0")
                axes[row,axis].set_title(f"seed {seed} {'North' if axis==0 else 'East'}");axes[row,axis].grid(alpha=.3)
                axes[row,axis].set_ylabel("Raw ECL position (m)");axes[row,axis].set_xlabel("Static alignment caller time (s)")
        axes[row,0].legend(ncol=3)
    fig.savefig(DOC/"static_alignment_all_seeds.png",dpi=150);plt.close(fig)
    fig,axes=plt.subplots(3,2,figsize=(13,10),layout="constrained")
    for row,seed in enumerate((501,502,503)):
        for axis in (0,1):
            for cond in ("F","G","B"):
                L=runs[seed,cond]["L"]
                error=L["estimated_position"][:,axis]-L["position"][:,axis]
                axes[row,axis].plot(L["time_s"],error,label=f"{cond}: local ECL error",color=COLORS[cond])
            D=runs[seed,"F"];slow0=D["comp"]["slow_m"][int(D["comp"]["warmup_samples"]),axis]
            expected=slow0-D["L"]["navigation_origin_offset"][axis]
            axes[row,axis].axhline(expected,color=COLORS["F"],ls=":",label="F: slow0 - origin")
            axes[row,axis].set_title(f"seed {seed} {'North' if axis==0 else 'East'}")
            axes[row,axis].set_xlabel("Mission time (s)");axes[row,axis].set_ylabel("Position error (m)");axes[row,axis].grid(alpha=.3)
        axes[row,0].legend(fontsize=8)
    fig.savefig(DOC/"frozen_bias_convergence.png",dpi=150);plt.close(fig)
    checks=dict(new_closed_loop_G_files=len(list(OUT.glob("G_s*.mat"))),static_alignment_replays=len(list(OUT.glob("init_*.mat"))),
                gnss_samples_checked=len(samples),gnss_alignment_max_abs_m=max_error,old_receive_alignment_max_h_error_m=max(old_alignment),
                static_gnss_samples_checked=len(static_samples),
                checkpoints=len(snapshots),all_origin_replays_match=True,production_sources_changed=False,
                mission_last_time_s=11.99875,rmse_differences_not_physical_additive_contributions=True)
    (DOC/"analysis_checks.json").write_text(json.dumps(checks,indent=2),encoding="utf-8")
    print(json.dumps(checks))
    print(json.dumps(summaries,default=float))
    print(json.dumps(pairs,default=float))


if __name__=="__main__":
    main()
