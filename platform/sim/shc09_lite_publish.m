function shc09_lite_publish(bus,q,time_s)
% 只发布原始传感器，不发布姿态/位置真值topic。
bus.publish('sensor_imu',q.imu,time_s);bus.publish('sensor_mag',q.mag,time_s);
bus.publish('sensor_baro',q.baro,time_s);bus.publish('sensor_gnss',q.gnss,time_s);
end
