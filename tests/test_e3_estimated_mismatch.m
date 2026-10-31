function report = test_e3_estimated_mismatch()
% 两秒M0/M2b覆盖两反馈链，独立重跑检查确定性，不替代正式三十次。
ca_setup();tag=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
a=e3_estimated_mismatch_app('case_ids',["M0","M2b"],'duration_s',2,'output_tag','test_'+tag+'_fresh');assert(a.completed);
b=e3_estimated_mismatch_app('case_ids',["M0","M2b"],'duration_s',2,'output_tag','test_'+tag+'_repeat');assert(b.completed);
left=removevars(a.summary,'simulation_elapsed_s');right=removevars(b.summary,'simulation_elapsed_s');
assert(isequaln(left,right)&&isequaln(a.pareto,b.pareto),'同种子独立重跑不确定。');
assert(height(a.status)==20 && height(a.summary)==60 && numel(unique(a.summary.case_id))==2 && numel(unique(a.summary.estimator_mode))==2);
assert(all(a.provenance.topic_check(a.provenance.estimator_mode=="lite")=="verified_absent") && ~any(b.provenance.loaded));
assert(all(a.summary.window_start_s==0)&&all(a.summary.window_end_s==2));
% 对照实际数值日志：共同输入相同，允许测量随各自物理轨迹变化。
for id=["M0","M2b"]
 for mode=["ideal","lite"]
  methods=unique(a.status.method,'stable');first=load(fullfile(a.output_dir,'logs',id+'_'+mode+'_'+methods(1)+'.mat'));
  for method=reshape(methods,1,[])
   other=load(fullfile(a.output_dir,'logs',id+'_'+mode+'_'+method+'.mat'));
   repeated=load(fullfile(b.output_dir,'logs',id+'_'+mode+'_'+method+'.mat'));
   assert(isequaln(shc09_log_signature(other.L),shc09_log_signature(repeated.L)),'同种子非耗时完整数值日志改变。');
   assert(isequaln(first.c,other.c)&&isequaln(first.r,other.r));
   assert(isequal(first.L.gyro_noise_rad_s,other.L.gyro_noise_rad_s)&&isequal(first.L.disturbance_torque_nm,other.L.disturbance_torque_nm));
   assert(isequal(first.L.position_ned_m(1,:),other.L.position_ned_m(1,:))&&isequal(first.L.omega_rad_s(1,:),other.L.omega_rad_s(1,:)));
  end
 end
end

assert(all(ismember(["common_predicted_torque_error_rms_nm","allocation_demand_error_rms_rad_s2","native_residual_rms","bias_rmse_max_axis_deg_s"],string(a.summary.Properties.VariableNames))));
assert(height(a.pareto)==540 && all(a.pareto.valid) && all(a.pareto.experiment_id=="E3") && numel(unique(a.pareto.case_id))==2);
for file=["summary.csv","pareto.csv","report.md","figures/M2b_time.png","figures/pareto_M2b_lite_task.png"]
 assert(isfile(fullfile(a.output_dir,file)));
end
report=struct('fresh_output',a.output_dir,'repeat_output',b.output_dir,'completed',true,'truth_topics_absent',true,'deterministic',true);disp(report);
end
