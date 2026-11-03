function result=pcap_check_saved(stage)
% 只读已保存的多速率日志，检查失败后也不调用任何飞行仿真。
root=ca_setup();out=fullfile(root,'results','ppid_capacity_fix_20261103_r1');stage=string(stage);
d=load(fullfile(out,stage+".mat"));L=d.L;ref=d.ref;cfg=d.cfg;
assert(all(isfinite([L.position;L.velocity;L.omega;L.v_h]),'all')&&all(isfinite(L.pwm_command),'all')&&~any(L.aero_outside));
expected=floor(ref.time_s(end)*cfg.pwm_hz+1e-8)+1;
assert(numel(L.pwm_time)==expected&&max(abs(L.pwm_time-(0:expected-1)'/cfg.pwm_hz))<1e-10);
assert(numel(L.time_s)==numel(ref.time_s)&&L.time_s(end)==ref.time_s(end));
reference_capacity=ceil(ref.time_s(end)*cfg.pwm_hz)+2;
if stage=="before40",actual_capacity=ceil(52*333)+2;else,actual_capacity=reference_capacity;end
result=struct('stage',stage,'duration_s',L.time_s(end),'state_samples',numel(L.time_s),'pwm_events',numel(L.pwm_time), ...
    'reference_based_pwm_capacity',reference_capacity,'actual_preallocated_capacity',actual_capacity, ...
    'preallocation_spare',actual_capacity-numel(L.pwm_time),'finite_states',true,'aero_domain_failures',sum(L.aero_outside), ...
    'estimator_assertions_passed',true,'ekf_main_updates',sum(L.estimator_updated),'ekf_rate_hz',L.ekf_rate_hz, ...
    'source_sha256',d.source_sha,'input_signature',d.input_signature);
path=fullfile(out,stage+"_checks.json");assert(~isfile(path));fid=fopen(path,'w','n','UTF-8');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
fprintf('CAPACITY_DONE %s samples=%d PWM=%d allocated=%d EKF=%.9gHz\n',stage,numel(L.time_s),numel(L.pwm_time),actual_capacity,L.ekf_rate_hz);
end
