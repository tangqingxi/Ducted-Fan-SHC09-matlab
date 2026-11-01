function report=test_f8_pressure_protocol(version)
% 在压力仿真前核对位置与门槛不变、保留种子独立，以及偏航参考导数一致。
if nargin<1,version=1;end
ca_setup();pressure=ca_f8_pressure_protocol([],[],version);[~,~,base,base_protocol]=ca_f8_protocol(pressure.base_position_scenario,101);
maximum_rotation_error=0;maximum_alpha_error=0;preflight=table();
for id=string({pressure.candidates.id})
    [c,m,r,p]=ca_f8_pressure_protocol(id,9002,version);dt=1/c.sample_hz;
    assert(isequal(p.tracking_requirements,base_protocol.tracking_requirements)&&isequal(p.envelope,base_protocol.envelope));
    for field=["position_ned_m","velocity_ned_m_s","acceleration_ned_m_s2","jerk_ned_m_s3","snap_ned_m_s4"]
        assert(isequal(r.(field),base.(field)),'压力预案不得改变位置轨迹。');
    end
    assert(isequal(c.tau_actual_s,0.001*[24;27;30;33;36;40])&&isequal(c.tau_model_s,0.03*ones(6,1)));
    assert(abs(r.euler_rad(end,3))<1e-10&&max(abs(r.omega_body_rad_s([1,end],:)),[],'all')<1e-10);
    assert(max(abs(r.alpha_body_rad_s2([1,end],:)),[],'all')<1e-10);
    for k=2:80:numel(r.time_s)-1
        derivative=(r.rotation_ff(:,:,k+1)-r.rotation_ff(:,:,k-1))/(2*dt);
        error=norm(derivative-r.rotation_ff(:,:,k)*ca_skew(r.omega_body_rad_s(k,:)'),'fro');
        maximum_rotation_error=max(maximum_rotation_error,error);assert(error<1e-3);
        a=(r.omega_body_rad_s(k+1,:)-r.omega_body_rad_s(k-1,:))/(2*dt);
        error=max(abs(a-r.alpha_body_rad_s2(k,:)));maximum_alpha_error=max(maximum_alpha_error,error);assert(error<1e-2);
    end
    x=p.reference_preflight_result;preflight=[preflight;table(id,x.peak_yaw_rate_deg_s,x.peak_yaw_acceleration_deg_s2, ...
        x.peak_body_rate_deg_s,x.peak_body_acceleration_deg_s2,'VariableNames', ...
        {'scenario_id','yaw_rate_peak_deg_s','yaw_acceleration_peak_deg_s2','body_rate_peak_deg_s','body_acceleration_peak_deg_s2'})];
end
assert(isempty(intersect(pressure.development_seeds,pressure.confirmation_seeds)));
report=struct('protocol_id',pressure.protocol_id,'protocol_version',version,'frozen_protocol_hash',p.frozen_protocol_hash, ...
    'engine_fingerprint',allocation_comparison_engine(ca_setup()),'candidates_checked',3,'formal_or_pressure_simulations_run',0,'position_and_task_thresholds_unchanged',true, ...
    'maximum_rotation_derivative_error',maximum_rotation_error,'maximum_alpha_derivative_error',maximum_alpha_error,'preflight',preflight);
disp(report);
end
