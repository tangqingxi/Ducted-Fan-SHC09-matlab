"""验证导出层边界、时间、坐标、完整性与参数生效来源。"""
import io
import json
import zipfile

import numpy as np
import pytest
from scipy.io import loadmat,savemat
from scipy.spatial.transform import Rotation

from core.exporter import C,export_flight,frd_quaternion
from core.flight import FlightError,digest,json_bytes,read_flight


@pytest.fixture
def flight(tmp_path):
    t=np.arange(9)/800; n=len(t); xyz=np.tile([.1,.2,-10.],(n,1))
    L={k:np.zeros((n,3)) for k in ['euler','omega','measured_omega','estimated_euler','velocity','estimated_velocity','omega_sp','gamma_sp','gamma_ff','measured_gamma','v_h','v_c','attitude_command']}
    L.update(time_s=t,position=xyz,estimated_position=xyz+[.3,.4,0],control_updated=np.arange(n)%2==0,name='CUSTOM_ALLOCATOR',lambda_=np.full(n,np.nan),mode=np.zeros(n),command=np.zeros((n,6)),actual_delta=np.zeros((n,6)),estimated_delta=np.zeros((n,6)),pwm_time=np.arange(4)/333,pwm_command=np.zeros((4,6)))
    L['lambda']=L.pop('lambda_'); L['v_h'][:]=[1,2,3]; L['v_c'][:]=[4,5,6]
    ref={'time_s':t,'position_ned_m':xyz,'velocity_ned_m_s':np.zeros_like(xyz),'acceleration_ned_m_s2':np.zeros_like(xyz),'euler_rad':L['euler'],'omega_body_rad_s':L['omega']}
    controller={'indi_output_filter_hz':15,'indi_input_filter_hz':15}
    src=tmp_path/'raw.mat'
    savemat(src,{'L':L,'cfg':{'duration_s':t[-1],'navigation_seed':901},'model':{'command_lower':np.full(6,-.7),'command_upper':np.full(6,.7)},'ref':ref,'plan':{'controller':controller,'scenario':'fixture'},'spec':{'seed':901,'parent_controller':{'indi_output_filter_hz':8,'indi_input_filter_hz':8}},'signature':'saved-signature'})
    before=src.read_bytes(); result=export_flight(src,tmp_path/'flight.wtr')
    assert src.read_bytes()==before
    return result


def rewrite(flight, tmp_path, mutate):
    with zipfile.ZipFile(flight.path) as z: data={n:z.read(n) for n in z.namelist()}
    mutate(data)
    path=tmp_path/'bad.wtr'
    with zipfile.ZipFile(path,'w') as z:
        for n,v in data.items(): z.writestr(n,v)
    return path


def test_roundtrip_native_clocks_and_domains(flight):
    assert flight.manifest['method']=='CUSTOM_ALLOCATOR'
    np.testing.assert_allclose(flight.time('actuator_servos_pwm'),np.arange(4)/333,atol=0,rtol=0)
    np.testing.assert_allclose(flight.time('shc09_indi'),np.arange(0,9,2)/800,atol=0,rtol=0)
    assert np.isnan(flight.field('shc09_allocation','lambda')).all()
    assert np.max(np.abs(flight.position('vehicle_local_position')-flight.position('vehicle_local_position_groundtruth')))==pytest.approx(.4)
    expected=np.tile(np.array([5,7,9])@C.T,(5,1))
    np.testing.assert_array_equal(flight.field('shc09_indi','v_h')+flight.field('shc09_indi','v_c'),expected)
    assert 'sensor_accel' not in flight.topics


def test_effective_parameters_and_unknown_defaults(flight):
    values={r['path']:r for r in flight.parameters}
    row=values['controller.indi_output_filter_hz']
    assert row['value']==15 and row['baseline_value']==8 and row['overridden']
    assert flight.manifest['audit']['original']['status']=='unknown'
    assert flight.manifest['execution']['status']=='completed'


def test_frd_attitude_and_geometry(flight):
    q=frd_quaternion(np.zeros((1,3)))
    R=Rotation.from_quat(q[:,[1,2,3,0]]).as_matrix()[0]
    np.testing.assert_allclose(R@np.array([1,0,0]),[0,1,0],atol=1e-15)
    np.testing.assert_allclose(np.linalg.det(R),1,atol=1e-15)
    np.testing.assert_allclose(flight.geometry['vehicle']['hinges_m'][0],[-.267,0,.066],atol=1e-14)
    assert len(flight.geometry['meshes']['vanes'])==6


def test_near_180_quaternion():
    angles=np.array([[.1,.2,np.pi],[0,0,-np.pi]])
    q=frd_quaternion(angles)
    matrices=Rotation.from_quat(q[:,[1,2,3,0]]).as_matrix()
    original=Rotation.from_euler('ZYX',angles[:,::-1]).as_matrix()
    np.testing.assert_allclose(matrices@C,original,atol=1e-14)


def test_no_overwrite_or_legacy_bundle(flight):
    with pytest.raises(FlightError,match='不覆盖'): export_flight(flight.path,flight.path)
    with pytest.raises(FlightError,match='只接受'): read_flight('old.wtr.mat')


@pytest.mark.parametrize('mutation',['hash','member','schema','time','shape','quat'])
def test_invalid_contract(flight,tmp_path,mutation):
    def mutate(data):
        manifest=json.loads(data['manifest.json'])
        if mutation=='hash': data['geometry.json']+=b' '; return
        if mutation=='member': data['../outside']=b'bad'; return
        if mutation=='schema': manifest['schema']='wrong'
        else:
            payload=loadmat(io.BytesIO(data['flight.mat']),simplify_cells=True)
            if mutation=='time': payload['topics']['shc09_indi']['time_s'][1]=0
            if mutation=='shape': payload['topics']['shc09_indi']['v_h']=np.zeros((5,2))
            if mutation=='quat': payload['topics']['vehicle_attitude']['q']*=2
            buffer=io.BytesIO(); savemat(buffer,{k:v for k,v in payload.items() if not k.startswith('__')},long_field_names=True)
            data['flight.mat']=buffer.getvalue(); manifest['members']['flight.mat']={'sha256':digest(data['flight.mat']),'bytes':len(data['flight.mat'])}
        data['manifest.json']=json_bytes(manifest)
    with pytest.raises(FlightError): read_flight(rewrite(flight,tmp_path,mutate))


def test_duplicate_member_rejected(flight,tmp_path):
    path=tmp_path/'duplicate.wtr'; path.write_bytes(flight.path.read_bytes())
    with zipfile.ZipFile(path,'a') as z:
        with pytest.warns(UserWarning): z.writestr('manifest.json',b'{}')
    with pytest.raises(FlightError): read_flight(path)
