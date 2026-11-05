function outputs = shc09_actuator_output_module(bus,event_time)
% PWM边界锁存最新候选值；源时间戳来自控制发布，电机仍按控制周期保持。
servos=bus.subscribe('actuator_servos');motors=bus.subscribe('actuator_motors');
outputs=struct('command',servos.command,'source_time_s',servos.source_time_s,'motor_command',motors.motor_command);
bus.publish('actuator_outputs',outputs,event_time);
end
