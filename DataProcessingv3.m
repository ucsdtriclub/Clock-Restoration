clear
clc

% DataProcessingv3.m
% Updated script: Computes motion analysis and selectively plots top 3 longest runtime tests
close all;clc;
% Prompt user to select a folder of CSV files
folderPath = uigetdir('', 'Select Folder Containing CSV Files');
if folderPath == 0
    disp('No folder selected.'); return;
end

filePattern = fullfile(folderPath, '*.csv');
csvFiles = dir(filePattern);
if isempty(csvFiles)
    error('No CSV files found in the selected folder.');
end

fileList = cell(1, numel(csvFiles));
dataList = cell(1, numel(csvFiles));
for i = 1:numel(csvFiles)
    fileList{i} = fullfile(folderPath, csvFiles(i).name);
    dataList{i} = readtable(fileList{i}, 'PreserveVariableNames', true);
end

validData = dataList(~cellfun(@isempty, dataList));
if isempty(validData), error('No data loaded.'); end

refTime = validData{1}.Time_s;
combined = validData{1};
for i = 2:numel(validData)
    d = validData{i};
    combined.Temp_F = combined.Temp_F + interp1(d.Time_s, d.Temp_F, refTime, 'linear', NaN);
    combined.DeltaT_ms = combined.DeltaT_ms + interp1(d.Time_s, d.DeltaT_ms, refTime, 'linear', NaN);
    combined.AngleX = combined.AngleX + interp1(d.Time_s, d.AngleX, refTime, 'linear', NaN);
    combined.AngleY = combined.AngleY + interp1(d.Time_s, d.AngleY, refTime, 'linear', NaN);
    combined.AngleZ = combined.AngleZ + interp1(d.Time_s, d.AngleZ, refTime, 'linear', NaN);
end
if numel(validData) > 1
    combined.Temp_F = combined.Temp_F / numel(validData);
    combined.DeltaT_ms = combined.DeltaT_ms / numel(validData);
    combined.AngleX = combined.AngleX / numel(validData);
    combined.AngleY = combined.AngleY / numel(validData);
    combined.AngleZ = combined.AngleZ / numel(validData);
end

filteredMask = mod(combined.DeltaT_ms, 1) == 0;
data = combined(filteredMask, :);

% Analysis and runtime tracking
fprintf('\n===== Per-Test Motion Analysis =====\n');
runtimes = zeros(1, numel(validData));

for i = 1:numel(validData)
    raw = validData{i};
    gearMask = mod(raw.DeltaT_ms, 1) == 0;
    d = raw(gearMask, :);

    t = d.Time_s;
    deltaT = d.DeltaT_ms;
    tempF = d.Temp_F;
    angleX = raw.AngleX;
    angleY = raw.AngleY;
    angleZ = raw.AngleZ;

    fprintf('\nTest %d:\n', i);
    tempRange = max(tempF, [], 'omitnan') - min(tempF, [], 'omitnan');
    fprintf('  Temperature range: %.2f°F\n', tempRange);

    gearTimes = t(~isnan(deltaT));
    if numel(gearTimes) > 1
lowerTol = 1.950;
upperTol = 2.050;

gearIntervals = diff(gearTimes);
accurateTicks = sum(gearIntervals >= lowerTol & gearIntervals <= upperTol);

totalRuntime = gearTimes(end) - gearTimes(1); % in seconds
expectedTicks = floor(totalRuntime / 2); % expected number of 2-second intervals
  runtimes(i) = totalRuntime;
accuracyPercent = accurateTicks / expectedTicks * 100;

fprintf('  Accurate ticks (1950–2050 ms) as %% of total: %.2f%%\n', accuracyPercent);
fprintf('  Total runtime (gear-based): %.2f s\n', totalRuntime);

    else
        fprintf('  Not enough gear events for analysis.\n');
    end

    fprintf('  Angle X range: %.2f\xB0\n', range(angleX, 'omitnan'));
    fprintf('  Angle Y range: %.2f\xB0\n', range(angleY, 'omitnan'));
    fprintf('  Angle Z range: %.2f\xB0\n', range(angleZ, 'omitnan'));

    if sum(~isnan(tempF) & ~isnan(deltaT)) > 10
        r = corr(tempF, deltaT, 'Rows','complete');
        fprintf('  Correlation Temp vs DeltaT: %.2f\n', r);
    else
        fprintf('  Not enough data to correlate Temp and DeltaT.\n');
    end
end

validRuntimes = runtimes(runtimes > 0);
fprintf('\n===== Summary Statistics =====\n');
fprintf('Mean runtime: %.2f s\n', mean(validRuntimes));
fprintf('Standard deviation: %.2f s\n', std(validRuntimes));
fprintf('Longest runtime: %.2f s\n', max(validRuntimes));
fprintf('Shortest runtime: %.2f s\n', min(validRuntimes));

[~, topIndices] = maxk(runtimes, min(3, numel(runtimes)));
topData = validData(topIndices);

% Plot: Temperature
figure('Name', 'Top 3 Temperature Runs', 'Position', [100, 700, 560, 420]);
for i = 1:numel(topData)
    subplot(3,1,i);
    plot(topData{i}.Time_s, topData{i}.Temp_F, '-r');
    title(sprintf('Top Run %d Temperature (°F)', i)); xlabel('Time (s)'); ylabel('Temp (°F)'); grid on;
    ylim([60 90]);
end

% Plot: Gear Detections
figure('Name', 'Top 3 Gear Detections', 'Position', [700, 700, 560, 420]);
for i = 1:numel(topData)
    raw = topData{i};
    gearMask = mod(raw.DeltaT_ms, 1) == 0;
    d = raw(gearMask, :);

    t = d.Time_s;
    deltaT = d.DeltaT_ms;

    subplot(3,1,i);
    plot(t, deltaT, '.-');
    title(sprintf('Top Run %d Gear Detections (DeltaT)', i));
    xlabel('Time (s)');
    ylabel('Tick Time (ms)');
    grid on;
end

% Plot: Accelerometer X/Y/Z
angles = {'AngleX', 'AngleY', 'AngleZ'};
angleTitles = {'X', 'Y', 'Z'};
colors = {'r', 'g', 'b'};
%yLims = {[], [-20 20], []};
for j = 1:3
    figure('Name', sprintf('Top 3 Accelerometer %s', angleTitles{j}), 'Position', [100+600*(j-1), 200, 560, 420]);
    for i = 1:numel(topData)
        subplot(3,1,i);
        plot(topData{i}.Time_s, topData{i}.(angles{j}), colors{j});
        title(sprintf('Top Run %d Angle %s', i, angleTitles{j}));
        xlabel('Time (s)');
        ylabel(sprintf('Angle %s (°)', angleTitles{j}));
        grid on;
        %if ~isempty(yLims{j}), ylim(yLims{j}); end
    end
end
