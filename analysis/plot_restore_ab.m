function figures = plot_restore_ab(folder,show_figures)
% 纯离线重绘恢复A/B，完整时域和主机动指标同时保留。
if nargin<2, show_figures=true; end
d=load(fullfile(folder,'comparison.mat'),'results'); r=d.results;
labels=string({r.variants.label}); colors=lines(numel(labels)); t=r.reference.time_s;
visible='off'; if show_figures, visible='on'; end
figures=gobjects(2,1);
fig=figure('Visible',visible,'Color','w','Position',[80,70,1250,800]); figures(1)=fig;
layout=tiledlayout(2,2);
names={'Yaw error (deg)','Position error norm (m)','Applied command step RMS across fins (deg)','Maximum applied command magnitude (deg)'};
for panel=1:4
    nexttile; hold on;
    for k=1:numel(labels)
        log=r.logs.(labels(k)); times=t;
        if panel==1
            values=rad2deg(atan2(sin(log.euler_rad(:,3)-r.reference.euler_rad(:,3)),cos(log.euler_rad(:,3)-r.reference.euler_rad(:,3))));
        elseif panel==2
            values=vecnorm(log.position_ned_m-r.reference.position_ned_m,2,2);
        elseif panel==3
            times=log.pwm_update_time_s(2:end);
            values=sqrt(mean(diff(rad2deg(log.pwm_command_rad)).^2,2));
        else
            values=max(abs(rad2deg(log.held_command_rad)),[],2);
        end
        ids=extreme_indices(values);
        plot(times(ids),values(ids),'Color',colors(k,:),'LineWidth',1.1);
    end
    xline(4,'k:','HandleVisibility','off'); xline(34,'k:','HandleVisibility','off');
    grid on; xlabel('Time (s)'); ylabel(names{panel});
end
legend(cellstr(labels),'Interpreter','none','Location','eastoutside');
title(layout,'Restoration A/B: same references, noise, plant, controller and priority allocation');
finish(fig,folder,'restore_response',show_figures);
fig=figure('Visible',visible,'Color','w','Position',[80,70,1200,750]); figures(2)=fig;
layout=tiledlayout(2,2); m=r.metrics(string(r.metrics.window)=="maneuver",:);
fields={'yaw_rmse_deg','command_step_rms_deg','position_rmse_m'};
titles={'Yaw RMSE (deg)','PWM command step RMS (deg)','Position vector RMSE (m)'};
for k=1:3
    nexttile; bar(m.(fields{k})); xticks(1:numel(labels)); xticklabels(labels);
    set(gca,'TickLabelInterpreter','none'); ylabel(titles{k}); grid on;
end
nexttile; timing=r.timing(string(r.timing.window)=="maneuver",:);
bar([timing.median_ms,timing.p95_ms,timing.p99_ms]); xticks(1:numel(labels)); xticklabels(labels);
set(gca,'TickLabelInterpreter','none'); ylabel('Desktop allocator solve time (ms)');
legend({'Median','95th percentile','99th percentile'},'Location','northwest'); grid on;
title(layout,'Maneuver window 4 to 34 s; solve times do not delay simulated commands');
finish(fig,folder,'restore_summary',show_figures);
end
function ids=extreme_indices(values)
% 只压缩显示点，分块保留最小值和最大值，指标仍使用完整采样。
n=numel(values); width=max(1,ceil(n/1500)); ids=zeros(0,1);
for first=1:width:n
    last=min(n,first+width-1); [~,a]=min(values(first:last)); [~,b]=max(values(first:last));
    ids=[ids;first;last;first+a-1;first+b-1]; %#ok<AGROW>
end
ids=unique(ids);
end
function finish(fig,folder,name,show_figures)
% 保留交互图窗，并保证后台导出先完成渲染。
drawnow; exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',160);
savefig(fig,fullfile(folder,[name,'.fig']));
if ~show_figures, close(fig); end
end
