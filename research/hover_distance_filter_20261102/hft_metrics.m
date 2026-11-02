function m=hft_metrics(L,cfg,model,ref,plan,seed,h1,h2)
% 只读评估滚转0.5Hz补偿残差；外扰真值只进入离线指标，不能进入控制器。
m=hdf_metrics(L,ref,plan,seed);m.h1_hz=h1;m.h2_hz=h2;
q=L.control_updated&L.time_s>=10&L.time_s<22;t=L.time_s(q);assert(numel(t)==4800);
torque=interp1(cfg.disturbance_series.time_s,cfg.disturbance_series.torque_nm,t);
equivalent=(model.inertia\torque')';residual=L.v_h(q,:)+equivalent;
carrier=exp(-1i*2*pi*.5*t);coefficient=2/numel(t)*(carrier.'*residual);
reference=2/numel(t)*(carrier.'*equivalent);amplitude=abs(coefficient);denominator=abs(reference);
m.residual_roll_ratio=amplitude(1)/denominator(1);m.residual_vector_ratio=norm(amplitude)/norm(denominator);
m.residual_roll_amplitude_rad_s2=amplitude(1);m.residual_pitch_amplitude_rad_s2=amplitude(2);m.residual_yaw_amplitude_rad_s2=amplitude(3);
m.disturbance_roll_amplitude_rad_s2=denominator(1);m.residual_roll_real=real(coefficient(1));m.residual_roll_imag=imag(coefficient(1));
% 用常数项加正余弦最小二乘独立核对投影归一化，排除把半幅写成全幅的错误。
fit=[ones(numel(t),1),cos(2*pi*.5*t),sin(2*pi*.5*t)]\residual;
fit_amplitude=hypot(fit(2,:),fit(3,:));m.fourier_crosscheck_error=max(abs(fit_amplitude-amplitude));assert(m.fourier_crosscheck_error<1e-10);
command=rad2deg(L.command(q,:));spectrum=fft(command);frequency=(0:numel(t)-1)'*400/numel(t);
keep=min(frequency,400-frequency)>=20;spectrum(~keep,:)=0;high=real(ifft(spectrum));
m.command_hf_rms_deg=sqrt(mean(high.^2,'all'));m.command_hf_cutoff_hz=20;
end
