function diagnosis = diagnose_lite_comparison_peaks(output_tag,study_dir)
% 离线读取默认v0.4或显式指定的数值日志，定位峰值及估计/参考变化，不运行或修改模型。
if nargin<1,output_tag=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));end
assert(~isempty(regexp(char(output_tag),'^[A-Za-z0-9_-]+$','once')));
root=ca_setup();old=fullfile(root,'results','allocation_comparison_research_3seeds');
complete=fullfile(root,'results','allocation_comparison_allocation_comparison_research_resume');
if nargin>=2,complete=string(study_dir);end
B=readtable(fullfile(complete,'status.csv'),'TextType','string');A=B([],:);
if nargin<2,A=readtable(fullfile(old,'status.csv'),'TextType','string');end
plan=B(B.estimator_mode=="lite" & B.status=="completed",:);assert(height(plan)==30);
out=fullfile(root,'results','lite_peak_diagnosis_v050_'+string(output_tag));assert(~isfolder(out),'禁止覆盖诊断证据。');mkdir(out);
D=table();traces=table();
for k=1:height(plan)
 row=plan(k,:);q=A.case_id==row.case_id & A.estimator_mode==row.estimator_mode & A.seed==row.seed & A.method==row.method & A.status=="completed";
 source=complete;if any(q),source=old;end
 saved=load(fullfile(source,'logs',row.log_key+'.mat'),'L','c');L=saved.L;c=saved.c;model=ca_model(c);t=L.time_for_metrics;
 reference_steps=[0;vecnorm(rad2deg(diff(L.desired_euler_rad)),2,2)];
 measured_steps=[0;vecnorm(rad2deg(diff(L.measured_euler_rad)),2,2)];
 position_steps=[0;vecnorm(diff(L.estimated_position_ned_m),2,2)];
 velocity_steps=[0;vecnorm(diff(L.estimated_velocity_ned_m_s),2,2)];
 for window=["whole","task"]
  selected=true(size(t));if window=="task",selected=t>=6 & t<=16;end
  indices=find(selected);[peak,j]=max(L.rotation_error_rad(selected));i=indices(j);
  [~,axis]=max(abs(L.euler_error_rad(i,:)));lo=max(1,i-40);hi=min(numel(t),i+40);
  r=table(row.case_id,row.method,row.seed,window,t(i),rad2deg(peak),rad2deg(L.estimated_attitude_error_rad(i)),axis, ...
   reference_steps(i),measured_steps(i),position_steps(i),velocity_steps(i),norm(L.estimated_position_error_m(i,:)), ...
   norm(L.raw_specific_force_m_s2(i,:))-c.lite_gravity_m_s2,norm(L.v_h(i,:)),norm(L.v_c(i,:)), ...
   max(abs(rad2deg(L.command_rad(i,:)))),max(abs(rad2deg(L.actual_delta_rad(i,:)))), ...
   any(abs(rad2deg(L.command_rad(i,:)))>=40-1e-5),string(source), ...
   'VariableNames',{'case_id','method','seed','window','peak_time_s','peak_deg','estimate_error_at_peak_deg','dominant_axis', ...
   'reference_step_at_peak_deg','measured_step_at_peak_deg','position_step_at_peak_m','velocity_step_at_peak_m_s','estimated_position_error_at_peak_m', ...
   'accel_norm_minus_g_m_s2','vh_norm_rad_s2','vc_norm_rad_s2','command_max_deg','actual_delta_max_deg','command_saturated','source_dir'});
  for a=1:3
   r.("true_euler_"+a+"_deg")=rad2deg(L.euler_rad(i,a));r.("estimated_euler_"+a+"_deg")=rad2deg(L.measured_euler_rad(i,a));r.("desired_euler_"+a+"_deg")=rad2deg(L.desired_euler_rad(i,a));
   r.("omega_"+a+"_deg_s")=rad2deg(L.omega_rad_s(i,a));r.("omega_reference_"+a+"_deg_s")=rad2deg(L.omega_reference_rad_s(i,a));
   r.("vh_"+a+"_rad_s2")=L.v_h(i,a);r.("vc_"+a+"_rad_s2")=L.v_c(i,a);r.("estimated_bias_"+a+"_deg_s")=rad2deg(L.estimated_gyro_bias_rad_s(i,a));
  end
  for a=1:6
   r.("actual_delta_"+a+"_deg")=rad2deg(L.actual_delta_rad(i,a));r.("command_"+a+"_deg")=rad2deg(L.command_rad(i,a));r.("held_command_"+a+"_deg")=rad2deg(L.held_command_rad(i,a));
  end
  for a=1:3,r.("measured_omega_"+a+"_deg_s")=rad2deg(L.measured_omega_rad_s(i,a));end
  r.bias_step_at_peak_deg_s=norm(rad2deg(L.estimated_gyro_bias_rad_s(i,:)-L.estimated_gyro_bias_rad_s(max(1,i-1),:)));
  r.true_euler_step_at_peak_deg=norm(rad2deg(L.euler_rad(i,:)-L.euler_rad(max(1,i-1),:)));
  reconstructed=ca_position_control(L.estimated_position_ned_m(i,:)',L.estimated_velocity_ned_m_s(i,:)',L.desired_euler_rad(i,3),model,c,L.position_reference_ned_m(i,:)');
  r.reference_reconstruction_error=norm(reconstructed-ca_euler_rotation(L.desired_euler_rad(i,:)'),'fro');
  r.pre_peak_error_deg=rad2deg(L.rotation_error_rad(max(1,i-1)));r.post_50ms_error_deg=rad2deg(L.rotation_error_rad(hi));
  r.max_reference_step_near_peak_deg=max(reference_steps(lo:hi));r.max_velocity_step_near_peak_m_s=max(velocity_steps(lo:hi));D=[D;r];
  if window=="task"
   for a=lo:hi
    trace=table(row.case_id,row.method,row.seed,t(a),rad2deg(L.rotation_error_rad(a)),rad2deg(L.estimated_attitude_error_rad(a)), ...
     reference_steps(a),measured_steps(a),velocity_steps(a),position_steps(a),'VariableNames',{'case_id','method','seed','time_s','true_tracking_error_deg','estimate_error_deg','reference_step_deg','measured_step_deg','estimated_velocity_step_m_s','estimated_position_step_m'});
    for b=1:3
     trace.("true_euler_"+b+"_deg")=rad2deg(L.euler_rad(a,b));trace.("estimated_euler_"+b+"_deg")=rad2deg(L.measured_euler_rad(a,b));trace.("desired_euler_"+b+"_deg")=rad2deg(L.desired_euler_rad(a,b));
     trace.("omega_"+b+"_deg_s")=rad2deg(L.omega_rad_s(a,b));trace.("omega_reference_"+b+"_deg_s")=rad2deg(L.omega_reference_rad_s(a,b));trace.("estimated_bias_"+b+"_deg_s")=rad2deg(L.estimated_gyro_bias_rad_s(a,b));
    end
    traces=[traces;trace];
   end
  end
 end
end
writetable(D,fullfile(out,'peaks.csv'),'Encoding','UTF-8');writetable(traces,fullfile(out,'peak_neighborhoods.csv'),'Encoding','UTF-8');
diagnosis=struct('output_dir',out,'peaks',D,'trajectories',30,'read_only',true);save(fullfile(out,'diagnosis.mat'),'diagnosis','-v7');
disp(D(D.window=="task",{'case_id','method','seed','peak_time_s','peak_deg','estimate_error_at_peak_deg','reference_step_at_peak_deg','velocity_step_at_peak_m_s','pre_peak_error_deg','dominant_axis'}));
end
