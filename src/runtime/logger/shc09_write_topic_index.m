function shc09_write_topic_index(history,folder)
% 额外导出topic目录；完整结构载荷随旧log.mat保存，不改旧CSV列。
names=fieldnames(history);rows=cell(numel(names),5);
for k=1:numel(names)
    topic=history.(names{k});rows(k,:)={names{k},numel(topic.time_s),topic.time_s(1),topic.time_s(end),"log.mat:log.topic_log"};
end
index=cell2table(rows,'VariableNames',{'topic','sample_count','first_time_s','last_time_s','payload_location'});
writetable(index,fullfile(folder,'topics.csv'),'Encoding','UTF-8');
end
