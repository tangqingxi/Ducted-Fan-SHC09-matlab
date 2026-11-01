function report=f8_allocation_diagnostics(folder)
% 离线比较真实舵效与名义需求，并用独立线性规划抽查PCA；不进入控制链。
ca_setup();P=readtable(fullfile(folder,'status.csv'),'TextType','string');assert(height(P)==15&&all(P.status=="completed"));
diagnostics=table();lp=table();activation=table();
for index=1:height(P)
    method=P.method(index);seed=P.seed(index);d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)));
    L=d.L;m=d.m;c=d.c;t=d.ref.time_s;n=numel(t);actual_torque=zeros(n,3);
    for axis=1:3,for channel=1:6
        actual_torque(:,axis)=actual_torque(:,axis)+reshape(L.actual_torque_matrix(axis,channel,:),[],1).*L.effective_delta_rad(:,channel);
    end,end
    requested=(L.v_h+L.v_c)*m.inertia';nominal=L.actual_delta_rad*m.torque_matrix';
    bounds=[0,52;6,50;10,46;0,6];windows=["whole","task","cruise","initial_hover"];
    for wi=1:4
        q=t>=bounds(wi,1)&t<=bounds(wi,2);pwm=L.pwm_update_time_s>=bounds(wi,1)&L.pwm_update_time_s<=bounds(wi,2);
        forecast=pwm&L.pwm_prediction_checked;
        instantaneous=sqrt(mean(sum((actual_torque(q,:)-requested(q,:)).^2,2)));
        physical_difference=sqrt(mean(sum((actual_torque(q,:)-nominal(q,:)).^2,2)));
        prediction=sqrt(mean(rad2deg(L.pwm_end_prediction_error_rad(forecast,:)).^2,'all','omitnan'));
        activities=diff(rad2deg(L.pwm_command_rad(pwm,:)));activity=sqrt(mean(activities.^2,'all'));
        nominal_forecast=L.common_predicted_delta_rad(q,:)*m.torque_matrix'-requested(q,:);
        nominal_forecast_rms=sqrt(mean(sum(nominal_forecast.^2,2)));
        actual_changes=diff(rad2deg(L.actual_delta_rad(q,:)));actual_rate_rms=sqrt(mean((actual_changes*c.sample_hz).^2,'all'));
        actual_total_variation=sum(abs(actual_changes),'all');
        diagnostics=[diagnostics;table(method,seed,windows(wi),instantaneous,physical_difference,prediction,activity,nominal_forecast_rms,actual_rate_rms,actual_total_variation, ...
            max(rad2deg(L.rotation_error_rad(q))),sqrt(mean(L.estimated_position_error_m(q,:).^2,'all')), ...
            'VariableNames',{'method','seed','window','actual_instantaneous_vane_demand_residual_rms_nm', ...
            'actual_nominal_vane_torque_difference_rms_nm','actual_pwm_forecast_rmse_deg','pwm_command_step_rms_deg', ...
            'nominal_pwm_forecast_demand_residual_rms_nm','actual_servo_rate_rmse_deg_s','actual_servo_total_variation_deg', ...
            'inner_attitude_peak_deg','estimated_position_component_rmse_m'})];
    end
    if startsWith(method,"PCA")
        q=find(t>=6&t<=50&L.mode==0&isfinite(L.lambda));assert(~isempty(q));
        [~,a]=min(L.lambda(q));[~,b]=max(vecnorm(L.v_h(q,:)+L.v_c(q,:),2,2));
        demand_change=[zeros(1,3);diff(L.v_h+L.v_c)];[~,e]=max(vecnorm(demand_change(q,:),2,2));
        samples=unique([q(1);q(a);q(b);q(e)]);options=optimoptions('linprog','Display','none','Algorithm','dual-simplex-highs');
        for i=reshape(samples,1,[])
            B=m.acceleration_matrix;continued=zeros(3,1);lower=m.command_lower;upper=m.command_upper;
            if method=="PCA_PREDICTIVE"
                timing=ca_pwm_timing(t(i),c,L.allocation_held_command_rad(i,:)');
                at=ca_actuator_step(L.estimated_delta_rad(i,:)',timing.held_command,c.tau_model_s,timing.delay_s,deg2rad(c.rate_limit_deg_s));
                f=exp(-timing.hold_s./c.tau_model_s);B=B*diag(1-f);continued=m.acceleration_matrix*(f.*at);
                lower=max(lower,at-c.tau_model_s*deg2rad(c.rate_limit_deg_s));upper=min(upper,at+c.tau_model_s*deg2rad(c.rate_limit_deg_s));
            end
            vh=L.v_h(i,:)';vc=L.v_c(i,:)';
            [solution,~,flag]=linprog([zeros(6,1);-1],[],[],[B,-vc],vh-continued,[lower;0],[upper;1],options);
            assert(flag>0&&numel(solution)==7,'独立LP不能复现PCA的正常模式快照。');
            discrepancy=abs(solution(7)-L.lambda(i));assert(discrepancy<1e-6);
            lp=[lp;table(method,seed,t(i),L.lambda(i),solution(7),discrepancy,flag, ...
                'VariableNames',{'method','seed','time_s','native_lambda','independent_lp_lambda','absolute_error','linprog_exitflag'})];
        end
    end
    clear d L
end
writetable(diagnostics,fullfile(folder,'allocation_truth_diagnostics.csv'));writetable(lp,fullfile(folder,'independent_priority_lp.csv'));
report=struct('formal_logs_read',15,'diagnostic_windows_per_log',4,'independent_lp_snapshots',height(lp), ...
    'maximum_lp_lambda_error',max(lp.absolute_error),'physical_torque_is_offline_truth_only',true, ...
    'instantaneous_residual_is_not_pwm_endpoint_equality',true);
fid=fopen(fullfile(folder,'allocation_diagnostics_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fprintf('F8_ALLOCATION_DIAGNOSTICS_PASS 15 logs, %d LP snapshots\n',height(lp));
end
