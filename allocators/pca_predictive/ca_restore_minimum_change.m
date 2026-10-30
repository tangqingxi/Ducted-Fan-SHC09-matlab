function [command,info] = ca_restore_minimum_change(matrix,candidate,held,lower,upper)
% 借鉴Härkegård的历史输入次级目标，保持本次预测效果并最小化相对已保持命令的变化。
% 本次仅使用命令变化目标，不混入新的稳态偏好，便于单因素对比。
persistent options backup_options
if isempty(options)
    % 第一阶段候选已可行，活动集从该点出发，避免边界退化时内点法迭代停滞。
    options=optimoptions('lsqlin','Algorithm','active-set','Display','none', ...
        'OptimalityTolerance',1e-9,'ConstraintTolerance',1e-10,'MaxIterations',200);
    backup_options=optimoptions('lsqlin','Algorithm','interior-point','Display','none', ...
        'OptimalityTolerance',1e-9,'ConstraintTolerance',1e-10,'MaxIterations',500);
end
scale=vecnorm(matrix,2,2);
assert(all(scale>0),'预测效能矩阵含零行，无法归一化。');
target=matrix*candidate;
[command,~,~,flag,output]=lsqlin(eye(numel(candidate)),held,[],[], ...
    matrix./scale,target./scale,lower,upper,candidate,options);
rescued=false;
if flag<=0
    % 主活动集在近边界退化时可循环，用同一目标和约束的另一求解器复核，不改回旧分配。
    [command,~,~,flag,second_output]=lsqlin(eye(numel(candidate)),held,[],[], ...
        matrix./scale,target./scale,lower,upper,candidate,backup_options);
    second_output.iterations=second_output.iterations+output.iterations;
    output=second_output; rescued=true;
end
if flag<=0
    folder=fullfile(ca_setup(),'results','validation');
    name=['minimum_change_failure_',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')),'.mat'];
    save(fullfile(folder,name),'matrix','candidate','held','lower','upper','target','scale','command','flag','output');
    error('ca:RestoreSolveFailed','最小命令变化恢复未正常求解：标志%d，%s',flag,output.message);
end
effect_error=norm(matrix*command-target,Inf);
assert(effect_error<1e-7 && all(command>=lower-1e-8 & command<=upper+1e-8), ...
    '最小变化恢复改变了预测控制效果或违反边界。');
assert(norm(command-held)^2<=norm(candidate-held)^2+1e-7, ...
    '最小变化恢复的次级目标比原可行解更差。');
info=struct('exitflag',flag,'iterations',output.iterations,'effect_error',effect_error,'solver_rescue',rescued);
end
