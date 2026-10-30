function test_benchmark_organization()
% 检查随机模型统计特征、输入配对、独立重复及真实状态评价。
folder=ca_setup();
cfg=ca_validate_config(ca_config());
cfg.duration_s=120;
cfg.disturbance_type="random";
cfg.disturbance_start_s=0;
cfg.random_moment_rms_nm=[0.1;0.2;0.03];
time=(0:1/cfg.sample_hz:cfg.duration_s)';
first=ca_prepare_experiment(cfg,time);
again=ca_prepare_experiment(cfg,time);
assert(isequal(first,again),'同种子未产生相同随机输入。');
changed=cfg; changed.disturbance_seed=cfg.disturbance_seed+1;
second=ca_prepare_experiment(changed,time);
assert(~isequal(first.disturbance_series.torque_nm,second.disturbance_series.torque_nm) ...
    && isequal(first.gyro_noise_rad_s,second.gyro_noise_rad_s),'扰动随机流没有独立于测量噪声。');
values=first.disturbance_series.torque_nm;
observed=sqrt(mean(values.^2,1));
assert(all(abs(observed./cfg.random_moment_rms_nm'-1)<0.2),'长序列随机力矩RMS偏离设置过大。');
step=round(0.1*cfg.sample_hz);
for axis=1:3
    correlations=corrcoef(values(1:end-step,axis),values(1+step:end,axis));
    expected=exp(-0.1/cfg.random_moment_correlation_s(axis));
    assert(abs(correlations(1,2)-expected)<0.1,'随机力矩相关时间错误。');
end
with_series=cfg; with_series.disturbance_series=first.disturbance_series;
tick=83;
midpoint=(first.disturbance_series.time_s(tick)+first.disturbance_series.time_s(tick+1))/2;
assert(norm(ca_disturbance_torque(midpoint,with_series)-mean(values(tick:tick+1,:),1)')<1e-10, ...
    '动力学中点未正确插值预生成随机力矩。');
assert(ca_stable_seed(24001,'hold','low',1)==ca_stable_seed(24001,'hold','low',1) ...
    && ca_stable_seed(24001,'hold','low',1)~=ca_stable_seed(24001,'hold','low',2),'重复试验种子不独立或不可复现。');
short=ca_config(); short.duration_s=0.1;
short.roll_amplitude_deg=0; short.pitch_amplitude_deg=0; short.yaw_amplitude_deg=0;
short.attitude_noise_std_deg=[0.034;0.034;0.068];
short.disturbance_type="random"; short.random_moment_rms_nm=[0.05;0.05;0.005];
ref=ca_reference(short); model=ca_model(short); experiment=ca_prepare_experiment(short,ref.time_s);
one=ca_simulate(model,short,ref,"DCA",experiment);
two=ca_simulate(model,short,ref,"PCA_PREDICTIVE",experiment);
assert(isequal(one.attitude_noise_rad,two.attitude_noise_rad) ...
    && isequal(one.gyro_noise_rad_s,two.gyro_noise_rad_s) ...
    && isequal(one.disturbance_torque_nm,two.disturbance_torque_nm),'方法间随机输入未配对。');
assert(norm(one.measured_euler_rad-one.euler_rad,'fro')>1e-6,'姿态噪声没有进入测量状态。');
assert(max(abs(one.rotation_error_rad-vecnorm(one.euler_error_rad,2,2)))<1e-5, ...
    '小角度真实误差评价被错误替换为测量误差。');
% 重绘测试使用人为的大误差和失败行，确认其均保留在汇总计数中。
plotcfg=ca_benchmark_config(); plotcfg.scenarios="hold"; plotcfg.methods="DCA";
plotcfg.levels=plotcfg.levels(1); plotcfg.num_repeats=3;
synthetic=table({'hold';'hold';'hold'},{'low';'low';'low'},{'DCA';'DCA';'DCA'}, ...
    {'completed';'completed';'failed'},[1;100;NaN], ...
    'VariableNames',{'scenario','level','method','status','rotation_rmse_deg'});
out=fullfile(folder,'results','benchmark_plot_test');
if ~isfolder(out), mkdir(out); end
summary=render_disturbance_benchmark(synthetic,plotcfg,out);
assert(summary.completed_count==2 && summary.failed_count==1 && summary.max_rmse_deg==100, ...
    '绘图或汇总静默丢弃了大误差或失败。');
fprintf('随机力矩统计、重放插值、配对噪声、真实状态评价及大误差/失败保留检查通过。\n');
end
