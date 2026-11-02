function m=hdf_metrics(L,ref,plan,seed)
% 正式深度饱和批只补充报告指标，不把旧预检门槛作为正式验收门槛。
m=hd_metrics(L,ref,plan,seed);
m=rmfield(m,{'lambda_target_passed','precheck_passed'});
t=L.time_s;q=t>=10&t<22;qc=q&L.control_updated;
normal=qc&L.mode==0&isfinite(L.lambda);indices=find(normal);
m.normal_lambda_min_time_s=NaN;
if ~isempty(indices),[~,k]=min(L.lambda(indices));m.normal_lambda_min_time_s=t(indices(k));end
m.high_priority_fallback_duration_s=m.mode1_duration_s;
m.engineering_fallback_duration_s=m.mode2_duration_s;
m.all_fallback_duration_s=m.mode1_duration_s+m.mode2_duration_s;
m.lambda_applicable=startsWith(string(L.name),'PCA');
m.whole_normal_lambda_min=NaN;m.whole_normal_lambda_min_time_s=NaN;
indices=find(L.control_updated&L.mode==0&isfinite(L.lambda));
if ~isempty(indices)
    [m.whole_normal_lambda_min,k]=min(L.lambda(indices));m.whole_normal_lambda_min_time_s=t(indices(k));
end
steps=rad2deg(diff(L.pwm_command));pwm=L.pwm_time(2:end)>=10&L.pwm_time(2:end)<22;
m.pwm_step_total_deg=sum(abs(steps(pwm,:)),'all');m.pwm_nonzero_step_events=sum(any(abs(steps(pwm,:))>1e-9,2));
m.no_divergence=m.finite_states&&m.completed_40s&&max(vecnorm(L.omega,2,2))<100;
m.true_velocity_peak_m_s=max(vecnorm(L.velocity,2,2));
% 真值恢复与估计恢复使用同一判据，但不对真值作平移或对齐。
ix=find(t>=22&t<32);d=L.position-ref.position_ned_m;distance=vecnorm(d(:,1:2),2,2);
roll=rad2deg(L.euler(:,1));speed=vecnorm(L.velocity(:,1:2),2,2);r=plan.hover_distance.recovery;
settled=distance(ix)<=r.position_radius_m&speed(ix)<=r.speed_radius_m_s&abs(roll(ix))<=r.roll_radius_deg;
edges=diff([false;settled;false]);starts=find(edges==1);lengths=find(edges==-1)-starts;k=find(lengths>=r.hold_s*800,1);
m.true_recovery_entry_s=NaN;m.true_recovery_confirmed_s=NaN;m.true_recovery_not_reached=isempty(k);
if ~isempty(k),m.true_recovery_entry_s=t(ix(starts(k)))-22;m.true_recovery_confirmed_s=m.true_recovery_entry_s+r.hold_s;end
m.true_recovery_horizontal_peak_m=max(distance(ix));m.true_recovery_roll_peak_deg=max(abs(roll(ix)));
initial=d(ix(1),1:2);m.true_recovery_opposite_position_overshoot_m=NaN;
if norm(initial)>1e-6,m.true_recovery_opposite_position_overshoot_m=max(0,-min(d(ix,1:2)*initial'/norm(initial)));end
m.true_recovery_opposite_roll_overshoot_deg=max(0,-min(sign(roll(ix(1)))*roll(ix)));
end
