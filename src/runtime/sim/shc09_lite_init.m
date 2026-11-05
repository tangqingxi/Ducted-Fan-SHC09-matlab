function [estimator,memory] = shc09_lite_init(initial,cfg,noise,bus)
% 起飞前静置对准：初态只用于生成测量，不传给估计模块。
estimator=[];memory=[];stationary=initial;stationary.omega=zeros(3,1);stationary.velocity=zeros(3,1);
physical=struct('acceleration_ned_m_s2',zeros(3,1));warm=round(cfg.navigation_warmup_s*cfg.sample_hz);
p=shc09_lite_params(cfg);
for k=1:warm
 [q,memory]=shc09_lite_sensors(stationary,physical,cfg,noise,k,memory);
 t=(k-warm-1)/cfg.sample_hz;shc09_lite_publish(bus,q,t);
 estimator=shc09_estimator_lite_module(bus,estimator,p,t);
end
health=bus.latest('estimator_health');assert(health.valid,'shc09:LiteNotAligned','lite未对准，不能用真值补位。');
end
