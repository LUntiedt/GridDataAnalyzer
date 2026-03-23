% =========================================================================
% Projekt: Grid Data Analyzer (Power Quality & Event Detection)
% Skript:  B_grid_analyzer.m
% Autor:   Laurenz Untiedt
% Zweck:   Pre-Processing und Filterung von hochaufgelösten Netzdaten.
% =========================================================================

clear; clc; close all;

%% 1. Data Import & Setup
% Einlesen der PMU-Rohdaten (Spannungswerte inkl. Sensor-Rauschen)
data = readtable('grid_data.csv'); 

t = data.Time_s;
V_measured = data.Voltage_V;

% Dynamische Berechnung der Abtastrate aus den Zeitstempeln
fs = 1 / (t(2) - t(1)); 

%% 2. Signal Pre-Processing: Digitaler Tiefpassfilter
% Ziel: Eliminierung von hochfrequentem Mess- und Quantisierungsrauschen der Sensorik.
% Cutoff bei 500 Hz gewählt, um die 50Hz-Grundschwingung sowie relevante 
% Oberschwingungen (z. B. bis zur 7. Harmonischen bei 350 Hz) nicht zu dämpfen.
fc = 500; 

% IIR-Butterworth-Filter (4. Ordnung)
lp_filter = designfilt('lowpassiir', 'FilterOrder', 4, 'HalfPowerFrequency', fc, 'SampleRate', fs);
                   
% Anwendung von Zero-Phase Filtering (filtfilt anstatt filter):
% Zwingend erforderlich, um Phasenverschiebungen durch den Filter zu vermeiden, 
% da die exakte Phasenlage für nachfolgende Lastfluss- und Blindleistungsberechnungen 
% intakt bleiben muss.
V_filtered = filtfilt(lp_filter, V_measured);

%% 3. Plot: Pre-Processing Kontrolle
figure('Name', 'Pre-Processing: Filterung');
plot(t, V_measured, 'Color', [0.8 0.8 0.8]); % Verrauschte Rohdaten im Hintergrund
hold on;
plot(t, V_filtered, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5); % Gefiltertes Signal

xlim([0 0.1]); % Zoom auf die ersten 100 ms für bessere Erkennbarkeit
xlabel('Zeit (s)'); 
ylabel('Spannung (V)');
title('Signal Pre-Processing: Sensor-Rohdaten vs. Zero-Phase Filter');
legend('Rohdaten (verrauscht)', 'Gefiltert (Zero-Phase)', 'Location', 'best');
grid on;

%% 4. Harmonische Analyse (FFT) - Fokus: Power Quality / Lastfluss
% Überführung des Zeitsignals in den Frequenzbereich zur Identifikation 
% von Oberschwingungen (verursacht z. B. durch leistungselektronische Anlagen).

L = length(V_filtered);         % Signallänge
Y = fft(V_filtered);            % Die eigentliche Fast Fourier Transformation

% MATLAB gibt ein beidseitiges, komplexes Spektrum zurück. 
% Relevant ist das reale, einseitige Amplitudenspektrum:
P2 = abs(Y / L);
P1 = P2(1:floor(L/2)+1);        % Halbes Spektrum abschneiden
P1(2:end-1) = 2 * P1(2:end-1);  % Amplituden verdoppeln (Energie-Erhaltung)

% Frequenzvektor für die X-Achse (0 bis zur halben Abtastrate - Nyquist)
f = fs * (0:(L/2)) / L;

%% 5. Event Detection (Moving RMS) - Fokus: Systemstabilität
% Berechnung des gleitenden Effektivwerts (RMS) über exakt eine Netzperiode.
% Bei 50 Hz dauert eine Periode 20 ms. Bei 10.000 Hz Abtastrate sind das 200 Samples.
window_samples = fs * 0.02; 

% Vektorisierte Berechnung: Wurzel aus dem gleitenden Mittelwert der quadrierten Spannung
V_rms_moving = sqrt(movmean(V_filtered.^2, window_samples));

% Trigger-Logik nach EN 50160: Spannungsabfall unter 90% der Nennspannung
V_nominal_rms = 230; 
dip_threshold = V_nominal_rms * 0.9;

% Logische Indizierung zur Fehlererkennung (Array mit 1 für Fehler, 0 für Normal)
fault_indices = V_rms_moving < dip_threshold;

%% 6. Reporting & Dashboarding: Visualisierung der Netzqualität und Stabilität
% Generierung eines mehrteiligen Layouts zur simultanen Überwachung 
% von Zeitbereich, Frequenzspektrum und RMS-Grenzwerten.

% Hauptfenster initialisieren
figure('Name', 'Grid Data Analyzer Dashboard', 'Position', [100, 100, 1000, 800]);

% Layout-Raster definieren (3 Zeilen, 1 Spalte)
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Grid Data Analyzer: Power Quality & Event Detection', 'FontSize', 16, 'FontWeight', 'bold');

% =========================================================================
% Subplot 1: Time Domain (Filter-Performance)
% =========================================================================
nexttile;
plot(t, V_measured, 'Color', [0.8 0.8 0.8]); hold on;
plot(t, V_filtered, 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);

% Markierung des transienten Störfalls
xline(0.4, 'k--', 'LineWidth', 1);
xline(0.5, 'k--', 'LineWidth', 1);

xlim([0 0.6]); 
title('1. Zeitbereich: Sensor-Rohdaten vs. Zero-Phase Filterung');
ylabel('Spannung (V)');
legend('Rohdaten (inkl. Rauschen)', 'Gefiltert (50 Hz + Harmonische)', 'Location', 'northeast');
grid on;

% =========================================================================
% Subplot 2: Frequenzspektrum (Harmonische Lastflussanalyse)
% =========================================================================
nexttile;
% Darstellung der diskreten Frequenzkomponenten
stem(f, P1, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'MarkerFaceColor', [0.8500 0.3250 0.0980]);
xlim([0 350]); % Betrachtungsbereich bis zur 7. Harmonischen

title('2. Frequenzspektrum (FFT): Identifikation von Oberschwingungen');
ylabel('Amplitude (V)');
xlabel('Frequenz (Hz)');

% Beschriftung der charakteristischen Frequenzen (Fundamental & Harmonische)
text(50, 320, ' Fundamental (50 Hz)', 'VerticalAlignment', 'bottom');
text(150, 25, ' 3. Harmonische', 'VerticalAlignment', 'bottom');
text(250, 15, ' 5. Harmonische', 'VerticalAlignment', 'bottom');
grid on;

% =========================================================================
% Subplot 3: Event Detection (Gleitender RMS & Systemstabilität)
% =========================================================================
nexttile;
plot(t, V_rms_moving, 'Color', [0.9290 0.6940 0.1250], 'LineWidth', 2); hold on;

% Grenzwert nach EN 50160 Norm einzeichnen
yline(dip_threshold, 'r-', 'EN 50160 Limit (90%)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

% Hervorheben der detektierten Spannungseinbrüche (Voltage Dips)
fault_t = t(fault_indices);
fault_v = V_rms_moving(fault_indices);
scatter(fault_t, fault_v, 15, 'r', 'filled');

xlim([0 0.6]);
ylim([150 250]); 
title('3. Systemstabilität: Gleitender RMS-Wert & Spannungsabfall-Erkennung');
ylabel('RMS Spannung (V)');
xlabel('Zeit (s)');
legend('Gleitender RMS (20ms Fenster)', 'Kritischer Grenzwert', 'Detektiertes Event (Dip)', 'Location', 'southwest');
grid on;
