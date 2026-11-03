% 只核对汇总结构与状态字符串修复，不调用仿真、控制器或对象积分。
root=ca_setup();folder=fullfile(root,'docs','validation','hover_distance_takeoff_formal_20261103_r1');
addpath(fullfile(root,'research','hover_distance_takeoff_formal_20261103'));
a=load(fullfile(root,'results','hover_distance_takeoff_final_precheck_20261103_r1','logs','PCA_PREDICTIVE_s501.mat'),'metrics');
b=load(fullfile(root,'results','hover_distance_takeoff_formal_20261103_r1','logs','DA_NS_s501.mat'),'metrics');
m=a.metrics([]);m(end+1)=b.metrics;m(end+1)=a.metrics;assert(numel(m)==2);
q=readtable(fullfile(root,'results','hover_distance_takeoff_formal_20261103_r1','status.csv'),'TextType','string');
q.error_id=string(q.error_id);q.error_id(ismissing(q.error_id)|q.error_id=="NaN")="";assert(all(strlength(q.error_id)==0));
assert(nargin('hdtf_run')==1);engine=allocation_comparison_engine(root);
assert(engine=="d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750");
report=struct('passed',true,'empty_schema_assignment_rows',numel(m),'error_id_empty_rows',height(q), ...
    'corrected_driver_parses',true,'engine',engine,'flight_simulation_calls',0);
fid=fopen(fullfile(folder,'management_check.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
disp('MANAGEMENT_ONLY_CHECK_PASS_NO_SIMULATION');
