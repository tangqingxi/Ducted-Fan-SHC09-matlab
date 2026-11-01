function parameters = shc09_module_params(cfg,role)
% 控制链只取得职责所需参数，不把对象真值配置当作模块接口。
switch string(role)
    case "sensors"
        names=["sample_hz","measurement_mode","gyro_transport_delay_s","filter_h1_hz","filter_h2_hz", ...
         "gyro_prefilter_enabled","gyro_prefilter_hz","gyro_notch_enabled","gyro_notch_hz","gyro_notch_bandwidth_hz"];
    case "position"
        names=["position_gain","velocity_gain","position_reference_ned_m","position_attitude_mode"];
    case "attitude"
        names="attitude_gain";
    case "rate"
        names="rate_gain";
    otherwise
        error('shc09:ModuleParameters','未知模块参数角色。');
end
parameters=struct();for name=names,parameters.(name)=cfg.(name);end
if string(role)=="position"
    % 可选F8参数不进入旧配置，也不把执行器真实时间常数交给控制链。
    for name=["f8_feedforward_enabled","f8_max_tilt_deg","f8_max_thrust_fraction"]
        if isfield(cfg,name),parameters.(name)=cfg.(name);end
    end
end
end
