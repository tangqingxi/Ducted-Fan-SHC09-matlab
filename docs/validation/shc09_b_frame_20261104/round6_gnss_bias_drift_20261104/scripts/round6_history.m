base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup; addpath(fullfile(base,'results')); addpath(fullfile(base,'research','ppid_pindi'));
dir=fullfile(base,'results','hover_distance_takeoff_formal_changeB_20261104_r1','logs');
out=fullfile(base,'results','round6_changeB_20261104'); if ~isfolder(out), mkdir(out); end
rows={}; maxrows={};
for seed=[501 502 503]
 d=load(fullfile(dir,sprintf('PCA_PREDICTIVE_s%d.mat',seed))); L=d.L; ref=d.ref; cfg=d.cfg; plan=d.plan;
 [~,comp]=round5_components(cfg,ref,plan); n=numel(L.time_s); warm=comp.warmup_samples;
 trueErr=L.position-ref.position_ned_m; trueH=vecnorm(trueErr(:,1:2),2,2);
 estErr=L.estimated_position-L.position; estH=vecnorm(estErr(:,1:2),2,2);
 percErr=L.estimated_position-ref.position_ned_m; percH=vecnorm(percErr(:,1:2),2,2);
 cc=warm+(1:n)'; slow=comp.slow_m(cc,1:2); white=comp.white_m(cc,1:2); slow0=comp.slow_m(warm+1,1:2); dslow=slow-slow0;
 idx=find(L.gnss_fresh); gidx=warm+idx; gnssH=vecnorm(comp.total_m(gidx,1:2),2,2);
 [mx,im]=max(trueH);
 ct=dot(trueErr(im,1:2),dslow(im,:))/(norm(trueErr(im,1:2))*norm(dslow(im,:)));
 ce=dot(estErr(im,1:2),dslow(im,:))/(norm(estErr(im,1:2))*norm(dslow(im,:)));
 maxrows{end+1}=table(seed,L.time_s(im),mx,estH(im),percH(im),norm(slow(im,:)),norm(dslow(im,:)), ...
  trueErr(im,1),trueErr(im,2),estErr(im,1),estErr(im,2),dslow(im,1),dslow(im,2),ct,ce, ...
  'VariableNames',{'seed','t_max_s','true_h_max_m','ecl_vs_true_h_at_max_m','perceived_h_at_max_m','slow_norm_at_max_m','dslow_norm_at_max_m', ...
  'true_err_n_at_max','true_err_e_at_max','ecl_err_n_at_max','ecl_err_e_at_max','dslow_n_at_max','dslow_e_at_max','cos_true_dslow','cos_ecl_dslow'});
 for w=[15 27;27 37;37 55]'
  q=L.time_s>=w(1)&L.time_s<w(2); qf=L.gnss_fresh&L.time_s>=w(1)&L.time_s<w(2);
  rows{end+1}=table(seed,w(1),w(2),sqrt(mean(trueH(q).^2)),max(trueH(q)),trueH(find(q,1,'last')), ...
   sqrt(mean(estH(q).^2)),sqrt(mean(percH(q).^2)),sqrt(mean(gnssH(L.time_s(idx)>=w(1)&L.time_s(idx)<w(2)).^2)), ...
   mean(vecnorm(dslow(q,:),2,2)),max(vecnorm(dslow(q,:),2,2)), ...
   'VariableNames',{'seed','window_start_s','window_end_s','true_h_rmse_m','true_h_peak_m','true_h_end_m', ...
   'ecl_vs_true_h_rmse_m','perceived_h_rmse_m','gnss_noise_h_rmse_m','dslow_h_mean_m','dslow_h_max_m'});
 end
 q=L.time_s>=15; rn=corrcoef(dslow(q,1),estErr(q,1)); re=corrcoef(dslow(q,2),estErr(q,2));
 fprintf('HIST seed=%d max=%.3f at %.2f; corr_dslowN=%.3f dslowE=%.3f; end trueH=%.3f\n',seed,mx,L.time_s(im),rn(1,2),re(1,2),trueH(end));
 if seed==501
  T=table(L.time_s,trueH,estH,percH,slow(:,1),slow(:,2),dslow(:,1),dslow(:,2), ...
   'VariableNames',{'time_s','true_h_m','ecl_vs_true_h_m','perceived_h_m','slow_n','slow_e','dslow_n','dslow_e'});
  writetable(T,fullfile(out,'round6_historical_series_s501.csv'));
  figure('Visible','off'); plot(L.time_s,trueH,'k-',L.time_s,estH,'r--',L.time_s,percH,'b:','LineWidth',1.1); xlabel('time / s'); ylabel('horizontal / m'); legend('true error','ECL vs true','perceived'); grid on; title('Formal 55 s seed501'); saveas(gcf,fullfile(out,'round6_historical_s501.png'));
  figure('Visible','off'); plot(L.time_s,dslow(:,1),'m-',L.time_s,estErr(:,1),'k-',L.time_s,dslow(:,2),'c--',L.time_s,estErr(:,2),'b--'); xlabel('time / s'); ylabel('m'); legend('dSlow N','ECL err N','dSlow E','ECL err E'); grid on; title('Formal 55 s slow change vs ECL error'); saveas(gcf,fullfile(out,'round6_historical_slow_ecl_s501.png'));
 end
end
writetable(vertcat(rows{:}),fullfile(out,'round6_historical_windows.csv'));
writetable(vertcat(maxrows{:}),fullfile(out,'round6_historical_max.csv'));
fprintf('ROUND6_HIST_DONE\n');
