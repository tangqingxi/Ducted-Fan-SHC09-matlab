function checks=hd_check_log(L,ref,plan)
% 新工况日志契约：全时长、多速率、控制公式、执行器界和真值隔离。
assert(numel(L.time_s)==32001&&L.time_s(end)==40&&isequal(L.time_s,ref.time_s));
assert(isequal(find(L.control_updated),(1:2:32001)'));
assert(L.update_counts.position_updates==1001&&L.update_counts.velocity_updates==2001 ...
    &&L.update_counts.attitude_updates==4001&&L.update_counts.rate_updates==16001);
assert(sum(L.estimator_updated)==4001&&sum(L.gnss_fresh)==200);
assert(numel(L.pwm_time)==13321&&max(abs(L.pwm_time-(0:13320)'/333))<1e-10);
assert(~L.truth_feedback&&~any(ismember(string(L.control_interface_fields),["state","truth","actual_delta","tau_actual_s"])));
q=L.control_updated;expected=L.gamma_ff(q,:)+(L.omega_sp(q,:)-L.measured_omega(q,:)).*plan.controller.rate_gain(:)';
error=max(abs(L.v_c(q,:)-expected),[],'all');assert(error<1e-10);
assert(max(abs(L.gamma_sp(q,:)-L.v_c(q,:)),[],'all')<1e-10);
assert(max(abs(rad2deg(L.command)),[],'all')<=40+1e-7&&max(abs(rad2deg(L.actual_delta)),[],'all')<=40+1e-7);
assert(max(abs(rad2deg(diff(L.actual_delta))*800),[],'all')<=600+1e-6);
assert(max(abs(L.raw_navigation_position-L.estimated_position-L.navigation_origin_offset'),[],'all')<1e-10);
checks=struct('score_samples',32001,'rate_samples',16001,'pwm_events',13321, ...
    'maximum_control_formula_error',error,'truth_interface_checked',true,'simulations_rerun',0);
end
