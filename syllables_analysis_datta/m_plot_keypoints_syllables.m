% Plot keypoint traces with syllable rectangles below
% Works with either:
%   1) a table with keypoint columns (_x, _y), or
%   2) a SLEAP-style Datasets struct array with Name/Value entries

% Parameters - adjust these
animal = 1;
day = 2;
start_time = 500;      % start time in seconds
duration = 30;       % duration in seconds
fps = 60;            % video frame rate

% Keypoint source
% Example for the "weird" imported variable format from MATLAB:
%   kp_source = C57_51_9_day2_10172025_video_1.Datasets;
kp_source = C57_51_9_day2_10172025_video_1.Datasets;

% Keypoint names to plot
keypoint_names = {'bum', 'mouth', 'leftHindpaw', 'rightHindpaw', 'leftForepaw', 'rightForepaw'};

% Colors for each keypoint (6 distinct colors)
keypoint_colors = [
    0.8, 0.2, 0.2;   % red - bum
    1.0, 0.6, 0.0;   % orange - mouth
    0.9, 0.9, 0.0;   % yellow - left hindpaw
    0.2, 0.8, 0.2;   % green - right hindpaw
    0.2, 0.6, 1.0;   % blue - left forepaw
    0.8, 0.2, 0.8;   % magenta - right forepaw
];

d = all_data(animal).data(day).d;

% Align keypoints to the same frame/time base as d and syllables
[traces, keypoint_labels] = extractAlignedKeypointTraces(kp_source, keypoint_names, d);
time_vec = d.time;
n_frames = numel(time_vec);
total_duration = time_vec(end) - time_vec(1);

n_keypoints = length(keypoint_names);

% Normalize traces for stacked display (each keypoint gets its own row)
trace_height = 1;  % height allocated per keypoint
trace_gap = 0.2;   % gap between keypoints
traces_norm = cell(n_keypoints, 2);
label_y_positions = nan(n_keypoints, 1);

% Debug: print ranges
fprintf('\nKeypoint data ranges:\n');
for i = 1:n_keypoints
    for j = 1:2
        data = traces{i, j};
        xy = {'x', 'y'};
        fprintf('  %s_%s: min=%.1f, max=%.1f, std=%.2f, nans=%d/%d\n', ...
            keypoint_names{i}, xy{j}, min(data, [], 'omitnan'), max(data, [], 'omitnan'), ...
            std(data, 'omitnan'), sum(isnan(data)), length(data));
    end
end

for i = 1:n_keypoints
    for j = 1:2  % x and y
        data = traces{i, j};
        % Z-score normalization (shows relative movement)
        data_mean = mean(data, 'omitnan');
        data_std = std(data, 'omitnan');
        if data_std > 0
            data_norm = (data - data_mean) / data_std;
        else
            data_norm = zeros(size(data));
        end
        % Scale and offset for stacking (top to bottom)
        y_offset = (n_keypoints - i) * (trace_height + trace_gap) + trace_height/2;
        traces_norm{i, j} = data_norm * 0.3 + y_offset;  % 0.3 = visual scale factor
        label_y_positions(i) = y_offset;
    end
end

% Create figure
total_trace_height = n_keypoints * (trace_height + trace_gap);
syllable_height = 1.5;  % height for syllable rectangles
total_height = total_trace_height + syllable_height + trace_gap;

[fig, tl] = myFigure(1, 1, 800, 400, true);
ax = nexttile(tl);
hold(ax, 'on');

% Plot traces
for i = 1:n_keypoints
    col = keypoint_colors(i, :);
    % Plot x trace (solid)
    plot(ax, time_vec, traces_norm{i, 1}, '-', 'Color', col, 'LineWidth', 1.2);
    % Plot y trace (slightly darker/same color)
    plot(ax, time_vec, traces_norm{i, 2}, '-', 'Color', col * 0.7, 'LineWidth', 1.2);
end

% Add keypoint labels (normalized units so they stay visible when panning)
for i = 1:n_keypoints
    y_norm = (label_y_positions(i) - syllable_y_base) / (total_trace_height - syllable_y_base);
    text(ax, 0.01, y_norm, keypoint_labels{i}, ...
        'Units', 'normalized', ...
        'Color', keypoint_colors(i, :), 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

% Plot syllable rectangles below traces
% Get syllable data from aligned d
syllable_y_base = -syllable_height - trace_gap/2;
syl_all = d.syllable;
if ~isempty(syl_all)
    n_frames_syl = min(n_frames, numel(syl_all));
    syl = syl_all(1:n_frames_syl);

    % Get unique syllables for coloring
    unique_syls = unique(syl(~isnan(syl) & syl >= 0));
    n_unique = length(unique_syls);
    clear lines;
    syl_colors = lines(max(n_unique, 10));
    syl_to_color = containers.Map('KeyType', 'double', 'ValueType', 'any');
    for i = 1:length(unique_syls)
        syl_to_color(unique_syls(i)) = syl_colors(mod(i-1, size(syl_colors,1))+1, :);
    end

    % Find runs of same syllable
    run_starts = [1; find(diff(syl) ~= 0) + 1];
    run_ends = [run_starts(2:end) - 1; n_frames_syl];

    for i_run = 1:length(run_starts)
        rs = run_starts(i_run);
        re = run_ends(i_run);
        s = syl(rs);

        if isnan(s) || s < 0
            col = [0.9 0.9 0.9];
        elseif syl_to_color.isKey(s)
            col = syl_to_color(s);
        else
            col = [0.5 0.5 0.5];
        end

        x_start = time_vec(rs);
        if re < numel(time_vec)
            x_end = time_vec(re + 1);
        else
            median_dt = median(diff(time_vec), 'omitnan');
            if ~isfinite(median_dt) || median_dt <= 0
                median_dt = 1 / fps;
            end
            x_end = time_vec(re) + median_dt;
        end
        x_width = x_end - x_start;
        rectangle(ax, 'Position', [x_start, syllable_y_base, x_width, syllable_height], ...
            'FaceColor', col, 'EdgeColor', 'none');

        % Add syllable number if wide enough
        if x_width > 0.3 && ~isnan(s) && s >= 0
            text(ax, x_start + x_width/2, syllable_y_base + syllable_height/2, num2str(s), ...
                'Color', 'w', 'FontSize', 8, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
    end
else
    % No syllable data - just draw empty rectangle for visible range
    rectangle(ax, 'Position', [0, syllable_y_base, total_duration, syllable_height], ...
        'FaceColor', [0.9 0.9 0.9], 'EdgeColor', [0.5 0.5 0.5]);
end

% Formatting - use xlim to set initial view (pan/zoom to explore)
xlim(ax, [start_time, start_time + duration]);
ylim(ax, [syllable_y_base total_trace_height]);
xlabel(ax, 'Time (s)');
set(ax, 'YTick', []);

title(ax, sprintf('Keypoints + Syllables'));

%--------------------------------------------------------------------------
function [traces, keypoint_labels] = extractAlignedKeypointTraces(kp_source, keypoint_names, d)
    [raw_traces, keypoint_labels, n_source_frames] = extractKeypointTraces(kp_source, keypoint_names);
    n_keypoints = numel(keypoint_names);
    n_target_frames = height(d);
    traces = cell(n_keypoints, 2);

    if ismember('frame_idx', d.Properties.VariableNames) && ~isempty(d.frame_idx)
        frame_idx = d.frame_idx;
        valid_frame_idx = isfinite(frame_idx) & frame_idx >= 1 & frame_idx <= n_source_frames;
        frame_idx = round(frame_idx);

        for i = 1:n_keypoints
            for j = 1:2
                aligned_trace = nan(n_target_frames, 1);
                source_trace = raw_traces{i, j};
                aligned_trace(valid_frame_idx) = source_trace(frame_idx(valid_frame_idx));
                traces{i, j} = aligned_trace;
            end
        end
        return;
    end

    if n_source_frames == n_target_frames
        traces = raw_traces;
        return;
    end

    error('Could not align keypoints: d.frame_idx is missing and source frame count does not match d.');
end

%--------------------------------------------------------------------------
function [traces, keypoint_labels, n_frames] = extractKeypointTraces(kp_source, keypoint_names)
    n_keypoints = numel(keypoint_names);
    traces = cell(n_keypoints, 2);
    keypoint_labels = keypoint_names;

    if istable(kp_source)
        n_frames = height(kp_source);
        for i = 1:n_keypoints
            name = keypoint_names{i};
            x_col = [name '_x'];
            y_col = [name '_y'];

            if ismember(x_col, kp_source.Properties.VariableNames) && ...
                    ismember(y_col, kp_source.Properties.VariableNames)
                traces{i, 1} = kp_source.(x_col);
                traces{i, 2} = kp_source.(y_col);
            else
                warning('Columns %s or %s not found', x_col, y_col);
                traces{i, 1} = nan(n_frames, 1);
                traces{i, 2} = nan(n_frames, 1);
            end
        end
        return;
    end

    if isstruct(kp_source) && isfield(kp_source, 'Name') && isfield(kp_source, 'Value')
        node_names = getDatasetValue(kp_source, 'node_names');
        tracks = getDatasetValue(kp_source, 'tracks');
        [traces, keypoint_labels, n_frames] = extractFromDatasetTracks(tracks, node_names, keypoint_names);
        return;
    end

    if isstruct(kp_source) && isfield(kp_source, 'node_names') && isfield(kp_source, 'tracks')
        [traces, keypoint_labels, n_frames] = extractFromDatasetTracks(kp_source.tracks, kp_source.node_names, keypoint_names);
        return;
    end

    error('Unsupported keypoint source. Use a table or a Datasets struct array with Name/Value entries.');
end

%--------------------------------------------------------------------------
function [traces, keypoint_labels, n_frames] = extractFromDatasetTracks(tracks, node_names, keypoint_names)
    n_keypoints = numel(keypoint_names);
    traces = cell(n_keypoints, 2);

    if isstring(node_names) || ischar(node_names) || iscategorical(node_names)
        node_names = cellstr(node_names);
    end
    node_names = node_names(:);
    keypoint_labels = keypoint_names;

    if ndims(tracks) == 3
        % Expected imported shape: n_frames x n_nodes x 2
        n_frames = size(tracks, 1);
    elseif ndims(tracks) == 4
        % H5-read shape often ends up as n_frames x n_nodes x 2 x n_tracks
        tracks = tracks(:, :, :, 1);
        n_frames = size(tracks, 1);
    else
        error('Unsupported tracks array shape. Expected n_frames x n_nodes x 2 or n_frames x n_nodes x 2 x n_tracks.');
    end

    normalized_node_names = cellfun(@normalizeKeypointName, node_names, 'UniformOutput', false);

    for i = 1:n_keypoints
        requested_name = keypoint_names{i};
        match_idx = find(strcmp(normalized_node_names, normalizeKeypointName(requested_name)), 1);

        if isempty(match_idx)
            warning('Keypoint %s not found in node_names', requested_name);
            traces{i, 1} = nan(n_frames, 1);
            traces{i, 2} = nan(n_frames, 1);
            continue;
        end

        traces{i, 1} = squeeze(tracks(:, match_idx, 1));
        traces{i, 2} = squeeze(tracks(:, match_idx, 2));
        keypoint_labels{i} = strrep(node_names{match_idx}, '_', ' ');
    end
end

%--------------------------------------------------------------------------
function value = getDatasetValue(dataset_entries, field_name)
    dataset_names = string({dataset_entries.Name});
    match_idx = find(dataset_names == string(field_name), 1);
    if isempty(match_idx)
        error('Field %s not found in dataset entries.', field_name);
    end
    value = dataset_entries(match_idx).Value;
end

%--------------------------------------------------------------------------
function normalized_name = normalizeKeypointName(name)
    normalized_name = lower(char(name));
    normalized_name = regexprep(normalized_name, '[^a-z0-9]', '');
end
