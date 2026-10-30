function y = Constrain(x, lower_limit, upper_limit)
% Constrain 标量限幅函数

    y = min(max(x, lower_limit), upper_limit);

end

