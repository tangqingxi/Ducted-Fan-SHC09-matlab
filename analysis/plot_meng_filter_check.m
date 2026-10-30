function plot_meng_filter_check(summary,folder)
% 同时展示反馈链路对姿态误差及指令变化的影响。
fig=figure('Visible','off','Color','w','Position',[80,80,1100,700]);
tiledlayout(2,1,'Padding','loose');
fields={'rotation_rmse_deg','command_step_rms_deg'};
labels={'Attitude error RMS (deg)','Command step RMS (deg)'};
for k=1:2
    nexttile;
    values=reshape(summary.(fields{k}),2,[])';
    bar(values); grid on;
    xticklabels({'Ideal acceleration','H1/H2: no gyro noise','H1/H2: gyro noise 0.05 deg/s'});
    ylabel(labels{k});
    legend({'DCA','Predictive PCA'},'Location','northwest');
end
exportgraphics(fig,fullfile(folder,'sensor_chain_comparison.png'),'Resolution',150);
savefig(fig,fullfile(folder,'sensor_chain_comparison.fig'));
close(fig);
end
