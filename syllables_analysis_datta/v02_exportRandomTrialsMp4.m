%--------------------------------------------------------------------------
% Export random trial clips as a concatenated MP4 with syllable strip overlay
% Requires `all_data` in the workspace.
%--------------------------------------------------------------------------

animal = 5;
day = 5;
video_scale = 1;
playback_speed = 3;
t_before = 5;
t_after = 3;
num_trials = 15;

exclude_edge_sec = 300;
title_card_sec = 1;
output_path = '';

if ~exist('all_data', 'var')
    error('v02_exportRandomTrialsMp4:MissingAllData', ...
        '`all_data` must already exist in the workspace.');
end

session_data = all_data(animal).data(day);
if ~isfield(session_data, 'd') || isempty(session_data.d)
    error('v02_exportRandomTrialsMp4:MissingD', ...
        'Session all_data(%d).data(%d).d is missing or empty.', animal, day);
end
if ~isfield(session_data, 'd_old') || isempty(session_data.d_old)
    error('v02_exportRandomTrialsMp4:MissingDOld', ...
        'Session all_data(%d).data(%d).d_old is missing or empty.', animal, day);
end
if ~isfield(session_data, 'mp4_path') || isempty(session_data.mp4_path)
    error('v02_exportRandomTrialsMp4:MissingVideoPath', ...
        'Session all_data(%d).data(%d).mp4_path is missing.', animal, day);
end

d = session_data.d;
d_old = session_data.d_old;
mp4_path = session_data.mp4_path;

if ~isscalar(playback_speed) || ~isfinite(playback_speed) || playback_speed <= 0
    error('v02_exportRandomTrialsMp4:InvalidPlaybackSpeed', ...
        '`playback_speed` must be a positive scalar.');
end

required_cols = {'time', 'frame_idx', 'centroidX', 'centroidY', 'syllable'};
missing_cols = required_cols(~ismember(required_cols, d.Properties.VariableNames));
if ~isempty(missing_cols)
    error('v02_exportRandomTrialsMp4:MissingColumns', ...
        'Missing required columns in d: %s', strjoin(missing_cols, ', '));
end

time_vec = d.time;
frame_idx = d.frame_idx;
centroid_x = d.centroidX;
centroid_y = d.centroidY;
syllables = d.syllable;
n_rows = height(d);

valid_main = isfinite(time_vec) & isfinite(frame_idx);
if ~any(valid_main)
    error('v02_exportRandomTrialsMp4:NoValidRows', ...
        'No valid rows with both `time` and `frame_idx` were found.');
end

session_start = min(time_vec(valid_main));
session_end = max(time_vec(valid_main));
clip_start_min = session_start + exclude_edge_sec;
clip_end_max = session_end - exclude_edge_sec;

[trial_starts, trial_ends] = v02_pair_trial_intervals(d_old);
if isempty(trial_starts)
    error('v02_exportRandomTrialsMp4:NoTrials', ...
        'No valid paired start_of_trial/end_of_trial events were found.');
end

clip_starts = trial_starts - t_before;
clip_ends = trial_ends + t_after;
valid_trials = clip_starts >= clip_start_min & clip_ends <= clip_end_max;
trial_starts = trial_starts(valid_trials);
trial_ends = trial_ends(valid_trials);
clip_starts = clip_starts(valid_trials);
clip_ends = clip_ends(valid_trials);

if isempty(trial_starts)
    error('v02_exportRandomTrialsMp4:NoEligibleTrials', ...
        ['No trials remain after excluding the first/last %.0f seconds ', ...
        'and applying t_before/t_after padding.'], exclude_edge_sec);
end

rng('shuffle');
n_valid = numel(trial_starts);
n_select = min(num_trials, n_valid);
selected_idx = randperm(n_valid, n_select);
[~, sort_idx] = sort(trial_starts(selected_idx));
selected_idx = selected_idx(sort_idx);

if n_select < num_trials
    warning('v02_exportRandomTrialsMp4:FewerTrialsThanRequested', ...
        'Requested %d trials but only %d valid trials were available.', ...
        num_trials, n_select);
end

trial_starts = trial_starts(selected_idx);
trial_ends = trial_ends(selected_idx);
clip_starts = clip_starts(selected_idx);
clip_ends = clip_ends(selected_idx);

vid = VideoReader(mp4_path);
framerate = vid.FrameRate;
first_frame = read(vid, 1);
first_frame = v02_ensure_rgb_uint8(first_frame);
if video_scale ~= 1
    first_frame = imresize(first_frame, video_scale);
end

frame_height = size(first_frame, 1);
frame_width = size(first_frame, 2);
strip_height = max(36, round(frame_height * 0.065));
final_height = strip_height + frame_height;
output_framerate = framerate * playback_speed;
title_card_frames = max(1, round(title_card_sec * output_framerate));

if isempty(output_path)
    [video_folder, ~, ~] = fileparts(mp4_path);
    output_name = sprintf('animal%02d_day%02d_randomTrials_tb%g_ta%g_n%d_x%g.mp4', ...
        animal, day, t_before, t_after, n_select, playback_speed);
    output_path = fullfile(video_folder, output_name);
end

[color_map_fn, other_color, nan_color] = v02_make_color_getter();
run_starts = [1; find(diff(syllables) ~= 0) + 1];
run_ends = [run_starts(2:end) - 1; n_rows];
run_syllables = syllables(run_starts);
run_times_start = time_vec(run_starts);
run_times_end = time_vec(run_ends);

writer = VideoWriter(output_path, 'MPEG-4');
writer.FrameRate = output_framerate;
open(writer);

cleanup_writer = onCleanup(@() close(writer));

fprintf('Exporting %d trial clips to:\n%s\n', n_select, output_path);

for i_trial = 1:n_select
    clip_start = clip_starts(i_trial);
    clip_end = clip_ends(i_trial);
    trial_start = trial_starts(i_trial);
    trial_end = trial_ends(i_trial);

    start_row = v02_time_to_row(time_vec, clip_start);
    end_row = v02_time_to_row(time_vec, clip_end);
    start_row = max(1, min(n_rows, start_row));
    end_row = max(start_row, min(n_rows, end_row));

    n_video_frames = max(1, floor(vid.Duration * framerate));
    clip_rows = start_row:end_row;
    clip_rows = clip_rows(isfinite(frame_idx(clip_rows)));
    if isempty(clip_rows)
        warning('v02_exportRandomTrialsMp4:InvalidFrameRange', ...
            'Skipping trial %d because no finite frame indices were found in the clip.', i_trial);
        continue;
    end

    clip_frames = round(frame_idx(clip_rows));
    valid_frame_mask = clip_frames >= 1 & clip_frames <= n_video_frames;
    clip_rows = clip_rows(valid_frame_mask);
    clip_frames = clip_frames(valid_frame_mask);
    if isempty(clip_rows)
        warning('v02_exportRandomTrialsMp4:InvalidFrameRange', ...
            'Skipping trial %d because all clip frames were out of video bounds.', i_trial);
        continue;
    end

    title_card = v02_make_title_card(frame_width, final_height, i_trial, n_select);
    for i_card = 1:title_card_frames
        writeVideo(writer, title_card);
    end

    fprintf('Trial %d/%d: %.2f s to %.2f s\n', i_trial, n_select, trial_start, trial_end);

    for i_clip_frame = 1:numel(clip_frames)
        current_frame = clip_frames(i_clip_frame);
        current_row = clip_rows(i_clip_frame);

        raw_frame = read(vid, current_frame);
        raw_frame = v02_ensure_rgb_uint8(raw_frame);
        if video_scale ~= 1
            raw_frame = imresize(raw_frame, video_scale);
        end

        trail_img = v02_draw_trail(raw_frame, start_row, current_row, ...
            centroid_x, centroid_y, syllables, video_scale, ...
            color_map_fn, other_color, nan_color);

        current_time = time_vec(current_row);
        strip_img = v02_make_syllable_strip(frame_width, strip_height, ...
            clip_start, clip_end, current_time, ...
            run_times_start, run_times_end, run_syllables, ...
            color_map_fn, other_color, nan_color);

        output_frame = cat(1, strip_img, trail_img);
        writeVideo(writer, output_frame);
    end
end

clear cleanup_writer
fprintf('Finished writing MP4:\n%s\n', output_path);

function [trial_starts, trial_ends] = v02_pair_trial_intervals(d_old)
trial_starts = [];
trial_ends = [];

if ~istable(d_old) || ...
        ~ismember('time', d_old.Properties.VariableNames) || ...
        ~ismember('type', d_old.Properties.VariableNames)
    return;
end

event_times = d_old.time;
event_types = d_old.type;
valid_events = isfinite(event_times);

start_times = sort(event_times(valid_events & strcmp(event_types, 'start_of_trial')));
end_times = sort(event_times(valid_events & strcmp(event_types, 'end_of_trial')));
remaining_end_times = end_times(:);

for i_start = 1:numel(start_times)
    next_end_idx = find(remaining_end_times > start_times(i_start), 1, 'first');
    if isempty(next_end_idx)
        continue;
    end

    trial_starts(end + 1, 1) = start_times(i_start); %#ok<AGROW>
    trial_ends(end + 1, 1) = remaining_end_times(next_end_idx); %#ok<AGROW>
    remaining_end_times(next_end_idx) = [];
end
end

function row_idx = v02_time_to_row(time_vec, target_time)
[~, row_idx] = min(abs(time_vec - target_time));
end

function [color_map_fn, other_color, nan_color] = v02_make_color_getter()
other_color = [0.15 0.15 0.15];
nan_color = [0.85 0.85 0.85];

has_workspace_colors = evalin('base', 'exist(''cmap20'', ''var'') && exist(''most_common_motifs'', ''var'')');
if has_workspace_colors
    cmap20 = evalin('base', 'cmap20');
    most_common_motifs = evalin('base', 'most_common_motifs');

    if ~isempty(cmap20) && ~isempty(most_common_motifs)
        syl_to_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
        max_idx = min(numel(most_common_motifs), size(cmap20, 1));
        for i_syl = 1:max_idx
            syl_to_idx(most_common_motifs(i_syl)) = i_syl;
        end

        color_map_fn = @(syl) v02_get_workspace_color(syl, syl_to_idx, cmap20, other_color, nan_color);
        return;
    end
end

fallback_palette = lines(20);
color_map_fn = @(syl) v02_get_fallback_color(syl, fallback_palette, other_color, nan_color);
end

function color = v02_get_workspace_color(syl, syl_to_idx, cmap20, other_color, nan_color)
if ~isfinite(syl)
    color = nan_color;
elseif isKey(syl_to_idx, syl)
    color = cmap20(syl_to_idx(syl), :);
else
    color = other_color;
end
end

function color = v02_get_fallback_color(syl, palette, other_color, nan_color)
if ~isfinite(syl)
    color = nan_color;
    return;
end

if syl < 0 || abs(syl - round(syl)) > 1e-9
    color = other_color;
    return;
end

idx = mod(round(syl), size(palette, 1)) + 1;
color = palette(idx, :);
end

function frame_rgb = v02_ensure_rgb_uint8(frame_in)
if isa(frame_in, 'uint8')
    frame_rgb = frame_in;
elseif isfloat(frame_in)
    frame_rgb = im2uint8(mat2gray(frame_in));
else
    frame_rgb = uint8(frame_in);
end

if ndims(frame_rgb) == 2
    frame_rgb = repmat(frame_rgb, 1, 1, 3);
elseif size(frame_rgb, 3) == 1
    frame_rgb = repmat(frame_rgb, 1, 1, 3);
end
end

function title_card = v02_make_title_card(frame_width, frame_height, trial_idx, n_trials)
title_card = zeros(frame_height, frame_width, 3, 'uint8');
label = sprintf('Trial %d/%d', trial_idx, n_trials);
position = [round(frame_width * 0.32), round(frame_height * 0.45)];
title_card = insertText(title_card, position, label, ...
    'FontSize', 32, ...
    'TextColor', 'white', ...
    'BoxOpacity', 0, ...
    'AnchorPoint', 'LeftTop');
end

function frame_out = v02_draw_trail(frame_in, trail_start_row, current_row, ...
        centroid_x, centroid_y, syllables, video_scale, ...
        color_map_fn, other_color, nan_color)
frame_out = frame_in;

if current_row <= trail_start_row
    return;
end

trail_x = centroid_x(trail_start_row:current_row);
trail_y = centroid_y(trail_start_row:current_row);
trail_syl = syllables(trail_start_row:current_row);

if video_scale ~= 1
    trail_x = trail_x * video_scale;
    trail_y = trail_y * video_scale;
end

valid = ~isnan(trail_x) & ~isnan(trail_y);
if nnz(valid) < 2
    return;
end

seg_x1 = [];
seg_y1 = [];
seg_x2 = [];
seg_y2 = [];
seg_syl = [];

for i_seg = 1:(numel(trail_x) - 1)
    if valid(i_seg) && valid(i_seg + 1)
        seg_x1(end + 1, 1) = trail_x(i_seg); %#ok<AGROW>
        seg_y1(end + 1, 1) = trail_y(i_seg); %#ok<AGROW>
        seg_x2(end + 1, 1) = trail_x(i_seg + 1); %#ok<AGROW>
        seg_y2(end + 1, 1) = trail_y(i_seg + 1); %#ok<AGROW>
        seg_syl(end + 1, 1) = trail_syl(i_seg); %#ok<AGROW>
    end
end

if isempty(seg_syl)
    return;
end

unique_syls = unique(seg_syl);
for i_color = 1:numel(unique_syls)
    syl_now = unique_syls(i_color);
    mask = seg_syl == syl_now;
    if ~any(mask)
        continue;
    end

    line_segments = [seg_x1(mask), seg_y1(mask), seg_x2(mask), seg_y2(mask)];
    color = color_map_fn(syl_now);
    if any(~isfinite(color))
        color = other_color;
    end

    frame_out = insertShape(frame_out, 'Line', line_segments, ...
        'Color', uint8(255 * color), 'LineWidth', 3);
end

if any(isnan(seg_syl))
    nan_mask = isnan(seg_syl);
    line_segments = [seg_x1(nan_mask), seg_y1(nan_mask), seg_x2(nan_mask), seg_y2(nan_mask)];
    if ~isempty(line_segments)
        frame_out = insertShape(frame_out, 'Line', line_segments, ...
            'Color', uint8(255 * nan_color), 'LineWidth', 3);
    end
end
end

function strip_img = v02_make_syllable_strip(frame_width, strip_height, ...
        clip_start, clip_end, current_time, ...
        run_times_start, run_times_end, run_syllables, ...
        color_map_fn, other_color, nan_color)

strip_img = uint8(245 * ones(strip_height, frame_width, 3));
segment_duration = max(clip_end - clip_start, eps);

visible_runs = run_times_end >= clip_start & run_times_start <= clip_end;
visible_idx = find(visible_runs);
for i_run = 1:numel(visible_idx)
    idx = visible_idx(i_run);
    run_start = max(run_times_start(idx), clip_start);
    run_end = min(run_times_end(idx), clip_end);
    if run_end <= run_start
        continue;
    end

    x_start = 1 + floor((run_start - clip_start) / segment_duration * frame_width);
    x_end = 1 + ceil((run_end - clip_start) / segment_duration * frame_width);
    x_start = max(1, min(frame_width, x_start));
    x_end = max(x_start, min(frame_width, x_end));

    syl_now = run_syllables(idx);
    color = color_map_fn(syl_now);
    if any(~isfinite(color))
        color = nan_color;
    end

    rgb = reshape(uint8(255 * color), 1, 1, 3);
    strip_img(:, x_start:x_end, :) = repmat(rgb, strip_height, x_end - x_start + 1);

    if (x_end - x_start + 1) >= 30 && isfinite(syl_now)
        text_color = v02_get_label_text_color(color);
        strip_img = insertText(strip_img, [x_start + 4, max(1, round(strip_height * 0.18))], ...
            sprintf('%d', round(syl_now)), ...
            'FontSize', max(12, round(strip_height * 0.45)), ...
            'TextColor', uint8(255 * text_color), ...
            'BoxOpacity', 0, ...
            'AnchorPoint', 'LeftTop');
    end
end

cursor_x = 1 + round((current_time - clip_start) / segment_duration * (frame_width - 1));
cursor_x = max(1, min(frame_width, cursor_x));
cursor_line = [cursor_x, 1, cursor_x, strip_height];
strip_img = insertShape(strip_img, 'Line', cursor_line, ...
    'Color', uint8([255 0 0]), 'LineWidth', 2);

strip_img = insertShape(strip_img, 'Line', [1, strip_height, frame_width, strip_height], ...
    'Color', uint8([200 200 200]), 'LineWidth', 1);

if isempty(visible_idx)
    strip_img(:, :, :) = 255;
    strip_img = insertShape(strip_img, 'Line', cursor_line, ...
        'Color', uint8([255 0 0]), 'LineWidth', 2);
end
end

function text_color = v02_get_label_text_color(fill_color)
luminance = 0.299 * fill_color(1) + 0.587 * fill_color(2) + 0.114 * fill_color(3);
if luminance > 0.6
    text_color = [0 0 0];
else
    text_color = [1 1 1];
end
end
