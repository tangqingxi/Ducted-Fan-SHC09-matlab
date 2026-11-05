function report = test_estimated_allocation_comparison()
% 新鲜两秒五方法检查隔离，再从缓存重放；不替代正式E1/E2研究。
ca_setup();[front,valid]=estimated_pareto_front([1;2;3;2;NaN],[3;2;4;2;1]);
assert(isequal(front,[true;true;false;true;false]) && ~valid(5),'已知权衡/支配/平局前沿错误。');
tag=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
a=estimated_allocation_comparison_app('studies','legacy_experiments','E1','smoke_test',true,'use_cached',false,'output_tag','test_'+tag+'_fresh');
b=estimated_allocation_comparison_app('studies','legacy_experiments','E1','smoke_test',true,'output_tag','test_'+tag+'_cached');
assert(isequaln(a.summary,b.summary)&&isequaln(a.pareto,b.pareto),'同种子缓存重放不确定。');
assert(height(a.summary)==15 && numel(unique(a.summary.method))==5);
assert(all(a.provenance.topic_check=="verified_absent") && all(b.provenance.loaded));
assert(all(a.summary.backend_role=="experimental"));
for experiment=["E1","E2"]
 [~,w]=estimated_comparison_windows(experiment,false);
 expected=[0,12;2,10;0,2];if experiment=="E2",expected=[0,20;6,16;0,6];end
 assert(isequal(w,expected));
end
[~,w]=estimated_comparison_windows("E1",true);
for k=1:3
 windows=["whole","task","transient"];chosen=a.summary.window==windows(k);
 assert(all(a.summary.window_start_s(chosen)==w(k,1)) && all(a.summary.window_end_s(chosen)==w(k,2)));
end
names=["attitude_rmse_deg","yaw_rmse_deg","position_rmse_m","rate_rmse_deg_s", ...
 "common_residual_rms","common_predicted_torque_error_rms_nm","allocation_demand_error_rms_rad_s2", ...
 "native_residual_rms","command_total_variation_deg","bias_rmse_max_axis_deg_s"];
assert(all(ismember(names,string(a.summary.Properties.VariableNames))));
assert(height(a.pareto)==135 && all(a.pareto.valid));
assert(all(ismember(["cost_metric","objective_metric","pareto_efficient"],string(a.pareto.Properties.VariableNames))));
for file=["summary.csv","pareto.csv","metric_effects.csv","report.md","figures/pareto_E1_whole.png"]
 assert(isfile(fullfile(a.output_dir,file)));
end
report=struct('fresh_output',a.output_dir,'cached_output',b.output_dir,'methods',5,'deterministic',true,'truth_topics_absent',true);disp(report);
end
