function shc09_estimator_module(bus,time_s)
% 理想导航也经明确测量topic转发，控制器仅订阅vehicle估计topic。
attitude=bus.subscribe('sensor_attitude');position=bus.subscribe('sensor_local_position');
bus.publish('vehicle_attitude',attitude,time_s);bus.publish('vehicle_local_position',position,time_s);
end
