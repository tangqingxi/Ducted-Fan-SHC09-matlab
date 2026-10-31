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
report=struct('boundary_passed',true,'nonfinite_invalid',true,'missing_seed_stress',true,'position_not_threshold',true);disp(report);
end
