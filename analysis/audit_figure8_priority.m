function audit = audit_figure8_priority(input_dir,output_dir)
% 只读既有八字日志，核对优先级触发、实际PWM下发及执行器模型匹配，不运行仿真。
ca_setup();assert(isfolder(input_dir)&&~isfolder(output_dir),'输入必须存在，审计输出不得覆盖。');mkdir(output_dir);
status=readtable(fullfile(input_dir,'status.csv'),'TextType','string');
assert(height(status)==15&&all(status.status=="completed"));
windows=["whole","task","cruise","transient"];bounds=[0,52;6,50;10,46;0,6];
rows=table();models=table();events=table();independent=table();
for k=1:height(status)
    method=status.method(k);seed=status.seed(k);priority=startsWith(method,"PCA");
    d=load(fullfile(input_dir,'logs',sprintf('%s_s%d.mat',method,seed)),'L','c','model','ref');
    L=d.L;c=d.c;m=d.model;t=d.ref.time_s;
    assert(string(L.name)==method&&numel(t)==41601);
    delta_error=max(abs(rad2deg(L.estimated_delta_rad-L.actual_delta_rad)),[],'all');
    tau_error=max(abs(L.actual_tau_s-c.tau_model_s(:)'),[],'all');
    checked=L.pwm_prediction_checked;forecast=rad2deg(L.pwm_end_prediction_error_rad(checked,:));
    prediction_max=max(abs(forecast),[],'all');prediction_rms=sqrt(mean(forecast.^2,'all'));
    raw_rate=(L.held_command_rad-L.actual_delta_rad)./L.actual_tau_s;
    rate_limited=any(abs(raw_rate)>=deg2rad(c.rate_limit_deg_s)-1e-8,2);
    models=[models;table(method,seed,tau_error,delta_error,prediction_rms,prediction_max, ...
        c.actuator_tau_variation_enabled,c.tau_model_s(1),c.rate_limit_deg_s,m.command_limit_deg, ...
        'VariableNames',{'method','seed','tau_actual_minus_model_max_s','actuator_estimate_error_max_deg', ...
        'pwm_prediction_rms_deg','pwm_prediction_max_deg','actuator_tau_variation_enabled','tau_model_s', ...
        'rate_limit_deg_s','command_limit_deg'})];
    actual_vane=zeros(numel(t),3);
    for axis=1:3
        actual_vane(:,axis)=sum(squeeze(L.actual_torque_matrix(axis,:,:))'.*L.effective_delta_rad,2);
    end
    desired_nominal_torque=(L.v_h+L.v_c)*m.parameters.J';
    instantaneous_residual=actual_vane-desired_nominal_torque;
    if priority
        scaled_indices=find(L.mode==0&isfinite(L.lambda)&L.lambda<1-1e-6);
        for i=reshape(scaled_indices,1,[])
            timing=ca_pwm_timing(t(i),c,L.allocation_held_command_rad(i,:)');
            at=ca_actuator_step(L.estimated_delta_rad(i,:)',timing.held_command,c.tau_model_s,timing.delay_s,deg2rad(c.rate_limit_deg_s));
            f=exp(-timing.hold_s./c.tau_model_s);g=1-f;
            matrix=m.acceleration_matrix*diag(g);continued=m.acceleration_matrix*(f.*at);
            lower=max(m.command_lower,at-c.tau_model_s*deg2rad(c.rate_limit_deg_s));
            upper=min(m.command_upper,at+c.tau_model_s*deg2rad(c.rate_limit_deg_s));
            options=optimoptions('linprog','Display','none');
            [~,~,full_flag]=linprog(zeros(6,1),[],[],matrix,L.v_h(i,:)'+L.v_c(i,:)'-continued,lower,upper,options);
            [solution,~,flag]=linprog([zeros(6,1);-1],[],[],[matrix,-L.v_c(i,:)'],L.v_h(i,:)'-continued,[lower;0],[upper;1],options);
            assert(flag>0&&abs(solution(end)-L.lambda(i))<1e-6,'独立LP与原始缩放系数不一致。');
            independent=[independent;table(method,seed,t(i),L.lambda(i),solution(end),full_flag, ...
                abs(solution(end)-L.lambda(i)), ...
                'VariableNames',{'method','seed','time_s','recorded_lambda','independent_max_lambda','full_demand_exitflag','lambda_difference'})];
            events=[events;table(method,seed,"control_candidate",t(i),t(i),L.lambda(i),max(abs(rad2deg(L.command_rad(i,:)))), ...
                'VariableNames',{'method','seed','event_kind','time_s','source_time_s','lambda','command_max_deg'})];
        end
        scaled_events=find(L.pwm_mode==0&isfinite(L.pwm_lambda)&L.pwm_lambda<1-1e-6);
        for i=reshape(scaled_events,1,[])
            events=[events;table(method,seed,"pwm_delivered",L.pwm_update_time_s(i),L.pwm_source_time_s(i),L.pwm_lambda(i), ...
                max(abs(rad2deg(L.pwm_command_rad(i,:)))), ...
                'VariableNames',{'method','seed','event_kind','time_s','source_time_s','lambda','command_max_deg'})];
        end
    end
    for wi=1:4
        q=t>=bounds(wi,1)&t<=bounds(wi,2);p=L.pwm_update_time_s>=bounds(wi,1)&L.pwm_update_time_s<=bounds(wi,2);
        lambda=L.lambda(q);finite=isfinite(lambda);v=lambda(finite);
        minimum=NaN;maximum=NaN;deviation=NaN;
        if ~isempty(v),minimum=min(v);maximum=max(v);deviation=max(abs(v-1));end
        scaled=L.mode(q)==0&finite&lambda<1-1e-6;
        near_one=finite&abs(lambda-1)<=1e-6;
        beta=L.beta(q);b=beta(isfinite(beta));beta_min=NaN;beta_max=NaN;
        if ~isempty(b),beta_min=min(b);beta_max=max(b);end
        mode0=NaN;mode1=NaN;mode2=NaN;scaled_count=NaN;
        if priority
            mode0=sum(L.mode(q)==0);mode1=sum(L.mode(q)==1);mode2=sum(L.mode(q)==2);scaled_count=sum(scaled);
            assert(mode0+mode1+mode2==sum(q),'未知PCA模式。');
        end
        pwm_lambda=L.pwm_lambda(p);pv=pwm_lambda(isfinite(pwm_lambda));pmin=NaN;pmax=NaN;pscaled=NaN;
        if ~isempty(pv),pmin=min(pv);pmax=max(pv);end
        if priority,pscaled=sum(L.pwm_mode(p)==0&isfinite(pwm_lambda)&pwm_lambda<1-1e-6);end
        equality=NaN;
        if priority
            native=L.command_rad;if method=="PCA_PREDICTIVE",native=L.native_predicted_delta_rad;end
            normal=q&L.mode==0&isfinite(L.lambda);
            error=native(normal,:)*m.acceleration_matrix'-L.v_h(normal,:)-L.lambda(normal).*L.v_c(normal,:);
            equality=max(abs(error),[],'all');
        end
        commanded=L.pwm_command_rad(p,:);
        saturation=100*mean(any(abs(rad2deg(commanded))>=m.command_limit_deg-1e-5,2));
        physical_rms=sqrt(mean(sum(instantaneous_residual(q,:).^2,2)));
        rows=[rows;table(method,seed,windows(wi),priority,sum(q),sum(finite),minimum,maximum,deviation, ...
            sum(near_one),scaled_count,mode0,mode1,mode2,numel(b),beta_min,beta_max,sum(p),pmin,pmax,pscaled, ...
            saturation,100*mean(rate_limited(q)),equality,physical_rms, ...
            'VariableNames',{'method','seed','window','priority_applicable','control_samples','lambda_finite_count', ...
            'lambda_min','lambda_max','lambda_max_abs_deviation_from_one','lambda_near_one_count_tol_1e6', ...
            'lambda_scaled_count_tol_1e6','mode0_count','mode1_count','mode2_count','beta_finite_count','beta_min','beta_max', ...
            'pwm_events','pwm_lambda_min','pwm_lambda_max','pwm_lambda_scaled_count_tol_1e6', ...
            'position_saturation_percent','instantaneous_rate_limited_percent','native_equality_max_error_rad_s2', ...
            'instantaneous_true_vane_torque_minus_current_nominal_demand_rms_nm'})];
    end
end
writetable(rows,fullfile(output_dir,'priority_activation.csv'));
writetable(models,fullfile(output_dir,'actuator_model_match.csv'));
writetable(events,fullfile(output_dir,'scaled_events.csv'));
writetable(independent,fullfile(output_dir,'independent_lp_checks.csv'));
audit=struct('input_dir',string(input_dir),'logs_verified',15,'fresh_simulations',0,'lambda_tolerance',1e-6, ...
    'native_vs_delivered_checked',true,'numerical_core_modified',false,'statistics_rows',height(rows), ...
    'physical_residual_role',"当前实际舵效力矩减当前名义角加速度需求经J换算；包含舵机滞后，不含被动气动力矩与外扰，不是总角加速度跟踪误差", ...
    'non_pca_lambda_role',"其他方法没有PCA缩放因子，缺失值保留NaN，不能视为1", ...
    'beta_role',"仅mode1记录高优先级缩放，未进入时为NaN，不是恒为1");
fid=fopen(fullfile(output_dir,'checks.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(audit,PrettyPrint=true));
disp(rows(rows.priority_applicable&rows.window=="whole",{'method','seed','lambda_min','lambda_max', ...
    'lambda_scaled_count_tol_1e6','mode1_count','mode2_count','pwm_lambda_scaled_count_tol_1e6'}));
fprintf('FIGURE8_PRIORITY_AUDIT_PASS 15 logs, no simulation\n');
end
