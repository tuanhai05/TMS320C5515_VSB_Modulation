% =========================================================================
% MATLAB SCRIPT: VSB SYSTEM TIME-DOMAIN AND FREQUENCY-DOMAIN ANALYSIS
% =========================================================================
clc;
clear;
close all;

%% 1. Load Data Files (Skipping the TI-CCS Header Line)
% Make sure input.dat, modulated.dat, and output.dat are in your current folder
try
    original_msg    = readmatrix('input.dat', 'NumHeaderLines', 1);
    vsb_modulated   = readmatrix('modulated.dat', 'NumHeaderLines', 1);
    demod_recovered = readmatrix('output.dat', 'NumHeaderLines', 1);
catch
    error('Error: Please check if input.dat, modulated.dat, and output.dat exist in the current directory.');
end

%% 2. System Parameters
fs = 48000;                 % Sampling frequency (48 kHz)
N = length(original_msg);   % Number of samples (1000)
t = (0:N-1) / fs;           % Time vector
f = fs * (0:(N/2)) / N;     % Frequency vector for one-sided spectrum

%% 3. Compute Frequency Spectrum (FFT)
% --- FFT for Original Message Signal ---
Y_in = fft(original_msg);
P2_in = abs(Y_in / N);
P1_in = P2_in(1:floor(N/2)+1);
P1_in(2:end-1) = 2 * P1_in(2:end-1);

% --- FFT for VSB Modulated Signal ---
Y_mod = fft(vsb_modulated);
P2_mod = abs(Y_mod / N);
P1_mod = P2_mod(1:floor(N/2)+1);
P1_mod(2:end-1) = 2 * P1_mod(2:end-1);

% --- FFT for Demodulated Recovered Signal ---
Y_out = fft(demod_recovered);
P2_out = abs(Y_out / N);
P1_out = P2_out(1:floor(N/2)+1);
P1_out(2:end-1) = 2 * P1_out(2:end-1);

%% 4. Plotting Time-Domain Waveforms and Frequency Spectrums
figure('Name', 'VSB Complete System Analysis: Time & Frequency Domain', 'Color', [1 1 1], 'Position', [100, 50, 1100, 850]);

% -------------------------------------------------------------------------
% ROW 1: ORIGINAL MESSAGE SIGNAL (300, 500, 700, 900 Hz Tones)
% -------------------------------------------------------------------------
% Time Domain
subplot(3, 2, 1);
plot(t * 1000, original_msg, 'b', 'LineWidth', 1.2);
grid on;
title('Sóng tín hiệu thông tin');
xlabel('TThời gian (ms)');
ylabel('Biên độ');

% Frequency Domain
subplot(3, 2, 2);
stem(f, P1_in, 'b', 'Marker', 'none', 'LineWidth', 1.5);
grid on;
title('Phổ tín hiệu thông tin');
xlabel('Tần số (Hz)');
ylabel('|X(f)|');
xlim([0, 2000]); % Zoom into 0 - 2000 Hz to see the 4 tones clearly

% -------------------------------------------------------------------------
% ROW 2: VSB MODULATED SIGNAL (Around 10 kHz Carrier)
% -------------------------------------------------------------------------
% Time Domain
subplot(3, 2, 3);
plot(t * 1000, vsb_modulated, 'r', 'LineWidth', 1.0);
grid on;
title('Sóng tín hiệu AM - VSB');
xlabel('TThời gian (ms)');
ylabel('Biên độ');

% Frequency Domain
subplot(3, 2, 4);
plot(f, P1_mod, 'r', 'LineWidth', 1.2);
grid on;
title('Phổ tín hiệu AM - VSB');
xlabel('Tần số (Hz)');
ylabel('|Xc(f)|');
xlim([0, 15000]); % Zoom around 10 kHz area to view the asymmetric band

% -------------------------------------------------------------------------
% ROW 3: DEMODULATED RECOVERED SIGNAL (Baseband Restored with Delay Compensation)
% -------------------------------------------------------------------------
% Time Domain (Compensating 72 samples group delay for visualization)
subplot(3, 2, 5);
demod_aligned = circshift(demod_recovered, -72); % Shift left by 72 samples
plot(t * 1000, demod_aligned, 'g', 'LineWidth', 1.2);
grid on;
title('SÓng tín hiệu sau giải điều chế');
xlabel('Thời gian (ms)');
ylabel('Biên độ');

% Frequency Domain (Keep unchanged)
subplot(3, 2, 6);
stem(f, P1_out, 'g', 'Marker', 'none', 'LineWidth', 1.5);
grid on;
title('Phổ sau giải điều chế');
xlabel('Tần số (Hz)');
ylabel('|Y(f)|');
xlim([0, 2000]);

% Optimize layout spacing
sgtitle('Điều chế AM - VSB và giải điều chế', 'FontSize', 14, 'FontWeight', 'bold');