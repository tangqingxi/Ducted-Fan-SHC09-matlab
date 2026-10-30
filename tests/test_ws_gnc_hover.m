function test_ws_gnc_hover()
% 固定点平移应只改变位置原点，不改变同工况控制结果；指标使用真实位置误差。
ca_setup();
cfg=ca_config(); cfg.duration_s=0.05; cfg.flight_mode="position_hold";
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.disturbance_start_s=0.025; cfg.disturbance_amplitude_nm=[0.6;0.6;0];
cfg=ca_validate_config(cfg); model=ca_model(cfg); ref=ca_reference(cfg);
experiment=ca_prepare_experiment(cfg,ref.time_s);
one=ca_simulate(model,cfg,ref,"PCA_PREDICTIVE",experiment);
cfg.initial_position_ned_m=[0;0;-10]; cfg.position_reference_ned_m=[0;0;-10];
translated_ref=ca_reference(cfg);
two=ca_simulate(model,cfg,translated_ref,"PCA_PREDICTIVE",experiment);
assert(norm(two.position_ned_m(1,:)-[0,0,-10])==0,'定点初态错误。');
assert(max(abs(one.command_rad-two.command_rad),[],'all')<1e-8,'平移改变了分配指令。');
assert(max(abs(two.position_ned_m-one.position_ned_m-[0,0,-10]),[],'all')<1e-9,'平移不满足物理对称性。');
r=struct('config',cfg,'model',model,'reference',translated_ref,'logs',struct());
r.config.methods="PCA_PREDICTIVE"; r.logs.PCA_PREDICTIVE=two;
metrics=ca_hover_metrics(r,0.6);
selected=ref.time_s>=cfg.disturbance_start_s;
error=two.position_ned_m(selected,:)-[0,0,-10];
assert(abs(metrics.position_rmse_m-sqrt(mean(sum(error.^2,2))))<1e-12,'位置向量RMSE定义错误。');
assert(abs(metrics.rate_control_error_rmse_deg_s ...
    -sqrt(mean(sum(rad2deg(two.omega_rad_s(selected,:)-two.omega_reference_rad_s(selected,:)).^2,2))))<1e-12, ...
    '角速度误差没有使用姿态环的角速度指令。');
fprintf('定点初态、平移对称性、位置与角速度指标检查通过。\n');
end
