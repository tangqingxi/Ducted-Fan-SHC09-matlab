function experiment = ca_prepare_experiment(cfg,time_s)
% 借鉴UAV_Algorithm_Benchmark的预生成随机模型；随机调用不发生在动力学积分内部。
time_s=time_s(:);
n=numel(time_s);
experiment.time_s=time_s;
experiment.gyro_noise_rad_s=zeros(n,3);
experiment.attitude_noise_rad=zeros(n,3);
if cfg.feedback_noise_enabled
    if string(cfg.measurement_mode)=="meng_filtered"
        stream=RandStream('mt19937ar','Seed',cfg.gyro_noise_seed);
        experiment.gyro_noise_rad_s=deg2rad(cfg.gyro_noise_std_deg_s)*randn(stream,n,3);
    end
    % 单独随机流使新增姿态噪声不会改变已有陀螺仪随机序列。
    stream=RandStream('mt19937ar','Seed',cfg.attitude_noise_seed);
    experiment.attitude_noise_rad=randn(stream,n,3).*deg2rad(cfg.attitude_noise_std_deg(:)');
end
experiment.disturbance_series=struct('time_s',[],'torque_nm',[]);
if string(cfg.disturbance_type)=="random"
    dt=1/cfg.sample_hz;
    ticks=(0:ceil(cfg.duration_s/dt)+1)'*dt;
    stream=RandStream('mt19937ar','Seed',cfg.disturbance_seed);
    phi=exp(-dt./cfg.random_moment_correlation_s(:));
    sigma=sqrt(1-phi.^2);
    values=zeros(numel(ticks),3);
    values(1,:)=randn(stream,3,1)';
    for k=2:numel(ticks)
        values(k,:)=(phi.*values(k-1,:)'+sigma.*randn(stream,3,1))';
    end
    values=values.*cfg.random_moment_rms_nm(:)';
    experiment.disturbance_series=struct('time_s',ticks,'torque_nm',values);
end
if isfield(cfg,'estimator_mode') && string(cfg.estimator_mode)=="lite"
    experiment.lite=shc09_lite_random(cfg,n+round(cfg.navigation_warmup_s*cfg.sample_hz));
end
experiment.seeds=struct('gyro',cfg.gyro_noise_seed,'attitude',cfg.attitude_noise_seed,'disturbance',cfg.disturbance_seed);
if isfield(cfg,'navigation_mode') && string(cfg.navigation_mode)=="px4_ecl"
    experiment.navigation=ca_navigation_random(cfg,experiment.gyro_noise_rad_s);
end
end
