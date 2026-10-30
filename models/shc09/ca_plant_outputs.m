function out = ca_plant_outputs(state,model,cfg,time_s)
% 真实物理输出供积分器及传感器使用，不作为分配器额外输入。
disturbance=ca_disturbance_torque(time_s,cfg);
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
    try
        out=ca_shc09_aerodynamics(state.rotation,state.velocity,state.omega,state.delta,state.motor,model,cfg);
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
    p=model.parameters;
    out.acceleration_ned_m_s2=state.rotation*out.force_body_n/p.m ...
        +cfg.external_force_ned_n(:)/p.m+[0;0;p.g];
end
out.disturbance_torque_nm=disturbance;
out.alpha_rad_s2=model.inertia\(out.torque_body_nm+disturbance-cross(state.omega,model.inertia*state.omega));
end
