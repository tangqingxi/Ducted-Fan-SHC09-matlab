function figures = plot_priority_pilot(result_path,show_figures)
% 离线显示偏航稳定、位置机动及正常缩减与回退，不剔除大误差。
if nargin<2, show_figures=true; end
if isfolder(result_path), folder=result_path; else, folder=fileparts(result_path); end
d=load(fullfile(folder,'comparison.mat'),'results'); r=d.results;
methods=r.config.methods; methods=methods(arrayfun(@(m)isfield(r.logs,m),methods));
colors=lines(numel(methods)); t=r.reference.time_s;
visible='off'; if show_figures, visible='on'; end
figures=gobjects(2,1);
fig=figure('Visible',visible,'Color','w','Position',[70,70,1300,880]); figures(1)=fig;
layout=tiledlayout(3,2);
labels={'Yaw angle (deg)','E position (m)','Roll angle (deg)','PWM command max (deg)','Normal tracking fraction','Fallback mode'};
for panel=1:6
    nexttile; hold on;
    for k=1:numel(methods)
        log=r.logs.(methods(k));
        if panel==1, values=rad2deg(log.euler_rad(:,3));
        elseif panel==2, values=log.position_ned_m(:,2);
        elseif panel==3, values=rad2deg(log.euler_rad(:,1));
        elseif panel==4, values=max(abs(rad2deg(log.held_command_rad)),[],2);
        elseif panel==5, values=log.lambda; values(log.mode~=0)=NaN;
        else, values=log.mode; end
        plot(t,values,'Color',colors(k,:),'LineWidth',1.1);
    end
    if panel==2, plot(t,r.reference.position_ned_m(:,2),'k--','HandleVisibility','off'); end
    xline(4,'k:','HandleVisibility','off'); xline(10,'k:','HandleVisibility','off');
    grid on; xlabel('Time (s)'); ylabel(labels{panel});
end
legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
title(layout,sprintf('Yaw compensation %.0f%%; lateral position command +/- %.2f m', ...
    100*r.options.load_fraction,r.options.position_amplitude_m));
finish(fig,folder,'priority_pilot_response',show_figures);
fig=figure('Visible',visible,'Color','w','Position',[70,70,1300,880]); figures(2)=fig;
layout=tiledlayout(2,2);
for panel=1:4
    nexttile; hold on;
    for k=1:numel(methods)
        data=r.diagnostics.(methods(k)); data=data(string(data.reachable_set)=="full_dynamic",:);
        if panel==1
            values=double(data.compensation_exitflag>0 & data.total_exitflag==-2 ...
                & data.ray_exitflag>0 & data.max_tracking_fraction>1e-6 & data.max_tracking_fraction<1-1e-6);
            label='Compensation feasible, total infeasible';
        elseif panel==2, values=data.max_tracking_fraction; label='Common full-reachability maximum fraction';
        elseif panel==3, values=data.normalized_priority_distance; label='Normalized priority-segment distance';
        else, values=data.normalized_torque_angle_deg; label='Normalized compensation/tracking angle (deg)'; end
        plot(data.time_s,values,'Color',colors(k,:));
    end
    grid on; xlabel('Time (s)'); ylabel(label);
end
legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
title(layout,'Independent offline LP diagnostics at the same PWM evaluation horizon');
finish(fig,folder,'priority_pilot_reachability',show_figures);
fprintf('已重绘优先级先行实验：%s\n',folder);
end
function finish(fig,folder,name,show_figures)
% 保留完整数值范围，后台模式保存后关闭图窗。
exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',160);
savefig(fig,fullfile(folder,[name,'.fig']));
if show_figures, drawnow; else, close(fig); end
end
