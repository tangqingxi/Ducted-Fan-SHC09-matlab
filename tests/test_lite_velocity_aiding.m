function report = test_lite_velocity_aiding()
% 水平运动比力接近重力模长，验证新路径不把这种加速度解释成倾角。
ca_setup();c=ca_validate_config(ca_config());c.duration_s=12;c.estimator_mode="lite";
c.feedback_noise_enabled=false;warm=round(c.navigation_warmup_s*c.sample_hz);n=warm+round(c.duration_s*c.sample_hz)+1;
noise=shc09_lite_random(c,n);legacy=shc09_lite_params(c);c.lite_velocity_aiding_enabled=true;p=shc09_lite_params(c);
buses={Shc09Bus(),Shc09Bus()};states={[],[]};memory=[];errors=zeros(n-warm,2);velocity_error=zeros(n-warm,2);
for k=1:n
    t=(k-warm-1)/c.sample_hz;u=max(0,t);w=0.8;A=0.8;
    a=[A*sin(w*u);0;0];v=[A/w*(1-cos(w*u));0;0];position=[A/w*u-A/w^2*sin(w*u);0;0];
    x=struct('rotation',eye(3),'omega',zeros(3,1),'position',position,'velocity',v);
    [q,memory]=shc09_lite_sensors(x,struct('acceleration_ned_m_s2',a),c,noise,k,memory);
    for j=1:2
        shc09_lite_publish(buses{j},q,t);parameters=legacy;if j==2,parameters=p;end
        states{j}=shc09_estimator_lite_module(buses{j},states{j},parameters,t);
        if k>warm
            s=states{j};errors(k-warm,j)=rad2deg(acos(min(1,max(-1,(trace(s.rotation)-1)/2))));
            velocity_error(k-warm,j)=norm(s.velocity-v);
        end
    end
end
q=(0:size(errors,1)-1)'/c.sample_hz>=2;
old=sqrt(mean(errors(q,1).^2));new=sqrt(mean(errors(q,2).^2));
assert(new<1.5&&new<0.65*old,'速度辅助没有降低侧向加速度引起的错误倾角。');
assert(sqrt(mean(velocity_error(q,2).^2))<sqrt(mean(velocity_error(q,1).^2)));
assert(states{2}.velocity_aiding.count<=ceil(p.lite_velocity_aiding_history_s*p.sample_hz)+2);
for j=1:2,assert(~buses{j}.exists('plant_truth')&&~buses{j}.exists('sensor_attitude')&&~buses{j}.exists('sensor_local_position'));end
changed=c;changed.gyro_bias_deg_s=[10;20;30];changed.accelerometer_bias_m_s2=[1;2;3];
changed.gnss_position_bias_m=[9;8;7];assert(isequaln(p,shc09_lite_params(changed)),'真实传感器偏置进入估计器参数。');
report=struct('legacy_attitude_rmse_deg',old,'aided_attitude_rmse_deg',new,'truth_topics_absent',true,'history_bounded',true);
disp(report);fprintf('LITE_VELOCITY_AIDING_SYNTHETIC_PASS\n');
end
