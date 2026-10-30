function plot_noncollinear_study(report,cfg,out)
% 同时展示补偿方向、跟踪方向及优先关系距离，保留收益与代价。
fig=figure('Visible','off','Color','w','Position',[80,80,1500,950]);
tiledlayout(3,1,'TileSpacing','compact','Padding','loose');
fields={'compensation_axis_projection_ratio','tracking_axis_projection_ratio','normalized_priority_distance'};
labels={'Comp. axis / target','Tracking axis / target','Priority distance'};
ticklabels=["Trim R/P","Trim R/Y","Trim P/R","Trim P/Y","Trim Y/R","Trim Y/P", ...
    "New R/P","New R/Y","New P/R","New P/Y","New Y/R","New Y/P"];
for panel=1:3
    values=reshape(report.(fields{panel}),5,[])';
    nexttile;
    bar(values); grid on; hold on;
    if panel==1, yline(1,'k--'); end
    ylabel(labels{panel});
    xline(6.5,'k:');
    if panel<3
        xticks([]);
    else
        xticks(1:12); xticklabels(ticklabels);
        xlabel('Compensation / tracking axis: R=roll, P=pitch, Y=yaw; Trim=existing trim, New=new demand');
    end
    if panel==1, legend(cellstr(cfg.methods),'Interpreter','none','Location','eastoutside'); end
end
exportgraphics(fig,fullfile(out,'priority_comparison.png'),'Resolution',150);
savefig(fig,fullfile(out,'priority_comparison.fig'));
close(fig);
end
