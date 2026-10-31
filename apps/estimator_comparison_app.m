function study = estimator_comparison_app(output_tag)
% 固定设计的E1/E2估计反馈比较；不搜索控制、分配或估计增益。
root=ca_setup();if nargin<1,output_tag=char("estimator_realism_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));end
assert(startsWith(string(output_tag),"estimator_realism_") && ~isempty(regexp(output_tag,'^[A-Za-z0-9_-]+$','once')));
out=fullfile(root,'results',output_tag);assert(~isfolder(out),'禁止覆盖已有结果。');mkdir(out);
summary=table();status=table();index=0;
for experiment=["E1","E2"]
 seeds=1;if experiment=="E1",seeds=1:3;end
 for seed=seeds
  for mode=["ideal","lite"]
   if experiment=="E1"
    c=ca_config();c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
    c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="record";
   else
    [c,~,~,~]=ca_mismatch_protocol(20,0.6,"load_hold");
   end
   c.estimator_mode=mode;c.navigation_mode="ideal";
   c.gyro_noise_seed=c.gyro_noise_seed+seed-1;c.attitude_noise_seed=c.attitude_noise_seed+seed-1;
   c.disturbance_seed=c.disturbance_seed+seed-1;c.lite_seed=c.lite_seed+seed-1;
   c.show_figures=false;c.save_figures=false;c.save_results=false;c=ca_validate_config(c);
   m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);
   for method=c.methods
    index=index+1;fprintf('%s 配对种子%d %s/%s\n',experiment,seed,mode,method);
    state="completed";message="";
    try
     L=ca_simulate(m,c,r,method,e);L.time_for_metrics=r.time_s;
     windows="whole";if experiment=="E2",windows=["whole","task"];end
     for window=windows
      bounds=[0,c.duration_s];if window=="task",bounds=[6,16];end
      row=ca_mismatch_metrics(L,m,experiment,window,bounds);
      row.estimator_mode=mode;row.seed=seed;
      chosen=r.time_s>=bounds(1) & r.time_s<=bounds(2);
      row.rate_rmse_deg_s=sqrt(mean(sum(rad2deg(L.rate_error_rad_s(chosen,:)).^2,2)));
      row.estimated_attitude_rmse_deg=0;row.estimated_position_rmse_m=0;
      if isfield(L,'estimated_attitude_error_rad')
       row.estimated_attitude_rmse_deg=rad2deg(sqrt(mean(L.estimated_attitude_error_rad(chosen).^2)));
       row.estimated_position_rmse_m=sqrt(mean(sum(L.estimated_position_error_m(chosen,:).^2,2)));
      end
      if isempty(summary),summary=row;else,summary=[summary;row];end
     end
    catch problem
     state="failed";message=string(problem.identifier)+": "+string(problem.message);
     failure=struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
     save(fullfile(out,sprintf('failure_%02d.mat',index)),'failure','c');
    end
    record=table(experiment,seed,mode,method,state,message,'VariableNames',{'experiment','seed','estimator_mode','method','status','message'});
    if isempty(status),status=record;else,status=[status;record];end
    save(fullfile(out,sprintf('config_%02d.mat',index)),'c');
    writetable(status,fullfile(out,'status.csv'),'Encoding','UTF-8');
    if ~isempty(summary),writetable(summary,fullfile(out,'summary.csv'),'Encoding','UTF-8');end
    clear L;
    assert(state=="completed",'shc09:EstimatorExperimentFailed','估计实验失败，结果已保存：%s',message);
   end
  end
 end
end
study=struct('output_dir',out,'summary',summary,'status',status,'E3_run',false);save(fullfile(out,'study.mat'),'study');
end
