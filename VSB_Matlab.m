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

t = 0:1/fs:0.05;     % mo phong 0.05 giay
N = length(t);       % so mau tin hieu

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

%df = fs/N;                         % buoc tan so cua FFT
%k = -floor(N/2):ceil(N/2)-1;       % chi so tan so sau fftshift
%f = k*df;                          % truc tan so theo Hz

%% 7. Tinh pho DSB

Xdsb = fft(xdsb);
Xdsb_shift = fftshift(Xdsb);

%% 8. Lay he so bo loc FIR 
BP = bandpassfir1_Num(:).';

% Kiem tra so he so bo loc
fprintf('So he so FIR = %d\n', length(BP));
fprintf('Bac bo loc FIR = %d\n', length(BP)-1);

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
title('Dap ung tan so cua bo loc FIR moi');

%% 12. Ve tin hieu ngo vao

figure;
plot(x);
title('Dang song ngo vao');
xlabel('Discrete time n');
ylabel('Amplitude (V)');
ylim([-4 4]);
grid on;

%% 13. Ve tin hieu DSB trong mien thoi gian

figure;
plot(xdsb);
title('Dang song khi dieu che DSB-SC');
xlabel('Discrete time n');
ylabel('Amplitude (V)');
xlim([0 450]);
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
plot(xvsb);
title('Dang song khi dieu che VSB');
xlabel('Discrete time n');
ylabel('Amplitude (V)');
xlim([0 450]);
grid on;

%% 16. Ve pho tan so VSB

figure;
plot(f, abs(Xvsb_shift)/N);
title('Pho tan so VSB');
xlabel('Frequency (Hz)');
ylabel('|X_{VSB}(f)|');
xlim([0 12000]);
grid on;