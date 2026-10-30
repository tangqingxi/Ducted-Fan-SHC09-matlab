classdef CaPx4Ecl < handle
    % 通过标准管道调用未改动的官方EKF核心，接口只包含传感器输入与估计输出。
    properties
        process
        writer
        reader
        magnetic_ned_gauss
        stderr_path
        closed=false
    end
    methods
        function obj=CaPx4Ecl(cfg)
            root=ca_setup(); executable=fullfile(root,'build','px4_ecl','px4_ecl_bridge.exe');
            assert(isfile(executable),'官方ECL桥接程序未构建，请先运行构建脚本。');
            arguments=java.util.ArrayList(); arguments.add(java.lang.String(executable));
            builder=java.lang.ProcessBuilder(arguments);
            obj.stderr_path=[tempname(fullfile(root,'build','px4_ecl')),'.stderr.txt'];
            builder.redirectError(java.io.File(obj.stderr_path));
            obj.process=builder.start();
            obj.writer=java.io.PrintWriter(obj.process.getOutputStream(),true);
            obj.reader=java.io.BufferedReader(java.io.InputStreamReader(obj.process.getInputStream()));
            values=[cfg.navigation_origin(:)',1000*[cfg.gnss_delay_s,cfg.barometer_delay_s,cfg.magnetometer_delay_s], ...
                max(cfg.gnss_position_std_m(1:2)),cfg.gnss_position_std_m(3),cfg.gnss_velocity_std_m_s];
            obj.magnetic_ned_gauss=obj.exchange(['INIT ',sprintf('%.17g ',values)],'B ');
            assert(numel(obj.magnetic_ned_gauss)==3,'官方磁场接口返回长度错误。');
        end
        function values=step(obj,packet)
            values=obj.exchange(['STEP ',sprintf('%.17g ',packet)],'R ');
            assert(numel(values)==26,'官方EKF输出长度错误。');
        end
        function values=exchange(obj,command,prefix)
            obj.writer.println(command);
            while true
                raw=obj.reader.readLine();
                assert(~isempty(raw),'官方EKF进程意外退出，错误日志：%s',obj.stderr_path);
                line=char(raw);
                if startsWith(line,'ERROR'), error('ca:EkfBridgeProtocol','官方EKF接口错误：%s',line); end
                if startsWith(line,prefix), values=sscanf(line(numel(prefix)+1:end),'%f'); return; end
            end
        end
        function close(obj)
            if obj.closed, return; end
            obj.closed=true;
            if ~isempty(obj.writer), obj.writer.println('CLOSE'); obj.writer.close(); end
            if ~isempty(obj.reader), obj.reader.close(); end
            if ~isempty(obj.process), obj.process.destroy(); end
        end
        function delete(obj)
            obj.close();
        end
    end
end
