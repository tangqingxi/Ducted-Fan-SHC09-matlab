function summary = ca_priority_diagnostic_summary(results)
% 可达域判据与分配器自身分支分列，不能把回退当成正常优先级发挥。
rows={};
for method=results.config.methods
    if ~isfield(results.diagnostics,method), continue; end
    data=results.diagnostics.(method);
    for set_name=["static","full_dynamic","affine_dynamic"]
        d=data(string(data.reachable_set)==set_name,:);
        comp=d.compensation_exitflag>0; total_bad=d.total_exitflag==-2;
        ray=d.ray_exitflag>0;
        conflict=comp & total_bad & ray & d.max_tracking_fraction>1e-6 & d.max_tracking_fraction<1-1e-6;
        noncollinear=d.normalized_torque_angle_deg>=30 & d.normalized_torque_angle_deg<=150;
        unknown=sum((d.compensation_exitflag<=0 & d.compensation_exitflag~=-2) ...
            | (d.total_exitflag<=0 & d.total_exitflag~=-2) | (d.ray_exitflag<=0 & d.ray_exitflag~=-2));
        rows(end+1,:)={char(method),char(set_name),height(d),100*mean(comp), ...
            100*mean(total_bad),100*mean(conflict),100*mean(conflict & noncollinear), ...
            100*mean(d.compensation_exitflag==-2),100*mean(d.ray_exitflag==-2), ...
            mean(d.normalized_priority_distance),unknown}; %#ok<AGROW>
    end
end
summary=cell2table(rows,'VariableNames',{'method','reachable_set','sample_count','compensation_reachable_percent', ...
    'total_unreachable_percent','normal_conflict_percent','noncollinear_conflict_percent', ...
    'compensation_unreachable_percent','priority_ray_unreachable_percent','mean_normalized_priority_distance','lp_unknown_count'});
end
