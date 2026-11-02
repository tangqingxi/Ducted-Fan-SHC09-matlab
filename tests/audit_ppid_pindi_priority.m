function checks=audit_ppid_pindi_priority(folder)
% 只读正式日志；以支撑面几何及独立LP检查缩放/回退，不重跑对象或分配器。
root=ca_setup();status=readtable(fullfile(folder,'status.csv'),'TextType','string');
summary=table();maximum_equality=0;maximum_lambda=0;lp_count=0;lp_max_error=0;
out=fullfile(folder,'priority_audit');if ~isfolder(out),mkdir(out);end
for row=reshape(find(startsWith(status.method,"PCA_")),1,[])
    assert(status.status(row)=="completed");
    d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',status.method(row),status.seed(row))));L=d.L;
    k=find(L.control_updated);time=L.time_s(k);cfg=ca_allocator_config(d.cfg);cfg.sample_hz=400;B=d.model.acceleration_matrix;
    % 同时刻先分配再锁存；回溯严格早于控制时刻的PWM，避免把刚下发指令冒充历史输入。
    held=interp1(L.pwm_time,L.pwm_command,time-1e-9,'previous',NaN);held(1,:)=d.model.trim_delta_rad';
    assert(all(isfinite(held),'all'));
    shim=struct('v_h',L.v_h(k,:),'v_c',L.v_c(k,:),'estimated_delta_rad',L.estimated_delta(k,:), ...
        'allocation_held_command_rad',held);
    G=ca_priority_polytope_audit(shim,d.model,cfg,time,[6,50]);
    task=time>=6&time<=50;indices=find(task);mode=L.mode(k(task));lambda=L.lambda(k(task));
    predictive=status.method(row)=="PCA_PREDICTIVE";
    if predictive
        high=G.dynamic_high_feasible;full=G.dynamic_full_feasible;bound=G.dynamic_lambda_max;
    else
        high=G.static_high_feasible;full=G.static_full_feasible;bound=G.static_lambda_max;
    end
    normal=mode==0;scaled=normal&lambda<1-1e-6;
    assert(all(isfinite(bound(normal))));
    error=max(abs(lambda(normal)-bound(normal)),[],'omitnan');if isempty(error),error=0;end
    maximum_lambda=max(maximum_lambda,error);assert(error<1e-5);
    strict=scaled&high&~full&min(G.vh_vc_angle_deg,180-G.vh_vc_angle_deg)>=15;
    residual=zeros(numel(indices),1);optimality=zeros(numel(indices),1);
    lp_selected=[];
    groups={find(normal&~scaled),find(scaled),find(mode==1),find(mode==2)};
    for group=groups
        values=group{1};if isempty(values),continue;end
        lp_selected=[lp_selected;values(unique(round(linspace(1,numel(values),min(8,numel(values))))))]; %#ok<AGROW>
    end
    for j=1:numel(indices)
        i=indices(j);sample=k(i);timing=ca_pwm_timing(time(i),cfg,held(i,:)');
        lower=d.model.command_lower;upper=d.model.command_upper;matrix=B;continued=zeros(3,1);
        if predictive
            at=ca_actuator_step(L.estimated_delta(sample,:)',held(i,:)',cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
            f=exp(-timing.hold_s./cfg.tau_model_s);matrix=B*diag(1-f);continued=B*(f.*at);
            lower=max(lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
            upper=min(upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
        end
        command=L.command(sample,:)';effect=continued+matrix*command;vh=L.v_h(sample,:)';vc=L.v_c(sample,:)';
        assert(all(command>=lower-1e-7&command<=upper+1e-7));
        if mode(j)==0,residual(j)=norm(effect-vh-lambda(j)*vc,Inf);
        elseif mode(j)==1,residual(j)=norm(effect-lambda(j)*vh,Inf);
        else,residual(j)=NaN;end
        if ismember(j,lp_selected)
            options=optimoptions('linprog','Display','none');
            [solution,~,flag]=linprog([zeros(6,1);-1],[],[],[matrix,-vc],vh-continued,[lower;0],[upper;1],options);
            if mode(j)==0
                assert(flag>0);optimality(j)=abs(solution(end)-lambda(j));
            else
                assert(flag==-2,'回退时原正常射线并非不可达。');
                [solution,~,flag]=linprog([zeros(6,1);-1],[],[],[matrix,-vh],-continued,[lower;0],[upper;1],options);
                if mode(j)==1
                    assert(flag>0);optimality(j)=abs(solution(end)-lambda(j));
                else
                    assert(flag==-2,'工程兜底时高优先级缩放射线并非不可达。');
                    A=[matrix,-ones(3,1);-matrix,-ones(3,1)];b=[vh-continued;continued-vh];
                    [solution,~,flag]=linprog([zeros(6,1);1],A,b,[],[],[lower;0],[upper;Inf],options);
                    assert(flag>0);optimality(j)=abs(norm(effect-vh,Inf)-solution(end));
                end
            end
            lp_count=lp_count+1;lp_max_error=max(lp_max_error,optimality(j));
        end
    end
    maximum_equality=max(maximum_equality,max(residual,[],'omitnan'));assert(maximum_equality<1e-5&&lp_max_error<1e-5);
    G.mode=mode;G.recorded_lambda=lambda;G.equality_residual=residual;G.strict_noncollinear_certificate=strict;
    writetable(G,fullfile(out,sprintf('%s_s%d.csv',status.method(row),status.seed(row))));
    summary=[summary;table(status.method(row),status.seed(row),sum(task),sum(scaled)/400,sum(mode==1)/400, ...
        sum(mode==2)/400,sum(strict)/400,sum(~high)/400,min(lambda(normal)),max(residual,[],'omitnan'), ...
        'VariableNames',{'method','seed','control_samples','normal_scaled_s','high_priority_fallback_s', ...
        'emergency_fallback_s','strict_noncollinear_certificate_s','high_target_infeasible_s','normal_lambda_min','maximum_equality_error'})]; %#ok<AGROW>
end
writetable(summary,fullfile(folder,'priority_summary.csv'));
checks=struct('runs_verified',height(summary),'maximum_equality_error',maximum_equality, ...
    'maximum_lambda_geometry_error',maximum_lambda,'independent_lp_samples',lp_count,'maximum_lp_error',lp_max_error, ...
    'simulations_rerun',0,'scope','Nominal static or nominal PWM-endpoint allocation geometry only; not a stability or actual-plant robustness proof.');
fid=fopen(fullfile(folder,'priority_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));disp(checks);
end
