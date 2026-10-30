function results = run_priority_pilot(overrides)
% 先稳定建立偏航补偿，再用横向机动检验正常优先级缩减及其代价。
if nargin<1, overrides=struct(); end
root=ca_setup();
options=struct('load_fraction',0.8,'position_amplitude_m',2,'position_transition_s',0.15, ...
    'output_tag',char("priority_pilot_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))), ...
    'show_figures',usejava('desktop'),'make_plots',true,'diagnostic_hz',50, ...
    'simulation_overrides',struct());
for name=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,name),'未知先行实验选项：%s',name); options.(name)=overrides.(name);
end
assert(isscalar(options.load_fraction) && options.load_fraction>0 && options.load_fraction<1,'补偿占用须位于零至一之间。');
assert(isscalar(options.position_amplitude_m) && isfinite(options.position_amplitude_m) && options.position_amplitude_m>0,'机动幅值须为正。');
cfg=ca_config();
for name=reshape(string(fieldnames(options.simulation_overrides)),1,[])
    assert(isfield(cfg,name),'未知公共仿真参数：%s',name); cfg.(name)=options.simulation_overrides.(name);
end
cfg.duration_s=12; cfg.flight_mode="position_hold"; cfg.plant_model="shc09_6dof";
cfg.position_reference_ned_m=[0;0;-10]; cfg.initial_position_ned_m=cfg.position_reference_ned_m;
a=options.position_amplitude_m;
cfg.position_reference_stages=[0,0,0,-10;4,0,a,-10;5.5,0,-a,-10;7,0,a,-10;8.5,0,-a,-10;10,0,0,-10];
cfg.position_transition_s=options.position_transition_s;
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.disturbance_torque_nm=zeros(3,1); cfg.disturbance_amplitude_nm=zeros(3,1); cfg.disturbance_bias_nm=zeros(3,1);
cfg.disturbance_type="constant"; cfg.disturbance_start_s=0; cfg.disturbance_end_s=Inf;
cfg.output_tag=options.output_tag; cfg.show_figures=options.show_figures;
cfg.save_figures=false; cfg.save_results=true; cfg=ca_validate_config(cfg);
assert(isscalar(options.diagnostic_hz) && options.diagnostic_hz>0 && options.diagnostic_hz<=cfg.sample_hz,'诊断频率错误。');
model=ca_model(cfg); C=model.torque_matrix; p=model.parameters;
lp=optimoptions('linprog','Display','none');
[u,~,flag]=linprog(-C(3,:)',[],[],C(1:2,:),zeros(2,1),model.command_lower,model.command_upper,lp);
assert(flag>0,'偏航能力标定失败。');
capacity=C(3,:)*u;
passive=-p.FanDir*p.Duct.k_Q0*model.hover_motor_rad_s^2+p.FanDir*p.k_sta*model.hover_exit_speed_m_s^2;
external_yaw=-options.load_fraction*capacity-passive;
cfg.disturbance_stages_nm=[0,0,0,0;2,0,0,external_yaw;10,0,0,0];
cfg.disturbance_transition_s=0.5; cfg=ca_validate_config(cfg);
ref=ca_reference(cfg); experiment=ca_prepare_experiment(cfg,ref.time_s);
out=fullfile(root,'results',cfg.output_tag);
assert(~isfolder(out),'结果目录已存在，请另设output_tag保留原数据。'); mkdir(out);
results=struct('config',cfg,'options',options,'model',model,'reference',ref,'experiment',experiment, ...
    'logs',struct(),'status',table(),'yaw_capacity_nm',capacity,'external_yaw_nm',external_yaw,'output_dir',out);
sources=dir(fullfile(root,'**','*.m')); sources=sources(~contains(string({sources.folder}),[filesep,'reference']));
implementation=cell(numel(sources),2);
for k=1:numel(sources)
    implementation{k,1}=fullfile(sources(k).folder,sources(k).name);
    implementation{k,2}=fileread(implementation{k,1});
end
environment=struct('matlab',version,'created_at',char(datetime('now')));
save(fullfile(out,'inputs.mat'),'cfg','model','ref','experiment','options','capacity','external_yaw','-v7');
save(fullfile(out,'provenance.mat'),'implementation','environment','-v7');
statuses={};
for method=cfg.methods
    fprintf('偏航补偿占用%.0f%%，横向参考±%gm，开始%s。\n',100*options.load_fraction,a,method);
    started=tic;
    try
        log=ca_simulate(model,cfg,ref,method,experiment);
        results.logs.(method)=log;
        method_dir=fullfile(out,char(method)); mkdir(method_dir);
        save(fullfile(method_dir,'log.mat'),'log','-v7'); ca_write_logs(log,ref,method_dir);
        statuses(end+1,:)={char(method),'completed','','',toc(started)}; %#ok<AGROW>
    catch problem
        statuses(end+1,:)={char(method),'failed',problem.identifier,problem.message,toc(started)}; %#ok<AGROW>
        warning('ca:PilotMethodFailed','%s失败：%s。',method,problem.message);
    end
    results.status=cell2table(statuses,'VariableNames',{'method','status','error_id','error_message','elapsed_s'});
    save(fullfile(out,'checkpoint.mat'),'results','-v7');
    writetable(results.status,fullfile(out,'status.csv'),'Encoding','UTF-8');
end
results.metrics=ca_priority_pilot_metrics(results);
writetable(results.metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
results.diagnostics=struct();
for method=cfg.methods
    if ~isfield(results.logs,method), continue; end
    diagnostics=ca_priority_reachability(results.logs.(method),ref,model,cfg,options.diagnostic_hz,[4,10]);
    results.diagnostics.(method)=diagnostics;
    writetable(diagnostics,fullfile(out,char(method),'reachability.csv'),'Encoding','UTF-8');
end
results.diagnostic_summary=ca_priority_diagnostic_summary(results);
writetable(results.diagnostic_summary,fullfile(out,'reachability_summary.csv'),'Encoding','UTF-8');
save(fullfile(out,'comparison.mat'),'results','-v7');
if options.make_plots, plot_priority_pilot(out,options.show_figures); end
disp(results.metrics(string(results.metrics.window)=="maneuver",:));
disp(results.diagnostic_summary);
fprintf('先行实验保存位置：%s\n',out);
end
