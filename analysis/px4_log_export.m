function files = px4_log_export(log_or_mat_path,out_dir,model,cfg)
% 将离线视图写成MAT与带点号列名的宽表，禁止覆盖已有导出。
if nargin<3,model=struct();end
if nargin<4,cfg=struct();end
if ischar(log_or_mat_path)||isstring(log_or_mat_path)
 saved=load(log_or_mat_path);
 if isfield(saved,'log'),log=saved.log;elseif isfield(saved,'L'),log=saved.L;else,error('shc09:Px4Input','MAT必须包含log或L。');end
 if isempty(fieldnames(cfg))
  if isfield(saved,'cfg'),cfg=saved.cfg;elseif isfield(saved,'c'),cfg=saved.c;end
 end
 if isempty(fieldnames(model))
  if isfield(saved,'model'),model=saved.model;elseif isfield(saved,'m'),model=saved.m;elseif ~isempty(fieldnames(cfg)),model=ca_model(cfg);end
 end
 if ~isfield(log,'time_for_metrics')&&~isfield(log,'time_s')
  if isfield(saved,'ref'),log.time_for_metrics=saved.ref.time_s;elseif isfield(saved,'r'),log.time_for_metrics=saved.r.time_s;end
 end
else,log=log_or_mat_path;end
px4=px4_log_view(log,model,cfg);out_dir=char(out_dir);
mat_path=fullfile(out_dir,'px4.mat');csv_path=fullfile(out_dir,'px4_log.csv');
assert(~isfile(mat_path)&&~isfile(csv_path),'shc09:Px4Exists','禁止覆盖已有px4.mat/px4_log.csv。');
if ~isfolder(out_dir),mkdir(out_dir);end
[ok,attributes]=fileattrib(out_dir);assert(ok,'shc09:Px4Output','无法定位输出目录。');out_dir=attributes.Name;
mat_path=fullfile(out_dir,'px4.mat');csv_path=fullfile(out_dir,'px4_log.csv');
T=table();flatten(px4,"");csv=T;
% 十七位有效数字确保double往返；微秒整型仍按uint64原样写十进制。
for name=reshape(string(T.Properties.VariableNames),1,[])
 if isfloat(T.(name)),csv.(name)=compose('%.17g',double(T.(name)));end
end
writetable(csv,csv_path,'Encoding','UTF-8');save(mat_path,'px4','-v7');
files=struct('mat_path',string(mat_path),'csv_path',string(csv_path),'rows',height(T),'columns',width(T));
 function flatten(s,prefix)
  names=fieldnames(s);
  for i=1:numel(names)
   name=string(names{i});if prefix==""&&name=="meta",continue;end
   key=name;if prefix~="",key=prefix+"."+name;end
   value=s.(name);
   if isstruct(value),flatten(value,key);
   elseif isnumeric(value)||islogical(value)
    assert(size(value,1)==numel(px4.time_s),'shc09:Px4Shape','宽表字段首维必须为样本数。');
    value=reshape(value,numel(px4.time_s),[]);
    if size(value,2)==1,T.(key)=value;else,for j=1:size(value,2),T.(key+string(j-1))=value(:,j);end,end
   end
  end
 end
end
