function test_priority_pilot()
% 检查分段激励的解析中点、空配置兼容、同输入条件及独立射线最优性。
root=ca_setup();
stages=[0,0,0,0;2,0,2,-4;4,0,-2,0];
values=ca_stage_reference([0;2;2.25;2.5;4;4.25;4.5],stages,0.5,zeros(3,1));
expected=[0,0,0;0,0,0;0,1,-2;0,2,-4;0,2,-4;0,0,-2;0,-2,0];
assert(max(abs(values-expected),[],'all')<1e-12,'分段平滑参考的中点或端点错误。');
assert(isequal(ca_stage_reference([0;1],zeros(0,4),0.5,[1;2;3]),[1,2,3;1,2,3]),'空分段配置改变了常值参考。');
cfg=ca_config(); cfg.disturbance_stages_nm=[0,0,0,0;2,0,0,-0.32];
assert(norm(ca_disturbance_torque(2,cfg))==0 && abs(ca_disturbance_torque(2.25,cfg)'*[0;0;1]+0.16)<1e-12,'扰动平滑加载时钟错误。');
cfg.duration_s=1; cfg.position_reference_ned_m=[0;0;-10];
ref=ca_reference(cfg);
assert(isequal(ref.position_ned_m,repmat([0,0,-10],numel(ref.time_s),1)),'默认参考未保持原固定点。');
data=load(fullfile(root,'tests','fixtures','priority_pilot_samples.mat'),'results'); r=data.results;
first=r.logs.(r.config.methods(1));
for method=r.config.methods
    log=r.logs.(method);
    assert(isequal(log.gyro_noise_rad_s,first.gyro_noise_rad_s) && isequal(log.attitude_noise_rad,first.attitude_noise_rad) ...
        && isequal(log.disturbance_torque_nm,first.disturbance_torque_nm) ...
        && isequal(log.pwm_update_time_s,first.pwm_update_time_s),'五方法未使用同一实验输入或PWM时钟。');
    assert(isequal(log.position_reference_ned_m,r.reference.position_ned_m),'位置参考没有按同一时钟进入控制器。');
    checked=log.pwm_prediction_checked;
    assert(max(abs(log.pwm_end_prediction_error_rad(checked,:)),[],'all')<1e-9,'诊断日志改变了匹配舵机的预测一致性。');
end
d=r.diagnostics.PCA_PREDICTIVE; d=d(string(d.reachable_set)=="affine_dynamic",:);
normal=d.native_mode==0 & d.ray_exitflag>0;
assert(max(abs(d.native_lambda(normal)-d.max_tracking_fraction(normal)))<1e-5,'独立LP与预测PCA的最大跟踪系数不一致。');
fprintf('分段激励、参考时钟、五方法配对、PWM预测与离线可达性核对通过。\n');
end
