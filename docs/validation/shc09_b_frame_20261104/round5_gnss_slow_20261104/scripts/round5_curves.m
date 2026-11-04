base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup; out=fullfile(base,'results','round5_changeB_20261104');
rows={}; data=struct();
for cond=["A","B","C"]
 d=load(fullfile(out,sprintf('%s_s501.mat',cond)),'L','ref','comp'); L=d.L; ref=d.ref; comp=d.comp;
 t=L.time_s; n=numel(t); trueH=vecnorm(L.position(:,1:2)-ref.position_ned_m(:,1:2),2,2);
 estH=vecnorm(L.estimated_position-L.position,2,2); percH=vecnorm(L.estimated_position-ref.position_ned_m,2,2);
 idx=find(L.gnss_fresh); ci=comp.warmup_samples+idx; gnssH=nan(size(t)); slowH=nan(size(t)); whiteH=nan(size(t));
 cc=comp.warmup_samples+(1:n)';
 gnssH(idx)=vecnorm(L.gnss_position(idx,1:2)-L.position(idx,1:2),2,2);
 slowH=vecnorm(comp.slow_m(cc,1:2),2,2); whiteH=vecnorm(comp.white_m(cc,1:2),2,2);
 data.(char(cond))=struct('t',t,'trueH',trueH,'estH',estH,'percH',percH,'gnssH',gnssH,'slowH',slowH,'whiteH',whiteH);
 for k=1:40:n
  rows{end+1}=table(cond,t(k),trueH(k),estH(k),percH(k),gnssH(k),slowH(k),whiteH(k), ...
   'VariableNames',{'condition','time_s','true_h_m','ecl_vs_true_h_m','perceived_h_m','gnss_h_m','slow_h_m','white_h_m'});
 end
end
writetable(vertcat(rows{:}),fullfile(out,'round5_curves_seed501.csv'));
figure('Visible','off'); plot(data.A.t,data.A.trueH,'k-',data.B.t,data.B.trueH,'b--',data.C.t,data.C.trueH,'g:','LineWidth',1.2); xlabel('time / s'); ylabel('true horizontal error / m'); legend('A formal','B no slow','C no GNSS pos'); grid on; title('Seed 501 true horizontal error'); saveas(gcf,fullfile(out,'round5_true_error_s501.png'));
figure('Visible','off'); plot(data.A.t,data.A.estH,'k-',data.B.t,data.B.estH,'b--',data.C.t,data.C.estH,'g:','LineWidth',1.2); xlabel('time / s'); ylabel('ECL vs true horizontal error / m'); legend('A formal','B no slow','C no GNSS pos'); grid on; title('Seed 501 ECL estimation error'); saveas(gcf,fullfile(out,'round5_ecl_error_s501.png'));
figure('Visible','off'); plot(data.A.t,data.A.percH,'k-',data.B.t,data.B.percH,'b--','LineWidth',1.2); xlabel('time / s'); ylabel('perceived horizontal tracking error / m'); legend('A formal','B no slow'); grid on; title('Seed 501 controller perceived error'); saveas(gcf,fullfile(out,'round5_perceived_error_s501.png'));
figure('Visible','off'); plot(data.A.t,data.A.slowH,'m-',data.A.t,data.A.estH,'k-','LineWidth',1.2); xlabel('time / s'); ylabel('m'); legend('GNSS slow component','ECL vs true'); grid on; title('Seed 501 slow error vs ECL estimation error'); saveas(gcf,fullfile(out,'round5_slow_vs_ecl_s501.png'));
fprintf('ROUND5_CURVES_DONE\n');
