function [cfg,model,ref,plan,spec]=ppid_gnss_v2_config(seed,scenario)
% 复用冻结配置加载链，仅在新协议中覆盖三轴共同的相关时间。
root=ca_setup();
for rel=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103","research/hover_distance_takeoff_formal_20261103"]
    addpath(fullfile(root,rel));
end
version_path=fullfile(fileparts(mfilename('fullpath')),'protocol.json');
version=jsondecode(fileread(version_path));
base_path=fullfile(root,'research','ppid_pindi','protocol.json');
fid=fopen(base_path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
assert(strcmp(allocation_comparison_hash(bytes,true),version.base_protocol_sha256), ...
    'gnssv2:BaseChanged','父协议字节与新版本引用不一致，禁止静默继承变更。');
switch string(scenario)
    case "f8"
        [cfg,model,ref,plan]=ppid_config(seed);spec=struct();
    case "takeoff55"
        [cfg,model,ref,plan,spec]=hdtf_config(seed);
    otherwise
        error('gnssv2:Scenario','仅支持显式选择f8或takeoff55场景。');
end
g=version.gnss;
assert(isequal(cfg.gnss_position_std_m(:),g.total_axis_sigma_m(:)));
assert(isequal(plan.sensors.gnss_white_axis_sigma_m(:),g.white_axis_sigma_m(:)));
assert(cfg.gnss_velocity_std_m_s==g.velocity_sigma_m_s&&cfg.gnss_hz==g.update_hz&&cfg.gnss_delay_s==g.delay_s);
assert(isscalar(g.correlation_s)&&isfinite(g.correlation_s)&&g.correlation_s==1000);
parent_sensors=plan.sensors;
plan.sensors.gnss_correlation_s=g.correlation_s;
plan.sensors.assumptions=strrep(plan.sensors.assumptions,'GNSS 60s correlation','GNSS 1000s correlation under versioned engineering model');
assert(isequaln(rmfield(parent_sensors,{'gnss_correlation_s','assumptions'}), ...
    rmfield(plan.sensors,{'gnss_correlation_s','assumptions'})),'gnssv2:AmplitudeChanged','除相关时间外的传感器参数发生变化。');
plan.gnss_model=struct('id',version.id,'protocol_path','research/ppid_pindi/gnss_v2/protocol.json', ...
    'base_protocol_sha256',version.base_protocol_sha256,'physical_correlation_s',g.correlation_s);
fprintf('GNSS_MODEL_SELECTED %s tau=%.0fs dt=%.8fs rate=%.0fHz delay=%.3fs\n', ...
    version.id,g.correlation_s,1/cfg.sample_hz,cfg.gnss_hz,cfg.gnss_delay_s);
end
