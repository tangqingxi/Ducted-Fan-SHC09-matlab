function study = run_priority_direction_study(overrides)
% 固定方向与变化方向成对运行，包含三个显式配权的WLS强基线。
if nargin<1, overrides=struct(); end
root=ca_setup();
options=struct('output_tag',char("priority_direction_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))), ...
    'load_fraction',0.8,'dwell_s',10,'diagnostic_hz',25,'show_figures',usejava('desktop'),'make_plots',true, ...
    'cases',["fixed","turning"],'simulation_overrides',struct());
for name=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,name),'未知方向实验选项：%s',name); options.(name)=overrides.(name);
end
assert(isscalar(options.load_fraction) && isfinite(options.load_fraction) && options.load_fraction>0 && options.load_fraction<1,'负载比例错误。');
assert(~isempty(regexp(options.output_tag,'^[A-Za-z0-9_-]+$','once')),'输出标签错误。');
assert(~isempty(options.cases) && all(ismember(string(options.cases),["fixed","turning"])) ...
    && numel(unique(options.cases))==numel(options.cases),'场景选择错误。');
cfg=ca_config();
for name=reshape(string(fieldnames(options.simulation_overrides)),1,[])
    assert(isfield(cfg,name),'未知公共配置：%s',name); cfg.(name)=options.simulation_overrides.(name);
end
cfg.duration_s=40; cfg.plant_model="shc09_6dof"; cfg.flight_mode="position_hold";
cfg.initial_position_ned_m=[0;0;-10]; cfg.position_reference_ned_m=cfg.initial_position_ned_m;
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.wind_ned_m_s=zeros(3,1); cfg.external_force_ned_n=zeros(3,1);
cfg.disturbance_type="constant"; cfg.disturbance_torque_nm=zeros(3,1);
cfg.disturbance_amplitude_nm=zeros(3,1); cfg.disturbance_bias_nm=zeros(3,1);
cfg.disturbance_start_s=0; cfg.disturbance_end_s=Inf; cfg.disturbance_stages_nm=zeros(0,4);
cfg.position_transition_s=0.15; cfg.disturbance_transition_s=0.75;
cfg.output_tag=options.output_tag; cfg.show_figures=false; cfg.save_figures=false;
cfg=ca_validate_config(cfg); model=ca_model(cfg);
assert(options.diagnostic_hz>0 && options.diagnostic_hz<=cfg.sample_hz,'诊断频率错误。');
protocol=ca_priority_direction_protocol(cfg,model,options.load_fraction,options.dwell_s);
cfg.duration_s=protocol.duration_s;
cfg.position_reference_stages=protocol.position_stages;
variants=struct('label',{'DA_NS','WLS_EQ','WLS_YAW','WLS_TASK','DCA','PCA_STATIC','PCA_PREDICTIVE'}, ...
    'method',{'DA_NS','WLS','WLS','WLS','DCA','PCA_STATIC','PCA_PREDICTIVE'}, ...
    'weights',{[1;1;1],[1;1;1],[1;1;1000],[1;1000;1000],[1;1;1],[1;1;1],[1;1;1]});
out=fullfile(root,'results',options.output_tag); assert(~isfolder(out),'结果目录已存在，请使用新标签。'); mkdir(out);
sources=dir(fullfile(root,'**','*.m')); sources=sources(~contains(string({sources.folder}),[filesep,'reference']));
implementation=cell(numel(sources),2);
for k=1:numel(sources)
    implementation{k,1}=fullfile(sources(k).folder,sources(k).name);
    implementation{k,2}=fileread(implementation{k,1});
end
environment=struct('matlab',version,'created_at',char(datetime('now')));
save(fullfile(out,'protocol.mat'),'options','protocol','cfg','model','variants','environment','implementation','-v7');
study=struct('options',options,'protocol',protocol,'variants',variants,'output_dir',out,'metrics',table(),'terminals',table(),'status',table());
for scenario=reshape(string(options.cases),1,[])
    common=cfg;
    if scenario=="fixed", common.disturbance_stages_nm=protocol.fixed_disturbance_stages;
    else, common.disturbance_stages_nm=protocol.turning_disturbance_stages; end
    common=ca_validate_config(common); ref=ca_reference(common); experiment=ca_prepare_experiment(common,ref.time_s);
    folder=fullfile(out,char(scenario)); mkdir(folder);
    results=struct('config',common,'options',options,'protocol',protocol,'variants',variants, ...
        'reference',ref,'experiment',experiment,'model',model,'logs',struct(),'status',table(),'scenario',scenario);
    save(fullfile(folder,'inputs.mat'),'common','ref','experiment','model','protocol','variants','-v7');
    rows={}; first=[];
    for k=1:numel(variants)
        variant=variants(k); trial=common; trial.methods=string(variant.method); trial.wls_axis_weights=variant.weights;
        trial=ca_validate_config(trial); started=tic;
        fprintf('%s，开始%s；补偿负载%.0f%%，机动驻留%g秒。\n',scenario,variant.label,100*options.load_fraction,options.dwell_s);
        try
            log=ca_simulate(model,trial,ref,string(variant.method),experiment);
            log.variant_label=variant.label;
            if ~isempty(first)
                assert(isequal(log.gyro_noise_rad_s,first.gyro_noise_rad_s) ...
                    && isequal(log.disturbance_torque_nm,first.disturbance_torque_nm) ...
                    && isequal(log.pwm_update_time_s,first.pwm_update_time_s),'ca:UnpairedInputs','方法间输入不一致。');
            else, first=log; end
            results.logs.(variant.label)=log;
            method_dir=fullfile(folder,variant.label); mkdir(method_dir);
            save(fullfile(method_dir,'log.mat'),'log','trial','-v7'); ca_write_logs(log,ref,method_dir);
            rows(end+1,:)={char(scenario),variant.label,'completed','','',toc(started)}; %#ok<AGROW>
        catch problem
            if strcmp(problem.identifier,'ca:UnpairedInputs'), rethrow(problem); end
            rows(end+1,:)={char(scenario),variant.label,'failed',problem.identifier,problem.message,toc(started)}; %#ok<AGROW>
            warning('ca:DirectionTrialFailed','%s/%s失败：%s',scenario,variant.label,problem.message);
        end
        results.status=cell2table(rows,'VariableNames',{'scenario','variant','status','error_id','error_message','elapsed_s'});
        writetable(results.status,fullfile(folder,'status.csv'),'Encoding','UTF-8');
        save(fullfile(folder,'checkpoint.mat'),'results','-v7');
    end
    [results.metrics,results.terminals]=ca_priority_direction_metrics(results);
    writetable(results.metrics,fullfile(folder,'metrics.csv'),'Encoding','UTF-8');
    writetable(results.terminals,fullfile(folder,'terminal_metrics.csv'),'Encoding','UTF-8');
    results.diagnostics=struct();
    for k=1:numel(variants)
        label=variants(k).label; if ~isfield(results.logs,label), continue; end
        diagnostics=ca_priority_reachability(results.logs.(label),ref,model,common,options.diagnostic_hz,protocol.maneuver_window_s);
        results.diagnostics.(label)=diagnostics;
        writetable(diagnostics,fullfile(folder,label,'reachability.csv'),'Encoding','UTF-8');
    end
    summary_input=results; summary_input.config.methods=string({variants.label});
    results.diagnostic_summary=ca_priority_diagnostic_summary(summary_input);
    writetable(results.diagnostic_summary,fullfile(folder,'reachability_summary.csv'),'Encoding','UTF-8');
    save(fullfile(folder,'comparison.mat'),'results','-v7');
    if options.make_plots, plot_priority_direction_study(folder,options.show_figures); end
    study.metrics=[study.metrics;results.metrics]; study.terminals=[study.terminals;results.terminals]; study.status=[study.status;results.status];
    save(fullfile(out,'study.mat'),'study','-v7');
    writetable(study.metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
    writetable(study.terminals,fullfile(out,'terminal_metrics.csv'),'Encoding','UTF-8');
    disp(results.metrics(string(results.metrics.window)=="maneuver",:));
    disp(results.terminals);
end
fprintf('长驻留方向对比保存至：%s\n',out);
end
