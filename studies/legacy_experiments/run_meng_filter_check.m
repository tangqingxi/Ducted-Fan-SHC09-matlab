function summary = run_meng_filter_check()
% 先按Meng图8使用H1/H2，不把论文实飞振动频率自动当作SHC09参数。
folder=ca_setup();
ideal=load(fullfile(folder,'results','ws_gnc_m060','comparison.mat'));
cases={ideal.results};
labels="ideal";
for noise=[0,0.05]
    tag=sprintf('meng_h8_noise%03d',round(noise*1000));
    results=run_ws_gnc_disturbance(struct('measurement_mode',"meng_filtered", ...
        'filter_h1_hz',8,'filter_h2_hz',8,'gyro_noise_std_deg_s',noise, ...
        'methods',["DCA","PCA_PREDICTIVE"],'output_tag',tag,'save_figures',false));
    cases{end+1}=results; %#ok<AGROW>
    labels(end+1)="H1_H2_8Hz_noise_"+string(noise); %#ok<AGROW>
end
rows={};
for k=1:numel(cases)
    result=cases{k};
    selected=result.reference.time_s>=result.config.disturbance_start_s;
    for method=["DCA","PCA_PREDICTIVE"]
        log=result.logs.(method);
        error=rad2deg(log.rotation_error_rad(selected));
        if isfield(log,'measured_alpha_rad_s2')
            alpha_error=log.measured_alpha_rad_s2(selected,:)-log.true_alpha_rad_s2(selected,:);
            alpha_rms=sqrt(mean(alpha_error.^2,'all'));
        else
            alpha_rms=0;
        end
        events=log.pwm_update_time_s>=result.config.disturbance_start_s;
        commands=diff(rad2deg(log.pwm_command_rad(events,:)));
        rows(end+1,:)={char(labels(k)),char(method),sqrt(mean(error.^2)),max(error),alpha_rms, ...
            sqrt(mean(commands.^2,'all')),sum(log.mode(selected)==1),sum(log.mode(selected)==2)}; %#ok<AGROW>
    end
end
summary=cell2table(rows,'VariableNames',{'case_name','method','rotation_rmse_deg','rotation_peak_deg', ...
    'alpha_estimation_rmse_rad_s2','command_step_rms_deg','mode1_count','mode2_count'});
out=fullfile(folder,'results','meng_filter_check');
if ~isfolder(out), mkdir(out); end
writetable(summary,fullfile(out,'comparison.csv'));
save(fullfile(out,'cases.mat'),'cases','labels','summary','-v7');
disp(summary);
end
