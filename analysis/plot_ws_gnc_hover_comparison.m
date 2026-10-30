function figures = plot_ws_gnc_hover_comparison(result_path,show_figures)
% 离线绘制定点悬停轨迹、瞬时误差、扫幅指标和时间样本分布。
if nargin<2, show_figures=true; end
if isfolder(result_path), folder=result_path; else, folder=fileparts(result_path); end
data=load(fullfile(folder,'summary.mat'),'summary'); summary=data.summary;
metrics=summary.metrics; methods=unique(string(metrics.method),'stable'); colors=lines(numel(methods));
visible='off'; if show_figures, visible='on'; end
figures=gobjects(3,1);
primary=summary.options.primary_amplitude_nm;
case_data=load(fullfile(folder,sprintf('M%03d',round(primary*1000)),'comparison.mat'),'results');
r=case_data.results; cfg=r.config; t=r.reference.time_s; selected=t>=cfg.disturbance_start_s;
fig=figure('Visible',visible,'Color','w','Position',[60,60,1300,850]); figures(1)=fig;
layout=tiledlayout(2,2);
labels={'E position error (m)','Position error norm (m)','Velocity norm (m/s)','Rate-control error norm (deg/s)'};
for panel=1:4
    nexttile; hold on;
    for k=1:numel(methods)
        log=r.logs.(methods(k));
        position=log.position_ned_m-cfg.position_reference_ned_m(:)';
        if panel==1
            plot(position(selected,1),position(selected,2),'Color',colors(k,:),'LineWidth',1.2);
        else
            if panel==2, values=vecnorm(position,2,2);
            elseif panel==3, values=vecnorm(log.velocity_ned_m_s,2,2);
            else, values=vecnorm(rad2deg(log.omega_rad_s-log.omega_reference_rad_s),2,2); end
            plot(t,values,'Color',colors(k,:),'LineWidth',1.1);
        end
    end
    grid on; ylabel(labels{panel});
    if panel==1
        plot(0,0,'k+','MarkerSize',9,'HandleVisibility','off');
        xlabel('N position error (m)'); axis equal;
    else
        xline(cfg.disturbance_start_s,'k:','HandleVisibility','off'); xlabel('Time (s)');
    end
end
legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
title(layout,sprintf('Fixed-point hover: M_D = %.2f N m; NED target [0, 0, -10] m',primary));
finish(fig,folder,'hover_primary',show_figures);
fig=figure('Visible',visible,'Color','w','Position',[60,60,1300,850]); figures(2)=fig;
layout=tiledlayout(2,2);
fields={'position_rmse_m','position_peak_m','rate_control_error_rmse_deg_s','aero_extrapolated_percent'};
labels={'Position RMSE (m)','Peak position error (m)','Rate-control error RMS (deg/s)','Aero-table extrapolation (%)'};
for panel=1:4
    nexttile; hold on;
    for k=1:numel(methods)
        rows=string(metrics.method)==methods(k); values=metrics(rows,:);
        [amplitudes,order]=sort(values.amplitude_nm);
        plot(amplitudes,values.(fields{panel})(order),'-o','Color',colors(k,:),'LineWidth',1.3);
    end
    grid on; xlabel('Lateral moment amplitude (N m)'); ylabel(labels{panel});
end
legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
title(layout,'Common controller and sensors; only the allocator changes');
finish(fig,folder,'hover_amplitude_sweep',show_figures);
% 每个箱体对应一次确定性正弦实验的时间样本分布，不用于独立重复的显著性推断。
values=[]; amplitude_groups=strings(0,1); method_groups=strings(0,1);
for amplitude=reshape(summary.options.amplitudes_nm,1,[])
    data=load(fullfile(folder,sprintf('M%03d',round(amplitude*1000)),'comparison.mat'),'results');
    r=data.results; selected=r.reference.time_s>=r.config.disturbance_start_s;
    for method=methods'
        log=r.logs.(method);
        error=vecnorm(log.position_ned_m(selected,:)-r.config.position_reference_ned_m(:)',2,2);
        values=[values;error]; %#ok<AGROW>
        amplitude_groups=[amplitude_groups;repmat(string(amplitude),numel(error),1)]; %#ok<AGROW>
        method_groups=[method_groups;repmat(method,numel(error),1)]; %#ok<AGROW>
    end
end
fig=figure('Visible',visible,'Color','w','Position',[60,60,1200,700]); figures(3)=fig;
levels=string(sort(summary.options.amplitudes_nm));
boxchart(categorical(amplitude_groups,levels,levels),values, ...
    'GroupByColor',categorical(method_groups,methods,methods));
ylabel('Position error norm (m)'); xlabel('Lateral moment amplitude (N m)'); grid on;
legend('Location','eastoutside','Interpreter','none');
title('Time-sample distributions within each run; samples are not independent trials');
finish(fig,folder,'hover_position_distribution',show_figures);
fprintf('已从保存日志重绘定点悬停三张图：%s\n',folder);
end
function finish(fig,folder,name,show_figures)
% 保存标准图片与可编辑图；交互模式保留窗口。
exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',160);
savefig(fig,fullfile(folder,[name,'.fig']));
if show_figures, drawnow; else, close(fig); end
end
