function report = test_mismatch_runner()
% 两秒成对烟雾测试覆盖十次运行、原始数据输出与严格气动门禁。
ca_setup();
tag=char("mismatch_ladder_smoke_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
study=run_mismatch_ladder(struct('output_tag',tag,'duration_s',2,'case_ids',["M0","M2b"],'fail_fast',true));
assert(study.completed,'严格门禁烟雾测试未完成；查看%s',study.output_dir);
assert(height(study.status)==10 && all(string(study.status.status)=="completed"),'烟雾测试方法缺失。');
assert(all(study.summary.aero_extrapolated_percent==0),'烟雾测试发生气动外推。');
for filename=["cases.csv","summary.csv","status.csv","inputs.mat","provenance.mat","report.md"]
    assert(isfile(fullfile(study.output_dir,filename)),'缺少实验根目录输出。');
end
definitions=readtable(fullfile(study.output_dir,'cases.csv'),'TextType','string');
assert(all(ismember(["rowspace_mismatch","nullspace_mismatch"],string(definitions.Properties.VariableNames))), ...
    '工况失配指标缺失。');
assert(definitions.rowspace_mismatch(definitions.case_id=="M2b")>0.05,'烟雾工况未包含真正行空间失配。');
assert(all(ismember(["low_speed_regularized_percent","position_metric_role"],string(study.summary.Properties.VariableNames))), ...
    '新汇总列缺失。');
for id=["M0","M2b"]
    first=[];
    for method=study.config.methods
        folder=fullfile(study.output_dir,id,method); saved=load(fullfile(folder,'log.mat'));
        names=string(readtable(fullfile(folder,'control.csv'),'VariableNamingRule','preserve').Properties.VariableNames);
        required=["moment_model_error_nm","effective_delta_rad_1","effective_delta_rad_6", ...
            "vane_incremental_gain_1","vane_incremental_gain_6","actual_deg_1","estimated_deg_1","low_speed_regularized"];
        assert(all(ismember(required,names)) && isfile(fullfile(folder,'pwm.csv')),'日志列缺失或旧列被删除。');
        assert(size(saved.log.effective_delta_rad,2)==6 && size(saved.log.vane_incremental_gain,2)==6,'新日志形状错误。');
        if ~isempty(first)
            assert(isequal(saved.log.gyro_noise_rad_s,first.gyro_noise_rad_s) ...
                && isequal(saved.log.disturbance_torque_nm,first.disturbance_torque_nm) ...
                && isequal(saved.log.pwm_update_time_s,first.pwm_update_time_s),'同工况方法未配对。');
        else, first=saved.log; end
    end
end
report=struct('output_dir',study.output_dir,'completed',10,'aero_extrapolated_percent',0);
fprintf('两秒M0/M2b十次烟雾测试通过：%s\n',study.output_dir);
end
