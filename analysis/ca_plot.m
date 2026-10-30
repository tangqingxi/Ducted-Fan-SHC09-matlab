function ca_plot(results,folder)
% 保存真实姿态跟踪曲线及求解、残差诊断；不同方法使用一致颜色。
visible='off';
if results.config.show_figures, visible='on'; end
methods=results.config.methods;
colors=lines(numel(methods));
t=results.reference.time_s;
fig=figure('Visible',visible,'Color','w','Position',[80,80,1200,800]);
layout=tiledlayout(3,1);
axis_names={'Roll (deg)','Pitch (deg)','Yaw (deg)'};
for axis=1:3
    nexttile;
    hold on;
    position_mode=isfield(results.config,'flight_mode') && string(results.config.flight_mode)=="position_hold";
    if ~position_mode
        plot(t,rad2deg(results.reference.euler_rad(:,axis)),'k--','LineWidth',1.5);
    end
    for k=1:numel(methods)
        log=results.logs.(methods(k));
        if position_mode
            values=log.euler_error_rad(:,axis);
        else
            values=log.euler_rad(:,axis);
        end
        plot(t,rad2deg(values),'Color',colors(k,:));
    end
    grid on; ylabel(axis_names{axis});
end
xlabel('Time (s)');
if position_mode
    legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
    title(layout,'Position mode: actual attitude minus each controller command');
else
    legend(['Reference',cellstr(methods)],'Interpreter','none','Location','eastoutside');
end
title(layout,sprintf('SHC09: common %g Hz control and %g Hz PWM', ...
    results.config.sample_hz,results.config.pwm_hz));
if position_mode, title(layout,'Position hold: attitude error relative to the outer-loop command'); end
exportgraphics(fig,fullfile(folder,'attitude_tracking.png'),'Resolution',150);
savefig(fig,fullfile(folder,'attitude_tracking.fig'));
if ~results.config.show_figures, close(fig); end
fig=figure('Visible',visible,'Color','w','Position',[80,80,1200,800]);
tiledlayout(3,1);
for panel=1:3
    nexttile; hold on;
    for k=1:numel(methods)
        log=results.logs.(methods(k));
        if panel==1
            values=log.common_residual;
            label='Common residual (rad/s^2)';
        elseif panel==2
            values=1e3*log.solve_time_s;
            label='Solve time (ms, log scale)';
        else
            values=max(abs(rad2deg(log.command_rad)),[],2);
            label='Max candidate (deg)';
        end
        plot(t,values,'Color',colors(k,:));
    end
    if panel==2, set(gca,'YScale','log'); end
    grid on; ylabel(label);
end
xlabel('Time (s)'); legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
exportgraphics(fig,fullfile(folder,'allocation_diagnostics.png'),'Resolution',150);
savefig(fig,fullfile(folder,'allocation_diagnostics.fig'));
if ~results.config.show_figures, close(fig); end
first=results.logs.(methods(1));
if isfield(first,'plant_model') && first.plant_model=="shc09_6dof"
    fig=figure('Visible',visible,'Color','w','Position',[80,80,1200,900]);
    tiledlayout(3,2);
    labels={'N position (m)','E position (m)','D position (m)','Airspeed (m/s)','Exit speed (m/s)','Motor (rad/s)'};
    for panel=1:6
        nexttile; hold on;
        for k=1:numel(methods)
            log=results.logs.(methods(k));
            if panel<=3, values=log.position_ned_m(:,panel);
            elseif panel==4, values=vecnorm(log.airspeed_body_m_s,2,2);
            elseif panel==5, values=log.exit_speed_m_s;
            else, values=log.motor_rad_s; end
            plot(t,values,'Color',colors(k,:));
        end
        grid on; ylabel(labels{panel}); xlabel('Time (s)');
    end
    legend(cellstr(methods),'Interpreter','none','Location','eastoutside');
    exportgraphics(fig,fullfile(folder,'physical_states.png'),'Resolution',150);
    savefig(fig,fullfile(folder,'physical_states.fig'));
    if ~results.config.show_figures, close(fig); end
end
end
