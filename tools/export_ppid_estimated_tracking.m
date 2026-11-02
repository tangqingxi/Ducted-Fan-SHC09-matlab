function metrics=export_ppid_estimated_tracking(input_folder,output_folder)
% 仅从既有完整日志计算估计状态相对规划参考的误差，不调用仿真、不覆盖原指标。
assert(isfolder(input_folder)&&~isfolder(output_folder),'输入须存在，输出须为全新目录。');
status=readtable(fullfile(input_folder,'status.csv'),'TextType','string');
assert(height(status)==15&&all(status.status=="completed"));
metrics=table();signatures=strings(height(status),1);
for i=1:height(status)
    path=fullfile(input_folder,'logs',sprintf('%s_s%d.mat',status.method(i),status.seed(i)));
    d=load(path,'L','ref','plan','signature');L=d.L;ref=d.ref;
    assert(numel(L.time_s)==41601&&L.time_s(end)==52&&~L.truth_feedback);
    q=L.time_s>=d.plan.main_window_s(1)&L.time_s<=d.plan.main_window_s(2);
    position=L.estimated_position(q,:)-ref.position_ned_m(q,:);
    velocity=L.estimated_velocity(q,:)-ref.velocity_ned_m_s(q,:);
    yaw=atan2(sin(L.estimated_euler(q,3)-ref.euler_rad(q,3)),cos(L.estimated_euler(q,3)-ref.euler_rad(q,3)));
    metrics=[metrics;table(status.method(i),status.seed(i),sum(q), ...
        sqrt(mean(sum(position(:,1:2).^2,2))),sqrt(mean(position(:,1).^2)),sqrt(mean(position(:,2).^2)), ...
        sqrt(mean(position(:,3).^2)),sqrt(mean(sum(position.^2,2))),sqrt(mean(sum(velocity.^2,2))), ...
        rad2deg(sqrt(mean(yaw.^2))), ...
        'VariableNames',{'method','seed','score_samples','estimated_horizontal_rmse_m','estimated_north_rmse_m', ...
        'estimated_east_rmse_m','estimated_altitude_rmse_m','estimated_position_3d_rmse_m', ...
        'estimated_velocity_3d_rmse_m_s','estimated_yaw_rmse_deg'})]; %#ok<AGROW>
    signatures(i)=d.signature;
end
assert(all(metrics.score_samples==35201));
for seed=unique(status.seed)'
    assert(numel(unique(signatures(status.seed==seed)))==1,'同种子五方法的输入签名不一致。');
end
mkdir(output_folder);writetable(metrics,fullfile(output_folder,'estimated_tracking_metrics.csv'));
note=struct('metric','EKF estimated state minus planned reference; not physical truth tracking', ...
    'input_folder',input_folder,'window_s',[6,50],'score_hz',800,'plot_hz',100, ...
    'runs',height(status),'samples_per_run',35201,'postflight_alignment',false, ...
    'original_scores_overwritten',false,'simulations_rerun',0);
fid=fopen(fullfile(output_folder,'measurement_domain_analysis.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(note,PrettyPrint=true));disp(metrics);
end
