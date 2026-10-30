function model = shc09_prediction_model(cfg)
% 从迁移前原SHC09脚本提取的独立样本读取旧模型，不依赖当前模型实现。
folder=fileparts(fileparts(mfilename('fullpath')));
saved=load(fullfile(folder,'fixtures','legacy_nominal_model.mat'),'model');model=saved.model;
if ~isempty(cfg.command_limit_deg), model.command_limit_deg=cfg.command_limit_deg; end
assert(model.command_limit_deg>0 && model.command_limit_deg<=model.source_limit_deg,'旧模型偏角限制错误。');
model.command_lower=-deg2rad(model.command_limit_deg)*ones(6,1);model.command_upper=-model.command_lower;
end
