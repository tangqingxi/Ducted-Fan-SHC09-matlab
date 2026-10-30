function audit = ca_priority_interval_audit(results,frequency_hz)
% 用最小和最大可行跟踪系数检查动态射线是否为不包含零的区间。
if nargin<2, frequency_hz=50; end
cfg=results.config; model=results.model; ref=results.reference;
C=model.torque_matrix; capacity=sum(abs(C).*model.command_upper',2); A=C./capacity;
indices=find(ref.time_s>=4 & ref.time_s<10); indices=indices(1:max(1,round(cfg.sample_hz/frequency_hz)):end);
opt=optimoptions('linprog','Display','none'); rows={};
for method=cfg.methods
    if ~isfield(results.logs,method), continue; end
    log=results.logs.(method);
    for index=indices'
        held=log.allocation_held_command_rad(index,:)';
        timing=ca_pwm_timing(ref.time_s(index),cfg,held);
        at=ca_actuator_step(log.estimated_delta_rad(index,:)',held,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
        f=exp(-timing.hold_s./cfg.tau_model_s); g=1-f;
        lo=f.*at+g.*max(model.command_lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
        hi=f.*at+g.*min(model.command_upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
        vh=(model.inertia*log.v_h(index,:)')./capacity; vc=(model.inertia*log.v_c(index,:)')./capacity;
        [minimum,~,minflag]=linprog([zeros(6,1);1],[],[],[A,-vc],vh,[lo;0],[hi;1],opt);
        [maximum,~,maxflag]=linprog([zeros(6,1);-1],[],[],[A,-vc],vh,[lo;0],[hi;1],opt);
        lmin=NaN; lmax=NaN;
        if minflag>0, lmin=minimum(7); end
        if maxflag>0, lmax=maximum(7); end
        rows(end+1,:)={char(method),ref.time_s(index),minflag,maxflag,lmin,lmax, ...
            log.mode(index),log.lambda(index)}; %#ok<AGROW>
    end
end
audit=cell2table(rows,'VariableNames',{'method','time_s','minimum_exitflag','maximum_exitflag', ...
    'minimum_tracking_fraction','maximum_tracking_fraction','native_mode','native_lambda'});
end
