function [output,filter] = ca_biquad_step(input,filter)
% 转置直接二型递推；每个通道独立使用同一传递函数。
input=input(:)';
output=filter.b(1)*input+filter.state(1,:);
first=filter.b(2)*input-filter.a(2)*output+filter.state(2,:);
second=filter.b(3)*input-filter.a(3)*output;
filter.state=[first;second];
output=output';
end
