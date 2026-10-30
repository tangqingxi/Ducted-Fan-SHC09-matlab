function report = test_platform_baseline()
% 重放既有20秒单方法协议及两秒五方法，不启动正式失配阶梯。
root=ca_setup();d=load(fullfile(root,'tests','baseline','numeric_baseline.mat'),'baseline');baseline=d.baseline;
rows={};
for k=1:numel(baseline.cases)
    item=baseline.cases{k};cfg=ca_validate_config(item.config);model=ca_model(cfg);
    ref=ca_reference(cfg);experiment=ca_prepare_experiment(cfg,ref.time_s);
    log=ca_simulate(model,cfg,ref,item.method,experiment);
    signature=shc09_log_signature(log);
    for field=reshape(string(fieldnames(item.signature)),1,[])
        assert(isfield(signature,field) && strcmp(signature.(field),item.signature.(field)), ...
            'shc09:BaselineChanged','基线字段改变：%s/%s',item.label,field);
    end
    assert(isequal(log.pwm_update_time_s,item.pwm_update_time_s) && isequal(log.pwm_source_time_s,item.pwm_source_time_s), ...
        'shc09:BaselinePWM','PWM事件时间数组改变。');
    for field=reshape(string(fieldnames(item.samples)),1,[])
        assert(isequaln(log.(field)(item.sample_indices,:),item.samples.(field)), ...
            'shc09:BaselineSamples','稀疏数值样本改变：%s/%s',item.label,field);
    end
    metric_log=log;metric_log.time_for_metrics=ref.time_s;
    metrics=ca_mismatch_metrics(metric_log,model,'M0',"whole",[0,cfg.duration_s]);
    assert(isequaln(metrics,item.metrics),'shc09:BaselineMetrics','基线指标改变：%s',item.label);
    rows(end+1,:)={item.label,0,true}; %#ok<AGROW>
end
report=cell2table(rows,'VariableNames',{'case_name','maximum_difference','pwm_exact'});
fprintf('20秒M0及两秒五方法完整非耗时日志SHA逐位一致。\n');
end
