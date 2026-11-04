base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup; addpath(fullfile(base,'research','ppid_pindi'));
[cfg,model,~,plan]=ppid_config(501); n=round(12*cfg.sample_hz); dt=1/cfg.sample_hz; ref=struct('time_s',(0:n-1)'*dt);
cfg.gnss_position_bias_m=zeros(3,1);cfg.gyro_bias_deg_s=zeros(3,1);cfg.accelerometer_bias_m_s2=zeros(3,1);cfg.magnetometer_bias_gauss=zeros(3,1);cfg.barometer_bias_m=0;
experiment=ppid_noise(cfg,ref,plan); fn=fieldnames(experiment.navigation);
for k=1:numel(fn)
 if fn{k}=="warmup_samples", continue; end
 v=experiment.navigation.(fn{k}); if isnumeric(v), experiment.navigation.(fn{k})=zeros(size(v)); end
end
[nav,bus,fusion]=ppid_estimator_init(cfg,model,plan,experiment.navigation); %#ok<NASGU>
offset=nav.estimate.position; state=ca_plant_init(model,cfg); physical=struct('acceleration_ned_m_s2',zeros(3,1)); est=zeros(n,3);tru=zeros(n,3);
for k=1:n
 t=(k-1)*dt; state.position=[0.20*t;-0.10*t;0]; state.velocity=[0.20;-0.10;0];
 [packet,observation,nav]=ppid_sensor_step(state,physical,nav,cfg,true,plan);
 bus.publish('sensor_navigation',struct('packet',packet,'observation',observation),t);
 e=shc09_navigation_module(bus,fusion,t); est(k,:)=(e.position-offset)';tru(k,:)=state.position';
end
save(fullfile(base,'results','audit_changeB_20261104','ecl_open_loop_noiseless.mat'),'est','tru');
fprintf('NOISELESS true=%s est=%s err=%s\n',mat2str(tru(end,:),4),mat2str(est(end,:),4),mat2str(est(end,:)-tru(end,:),4));
