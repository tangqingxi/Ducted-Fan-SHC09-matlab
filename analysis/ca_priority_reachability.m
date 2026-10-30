function diagnostics = ca_priority_reachability(log,ref,model,cfg,frequency_hz,window)
% 离线用独立线性规划检查可达性，不改变控制循环和求解时长。
stride=max(1,round(cfg.sample_hz/frequency_hz));
indices=find(ref.time_s>=window(1) & ref.time_s<window(2)); indices=indices(1:stride:end);
C=model.torque_matrix;
capacity=sum(abs(C).*model.command_upper',2);
A=C./capacity; J=model.inertia;
options=optimoptions('linprog','Display','none'); rows={};
for index=indices'
    time_s=ref.time_s(index);
    delta=log.estimated_delta_rad(index,:)';
    held=log.allocation_held_command_rad(index,:)';
    timing=ca_pwm_timing(time_s,cfg,held);
    at=ca_actuator_step(delta,held,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
    vh=(J*log.v_h(index,:)')./capacity;
    vc=(J*log.v_c(index,:)')./capacity;
    full_lo=ca_actuator_step(at,model.command_lower,cfg.tau_model_s,timing.hold_s,deg2rad(cfg.rate_limit_deg_s));
    full_hi=ca_actuator_step(at,model.command_upper,cfg.tau_model_s,timing.hold_s,deg2rad(cfg.rate_limit_deg_s));
    f=exp(-timing.hold_s./cfg.tau_model_s); g=1-f;
    command_lo=max(model.command_lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    command_hi=min(model.command_upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    affine_lo=f.*at+g.*command_lo; affine_hi=f.*at+g.*command_hi;
    sets={"static",model.command_lower,model.command_upper; ...
        "full_dynamic",full_lo,full_hi;"affine_dynamic",affine_lo,affine_hi};
    product=norm(vh)*norm(vc);
    angle=NaN;
    if product>1e-12, angle=acosd(min(1,max(-1,vh'*vc/product))); end
    effect=A*log.common_predicted_delta_rad(index,:)';
    if norm(vc)>1e-12, ratio=min(1,max(0,vc'*(effect-vh)/(vc'*vc))); else, ratio=0; end
    distance=norm(effect-vh-ratio*vc);
    for k=1:3
        lo=sets{k,2}; hi=sets{k,3};
        [~,~,comp]=linprog(zeros(6,1),[],[],A,vh,lo,hi,options);
        [~,~,total]=linprog(zeros(6,1),[],[],A,vh+vc,lo,hi,options);
        [solution,~,ray]=linprog([zeros(6,1);-1],[],[],[A,-vc],vh,[lo;0],[hi;1],options);
        lambda=NaN; if ray>0, lambda=solution(7); end
        rows(end+1,:)={time_s,char(sets{k,1}),comp,total,ray,lambda,angle,distance, ...
            log.mode(index),log.lambda(index)}; %#ok<AGROW>
    end
end
diagnostics=cell2table(rows,'VariableNames',{'time_s','reachable_set','compensation_exitflag','total_exitflag', ...
    'ray_exitflag','max_tracking_fraction','normalized_torque_angle_deg','normalized_priority_distance', ...
    'native_mode','native_lambda'});
end
