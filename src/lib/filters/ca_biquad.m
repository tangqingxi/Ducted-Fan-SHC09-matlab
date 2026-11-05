function filter = ca_biquad(kind,frequency_hz,sample_hz,channels,bandwidth_hz)
% 按Meng论文式(133)使用普通Tustin变换，不额外预畸变截止频率。
if nargin<5, bandwidth_hz=0; end
w=2*pi*frequency_hz;
k=2*sample_hz;
if string(kind)=="lowpass"
    damping=1/sqrt(2);
    numerator=w^2*[1,2,1];
elseif string(kind)=="notch"
    damping=bandwidth_hz/(2*frequency_hz);
    numerator=[k^2+w^2,-2*k^2+2*w^2,k^2+w^2];
else
    error('未知二阶滤波器类型。');
end
denominator=[k^2+2*damping*w*k+w^2,-2*k^2+2*w^2,k^2-2*damping*w*k+w^2];
filter.b=numerator/denominator(1);
filter.a=denominator/denominator(1);
filter.state=zeros(2,channels);
end
