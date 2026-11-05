function runtime = shc09_runtime(cfg)
% 每次运行拥有独立总线和时钟，不复用全局状态。
runtime.bus=Shc09Bus();
runtime.logger=Shc09TopicLogger(ceil(cfg.duration_s*cfg.sample_hz)+4);runtime.bus.attach_logger(runtime.logger);runtime.scheduler=Shc09Scheduler(cfg.sample_hz,cfg.pwm_hz,cfg.pwm_phase_s);
end
