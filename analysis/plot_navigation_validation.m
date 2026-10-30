function plot_navigation_validation(folder)
% 显示真实轨迹与估计轨迹的差异和各方法估计误差，避免把估计曲线冒充真值。
d=load(fullfile(folder,'comparison.mat'),'results'); r=d.results; t=r.reference.time_s;
methods=r.config.methods; colors=lines(numel(methods));
fig=figure('Visible','off','Color','w','Position',[60,60,1300,850]); layout=tiledlayout(2,2);
nexttile; hold on;
for k=1:numel(methods)
    log=r.logs.(methods(k));
    plot(log.position_ned_m(:,2),log.position_ned_m(:,1),'Color',colors(k,:),'LineWidth',1.1);
end
plot(r.reference.position_ned_m(:,2),r.reference.position_ned_m(:,1),'k--','HandleVisibility','off');
axis equal; grid on; xlabel('True E position (m)'); ylabel('True N position (m)');
legend(cellstr(methods),'Interpreter','none','Location','best');
nexttile; hold on;
for k=1:numel(methods)
    log=r.logs.(methods(k)); values=vecnorm(log.estimated_position_ned_m-log.position_ned_m,2,2);
    plot(t,values,'Color',colors(k,:));
end
grid on; xlabel('Time (s)'); ylabel('Navigation position error norm (m)');
nexttile; hold on;
for k=1:numel(methods)
    log=r.logs.(methods(k)); values=log.measured_euler_rad-log.euler_rad;
    values=rad2deg(atan2(sin(values),cos(values))); plot(t,vecnorm(values,2,2),'Color',colors(k,:));
end
grid on; xlabel('Time (s)'); ylabel('Navigation Euler error norm (deg)');
nexttile; hold on;
for k=1:numel(methods)
    log=r.logs.(methods(k)); plot(t,sqrt(mean(rad2deg(log.estimated_delta_rad-log.actual_delta_rad).^2,2)),'Color',colors(k,:));
end
grid on; xlabel('Time (s)'); ylabel('Fin estimate error RMS across fins (deg)');
title(layout,'Official PX4 ECL estimates in feedback; truth used for evaluation only');
drawnow; exportgraphics(fig,fullfile(folder,'navigation_validation.png'),'Resolution',160);
savefig(fig,fullfile(folder,'navigation_validation.fig')); close(fig);
fig=figure('Visible','off','Color','w','Position',[60,60,1250,800]); layout=tiledlayout(2,2);
method="PCA_PREDICTIVE"; if ~isfield(r.logs,method), method=methods(1); end
log=r.logs.(method);
for axis_id=1:3
    nexttile; plot(t,log.position_ned_m(:,axis_id),'b','LineWidth',1.1); hold on;
    plot(t,log.estimated_position_ned_m(:,axis_id),'r--'); plot(t,r.reference.position_ned_m(:,axis_id),'k:');
    ylabel(sprintf('NED axis %d position (m)',axis_id)); xlabel('Time (s)'); grid on;
    if axis_id==1, legend({'Truth','EKF estimate used by controller','Reference'},'Location','best'); end
end
nexttile; plot(t,1000*log.actual_tau_s,'LineWidth',1.1); hold on;
yline(1000*r.config.tau_model_s(1),'k--','LineWidth',1.5); grid on;
xlabel('Time (s)'); ylabel('Fin time constant (ms)'); legend({'1','2','3','4','5','6','Nominal model'},'Location','best');
title(layout,sprintf('%s: estimated feedback and hidden physical actuator parameters',method),'Interpreter','none');
drawnow; exportgraphics(fig,fullfile(folder,'estimated_feedback_and_tau.png'),'Resolution',160);
savefig(fig,fullfile(folder,'estimated_feedback_and_tau.fig')); close(fig);
end
