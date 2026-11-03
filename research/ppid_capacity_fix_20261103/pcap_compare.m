function report=pcap_compare(which)
% 比较双精度原始字节，包含NaN载荷与正负零，计时和统计元数据单独报告。
root=ca_setup();out=fullfile(root,'results','ppid_capacity_fix_20261103_r1');which=string(which);
if which=="40",old=fullfile(out,'before40.mat');new=fullfile(out,'after40.mat');
elseif which=="50",old=fullfile(root,'results','hover_distance_takeoff_precheck_20261103_r1','logs','PCA_PREDICTIVE_s501.mat');new=fullfile(out,'after50.mat');
else,error('只比较40或50秒。');end
a=load(old,'L');b=load(new,'L');a=a.L;b=b.L;
excluded={"solve_time_s","elapsed_s","ekf_rate_hz"};names=intersect(fieldnames(a),fieldnames(b),'stable');rows=struct([]);
for k=1:numel(names)
    name=names{k};x=a.(name);y=b.(name);
    if any(string(name)==string(excluded))||~(isnumeric(x)||islogical(x)),continue;end
    assert(isequal(size(x),size(y))&&strcmp(class(x),class(y)),name);
    if islogical(x),xb=uint8(x(:));yb=uint8(y(:));else,xb=typecast(x(:),'uint8');yb=typecast(y(:),'uint8');end
    finite=isfinite(x)&isfinite(y);difference=max([0;abs(double(x(finite))-double(y(finite)))]);
    row=struct('field',string(name),'class',string(class(x)),'elements',numel(x),'bitwise_equal',isequal(xb,yb), ...
        'max_absolute_difference',difference,'before_sha256',allocation_comparison_hash(xb,true),'after_sha256',allocation_comparison_hash(yb,true));
    rows=[rows;row]; %#ok<AGROW>
end
required=["position","omega","v_h","lambda","pwm_command"];
assert(all(ismember(required,[rows.field]))&&all([rows.bitwise_equal]),'物理或决策字段出现字节差异，停止验收。');
assert(isequaln(a.update_counts,b.update_counts));
report=struct('duration_s',str2double(which),'baseline',old,'current',new,'all_bitwise_identical',true,'fields_verified',numel(rows), ...
    'required_fields',required,'rows',rows,'excluded_timing_and_metadata',string(excluded), ...
    'old_ekf_rate_hz',a.ekf_rate_hz,'new_ekf_rate_hz',b.ekf_rate_hz,'counts_identical',true);
path=fullfile(out,"comparison"+which+".json");assert(~isfile(path));fid=fopen(path,'w','n','UTF-8');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('CAPACITY_BITWISE_%s PASS fields=%d required=5\n',which,numel(rows));
end
