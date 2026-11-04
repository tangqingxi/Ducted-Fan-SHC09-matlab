base='E:\Ducted-Fan-SHC09-matlab'; cd(base); r5=fullfile(base,'results','round5_changeB_20261104'); r6=fullfile(base,'results','round6_changeB_20261104'); rows={}; data=struct();
for cond=["A","F","B"]
 if cond=="B", d=load(fullfile(r5,sprintf('B_s501.mat')),'L','ref'); else, d=load(fullfile(r6,sprintf('%s_s501.mat',cond)),'L','ref'); end
 L=d.L; ref=d.ref; t=L.time_s; trueH=vecnorm(L.position(:,1:2)-ref.position_ned_m(:,1:2),2,2);
 estH=vecnorm(L.estimated_position-L.position,2,2); percH=vecnorm(L.estimated_position-ref.position_ned_m,2,2);
 data.(char(cond))=struct('t',t,'trueH',trueH,'estH',estH,'percH',percH);
 for k=1:40:numel(t)
  rows{end+1}=table(cond,t(k),trueH(k),estH(k),percH(k),'VariableNames',{'condition','time_s','true_h_m','ecl_vs_true_h_m','perceived_h_m'});
 end
end
writetable(vertcat(rows{:}),fullfile(r6,'round6_curves_seed501.csv'));
figure('Visible','off'); plot(data.A.t,data.A.trueH,'k-',data.F.t,data.F.trueH,'m--',data.B.t,data.B.trueH,'b:','LineWidth',1.1); xlabel('time / s'); ylabel('true horizontal error / m'); legend('A original','F frozen slow','B no slow'); grid on; title('Seed 501: initial bias vs dynamic slow'); saveas(gcf,fullfile(r6,'round6_true_error_s501.png'));
figure('Visible','off'); plot(data.A.t,data.A.estH,'k-',data.F.t,data.F.estH,'m--',data.B.t,data.B.estH,'b:','LineWidth',1.1); xlabel('time / s'); ylabel('ECL vs true horizontal error / m'); legend('A original','F frozen slow','B no slow'); grid on; title('Seed 501: ECL estimation error'); saveas(gcf,fullfile(r6,'round6_ecl_error_s501.png'));
fprintf('ROUND6_CURVES_DONE\n');
