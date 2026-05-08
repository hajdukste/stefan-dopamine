% a07b_arduino_sync.m
% Sync arduino start_of_trial events to video time using ttl_meta or fip_ttl_onset
% Similar to a03_sync_arduino_to_video.m but uses d_new from a07a

% Configuration
params = struct();
params.sync_target = 'ttl_meta';  % 'ttl_meta' or 'fip_ttl_onset'
params.use_spline_corrected = false;  % apply spline drift correction from a07a
params.good_threshold_ms = 500;  % what counts as "good" match

plot_mode = 1;  % 0 = full plots per animal/day, 1 = scatter summary
animals = 1:6;
days = 1:6;

% Override for split video processing
if exist('loading_split_video', 'var') && loading_split_video
    animals = 1;
    days = 1:2;
end

% spline fitting for error visualization
n_splines = 50;
pyenv('Version', '/opt/anaconda3/envs/pygam/bin/python');

if plot_mode == 1
    [fig_scatter, tl_scatter] = myFigure(-length(animals)*length(days), [], 400, 300, true);
end

for animal = animals
for day = days

all_data(animal).data(day).d_old = all_data(animal).data(day).d;
% skip bad recordings
if exist('loading_split_video', 'var') && loading_split_video
    skip_list = [];
else
    skip_list = [1, 3];  % [animal, day] pairs to skip
end

if ~isempty(skip_list) && any(all(skip_list == [animal, day], 2))
    continue;
end
fprintf('\n=== Processing A%d D%d ===\n', animal, day);

% Load data
if ~isfield(all_data(animal).data(day), 'd_new')
    fprintf('Skipping: no d_new\n');
    continue;
end
if ~isfield(all_data(animal).data(day), 'd_old')
    fprintf('Skipping: no d_old\n');
    continue;
end

d_new = all_data(animal).data(day).d_new;
d_old = all_data(animal).data(day).d_old;

if isempty(d_new) || isempty(d_old); continue; end
if ~ismember('type', d_old.Properties.VariableNames); continue; end

% Get video time (with optional spline correction)
if params.use_spline_corrected && isfield(all_data(animal).data(day), 'sync') && ...
        isfield(all_data(animal).data(day).sync, 'spline_correction_ms')
    sync = all_data(animal).data(day).sync;
    video_time = sync.video_time_mapped - sync.spline_correction_ms / 1000;
    fprintf('Using spline-corrected video time\n');
else
    video_time = d_new.time;
    fprintf('Using uncorrected video time\n');
end

% Get TTL onsets based on sync_target
if strcmp(params.sync_target, 'ttl_meta')
    if ~ismember('ttl_meta', d_new.Properties.VariableNames)
        fprintf('Skipping: no ttl_meta in d_new\n');
        continue;
    end
    ttl_mask = d_new.ttl_meta;
    target_name = 'ttl_meta';
elseif strcmp(params.sync_target, 'fip_ttl_onset')
    if ~ismember('fip_ttl_onset', d_new.Properties.VariableNames)
        fprintf('Skipping: no fip_ttl_onset in d_new\n');
        continue;
    end
    ttl_mask = d_new.fip_ttl_onset;
    target_name = 'fip_ttl_onset';
else
    error('Unknown sync_target: %s', params.sync_target);
end

ttl_times = video_time(ttl_mask);
n_ttl = length(ttl_times);

% Get start_of_trial events from d_old
trial_mask = strcmp(d_old.type, 'start_of_trial');
trial_times = d_old.arduino_time(trial_mask);
n_trials = length(trial_times);

if isempty(trial_times)
    fprintf('No start_of_trial events found\n');
    continue;
end
if isempty(ttl_times)
    fprintf('No TTL events found in %s\n', target_name);
    continue;
end

fprintf('Arduino: %d start_of_trial events\n', n_trials);
fprintf('Video:   %d %s events\n', n_ttl, target_name);

% Check count match
count_match = (n_trials == n_ttl);
if ~count_match
    fprintf('WARNING: count mismatch! %d trials vs %d TTLs\n', n_trials, n_ttl);
end

% Linear time mapping using first and last events
% For split video: use trial[1:n_ttl] matched to ttl[1:n_ttl]
if exist('loading_split_video', 'var') && loading_split_video && n_trials > n_ttl
    fprintf('Split video mode: matching trial[1:%d] to ttl[1:%d]\n', n_ttl, n_ttl);
    trial_first = trial_times(1);
    trial_last = trial_times(n_ttl);  % use n_ttl-th trial, not last
    ttl_first = ttl_times(1);
    ttl_last = ttl_times(n_ttl);
else
    trial_first = trial_times(1);
    trial_last = trial_times(end);
    ttl_first = ttl_times(1);
    ttl_last = ttl_times(end);
end

a = (ttl_last - ttl_first) / (trial_last - trial_first);
b = ttl_first - a * trial_first;
fprintf('Mapping: video_time = %.6f * arduino_time + %.4f\n', a, b);
fprintf('Time scale ratio: %.6f (should be ~1)\n', a);

% Map all trial times to video clock
trial_time_mapped = a * trial_times + b;

% Compute sync quality (error between mapped trials and TTL)
closest_dt_signed = zeros(n_ttl, 1);
for i = 1:n_ttl
    diffs = trial_time_mapped - ttl_times(i);
    [~, idx] = min(abs(diffs));
    closest_dt_signed(i) = diffs(idx);  % positive = trial after TTL
end
closest_dt = abs(closest_dt_signed);
good = closest_dt * 1000 < params.good_threshold_ms;

if sum(good) < 2
    fprintf('Not enough good matches for analysis\n');
    continue;
end

% Fit linear drift
p = polyfit(ttl_times(good), closest_dt_signed(good) * 1000, 1);
drift_rate = p(1) * 1000;  % ms per 1000s

fprintf('Quality: median=%.1f ms, max=%.1f ms, drift=%.2f ms/1000s\n', ...
    median(closest_dt(good)) * 1000, max(closest_dt(good)) * 1000, drift_rate);

% Plotting
if plot_mode == 1
    % Scatter summary with spline fit
    ax = nexttile(tl_scatter);
    x_data = ttl_times(good);
    y_data = closest_dt_signed(good) * 1000;
    scatter(ax, x_data, y_data, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax, 'on');

    if sum(good) >= 3
        % Fit spline for visualization
        x_pred = linspace(min(x_data), max(x_data), 200)';
        [predictions, ci] = pyrunfile("fit_spline_gam.py", ["predictions", "ci"], ...
            x=x_data, y=y_data, x_pred=x_pred, n_splines=int32(n_splines));
        predictions = double(predictions);
        ci = double(ci);
        % Plot spline fit with confidence interval
        fill(ax, [x_pred; flipud(x_pred)], [ci(:,1); flipud(ci(:,2))], ...
            'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ax, x_pred, predictions, 'r-', 'LineWidth', 2);
    end

    yline(ax, 0, 'k--');
    hold(ax, 'off');
    xlabel(ax, 'Video time (s)');
    ylabel(ax, 'Trial - TTL (ms)');

    % Title shows count match status
    if count_match
        match_str = sprintf('%d=%d', n_trials, n_ttl);
    else
        match_str = sprintf('%d~=%d', n_trials, n_ttl);
    end
    title(ax, sprintf('A%d D%d: %.1fms (%s)', animal, day, ...
        median(closest_dt(good)) * 1000, match_str));
else
    % Full plots
    [fig, tl] = myFigure(4, 1, 2200, 300, true);

    % Row 1: arduino_time (raw trial events)
    ax1 = nexttile(tl);
    hold(ax1, 'on');
    for tt = trial_times'
        xline(ax1, tt, 'b-', 'LineWidth', 1);
    end
    xline(ax1, trial_first, 'g-', 'LineWidth', 2);
    xline(ax1, trial_last, 'g-', 'LineWidth', 2);
    hold(ax1, 'off');
    ylabel(ax1, 'Arduino time');
    title(ax1, sprintf('start_of_trial in arduino_time (%d events)', n_trials));
    xlim(ax1, [trial_first - 10, trial_last + 10]);

    % Row 2: TTL events in video time
    ax2 = nexttile(tl);
    hold(ax2, 'on');
    for tt = ttl_times'
        xline(ax2, tt, 'r-', 'LineWidth', 1);
    end
    xline(ax2, ttl_first, 'g-', 'LineWidth', 2);
    xline(ax2, ttl_last, 'g-', 'LineWidth', 2);
    hold(ax2, 'off');
    ylabel(ax2, target_name);
    title(ax2, sprintf('%s in video time (%d events)', target_name, n_ttl));

    % Row 3: aligned comparison
    ax3 = nexttile(tl);
    hold(ax3, 'on');
    for tt = ttl_times'
        xline(ax3, tt, 'r-', 'LineWidth', 1, 'Alpha', 0.5);
    end
    for tt = trial_time_mapped'
        xline(ax3, tt, 'b--', 'LineWidth', 1);
    end
    hold(ax3, 'off');
    ylabel(ax3, 'Aligned');
    title(ax3, sprintf('TTL (red) vs mapped trials (blue dashed)'));
    linkaxes([ax2, ax3], 'x');

    % Row 4: error scatter with spline
    ax4 = nexttile(tl);
    x_data = ttl_times(good);
    y_data = closest_dt_signed(good) * 1000;
    scatter(ax4, x_data, y_data, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax4, 'on');

    if sum(good) >= 3
        x_pred = linspace(min(x_data), max(x_data), 200)';
        [predictions, ci] = pyrunfile("fit_spline_gam.py", ["predictions", "ci"], ...
            x=x_data, y=y_data, x_pred=x_pred, n_splines=int32(n_splines));
        predictions = double(predictions);
        ci = double(ci);
        fill(ax4, [x_pred; flipud(x_pred)], [ci(:,1); flipud(ci(:,2))], ...
            'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ax4, x_pred, predictions, 'r-', 'LineWidth', 2);
    end

    yline(ax4, 0, 'k--');
    hold(ax4, 'off');
    xlabel(ax4, 'Video time (s)');
    ylabel(ax4, 'Trial - TTL (ms)');
    title(ax4, sprintf('Sync error: %.1fms median, drift=%.2f ms/1000s (%d=%d?)', ...
        median(closest_dt(good)) * 1000, drift_rate, n_trials, n_ttl));
end

% Save sync mapping
sync_arduino = struct();
sync_arduino.a = a;
sync_arduino.b = b;
sync_arduino.trial_times = trial_times;
sync_arduino.trial_time_mapped = trial_time_mapped;
sync_arduino.sync_target = params.sync_target;
sync_arduino.use_spline_corrected = params.use_spline_corrected;
sync_arduino.n_trials = n_trials;
sync_arduino.n_ttl = n_ttl;
sync_arduino.count_match = count_match;

all_data(animal).data(day).sync_arduino = sync_arduino;
fprintf('Saved sync_arduino to all_data(%d).data(%d)\n', animal, day);

% Add/replace time column in d_old
d_old.time = a * d_old.arduino_time + b;
all_data(animal).data(day).d_old = d_old;
% Reorder fields: d_new first, d_old second, paths last
flds = fieldnames(all_data(animal).data);
first_flds = {'d_new', 'd_old'};
last_flds = {'csv_path', 'mp4_path', 'txt_path'};
first_flds = first_flds(ismember(first_flds, flds));
last_flds = last_flds(ismember(last_flds, flds));
middle_flds = flds(~ismember(flds, [first_flds, last_flds]));
new_order = [first_flds'; middle_flds; last_flds'];
all_data(animal).data = orderfields(all_data(animal).data, new_order);
fprintf('Added d_old.time (arduino_time mapped to video time)\n');

end
end

fprintf('\n=== Done ===\n');
