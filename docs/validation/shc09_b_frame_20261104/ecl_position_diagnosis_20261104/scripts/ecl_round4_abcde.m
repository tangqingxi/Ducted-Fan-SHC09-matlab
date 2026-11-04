base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup; addpath(fullfile(base,'research','ppid_pindi'));
[cfg,model,~,plan]=ppid_config(501); n=round(12*cfg.sample_hz); dt=1/cfg.sample_hz; ref=struct('time_s',(0:n-1)'*dt);
base_exp=ppid_noise(cfg,ref,plan);
conds=["A","B","C","D","E"]; rows={};
for cond=conds
 e=base_exp; c=cfg; setenv('ECL_HACC',''); setenv('ECL_TIME_MODE','A');
 if cond=="B"
  e.navigation.gnss_position_m=zeros(size(e.navigation.gnss_position_m));
 elseif cond=="C"
  setenv('ECL_HACC','0.5');
 elseif cond=="D"
  c.gyro_bias_deg_s=zeros(3,1);c.accelerometer_bias_m_s2=zeros(3,1);c.magnetometer_bias_gauss=zeros(3,1);c.barometer_bias_m=0;
  for fn=["gyro_rad_s","accelerometer_m_s2","gyro_walk","accel_walk"]
   e.navigation.(char(fn))=zeros(size(e.navigation.(char(fn))));
  end
 elseif cond=="E"
  stream=RandStream('mt19937ar','Seed',c.navigation_seed+2);
  total=size(e.navigation.gnss_position_m,1);
  e.navigation.gnss_position_m=c.gnss_position_std_m(:)' .* randn(stream,total,3);
 end
 [nav,bus,fusion]=ppid_estimator_init(c,model,plan,e.navigation); %#ok<NASGU>
 stderr=nav.bridge.stderr_path;
 offset=nav.estimate.position; state=ca_plant_init(model,c); physical=struct('acceleration_ned_m_s2',zeros(3,1));
 est=zeros(n,3);tru=zeros(n,3);gnss=nan(n,3);gt=nan(n,3);
 for k=1:n
  t=(k-1)*dt; state.position=[0.20*t;-0.10*t;0]; state.velocity=[0.20;-0.10;0];
  [packet,observation,nav]=ppid_sensor_step(state,physical,nav,c,true,plan);
  bus.publish('sensor_navigation',struct('packet',packet,'observation',observation),t);
  ev=shc09_navigation_module(bus,fusion,t); est(k,:)=(ev.position-offset)'; tru(k,:)=state.position';
  if observation.fresh(1), gnss(k,:)=observation.gps_position; gt(k,:)=state.position'; end
 end
 nav.bridge.close();
 save(fullfile(base,'results','audit_changeB_20261104',sprintf('ecl_round4_%s.mat',cond)),'est','tru','gnss','gt','c','stderr','cond');
 valid=~isnan(gnss(:,1)); noise=gnss(valid,1:2)-gt(valid,1:2);
 rows{end+1}=table(cond,n,std(noise(:,1)),std(noise(:,2)),mean(vecnorm(noise,2,2)), ...
   norm(est(end,1:2)-tru(end,1:2)),string(stderr),'VariableNames',{'condition','samples','gnss_std_x','gnss_std_y','gnss_mean_norm','final_xy_error','stderr'});
 fprintf('ROUND4 %s gnss_std=%s final_est=%s true=%s err=%s\n',cond,mat2str(std(noise),4),mat2str(est(end,1:2),4),mat2str(tru(end,1:2),4),mat2str(est(end,1:2)-tru(end,1:2),4));
 clear nav bus fusion
end
writetable(vertcat(rows{:}),fullfile(base,'results','audit_changeB_20261104','ecl_round4_summary.csv'));
