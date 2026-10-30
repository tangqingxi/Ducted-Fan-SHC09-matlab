function test_plugin_conformance()
% 冻结上下文、确定性、限幅、清单和真值隔离适用于全部注册插件。
cfg=ca_validate_config(ca_config());model=ca_model(cfg);entries=registry();
B=model.acceleration_matrix;timing=ca_pwm_timing(0.0007,cfg,model.trim_delta_rad);
for scale=[0,0.1,1,2]
    ctx=shc09_allocator_context([0;0;1],scale*B*model.command_upper,model.trim_delta_rad,model,cfg,timing);
    verify_fields(ctx);
    for entry=entries
        m=entry.manifest();assert(m.name==entry.name && strlength(m.version)>0 && m.max_solve_time_s>0);
        assert(all(isfield(m,{'requires','info_fields','supports'})));
        [a,ia]=entry.allocate(ctx);[b,ib]=entry.allocate(ctx);
        assert(isequaln(a,b) && isequaln(ia,ib),'插件不确定。');
        assert(isequal(size(a),[6,1]) && all(isfinite(a)) && all(a>=model.command_lower-1e-7 & a<=model.command_upper+1e-7));
        assert(all(isfield(ia,cellstr(m.info_fields))));
    end
end
poison=cfg;poison.vane_gain_scale=[1;1;0.7;1;1;1];poison.aero_low_speed_model="hold_90";
poison.tau_actual_s=2*cfg.tau_actual_s;poison.gyro_bias_deg_s=[1;2;3];
a=shc09_allocator_context(zeros(3,1),zeros(3,1),zeros(6,1),model,cfg,timing);
b=shc09_allocator_context(zeros(3,1),zeros(3,1),zeros(6,1),model,poison,timing);
assert(isequaln(a,b),'真实参数改变了插件上下文。');
overrides=struct('duration_s',0.2,'flight_mode',"position_hold",'aero_low_speed_model',"hold_90", ...
 'aero_extrapolation_policy',"error",'show_figures',false,'save_figures',false,'save_results',false);
r=main("EXAMPLE_PINV",overrides);assert(isfield(r.logs,'EXAMPLE_PINV'));
end
function verify_fields(value)
% 递归检查字段，名义inertia/torque_matrix是原DCA目标函数所需的固定度量。
if ~isstruct(value),return;end
for name=reshape(string(fieldnames(value)),1,[])
    assert(~any(startsWith(name,["vane_","aero_","tau_actual","disturbance","gyro_bias", ...
        "actuator_tau_variation","accelerometer_bias","magnetometer_bias"])) && name~="parameters", ...
        '真实对象字段进入插件：%s',name);
    verify_fields(value.(name));
end
end
