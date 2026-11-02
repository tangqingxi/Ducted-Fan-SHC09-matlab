"""独立核对源日志与.wtr；仅读取保存数据，不调用仿真。"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat
from scipy.spatial.transform import Rotation

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'apps/windtrace'))
from core.flight import digest,read_flight


def audit(source,artifact):
    source=Path(source); raw=source.read_bytes(); data=loadmat(source,simplify_cells=True)
    f=read_flight(artifact); L=data['L']; t=np.asarray(L['time_s']).reshape(-1)
    control=np.flatnonzero(np.asarray(L['control_updated']).reshape(-1))
    assert f.manifest['source']['log_sha256']==digest(raw)
    errors={}

    def compare(name,a,b,tolerance=0):
        a,b=np.asarray(a),np.asarray(b)
        if a.size==b.size: a=a.reshape(b.shape)
        assert a.shape==b.shape,(name,a.shape,b.shape)
        assert np.array_equal(np.isnan(a),np.isnan(b)),name
        difference=np.abs(a-b); finite=difference[np.isfinite(difference)]
        value=float(finite.max()) if finite.size else 0.
        assert value<=tolerance,(name,value); errors[name]=value

    compare('estimate_position',f.position('vehicle_local_position'),L['estimated_position'])
    compare('truth_position',f.position('vehicle_local_position_groundtruth'),L['position'])
    compare('reference_position',f.position('trajectory_setpoint'),data['ref']['position_ned_m'])
    compare('state_time',f.time('vehicle_local_position'),t)
    compare('control_time',f.time('shc09_indi'),t[control])
    compare('PWM_time',f.time('actuator_servos_pwm'),L['pwm_time'])
    compare('PWM_command',f.field('actuator_servos_pwm','command_rad'),L['pwm_command'])
    compare('command',f.field('actuator_servos','command_rad'),np.asarray(L['command'])[control])
    compare('actual_vanes',f.field('shc09_vanes','actual'),L['actual_delta'])
    compare('lambda',f.field('shc09_allocation','lambda'),np.asarray(L['lambda'])[control])
    # 逐列手写机体坐标重排，避免复用导出器中的坐标变换常量。
    for key in ['v_h','v_c']:
        old=np.asarray(L[key])[control]; expected=np.column_stack([old[:,1],-old[:,0],old[:,2]])
        compare(key,f.field('shc09_indi',key),expected)
    for topic,key in [('vehicle_attitude','estimated_euler'),('vehicle_attitude_groundtruth','euler')]:
        angles=np.asarray(L[key]); phi,theta,psi=angles.T
        cp,sp,ct,st,cf,sf=np.cos(psi),np.sin(psi),np.cos(theta),np.sin(theta),np.cos(phi),np.sin(phi)
        original=np.stack([cp*ct,cp*st*sf-sp*cf,cp*st*cf+sp*sf,sp*ct,sp*st*sf+cp*cf,sp*st*cf-cp*sf,-st,ct*sf,ct*cf],axis=1).reshape(-1,3,3)
        expected=np.stack([original[:,:,1],-original[:,:,0],original[:,:,2]],axis=2)
        q=f.field(topic,'q'); current=Rotation.from_quat(q[:,[1,2,3,0]]).as_matrix()
        compare(topic+'_rotation',current,expected,2e-14)
    rows={r['path']:r for r in f.parameters}
    for key,value in data['plan']['controller'].items():
        compare('parameter_'+key,rows['controller.'+key]['value'],value)
    assert not f.manifest['unknown_parameter_fields']
    assert source.read_bytes()==raw
    return {'source':source.as_posix(),'artifact':Path(artifact).as_posix(),'source_sha256':digest(raw),'artifact_sha256':digest(Path(artifact).read_bytes()),'method':f.manifest['method'],'seed':f.manifest['seed'],'duration_s':f.manifest['duration_s'],'parameters':len(f.parameters),'topics':len(f.topics),'samples':{'state':len(t),'control':len(control),'PWM':len(f.time('actuator_servos_pwm'))},'errors':errors,'passed':True}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('source',type=Path); p.add_argument('artifact',type=Path); p.add_argument('report',type=Path)
    args=p.parse_args(); report=audit(args.source,args.artifact)
    with args.report.open('x',encoding='utf-8') as stream: json.dump(report,stream,ensure_ascii=False,indent=2)
    print('AUDIT_OK',report['method'],report['seed'])
