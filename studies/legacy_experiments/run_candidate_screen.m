function summary = run_candidate_screen(overrides)
% 有限候选搜索保留全部结果；达到预定判据后才建议重复试验，不按噪声极小差异宣称优势。
root=ca_setup(); if nargin<1, overrides=struct(); end
options=struct('cases',["figure8_T8","figure8_T12","hover_turning"], ...
    'gyro_seed',20261029,'load_fraction',0.8,'simulation_overrides',struct(), ...
    'output_tag',char("candidate_screen_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))));
for field=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,field),'未知搜索选项：%s',field); options.(field)=overrides.(field);
end
assert(~isempty(regexp(options.output_tag,'^[A-Za-z0-9_-]+$','once')),'结果标签错误。');
out=fullfile(root,'results',options.output_tag); assert(~isfolder(out),'标签已存在。'); mkdir(out);
selection_rule=struct('primary_metric',"yaw_rmse_deg",'relative_improvement_minimum',0.05, ...
    'position_degradation_maximum',0.05,'require_all_completed',true,'require_no_task_extrapolation',true);
summary=struct('options',options,'output_dir',out,'metrics',table(),'status',table(),'selection_rule',selection_rule);
implementation=cell(0,2);
for folder=["config","models","drivers","modules","lib","simulation","experiments","analysis","tests"]
    files=dir(fullfile(root,folder,'**','*.m'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);
        if contains(path,[filesep,'reference',filesep]), continue; end
        implementation(end+1,:)={path,fileread(path)}; %#ok<AGROW>
    end
end
save(fullfile(out,'protocol.mat'),'options','selection_rule','implementation','-v7');
for case_name=reshape(string(options.cases),1,[])
    [cfg,model,ref,protocol]=ca_candidate_protocol(case_name,options.gyro_seed,options.load_fraction,options.simulation_overrides);
    experiment=ca_prepare_experiment(cfg,ref.time_s);
    folder=fullfile(out,case_name); mkdir(folder);
    results=struct('config',cfg,'model',model,'reference',ref,'protocol',protocol,'experiment',experiment,'logs',struct());
    save(fullfile(folder,'inputs.mat'),'cfg','model','ref','protocol','experiment','-v7'); rows={}; first=[];
    for method=cfg.methods
        fprintf('候选%s，%s，%g秒。\n',case_name,method,cfg.duration_s); started=tic;
        try
            log=ca_simulate(model,cfg,ref,method,experiment);
            if ~isempty(first)
                assert(isequal(log.gyro_noise_rad_s,first.gyro_noise_rad_s) ...
                    && isequal(log.disturbance_torque_nm,first.disturbance_torque_nm) ...
                    && isequal(log.pwm_update_time_s,first.pwm_update_time_s),'ca:CandidateUnpaired','输入不配对。');
            else, first=log; end
            results.logs.(method)=log; method_folder=fullfile(folder,method); mkdir(method_folder);
            save(fullfile(method_folder,'log.mat'),'log','-v7'); ca_write_logs(log,ref,method_folder);
            rows(end+1,:)={char(case_name),char(method),'completed','','',toc(started)}; %#ok<AGROW>
        catch problem
            if strcmp(problem.identifier,'ca:CandidateUnpaired'), rethrow(problem); end
            rows(end+1,:)={char(case_name),char(method),'failed',problem.identifier,problem.message,toc(started)}; %#ok<AGROW>
        end
        results.status=cell2table(rows,'VariableNames',{'scenario','method','status','error_id','error_message','elapsed_s'});
        writetable(results.status,fullfile(folder,'status.csv'),'Encoding','UTF-8');
        save(fullfile(folder,'checkpoint.mat'),'results','-v7');
    end
    results.metrics=ca_candidate_metrics(results);
    save(fullfile(folder,'comparison.mat'),'results','-v7');
    writetable(results.metrics,fullfile(folder,'metrics.csv'),'Encoding','UTF-8');
    summary.metrics=[summary.metrics;results.metrics]; summary.status=[summary.status;results.status];
    save(fullfile(out,'summary.mat'),'summary','-v7');
    writetable(summary.metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
    writetable(summary.status,fullfile(out,'status.csv'),'Encoding','UTF-8');
    disp(results.metrics(string(results.metrics.window)=="task",:));
end
fprintf('有限工况筛查完成：%s\n',out);
end
