function study = mismatch_app(overrides)
% 默认仅运行两秒M0/M2b配对烟雾，不启动三十次正式阶梯。
ca_setup();options=struct('duration_s',2,'case_ids',["M0","M2b"],'fail_fast',true);
if nargin>=1,for name=reshape(string(fieldnames(overrides)),1,[]),options.(name)=overrides.(name);end,end
study=main_mismatch_ladder(options);
end
