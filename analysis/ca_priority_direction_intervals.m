function intervals = ca_priority_direction_intervals(results)
% 复用已保存的射线上界，只对预测PCA补充最小可行系数的独立求解。
label='PCA_PREDICTIVE';
assert(isfield(results.logs,label),'预测PCA本次运行没有完整日志。');
log=results.logs.(label); cfg=results.config; model=results.model; t=results.reference.time_s;
d=results.diagnostics.(label); d=d(string(d.reachable_set)=="affine_dynamic",:);
C=model.torque_matrix; capacity=sum(abs(C).*model.command_upper',2); A=C./capacity;
options=optimoptions('linprog','Display','none'); rows={};
for k=1:height(d)
    index=round(d.time_s(k)*cfg.sample_hz)+1;
    assert(abs(t(index)-d.time_s(k))<1e-9,'诊断与控制时钟不一致。');
    held=log.allocation_held_command_rad(index,:)';
    timing=ca_pwm_timing(t(index),cfg,held);
    at=ca_actuator_step(log.estimated_delta_rad(index,:)',held,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
    f=exp(-timing.hold_s./cfg.tau_model_s); g=1-f;
    lo=f.*at+g.*max(model.command_lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    hi=f.*at+g.*min(model.command_upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    vh=(model.inertia*log.v_h(index,:)')./capacity; vc=(model.inertia*log.v_c(index,:)')./capacity;
    [solution,~,flag]=linprog([zeros(6,1);1],[],[],[A,-vc],vh,[lo;0],[hi;1],options);
    minimum=NaN; if flag>0, minimum=solution(7); end
    rows(end+1,:)={t(index),flag,d.ray_exitflag(k),minimum,d.max_tracking_fraction(k), ...
        log.mode(index),log.lambda(index)}; %#ok<AGROW>
end
intervals=cell2table(rows,'VariableNames',{'time_s','minimum_exitflag','maximum_exitflag','minimum_fraction', ...
    'maximum_fraction','native_mode','native_lambda'});
normal=intervals.native_mode==0 & intervals.maximum_exitflag>0;
assert(all(intervals.minimum_exitflag(normal)>0),'上下界求解状态不一致。');
assert(max(abs(intervals.native_lambda(normal)-intervals.maximum_fraction(normal)))<1e-5, ...
    '预测PCA与独立最大跟踪比例不一致。');
assert(all(intervals.minimum_fraction(normal)<=intervals.native_lambda(normal)+1e-6),'预测PCA超出可行系数区间。');
end
