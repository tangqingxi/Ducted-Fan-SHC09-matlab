function study = run_horizon_study()
% 在独立短轨迹选择时域，再固定参数运行原30秒轨迹，不按正式结果回调参数。
folder=ca_setup();
out=fullfile(folder,'results','horizon_study');
assert(~isfolder(out),'时域研究目录已存在，请保留旧结果后另设输出目录。');
mkdir(out);
cfg=ca_validate_config(ca_config());
cfg.plant_model="hover_linear";
cfg.measurement_mode="ideal";
cfg.duration_s=6;
cfg.envelope_ramp_s=1;
cfg.yaw_frequency_stages=[0,3];
cfg.show_figures=false;
cfg.save_figures=false;
model=ca_model(cfg);
ref=ca_reference(cfg);
rows={};
tuning=struct();
chosen=struct();
for method=["DCA","PCA_PREDICTIVE"]
    best=Inf;
    for fraction=[0.5,1]
        trial=cfg;
        trial.predictive_horizon_fraction=fraction;
        trial.dca_horizon_s=fraction/cfg.pwm_hz;
        fprintf('调试：%s，保持周期比例%g。\n',method,fraction);
        log=ca_simulate(model,trial,ref,method);
        selected=ref.time_s>=2 & ref.time_s<=5;
        score=sqrt(mean(rad2deg(log.rotation_error_rad(selected)).^2));
        abnormal=sum(log.mode>0);
        % 选择规则预先固定：存在回退或不可证最优时不选；其余取姿态误差较小者。
        admissible=abnormal==0 && all(log.solver_exitflag>0);
        rows(end+1,:)={char(method),fraction,score,abnormal,admissible}; %#ok<AGROW>
        key=char(method+"_f"+string(round(10*fraction)));
        tuning.(key)=struct('config',trial,'log',log);
        if admissible && score<best
            best=score;
            chosen.(method)=fraction;
        end
    end
    assert(isfield(chosen,method),'该方法的候选时域均未通过可用性检查。');
end
study.tuning=cell2table(rows,'VariableNames',{'method','fraction','rotation_rmse_deg','abnormal_count','admissible'});
study.chosen=chosen;
writetable(study.tuning,fullfile(out,'tuning.csv'));
save(fullfile(out,'tuning.mat'),'tuning','chosen','cfg','ref','model','-v7');
disp(study.tuning);
% 正式工况回到原30秒参考；两种方法分别使用短轨迹选出的参数。
overrides=struct('plant_model',"hover_linear",'methods',["DCA","PCA_PREDICTIVE"], ...
    'measurement_mode',"ideal", ...
    'dca_horizon_s',chosen.DCA/cfg.pwm_hz, ...
    'predictive_horizon_fraction',chosen.PCA_PREDICTIVE, ...
    'show_figures',false,'output_tag','horizon_selected');
formal=main_comparison(overrides);
study.formal_metrics=formal.metrics;
save(fullfile(out,'study.mat'),'study','overrides');
end
