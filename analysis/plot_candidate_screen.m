function plot_candidate_screen(folder)
% 对全部预定候选统一重绘，不删去没有优势或数值失败的方法。
s=load(fullfile(folder,'summary.mat'),'summary'); summary=s.summary;
for name=reshape(string(summary.options.cases),1,[])
    case_folder=fullfile(folder,name); d=load(fullfile(case_folder,'comparison.mat'),'results'); r=d.results;
    methods=r.config.methods; methods=methods(arrayfun(@(m)isfield(r.logs,m),methods)); colors=lines(numel(methods));
    t=r.reference.time_s; fig=figure('Visible','off','Color','w','Position',[60,60,1250,800]); layout=tiledlayout(2,2);
    nexttile; hold on;
    for k=1:numel(methods)
        log=r.logs.(methods(k)); ids=1:8:numel(t);
        plot(log.position_ned_m(ids,2),log.position_ned_m(ids,1),'Color',colors(k,:),'LineWidth',1.1);
    end
    plot(r.reference.position_ned_m(:,2),r.reference.position_ned_m(:,1),'k--','HandleVisibility','off');
    axis equal; grid on; xlabel('E position (m)'); ylabel('N position (m)');
    legend(cellstr(methods),'Interpreter','none','Location','best');
    for panel=2:4
        nexttile; hold on;
        for k=1:numel(methods)
            log=r.logs.(methods(k)); times=t;
            if panel==2
                values=rad2deg(log.euler_rad(:,3)); label='Yaw error (deg)';
            elseif panel==3
                values=vecnorm(log.position_ned_m-r.reference.position_ned_m,2,2); label='Position error norm (m)';
            else
                values=sqrt(mean(diff(rad2deg(log.pwm_command_rad)).^2,2)); times=log.pwm_update_time_s(2:end);
                label='Applied command step RMS across fins (deg)';
            end
            ids=extremes(values); plot(times(ids),values(ids),'Color',colors(k,:),'LineWidth',1.1);
        end
        xline(r.protocol.task_window_s(1),'k:','HandleVisibility','off');
        xline(r.protocol.task_window_s(2),'k:','HandleVisibility','off');
        grid on; xlabel('Time (s)'); ylabel(label);
    end
    title(layout,sprintf('%s: same controller and plant; WLS uses equal normalized axis weights',name),'Interpreter','none');
    drawnow; exportgraphics(fig,fullfile(case_folder,'candidate_response.png'),'Resolution',160);
    savefig(fig,fullfile(case_folder,'candidate_response.fig')); close(fig);
end
data=summary.metrics(string(summary.metrics.window)=="task",:);
cases=string(summary.options.cases); methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
fig=figure('Visible','off','Color','w','Position',[60,60,1300,800]); layout=tiledlayout(2,2);
fields=["yaw_rmse_deg","position_rmse_m","command_step_rms_deg","pwm_saturation_percent"];
ylabels=["Yaw RMSE (deg)","Position vector RMSE (m)","PWM command step RMS (deg)","PWM command at limit (%)"];
for panel=1:4
    values=NaN(numel(cases),numel(methods));
    for i=1:numel(cases)
        for j=1:numel(methods)
            row=data(string(data.scenario)==cases(i) & string(data.method)==methods(j),:);
            if height(row)==1, values(i,j)=row.(fields(panel)); end
        end
    end
    nexttile;
    if numel(cases)==1
        bar(values(1,:)); xticks(1:numel(methods)); xticklabels(methods);
    else
        bar(values); xticks(1:numel(cases)); xticklabels(cases);
    end
    set(gca,'TickLabelInterpreter','none'); ylabel(ylabels(panel)); grid on;
    if panel==1 && numel(cases)>1, legend(cellstr(methods),'Interpreter','none','Location','best'); end
end
title(layout,'All predeclared candidates: task-window metrics, single paired seed');
drawnow; exportgraphics(fig,fullfile(folder,'candidate_summary.png'),'Resolution',160);
savefig(fig,fullfile(folder,'candidate_summary.fig')); close(fig);
end
function ids=extremes(values)
% 分块保留极值仅用于显示，所有指标和原始日志使用完整采样。
n=numel(values); width=max(1,ceil(n/1000)); ids=zeros(0,1);
for first=1:width:n
    last=min(n,first+width-1); [~,lo]=min(values(first:last)); [~,hi]=max(values(first:last));
    ids=[ids;first;last;first+lo-1;first+hi-1]; %#ok<AGROW>
end
ids=unique(ids);
end
