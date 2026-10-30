function results = run_physical_model_check(output_tag)
% 同一噪声与随机力矩条件下检查六自由度姿态跟踪和带风位置保持。
ca_setup();
if nargin<1, output_tag=char(datetime('now','Format','yyyyMMdd_HHmmss')); end
results.physics=test_shc09_physics();
settings=struct('duration_s',6,'save_figures',true,'show_figures',usejava('desktop'), ...
    'disturbance_type',"random",'random_moment_rms_nm',[0.05;0.05;0.005], ...
    'disturbance_start_s',1,'envelope_ramp_s',1,'plant_model',"shc09_6dof");
settings.output_tag=['shc09_audit_attitude_',output_tag];
results.attitude=main_comparison(settings);
settings.flight_mode="position_hold"; settings.wind_ned_m_s=[1;-0.5;0];
settings.aero_extrapolation_policy="error";
settings.output_tag=['shc09_audit_position_',output_tag];
results.position=main_comparison(settings);
end
