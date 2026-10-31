function report = test_estimator_lite_position()
% 二十秒M0六自由度位置保持，真实误差只用于离线验收。
[c,m,r,e]=ca_mismatch_protocol(20,0.6,"load_hold");c.estimator_mode="lite";c=ca_validate_config(c);
r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);L=ca_simulate(m,c,r,"WLS",e);
position=L.estimated_position_error_m;velocity=L.estimated_velocity_ned_m_s-L.velocity_ned_m_s;
report=struct('position_rmse_m',sqrt(mean(sum(position.^2,2))),'velocity_rmse_m_s',sqrt(mean(sum(velocity.^2,2))), ...
 'attitude_rmse_deg',rad2deg(sqrt(mean(L.estimated_attitude_error_rad.^2))),'healthy',all(L.estimator_health),'aero_extrapolated_count',L.table_extrapolated_count);
disp(report);
assert(report.position_rmse_m<0.5 && report.velocity_rmse_m_s<0.2 && report.healthy,'shc09:LitePositionConvergence','lite位置未达到门限，禁止真值补位。');
assert(~isfield(L.topic_log,'sensor_attitude') && ~isfield(L.topic_log,'sensor_local_position') && ~isfield(L.topic_log,'plant_truth'));
assert(all(isfinite([position(:);velocity(:)])) && L.table_extrapolated_count==0);
end
