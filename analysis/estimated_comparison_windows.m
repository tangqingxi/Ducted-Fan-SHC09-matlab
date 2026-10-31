function [names,bounds] = estimated_comparison_windows(experiment,smoke)
% 正式窗口固定；两秒窗口仅供契约烟雾测试，不替代完整协议。
names=["whole","task","transient"];
if smoke,bounds=[0,2;1,2;0,1];
elseif experiment=="E1",bounds=[0,12;2,10;0,2];
else,bounds=[0,20;6,16;0,6];end
end
