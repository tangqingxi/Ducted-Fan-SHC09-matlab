function report = test_b_frame_dynamics_equivalence()
% 同物理状态：新 b 系输出 vs 旧原生系输出的 R 变换。
% 分开报告“纯坐标变换”与“旧 J 轴序错误”两种差异。
root=ca_setup();
cfg=ca_validate_config(ca_config());
model=ca_model(cfg); p=model.parameters; R=p.R_old_to_b;
state=ca_plant_init(model);
state.rotation=ca_euler_rotation([0.04;-0.03;0.02]);
state.velocity=[1.1;2.0;0.4];
state.omega=[0.12;-0.18;0.09];
state.delta=deg2rad([6;-4;3;-2;5;1]);
state.motor=660;
trial=cfg; trial.wind_ned_m_s=[0.4;-0.3;0.1]; trial.external_force_ned_n=[0.1;0.2;-0.2];
trial.disturbance_torque_nm=[0.003;-0.002;0.001];
out_new=ca_plant_outputs(state,model,trial,0.7);
old=state; old.rotation=state.rotation*R; old.velocity=state.velocity; old.omega=R'*state.omega;
aero=ca_shc09_aerodynamics(old.rotation,old.velocity,old.omega,old.delta,old.motor,model,trial);
dist_old=ca_disturbance_torque(0.7,trial);
J_code=diag([0.0438,0.0436,0.005006]); % 旧代码实际使用的轴序
J_correct=R'*p.J_b*R;                     % 与 b 系一致的旧原生系惯量
alpha_old_code=J_code\(aero.torque_body_nm+dist_old-cross(old.omega,J_code*old.omega));
alpha_old_correct=J_correct\(aero.torque_body_nm+dist_old-cross(old.omega,J_correct*old.omega));
err_code=norm(out_new.alpha_rad_s2-R*alpha_old_code,Inf);
err_correct=norm(out_new.alpha_rad_s2-R*alpha_old_correct,Inf);
report=struct('alpha_new',out_new.alpha_rad_s2,'alpha_old_code_frames',R*alpha_old_code, ...
    'alpha_old_correct_frames',R*alpha_old_correct,'error_old_code_J',err_code, ...
    'error_correct_J',err_correct,'J_code',J_code,'J_correct_old',J_correct);
assert(err_correct<1e-10,'坐标转换后动力学不一致（正确 J 下应一致）。');
assert(err_code>1e-5,'旧 J 轴序差异没有体现在动力学中，检查测试是否失效。');
fprintf('动力学坐标等效通过；旧 J 轴序造成的差异=%.6g rad/s^2（不是坐标变换误差）。\n',err_code);
disp(report);
outdir=fullfile(root,'results','validation'); if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir,'shc09_b_frame_dynamics.mat'),'report');
end
