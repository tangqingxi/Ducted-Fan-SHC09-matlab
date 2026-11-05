function summary = run_tau_mismatch_check()
% 在同一抗扰工况下对称改变真实时间常数，所有分配器均只知道相同标称模型。
folder=ca_setup();
rows={};
nominal=load(fullfile(folder,'results','ws_gnc_m060','comparison.mat'));
cases={nominal.results};
for actual=[0.024,0.036]
    tag=sprintf('ws_gnc_tau%03d',round(actual*1000));
    fprintf('真实时间常数%g秒，估计模型固定为0.03秒。\n',actual);
    results=run_ws_gnc_disturbance(struct('methods',["DCA","PCA_PREDICTIVE"], ...
        'measurement_mode',"ideal", ...
        'tau_actual_s',actual,'tau_model_s',0.03,'save_figures',false,'output_tag',tag));
    cases{end+1}=results; %#ok<AGROW>
end
for k=1:numel(cases)
    result=cases{k};
    selected=result.reference.time_s>=result.config.disturbance_start_s;
    for method=["DCA","PCA_PREDICTIVE"]
        log=result.logs.(method);
        error=rad2deg(log.rotation_error_rad(selected));
        estimation=rad2deg(log.estimated_delta_rad(selected,:)-log.actual_delta_rad(selected,:));
        complete=log.pwm_prediction_checked;
        prediction=rad2deg(log.pwm_end_prediction_error_rad(complete,:));
        rows(end+1,:)={char(method),result.config.tau_actual_s(1),result.config.tau_model_s(1), ...
            sqrt(mean(error.^2)),max(error),sqrt(mean(estimation.^2,'all')), ...
            max(abs(prediction),[],'all'),sum(log.mode(selected)==1),sum(log.mode(selected)==2)}; %#ok<AGROW>
    end
end
summary=cell2table(rows,'VariableNames',{'method','tau_actual_s','tau_model_s', ...
    'rotation_rmse_deg','rotation_peak_deg','estimated_delta_rmse_deg','max_hold_prediction_error_deg', ...
    'mode1_count','mode2_count'});
out=fullfile(folder,'results','tau_mismatch_check');
if ~isfolder(out), mkdir(out); end
writetable(summary,fullfile(out,'comparison.csv'));
disp(summary);
end
