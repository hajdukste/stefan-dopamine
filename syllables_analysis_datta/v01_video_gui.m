%---------------------- v01_video_gui - Video Player with Syllable Visualization
% Parameters
animal = 5;
day = 5;
trail_duration = 3;   % Trail length in seconds
video_scale = 1;      % Video window scale factor (1 = native size)
seconds_per_view = 150; % Time window for timeseries display
smoothing_window = 5;  % Moving average window size
overlay_update_interval = 3;  % Update overlay every N frames (higher = faster but choppier trail)
trail_is_always_gray = false;  % If true, the video trail ignores syllable colors
trail_gray_color = [0.5 0.5 0.5];

% Run the GUI
v01_video_gui_main(animal, day, trail_duration, video_scale, seconds_per_view, smoothing_window, ...
    overlay_update_interval, trail_is_always_gray, trail_gray_color, all_data, cmap20, most_common_motifs);

function v01_video_gui_main(animal, day, trail_duration, video_scale, seconds_per_view, smoothing_window, ...
    overlay_update_interval, trail_is_always_gray, trail_gray_color, all_data, cmap20, most_common_motifs)
%---------------------- Data Loading
d = all_data(animal).data(day).d;
mp4_path = all_data(animal).data(day).mp4_path;
d_old = [];
if isfield(all_data(animal).data(day), 'd_old') && istable(all_data(animal).data(day).d_old)
    d_old = all_data(animal).data(day).d_old;
end

% Load video
vid = VideoReader(mp4_path);
framerate = vid.FrameRate;
vid_width = vid.Width;
vid_height = vid.Height;
total_video_frames = floor(vid.Duration * framerate);

% Extract arrays from table
time_vec = d.time;
centroid_x = d.centroidX;
centroid_y = d.centroidY;
syllables = d.syllable;
n_rows = height(d);
zsc_exp = [];
has_da_data = false;
da_clip = NaN;
if ismember('zsc_exp', d.Properties.VariableNames) && isnumeric(d.zsc_exp)
    zsc_exp = d.zsc_exp;
    valid_zsc = zsc_exp(isfinite(zsc_exp));
    if ~isempty(valid_zsc)
        abs_sorted = sort(abs(valid_zsc));
        clip_idx = max(1, ceil(0.98 * numel(abs_sorted)));
        da_clip = abs_sorted(clip_idx);
        if ~isfinite(da_clip) || da_clip <= 0
            da_clip = max(abs_sorted);
        end
        has_da_data = isfinite(da_clip) && da_clip > 0;
    end
end

has_trial_event_data = false;
start_of_trial_times = [];
end_of_trial_times = [];
final_approach_times = [];
trial_interval_starts = [];
trial_interval_ends = [];
if istable(d_old) && ismember('time', d_old.Properties.VariableNames) && ...
        ismember('type', d_old.Properties.VariableNames)
    has_trial_event_data = true;
    event_times = d_old.time;
    event_types = d_old.type;
    valid_events = isfinite(event_times);
    start_of_trial_times = event_times(valid_events & strcmp(event_types, 'start_of_trial'));
    end_of_trial_times = event_times(valid_events & strcmp(event_types, 'end_of_trial'));
    final_approach_times = event_times(valid_events & strcmp(event_types, 'final_approach_start'));

    trial_interval_starts = [];
    trial_interval_ends = [];
    remaining_end_times = sort(end_of_trial_times(:));
    sorted_start_times = sort(start_of_trial_times(:));
    for i_start = 1:length(sorted_start_times)
        next_end_idx = find(remaining_end_times > sorted_start_times(i_start), 1, 'first');
        if isempty(next_end_idx)
            continue;
        end

        trial_interval_starts(end + 1, 1) = sorted_start_times(i_start); %#ok<AGROW>
        trial_interval_ends(end + 1, 1) = remaining_end_times(next_end_idx); %#ok<AGROW>
        remaining_end_times(next_end_idx) = [];
    end
end

% Frame offset: d row 1 corresponds to video frame frame_offset+1
% So: video_frame = row + frame_offset, row = video_frame - frame_offset
frame_offset = d.frame_idx(1) - 1;

% Build syllable-to-color map
syl_to_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:length(most_common_motifs)
    syl_to_idx(most_common_motifs(i)) = i;
end
other_color = [0.15 0.15 0.15];
nan_color = [0.9 0.9 0.9];
da_cmap = makeDopamineColormap(256);
da_stripe_offset_px = 10;

% Pre-compute syllable runs for bar visualization
run_starts = [1; find(diff(syllables) ~= 0) + 1];
run_ends = [run_starts(2:end) - 1; n_rows];
run_syllables = syllables(run_starts);
run_times_start = time_vec(run_starts);
run_times_end = time_vec(run_ends);

% Auto-detect numeric columns for traces
col_names = d.Properties.VariableNames;
numeric_cols = {};
for i = 1:length(col_names)
    if isnumeric(d.(col_names{i})) && ~all(isnan(d.(col_names{i})))
        numeric_cols{end+1} = col_names{i};
    end
end

% Default selected traces
default_traces = {'zsc_exp', 'speed_norm'};
selected_traces = default_traces(ismember(default_traces, numeric_cols));

% Speed settings
speed_factors = [1, 3, 5, 10, 20];
current_speed = 1;
base_period = 1 / framerate;

% Trail settings (in terms of d table rows, not video frames)
trail_rows = round(trail_duration * framerate);

% State variables
current_video_frame = 1;
is_playing = false;
xlim_start = time_vec(1);
xlim_end = xlim_start + seconds_per_view;
frame_counter = 0;  % For overlay update throttling
show_trial_lines = false;
show_da_stripe = false;
cached_trail = struct('line_groups', {{}}, 'color_groups', [], ...
    'da_line_groups', {{}}, 'da_color_groups', []);  % Cache trail data grouped by color
video_fig = [];
overview_fig = [];
overview_ax = [];
overview_cursor = [];
overview_row_count = 0;
overview_filter_values = [];
overview_last_valid_filter_text = '';
existing_figures = findall(groot, 'Type', 'figure');

%---------------------- Create Video Figure using vision.VideoPlayer
player = vision.VideoPlayer('Position', [100, 100, vid_width * video_scale + 50, vid_height * video_scale + 80]);

% Read and display first frame
vid.CurrentTime = 0;
frame = readFrame(vid);
if video_scale ~= 1
    frame = imresize(frame, video_scale);
end

% Draw initial overlay on frame
updateTrailCache(1);
frame_with_overlay = drawCachedTrail(frame);
player(frame_with_overlay);

%---------------------- Create Control Figure
screen_size = get(0, 'ScreenSize');
ctrl_height = 500;
ctrl_fig_pos = [screen_size(1), screen_size(2) + screen_size(4) - ctrl_height, ...
    screen_size(3), ctrl_height];
left_margin = 20;
right_margin = 20;
control_col_width = 155;
control_gap = 18;
plot_left = left_margin + control_col_width + control_gap;
plot_width = ctrl_fig_pos(3) - plot_left - right_margin;
slider_y = 20;
slider_height = 25;
syl_y = 58;
syl_height = 34;
ts_y = 108;
ts_height = ctrl_height - ts_y - 18;
slider_x = 215;
time_text_width = 120;
slider_width = ctrl_fig_pos(3) - slider_x - time_text_width - right_margin - 10;
time_text_x = slider_x + slider_width + 10;

ctrl_fig = figure('Name', 'Controls', 'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', ctrl_fig_pos, ...
    'WindowKeyPressFcn', @figureKeyPress, ...
    'CloseRequestFcn', @closeFigures);

% Timeseries axes
ts_ax = axes(ctrl_fig, 'Units', 'pixels', 'Position', [plot_left, ts_y, plot_width, ts_height]);
hold(ts_ax, 'on');
ylabel(ts_ax, 'Value');
xlabel(ts_ax, 'Time (s)');
set(ts_ax, 'ButtonDownFcn', @timeseriesClickCallback);

% Syllable bar axes
syl_ax = axes(ctrl_fig, 'Units', 'pixels', 'Position', [plot_left, syl_y, plot_width, syl_height]);
hold(syl_ax, 'on');
set(syl_ax, 'YTick', [], 'Box', 'on');
ylabel(syl_ax, 'Syl');

% Vertical time indicator line
ts_line = xline(ts_ax, time_vec(1), 'r', 'LineWidth', 1.5);
syl_line = xline(syl_ax, time_vec(1), 'r', 'LineWidth', 1.5);

%---------------------- UI Controls
% Play/Pause button
play_btn = uicontrol(ctrl_fig, 'Style', 'togglebutton', ...
    'String', 'Play', 'Position', [20, 20, 60, 30], ...
    'Callback', @playPauseCallback);

% Speed dropdown
uicontrol(ctrl_fig, 'Style', 'text', 'String', 'Speed:', ...
    'Position', [90, 20, 40, 25], 'HorizontalAlignment', 'right', ...
    'BackgroundColor', 'w');
speed_dropdown = uicontrol(ctrl_fig, 'Style', 'popupmenu', ...
    'String', {'1x', '3x', '5x', '10x', '20x'}, ...
    'Position', [135, 20, 60, 30], 'Value', 1, ...
    'Callback', @speedCallback);

% Timeline slider
slider = uicontrol(ctrl_fig, 'Style', 'slider', ...
    'Min', 1, 'Max', total_video_frames, 'Value', 1, ...
    'Position', [slider_x, slider_y, slider_width, slider_height], ...
    'Callback', @sliderCallback);

% Time display
time_text = uicontrol(ctrl_fig, 'Style', 'text', ...
    'String', sprintf('%.1f / %.1f s', 0, vid.Duration), ...
    'Position', [time_text_x, slider_y, time_text_width, slider_height], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w');

% Trace selection listbox
uicontrol(ctrl_fig, 'Style', 'text', 'String', 'Traces:', ...
    'Position', [20, 440, 80, 20], 'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w');
trace_listbox = uicontrol(ctrl_fig, 'Style', 'listbox', ...
    'String', numeric_cols, 'Position', [20, 200, control_col_width - 5, 240], ...
    'Max', 100, 'Min', 0, ...
    'Value', find(ismember(numeric_cols, selected_traces)), ...
    'Callback', @traceToggleCallback);

% Smoothing control
uicontrol(ctrl_fig, 'Style', 'text', 'String', 'Smooth:', ...
    'Position', [20, 160, 50, 20], 'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w');
smooth_edit = uicontrol(ctrl_fig, 'Style', 'edit', ...
    'String', num2str(smoothing_window), ...
    'Position', [75, 160, 40, 25], ...
    'Callback', @smoothingCallback);

% View window control
uicontrol(ctrl_fig, 'Style', 'text', 'String', 'Window:', ...
    'Position', [20, 130, 50, 20], 'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w');
window_edit = uicontrol(ctrl_fig, 'Style', 'edit', ...
    'String', num2str(seconds_per_view), ...
    'Position', [75, 130, 40, 25], ...
    'Callback', @windowCallback);

overview_btn = uicontrol(ctrl_fig, 'Style', 'pushbutton', ...
    'String', 'Overview', ...
    'Position', [20, 98, 72, 24], ...
    'Callback', @overviewButtonCallback);
overview_filter_edit = uicontrol(ctrl_fig, 'Style', 'edit', ...
    'String', overview_last_valid_filter_text, ...
    'Position', [95, 98, 72, 24], ...
    'TooltipString', 'Empty = all syllables; example: [0 2 3]', ...
    'Callback', @overviewFilterCallback);

trial_lines_enable = 'off';
if has_trial_event_data
    trial_lines_enable = 'on';
end
trial_lines_chk = uicontrol(ctrl_fig, 'Style', 'checkbox', ...
    'String', 'Trial lines', 'Value', 0, ...
    'Position', [20, 68, 120, 22], ...
    'Enable', trial_lines_enable, ...
    'BackgroundColor', 'w', ...
    'Callback', @trialLinesCallback);

da_stripe_enable = 'off';
if has_da_data
    da_stripe_enable = 'on';
end
da_stripe_chk = uicontrol(ctrl_fig, 'Style', 'checkbox', ...
    'String', 'DA stripe', 'Value', 0, ...
    'Position', [20, 42, 120, 22], ...
    'Enable', da_stripe_enable, ...
    'BackgroundColor', 'w', ...
    'Callback', @daStripeCallback);

%---------------------- Timer Setup
timer_obj = timer('ExecutionMode', 'fixedRate', ...
    'Period', max(0.001, base_period), ...
    'TimerFcn', @timerCallback);

%---------------------- Initial Plot
plotTraces();
plotSyllableBar();
time_text.String = sprintf('%.1f / %.1f s', time_vec(1), time_vec(end));
captureVideoFigureHandle();

%---------------------- Helper Functions
    function color = getSyllableColor(syl)
        if trail_is_always_gray
            color = trail_gray_color;
            return;
        end

        if isnan(syl) || syl < 0
            color = nan_color;
        elseif syl_to_idx.isKey(syl)
            color = cmap20(syl_to_idx(syl), :);
        else
            color = other_color;
        end
    end

    function updateTrailCache(video_frame)
        % Find corresponding d table row for this video frame
        current_row = video_frame - frame_offset;
        if current_row < 1 || current_row > n_rows
            cached_trail.line_groups = {};
            cached_trail.color_groups = [];
            cached_trail.da_line_groups = {};
            cached_trail.da_color_groups = [];
            return;
        end

        % Get trail data (recent rows in d table)
        trail_start_row = max(1, current_row - trail_rows);
        trail_end_row = current_row;

        trail_x = centroid_x(trail_start_row:trail_end_row);
        trail_y = centroid_y(trail_start_row:trail_end_row);
        trail_syl = syllables(trail_start_row:trail_end_row);
        if has_da_data
            trail_da = zsc_exp(trail_start_row:trail_end_row);
        else
            trail_da = [];
        end

        % Scale coordinates if video is scaled
        if video_scale ~= 1
            trail_x = trail_x * video_scale;
            trail_y = trail_y * video_scale;
        end

        % Build line segments - find consecutive valid points
        valid = ~isnan(trail_x) & ~isnan(trail_y);
        n_pts = length(trail_x);

        % Build all valid segments first
        seg_x1 = []; seg_y1 = []; seg_x2 = []; seg_y2 = []; seg_syl = []; seg_da = [];
        for i = 1:n_pts-1
            if valid(i) && valid(i+1)
                seg_x1 = [seg_x1; trail_x(i)];
                seg_y1 = [seg_y1; trail_y(i)];
                seg_x2 = [seg_x2; trail_x(i+1)];
                seg_y2 = [seg_y2; trail_y(i+1)];
                seg_syl = [seg_syl; trail_syl(i)];
                if has_da_data
                    seg_da = [seg_da; trail_da(i)];
                end
            end
        end

        if isempty(seg_syl)
            cached_trail.line_groups = {};
            cached_trail.color_groups = [];
            cached_trail.da_line_groups = {};
            cached_trail.da_color_groups = [];
            return;
        end

        % Group segments by syllable for batch drawing
        unique_syls = unique(seg_syl);
        cached_trail.line_groups = cell(length(unique_syls), 1);
        cached_trail.color_groups = zeros(length(unique_syls), 3, 'uint8');

        for c = 1:length(unique_syls)
            syl = unique_syls(c);
            mask = seg_syl == syl;
            % Build N×4 matrix of line segments [x1, y1, x2, y2] for this color
            cached_trail.line_groups{c} = [seg_x1(mask), seg_y1(mask), seg_x2(mask), seg_y2(mask)];
            cached_trail.color_groups(c,:) = uint8(getSyllableColor(syl) * 255);
        end

        cached_trail.da_line_groups = {};
        cached_trail.da_color_groups = [];
        if has_da_data
            valid_da = isfinite(seg_da);
            if any(valid_da)
                da_segments = [seg_x1(valid_da) + da_stripe_offset_px, seg_y1(valid_da), ...
                    seg_x2(valid_da) + da_stripe_offset_px, seg_y2(valid_da)];
                da_indices = mapDopamineValuesToColorIdx(seg_da(valid_da));
                unique_da_idx = unique(da_indices);
                cached_trail.da_line_groups = cell(length(unique_da_idx), 1);
                cached_trail.da_color_groups = zeros(length(unique_da_idx), 3, 'uint8');

                for c = 1:length(unique_da_idx)
                    idx_now = unique_da_idx(c);
                    mask = da_indices == idx_now;
                    cached_trail.da_line_groups{c} = da_segments(mask, :);
                    cached_trail.da_color_groups(c,:) = uint8(da_cmap(idx_now, :) * 255);
                end
            end
        end
    end

    function frame_out = drawCachedTrail(frame_in)
        frame_out = frame_in;

        if isempty(cached_trail.line_groups)
            return;
        end

        % Draw all line groups (one insertShape call per color - FAST!)
        for c = 1:length(cached_trail.line_groups)
            if ~isempty(cached_trail.line_groups{c})
                frame_out = insertShape(frame_out, 'Line', ...
                    cached_trail.line_groups{c}, ...
                    'Color', cached_trail.color_groups(c,:), ...
                    'LineWidth', 3);
            end
        end

        if show_da_stripe && has_da_data
            for c = 1:length(cached_trail.da_line_groups)
                if ~isempty(cached_trail.da_line_groups{c})
                    frame_out = insertShape(frame_out, 'Line', ...
                        cached_trail.da_line_groups{c}, ...
                        'Color', cached_trail.da_color_groups(c,:), ...
                        'LineWidth', 3);
                end
            end
        end
    end

    function idx = mapDopamineValuesToColorIdx(values)
        clipped_vals = min(max(values, -da_clip), da_clip);
        scaled_vals = (clipped_vals + da_clip) ./ (2 * da_clip);
        idx = 1 + floor(scaled_vals * (size(da_cmap, 1) - 1));
        idx = min(max(idx, 1), size(da_cmap, 1));
    end

    function cmap = makeDopamineColormap(n_colors)
        n_left = floor(n_colors / 2);
        n_right = n_colors - n_left;
        blue_to_white = [linspace(0, 1, n_left)', linspace(0, 1, n_left)', ones(n_left, 1)];
        white_to_red = [ones(n_right, 1), linspace(1, 0, n_right)', linspace(1, 0, n_right)'];
        cmap = [blue_to_white; white_to_red];
    end

    function text_color = getLabelTextColor(fill_color)
        luminance = 0.299 * fill_color(1) + 0.587 * fill_color(2) + 0.114 * fill_color(3);
        if luminance > 0.6
            text_color = [0 0 0];
        else
            text_color = [1 1 1];
        end
    end

    function drawSyllableSegment(ax, x_start, x_end, y_start, y_height, syl)
        if x_end <= x_start
            return;
        end

        color = getSyllableColor(syl);
        rect_handle = rectangle(ax, 'Position', [x_start, y_start, x_end - x_start, y_height], ...
            'FaceColor', color, 'EdgeColor', 'none');
        label_pad = min(0.05, 0.1 * max(x_end - x_start, eps));
        text_handle = text(ax, x_start + label_pad, y_start + y_height / 2, sprintf('%d', syl), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'Clipping', 'on', 'Color', getLabelTextColor(color), ...
            'FontWeight', 'bold');

        if ~isempty(overview_ax) && isgraphics(overview_ax) && isequal(ax, overview_ax)
            set(rect_handle, 'ButtonDownFcn', @overviewClickCallback);
            set(text_handle, 'ButtonDownFcn', @overviewClickCallback);
        end
    end

    function current_time = getCurrentTime()
        current_row = max(1, min(n_rows, current_video_frame - frame_offset));
        current_time = time_vec(current_row);
    end

    function [filter_values, is_valid] = parseOverviewFilter(filter_text)
        filter_text = strtrim(filter_text);
        if isempty(filter_text)
            filter_values = [];
            is_valid = true;
            return;
        end

        if ~isempty(regexp(filter_text, '[^\d\s\[\],;\+\-\.]', 'once'))
            filter_values = [];
            is_valid = false;
            return;
        end

        normalized = regexprep(filter_text, '[\[\],;]', ' ');
        filter_values = sscanf(normalized, '%f').';
        if isempty(filter_values)
            is_valid = false;
            filter_values = [];
            return;
        end

        rounded_vals = round(filter_values);
        is_valid = all(abs(filter_values - rounded_vals) < 1e-9);
        if is_valid
            filter_values = unique(rounded_vals);
        else
            filter_values = [];
        end
    end

    function is_visible = shouldDrawOverviewSyllable(syl)
        is_visible = isempty(overview_filter_values) || ismember(syl, overview_filter_values);
    end

    function addTrialLines(ax)
        if ~show_trial_lines || ~has_trial_event_data
            return;
        end

        addSingleEventType(ax, start_of_trial_times, [1 0 1]);
        addSingleEventType(ax, final_approach_times, [1 0 0]);
        addSingleEventType(ax, end_of_trial_times, [0 0 0]);
    end

    function addSingleEventType(ax, event_times, event_color)
        visible_times = event_times(event_times >= xlim_start & event_times <= xlim_end);
        for i_event = 1:length(visible_times)
            h = xline(ax, visible_times(i_event), '-', 'Color', event_color, 'LineWidth', 1);
            h.Annotation.LegendInformation.IconDisplayStyle = 'off';
            if isequal(ax, ts_ax)
                set(h, 'ButtonDownFcn', @timeseriesClickCallback);
            end
        end
    end

    function addOverviewTrialLines(ax, row_start, row_end, y_base, row_height)
        if ~show_trial_lines || ~has_trial_event_data
            return;
        end

        addOverviewSingleEventType(ax, start_of_trial_times, row_start, row_end, y_base, row_height, [1 0 1]);
        addOverviewSingleEventType(ax, final_approach_times, row_start, row_end, y_base, row_height, [1 0 0]);
        addOverviewSingleEventType(ax, end_of_trial_times, row_start, row_end, y_base, row_height, [0 0 0]);
    end

    function addOverviewTrialShading(ax, row_start, row_end, y_base, row_height)
        if isempty(trial_interval_starts) || isempty(trial_interval_ends)
            return;
        end

        visible = trial_interval_ends >= row_start & trial_interval_starts <= row_end;
        visible_idx = find(visible);
        for i_interval = 1:length(visible_idx)
            idx = visible_idx(i_interval);
            x_start = max(trial_interval_starts(idx), row_start) - row_start;
            x_end = min(trial_interval_ends(idx), row_end) - row_start;
            if x_end <= x_start
                continue;
            end

            h = rectangle(ax, 'Position', [x_start, y_base, x_end - x_start, row_height], ...
                'FaceColor', [0.75 0.75 0.75], 'EdgeColor', 'none', 'FaceAlpha', 0.25);
            set(h, 'ButtonDownFcn', @overviewClickCallback);
        end
    end

    function addOverviewSingleEventType(ax, event_times, row_start, row_end, y_base, row_height, event_color)
        visible_times = event_times(event_times >= row_start & event_times <= row_end);
        for i_event = 1:length(visible_times)
            x_pos = visible_times(i_event) - row_start;
            h = plot(ax, [x_pos, x_pos], [y_base, y_base + row_height], '-', ...
                'Color', event_color, 'LineWidth', 1);
            h.Annotation.LegendInformation.IconDisplayStyle = 'off';
            set(h, 'ButtonDownFcn', @overviewClickCallback);
        end
    end

    function captureVideoFigureHandle()
        if ~isempty(video_fig) && isgraphics(video_fig)
            return;
        end

        try
            drawnow;
            current_figures = findall(groot, 'Type', 'figure');
            new_figures = setdiff(current_figures, existing_figures);
            if ~isempty(ctrl_fig) && isgraphics(ctrl_fig)
                new_figures(new_figures == ctrl_fig) = [];
            end
            if ~isempty(new_figures)
                video_fig = new_figures(1);
                set(video_fig, 'WindowKeyPressFcn', @figureKeyPress);
            end
        catch
            video_fig = [];
        end
    end

    function renderCurrentFrame()
        current_video_frame = max(1, min(total_video_frames, round(current_video_frame)));
        vid.CurrentTime = max(0, (current_video_frame - 1) / framerate);
        if ~hasFrame(vid)
            return;
        end

        frame = readFrame(vid);
        if video_scale ~= 1
            frame = imresize(frame, video_scale);
        end

        updateTrailCache(current_video_frame);
        frame_with_overlay = drawCachedTrail(frame);
        player(frame_with_overlay);
        captureVideoFigureHandle();
    end

    function refreshCurrentFramePreservePlayback()
        was_playing = is_playing;
        if was_playing
            togglePlayback(false);
        end

        renderCurrentFrame();

        if was_playing
            togglePlayback(true);
        end
    end

    function openOverviewFigure()
        if isempty(overview_fig) || ~isgraphics(overview_fig)
            overview_fig = figure('Name', 'Syllable Overview', 'NumberTitle', 'off', ...
                'Color', 'w', ...
                'Position', screen_size, ...
                'CloseRequestFcn', @overviewCloseCallback, ...
                'SizeChangedFcn', @overviewSizeChanged);
            overview_ax = axes(overview_fig, 'Units', 'pixels');
        else
            figure(overview_fig);
        end

        refreshOverviewFigure();
    end

    function refreshOverviewFigure()
        if isempty(overview_fig) || ~isgraphics(overview_fig)
            return;
        end

        if isempty(overview_ax) || ~isgraphics(overview_ax)
            overview_ax = axes(overview_fig, 'Units', 'pixels');
        end

        fig_pos = get(overview_fig, 'Position');
        ax_pos = [70, 35, max(120, fig_pos(3) - 95), max(120, fig_pos(4) - 60)];
        set(overview_ax, 'Units', 'pixels', 'Position', ax_pos);
        cla(overview_ax);
        hold(overview_ax, 'on');
        set(overview_ax, 'ButtonDownFcn', @overviewClickCallback);

        row_height_px = 24;
        row_gap_px = 4;
        overview_row_count = max(1, floor((ax_pos(4) + row_gap_px) / (row_height_px + row_gap_px)));
        row_height = 0.9;
        row_pad = 0.05;
        y_ticks = zeros(1, overview_row_count);
        y_labels = cell(1, overview_row_count);

        for row_idx = 1:overview_row_count
            row_start = (row_idx - 1) * seconds_per_view;
            row_end = row_start + seconds_per_view;
            y_base = row_idx - 1 + row_pad;
            y_ticks(row_idx) = row_idx - 0.5;
            y_labels{row_idx} = sprintf('%.0f-%.0f', row_start, row_end);
            addOverviewTrialShading(overview_ax, row_start, row_end, y_base, row_height);

            visible = run_times_end >= row_start & run_times_start <= row_end;
            visible_idx = find(visible);

            for i = 1:length(visible_idx)
                idx = visible_idx(i);
                if ~shouldDrawOverviewSyllable(run_syllables(idx))
                    continue;
                end

                x_start = max(run_times_start(idx), row_start) - row_start;
                x_end = min(run_times_end(idx), row_end) - row_start;
                drawSyllableSegment(overview_ax, x_start, x_end, y_base, row_height, run_syllables(idx));
            end

            addOverviewTrialLines(overview_ax, row_start, row_end, y_base, row_height);
        end

        xlim(overview_ax, [0, seconds_per_view]);
        ylim(overview_ax, [0, overview_row_count]);
        set(overview_ax, 'YDir', 'reverse', ...
            'YTick', y_ticks, ...
            'YTickLabel', y_labels, ...
            'Box', 'on');
        xlabel(overview_ax, 'Time In Window (s)');
        ylabel(overview_ax, 'Session Windows');
        title(overview_ax, 'Stacked Syllable Overview');

        updateOverviewCursor(getCurrentTime());
    end

    function updateOverviewCursor(current_time)
        if isempty(overview_fig) || ~isgraphics(overview_fig) || ...
                isempty(overview_ax) || ~isgraphics(overview_ax)
            return;
        end

        if ~isempty(overview_cursor) && isgraphics(overview_cursor)
            delete(overview_cursor);
        end
        overview_cursor = [];

        if seconds_per_view <= 0
            return;
        end

        row_idx = floor(current_time / seconds_per_view) + 1;
        if row_idx < 1 || row_idx > overview_row_count
            return;
        end

        row_start = (row_idx - 1) * seconds_per_view;
        x_now = current_time - row_start;
        y_base = row_idx - 1 + 0.05;
        overview_cursor = plot(overview_ax, [x_now, x_now], [y_base, y_base + 0.9], ...
            'r-', 'LineWidth', 1.5);
        set(overview_cursor, 'ButtonDownFcn', @overviewClickCallback);
    end

    function syncCurrentTimeDisplays(current_time)
        time_text.String = sprintf('%.1f / %.1f s', current_time, time_vec(end));
        if ~isempty(ts_line) && isgraphics(ts_line)
            ts_line.Value = current_time;
        end
        if ~isempty(syl_line) && isgraphics(syl_line)
            syl_line.Value = current_time;
        end
        updateOverviewCursor(current_time);
    end

    function plotTraces()
        cla(ts_ax);
        hold(ts_ax, 'on');
        set(ts_ax, 'ButtonDownFcn', @timeseriesClickCallback);

        selected_idx = trace_listbox.Value;
        selected_names = numeric_cols(selected_idx);
        colors = lines(length(selected_names));
        legend_entries = {};
        trace_handles = gobjects(0);

        for i = 1:length(selected_names)
            name = selected_names{i};
            data = d.(name);

            % Apply smoothing
            if smoothing_window > 1
                data = movmean(data, smoothing_window, 'omitnan');
            end

            trace_handles(end+1) = plot(ts_ax, time_vec, data, 'Color', colors(i,:), 'LineWidth', 1, ...
                'ButtonDownFcn', @timeseriesClickCallback); %#ok<AGROW>
            legend_entries{end+1} = name;
        end

        if ~isempty(trace_handles)
            legend(ts_ax, trace_handles, legend_entries, 'Location', 'northeast', 'Interpreter', 'none');
        else
            legend(ts_ax, 'off');
        end

        xlim(ts_ax, [xlim_start, xlim_end]);
        ylabel(ts_ax, 'Value');
        xlabel(ts_ax, 'Time (s)');

        addTrialLines(ts_ax);

        current_row = max(1, min(n_rows, current_video_frame - frame_offset));
        ts_line = xline(ts_ax, time_vec(current_row), 'r', 'LineWidth', 1.5);
        ts_line.Annotation.LegendInformation.IconDisplayStyle = 'off';
        set(ts_line, 'ButtonDownFcn', @timeseriesClickCallback);
    end

    function plotSyllableBar()
        cla(syl_ax);
        hold(syl_ax, 'on');

        % Only draw visible runs
        visible = run_times_end >= xlim_start & run_times_start <= xlim_end;
        visible_idx = find(visible);

        for i = 1:length(visible_idx)
            idx = visible_idx(i);
            x_start = max(run_times_start(idx), xlim_start);
            x_end = min(run_times_end(idx), xlim_end);
            drawSyllableSegment(syl_ax, x_start, x_end, 0, 1, run_syllables(idx));
        end

        xlim(syl_ax, [xlim_start, xlim_end]);
        ylim(syl_ax, [0, 1]);
        addTrialLines(syl_ax);

        % Get current time for line
        current_row = max(1, min(n_rows, current_video_frame - frame_offset));
        current_time = time_vec(current_row);
        syl_line = xline(syl_ax, current_time, 'r', 'LineWidth', 1.5);
        syl_line.Annotation.LegendInformation.IconDisplayStyle = 'off';
        set(syl_ax, 'YTick', []);
        updateOverviewCursor(current_time);
    end

%---------------------- Callbacks
    function timerCallback(~, ~)
        if ~isOpen(player)
            stop(timer_obj);
            return;
        end

        % Read next frame sequentially (fast - no seeking)
        if ~hasFrame(vid)
            stop(timer_obj);
            play_btn.Value = 0;
            play_btn.String = 'Play';
            is_playing = false;
            current_video_frame = total_video_frames;
            return;
        end

        frame = readFrame(vid);
        current_video_frame = round(vid.CurrentTime * framerate) + 1;
        frame_counter = frame_counter + 1;

        if video_scale ~= 1
            frame = imresize(frame, video_scale);
        end

        % Update trail cache every N frames (scaled by speed for performance)
        effective_interval = overlay_update_interval * current_speed;
        if mod(frame_counter, effective_interval) == 0 || isempty(cached_trail.line_groups)
            updateTrailCache(current_video_frame);
        end

        % Always draw the cached trail
        frame_with_overlay = drawCachedTrail(frame);
        player(frame_with_overlay);
        captureVideoFigureHandle();

        % Update slider
        slider.Value = current_video_frame;

        % Get current time from d table
        current_row = max(1, min(n_rows, current_video_frame - frame_offset));
        current_time = time_vec(current_row);

        % Update time display
        syncCurrentTimeDisplays(current_time);

        % Auto-scroll if needed
        if current_time > xlim_end || current_time < xlim_start
            xlim_start = floor(current_time / seconds_per_view) * seconds_per_view;
            xlim_end = xlim_start + seconds_per_view;
            plotTraces();
            plotSyllableBar();
        end
    end

    function playPauseCallback(src, ~)
        togglePlayback(logical(src.Value));
    end

    function togglePlayback(force_state)
        if nargin < 1
            force_state = ~is_playing;
        end

        if force_state
            if strcmp(timer_obj.Running, 'off')
                start(timer_obj);
            end
            is_playing = true;
            play_btn.Value = 1;
            play_btn.String = 'Pause';
        else
            if strcmp(timer_obj.Running, 'on')
                stop(timer_obj);
            end
            is_playing = false;
            play_btn.Value = 0;
            play_btn.String = 'Play';
        end
    end

    function speedCallback(src, ~)
        current_speed = speed_factors(src.Value);
        new_period = max(0.001, base_period / current_speed);
        frame_counter = 0;  % Reset so overlay updates with new interval
        cached_trail.line_groups = {};  % Reset cache
        cached_trail.color_groups = [];
        cached_trail.da_line_groups = {};
        cached_trail.da_color_groups = [];

        was_running = strcmp(timer_obj.Running, 'on');
        if was_running
            stop(timer_obj);
        end
        set(timer_obj, 'Period', new_period);
        if was_running
            start(timer_obj);
        end
    end

    function sliderCallback(src, ~)
        % Pause during seeking
        was_playing = is_playing;
        if is_playing
            togglePlayback(false);
        end

        current_video_frame = round(src.Value);
        frame_counter = 0;  % Reset counter

        % Update video
        renderCurrentFrame();

        % Get current time
        current_row = max(1, min(n_rows, current_video_frame - frame_offset));
        current_time = time_vec(current_row);

        % Update time display
        syncCurrentTimeDisplays(current_time);

        % Update view if needed
        if current_time > xlim_end || current_time < xlim_start
            xlim_start = floor(current_time / seconds_per_view) * seconds_per_view;
            xlim_end = xlim_start + seconds_per_view;
            plotTraces();
            plotSyllableBar();
        end

        % Resume if was playing
        if was_playing
            togglePlayback(true);
        end
    end

    function jumpToTime(target_time)
        target_time = min(max(target_time, time_vec(1)), time_vec(end));
        [~, current_row] = min(abs(time_vec - target_time));
        current_video_frame = current_row + frame_offset;
        current_video_frame = max(1, min(total_video_frames, round(current_video_frame)));
        slider.Value = current_video_frame;
        frame_counter = 0;

        was_playing = is_playing;
        if was_playing
            togglePlayback(false);
        end

        renderCurrentFrame();

        current_time = time_vec(current_row);
        syncCurrentTimeDisplays(current_time);

        if current_time > xlim_end || current_time < xlim_start
            xlim_start = floor(current_time / seconds_per_view) * seconds_per_view;
            xlim_end = xlim_start + seconds_per_view;
            plotTraces();
            plotSyllableBar();
        end

        if was_playing
            togglePlayback(true);
        end
    end

    function overviewButtonCallback(~, ~)
        openOverviewFigure();
    end

    function overviewFilterCallback(src, ~)
        [parsed_values, is_valid] = parseOverviewFilter(src.String);
        if is_valid
            overview_filter_values = parsed_values;
            overview_last_valid_filter_text = strtrim(src.String);
            if isempty(overview_last_valid_filter_text)
                overview_last_valid_filter_text = '';
            end
            if ~isempty(overview_fig) && isgraphics(overview_fig)
                refreshOverviewFigure();
            end
        else
            src.String = overview_last_valid_filter_text;
        end
    end

    function overviewSizeChanged(~, ~)
        if ~isempty(overview_fig) && isgraphics(overview_fig)
            refreshOverviewFigure();
        end
    end

    function overviewCloseCallback(~, ~)
        if ~isempty(overview_fig) && isgraphics(overview_fig)
            delete(overview_fig);
        end
        overview_fig = [];
        overview_ax = [];
        overview_cursor = [];
        overview_row_count = 0;
    end

    function overviewClickCallback(~, ~)
        if isempty(overview_ax) || ~isgraphics(overview_ax) || seconds_per_view <= 0
            return;
        end

        click_point = get(overview_ax, 'CurrentPoint');
        x_click = click_point(1, 1);
        y_click = click_point(1, 2);

        if x_click < 0 || x_click > seconds_per_view || y_click < 0 || y_click > overview_row_count
            return;
        end

        row_idx = floor(y_click) + 1;
        if row_idx < 1 || row_idx > overview_row_count
            return;
        end

        target_time = (row_idx - 1) * seconds_per_view + x_click;
        jumpToTime(target_time);
    end

    function timeseriesClickCallback(~, ~)
        click_point = get(ts_ax, 'CurrentPoint');
        jumpToTime(click_point(1, 1));
    end

    function traceToggleCallback(~, ~)
        plotTraces();
    end

    function smoothingCallback(src, ~)
        val = str2double(src.String);
        if ~isnan(val) && val >= 1
            smoothing_window = round(val);
            plotTraces();
        else
            src.String = num2str(smoothing_window);
        end
    end

    function windowCallback(src, ~)
        val = str2double(src.String);
        if ~isnan(val) && val > 0
            seconds_per_view = val;
            xlim_end = xlim_start + seconds_per_view;
            plotTraces();
            plotSyllableBar();
            refreshOverviewFigure();
        else
            src.String = num2str(seconds_per_view);
        end
    end

    function trialLinesCallback(src, ~)
        show_trial_lines = logical(src.Value);
        plotTraces();
        plotSyllableBar();
        if ~isempty(overview_fig) && isgraphics(overview_fig)
            refreshOverviewFigure();
        end
    end

    function daStripeCallback(src, ~)
        show_da_stripe = logical(src.Value);
        refreshCurrentFramePreservePlayback();
    end

    function figureKeyPress(~, evt)
        if strcmp(evt.Key, 'space')
            togglePlayback();
        end
    end

    function closeFigures(~, ~)
        % Stop timer and close
        if isvalid(timer_obj)
            stop(timer_obj);
            delete(timer_obj);
        end
        if isvalid(ctrl_fig)
            delete(ctrl_fig);
        end
        if ~isempty(overview_fig) && isgraphics(overview_fig)
            delete(overview_fig);
        end
        release(player);
    end

end % v01_video_gui_main
