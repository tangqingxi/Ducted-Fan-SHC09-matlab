function results = run_restore_ab(overrides)
% 完整复用既有物理对象、参考与随机输入，唯一实验因素是预测PCA的恢复方式。
root=ca_setup();
options=struct('source_tag','restore_source', ...
    'scenario','turning','output_tag',char("restore_ab_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))), ...
    'show_figures',usejava('desktop'));
for field=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,field),'未知恢复实验选项：%s',field); options.(field)=overrides.(field);
end
assert(ismember(string(options.scenario),["fixed","turning"]),'方向场景错误。');
assert(~isempty(regexp(options.output_tag,'^[A-Za-z0-9_-]+$','once')),'输出标签错误。');
source=fullfile(root,'results',options.source_tag,options.scenario,'comparison.mat');
assert(isfile(source),'ca:MissingRestoreSource', ...
    '请先运行README中的恢复A/B源实验，或通过source_tag指定已有方向实验目录。');
d=load(source,'results'); original=d.results;
results=original; results.logs=struct(); results.diagnostics=struct();
results.variants=struct('label',{'PCA_LEGACY','PCA_MIN_CHANGE'}, ...
    'method',{'PCA_PREDICTIVE','PCA_PREDICTIVE'},'restore_mode',{'legacy_norm','minimum_change'});
out=fullfile(root,'results',options.output_tag); assert(~isfolder(out),'结果标签已存在，请另设标签。'); mkdir(out);
results.options=options; results.output_dir=out;
results.config.predictive_restore_mode="legacy_norm";
results.config=ca_validate_config(results.config);
cfg=results.config; ref=results.reference; experiment=results.experiment; model=results.model;
implementation=cell(0,2);
for folder=["config","models","drivers","modules","lib","simulation","experiments","analysis","tests"]
    files=dir(fullfile(root,folder,'**','*.m'));
    for k=1:numel(files)
        path=fullfile(files(k).folder,files(k).name);
        if contains(path,[filesep,'reference',filesep]), continue; end
        implementation(end+1,:)={path,fileread(path)}; %#ok<AGROW>
    end
end
save(fullfile(out,'protocol.mat'),'options','source','cfg','ref','experiment','model','implementation','-v7');
status_rows={}; timing_rows={}; first=[];
for variant=results.variants
    trial=cfg; trial.predictive_restore_mode=string(variant.restore_mode);
    trial=ca_validate_config(trial); fprintf('开始恢复A/B：%s，%g秒。\n',variant.label,trial.duration_s);
    started=tic;
    try
        log=ca_simulate(model,trial,ref,"PCA_PREDICTIVE",experiment);
    catch problem
        % 失败尝试写入状态与检查点，不能把最后一个完成方法当作整个实验已完成。
        status_rows(end+1,:)={variant.label,'failed',toc(started)}; %#ok<AGROW>
        results.status=cell2table(status_rows,'VariableNames',{'variant','status','elapsed_s'});
        results.failure=struct('variant',variant.label,'identifier',problem.identifier,'message',problem.message);
        writetable(results.status,fullfile(out,'status.csv'),'Encoding','UTF-8');
        save(fullfile(out,'checkpoint.mat'),'results','-v7');
        rethrow(problem);
    end
    log.variant_label=variant.label;
    assert(max(log.restore_effect_error)<1e-7,'恢复改变原分配效果。');
    if isempty(first)
        first=log;
        baseline_error=max(abs(log.command_rad-original.logs.PCA_PREDICTIVE.command_rad),[],'all');
        assert(baseline_error<1e-9,'原恢复重跑未复现既有命令，应先检查公共代码变化。');
        results.legacy_reproduction_max_command_error_rad=baseline_error;
    else
        assert(isequal(log.gyro_noise_rad_s,first.gyro_noise_rad_s) ...
            && isequal(log.disturbance_torque_nm,first.disturbance_torque_nm) ...
            && isequal(log.pwm_update_time_s,first.pwm_update_time_s),'A/B输入或PWM时钟不配对。');
        assert(all(log.restore_exitflag>0),'新恢复存在非正常求解。');
    end
    results.logs.(variant.label)=log;
    folder=fullfile(out,variant.label); mkdir(folder);
    save(fullfile(folder,'log.mat'),'log','trial','-v7'); ca_write_logs(log,ref,folder);
    status_rows(end+1,:)={variant.label,'completed',toc(started)}; %#ok<AGROW>
    for window=["whole","maneuver"]
        selected=true(size(ref.time_s));
        if window=="maneuver", selected=ref.time_s>=results.protocol.maneuver_window_s(1) & ref.time_s<results.protocol.maneuver_window_s(2); end
        times=sort(log.solve_time_s(selected)); n=numel(times);
        quantiles=interp1((1:n)',times,1+(n-1)*[0.5,0.95,0.99]);
        timing_rows(end+1,:)={variant.label,char(window),1e3*mean(times),1e3*quantiles(1), ...
            1e3*quantiles(2),1e3*quantiles(3),1e3*max(times),100*mean(times>1/cfg.sample_hz)}; %#ok<AGROW>
    end
    results.status=cell2table(status_rows,'VariableNames',{'variant','status','elapsed_s'});
    writetable(results.status,fullfile(out,'status.csv'),'Encoding','UTF-8');
    save(fullfile(out,'checkpoint.mat'),'results','-v7');
end
[results.metrics,results.terminals]=ca_priority_direction_metrics(results);
results.timing=cell2table(timing_rows,'VariableNames',{'variant','window','mean_ms','median_ms','p95_ms','p99_ms','maximum_ms','over_control_period_percent'});
results.decomposition=ca_allocation_step_decomposition(results,results.protocol.maneuver_window_s);
writetable(results.metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
writetable(results.terminals,fullfile(out,'terminal_metrics.csv'),'Encoding','UTF-8');
writetable(results.timing,fullfile(out,'timing.csv'),'Encoding','UTF-8');
writetable(results.decomposition,fullfile(out,'command_step_decomposition.csv'),'Encoding','UTF-8');
save(fullfile(out,'comparison.mat'),'results','-v7');
plot_priority_direction_study(out,options.show_figures);
disp(results.metrics(string(results.metrics.window)=="maneuver",:)); disp(results.terminals); disp(results.timing);
fprintf('恢复A/B结果保存至：%s\n',out);
end
