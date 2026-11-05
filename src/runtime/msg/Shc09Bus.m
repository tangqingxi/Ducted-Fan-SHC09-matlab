classdef Shc09Bus < handle
    % 单线程最新样本总线；同一时刻允许覆盖，禁止单topic时间倒退。
    properties (Access=private)
        payloads
        times
        versions
        sequence=uint64(0)
        recorder=[]
    end
    methods
        function obj=Shc09Bus()
            obj.payloads=containers.Map('KeyType','char','ValueType','any');
            obj.times=containers.Map('KeyType','char','ValueType','double');
            obj.versions=containers.Map('KeyType','char','ValueType','any');
        end
        function publish(obj,name,payload,time_s)
            name=char(string(name));
            assert(isscalar(time_s) && isfinite(time_s),'shc09:BusTime','时间戳须为有限标量。');
            assert(~obj.exists(name) || time_s>=obj.times(name),'shc09:BusOrder','topic时间倒退。');
            obj.sequence=obj.sequence+uint64(1);obj.payloads(name)=payload;
            obj.times(name)=time_s;obj.versions(name)=obj.sequence;
            if ~isempty(obj.recorder),obj.recorder.record(name,payload,time_s,obj.sequence);end
        end
        function [payload,time_s,sequence]=latest(obj,name)
            name=char(string(name));assert(obj.exists(name),'shc09:MissingTopic','topic尚未发布：%s',name);
            payload=obj.payloads(name);time_s=obj.times(name);sequence=obj.versions(name);
        end
        function [payload,time_s,sequence]=subscribe(obj,name)
            [payload,time_s,sequence]=obj.latest(name);
        end
        function value=timestamp(obj,name)
            [~,value]=obj.latest(name);
        end
        function value=exists(obj,name)
            value=isKey(obj.payloads,char(string(name)));
        end
        function attach_logger(obj,logger)
            obj.recorder=logger;
        end
    end
end
