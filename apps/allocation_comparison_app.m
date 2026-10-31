function study = allocation_comparison_app(varargin)
% 一条标准入口：先评价可比性，再报告跨种子效应与九种二维权衡。
root=ca_setup();p=inputParser;
addParameter(p,'cases',"auto");addParameter(p,'modes',["ideal","lite"]);addParameter(p,'seeds',1:3);
addParameter(p,'methods',["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"]);addParameter(p,'m4_load',[]);
addParameter(p,'use_cached',true);addParameter(p,'reuse_from',"");addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
addParameter(p,'smoke_test',false);addParameter(p,'fail_fast',false);parse(p,varargin{:});o=p.Results;
ids=reshape(string(o.cases),1,[]);modes=reshape(string(o.modes),1,[]);methods=reshape(string(o.methods),1,[]);seeds=reshape(o.seeds,1,[]);
selection_path=fullfile(root,'configs','comparison','m4_selection.json');selection=[];
if isfile(selection_path),selection=jsondecode(fileread(selection_path));end
if isequal(ids,"auto")
 assert(~isempty(selection),'请先完成M4负载扫描及版本化选择证据。');ids=["M0","M2b"];
 if selection.has_comparable_m4,ids(end+1)="M4";end
end
assert(~isempty(ids)&&all(ismember(ids,["M0","M2b","M4"]))&&numel(unique(ids))==numel(ids),'工况只允许M0/M2b/M4。');
assert(~isempty(modes)&&all(ismember(modes,["ideal","lite"]))&&numel(unique(modes))==numel(modes),'模式只允许ideal/lite。');
allowed=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
assert(~isempty(methods)&&all(ismember(methods,allowed))&&numel(unique(methods))==numel(methods),'选择原五方法的无重复子集。');
assert(~isempty(seeds)&&all(isfinite(seeds)&seeds>=1&seeds==fix(seeds)&seeds<2^32-80000)&&numel(unique(seeds))==numel(seeds),'种子为无重复正整数。');
for field=["use_cached","smoke_test","fail_fast"],assert(isscalar(o.(field))&&ismember(o.(field),[true,false]));end
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
load_m4=o.m4_load;
if any(ids=="M4")&&isempty(load_m4)
 assert(~isempty(selection)&&selection.has_comparable_m4,'M4没有已选可比负载；压力演示须显式设置m4_load=0.6。');load_m4=selection.selected_m4_load;
end
if ~isempty(load_m4),assert(isscalar(load_m4)&&ismember(load_m4,[0.4,0.5,0.6]),'M4负载只允许扫描过的0.4/0.5/0.6。');end
assert(~o.smoke_test||all(ids~="M4"),'两秒烟雾只用M0/M2b，不代替M4负载扫描。');
duration=20;if o.smoke_test,duration=2;end
plan=table();
for id=ids
 load_value=0.6;if id=="M4",load_value=load_m4;end
 for mode=modes,for seed=seeds,for method=methods
  plan=[plan;table(id,load_value,mode,seed,method,duration,logical(o.smoke_test),'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','duration_s','smoke_test'})];
 end,end,end
end
out=fullfile(root,'results','allocation_comparison_'+string(o.output_tag));study=allocation_comparison_run(plan,out,o);
study=allocation_comparison_products(study);save(fullfile(out,'study.mat'),'study','-v7');
end
