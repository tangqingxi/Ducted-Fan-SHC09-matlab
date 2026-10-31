function summary = run_estimator_diagnosis()
% 固定增益的物理闭环消融；真值仅用于离线记录。
root=ca_setup();out=fullfile(root,'docs','estimator_diagnosis');if ~isfolder(out),mkdir(out);end
raw=fullfile(root,'results','estimator_diagnosis','D');if ~isfolder(raw),mkdir(raw);end
summary=table();
for id=["D0","D1","D2","D3","D4","D5","D6_0","D6_005","D6_01"]
 c=ca_config();c.estimator_mode="lite";c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
 c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="error";
 c.show_figures=false;c.save_figures=false;c.save_results=false;
 if ismember(id,["D1","D6_0"]),c.gyro_bias_walk_deg_s_sqrt_s=0;end
 if id=="D2",c.accelerometer_bias_m_s2=zeros(3,1);end
 if id=="D3",c.roll_amplitude_deg=0;c.pitch_amplitude_deg=0;c.yaw_amplitude_deg=0;end
 if id=="D4",c.duration_s=30;end
 if id=="D5"
  c.diagnosis_accel_gate_enabled=true;c.diagnosis_accel_gate_m_s2=0.1;c.diagnosis_rate_gate_rad_s=deg2rad(10);
 end
 if id=="D6_005",c.gyro_bias_walk_deg_s_sqrt_s=0.005;end
 c=ca_validate_config(c);m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);
 if id=="D4"
  % 三十秒使用标准E1轨迹；前十秒参考与十二秒版相同，随机流保持共同前缀。
  b=c;b.duration_s=12;rb=ca_reference(b);eb=ca_prepare_experiment(b,rb.time_s);nb=numel(rb.time_s);
  chosen=rb.time_s<=10;
  % 不同长度的向量积分可能有末位差异，显式固定共同评价窗的全部参考字段。
  for field=reshape(string(fieldnames(rb)),1,[])
   r.(field)(1:sum(chosen),:)=rb.(field)(chosen,:);
  end
  e.time_s=r.time_s;
  e.lite=extend_noise(b,eb.lite,numel(e.lite.walk(:,1)));
 end
 fprintf('诊断 %s 开始\n',id);cache=fullfile(raw,id+'.mat');
 if isfile(cache) && dir(cache).bytes>0
  saved=load(cache,'L','c','r');assert(isequaln(saved.c,c) && isequaln(saved.r,r),'诊断缓存配置或参考不一致。');L=saved.L;
 else
  try
   L=ca_simulate(m,c,r,"WLS",e);L.time_for_metrics=r.time_s;
  catch problem
   % 严格物理域失败保留原错误，不更改策略、不虚构三十秒结果。
   failure=struct('case_id',id,'identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
   fid=fopen(fullfile(out,id+'_failure.json'),'w','n','UTF-8');fwrite(fid,jsonencode(failure,PrettyPrint=true),'char');fclose(fid);
   if id~="D4",rethrow(problem);end
   prior=summary(summary.case_id=="D0",:);prior.case_id="D4";summary=[summary;prior];
   prior.window_end_s=30;prior{1,3:end}=nan(1,width(prior)-2);summary=[summary;prior];
   writetable(summary,fullfile(out,'diagnosis.csv'),'Encoding','UTF-8');continue;
  end
 end

 t=r.time_s;a=abs(vecnorm(L.raw_specific_force_m_s2,2,2)-c.lite_gravity_m_s2);w=vecnorm(L.omega_rad_s,2,2);
 bias=rad2deg(L.estimated_gyro_bias_rad_s);truth=bias-rad2deg(L.estimated_gyro_bias_error_rad_s);
 % 健康topic含预热，按日志索引对齐任务创新。
 if isfield(L,'topic_log')
  innovation=zeros(numel(t),1);buslog=L.topic_log.estimator_health;
  for k=1:numel(t),innovation(k)=buslog.data{end-numel(t)+k}.innovation_rad;end
 else
  previous=readtable(fullfile(out,id+'_trace.csv'));innovation=previous.innovation_rad;
 end
 signed_accel_norm_error_m_s2=vecnorm(L.raw_specific_force_m_s2,2,2)-c.lite_gravity_m_s2;
 T=table(t,a,w,innovation,bias,truth,'VariableNames',{'time_s','accel_norm_error_m_s2','omega_norm_rad_s','innovation_rad','estimated_bias_deg_s','true_bias_deg_s'});
 T.signed_accel_norm_error_m_s2=signed_accel_norm_error_m_s2;
 writetable(T,fullfile(out,id+'_trace.csv'),'Encoding','UTF-8');
 if isfield(L,'topic_log'),L=rmfield(L,'topic_log');end;save(fullfile(raw,id+'.mat'),'L','c','r','-v7');
 ends=10;if id=="D4",ends=[10,30];end
 for stop=ends
  q=t<=stop;ae=rad2deg(L.estimated_attitude_error_rad(q));be=rad2deg(L.estimated_gyro_bias_error_rad_s(q,:));
  corrvalue=corrcoef(vecnorm(be,2,2),a(q));rho=corrvalue(1,2);
  envelope=max(abs(be),[],2);last=find(envelope>=0.05,1,'last');settle=NaN;
  if isempty(last),settle=0;elseif last<numel(envelope) && t(find(q,1,'last'))-t(last)>=1,settle=t(last+1);end
  row=table(id,stop,sqrt(mean(ae.^2)),max(ae),max(sqrt(mean(be.^2,1))),max(abs(be(end,:))),rho,settle, ...
   'VariableNames',{'case_id','window_end_s','attitude_rmse_deg','attitude_peak_deg','bias_rmse_max_axis_deg_s','bias_final_max_axis_deg_s','bias_accel_abs_correlation','settling_time_s'});
  summary=[summary;row];disp(row);
 end
 writetable(summary,fullfile(out,'diagnosis.csv'),'Encoding','UTF-8');
end
assert(abs(summary.bias_rmse_max_axis_deg_s(1)-0.0610)<0.005 && abs(summary.bias_final_max_axis_deg_s(1)-0.0583)<0.005,'D0未复现。');
fid=fopen(fullfile(out,'diagnosis.json'),'w','n','UTF-8');fwrite(fid,jsonencode(table2struct(summary),PrettyPrint=true),'char');fclose(fid);
axes=table();
for id=["D0","D1","D2","D3","D5","D6_0","D6_005","D6_01"]
 trace=readtable(fullfile(out,id+'_trace.csv'));chosen=trace.time_s<=10;
 b=trace{chosen,startsWith(string(trace.Properties.VariableNames),"estimated_bias_deg_s_")};
 truth=trace{chosen,startsWith(string(trace.Properties.VariableNames),"true_bias_deg_s_")};
 for axis=1:3
  row=table(id,axis,mean(b(:,axis)),mean(truth(:,axis)),truth(1,axis),truth(end,axis),sqrt(mean((b(:,axis)-truth(:,axis)).^2)), ...
   'VariableNames',{'case_id','axis','estimated_bias_mean_deg_s','true_bias_mean_deg_s','true_bias_start_deg_s','true_bias_final_deg_s','error_rmse_deg_s'});
  axes=[axes;row];
 end
end
writetable(axes,fullfile(out,'bias_axes.csv'),'Encoding','UTF-8');
end

function noise = extend_noise(c,base,n)
% 延长各独立随机流，先消费原十二秒矩阵，再生成新增样本。
nb=size(base.walk,1);extra=n-nb;dt=1/c.sample_hz;noise=base;
stream=RandStream('mt19937ar','Seed',c.lite_seed);randn(stream,nb,3);raw=randn(stream,extra,3);
a=exp(-2*pi*c.gyro_lpf_hz/c.sample_hz);sigma=deg2rad(c.gyro_noise_density_dps_sqrtHz)*sqrt(pi*c.gyro_lpf_hz/2);
for k=1:extra,noise.gyro(nb+k,:)=a*noise.gyro(nb+k-1,:)+sigma*sqrt(1-a*a)*raw(k,:);end
stream=RandStream('mt19937ar','Seed',c.lite_seed+1);randn(stream,nb,3);
noise.walk=[base.walk;base.walk(end,:)+cumsum(deg2rad(c.gyro_bias_walk_deg_s_sqrt_s)*sqrt(dt)*randn(stream,extra,3),1)];
fields={'accel','mag','baro','position','velocity'};
scales={c.accelerometer_noise_std_m_s2,c.magnetometer_noise_std_gauss,c.barometer_noise_std_m,c.gnss_position_std_m(:)',c.gnss_velocity_std_m_s};
for k=1:5
 stream=RandStream('mt19937ar','Seed',c.lite_seed+1+k);width=size(base.(fields{k}),2);randn(stream,nb,width);
 noise.(fields{k})=[base.(fields{k});randn(stream,extra,width).*scales{k}];
end
end
