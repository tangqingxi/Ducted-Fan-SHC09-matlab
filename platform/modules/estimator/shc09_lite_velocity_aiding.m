function [s,correction,active] = shc09_lite_velocity_aiding(s,p,u,gps,time_s,dt)
% 用带时间戳的GNSS速度约束倾角漂移，不把运动比力直接当作重力。
% 历史、创新和修正均来自估计状态与原始测量，不接收物理真值或真实偏置。
if ~isfield(s,'velocity_aiding')
    capacity=ceil(p.lite_velocity_aiding_history_s*p.sample_hz)+2;
    s.velocity_aiding=struct('time',NaN(capacity,1),'velocity',zeros(capacity,3), ...
        'cursor',0,'count',0,'residual',zeros(3,1),'filtered_residual',zeros(3,1), ...
        'last_update',-Inf,'source_time',-Inf,'fusion_innovation',zeros(3,1));
end
a=s.velocity_aiding;
if dt>0&&isfield(s,'position_initialized')&&s.position_initialized
    % 保存上次发布时刻的估计；包含待注入量，避免重复计算已经承诺的互补修正。
    velocity=s.velocity;
    if isfield(s,'gnss_velocity_correction'),velocity=velocity+s.gnss_velocity_correction;end
    a.cursor=mod(a.cursor,numel(a.time))+1;a.count=min(a.count+1,numel(a.time));
    a.time(a.cursor)=time_s-dt;a.velocity(a.cursor,:)=velocity';
end
if gps.fresh&&isfield(gps,'velocity')&&all(isfinite(gps.velocity))&&gps.source_time_s<=time_s+1e-9&&a.count>0
    [distance,index]=min(abs(a.time(1:a.count)-gps.source_time_s));
    if distance<=max(2*dt,1e-6)
        a.residual=a.velocity(index,:)'-gps.velocity(:);
        a.fusion_innovation=-a.residual;a.last_update=time_s;a.source_time=gps.source_time_s;
    end
end
active=time_s-a.last_update<=p.lite_velocity_aiding_hold_s;
correction=zeros(3,1);
if active&&dt>0
    fraction=-expm1(-dt/p.lite_velocity_aiding_tau_s);
    a.filtered_residual=a.filtered_residual+fraction*(a.residual-a.filtered_residual);
    correction=p.lite_velocity_aiding_gain_s2*cross(s.rotation'*a.filtered_residual,u.accel(:))/p.lite_gravity_m_s2^2;
    limit=deg2rad(p.lite_velocity_aiding_max_rate_deg_s);
    if norm(correction)>limit,correction=correction*(limit/norm(correction));end
end
s.velocity_aiding=a;
end
