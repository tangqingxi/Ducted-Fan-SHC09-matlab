function value = ca_stage_reference(time_s,stages,transition_s,initial)
% 五次平滑连接分段常值目标，端点速度和加速度均为零。
time_s=time_s(:);
if isempty(stages), value=repmat(initial(:)',numel(time_s),1); return; end
value=repmat(stages(1,2:4),numel(time_s),1);
for k=2:size(stages,1)
    z=min(1,max(0,(time_s-stages(k,1))/transition_s));
    weight=10*z.^3-15*z.^4+6*z.^5;
    value=value+weight*(stages(k,2:4)-stages(k-1,2:4));
end
end
