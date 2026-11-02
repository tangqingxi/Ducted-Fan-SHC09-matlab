function output=export_windtrace_flight(source,output,python_executable)
% 只读一次已保存飞行，转换MATLAB字符串后调用独立单飞行导出器；不运行仿真。
if nargin<3,python_executable=getenv('WINDTRACE_PYTHON');end
if isempty(python_executable),python_executable='python';end
assert(isfile(source)&&~isfile(output),'必须提供原始日志和全新的输出路径。');
root=fileparts(fileparts(mfilename('fullpath')));
available=who('-file',source);requested={'L','cfg','model','ref','plan','spec','signature','checks','metrics'};
data=load(source,requested{ismember(requested,available)});
data=ordinary(data);snapshot=[tempname,'.mat'];cleanup=onCleanup(@()remove_snapshot(snapshot)); %#ok<NASGU>
save(snapshot,'-struct','data','-v7');
% 参数均为独立的进程参数；拒绝引号与换行，避免命令行边界被破坏。
arguments={python_executable,fullfile(root,'tools','export_windtrace.py'),source,output,'--normalized-input',snapshot};
for k=1:numel(arguments)
    value=char(arguments{k});assert(~any(ismember(value,[char(34),char(10),char(13),char(37)])),'参数含不支持的命令行字符。');
    arguments{k}=['"',value,'"'];
end
[status,message]=system(strjoin(arguments,' '));assert(status==0,'WindTrace:Export','%s',message);disp(message);
end

function value=ordinary(value)
% 将保存的字符串与结构递归转为SciPy可完整读取的普通值，参数仍来自本次日志。
if isstring(value)
    if isscalar(value),value=char(value);else,value=cellstr(value);end
elseif isstruct(value)
    names=fieldnames(value);
    for j=1:numel(value),for k=1:numel(names),value(j).(names{k})=ordinary(value(j).(names{k}));end,end
elseif iscell(value)
    for k=1:numel(value),value{k}=ordinary(value{k});end
end
end

function remove_snapshot(path)
% 仅删除本函数创建的临时值快照，不触及原始日志。
if isfile(path),delete(path);end
end
