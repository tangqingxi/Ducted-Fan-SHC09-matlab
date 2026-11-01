function result = ca_priority_polytope_audit(L,model,cfg,time_s,window_s)
% 用三维区间映射的支撑面核对名义可达性；全程离线，不改变任何分配结果。
B=model.acceleration_matrix;normals=zeros(0,3);
for i=1:5,for j=i+1:6
    normal=cross(B(:,i),B(:,j));
    if norm(normal)>1e-10,normal=normal/norm(normal);normals=[normals;normal';-normal'];end
end,end
assert(rank(B)==3&&~isempty(normals));
selected=find(time_s>=window_s(1)&time_s<=window_s(2));count=numel(selected);
static_full=false(count,1);static_high=static_full;dynamic_full=static_full;dynamic_high=static_full;
static_min=NaN(count,1);static_max=static_min;dynamic_min=static_min;dynamic_max=static_min;
static_bound=normals*(B*((model.command_lower+model.command_upper)/2)) ...
    +abs(normals*B)*((model.command_upper-model.command_lower)/2);
for k=1:count
    i=selected(k);vh=L.v_h(i,:)';vc=L.v_c(i,:)';
    [static_high(k),static_full(k),static_min(k),static_max(k)]=interval(normals,static_bound,vh,vc);
    timing=ca_pwm_timing(time_s(i),cfg,L.allocation_held_command_rad(i,:)');
    at=ca_actuator_step(L.estimated_delta_rad(i,:)',timing.held_command,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
    f=exp(-timing.hold_s./cfg.tau_model_s);g=1-f;matrix=B*diag(g);continued=B*(f.*at);
    lower=max(model.command_lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    upper=min(model.command_upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    bound=normals*(continued+matrix*((lower+upper)/2))+abs(normals*matrix)*((upper-lower)/2);
    [dynamic_high(k),dynamic_full(k),dynamic_min(k),dynamic_max(k)]=interval(normals,bound,vh,vc);
end
cosine=sum(L.v_h(selected,:).*L.v_c(selected,:),2)./(vecnorm(L.v_h(selected,:),2,2).*vecnorm(L.v_c(selected,:),2,2));
angle=rad2deg(acos(min(1,max(-1,cosine))));
static_certificate=static_high&~static_full&static_max>1e-6&static_max<1-1e-6&angle>=15;
dynamic_certificate=dynamic_high&~dynamic_full&dynamic_max>1e-6&dynamic_max<1-1e-6&angle>=15;
result=table(time_s(selected),static_high,static_full,static_min,static_max,dynamic_high,dynamic_full,dynamic_min,dynamic_max, ...
    angle,static_certificate,dynamic_certificate, ...
    'VariableNames',{'time_s','static_high_feasible','static_full_feasible','static_lambda_min','static_lambda_max', ...
    'dynamic_high_feasible','dynamic_full_feasible','dynamic_lambda_min','dynamic_lambda_max','vh_vc_angle_deg', ...
    'static_priority_certificate','dynamic_priority_certificate'});
end

function [high,full,minimum,maximum]=interval(normals,bound,vh,vc)
% 每个支撑面把射线可行条件化为一个标量区间；动态集合可不包含射线起点。
slack=bound-normals*vh;direction=normals*vc;tolerance=1e-7;
high=all(slack>=-tolerance);full=all(slack-direction>=-tolerance);
positive=direction>1e-12;negative=direction<-1e-12;zero=~positive&~negative;
minimum=max([0;slack(negative)./direction(negative)]);maximum=min([1;slack(positive)./direction(positive)]);
if any(slack(zero)<-tolerance)||minimum>maximum+tolerance||maximum<0||minimum>1,minimum=NaN;maximum=NaN;end
end
