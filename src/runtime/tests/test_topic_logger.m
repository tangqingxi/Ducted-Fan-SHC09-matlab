function test_topic_logger()
% 最新值与历史分离、扩容、时间戳、PWM锁存和真值topic隔离。
bus=Shc09Bus();logger=Shc09TopicLogger(1);bus.attach_logger(logger);
payload=struct('value',1);bus.publish('sample',payload,0);payload.value=2;bus.publish('sample',payload,0.01);
history=logger.snapshot();latest=bus.latest('sample');assert(history.sample.data{1}.value==1 && latest.value==2);
assert(isequal(history.sample.time_s,[0;0.01]) && isequal(history.sample.sequence,uint64([1;2])));
assert(~bus.exists('plant_truth') && ~isfield(history,'plant_truth'));
bus.publish('actuator_servos',struct('command',(1:6)','source_time_s',0.01),0.01);
bus.publish('actuator_motors',struct('motor_command',42),0.01);
output=shc09_actuator_output_module(bus,0.012);assert(isequal(output.command,(1:6)') && output.source_time_s==0.01);
assert(bus.timestamp('actuator_outputs')==0.012);
history=logger.snapshot();assert(numel(history.actuator_outputs.data)==1);
end
