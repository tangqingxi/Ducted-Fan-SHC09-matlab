base='E:\Ducted-Fan-SHC09-matlab'; cd(base); ca_setup;
for p=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103","research/hover_distance_takeoff_formal_20261103"], addpath(fullfile(base,p)); end
for mode=["A","B","C"]
 setenv('ECL_TIME_MODE',char(mode));
 [cfg,model,ref,plan,spec]=hdtf_config(501); N=numel(ref.time_s); n=find(ref.time_s<=12,1,'last');
 for f=reshape(fieldnames(ref),1,[])
  v=ref.(f{1});
  if ismatrix(v)&&~isvector(v)&&size(v,1)==N, ref.(f{1})=v(1:n,:);
  elseif ndims(v)==3&&size(v,3)==N, ref.(f{1})=v(:,:,1:n);
  elseif isvector(v)&&numel(v)==N, ref.(f{1})=v(1:n);
  end
 end
 experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
 L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
 save(fullfile(base,'results','audit_changeB_20261104',sprintf('ecl_abc_%s.mat',mode)),'L','ref','cfg','model','plan','spec');
 [~,k]=min(abs(L.time_s-12)); fprintf('MODE %s final true=%s est=%s err=%s\n',mode,mat2str(L.position(k,:),4),mat2str(L.estimated_position(k,:),4),mat2str(L.position(k,:)-L.estimated_position(k,:),4));
end
