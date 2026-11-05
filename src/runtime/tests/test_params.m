function test_params()
% 参数更新失败必须保持原值，日志仅记录成功更新。
p=Shc09Params();p.declare('gain',1,@(x)isscalar(x) && x>0);p.set('gain',2,0.5);
assert(p.get('gain')==2 && numel(p.log())==1);
rejected=false;try,p.set('gain',-1);catch,rejected=true;end
assert(rejected && p.get('gain')==2);
cfg=ca_config();p=Shc09Params(cfg,@ca_validate_config);assert(isequaln(p.snapshot(),ca_validate_config(cfg)));
end
