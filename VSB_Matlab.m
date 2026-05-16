% ============================================================
% Mo phong dieu che VSB voi bo loc FIR bac 48
% Tin hieu vao: 4 tone 300 Hz, 500 Hz, 700 Hz, 900 Hz
% Song mang: 10 kHz
% Tan so lay mau: 48 kHz
% Bo loc FIR: he so export tu MATLAB Filter Designer
% ============================================================

clc;
close all;

%% 1. Khai bao thong so tin hieu

f1 = 300;
f2 = 500;
f3 = 700;
f4 = 900;

fc = 10000;      % tan so song mang
fs = 48000;      % tan so lay mau

Ac = 1;          % bien do song mang
A1 = 1;
A2 = 1;
A3 = 1;
A4 = 1;

%% 2. Tao truc thoi gian

% t = 0:1/fs:0.05;     % cach nay tao 2401 mau
% N = length(t);

Tsim = 0.05;
t = 0:1/fs:Tsim-1/fs;    % tao dung 2400 mau
N = length(t);           % so mau tin hieu
t_ms = t*1000;           % doi sang ms de ve do thi

%% 3. Tao tin hieu tin tuc gom 4 tone

x1 = A1*cos(2*pi*f1*t);
x2 = A2*cos(2*pi*f2*t);
x3 = A3*cos(2*pi*f3*t);
x4 = A4*cos(2*pi*f4*t);

% Tin hieu tin tuc tong hop
x = x1 + x2 + x3 + x4;

%% 4. Tao song mang

xc = Ac*cos(2*pi*fc*t);

%% 5. Dieu che DSB-SC

% Nhan tung mau tin hieu tin tuc voi song mang
xdsb = x .* xc;

%% 6. Tao truc tan so de ve FFT

f = (-floor(N/2):ceil(N/2)-1) * (fs/N);

% df = fs/N;                         % buoc tan so cua FFT
% k = -floor(N/2):ceil(N/2)-1;       % chi so tan so sau fftshift
% f = k*df;                          % truc tan so theo Hz
%% 7a. Tinh pho tin hieu ngo vao

X = fft(x);
X_shift = fftshift(X);
%% 7b. Tinh pho DSB

Xdsb = fft(xdsb);
Xdsb_shift = fftshift(Xdsb);

%% 8. Lay he so bo loc FIR

BP = bandpassfir1_Num(:).';

%% 9. Loc DSB de tao VSB

% Vi bo loc bac 48 co 49 he so nen tre nhom la:
% delay = (49 - 1)/2 = 24 mau
filter_delay = (length(BP)-1)/2;

% Tich chap tin hieu DSB voi bo loc FIR
xvsb_full = conv(xdsb, BP);

% Cat bo phan qua do dau tien va dua do dai ve bang tin hieu goc
start_index = filter_delay + 1;
end_index   = start_index + N - 1;

xvsb = xvsb_full(start_index:end_index);

%% 10. Tinh pho VSB

Xvsb = fft(xvsb);
Xvsb_shift = fftshift(Xvsb);

%% 11. Ve dap ung tan so cua bo loc FIR moi

figure;
freqz(BP, 1, 2048, fs);
title('Dap ung tan so cua bo loc FIR');

%% 12. Ve tin hieu ngo vao

figure;
plot(t_ms, x);
title('Dang song ngo vao');
xlabel('Thoi gian (ms)');
ylabel('Amplitude (V)');
ylim([-4 4]);
grid on;
%% 12a. Ve pho tan so cua tin hieu ngo vao

figure;
plot(f, abs(X_shift)/N, 'LineWidth', 1.2);
title('Pho tan so cua tin hieu ngo vao');
xlabel('Frequency (Hz)');
ylabel('|X(f)|');
xlim([0 2000]);
xticks([0 300 500 700 900 1200 1500 2000]);
grid on;

xline(300, '--', '300 Hz');
xline(500, '--', '500 Hz');
xline(700, '--', '700 Hz');
xline(900, '--', '900 Hz');

%% 13. Ve tin hieu DSB trong mien thoi gian

figure;
plot(t_ms, xdsb);
title('Dang song khi dieu che DSB-SC');
xlabel('Thoi gian (ms)');
ylabel('Amplitude');
xlim([0 450/fs*1000]);   % giu dung vung 450 mau nhu code cu
grid on;

%% 14. Ve pho tan so DSB

figure;
plot(f, abs(Xdsb_shift)/N);
title('Pho tan so DSB-SC');
xlabel('Frequency (Hz)');
ylabel('|X_{DSB}(f)|');
xlim([0 12000]);
grid on;

%% 15. Ve tin hieu VSB trong mien thoi gian

figure;
plot(t_ms, xvsb);
title('Dang song khi dieu che VSB');
xlabel('Thoi gian (ms)');
ylabel('Amplitude');
xlim([0 450/fs*1000]);   % giu dung vung 450 mau nhu code cu
grid on;

%% 16. Ve pho tan so VSB

figure;
plot(f, abs(Xvsb_shift)/N);
title('Pho tan so VSB');
xlabel('Frequency (Hz)');
ylabel('|X_{VSB}(f)|');
xlim([0 12000]);
grid on;
%% 17. Giai dieu che VSB bang tach song dong bo

% Nhan tin hieu VSB voi song mang noi bo cung tan so va cung pha
% He so 2 dung de bu lai he so 1/2 sinh ra khi nhan cos*cos
lo = 2*cos(2*pi*fc*t);

xmix = xvsb .* lo;

%% 18. Thiet ke bo loc thong thap de lay lai tin hieu tin tuc

% Tin hieu goc co 4 tone: 300, 500, 700, 900 Hz
% Chon tan so cat LPF lon hon 900 Hz, vi du 1500 Hz
lpf_order = 96;
fcut = 1500;                         % Hz
LP = fir1(lpf_order, fcut/(fs/2), 'low');

% Tre nhom cua bo loc FIR thong thap
lpf_delay = (length(LP)-1)/2;

% Loc thong thap
xdemod_full = conv(xmix, LP);

% Cat bo tre de dua ve dung N mau nhu tin hieu goc
start_index_lpf = lpf_delay + 1;
end_index_lpf   = start_index_lpf + N - 1;

xdemod_raw = xdemod_full(start_index_lpf:end_index_lpf);
%% Ve dap ung tan so hai phia cua bo loc thong thap LPF

[Hlp_whole, Flp_whole] = freqz(LP, 1, 4096, 'whole', fs);

% Dua truc tan so ve dang -fs/2 den fs/2
Hlp_shift = fftshift(Hlp_whole);
Flp_shift = Flp_whole - fs/2;

figure;
plot(Flp_shift, 20*log10(abs(Hlp_shift) + eps), 'LineWidth', 1.2);
grid on;

title('Dap ung bien do hai phia cua bo loc thong thap FIR');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');

xlim([-5000 5000]);
ylim([-100 5]);


%% 19. Chuan hoa bien do de so sanh voi tin hieu goc

% Do bo loc VSB co the lam suy hao bien do, ta chuan hoa gain sau tach song
K = (x * xdemod_raw.') / (xdemod_raw * xdemod_raw.');
xdemod = K * xdemod_raw;

%% 20. Tinh pho tin hieu sau giai dieu che

Xdemod = fft(xdemod);
Xdemod_shift = fftshift(Xdemod);

%% 21. Ve tin hieu sau giai dieu che

figure;
plot(t_ms, x, 'LineWidth', 1.2);
hold on;
plot(t_ms, xdemod, '--', 'LineWidth', 1.2);
title('So sanh tin hieu goc va tin hieu sau giai dieu che VSB');
xlabel('Thoi gian (ms)');
ylabel('Amplitude');
legend('Tin hieu goc x(t)', 'Tin hieu sau giai dieu che');
xlim([0 20]);
ylim([-4.5 4.5]);
grid on;

%% 22. Ve pho tin hieu sau giai dieu che

figure;
plot(f, abs(Xdemod_shift)/N);
title('Pho tan so sau giai dieu che VSB');
xlabel('Frequency (Hz)');
ylabel('|X_{demod}(f)|');
xlim([0 2000]);
grid on;
