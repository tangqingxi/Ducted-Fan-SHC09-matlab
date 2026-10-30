function torque = ca_disturbance_torque(time_s,cfg)
% 保留原常值扰动，另按ws-gnc式(24)在指定时刻接入偏置加正弦扰动。
torque=cfg.disturbance_torque_nm(:);
if ~isempty(cfg.disturbance_stages_nm)
    torque=torque+ca_stage_reference(time_s,cfg.disturbance_stages_nm,cfg.disturbance_transition_s,zeros(3,1))';
end
ending=Inf;
kind="sin";
if isfield(cfg,'disturbance_end_s'), ending=cfg.disturbance_end_s; end
if isfield(cfg,'disturbance_type'), kind=string(cfg.disturbance_type); end
if time_s>=cfg.disturbance_start_s && time_s<=ending
    elapsed=time_s-cfg.disturbance_start_s;
    switch kind
        case "sin"
            extra=cfg.disturbance_amplitude_nm(:).*sin(2*pi*cfg.disturbance_frequency_hz(:)*elapsed);
        case "constant"
            extra=cfg.disturbance_amplitude_nm(:);
        case "random"
            assert(isfield(cfg,'disturbance_series'),'随机扰动须先调用ca_prepare_experiment。');
            series=cfg.disturbance_series;
            assert(~isempty(series.time_s),'随机力矩序列未生成。');
            dt=series.time_s(2)-series.time_s(1);
            tick=max(1,min(floor(time_s/dt)+1,numel(series.time_s)-1));
            weight=min(1,max(0,(time_s-series.time_s(tick))/dt));
            extra=((1-weight)*series.torque_nm(tick,:)+weight*series.torque_nm(tick+1,:))';
        otherwise
            error('未知扰动类型。');
    end
    torque=torque+cfg.disturbance_bias_nm(:)+extra;
end
end
