function test_scheduler()
% 控制与PWM同刻按优先级执行，PWM序列与旧除法公式逐位一致。
s=Shc09Scheduler(800,333,0);s.add_rate_group('control',800,100);s.add_rate_group('pwm',333,50);
t=s.run(1);assert(sum(strcmp(t.group,'control'))==801 && sum(strcmp(t.group,'pwm'))==334);
assert(strcmp(t.group{1},'control') && strcmp(t.group{2},'pwm'));
a=t.time_s(strcmp(t.group,'pwm'));assert(isequal(a,(0:333)'/333));
s=Shc09Scheduler(800,333,0.0007);
for k=0:100,assert(s.next_pwm_time()==0.0007+k/333);s.advance_pwm();end
end
