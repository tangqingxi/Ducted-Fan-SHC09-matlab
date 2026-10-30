function build_px4_ecl_bridge()
% 使用项目构建脚本和已固定版本的依赖生成官方EKF独立程序。
root=ca_setup(); script=fullfile(root,'tools','build_px4_ecl.py');
[status,message]=system(['python "',script,'"']);
assert(status==0,'官方ECL桥接构建失败：%s',message); fprintf('%s',message);
end
