function report = test_lite_comparison_rankable(folder)
% 用完整三种子实测记录回归主窗峰值；不修改门禁、窗口、负载或缺失样本。
root=ca_setup();if nargin<1,folder=fullfile(root,'examples','lite_comparison_v050','lite_3seeds');end
S=readtable(fullfile(folder,'summary.csv'),'TextType','string');T=readtable(fullfile(folder,'status.csv'),'TextType','string');
C=readtable(fullfile(folder,'comparability.csv'),'TextType','string');V=readtable(fullfile(folder,'provenance.csv'),'TextType','string');
assert(height(T)==30&&height(S)==90&&height(C)==2&&height(V)==30);
assert(all(T.status=="completed")&&all(T.estimator_mode=="lite")&&all(T.duration_s==20)&&~any(T.smoke_test));
assert(isequal(sort(unique(T.case_id)),["M0";"M2b"])&&isequal(sort(unique(T.seed)),[1;2;3]));
assert(height(unique(T(:,{'case_id','seed','method'}),'rows'))==30);
assert(all(T.load_fraction==0.6)&&all(C.completed_methods==5)&&all(C.requested_seed_count==3));
assert(all(V.topic_check=="verified_absent")&&numel(unique(V.engine_fingerprint))==1);
assert(V.engine_fingerprint(1)==allocation_comparison_engine(root),'峰值记录不属于当前估计器引擎。');
q=S.window=="task";assert(sum(q)==30&&all(S.window_start_s(q)==6)&&all(S.window_end_s(q)==16));
values=[S.attitude_peak_deg(q),S.saturation_percent(q),S.estimated_attitude_rmse_deg(q),S.aero_extrapolated_count(q)];
assert(all(isfinite(values),'all')&&all(values(:,1)<=5)&&all(values(:,2)<=10)&&all(values(:,3)<=2)&&all(values(:,4)==0),'lite主窗峰值或其他固定门禁未通过。');
actual=allocation_comparability(S,T);assert(all(actual.comparability=="rankable")&&all(C.comparability=="rankable"));
for id=["M0","M2b"]
 r=C.case_id==id;data=q&S.case_id==id;
 assert(abs(C.max_attitude_error_deg(r)-max(S.attitude_peak_deg(data)))<1e-10);
 assert(sum(T.case_id==id)==15&&all(ismember(["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"],unique(T.method(T.case_id==id)))));
end
report=struct('completed',30,'cases',C.case_id,'max_attitude_error_deg',C.max_attitude_error_deg,'rankable',true,'truth_topics_absent',true);disp(report);
end
