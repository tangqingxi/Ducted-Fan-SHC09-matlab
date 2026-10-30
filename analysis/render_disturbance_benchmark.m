function [summary,figures] = render_disturbance_benchmark(results,cfg,out,show_figures)
% 仅读取结果表绘图；每次完整运行一个RMSE样本，保留全部有限大误差并另报失败数。
if nargin<4, show_figures=false; end
assert(isscalar(show_figures) && ismember(show_figures,[false,true]),'图窗显示开关须为逻辑标量。');
visible='off';
if show_figures, visible='on'; end
figures=gobjects(numel(cfg.scenarios),1);
figure_index=0;
figdir=fullfile(out,'figures');
if ~isfolder(figdir), mkdir(figdir); end
rows={};
if ismember('aero_extrapolated_samples',results.Properties.VariableNames)
    validity=results(:,{'scenario','level','method','status','aero_extrapolated_samples'});
    writetable(validity,fullfile(out,'aero_validity.csv'),'Encoding','UTF-8');
end
methods=reshape(string(cfg.methods),1,[]);
levels=string({cfg.levels.name});
for scenario=reshape(string(cfg.scenarios),1,[])
    selected=string(results.scenario)==scenario;
    success=selected & string(results.status)=="completed" & isfinite(results.rotation_rmse_deg);
    failures=zeros(numel(levels),numel(methods));
    for level=1:numel(levels)
        for method=1:numel(methods)
            group=selected & string(results.level)==levels(level) & string(results.method)==methods(method);
            valid=group & success;
            values=results.rotation_rmse_deg(valid);
            failures(level,method)=sum(group & string(results.status)=="failed");
            stats=NaN(1,4);
            if ~isempty(values), stats=[mean(values),median(values),min(values),max(values)]; end
            rows(end+1,:)={char(scenario),char(levels(level)),char(methods(method)), ...
                sum(group),sum(valid),failures(level,method),stats(1),stats(2),stats(3),stats(4)}; %#ok<AGROW>
        end
    end
    fig=figure('Visible',visible,'Color','w','Position',[80,80,1200,800], ...
        'Name',char("随机扰动对比："+scenario),'NumberTitle','off');
    figure_index=figure_index+1;
    figures(figure_index)=fig;
    layout=tiledlayout(2,1,'Padding','loose');
    nexttile;
    if any(success)
        x=categorical(string(results.level(success)),levels,levels);
        groups=categorical(string(results.method(success)),methods,methods);
        boxchart(x,results.rotation_rmse_deg(success),'GroupByColor',groups);
        legend('Location','eastoutside','Interpreter','none');
    else
        text(0.5,0.5,'No completed trials','HorizontalAlignment','center');
    end
    grid on; ylabel('Attitude error RMS (deg)');
    title('One complete run = one sample; all finite RMSE values retained');
    nexttile;
    hold on;
    bars=gobjects(numel(methods),1);
    colors=lines(numel(methods));
    width=0.8/numel(methods);
    % 显式建立各方法的柱对象，避免单等级时矩阵退化成一个图例对象。
    for method=1:numel(methods)
        positions=(1:numel(levels))+(method-(numel(methods)+1)/2)*width;
        bars(method)=bar(positions,failures(:,method),width,'FaceColor',colors(method,:));
    end
    grid on;
    xticks(1:numel(levels)); xticklabels(levels);
    ylim([0,max(1,max(failures,[],'all')+1)]);
    yticks(0:max(1,max(failures,[],'all')+1));
    if all(failures==0,'all')
        text((numel(levels)+1)/2,0.5,sprintf('No failed trials (%d completed)',sum(success)), ...
            'HorizontalAlignment','center');
    end
    ylabel('Failed trials'); xlabel('Random moment RMS level');
    legend(bars,cellstr(methods),'Location','eastoutside','Interpreter','none');
    title(layout,sprintf('Scenario: %s; repeats per method/level: %d',scenario,cfg.num_repeats),'Interpreter','none');
    exportgraphics(fig,fullfile(figdir,char(scenario)+".png"),'Resolution',160);
    savefig(fig,fullfile(figdir,char(scenario)+".fig"));
    if show_figures, drawnow; else, close(fig); end
end
summary=cell2table(rows,'VariableNames',{'scenario','level','method','trial_count','completed_count', ...
    'failed_count','mean_rmse_deg','median_rmse_deg','min_rmse_deg','max_rmse_deg'});
writetable(summary,fullfile(out,'summary.csv'),'Encoding','UTF-8');
end
