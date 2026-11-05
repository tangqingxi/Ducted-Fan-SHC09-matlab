function summary = run_ws_gnc_hover_comparison(overrides)
% 借鉴论文第4节的任务形式，保留本项目公共控制器与含噪测量链。
if nargin<1, overrides=struct(); end
root=ca_setup();
options=struct('amplitudes_nm',[0.4,0.5,0.6,0.7,0.8],'primary_amplitude_nm',0.6, ...
    'duration_s',10,'disturbance_start_s',2,'frequency_hz',[0.5;1;0],'bias_nm',[0;0;0], ...
    'output_tag',char("ws_gnc_hover_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))), ...
    'show_figures',usejava('desktop'),'make_plots',true,'simulation_overrides',struct());
for name=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,name),'未知悬停实验选项：%s',name);
    options.(name)=overrides.(name);
end
assert(isvector(options.amplitudes_nm) && ~isempty(options.amplitudes_nm) ...
    && all(isfinite(options.amplitudes_nm)) && all(options.amplitudes_nm>0) ...
    && numel(unique(options.amplitudes_nm))==numel(options.amplitudes_nm),'扰动幅值配置错误。');
assert(any(abs(options.amplitudes_nm-options.primary_amplitude_nm)<1e-10),'主要幅值必须在扫幅列表内。');
assert(~isempty(regexp(options.output_tag,'^[A-Za-z0-9_-]+$','once')),'输出标签格式错误。');
cfg=ca_config();
for name=reshape(string(fieldnames(options.simulation_overrides)),1,[])
    assert(isfield(cfg,name),'未知公共仿真参数：%s',name);
    cfg.(name)=options.simulation_overrides.(name);
end
% 固定任务定义不被各方法单独改写；所有方法由同一入口得到相同初态和参考。
cfg.plant_model="shc09_6dof"; cfg.flight_mode="position_hold";
cfg.position_reference_ned_m=[0;0;-10]; cfg.initial_position_ned_m=cfg.position_reference_ned_m;
cfg.duration_s=options.duration_s; cfg.disturbance_start_s=options.disturbance_start_s;
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.disturbance_type="sin"; cfg.disturbance_torque_nm=zeros(3,1);
cfg.disturbance_frequency_hz=options.frequency_hz; cfg.disturbance_bias_nm=options.bias_nm;
cfg.disturbance_end_s=Inf;
cfg.save_results=true; cfg.save_figures=false; cfg.show_figures=options.show_figures;
cfg.output_tag=options.output_tag; cfg=ca_validate_config(cfg);
assert(cfg.disturbance_start_s>0 && cfg.disturbance_start_s<cfg.duration_s,'须预留悬停稳定段和扰动评价段。');
out=fullfile(root,'results',options.output_tag);
assert(~isfolder(out),'结果目录已存在，请另设output_tag以保留已有数据。');
mkdir(out);
reference=jsondecode(fileread(fullfile(root,'docs','ws_gnc_hover_reference.json')));
sources=dir(fullfile(root,'**','*.m'));
sources=sources(~contains(string({sources.folder}),[filesep,'reference']));
implementation=cell(numel(sources),2);
for k=1:numel(sources)
    implementation{k,1}=fullfile(sources(k).folder,sources(k).name);
    implementation{k,2}=fileread(implementation{k,1});
end
environment=struct('matlab',version,'created_at',char(datetime('now')));
save(fullfile(out,'provenance.mat'),'reference','options','cfg','environment','implementation','-v7');
summary=struct('options',options,'output_dir',out,'metrics',table(),'case_folders',strings(0,1),'reference',reference);
first_experiment=[];
for amplitude=reshape(options.amplitudes_nm,1,[])
    trial=cfg; trial.disturbance_amplitude_nm=[amplitude;amplitude;0];
    trial=ca_validate_config(trial); model=ca_model(trial); ref=ca_reference(trial);
    experiment=ca_prepare_experiment(trial,ref.time_s);
    if ~isempty(first_experiment)
        assert(isequal(experiment.gyro_noise_rad_s,first_experiment.gyro_noise_rad_s) ...
            && isequal(experiment.attitude_noise_rad,first_experiment.attitude_noise_rad),'不同幅值的测量噪声未配对。');
    else
        first_experiment=experiment;
    end
    case_folder=fullfile(out,sprintf('M%03d',round(amplitude*1000)));
    assert(~isfolder(case_folder),'幅值目录命名冲突，请增大幅值间隔。');
    mkdir(case_folder);
    results=struct('config',trial,'model',model,'reference',ref,'experiment',experiment,'logs',struct());
    for method=trial.methods
        fprintf('悬停扫幅 M=%g N·m，开始 %s。\n',amplitude,method);
        log=ca_simulate(model,trial,ref,method,experiment);
        assert(isequal(log.position_ned_m(1,:),[0,0,-10]),'初态不是指令悬停点。');
        if method~=trial.methods(1)
            first=results.logs.(trial.methods(1));
            assert(isequal(log.gyro_noise_rad_s,first.gyro_noise_rad_s) ...
                && isequal(log.disturbance_torque_nm,first.disturbance_torque_nm) ...
                && isequal(log.pwm_update_time_s,first.pwm_update_time_s),'同幅值各方法条件不一致。');
        end
        results.logs.(method)=log;
        method_folder=fullfile(case_folder,char(method)); mkdir(method_folder);
        save(fullfile(method_folder,'log.mat'),'log','-v7');
        ca_write_logs(log,ref,method_folder);
    end
    results.hover_metrics=ca_hover_metrics(results,amplitude);
    results.physical_metrics=ca_physical_metrics(results);
    save(fullfile(case_folder,'comparison.mat'),'results','-v7');
    writetable(results.hover_metrics,fullfile(case_folder,'hover_metrics.csv'),'Encoding','UTF-8');
    writetable(results.physical_metrics,fullfile(case_folder,'physical_metrics.csv'),'Encoding','UTF-8');
    summary.metrics=[summary.metrics;results.hover_metrics];
    summary.case_folders(end+1)=string(case_folder);
    writetable(summary.metrics,fullfile(out,'comparison.csv'),'Encoding','UTF-8');
    save(fullfile(out,'summary.mat'),'summary','-v7');
    disp(results.hover_metrics(:,{'amplitude_nm','method','position_rmse_m','rate_control_error_rmse_deg_s', ...
        'mode1_count','mode2_count','aero_extrapolated_percent'}));
end
if options.make_plots, plot_ws_gnc_hover_comparison(out,options.show_figures); end
fprintf('定点悬停比较结果：%s\n',out);
end
