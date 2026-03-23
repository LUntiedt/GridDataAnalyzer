% =========================================================================
% Projekt: Grid Data Analyzer
% Skript:  01_generate_data.m
% Autor:   Laurenz Untiedt
% Zweck:   Erzeugung synthetischer, hochaufgelöster Netzdaten (10 kHz)
%          inkl. Harmonischer, Spannungsabfall und IoT-Sensor-Rauschen.
% =========================================================================

clear; clc; close all; 
%% 1. Parameter-Setup (Vektorisierung)
fs = 10000;                  % Abtastrate 10 kHz (ausreichend für PQ-Analyse)
duration = 1;                % Dauer der Simulation in Sekunden
t = 0:1/fs:duration-(1/fs);  % Zeitvektor erstellen (Array von 0 bis 0.9999)

f_grid = 50;                 % Netzfrequenz 50 Hz
V_rms = 230;                 % Nennspannung (Effektivwert) in Volt
V_peak = V_rms * sqrt(2);    % Scheitelwert

%% 2. Signal-Synthese: Grundschwingung & Harmonische
% Beiischen einer 3. (150 Hz) und 5. (250 Hz) Harmonischen, um 
% Wechselrichter-Einspeisung (Power Quality Problem) zu simulieren.
V_fund = V_peak * sin(2*pi * f_grid * t);           % 50 Hz Ideal
V_h3   = (V_peak * 0.08) * sin(2*pi * (f_grid*3) * t); % 8% Amplitude
V_h5   = (V_peak * 0.05) * sin(2*pi * (f_grid*5) * t); % 5% Amplitude

% Kombiniertes Signal (noch ohne Fehler)
V_clean = V_fund + V_h3 + V_h5;

%% 3. Event Injection: Spannungsabfall (Voltage Dip für Netzstabilität)
% simulieren eines Kurzschlusses im Netz zwischen t = 0.4s und 0.5s.
% Die Spannung bricht in dieser Zeit auf 70% ein.
dip_multiplier = ones(size(t)); % Array voller Einsen

% Logische Indizierung
dip_multiplier(t >= 0.4 & t <= 0.5) = 0.7; 

% Elementweise Multiplikation
V_faulty = V_clean .* dip_multiplier; 

%% 4. IoT-Sensor-Rauschen (Quantisierungsrauschen / White Noise)
noise_level = 5; % Volt
noise = noise_level * randn(size(t)); 

% Das finale Messsignal
V_measured = V_faulty + noise;

%% 5. Export als CSV & Quick-Plot
% Daten in eine Tabelle packen mit transponierten '
data_table = table(t', V_measured', 'VariableNames', {'Time_s', 'Voltage_V'});
writetable(data_table, 'grid_data.csv');
disp('Erfolg: grid_data.csv wurde erstellt!');

% Kurzer Plot zur visuellen Kontrolle (Zoom auf die ersten 0.6 Sekunden)
figure('Name', 'Generierte Rohdaten');
plot(t, V_measured, 'Color', [0 0.4470 0.7410]); 
hold on;
xline(0.4, 'r--', 'Dip Start', 'LabelVerticalAlignment', 'bottom');
xline(0.5, 'r--', 'Dip Ende', 'LabelVerticalAlignment', 'bottom');
xlim([0 0.6]);
xlabel('Zeit (s)');
ylabel('Spannung (V)');
title('Synthetische PMU-Rohdaten (Verrauscht, inkl. Harmonischer & Dip)');
grid on;
