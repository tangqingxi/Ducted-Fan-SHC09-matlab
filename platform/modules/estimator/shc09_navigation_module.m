function estimate = shc09_navigation_module(bus,fusion,time_s)
% 订阅原始导航传感器包，发布估计姿态与位置，不接收物理state。
sensor=bus.subscribe('sensor_navigation');
estimate=shc09_navigation_fuse(sensor.packet,sensor.observation,fusion);
bus.publish('vehicle_attitude',struct('rotation',estimate.rotation),time_s);
bus.publish('vehicle_local_position',struct('position',estimate.position,'velocity',estimate.velocity),time_s);
bus.publish('estimator_health',struct('valid',estimate.attitude_valid && estimate.position_valid && estimate.origin_valid && estimate.yaw_aligned && estimate.fault_code==0),time_s);
end
