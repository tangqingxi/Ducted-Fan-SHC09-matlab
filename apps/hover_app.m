function results = hover_app(flag,overrides)
% 面向读者的两秒悬停入口，覆盖项仍由公共配置校验。
ca_setup();if nargin<1,flag=5;end
preset=shc09_airframe();
if nargin>=2,for name=reshape(string(fieldnames(overrides)),1,[]),preset.(name)=overrides.(name);end,end
results=main(flag,preset);
end
