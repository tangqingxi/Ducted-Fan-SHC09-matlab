function cfg = ca_benchmark_config()
% 默认六自由度姿态跟踪实验；随机力矩幅值为敏感性设置，尚未标定真实风场。
cfg.scenarios=["hold","tracking"];
cfg.methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
cfg.levels=struct('name',{'low','medium','high'}, ...
    'rms_nm',{[0.025;0.025;0.0025],[0.05;0.05;0.005],[0.08;0.08;0.008]});
cfg.num_repeats=3;
cfg.duration_s=6;
cfg.eval_start_s=2;
cfg.eval_end_s=Inf;
cfg.disturbance_start_s=1;
cfg.disturbance_end_s=Inf;
cfg.moment_correlation_s=[0.35;0.35;0.25];
cfg.gyro_seed_base=43001;
cfg.attitude_seed_base=53001;
cfg.disturbance_seed_base=24001;
cfg.attitude_noise_std_deg=[0.034;0.034;0.068];
cfg.simulation_overrides=struct();
cfg.save_trial_logs=true;
cfg.make_plots=true;
cfg.show_figures=usejava('desktop');
cfg.output_tag='shc09_6dof_random_mc';
end
