function report = test_allocation_comparability()
% 人工门禁边界、缺失种子和非有限值，不运行数值模型或改动实测数据。
S=table();T=table();methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
for seed=1:2,for method=methods
 S=[S;table("M0",0.6,"lite","task",10,5,100,2,0,'VariableNames',{'case_id','load_fraction','estimator_mode','window','saturation_percent','attitude_peak_deg','position_peak_m','estimated_attitude_rmse_deg','aero_extrapolated_count'})];
 T=[T;table("M0",0.6,"lite",seed,method,"completed",false,"",false,'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','status','smoke_test','error_id','aero_extrapolated'})];
end,end
C=allocation_comparability(S,T);assert(C.comparability=="rankable"&&C.completed_methods==5);
for field=["saturation_percent","attitude_peak_deg","position_peak_m","estimated_attitude_rmse_deg","aero_extrapolated_count"]
 bad=S;bad.(field)(1)=NaN;C=allocation_comparability(bad,T);assert(C.comparability=="invalid",'非有限门禁输入被遗漏。');
end
missing=T;missing(2,:)=[];C=allocation_comparability(S,missing);assert(C.completed_methods==4&&C.comparability=="stress",'方法缺失种子未被识别。');
for field=["saturation_percent","attitude_peak_deg","estimated_attitude_rmse_deg"]
 bad=S;bad.(field)(1)=bad.(field)(1)+1e-6;C=allocation_comparability(bad,T);assert(C.comparability=="stress");
end
% 保留真实CSV往返夹具，覆盖全空数值推断、审计错误和空状态拒绝。
root=ca_setup();folder=fullfile(root,'results','comparability_csv_'+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));mkdir(folder);
normal=T;normal.error_message=repmat("",height(T),1);path=fullfile(folder,'empty_errors.csv');writetable(normal,path);
loaded=readtable(path,'TextType','string');assert(all(ismissing(loaded.error_id))&&all(ismissing(loaded.error_message)));
Ccsv=allocation_comparability(S,loaded);Cnormal=allocation_comparability(S,normal);
assert(isequaln(Ccsv,Cnormal)&&Ccsv.comparability=="rankable",'全空错误列的正常完成CSV被误判。');
numeric=normal;numeric.error_id=NaN(height(T),1);numeric.error_message=NaN(height(T),1);
assert(isequaln(allocation_comparability(S,numeric),Cnormal),'数值缺失错误列未正确归一化。');
for identifier=["ca:CacheMismatch","ca:ComparisonTopicAudit"]
 bad=normal;bad.error_id(1)=identifier;path=fullfile(folder,erase(identifier,':')+'.csv');writetable(bad,path);
 loaded=readtable(path,'TextType','string');Ccsv=allocation_comparability(S,loaded);
 assert(Ccsv.comparability=="invalid"&&contains(Ccsv.reason,"缓存或真值隔离审计失败"),'审计错误CSV未被拒绝。');
end
blank=normal;blank.status(:)="";path=fullfile(folder,'empty_status.csv');writetable(blank,path);
Ccsv=allocation_comparability(S,readtable(path,'TextType','string'));
assert(Ccsv.comparability=="stress"&&Ccsv.completed_methods==0,'空状态被错误填为完成。');
report=struct('csv_empty_error_id_passed',true,'csv_audit_errors_invalid',true,'csv_normal_completed_rankable',true,'csv_empty_status_stress',true,'csv_fixture_dir',folder,'boundary_passed',true,'nonfinite_invalid',true,'missing_seed_stress',true,'position_not_threshold',true);disp(report);
end
