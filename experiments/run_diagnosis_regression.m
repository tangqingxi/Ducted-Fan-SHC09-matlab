function varargout = run_diagnosis_regression(varargin)
% 保留历史调用入口；实现作为Stage6A证据按需加载，不加入默认运行路径。
root=fileparts(fileparts(mfilename('fullpath')));folder=fullfile(root,'docs','evidence','stage6a');
already=any(strcmp(strsplit(path,pathsep),folder));
if ~already,addpath(folder);cleanup=onCleanup(@()rmpath(folder));end %#ok<NASGU>
[varargout{1:nargout}]=stage6a_run_diagnosis_regression(varargin{:});
end
