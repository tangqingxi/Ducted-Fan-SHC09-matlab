function results = main_disturbance_monte_carlo(overrides)
% 每次完整轨迹运行贡献一个RMSE样本，默认3次仅用于小规模预演。
ca_setup();
if nargin<1, overrides=struct(); end
results=run_disturbance_benchmark(overrides);
end
