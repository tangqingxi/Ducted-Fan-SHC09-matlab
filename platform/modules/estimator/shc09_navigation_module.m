function estimate = shc09_navigation_module(bus,fusion,time_s)
% 订阅原始导航传感器包，发布估计姿态与位置，不接收物理state。
sensor=bus.subscribe('sensor_navigation');
estimate=shc09_navigation_fuse(sensor.packet,sensor.observation,fusion);
bus.publish('vehicle_attitude',struct('rotation',estimate.rotation),time_s);
bus.publish('vehicle_local_position',struct('position',estimate.position,'velocity',estimate.velocity),time_s);
end
