clear; close all; clc;

%% 1. RADAR-BASED "CLEAN" SIGNAL (Pulsed LFM echo) & PARAMETERS
% Goal: keep the adaptive filter study unchanged, but make the "clean chirp"
%       come from a simple radar echo model (Tx LFM -> delay -> Doppler).
%
% Radar echo model (monostatic, single target):
%   s_rx(t) = A * s_tx(t - tau) * exp(j 2*pi*fD*t)
%   tau = 2R/c,  fD = 2v/lambda,  lambda = c/fc
%
% References:
% - Klauder et al., "The Theory and Design of Chirp Radars", BSTJ, 1960.
% - Widrow et al., "Adaptive Noise Cancelling: Principles and Applications", Proc. IEEE, 1975.

% --- Sampling / observation window (chosen to make tau resolvable) ---
fs         = 2e6;              % Sampling frequency (Hz)
Tobs       = 2.5e-3;           % Observation duration (s)
t          = (0:1/fs:Tobs-1/fs)';  % Time vector (N×1)

% --- LFM pulse (IF/baseband-equivalent) ---
B          = 200e3;            % Chirp bandwidth (Hz)
Tpulse     = 2e-3;             % Chirp pulse duration (s)
S          = B/Tpulse;         % Chirp slope (Hz/s)
f0_if      = 0;                % Start frequency in this IF-equivalent sim (Hz)

% --- Radar physical parameters (for tau & Doppler) ---
c          = 299792458;        % Speed of light (m/s)
fc         = 2.4e9;            % Carrier frequency (Hz) for Doppler mapping
lambda_c   = c/fc;

R_true     = 30e3;             % Target range (m)
v_true     = 30;               % Target radial speed (m/s)
tau        = 2*R_true/c;       % Round-trip delay (s)
fD         = 2*v_true/lambda_c;% Doppler frequency (Hz)

A_echo     = 1.0;              % Lumped echo amplitude (pathloss+RCS simplified)

% --- Adaptive filter params (unchanged in spirit) ---
M          = 32;               % Filter order (# taps)
mu_lms     = 0.001;            % Step-size for LMS
sigma      = 1.5;              % Std. dev. of white Gaussian noise (added AFTER radar echo)

%% 2. RLS PARAMS
% 2.1 Standalone RLS (for comparison if desired)
lambda_rls  = 0.995;           % Forgetting factor
delta_rls   = 1;               % Regularization (P(0) = I/δ)

% 2.2 Cascade RLS (only used in the LMS→RLS cascade)
lambda_cas  = 0.9995;          % Larger forgetting factor (slow RLS updates)
delta_cas   = 100;             % Large δ so initial P2 is small → small gains
gamma_thresh= 0.05;            % Threshold on |e1(n)| to allow RLS updates

%% 3. GENERATE SIGNALS (Radar echo replaces direct MATLAB chirp)
% 3.1 Transmit LFM pulse (complex IF/baseband-equivalent)
% s_tx(t) = exp(j*2*pi*(f0*t + 0.5*S*t^2)) for 0<=t<=Tpulse, else 0
gate_tx = double(t <= Tpulse);
s_tx_c  = exp(1j*2*pi*(f0_if*t + 0.5*S*t.^2)) .* gate_tx;

% 3.2 Received "clean" radar echo: delayed + Doppler
t_shift  = t - tau;
s_tx_del = interp1(t, s_tx_c, t_shift, 'linear', 0);      % fractional delay
s_rx_c   = A_echo * s_tx_del .* exp(1j*2*pi*fD*t);         % Doppler
s        = real(s_rx_c);                                   % waveform "clean" echo (real)

% 3.3 Add colored noise exactly like the original script
% NOTE: only the noise generator is changed to COLORED noise (AR(1)).
a_col   = 0.90;                         % AR(1) pole (0=white, closer to 1 => more colored)
w0      = sigma * randn(size(t));       % underlying white Gaussian
v_white = filter(1, [1 -a_col], w0);    % colored Gaussian noise
v_white = v_white * (sigma / max(std(v_white), 1e-12));  % normalize std ~ sigma
d       = s + v_white;                  % Primary = radar echo + colored noise
x       = v_white;                      % Reference = same noise (oracle reference, same as original)

N = length(t);

% Print a small radar summary (optional, helps thesis revision)
fprintf('==== Radar Echo Parameters (used to generate clean signal) ====');
fprintf('fc = %.3f GHz, B = %.1f kHz, Tpulse = %.3f ms, S = %.3e Hz/s', fc/1e9, B/1e3, Tpulse*1e3, S);
fprintf('R = %.1f m, v = %.1f m/s => tau = %.3e s, fD = %.2f Hz', R_true, v_true, tau, fD);
fprintf('Approx range resolution ΔR ≈ c/(2B) = %.2f m', c/(2*B));

%% 3.6 RADAR VISUALIZATION PLOTS (makes the radar "visible")
% Requested figures:
%   (A) Waveform Tx vs echo (delay visible)
%   (B) Matched filter output (range profile)

% (A1) Tx and echo magnitude (envelope) so delay tau is obvious
figure('Name','Radar: Tx vs Echo Envelope','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
hold on;
plot(t*1e3, abs(s_tx_c), 'LineWidth',1.6, 'DisplayName','|Tx LFM|');
plot(t*1e3, abs(s_rx_c), 'LineWidth',1.6, 'DisplayName','|Echo|');
xline(0,   '--', 'Color',[0.8 0.8 0.8], 'LineWidth',1.2, 'DisplayName','Tx start');
xline(tau*1e3, '--', 'Color',[0.8 0.8 0.8], 'LineWidth',1.2, 'DisplayName','Echo start (tau)');
xlim([0, (tau + Tpulse + 0.3e-3)*1e3]);
xlabel('Time (ms)','FontSize',13,'Color','w');
ylabel('Magnitude','FontSize',13,'Color','w');
title('Tx vs Echo Envelope (Echo delayed by tau = 2R/c)','FontSize',14,'Color','w');
legend('Location','southoutside','Orientation','horizontal','TextColor','w','EdgeColor','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_tx_vs_echo_envelope_colored.png');

% (A2) Tx vs echo real part (zoomed) to show waveform shift
figure('Name','Radar: Tx vs Echo (Real, Zoom)','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
hold on;
plot(t*1e3, real(s_tx_c), 'LineWidth',1.0, 'DisplayName','Tx (real)');
plot(t*1e3, s,            'LineWidth',1.0, 'DisplayName','Echo (real)');
xlim([0, (tau + 0.6e-3)*1e3]);
xlabel('Time (ms)','FontSize',13,'Color','w');
ylabel('Amplitude','FontSize',13,'Color','w');
title('Tx vs Echo (Real Part, Zoom near delay tau)','FontSize',14,'Color','w');
legend('Location','southoutside','Orientation','horizontal','TextColor','w','EdgeColor','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_tx_vs_echo_real_zoom_colored.png');

% (B) Matched filter (pulse compression) range profile: clean vs noisy
% Matched filter via cross-correlation with the known transmit waveform.
v_c_mf = (sigma/sqrt(2))*(randn(size(t)) + 1j*randn(size(t)));
rx_noisy_c_mf = s_rx_c + v_c_mf;
[mf_clean, lags] = xcorr(s_rx_c, s_tx_c);          % clean matched filter output
[mf_noisy, ~]    = xcorr(rx_noisy_c_mf, s_tx_c);   % noisy matched filter output

range_axis = (lags/fs) * (c/2);   % meters
sel = (range_axis >= 0) & (range_axis <= 2*R_true);

mf_clean_mag = abs(mf_clean(sel));
mf_noisy_mag = abs(mf_noisy(sel));

% Normalize (visual comparison)
mf_clean_mag = mf_clean_mag / max(mf_clean_mag + 1e-12);
mf_noisy_mag = mf_noisy_mag / max(mf_noisy_mag + 1e-12);

figure('Name','Radar: Matched Filter Range Profile (Clean vs Noisy)','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
hold on;
plot(range_axis(sel), mf_clean_mag, 'LineWidth',1.8, 'DisplayName','Matched filter (clean)');
plot(range_axis(sel), mf_noisy_mag, 'LineWidth',1.2, 'DisplayName','Matched filter (noisy)');
xlabel('Range (m)','FontSize',13,'Color','w');
ylabel('Normalized |MF output|','FontSize',13,'Color','w');
title('Pulse Compression: Matched Filter Range Profile','FontSize',14,'Color','w');
legend('Location','southoutside','Orientation','horizontal','TextColor','w','EdgeColor','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_range_profile_clean_vs_noisy_colored.png');


%% 4. PREALLOCATE STORAGE
% 4.1 Standalone LMS
w_LMS   = zeros(M,1);
y_LMS   = zeros(N,1);
e_LMS   = zeros(N,1);

% 4.2 Standalone RLS (not used in final summary but included)
w_RLS    = zeros(M,1);
P_RLS    = (1/delta_rls)*eye(M);
y_RLS    = zeros(N,1);
e_RLS    = zeros(N,1);

% 4.3 Improved Cascade: LMS → RLS
w1_cas   = zeros(M,1);                % LMS front-end weights
y1_cas   = zeros(N,1);                % LMS output
e1_cas   = zeros(N,1);                % LMS residual
w2_cas   = zeros(M,1);                % RLS weights in cascade
P2_cas   = (1/delta_cas)*eye(M);       % RLS covariance in cascade
y2_cas   = zeros(N,1);                % RLS output (stage 2)
e2_cas   = zeros(N,1);                % Final cascade error

% 4.4 Parallel Mixture: LMS + RLS side-by-side
w1_par   = zeros(M,1);          
y1_par   = zeros(N,1);
e1_par   = zeros(N,1);

w2_par   = zeros(M,1);
P2_par   = (1/delta_rls)*eye(M);  
y2_par   = zeros(N,1);
e2_par   = zeros(N,1);

alpha    = zeros(N,1);       % Mixing coefficient α(n)
y_par    = zeros(N,1);       % Final mixed output
e_par    = zeros(N,1);       % Final mixed error

%% 5. ADAPTIVE FILTERING LOOP (n = M:N)
for n = M:N
    %---------- Build reference vector x_vec = [ x(n), x(n-1), ..., x(n-M+1) ] ----------
    x_vec = x(n:-1:n-M+1);  % M×1 column
    
    %---------- 5.1 Standalone LMS ----------
    y_LMS(n) = w_LMS' * x_vec;
    e_LMS(n) = d(n) - y_LMS(n);
    w_LMS    = w_LMS + mu_lms * e_LMS(n) * x_vec;
    
    %---------- 5.2 Standalone RLS (for completeness) ----------
    y_RLS(n) = w_RLS' * x_vec;
    e_RLS(n) = d(n) - y_RLS(n);
    Pi_RLS   = P_RLS * x_vec;
    k_RLS    = Pi_RLS / (lambda_rls + x_vec' * Pi_RLS);
    w_RLS    = w_RLS + k_RLS * e_RLS(n);
    P_RLS    = (P_RLS - k_RLS * Pi_RLS') / lambda_rls;
    
    %---------- 5.3 Improved Cascade: LMS → RLS (thresholded) ----------
    % Stage 1: LMS
    y1_cas(n) = w1_cas' * x_vec;
    e1_cas(n) = d(n) - y1_cas(n);
    w1_cas    = w1_cas + mu_lms * e1_cas(n) * x_vec;
    
    % Stage 2: RLS only if |e1_cas(n)| > gamma_thresh
    y2_cas(n) = w2_cas' * x_vec;
    e2_cas(n) = e1_cas(n) - y2_cas(n);
    if abs(e1_cas(n)) > gamma_thresh
        Pi2    = P2_cas * x_vec;
        k2     = Pi2 / (lambda_cas + x_vec' * Pi2);
        w2_cas = w2_cas + k2 * e2_cas(n);
        P2_cas = (P2_cas - k2 * Pi2') / lambda_cas;
    end
    % If |e1_cas(n)| <= gamma_thresh, skip RLS update to avoid overfitting
    
    %---------- 5.4 Parallel Mixture: LMS + RLS in parallel ----------
    % 5.4.1 LMS branch
    y1_par(n) = w1_par' * x_vec;
    e1_par(n) = d(n) - y1_par(n);
    w1_par    = w1_par + mu_lms * e1_par(n) * x_vec;
    
    % 5.4.2 RLS branch
    y2_par(n) = w2_par' * x_vec;
    e2_par(n) = d(n) - y2_par(n);
    Pi_par    = P2_par * x_vec;
    k_par     = Pi_par / (lambda_rls + x_vec' * Pi_par);
    w2_par    = w2_par + k_par * e2_par(n);
    P2_par    = (P2_par - k_par * Pi_par') / lambda_rls;
    
    % 5.4.3 Adaptive mixing coefficient α(n)
    errL2 = e1_par(n)^2;
    errR2 = e2_par(n)^2;
    alpha(n) = errR2 / (errL2 + errR2 + 1e-8);
    
    % 5.4.4 Final mixed output
    y_par(n) = alpha(n)*y1_par(n) + (1-alpha(n))*y2_par(n);
    e_par(n) = d(n) - y_par(n);
end



%% 5.5 RADAR POST-PROCESSING PLOTS (Range profile after denoising + Doppler spectrum)
% This section connects the adaptive denoising outputs to standard radar processing:
%   (C) Matched filter range profile (raw vs denoised)
%   (D) (Multi-pulse) Doppler spectrum at the target range bin

% (C) Range profile comparison: raw vs denoised outputs
% Use real-valued matched filtering consistent with the adaptive-filter outputs.
tx_real = real(s_tx_c);

[mf_raw_r, lags_r] = xcorr(d, tx_real);
[mf_lms_r, ~]      = xcorr(e_LMS, tx_real);
[mf_cas_r, ~]      = xcorr(e2_cas, tx_real);
[mf_par_r, ~]      = xcorr(e_par, tx_real);

range_axis_r = (lags_r/fs) * (c/2);
sel_r = (range_axis_r >= 0) & (range_axis_r <= 2*R_true);

mf_raw_mag = abs(mf_raw_r(sel_r));
mf_lms_mag = abs(mf_lms_r(sel_r));
mf_cas_mag = abs(mf_cas_r(sel_r));
mf_par_mag = abs(mf_par_r(sel_r));

% Normalize each curve to its own peak (shape comparison)
mf_raw_mag = mf_raw_mag / max(mf_raw_mag + 1e-12);
mf_lms_mag = mf_lms_mag / max(mf_lms_mag + 1e-12);
mf_cas_mag = mf_cas_mag / max(mf_cas_mag + 1e-12);
mf_par_mag = mf_par_mag / max(mf_par_mag + 1e-12);

figure('Name','Radar: Range Profile (Raw vs Denoised Outputs)','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
hold on;
plot(range_axis_r(sel_r), mf_raw_mag, 'LineWidth',1.2, 'DisplayName','Raw (noisy)');
plot(range_axis_r(sel_r), mf_lms_mag, 'LineWidth',1.6, 'DisplayName','LMS output');
plot(range_axis_r(sel_r), mf_cas_mag, 'LineWidth',1.6, 'DisplayName','Cascade output');
plot(range_axis_r(sel_r), mf_par_mag, 'LineWidth',1.6, 'DisplayName','Parallel output');
xlabel('Range (m)','FontSize',13,'Color','w');
ylabel('Normalized |MF output|','FontSize',13,'Color','w');
title('Matched Filter Range Profile: Raw vs Denoised','FontSize',14,'Color','w');
legend('Location','southoutside','Orientation','horizontal','TextColor','w','EdgeColor','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_range_profile_raw_vs_denoised_colored.png');

% (D) Multi-pulse Doppler spectrum at target range bin
% Generate a pulse train (separate from the adaptive-filter experiment) just for Doppler visualization.
Npulses = 32;  % increase to 64 if you want a cleaner Doppler spectrum
PRI     = 2e-3;               % 2 ms → PRF 500 Hz (gives clear pulse separation)
PRF     = 1/PRI;

NsPRI   = round(PRI*fs);
NsPulse = round(Tpulse*fs);
Tframe  = Npulses*PRI;
t_frame = (0:1/fs:Tframe-1/fs)';

% Tx pulse train
s_tx_frame = zeros(size(t_frame));
for k = 0:(Npulses-1)
    t0  = k*PRI;
    idx = (t_frame >= t0) & (t_frame < t0 + Tpulse);
    tt  = t_frame(idx) - t0;
    s_tx_frame(idx) = exp(1j*2*pi*(f0_if*tt + 0.5*S*tt.^2));
end

% Echo pulse train (delay + Doppler)
t_shift_f   = t_frame - tau;
s_tx_del_f  = interp1(t_frame, s_tx_frame, t_shift_f, 'linear', 0);
s_rx_frame  = A_echo * s_tx_del_f .* exp(1j*2*pi*fD*t_frame);

% Add noise (match this script's noise type)
noise_frame = (sigma/sqrt(2))*(randn(size(t_frame)) + 1j*randn(size(t_frame)));
rx_frame = s_rx_frame + noise_frame;

% Reshape into pulses (fast-time × slow-time)
rx_frame = rx_frame(1:NsPRI*Npulses);
rx_mat   = reshape(rx_frame, NsPRI, Npulses);

% Matched filter template for one pulse
n_p   = (0:NsPulse-1)';
t_p   = n_p/fs;
tx_tpl = exp(1j*2*pi*(f0_if*t_p + 0.5*S*t_p.^2));
h_mf   = conj(flipud(tx_tpl));

Lout   = NsPRI + NsPulse - 1;
mf_mat = zeros(Lout, Npulses);

% Fast matched filtering using FFT convolution (much faster than conv in a loop)
Lfft = 2^nextpow2(Lout);
Hmf  = fft(h_mf, Lfft);
for p = 1:Npulses
    Xp = fft(rx_mat(:,p), Lfft);
    yp = ifft(Xp .* Hmf);
    mf_mat(:,p) = yp(1:Lout);
end
% Range axis for matched filter output
lag_samp = (0:Lout-1)' - (NsPulse-1);
tau_ax   = lag_samp / fs;
R_ax     = tau_ax * (c/2);

% Choose target range bin: use expected delay if valid; otherwise use global peak
idx_exp = round(tau*fs) + (NsPulse-1) + 1;  % +1 for MATLAB indexing
idx_exp = max(1, min(Lout, idx_exp));

% Quick sanity: if expected bin is very weak, fall back to average peak
avg_prof = mean(abs(mf_mat), 2);
[~, idx_pk] = max(avg_prof);
if avg_prof(idx_exp) < 0.5*avg_prof(idx_pk)
    idx_rb = idx_pk;
else
    idx_rb = idx_exp;
end

% Doppler FFT at the chosen range bin
z_slow = mf_mat(idx_rb, :).';
w     = hann(Npulses);
Z     = fftshift(fft(z_slow .* w, Npulses));
fd_ax = (-Npulses/2:Npulses/2-1).' * (PRF/Npulses);
v_ax  = fd_ax * (lambda_c/2);

figure('Name','Radar: Doppler Spectrum at Target Range Bin','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
plot(v_ax, 20*log10(abs(Z)/max(abs(Z)+1e-12)), 'LineWidth',1.8);
xlabel('Radial velocity (m/s)','FontSize',13,'Color','w');
ylabel('Normalized magnitude (dB)','FontSize',13,'Color','w');
title('Doppler Spectrum (FFT across pulses at target range bin)','FontSize',14,'Color','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_doppler_spectrum_colored.png');

% Also show the averaged range profile over pulses (range profile looks like a standard radar output)
selR = (R_ax >= 0) & (R_ax <= 2*R_true);
figure('Name','Radar: Averaged Range Profile (Multi-pulse)','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);
set(gca, 'Color', [0.1 0.1 0.1], 'XColor','w','YColor','w', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
plot(R_ax(selR), avg_prof(selR)/max(avg_prof(selR)+1e-12), 'LineWidth',1.8);
xline(R_true, '--', 'Color',[0.8 0.8 0.8], 'LineWidth',1.2);
xlabel('Range (m)','FontSize',13,'Color','w');
ylabel('Normalized |MF output|','FontSize',13,'Color','w');
title('Averaged Matched Filter Output across pulses (Range Profile)','FontSize',14,'Color','w');
grid on;
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off');
print('-dpng','-r300', 'radar_range_profile_multipulse_colored.png');
%% 6. SNR & MSE COMPUTATIONS
% 6.1 SNR before any filtering
snr_before = 10*log10( var(s) / var(v_white) );

% 6.2 Standalone LMS
resid_LMS   = e_LMS - s;                      % residual noise estimate
snr_LMS     = 10*log10( var(s) / var(resid_LMS) );
avgMSE_LMS  = mean(e_LMS.^2);                 % average MSE over N

% 6.3 Improved Cascade (LMS→RLS thresholded)
resid_cas   = e2_cas - s;
snr_cas     = 10*log10( var(s) / var(resid_cas) );
avgMSE_cas  = mean(e2_cas.^2);

% 6.4 Parallel Mixture (LMS+RLS)
resid_par   = e_par - s;
snr_par     = 10*log10( var(s) / var(resid_par) );
avgMSE_par  = mean(e_par.^2);

% Print numeric results
fprintf('\n==== Numerical Performance Metrics ====\n');
fprintf('SNR before filtering:                     %.2f dB\n', snr_before);
fprintf('Standalone LMS       → SNR: %.2f dB, Avg. MSE: %.5f\n', snr_LMS,    avgMSE_LMS);
fprintf('Improved Cascade     → SNR: %.2f dB, Avg. MSE: %.5f\n', snr_cas,    avgMSE_cas);
fprintf('Parallel Mixture     → SNR: %.2f dB, Avg. MSE: %.5f\n\n', snr_par,    avgMSE_par);

%% 6.5 Bar‐plots for SNR and MSE comparison

% Compute baseline MSE (before filtering)
mse_before = mean((d - s).^2);

% Pack values into vectors
snr_vals = [ snr_before, snr_LMS, snr_cas,   snr_par   ];
mse_vals = [ mse_before, avgMSE_LMS, avgMSE_cas, avgMSE_par ];

labels   = {'Before','LMS','Cascade','Parallel'};

% --- SNR bar plot  ---
figure('Name','SNR Comparison','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ... 
         'XColor','w', 'YColor','w', ... 
         'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4); 
hold on;

b1 = bar(snr_vals, 'FaceColor','flat');
b1.CData = lines(4); 
xticks(1:4);
xticklabels(labels);

xlabel('Filter Type','FontSize',12,'Color','w');
ylabel('SNR (dB)','FontSize',12,'Color','w');
title('SNR Before & After Filtering','FontSize',14,'Color','w');

grid on;
set(gca,'FontSize',11);
set(gcf,'InvertHardcopy','off'); 
print('-dpng','-r300','compare_SNR_colored.png');

% --- MSE bar plot ---
figure('Name','MSE Comparison','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ... 
         'XColor','w', 'YColor','w', ... 
         'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.4);
hold on;

b2 = bar(mse_vals, 'FaceColor','flat');
b2.CData = lines(4);
xticks(1:4);
xticklabels(labels);

% === Label dengan satuan ===
xlabel('Filter Type','FontSize',12,'Color','w');
ylabel('Average MSE (Amplitude^2)','FontSize',12,'Color','w'); 

title('MSE Before & After Filtering','FontSize',14,'Color','w');

grid on; 
set(gca,'FontSize',11);
set(gcf,'InvertHardcopy','off');  
print('-dpng','-r300','compare_MSE_colored.png');

%% 7. PLOTS
% 7.1 Running MSE curves (moving‐average window = M)
mse_LMS_run     = movmean(e_LMS.^2,    M);
mse_cas_run     = movmean(e2_cas.^2,   M);
mse_par_run     = movmean(e_par.^2,    M);
colors = lines(3);

% 7.1 Running MSE curves
figure('Name','Running MSE: LMS vs Cascade vs Parallel','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    % background figure
set(gca, 'Color', [0.1 0.1 0.1], ...
         'XColor','w', 'YColor','w', ...
         'GridColor',[0.5 0.5 0.5], ...
         'GridAlpha',0.4);
hold on;

plot(t, mse_LMS_run, 'LineWidth',1.8, 'Color', colors(1,:), 'DisplayName','Standalone LMS');
plot(t, mse_cas_run, 'LineWidth',1.8, 'Color', colors(2,:), 'DisplayName','Improved Cascade');
plot(t, mse_par_run, 'LineWidth',1.8, 'Color', colors(3,:), 'DisplayName','Parallel Mixture');

hold off;
xlabel('Time (s)','FontSize',14,'Color','w');
ylabel('MSE (Amplitude^2)','FontSize',14,'Color','w');
title('Running MSE Comparison','FontSize',16,'Color','w');

legend('Location','northeast','FontSize',12,'TextColor','w','EdgeColor','w');
grid on; 
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off'); 
print('-dpng','-r300','running_mse_colored.png');

% 7.2 Standalone LMS waveform 
figure('Name','Standalone LMS Output','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ...
         'XColor','w', 'YColor','w', ...
         'GridColor',[0.5 0.5 0.5], ...
         'GridAlpha',0.4);
hold on;

plot(t, d,    'Color',[0.7 0.7 0.7],'LineWidth',1,'DisplayName','Noisy');
plot(t, e_LMS,'Color',colors(1,:),'LineWidth',1.5,'DisplayName','LMS Output');
plot(t, s,    '-','Color',colors(2,:),'LineWidth',1.5,'DisplayName','Clean');

hold off;
xlabel('Time (s)','FontSize',14,'Color','w'); 
ylabel('Amplitude','FontSize',14,'Color','w');
title('Standalone LMS vs. Noisy & Clean','FontSize',16,'Color','w');
legend('Location','southoutside','Orientation','horizontal','FontSize',12,'TextColor','w','EdgeColor','w');
grid on; 
set(gca,'FontSize',12);

set(gcf,'InvertHardcopy','off'); 
print('-dpng','-r300','lms_waveform_colored.png');

% 7.3 Improved Cascade waveform 
figure('Name','Cascade LMS→RLS Output','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ...
         'XColor','w', 'YColor','w', ...
         'GridColor',[0.5 0.5 0.5], ...
         'GridAlpha',0.4);
hold on;

plot(t, d,       'Color',[0.7 0.7 0.7],'LineWidth',1,'DisplayName','Noisy');
plot(t, e2_cas,  'Color',colors(3,:),'LineWidth',1.5,'DisplayName','Cascade Output');
plot(t, s,       '-','Color',colors(2,:),'LineWidth',1.5,'DisplayName','Clean');

hold off;
xlabel('Time (s)','FontSize',14,'Color','w'); 
ylabel('Amplitude','FontSize',14,'Color','w');
title('Improved Cascade (LMS → RLS)','FontSize',16,'Color','w');
legend('Location','southoutside','Orientation','horizontal','FontSize',12, ...
       'TextColor','w','EdgeColor','w');
grid on; 
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off'); 
print('-dpng','-r300','cascade_waveform_colored.png');

% 7.4 Parallel Mixture waveform
figure('Name','Parallel LMS+RLS Mixture Output','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ...
         'XColor','w', 'YColor','w', ...
         'GridColor',[0.5 0.5 0.5], ...
         'GridAlpha',0.4);
hold on;

plot(t, d,     'Color',[0.7 0.7 0.7],'LineWidth',1,'DisplayName','Noisy');
plot(t, e_par, 'Color',colors(1,:),'LineWidth',1.5,'DisplayName','Mixed Output');
plot(t, s,     '-','Color',colors(2,:),'LineWidth',1.5,'DisplayName','Clean');

hold off;
xlabel('Time (s)','FontSize',14,'Color','w'); 
ylabel('Amplitude','FontSize',14,'Color','w');
title('Parallel Mixture Output','FontSize',16,'Color','w');
legend('Location','southoutside','Orientation','horizontal','FontSize',12, ...
       'TextColor','w','EdgeColor','w');
grid on; 
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off'); 

print('-dpng','-r300','parallel_waveform_colored.png');

% 7.5 Adaptive Mixing Coefficient α(n)
figure('Name','Adaptive Mixing Coefficient \alpha(n)','NumberTitle','off');
set(gcf, 'Color', [0.1 0.1 0.1]);    
set(gca, 'Color', [0.1 0.1 0.1], ...
         'XColor','w', 'YColor','w', ...
         'GridColor',[0.5 0.5 0.5], ...
         'GridAlpha',0.4);
hold on;

plot(t, alpha, 'LineWidth',1.8,'Color',colors(2,:));

xlabel('Time (s)','FontSize',14,'Color','w'); 
ylabel('\alpha(n)','FontSize',14,'Color','w');
title('Adaptive Mixing Coefficient Over Time','FontSize',16,'Color','w');

grid on; 
set(gca,'FontSize',12);
set(gcf,'InvertHardcopy','off'); 

print('-dpng','-r300','mixing_coefficient_colored.png');
