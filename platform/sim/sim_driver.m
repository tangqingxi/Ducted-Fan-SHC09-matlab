function log = sim_driver(model,cfg,ref,method,experiment)
% 薄适配器保留旧积分器与全部时序，参数存储只负责验证和快照。
parameters=Shc09Params(cfg,@ca_validate_config);
log=ca_simulate(model,parameters.snapshot(),ref,method,experiment);
end
