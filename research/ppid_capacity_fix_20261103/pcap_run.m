function result=pcap_run(stage)
% 容量补丁专用回归入口；不调用正式批、不覆盖任何旧实验或锁。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
addpath(fullfile(root,'research','hover_distance_takeoff_20261103'));
out=fullfile(root,'results','ppid_capacity_fix_20261103_r1');assert(isfolder(out));
stage=string(stage);assert(ismember(stage,["before40","after40","after50","after55"]));
path=fullfile(out,stage+".mat");assert(~isfile(path),'拒绝覆盖已有回归。');
target=fullfile(root,'research','ppid_pindi','ppid_simulate.m');source=read_bytes(target);
source_sha=allocation_comparison_hash(source,true);
if stage=="before40"
    before=jsondecode(fileread(fullfile(out,'lock_audit_before.json')));assert(source_sha==string(before.old_sha256));
    [cfg,model,ref,plan,spec]=hd_config(501,.85,280);
    plan.controller.indi_output_filter_hz=15;plan.controller.indi_input_filter_hz=15;
    experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
    signature=allocation_comparison_hash({cfg,model,ref,plan,experiment});
    save(fullfile(out,'input40.mat'),'cfg','model','ref','plan','spec','experiment','signature','-v7');
elseif stage=="after40"
    d=load(fullfile(out,'input40.mat'));cfg=d.cfg;model=d.model;ref=d.ref;plan=d.plan;spec=d.spec;experiment=d.experiment;signature=d.signature;
elseif stage=="after50"
    d=load(fullfile(root,'results','hover_distance_takeoff_precheck_20261103_r1','inputs','seed501.mat'));
    cfg=d.cfg;model=d.model;ref=d.ref;plan=d.plan;spec=d.spec;experiment=d.experiment;signature=d.signature;
else
    [cfg,model,~,plan,spec]=hdt_config();
    cfg.duration_s=55;cfg.disturbance_end_s=55;
    time=(0:round(55*cfg.sample_hz)+1)'/cfg.sample_hz;
    torque=zeros(numel(time),3);old=cfg.disturbance_series;torque(1:numel(old.time_s),:)=old.torque_nm;
    cfg.disturbance_series=struct('time_s',time,'torque_nm',torque);
    plan.takeoff.duration_s=55;plan.hover_distance.duration_s=55;
    spec.duration_s=55;spec.takeoff.duration_s=55;spec.expected_pwm_events=55*cfg.pwm_hz+1;
    spec.pwm_buffer_capacity=ceil(55*cfg.pwm_hz)+2;
    ref=hdt_reference(plan.takeoff,cfg.sample_hz);cfg=ca_validate_config(cfg);
    experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
    signature=allocation_comparison_hash({cfg,model,ref,plan,experiment});
    save(fullfile(out,'input55.mat'),'cfg','model','ref','plan','spec','experiment','signature','-v7');
end
if stage~="before40"
    patch=jsondecode(fileread(fullfile(out,'patch_record.json')));assert(source_sha==string(patch.new_sha256));
end
input_signature=allocation_comparison_hash({cfg,model,ref,plan,experiment});
fprintf('CAPACITY_RUN %s duration=%.3f input=%s source=%s\n',stage,ref.time_s(end),input_signature,source_sha);
% 每个阶段只有这一次对象仿真调用；失败写记录后返回原错误，不自动重试。
try
    L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
    save(path,'L','cfg','model','ref','plan','spec','signature','input_signature','source_sha','-v7');
catch problem
    write_json(fullfile(out,stage+"_failure.json"),struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
    rethrow(problem);
end
assert(all(read_bytes(target)==source),'运行中源码变化。');
result=pcap_check_saved(stage);
end

function value=read_bytes(path)
% 仅用于来源核验，不参与仿真数值。
fid=fopen(path,'rb');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
value=fread(fid,Inf,'*uint8');
end

function write_json(path,value)
% 每一阶段的证据写全新文件。
assert(~isfile(path));fid=fopen(path,'w','n','UTF-8');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
