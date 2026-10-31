function shc09_lite_publish(bus,q,time_s)
% 只发布原始传感器，不发布姿态/位置真值topic。
% 对准段和任务段共用一个仿真时钟，将缓存序号时间换算成总线时间。
offset=time_s-q.imu.sample_time_s;q.imu.sample_time_s=time_s;
for name=["mag","baro","gnss"],q.(name).source_time_s=q.(name).source_time_s+offset;end
bus.publish('sensor_imu',q.imu,time_s);bus.publish('sensor_mag',q.mag,time_s);
bus.publish('sensor_baro',q.baro,time_s);bus.publish('sensor_gnss',q.gnss,time_s);
end
