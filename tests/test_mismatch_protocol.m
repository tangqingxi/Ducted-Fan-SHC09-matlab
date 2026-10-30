function report = test_mismatch_protocol()
% 检验固定点负载协议、真正行空间失配及失败分类，不用算法结果调工况。
ca_setup(); [cfg,model,ref,experiment,protocol,cases]=ca_mismatch_protocol();
assert(cfg.duration_s==20 && protocol.load_fraction==0.6 && protocol.mode=="load_hold",'主协议默认值错误。');
assert(isequal(protocol.evaluation_window_s,[6,16]) && isempty(cfg.position_reference_stages),'主评价窗或固定点错误。');
assert(all(ref.position_ned_m==[0,0,-10],'all') && isequal(cfg.wls_axis_weights,[1;1;1000]),'位置参考或WLS主设置错误。');
assert(isequal(cases(4).gains,[1.2;1;0.8;1;1.2;1]) && strcmp(cases(4).id,'M2b'),'M2b定义错误。');
defs=ca_mismatch_cases(cases,model,protocol);
assert(defs.rowspace_mismatch(defs.case_id=="M2")<1e-12 && defs.rowspace_mismatch(defs.case_id=="M2b")>0.05,'行空间探针不可区分。');
assert(defs.nullspace_mismatch(defs.case_id=="M2")>0.1,'零空间探针未生效。');
again=ca_prepare_experiment(cfg,ref.time_s);
assert(isequal(experiment.gyro_noise_rad_s,again.gyro_noise_rad_s),'公共输入不可重放。');
for value=[0.3,0.9]
    rejected=false; try, ca_mismatch_protocol(20,value); catch, rejected=true; end
    assert(rejected,'非法负载比例未拒绝。');
end
[old,~,~,~,p]=ca_mismatch_protocol(12,0.8,"pilot_12s");
assert(old.duration_s==12 && ~isempty(old.position_reference_stages) && p.mode=="pilot_12s",'旧协议未保留。');
[stop,gate]=ca_mismatch_should_stop(MException('ca:MockSolver','测试求解器失败'),cfg,false); assert(~stop && ~gate,'普通失败应继续。');
[stop,gate]=ca_mismatch_should_stop(MException('ca:AeroTableDomain','空速=0.5米每秒'),cfg,false); assert(~stop && ~gate,'已知低速legacy越界不应触发高速整体门禁。');
[stop,gate]=ca_mismatch_should_stop(MException('ca:AeroTableDomain','空速=1.5米每秒'),cfg,false); assert(stop && gate,'高速气动失败必须整体停止。');
stop=ca_mismatch_should_stop(MException('ca:MockSolver','测试失败'),cfg,true); assert(stop,'烟雾快速失败未生效。');
report=struct('protocol',protocol,'definitions',defs,'failure_policy_passed',true);
fprintf('恒定负载协议、M2b、失配指标和失败策略检查通过。\n');
end
