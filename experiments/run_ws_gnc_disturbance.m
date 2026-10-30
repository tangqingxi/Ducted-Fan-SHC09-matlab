function results = run_ws_gnc_disturbance(overrides)
% 借鉴ws-gnc式(24)的横向力矩注入，比较固定姿态保持；不是完整位置悬停复现。
% 原文未明确给出频率与偏置数值；这里选用0.5/1Hz和零偏置，作为适配参数保存。
if nargin<1, overrides=struct(); end
ca_setup();
settings=struct('plant_model',"hover_linear",'duration_s',10,'roll_amplitude_deg',0,'pitch_amplitude_deg',0, ...
    'yaw_amplitude_deg',0,'disturbance_start_s',2,'disturbance_amplitude_nm',[0.6;0.6;0], ...
    'disturbance_frequency_hz',[0.5;1;0],'disturbance_bias_nm',[0;0;0], ...
    'show_figures',false,'output_tag','ws_gnc_m060');
names=fieldnames(overrides);
for k=1:numel(names), settings.(names{k})=overrides.(names{k}); end
results=main_comparison(settings);
% 单独评价扰动接入之后，不让接入前的零误差稀释抗扰指标。
selected=results.reference.time_s>=results.config.disturbance_start_s;
rows={};
for method=results.config.methods
    log=results.logs.(method);
    attitude=rad2deg(log.rotation_error_rad(selected));
    rates=rad2deg(log.omega_rad_s(selected,:));
    scaled=NaN;
    if startsWith(method,"PCA")
        scaled=100*mean(log.mode(selected)==0 & log.lambda(selected)<1-1e-6);
    end
    rows(end+1,:)={char(method),sqrt(mean(attitude.^2)),max(attitude), ...
        sqrt(mean(sum(rates.^2,2))),100*mean(log.mode(selected)==1),100*mean(log.mode(selected)==2), ...
        scaled}; %#ok<AGROW>
end
results.disturbance_metrics=cell2table(rows,'VariableNames',{'method','rotation_rmse_deg', ...
    'rotation_peak_deg','rate_rmse_deg_s','mode1_percent','mode2_percent','normal_tracking_scaled_percent'});
disp(results.disturbance_metrics);
if results.config.save_results
    out=fullfile(ca_setup(),'results',results.config.output_tag);
    writetable(results.disturbance_metrics,fullfile(out,'disturbance_metrics.csv'),'Encoding','UTF-8');
    save(fullfile(out,'comparison.mat'),'results','-v7');
end
end
