base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup; addpath(fullfile(base,'results'));
for p=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103","research/hover_distance_takeoff_formal_20261103"], addpath(fullfile(base,p)); end
out=fullfile(base,'results','round6_changeB_20261104'); if ~isfolder(out), mkdir(out); end
seeds=[501 502 503]; conds=["A","F"]; rows={};
for seed=seeds
 [cfg,model,ref55,plan,spec]=hdtf_config(seed);
 [exp,comp]=round5_components(cfg,ref55,plan);
 check=ppid_noise(cfg,ref55,plan);
 assert(norm(comp.total_m-check.navigation.gnss_position_m,'fro')<1e-12,'component mismatch');
 N=numel(ref55.time_s); n=round(12*cfg.sample_hz); ref=ref55; f=fieldnames(ref);
 for k=1:numel(f)
  v=ref.(f{k});
  if ismatrix(v)&&~isvector(v)&&size(v,1)==N, ref.(f{k})=v(1:n,:);
  elseif ndims(v)==3&&size(v,3)==N, ref.(f{k})=v(:,:,1:n);
  elseif isvector(v)&&numel(v)==N, ref.(f{k})=v(1:n);
  end
 end
 warm=comp.warmup_samples; slow0=comp.slow_m(warm+1,:);
 for cond=conds
  e=exp;
  if cond=="F"
   e.navigation.gnss_position_m=comp.total_m;
   for idx=warm+1:size(e.navigation.gnss_position_m,1)
    e.navigation.gnss_position_m(idx,:)=slow0+comp.white_m(idx,:);
   end
  end
  L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",e,plan);
  save(fullfile(out,sprintf('%s_s%d.mat',cond,seed)),'L','ref','cfg','model','plan','spec','comp','cond','seed','slow0','-v7');
  t=L.time_s; q=t>=0&t<12;
  trueErr=L.position-ref.position_ned_m; trueH=vecnorm(trueErr(:,1:2),2,2);
  estErr=L.estimated_position-L.position; estH=vecnorm(estErr(:,1:2),2,2);
  percErr=L.estimated_position-ref.position_ned_m; percH=vecnorm(percErr(:,1:2),2,2);
  idx=find(L.gnss_fresh & q); ci=warm+idx;
  gnssH=vecnorm(L.gnss_position(idx,1:2)-L.position(idx,1:2),2,2);
  slowH=vecnorm(comp.slow_m(ci,1:2),2,2); whiteH=vecnorm(comp.white_m(ci,1:2),2,2);
  rows{end+1}=table(seed,cond,sqrt(mean(trueH(q).^2)),max(trueH(q)),trueH(find(q,1,'last')), ...
    sqrt(mean(estH(q).^2)),sqrt(mean(percH(q).^2)),sqrt(mean(gnssH.^2)),mean(slowH),mean(whiteH), ...
    'VariableNames',{'seed','condition','true_h_rmse_m','true_h_peak_m','true_h_final_m', ...
    'ecl_vs_true_h_rmse_m','perceived_tracking_h_rmse_m','gnss_h_rmse_m','slow_h_mean_m','white_h_mean_m'});
  fprintf('ROUND6 seed=%d cond=%s true_rmse=%.4f true_final=%.4f true_peak=%.4f ecl_err=%.4f perc=%.4f gnss=%.4f\n', ...
    seed,cond,rows{end}.true_h_rmse_m,rows{end}.true_h_final_m,rows{end}.true_h_peak_m, ...
    rows{end}.ecl_vs_true_h_rmse_m,rows{end}.perceived_tracking_h_rmse_m,rows{end}.gnss_h_rmse_m);
  clear L
 end
 clear exp comp check
end
writetable(vertcat(rows{:}),fullfile(out,'round6_summary_A_F.csv'));
fprintf('ROUND6_DONE %s\n',out);
