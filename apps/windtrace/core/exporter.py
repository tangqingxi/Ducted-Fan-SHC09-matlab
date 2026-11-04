"""从已保存日志导出单飞行；不调用仿真或读取当前默认协议。"""
from __future__ import annotations

import csv
import io
import json
from pathlib import Path
import zipfile

import numpy as np
from scipy.io import loadmat, savemat
from scipy.io.matlab import MatlabOpaque
from scipy.spatial.transform import Rotation

from core.flight import SCHEMA, FlightError, digest, json_bytes, read_flight, validate

C = np.array([[0., 1., 0.], [-1., 0., 0.], [0., 0., 1.]])
ROOT = Path(__file__).resolve().parents[3]


def frd_quaternion(euler, body_frame=False):
    # 旧日志在旧原生系；新日志在 b 系。两者到 FRD 的旋转不同，不能混用。
    to_frd = C if body_frame else C.T
    matrix = Rotation.from_euler("ZYX", np.asarray(euler).reshape(-1, 3)[:, ::-1]).as_matrix() @ to_frd
    q = Rotation.from_matrix(matrix).as_quat()[:, [3, 0, 1, 2]]
    q[q[:, 0] < 0] *= -1
    return q


def sidecars(source, method, seed):
    base = source.parent.parent
    result = {}; hashes = {}; matched = {}
    for name in ["sources.json", "source_lock.json", "formal_lock.json", "formal_protocol.json", "tuning_protocol.json", "provenance.csv", "status.csv"]:
        path = base/name
        if not path.is_file():
            continue
        raw = path.read_bytes(); hashes[name] = digest(raw)
        if name.endswith(".json"):
            result[name] = json.loads(raw.decode("utf-8-sig"))
        else:
            rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))))
            candidates = [r for r in rows if r.get("method")==method and r.get("seed")==str(seed)]
            # 滤波批同方法／种子存在多配置，须按源文件中的H1/H2再次匹配。
            if source.stem.startswith("H"):
                h1,h2 = source.stem.split("_")[:2]
                candidates = [r for r in candidates if r.get("h1_hz")==str(int(h1[1:])) and r.get("h2_hz")==str(int(h2))]
            if len(candidates) == 1:
                matched[name] = candidates[0]
    return result, hashes, matched


def engine_from(value):
    if isinstance(value, dict):
        if isinstance(value.get("engine"), str):
            return value["engine"]
        for item in value.values():
            found = engine_from(item)
            if found:
                return found
    return None


def parameter_snapshot(data):
    entries = []; arrays = {}; unknown = []

    def walk(value, path, origin):
        if isinstance(value, MatlabOpaque):
            unknown.append(path); value = None; kind = "unknown_matlab_object"
        elif isinstance(value, dict):
            for key, child in value.items():
                walk(child, f"{path}.{key}" if path else key, origin)
            return
        elif isinstance(value, np.ndarray):
            if value.dtype.kind == "O":
                for i, child in enumerate(value.ravel()):
                    walk(child, f"{path}[{i}]", origin)
                return
            if value.size > 128:
                key = f"p{len(arrays):05d}"; arrays[key] = value
                value = {"key":key, "shape":list(value.shape), "dtype":str(value.dtype)}; kind = "array_ref"
            else:
                value = value.tolist(); kind = "array"
        else:
            if isinstance(value, np.generic): value = value.item()
            kind = type(value).__name__
        unit = "unknown"
        for suffix, u in [("_hz","Hz"),("_nm","N m"),("_deg_s","deg/s"),("_deg","deg"),("_rad","rad"),("_m_s2","m/s^2"),("_m_s","m/s"),("_m","m"),("_s","s")]:
            if path.lower().endswith(suffix): unit = u; break
        entries.append({"path":path,"value":_parameter_json(value),"type":kind,"unit":unit,"source":origin,"overridden":False})

    for key in ["cfg","model","ref"]:
        # 参考的完整时间序列由topics保存；参数表仅列参考字段的数组引用。
        if key in data: walk(data[key], key, f"saved.{key}")
    plan = data.get("plan", {})
    walk(plan.get("controller", {}), "controller", "saved.plan.controller")
    for key, value in plan.items():
        if key != "controller": walk(value, "plan."+key, "saved.plan")
    walk(data.get("spec", {}), "scenario", "saved.spec")
    for key in ['navigation_origin_offset','update_counts','ekf_main_updates','ekf_rate_hz','truth_feedback','control_interface_fields','allocator_interface_fields']:
        if key in data.get('L',{}): walk(data['L'][key],'recorded_runtime.'+key,'saved.L')
    parent = data.get("spec", {}).get("parent_controller", {})
    for entry in entries:
        if entry["path"].startswith("controller."):
            key = entry["path"].split(".",1)[1]
            if key in parent:
                original = parent[key]
                if isinstance(original, np.ndarray): original = original.tolist()
                if isinstance(original, np.generic): original = original.item()
                entry["baseline_value"] = _parameter_json(original)
                entry["baseline_source"] = "saved.spec.parent_controller"
                entry["overridden"] = original != entry["value"]
    return {"schema":"windtrace.parameters.v1","entries":entries,"unknown_fields":unknown}, arrays


def _parameter_json(value):
    # JSON标准没有非有限数；使用显式带类型标记保留无限阈值，不能误记为未知或0。
    if isinstance(value,float) and not np.isfinite(value):
        return {"special_float":"NaN" if np.isnan(value) else ("+Inf" if value>0 else "-Inf")}
    if isinstance(value,list): return [_parameter_json(x) for x in value]
    if isinstance(value,dict): return {k:_parameter_json(v) for k,v in value.items()}
    return value


def export_flight(source, output, normalized_input=None):
    source, output = Path(source).resolve(), Path(output).resolve()
    if output.suffix.lower() != ".wtr" or output.exists():
        raise FlightError("输出须为新的.wtr路径，不覆盖已有文件")
    raw_hash = digest(source.read_bytes())
    data = loadmat(normalized_input or source, simplify_cells=True)
    L = data.get("L", {}); cfg = data.get("cfg", {}); ref = data.get("ref", {}); plan = data.get("plan", {})
    model_data = data.get("model", {})
    body_frame = str(model_data.get("coordinate_frame", "old")) == "b"
    to_frd = lambda value: np.asarray(value) @ (C if body_frame else C.T)
    quat = lambda euler: frd_quaternion(euler, body_frame)
    if not {"time_s","position","euler","control_updated"}.issubset(L):
        raise FlightError("当前导出器仅支持保存完整L/cfg/ref/plan的PPID／hover日志")
    method = L.get("name"); seed = data.get("spec", {}).get("seed", cfg.get("navigation_seed"))
    if not isinstance(method, str) or seed is None:
        raise FlightError("日志缺少明确方法或种子")
    seed = int(seed); t = np.asarray(L["time_s"],float).reshape(-1)
    control = np.flatnonzero(np.asarray(L["control_updated"]).reshape(-1))
    topics = {}; specs = {}

    def add(name, times, fields, domain, frame):
        times = np.asarray(times,float).reshape(-1)
        topics[name] = {"time_s":times,"timestamp":np.round(times*1e6).astype(np.uint64)}
        specs[name] = {"domain":domain,"frame":frame,"fields":{}}
        for field, (value, unit, origin) in fields.items():
            value = np.asarray(value)
            if value.size == 0: continue
            value = value.reshape(len(times),-1)
            topics[name][field] = value
            specs[name]["fields"][field] = {"unit":unit,"source":origin,"width":value.shape[1],"allow_nan":field=="lambda"}

    for suffix, prefix, domain in [("","estimated_","estimate"),("_groundtruth","","truth")]:
        fields={}
        for src,keys,unit in [("position",("x","y","z"),"m"),("velocity",("vx","vy","vz"),"m/s")]:
            for i,key in enumerate(keys): fields[key]=(np.asarray(L[prefix+src])[:,i],unit,"L."+prefix+src+f"[:,{i}]")
        add("vehicle_local_position"+suffix,t,fields,domain,"NED")
        add("vehicle_attitude"+suffix,t,{"q":(quat(L[prefix+"euler"]),"1","L."+prefix+"euler")},domain,"FRD_to_NED")
    add("vehicle_angular_velocity",t,{"xyz":(to_frd(L["measured_omega"]),"rad/s","L.measured_omega, estimated-bias-corrected")},"measurement_corrected","FRD")
    add("vehicle_angular_velocity_groundtruth",t,{"xyz":(to_frd(L["omega"]),"rad/s","L.omega")},"truth","FRD")
    add("trajectory_setpoint",ref["time_s"],{
        "position":(ref["position_ned_m"],"m","ref.position_ned_m"),"velocity":(ref["velocity_ned_m_s"],"m/s","ref.velocity_ned_m_s"),
        "acceleration":(ref["acceleration_ned_m_s2"],"m/s^2","ref.acceleration_ned_m_s2")},"reference","NED")
    add("vehicle_attitude_reference",ref["time_s"],{"q":(quat(ref["euler_rad"]),"1","ref.euler_rad")},"reference","FRD_to_NED")
    add("vehicle_rates_reference",ref["time_s"],{"xyz":(to_frd(ref["omega_body_rad_s"]),"rad/s","ref.omega_body_rad_s")},"reference","reference_FRD")
    if "alpha_body_rad_s2" in ref:
        add("vehicle_angular_acceleration_reference",ref["time_s"],{"xyz":(to_frd(ref["alpha_body_rad_s2"]),"rad/s^2","ref.alpha_body_rad_s2")},"reference","reference_FRD")
    if "raw_navigation_position" in L:
        position=np.asarray(L["raw_navigation_position"])
        add("shc09_raw_navigation",t,{key:(position[:,i],"m","L.raw_navigation_position") for i,key in enumerate(["x","y","z"])},"estimate_before_mission_origin","NED")
    add("vehicle_attitude_setpoint",t[control],{"q":(quat(np.asarray(L["attitude_command"])[control]),"1","L.attitude_command")},"setpoint","FRD_to_NED")
    add("vehicle_rates_setpoint",t[control],{"xyz":(to_frd(np.asarray(L["omega_sp"])[control]),"rad/s","L.omega_sp")},"setpoint","estimated_FRD")
    add("shc09_indi",t[control],{key:(to_frd(np.asarray(L[src])[control]),"rad/s^2","L."+src) for key,src in [("v_h","v_h"),("v_c","v_c"),("gamma_sp","gamma_sp"),("gamma_ff","gamma_ff"),("gamma_hat","measured_gamma")]},"controller","estimated_FRD")
    add("shc09_allocation",t[control],{key:(np.asarray(L[key])[control],"1","L."+key) for key in ["lambda","mode"]},"allocator","none")
    add("shc09_vanes",t,{"actual":(L["actual_delta"],"rad","L.actual_delta"),"estimated":(L["estimated_delta"],"rad","L.estimated_delta")},"truth_and_estimate_separate","1-6")
    lo = np.asarray(data["model"]["command_lower"]); hi = np.asarray(data["model"]["command_upper"])
    command = np.asarray(L["command"])[control]
    normalized=2*(command-lo)/(hi-lo)-1
    add("actuator_servos",t[control],{"control":(np.clip(normalized,-1,1),"1","clipped display normalization"),"control_unclipped":(normalized,"1","L.command, unclipped normalization"),"command_rad":(command,"rad","L.command")},"command","1-6")
    add("actuator_servos_pwm",L["pwm_time"],{"command_rad":(L["pwm_command"],"rad","L.pwm_command")},"pwm_latched","1-6")
    extras, hashes, rows = sidecars(source,method,seed)
    provenance = rows.get("provenance.csv", {})
    sig = data.get("signature")
    if not isinstance(sig, str): sig = provenance.get("input_signature_including_plan",provenance.get("input_signature",provenance.get("signature")))
    scenario = plan.get("hover_distance", {}).get("id",plan.get("scenario","unknown"))
    scenario = extras.get('formal_protocol.json',{}).get('scenario_name',scenario)
    parameters, arrays = parameter_snapshot(data)
    geometry_path = Path(__file__).resolve().parents[1]/"assets/geometry_source.json"
    old_geo = json.loads(geometry_path.read_text(encoding="utf-8")); v = old_geo["vehicle"]
    if body_frame and "hinges_b" in model_data:
        hinges_b = np.asarray(model_data["hinges_b"], float).copy()
        # b3 安装坐标无 SDF/CAD 证据；三维显示暂用平面 0，不把 l2 当安装坐标。
        hinges_b[:,2] = np.nan_to_num(hinges_b[:,2], nan=0.0)
        hinges = hinges_b @ C
        theta = np.arctan2(hinges_b[:,1], hinges_b[:,0])
        axes = np.column_stack([np.cos(theta), np.sin(theta), np.zeros(6)]) @ C
    else:
        vertices = np.asarray(v["vane_vertices"]).T
        hinges = np.column_stack([v["l1_m"]*vertices[:,0],v["l1_m"]*vertices[:,1],np.full(6,v["l2_m"])])@C.T
        axes = np.column_stack([-vertices[:,1],vertices[:,0],np.zeros(6)])@C.T
    geometry = {"schema":"windtrace.geometry.v1","frame":"FRD","source_sha256":digest(geometry_path.read_bytes()),"assumed":old_geo["assumed"],
        "vehicle":{"body_box_m":v["body_box_m"],"duct_outer_m":v["duct_outer_m"],"duct_inner_m":v["duct_inner_m"],"vane_limit_rad":v["vane_limit_rad"],"hinges_m":hinges.tolist(),"axes":axes.tolist(),"vane_ids":[str(i) for i in range(1,7)]}}
    from core.visual_geometry import attach_meshes
    geometry = attach_meshes(geometry)
    expected = float(cfg.get("duration_s",t[-1]))
    manifest = {"schema":SCHEMA,"run_id":f"{method}_s{seed}_{raw_hash[:16]}","method":method,"seed":seed,"scenario":scenario,"duration_s":float(t[-1]),
        "execution":{"status":"completed" if abs(t[-1]-expected)<1e-8 else "incomplete","expected_duration_s":expected},
        "audit":{"original":rows.get("status.csv",{"status":"unknown"}),"saved_checks":data.get("checks",{}),"policy":"原驱动记录保留；未知不等于通过"},
        "source":{"log_sha256":raw_hash,"filename":source.name,"sidecar_sha256":hashes,"engine":engine_from(extras) or provenance.get("engine"),"input_signature":sig,"input_signature_scope":"includes_plan" if "input_signature_including_plan" in provenance else "legacy_cfg_model_reference_experiment; complete plan covered by source log SHA","records":extras},
        "exporter":{"version":"1.0","sha256":digest(Path(__file__).read_bytes()),"source_sha256":{str(p.relative_to(ROOT)).replace('\\','/'):digest(p.read_bytes()) for p in [Path(__file__),Path(__file__).with_name('flight.py'),Path(__file__).with_name('visual_geometry.py'),Path(__file__).parents[1]/'ui/glb_model.py',ROOT/'analysis/export_windtrace_flight.m']},"matlab_strings_normalized":normalized_input is not None},
        "time_origin":"relative mission start; no absolute UTC","topics":specs,"missing_topics":["sensor_accel","sensor_mag","sensor_baro","sensor_gps"],"unknown_parameter_fields":parameters["unknown_fields"]}
    # JSON只接受有限普通值；检查结构中的标量不影响原始运行或原门禁。
    manifest["audit"]["saved_checks"] = _plain(manifest["audit"]["saved_checks"])
    validate(manifest,topics,geometry)
    buffer = io.BytesIO(); savemat(buffer,{"topics":topics,"parameter_arrays":arrays},do_compression=True,long_field_names=True)
    members = {"parameters.json":json_bytes(parameters),"flight.mat":buffer.getvalue(),"geometry.json":json_bytes(geometry)}
    manifest["members"] = {k:{"sha256":digest(v),"bytes":len(v)} for k,v in members.items()}
    output.parent.mkdir(parents=True,exist_ok=True)
    with output.open("xb") as stream:
        with zipfile.ZipFile(stream,"w",compression=zipfile.ZIP_DEFLATED) as archive:
            for name,value in {"manifest.json":json_bytes(manifest),**members}.items(): archive.writestr(name,value)
    result = read_flight(output)
    if digest(source.read_bytes()) != raw_hash: raise FlightError("源日志在导出期间变化")
    return result


def _plain(value):
    if isinstance(value,dict): return {k:_plain(v) for k,v in value.items()}
    if isinstance(value,np.ndarray): return _plain(value.tolist())
    if isinstance(value,list): return [_plain(v) for v in value]
    if isinstance(value,np.generic): return _plain(value.item())
    if isinstance(value,float) and not np.isfinite(value): return None
    if isinstance(value,MatlabOpaque): return None
    return value
