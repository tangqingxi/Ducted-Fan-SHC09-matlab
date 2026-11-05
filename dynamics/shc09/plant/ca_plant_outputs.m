function out = ca_plant_outputs(state,model,cfg,time_s)
% 真实物理输出供积分器及传感器使用，不作为分配器额外输入。
% 对外状态/力矩/角加速度均为真实 b 系；气动内核仍按旧原生系方程计算，
% 在此处用 R=diag([-1,-1,1]) 做严格的旧原生系<->b 系边界转换。
if isfield(model,'parameters')
    p=model.parameters;
else
    p=struct('R_old_to_b',diag([-1,-1,1]),'m',model.mass_kg,'g',9.8);
end
R=p.R_old_to_b;
disturbance_b=R*ca_disturbance_torque(time_s,cfg);
if model.plant_model=="hover_linear"
    out.force_body_n=zeros(3,1); out.torque_body_nm=model.torque_matrix*state.delta;
    out.acceleration_ned_m_s2=zeros(3,1); out.exit_speed_m_s=NaN;
    out.actual_torque_matrix=model.torque_matrix;
    out.effective_delta_rad=state.delta;
    out.vane_incremental_gain=ones(6,1);
    out.airspeed_body_m_s=zeros(3,1); out.table_extrapolated=false;
    out.low_speed_regularized=false;
    out.duct_angle_rad=NaN; out.wing_angle_rad=NaN;
else
    old=state;
    old.rotation=state.rotation*R;
    % state.velocity 是 NED 导航速度，不是机体系速度，不能乘 R'。
    old.velocity=state.velocity;
    old.omega=R'*state.omega;
    try
        aero=ca_shc09_aerodynamics(old.rotation,old.velocity,old.omega,old.delta,old.motor,model,cfg);
    catch problem
        if strcmp(problem.identifier,'ca:AeroTableDomain')
            detailed=MException('ca:AeroTableDomain', ...
                '物理时刻%.9f秒，空速=%.17g米每秒，速度NED=[%.6g %.6g %.6g]m/s：%s', ...
                time_s,norm(state.velocity-cfg.wind_ned_m_s(:)), ...
                state.velocity(1),state.velocity(2),state.velocity(3),problem.message);
            throwAsCaller(addCause(detailed,problem));
        end
        rethrow(problem);
    end
    out.force_body_n=R*aero.force_body_n;
    out.torque_body_nm=R*aero.torque_body_nm;
    out.acceleration_ned_m_s2=state.rotation*out.force_body_n/p.m ...
        +cfg.external_force_ned_n(:)/p.m+[0;0;p.g];
    out.exit_speed_m_s=aero.exit_speed_m_s;
    out.actual_torque_matrix=R*aero.actual_torque_matrix;
    out.effective_delta_rad=aero.effective_delta_rad;
    out.vane_incremental_gain=aero.vane_incremental_gain;
    out.airspeed_body_m_s=R*aero.airspeed_body_m_s;
    out.table_extrapolated=aero.table_extrapolated;
    out.low_speed_regularized=aero.low_speed_regularized;
    out.duct_angle_rad=aero.duct_angle_rad;
    out.wing_angle_rad=aero.wing_angle_rad;
end
out.disturbance_torque_nm=disturbance_b;
out.alpha_rad_s2=model.inertia\(out.torque_body_nm+disturbance_b ...
    -cross(state.omega,model.inertia*state.omega));
end
