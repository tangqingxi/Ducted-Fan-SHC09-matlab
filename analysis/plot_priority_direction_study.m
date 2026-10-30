function figures = plot_priority_direction_study(result_path,show_figures)
% 长驻留任务同时显示位置目标、姿态误差和分支，失败方法在状态表保留。
if nargin<2, show_figures=true; end
if isfolder(result_path), folder=result_path; else, folder=fileparts(result_path); end
d=load(fullfile(folder,'comparison.mat'),'results'); r=d.results;
if isfield(r.variants,'restore_mode')
    figures=plot_restore_ab(folder,show_figures); return;
end
labels=string({r.variants.label}); labels=labels(arrayfun(@(s)isfield(r.logs,s),labels));
colors=lines(numel(labels)); t=r.reference.time_s;
visible='off'; if show_figures, visible='on'; end
figures=gobjects(2,1);
fig=figure('Visible',visible,'Color','w','Position',[60,60,1400,900]); figures(1)=fig;
layout=tiledlayout(3,2);
names={'Yaw angle (deg)','N position (m)','Tilt error norm (deg)','E position (m)','Normal tracking fraction','Applied PWM command max (deg)'};
for panel=1:6
    nexttile; hold on;
    for k=1:numel(labels)
        log=r.logs.(labels(k));
        if panel==1, values=rad2deg(log.euler_rad(:,3));
        elseif panel==2, values=log.position_ned_m(:,1);
        elseif panel==3, values=vecnorm(rad2deg(log.euler_error_rad(:,1:2)),2,2);
        elseif panel==4, values=log.position_ned_m(:,2);
        elseif panel==5, values=log.lambda; values(log.mode~=0)=NaN;
        else, values=max(abs(rad2deg(log.held_command_rad)),[],2); end
        indices=display_indices(values);
        plot(t(indices),values(indices),'Color',colors(k,:),'LineWidth',1.1);
    end
    if panel==2 || panel==4
        axis_id=1; if panel==4, axis_id=2; end
        values=r.reference.position_ned_m(:,axis_id); indices=display_indices(values);
        plot(t(indices),values(indices),'k--','LineWidth',1.4,'HandleVisibility','off');
    end
    xline(4,'k:','HandleVisibility','off'); xline(r.protocol.maneuver_window_s(2),'k:','HandleVisibility','off');
    grid on; ylabel(names{panel}); xlabel('Time (s)');
end
legend(cellstr(labels),'Interpreter','none','Location','eastoutside');
title(layout,sprintf('%s: %g s dwell, common controllers and plant',r.scenario,diff(r.protocol.leg_windows_s(1,:))),'Interpreter','none');
finish(fig,folder,'direction_response',show_figures);
fig=figure('Visible',visible,'Color','w','Position',[60,60,1300,700]); figures(2)=fig;
layout=tiledlayout(2,2);
nexttile; hold on;
first=r.logs.(labels(1));
plot(t,first.disturbance_torque_nm,'LineWidth',1.2); grid on;
xlabel('Time (s)'); ylabel('External moment (N m)'); legend({'Mx','My','Mz'});
nexttile; hold on;
for k=1:numel(labels)
    data=r.terminals(string(r.terminals.variant)==labels(k),:);
    plot(data.leg,data.terminal_position_rmse_m,'-o','Color',colors(k,:));
end
yline(r.protocol.settling_radius_m,'k:','HandleVisibility','off'); grid on;
xlabel('Leg'); ylabel('Last 0.5 s position RMSE (m)');
nexttile; hold on;
for k=1:numel(labels)
    data=r.diagnostics.(labels(k)); data=data(string(data.reachable_set)=="affine_dynamic",:);
    plot(data.time_s,data.max_tracking_fraction,'Color',colors(k,:));
end
grid on; xlabel('Time (s)'); ylabel('Maximum feasible tracking fraction');
nexttile; hold on;
for k=1:numel(labels)
    data=r.diagnostics.(labels(k)); data=data(string(data.reachable_set)=="full_dynamic",:);
    plot(data.time_s,data.normalized_priority_distance,'Color',colors(k,:));
end
grid on; xlabel('Time (s)'); ylabel('Normalized priority-segment distance');
legend(cellstr(labels),'Interpreter','none','Location','eastoutside');
title(layout,'Load protocol, endpoint completion and independent LP diagnostics');
finish(fig,folder,'direction_diagnostics',show_figures);
fprintf('已重绘长驻留方向实验：%s\n',folder);
end
function finish(fig,folder,name,show_figures)
% 图窗交互显示与后台导出采用相同的数据范围。
drawnow;
exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',160);
savefig(fig,fullfile(folder,[name,'.fig']));
if show_figures, drawnow; else, close(fig); end
end
function indices=display_indices(values)
% 长记录仅对显示做保极值压缩，原始日志及全部数值指标保持全采样率。
n=numel(values); width=max(1,ceil(n/1000)); indices=zeros(0,1);
for first=1:width:n
    last=min(n,first+width-1); block=values(first:last);
    if all(isnan(block))
        chosen=[first;last];
    else
        [~,low]=min(block,[],'omitnan'); [~,high]=max(block,[],'omitnan');
        chosen=[first;last;first+low-1;first+high-1];
    end
    indices=[indices;chosen]; %#ok<AGROW>
end
changes=find(diff(isnan(values))~=0);
indices=unique([indices;changes;changes+1]);
end
