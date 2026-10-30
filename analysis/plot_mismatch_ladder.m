function plot_mismatch_ladder(output_dir)
% 同时展示稳态主窗与整段瞬态，不把低误差窗口当作全程性能。
data=readtable(fullfile(output_dir,'summary.csv'),'TextType','string');
task=data(data.window=="task",:); whole=data(data.window=="whole",:);
ids=["M0","M1","M2","M2b","M3","M4"];
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
names=["yaw_rmse_deg","yaw_rmse_deg","moment_model_error_rms_nm", ...
    "saturation_percent","command_step_rms_deg","max_pwm_command_deg"];
titles=["主窗偏航误差","整段偏航误差（含加载卸载）","主窗力矩模型误差", ...
    "主窗命令触边事件","主窗PWM步变","主窗最大PWM命令"];
units=["RMSE (deg)","RMSE (deg)","RMS (Nm)","Percent (%)","RMS (deg)","Angle (deg)"];
figure_handle=figure('Visible','off','Color','w','Position',[40,40,1500,850]);
cleanup=onCleanup(@()close(figure_handle)); %#ok<NASGU>
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for panel=1:6
    source=task; if panel==2, source=whole; end
    values=NaN(numel(ids),numel(methods));
    for k=1:numel(ids)
        for m=1:numel(methods)
            row=source(source.case_id==ids(k) & source.method==methods(m),:);
            if ~isempty(row), values(k,m)=row.(names(panel)); end
        end
    end
    nexttile; bar(values); grid on; xticks(1:6); xticklabels(ids);
    title(titles(panel),'FontName','Microsoft YaHei'); ylabel(units(panel));
    if panel==3, set(gca,'YScale','log'); end
    if panel==4 && all(values==0,'all'), ylim([0,1]); end
    if panel==1, legend(methods,'Interpreter','none','Location','northwest','FontSize',8); end
end
exportgraphics(figure_handle,fullfile(output_dir,'mismatch_summary.png'),'Resolution',160);
savefig(figure_handle,fullfile(output_dir,'mismatch_summary.fig'));
end
