function results = platform_run(overrides)
% 平台统一入口；方法由配置及分配接口提供。
if nargin<1, overrides=struct(); end
folder=ca_setup();
cfg=ca_config();
fields=fieldnames(overrides);
for k=1:numel(fields)
    assert(isfield(cfg,fields{k}),'未知配置项：%s',fields{k});
    cfg.(fields{k})=overrides.(fields{k});
end
cfg=ca_validate_config(cfg);
model=ca_model(cfg);
ref=ca_reference(cfg);
experiment=ca_prepare_experiment(cfg,ref.time_s);
out=fullfile(folder,'results',cfg.output_tag);
if cfg.save_results
    assert(~isfolder(out) || cfg.overwrite_results, ...
        '结果目录已存在，请改用新的output_tag，或显式设置overwrite_results=true。');
    if ~isfolder(out), mkdir(out); end
end
results=struct('config',cfg,'model',model,'reference',ref,'logs',struct(), ...
    'environment',struct('matlab',version,'computer',computer,'created_at',char(datetime('now'))));
manifest=jsondecode(fileread(fullfile(folder,'docs','copy_manifest.json')));
results.copy_manifest=manifest;
results.physical_reference=jsondecode(fileread(fullfile(folder,'docs','physical_reference.json')));
if cfg.navigation_mode=="px4_ecl"
    results.navigation_reference=jsondecode(fileread(fullfile(folder,'docs','px4_ecl_reference.json')));
    results.navigation_build=jsondecode(fileread(fullfile(folder,'build','px4_ecl','build_manifest.json')));
end
results.experiment=experiment;
sources=dir(fullfile(folder,'**','*.m'));
sources=sources(~contains(string({sources.folder}),[filesep,'reference']) ...
    & ~contains(string({sources.folder}),[filesep,'third_party']) ...
    & ~contains(string({sources.folder}),[filesep,'archive']) ...
    & ~contains(string({sources.folder}),[filesep,'results']));
results.implementation=struct('paths',strings(numel(sources),1),'contents',{cell(numel(sources),1)});
for k=1:numel(sources)
    results.implementation.paths(k)=string(fullfile(sources(k).folder,sources(k).name));
    results.implementation.contents{k}=fileread(results.implementation.paths(k));
end
fprintf('共同平台：SHC09六舵面，控制%gHz，PWM%gHz，时长%gs。\n',cfg.sample_hz,cfg.pwm_hz,cfg.duration_s);
fprintf('物理模型：%s；飞行模式：%s；测量模式：%s。\n',cfg.plant_model,cfg.flight_mode,cfg.measurement_mode);
fprintf('估计器模式：%s；真实舵机时间常数基值ms：%s；名义模型ms：%s；真实缓变开关：%d。\n', ...
    cfg.estimator_mode,mat2str(1000*cfg.tau_actual_s'),mat2str(1000*cfg.tau_model_s'),cfg.actuator_tau_variation_enabled);
if cfg.navigation_mode=="px4_ecl"
    fprintf('官方ECL先静止对准%g秒，任务控制使用估计位置、速度和姿态。\n',cfg.navigation_warmup_s);
end
if string(cfg.measurement_mode)=="meng_filtered"
    fprintf('H1/H2：%g/%gHz；陀螺仪每采样点噪声标准差%g度/秒；附加传输延迟%gms。\n', ...
        cfg.filter_h1_hz,cfg.filter_h2_hz,cfg.gyro_noise_std_deg_s,1000*cfg.gyro_transport_delay_s);
end
for method=cfg.methods
    fprintf('开始 %s。\n',method);
    log=sim_driver(model,cfg,ref,method,experiment);
    results.logs.(method)=log;
    if method~=cfg.methods(1)
        first=results.logs.(cfg.methods(1));
        assert(isequal(first.pwm_update_time_s,log.pwm_update_time_s) ...
            && isequal(first.pwm_source_time_s,log.pwm_source_time_s),'方法之间的PWM时序不一致。');
        assert(isequal(first.gyro_noise_rad_s,log.gyro_noise_rad_s),'方法之间注入的陀螺仪噪声序列不一致。');
        assert(isequal(first.attitude_noise_rad,log.attitude_noise_rad) ...
            && isequal(first.disturbance_torque_nm,log.disturbance_torque_nm),'方法之间姿态噪声或扰动力矩序列不一致。');
    end
    if cfg.save_results
        method_dir=fullfile(out,char(method));
        if ~isfolder(method_dir), mkdir(method_dir); end
        save(fullfile(method_dir,'log.mat'),'log','-v7');
        ca_write_logs(log,ref,method_dir);
    end
    fprintf('%s完成，耗时%.2fs。\n',method,log.elapsed_s);
end
results.metrics=ca_metrics(results);
if model.plant_model=="shc09_6dof"
    results.physical_metrics=ca_physical_metrics(results);
    if cfg.save_results
        writetable(results.physical_metrics,fullfile(out,'physical_metrics.csv'),'Encoding','UTF-8');
    end
end
if cfg.save_results
    save(fullfile(out,'comparison.mat'),'results','-v7');
    writetable(results.metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
end
if cfg.save_figures, ca_plot(results,out); end
if cfg.save_results, fprintf('结果保存位置：%s\n',out); end
disp(results.metrics);
end
