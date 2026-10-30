function report = test_position_attitude_yaw()
% 同时检验期望偏航、推力方向、电机指令和旋转正交性。
root=ca_setup(); cfg=ca_config(); model=ca_model(cfg);
old=cfg; old.position_attitude_mode="legacy_projection";
new=cfg; new.position_attitude_mode="exact_yaw";
errors=[];
for yaw=deg2rad([-170,-60,0,75,165])
    for north=[-2,0,2]
        for east=[-2,0,2]
            goal=[north;east;-0.3]; velocity=[0.1;-0.2;0.05];
            [before,motor_before]=ca_position_control(zeros(3,1),velocity,yaw,model,old,goal);
            [after,motor_after]=ca_position_control(zeros(3,1),velocity,yaw,model,new,goal);
            angles=ca_rotation_euler(after);
            e=atan2(sin(angles(3)-yaw),cos(angles(3)-yaw));
            legacy=ca_rotation_euler(before);
            legacy_error=atan2(sin(legacy(3)-yaw),cos(legacy(3)-yaw));
            assert(abs(e)<1e-12,'期望偏航角不精确。');
            assert(norm(after(:,3)-before(:,3))<1e-12 && abs(motor_before-motor_after)<1e-12,'偏航修复改变了推力向量或电机指令。');
            assert(norm(after'*after-eye(3),'fro')<1e-12 && abs(det(after)-1)<1e-12,'期望姿态不属于旋转群。');
            errors(end+1,:)=[e,legacy_error]; %#ok<AGROW>
        end
    end
end
% 单轴水平机动的零偏航构造应与已有实现一致。
for east=[-2,2]
    a=ca_position_control(zeros(3,1),zeros(3,1),0,model,old,[0;east;0]);
    b=ca_position_control(zeros(3,1),zeros(3,1),0,model,new,[0;east;0]);
    assert(norm(a-b,'fro')<1e-12,'单轴零偏航构造发生变化。');
end
report=struct('cases',size(errors,1),'max_exact_yaw_error_deg',max(abs(rad2deg(errors(:,1)))), ...
    'max_legacy_yaw_error_deg',max(abs(rad2deg(errors(:,2)))));
save(fullfile(root,'results','validation','position_attitude_yaw_fix.mat'),'report');
disp(report); fprintf('公共位置姿态的偏航、推力、正交性和单轴兼容检查通过。\n');
end
