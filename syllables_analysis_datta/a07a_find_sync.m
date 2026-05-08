% a07a_find_sync.m
% Improved video-FIP synchronization using clean 4-light traces
%
% Improvements over a02:
% - Uses individual light traces (ttl_data2) instead of noisy combined trace
% - Uses reference signal to filter false positive video onsets
% - Uses all matched onset pairs for robust linear fit
% - No manual std_factor tuning required

% Configuration
params = struct();
params.mad_factor = 50;           % threshold = median + k*MAD (for 4-light traces)
params.mad_factor_combined = 0.01;   % threshold for combined ttl_trace
params.min_off_duration = 3;   % signal must be below threshold for this long before new onset (seconds)
params.ref_threshold = 0.5;      % reference binary threshold
params.match_tolerance = 5;      % initial matching window (seconds)
params.outlier_threshold = 0.5;  % for outlier rejection (seconds)
params.max_outlier_iters = 3;    % max outlier removal iterations
params.good_threshold_ms = 100;  % what counts as "good" match

plot_mode = 0;  % 0 = full plots per animal/day, 1 = scatter summary
plot_not_100_only = false;  % in scatter mode, only plot recordings with <100% match
animals = 2;
days = 5;

if length(days) == 1
    plot_mode = 0;
else
    plot_mode = 1;
end

% skip bad recordings
skip_list = [1, 3];  % [animal, day] pairs to skip

% Override for split video processing
if exist('loading_split_video', 'var') && loading_split_video
    animals = 1;
    days = 1:2;
    skip_list = [];
end

% special case: clamp outlier threshold for specific animal/day
% if one threshold is 3x higher than all others, set it to max of the rest
clamp_outlier_threshold = [2, 1];  % [animal, day]

% spline fitting for error visualization
n_splines = 50;
pyenv('Version', '/opt/anaconda3/envs/pygam/bin/python');

if plot_mode == 1
    [fig_scatter, tl_scatter] = myFigure(-length(animals)*length(days), [], 400, 300, true);
end

% Main Loop
for animal = animals
for day = days

% skip bad recordings
if ~isempty(skip_list) && any(all(skip_list == [animal, day], 2))
    continue;
end

fprintf('\n=== Processing A%d D%d ===\n', animal, day);

% 1. Load data
% Check if ttl_data2 exists
if ~isfield(all_data(animal).data(day), 'ttl_data2')
    fprintf('Skipping A%d D%d: no ttl_data2\n', animal, day);
    continue;
end

ttl_traces = all_data(animal).data(day).ttl_data2.ttl_traces;
ttl_time = all_data(animal).data(day).ttl_data2.ttl_time;
n_lights = size(ttl_traces, 2);

% Also load ttl_data (combined trace) if exists
if isfield(all_data(animal).data(day), 'ttl_data')
    ttl_trace_combined = all_data(animal).data(day).ttl_data.ttl_trace;
    has_ttl_data = true;
else
    ttl_trace_combined = sum(ttl_traces, 2);  % fallback: sum of 4 lights
    has_ttl_data = false;
end

% Load reference (try fip.reference first, then d.reference)
has_reference = false;
if isfield(all_data(animal).data(day), 'fip')
    fip = all_data(animal).data(day).fip;
    % fip is a table, check for reference column
    if istable(fip) && ismember('reference', fip.Properties.VariableNames)
        ref_signal = fip.reference;
        ref_time = fip.time;
        has_reference = true;
        ref_source = 'fip';
    elseif isstruct(fip) && isfield(fip, 'reference')
        ref_signal = fip.reference;
        ref_time = fip.time;
        has_reference = true;
        ref_source = 'fip';
    end
end

if ~has_reference
    fprintf('Skipping A%d D%d: no reference signal\n', animal, day);
    continue;
end

% 2. Detect video onsets from clean individual lights

% First pass: compute thresholds for all lights
thresholds = NaN(1, n_lights);
for light = 1:n_lights
    trace = ttl_traces(:, light);
    if all(trace == 0) || std(trace) < 1e-6
        continue;
    end

    % Robust threshold using MAD
    baseline = median(trace);
    mad_val = median(abs(trace - baseline));
    if mad_val < 1e-6
        mad_val = std(trace);  % fallback to std if MAD is zero
    end
    thresholds(light) = baseline + params.mad_factor * mad_val;
end

% Special case: clamp outlier threshold if one is 3x higher than all others
clamped_light = 0;  % track which light was clamped (only keep first onset for it)
if any(all(clamp_outlier_threshold == [animal, day], 2))
    valid_thresh = thresholds(~isnan(thresholds));
    if length(valid_thresh) >= 2
        [max_val, max_idx_valid] = max(valid_thresh);
        others = valid_thresh;
        others(max_idx_valid) = [];
        if max_val > 3 * max(others)
            % Find which light has the outlier threshold
            clamped_light = find(thresholds == max_val, 1);
            new_val = max(others);
            fprintf('Clamping outlier threshold: light %d from %.1f to %.1f (first onset only)\n', clamped_light, max_val, new_val);
            thresholds(clamped_light) = new_val;
        end
    end
end

% Second pass: detect onsets using thresholds
all_video_onsets = [];
for light = 1:n_lights
    if isnan(thresholds(light))
        continue;
    end

    trace = ttl_traces(:, light);
    threshold = thresholds(light);

    % Binarize and find rising/falling edges
    binary = trace > threshold;
    rising_edges = find(diff(binary) == 1) + 1;
    falling_edges = find(diff(binary) == -1) + 1;

    % Filter: only keep rising edges preceded by sufficient off-time
    valid_onsets = [];
    for ri = 1:length(rising_edges)
        re = rising_edges(ri);
        % Find the most recent falling edge before this rising edge
        prev_falls = falling_edges(falling_edges < re);
        if isempty(prev_falls)
            % No prior falling edge = signal was below threshold since start
            off_duration = ttl_time(re) - ttl_time(1);
        else
            last_fall = prev_falls(end);
            off_duration = ttl_time(re) - ttl_time(last_fall);
        end
        if off_duration >= params.min_off_duration
            valid_onsets = [valid_onsets; ttl_time(re)];
        end
    end

    % For clamped light, only keep the first onset
    if light == clamped_light && length(valid_onsets) > 1
        valid_onsets = valid_onsets(1);
    end

    all_video_onsets = [all_video_onsets; valid_onsets];
end

% Sort and deduplicate onsets (across lights)
if ~isempty(all_video_onsets)
    video_onsets = unique(sort(all_video_onsets));
else
    video_onsets = [];
end

fprintf('Video: detected %d onsets from %d lights\n', length(video_onsets), n_lights);

% Also detect onsets from combined trace (ttl_data)
% For bimodal distribution, use midpoint between low and high percentiles
low_pct = prctile(ttl_trace_combined, 10);   % representative of low state
high_pct = prctile(ttl_trace_combined, 90);  % representative of high state
threshold_combined = (low_pct + high_pct) / 2;

binary_combined = ttl_trace_combined > threshold_combined;
rising_combined = find(diff(binary_combined) == 1) + 1;
falling_combined = find(diff(binary_combined) == -1) + 1;

video_onsets_combined = [];
for ri = 1:length(rising_combined)
    re = rising_combined(ri);
    prev_falls = falling_combined(falling_combined < re);
    if isempty(prev_falls)
        off_duration = ttl_time(re) - ttl_time(1);
    else
        last_fall = prev_falls(end);
        off_duration = ttl_time(re) - ttl_time(last_fall);
    end
    if off_duration >= params.min_off_duration
        video_onsets_combined = [video_onsets_combined; ttl_time(re)];
    end
end
fprintf('Video (combined trace): detected %d onsets\n', length(video_onsets_combined));

% Create d_video table
n_frames = length(ttl_time);
ttl_onset_4lights = false(n_frames, 1);
ttl_onset_combined = false(n_frames, 1);

% Mark onset frames for 4-lights
for i = 1:length(video_onsets)
    [~, idx] = min(abs(ttl_time - video_onsets(i)));
    ttl_onset_4lights(idx) = true;
end

% Mark onset frames for combined
for i = 1:length(video_onsets_combined)
    [~, idx] = min(abs(ttl_time - video_onsets_combined(i)));
    ttl_onset_combined(idx) = true;
end

% Create d_video table (ttl_meta will be added after ref_onsets detection)
d_video = table(ttl_time, ttl_onset_4lights, ttl_onset_combined, ttl_trace_combined, ...
    'VariableNames', {'time', 'ttl_onset_4lights', 'ttl_onset_combined', 'ttl_trace_combined'});
% Also add the 4 individual traces
for light = 1:n_lights
    d_video.(['ttl_trace_' num2str(light)]) = ttl_traces(:, light);
end
fprintf('Created d_video table: %d rows, %d columns\n', height(d_video), width(d_video));

% 3. Detect reference onsets (ground truth)
onset_idx = find(ref_signal > params.ref_threshold);
if length(onset_idx) > 1
    gaps = diff(onset_idx);
    keep = [true; gaps > 1];
    onset_idx = onset_idx(keep);
end
ref_onsets = ref_time(onset_idx);

fprintf('Reference: detected %d onsets\n', length(ref_onsets));

% 4. Match video onsets to reference onsets (anchor-based alignment)
n_ref = length(ref_onsets);
n_video = length(video_onsets);

best_error = Inf;
best_matched_video = [];
best_matched_ref = [];
best_first_idx = 0;
best_last_idx = 0;

% Special case: split video where video is shorter than FIP
% Match video[1:n] to ref[1:n] directly
if exist('loading_split_video', 'var') && loading_split_video && n_video < n_ref
    fprintf('Split video mode: matching video[1:%d] to ref[1:%d]\n', n_video, n_video);

    % Use first and last video onsets as anchors to first n_video ref onsets
    anchor_video = [video_onsets(1); video_onsets(n_video)];
    anchor_ref = [ref_onsets(1); ref_onsets(n_video)];
    p = polyfit(anchor_video, anchor_ref, 1);

    % Match all video onsets to corresponding ref onsets
    matched_video = video_onsets;
    matched_ref = ref_onsets(1:n_video);

    best_first_idx = 1;
    best_last_idx = n_video;
    best_error = 0;

elseif n_ref >= 2 && n_video >= 2
    % Normal case: try combinations of first/last video onsets as anchors
    n_try = min(5, n_video);

    for first_idx = 1:n_try
        for last_offset = 0:(n_try-1)
            last_idx = n_video - last_offset;

            % Need at least as many video onsets between anchors as reference onsets
            if last_idx <= first_idx
                continue;
            end

            % Fit linear model from anchor points
            anchor_video = [video_onsets(first_idx); video_onsets(last_idx)];
            anchor_ref = [ref_onsets(1); ref_onsets(end)];
            p = polyfit(anchor_video, anchor_ref, 1);

            % For each reference onset, find closest video onset using the model
            candidate_video = [];
            candidate_ref = [];
            used = false(n_video, 1);

            for i = 1:n_ref
                % Expected video time for this ref onset
                expected_video = (ref_onsets(i) - p(2)) / p(1);

                % Find closest unused video onset
                diffs = abs(video_onsets - expected_video);
                diffs(used) = Inf;
                [min_diff, idx] = min(diffs);

                if min_diff < params.match_tolerance
                    candidate_video = [candidate_video; video_onsets(idx)];
                    candidate_ref = [candidate_ref; ref_onsets(i)];
                    used(idx) = true;
                end
            end

            if length(candidate_video) < 2
                continue;
            end

            % Refit with all matched pairs and compute error
            p = polyfit(candidate_video, candidate_ref, 1);
            predicted = p(1) * candidate_video + p(2);
            residuals = abs(candidate_ref - predicted);

            % Score: median error + penalty for missing matches + scale penalty
            median_error = median(residuals);
            missing_penalty = (n_ref - length(candidate_video)) * 1.0;
            scale_penalty = abs(p(1) - 1) * 10;
            score = median_error + missing_penalty + scale_penalty;

            if score < best_error
                best_error = score;
                best_matched_video = candidate_video;
                best_matched_ref = candidate_ref;
                best_first_idx = first_idx;
                best_last_idx = last_idx;
            end
        end
    end

    matched_video = best_matched_video;
    matched_ref = best_matched_ref;
end

% Track unmatched for diagnostics
if ~isempty(matched_video)
    unmatched_video = setdiff(video_onsets, matched_video);
    unmatched_ref = setdiff(ref_onsets, matched_ref);
else
    unmatched_video = video_onsets;
    unmatched_ref = ref_onsets;
end

fprintf('Matched: %d/%d pairs, anchors: video[%d]->ref[1], video[%d]->ref[end], score: %.4f\n', ...
    length(matched_video), n_ref, best_first_idx, best_last_idx, best_error);

if length(matched_video) < 2
    fprintf('ERROR: Not enough matched pairs for A%d D%d\n', animal, day);
    continue;
end

% 5. Robust linear fit
% Try robustfit first (requires Statistics Toolbox)
try
    [coeffs, stats] = robustfit(matched_video, matched_ref);
    b = coeffs(1);
    a = coeffs(2);
    fit_method = 'robustfit';
catch
    % Fallback: iterative outlier rejection with polyfit
    mv = matched_video;
    mr = matched_ref;

    for iter = 1:params.max_outlier_iters
        if length(mv) < 3
            break;
        end

        p = polyfit(mv, mr, 1);
        a = p(1);
        b = p(2);
        residuals = mr - (a * mv + b);

        if max(abs(residuals)) < params.outlier_threshold
            break;
        end

        % Remove worst outlier
        [~, worst_idx] = max(abs(residuals));
        mv(worst_idx) = [];
        mr(worst_idx) = [];
    end

    fit_method = 'polyfit_outlier_rejection';
end

fprintf('Mapping: ref_time = %.6f * video_time + %.4f\n', a, b);
fprintf('Method: %s, scale deviation from 1: %.6f\n', fit_method, abs(a - 1));

% 6. Map all video times and compute quality
video_time_mapped = a * ttl_time + b;
video_onsets_mapped = a * video_onsets + b;

% Compute quality metrics
closest_dt = zeros(length(ref_onsets), 1);
for i = 1:length(ref_onsets)
    if isempty(video_onsets_mapped)
        closest_dt(i) = NaN;
    else
        diffs = video_onsets_mapped - ref_onsets(i);
        [~, idx] = min(abs(diffs));
        closest_dt(i) = diffs(idx);
    end
end

quality = struct();
quality.closest_dt_ms = closest_dt * 1000;
quality.median_error_ms = median(abs(closest_dt)) * 1000;
quality.max_error_ms = max(abs(closest_dt)) * 1000;
quality.std_error_ms = std(closest_dt) * 1000;
quality.n_matched = length(matched_video);
quality.n_ref = length(ref_onsets);
quality.match_rate = length(matched_video) / length(ref_onsets);

% Drift analysis
good_mask = abs(closest_dt) * 1000 < 500;
if sum(good_mask) >= 2
    p = polyfit(ref_onsets(good_mask), closest_dt(good_mask) * 1000, 1);
    quality.drift_rate_ms_per_1000s = p(1) * 1000;
else
    quality.drift_rate_ms_per_1000s = NaN;
end

fprintf('Quality: median=%.1f ms, max=%.1f ms, match_rate=%.0f%%, drift=%.2f ms/1000s\n', ...
    quality.median_error_ms, quality.max_error_ms, quality.match_rate*100, ...
    quality.drift_rate_ms_per_1000s);

% Build ttl_meta based on ref_onsets: for each ref onset, find closest video source
% Use mapped video times (video_time_mapped) to compare with ref_onsets
n_from_4lights = 0;
n_from_combined = 0;
n_not_found = 0;
ref_onsets_not_found = [];  % track which ref_onsets had no match

ttl_meta = false(n_frames, 1);
ttl_meta_source = zeros(n_frames, 1);  % 1=4lights, 2=combined, 0=not found

idx_4lights = find(ttl_onset_4lights);
idx_combined = find(ttl_onset_combined);
times_4lights_mapped = video_time_mapped(idx_4lights);
times_combined_mapped = video_time_mapped(idx_combined);

for i = 1:length(ref_onsets)
    ref_t = ref_onsets(i);

    % Find closest 4lights within 1 sec (using mapped times)
    if ~isempty(times_4lights_mapped)
        [min_dist_4lights, best_idx_4lights] = min(abs(times_4lights_mapped - ref_t));
    else
        min_dist_4lights = Inf;
        best_idx_4lights = [];
    end

    % Find closest combined within 1 sec (using mapped times)
    if ~isempty(times_combined_mapped)
        [min_dist_combined, best_idx_combined] = min(abs(times_combined_mapped - ref_t));
    else
        min_dist_combined = Inf;
        best_idx_combined = [];
    end

    if min_dist_4lights <= 1.0
        % Use 4lights
        video_frame_idx = idx_4lights(best_idx_4lights);
        ttl_meta(video_frame_idx) = true;
        ttl_meta_source(video_frame_idx) = 1;
        n_from_4lights = n_from_4lights + 1;
    elseif min_dist_combined <= 1.0
        % Use combined
        video_frame_idx = idx_combined(best_idx_combined);
        ttl_meta(video_frame_idx) = true;
        ttl_meta_source(video_frame_idx) = 2;
        n_from_combined = n_from_combined + 1;
    else
        % Not found - save this ref_onset time
        n_not_found = n_not_found + 1;
        ref_onsets_not_found = [ref_onsets_not_found; ref_t];
    end
end

fprintf('ttl_meta: %d from 4lights, %d from combined, %d not found\n', ...
    n_from_4lights, n_from_combined, n_not_found);

% Add ttl_meta columns to d_video and save
d_video.ttl_meta = ttl_meta;
d_video.ttl_meta_source = ttl_meta_source;
all_data(animal).data(day).d_new = d_video;
% Reorder so d_new is first field
flds = fieldnames(all_data(animal).data);
if ismember('d_new', flds)
    new_order = [{'d_new'}; flds(~strcmp(flds, 'd_new'))];
    all_data(animal).data = orderfields(all_data(animal).data, new_order);
end
fprintf('Saved d_new to all_data(%d).data(%d).d_new\n', animal, day);

% Add ttl_onset to fip table based on ref_onsets
if istable(fip)
    fip_ttl_onset = false(height(fip), 1);
    for i = 1:length(ref_onsets)
        [~, idx] = min(abs(fip.time - ref_onsets(i)));
        fip_ttl_onset(idx) = true;
    end
    fip.ttl_onset = fip_ttl_onset;
    all_data(animal).data(day).fip = fip;
    fprintf('Added ttl_onset column to fip (%d onsets)\n', sum(fip_ttl_onset));
end

% 7. Plotting
if plot_mode == 1
    % Scatter summary - optionally skip 100% matches
    if ~plot_not_100_only || quality.match_rate < 1
        ax = nexttile(tl_scatter);
        x_data = ref_onsets(good_mask);
        y_data = closest_dt(good_mask) * 1000;
        scatter(ax, x_data, y_data, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
        hold(ax, 'on');
        if sum(good_mask) >= 3
            % Fit spline using pygam
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
        xlabel(ax, 'Reference time (s)');
        ylabel(ax, 'Video - Ref (ms)');
        title(ax, sprintf('A%d D%d: %.1fms, %.0f%% (%d,%d,%d)', animal, day, ...
            quality.median_error_ms, quality.match_rate*100, n_from_4lights, n_from_combined, n_not_found));
    end
else
    % Full verification plot
    [fig, tl] = myFigure(6, 1, 3200, 300, true);

    % Row 1: Individual 4-light traces with detected onsets
    ax1 = nexttile(tl);
    hold(ax1, 'on');
    clear lines;
    light_colors = lines(n_lights);
    for light = 1:n_lights
        plot(ax1, ttl_time, ttl_traces(:, light), '-', 'Color', light_colors(light,:), 'LineWidth', 0.5);
        % Plot threshold as dashed line
        if ~isnan(thresholds(light))
            plot(ax1, [ttl_time(1) ttl_time(end)], [thresholds(light) thresholds(light)], ...
                '--', 'Color', light_colors(light,:), 'LineWidth', 1);
        end
    end
    % Mark 4-light onsets (red triangles at top)
    y_max = max(ttl_traces(:));
    y_min = min(ttl_traces(:));
    if ~isempty(video_onsets)
        plot(ax1, video_onsets, repmat(y_max, length(video_onsets), 1), ...
            'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
    end
    % Mark combined trace onsets (blue triangles, right above red)
    if ~isempty(video_onsets_combined)
        y_offset = 0.1 * (y_max - y_min);
        plot(ax1, video_onsets_combined, repmat(y_max + y_offset, length(video_onsets_combined), 1), ...
            'b^', 'MarkerFaceColor', 'b', 'MarkerSize', 6);
    end
    ylabel(ax1, '4-light traces');
    hold(ax1, 'off');
    title(ax1, sprintf('A%d D%d: 4-light=%d onsets (red), combined=%d onsets (blue)', ...
        animal, day, length(video_onsets), length(video_onsets_combined)));

    % Row 2: Combined trace with detected onsets
    ax2 = nexttile(tl);
    hold(ax2, 'on');
    plot(ax2, ttl_time, ttl_trace_combined, 'k', 'LineWidth', 1);
    % Threshold for combined
    plot(ax2, [ttl_time(1) ttl_time(end)], [threshold_combined threshold_combined], ...
        'k--', 'LineWidth', 1);
    % Mark 4-light onsets (red triangles at top)
    y_max_comb = max(ttl_trace_combined);
    y_min_comb = min(ttl_trace_combined);
    if ~isempty(video_onsets)
        plot(ax2, video_onsets, repmat(y_max_comb, length(video_onsets), 1), ...
            'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
    end
    % Mark combined trace onsets (blue triangles, right above red)
    if ~isempty(video_onsets_combined)
        y_offset_comb = 0.1 * (y_max_comb - y_min_comb);
        plot(ax2, video_onsets_combined, repmat(y_max_comb + y_offset_comb, length(video_onsets_combined), 1), ...
            'b^', 'MarkerFaceColor', 'b', 'MarkerSize', 6);
    end
    ylabel(ax2, 'Combined trace');
    hold(ax2, 'off');
    title(ax2, sprintf('Combined trace: %d onsets (blue)', length(video_onsets_combined)));

    % Row 3: Reference signal with detected onsets and ttl_meta vertical lines
    ax3 = nexttile(tl);
    plot(ax3, ref_time, ref_signal, 'k', 'LineWidth', 0.5);
    hold(ax3, 'on');
    plot(ax3, ref_onsets, 0.5*ones(size(ref_onsets)), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
    % Plot ttl_meta as vertical lines (green=4lights, blue=combined) - use MAPPED times
    onset_times_4lights = video_time_mapped(ttl_meta_source == 1);
    onset_times_combined = video_time_mapped(ttl_meta_source == 2);
    y_lim = [0 1];
    for t = onset_times_4lights'
        plot(ax3, [t t], y_lim, 'g-', 'LineWidth', 1);
    end
    for t = onset_times_combined'
        plot(ax3, [t t], y_lim, 'b-', 'LineWidth', 1);
    end
    % Plot not found ref_onsets as red dashed lines
    for t = ref_onsets_not_found'
        plot(ax3, [t t], y_lim, 'r--', 'LineWidth', 1.5);
    end
    hold(ax3, 'off');
    ylabel(ax3, 'Reference');
    title(ax3, sprintf('Reference (%d) | 4lights=%d (grn), combined=%d (blu), not found=%d (red)', ...
        length(ref_onsets), n_from_4lights, n_from_combined, n_not_found));

    % Row 4: Aligned signals overlay
    ax4 = nexttile(tl);
    yyaxis(ax4, 'left');
    plot(ax4, video_time_mapped, sum(ttl_traces, 2), 'b', 'LineWidth', 0.5);
    ylabel(ax4, 'Video (mapped)');
    yyaxis(ax4, 'right');
    plot(ax4, ref_time, ref_signal, 'r', 'LineWidth', 0.5);
    ylabel(ax4, 'Reference');
    xlabel(ax4, 'Time (s)');
    title(ax4, sprintf('Aligned: ref = %.5f * video + %.3f', a, b));

    % Row 5: Sync quality - ttl_meta vs ref_onsets
    ax5 = nexttile(tl);
    % Compute error between ttl_meta (mapped) and ref_onsets
    ttl_meta_times_mapped = video_time_mapped(ttl_meta);
    ttl_meta_dt = zeros(length(ref_onsets), 1);
    for i = 1:length(ref_onsets)
        if isempty(ttl_meta_times_mapped)
            ttl_meta_dt(i) = NaN;
        else
            diffs = ttl_meta_times_mapped - ref_onsets(i);
            [~, idx] = min(abs(diffs));
            ttl_meta_dt(i) = diffs(idx);
        end
    end
    good_mask_meta = abs(ttl_meta_dt) * 1000 < 500;
    scatter(ax5, ref_onsets(good_mask_meta), ttl_meta_dt(good_mask_meta) * 1000, 15, 'k', 'filled');
    hold(ax5, 'on');
    if sum(good_mask_meta) >= 2
        p_meta = polyfit(ref_onsets(good_mask_meta), ttl_meta_dt(good_mask_meta) * 1000, 1);
        t_fit = linspace(min(ref_onsets(good_mask_meta)), max(ref_onsets(good_mask_meta)), 200);
        plot(ax5, t_fit, polyval(p_meta, t_fit), 'r-', 'LineWidth', 2);
    end
    yline(ax5, 0, 'k--');
    hold(ax5, 'off');
    xlabel(ax5, 'Reference time (s)');
    ylabel(ax5, 'ttl_meta - ref (ms)');
    title(ax5, sprintf('ttl_meta vs ref: median=%.1fms | (%d, %d, %d)', ...
        median(abs(ttl_meta_dt(good_mask_meta))) * 1000, n_from_4lights, n_from_combined, n_not_found));

    % Row 6: Error between 4-light and combined onset detection
    ax6 = nexttile(tl);
    hold(ax6, 'on');
    % For each 4-light onset, find closest combined onset and compute signed difference
    if ~isempty(video_onsets) && ~isempty(video_onsets_combined)
        onset_diff_ms = zeros(length(video_onsets), 1);
        for i = 1:length(video_onsets)
            diffs = video_onsets_combined - video_onsets(i);
            [~, idx] = min(abs(diffs));
            onset_diff_ms(i) = diffs(idx) * 1000;  % signed: combined - 4light
        end
        scatter(ax6, video_onsets, onset_diff_ms, 15, 'k', 'filled');
        yline(ax6, 0, 'k--');
        ylabel(ax6, 'combined - 4-light (ms)');
        title(ax6, sprintf('4-light vs combined: median=%.1fms, std=%.1fms, n=%d vs %d', ...
            median(onset_diff_ms), std(onset_diff_ms), length(video_onsets), length(video_onsets_combined)));
    else
        title(ax6, '4-light vs combined: no data');
    end
    xlabel(ax6, 'Time (s)');
    hold(ax6, 'off');
end

% 8. Save sync struct (compatible with a02 format)
sync = struct();
sync.a = a;
sync.b = b;
sync.video_time_mapped = video_time_mapped;
% Additional diagnostics
sync.matched_video_onsets = matched_video;
sync.matched_ref_onsets = matched_ref;
sync.n_video_onsets = length(video_onsets);
sync.n_ref_onsets = length(ref_onsets);
sync.n_matched = length(matched_video);
sync.is_cut_video = (length(video_onsets) < length(ref_onsets));  % video shorter than FIP
sync.fit_method = fit_method;
sync.quality = quality;
sync.params = params;

all_data(animal).data(day).sync = sync;
fprintf('Saved sync to all_data(%d).data(%d).sync\n', animal, day);

% 9. Downsample FIP to video frame rate with spline drift correction
if sum(good_mask) >= 3
    % Fit spline to get drift correction at all video frame times
    x_data = ref_onsets(good_mask);
    y_data = closest_dt(good_mask) * 1000;  % drift in ms
    x_pred = video_time_mapped;  % predict at all video frames (in ref/fip clock)

    [spline_pred, ~] = pyrunfile("fit_spline_gam.py", ["predictions", "ci"], ...
        x=x_data, y=y_data, x_pred=x_pred, n_splines=int32(n_splines));
    spline_pred = double(spline_pred);
    spline_pred = spline_pred(:);  % ensure column vector

    % Apply spline correction: corrected_time = mapped_time - drift
    % drift is (video - ref), so to get correct ref time: ref = video - drift
    corrected_time = video_time_mapped - spline_pred / 1000;

    % Save spline correction in sync struct
    sync.spline_correction_ms = spline_pred;
    all_data(animal).data(day).sync = sync;
else
    % Not enough points for spline, use linear mapping only
    corrected_time = video_time_mapped;
    fprintf('Warning: not enough points for spline correction, using linear mapping only\n');
end

% Interpolate FIP signals to corrected video times
fip_time = fip.time;
fip_ds_time = interp1(fip_time, fip_time, corrected_time, 'linear', NaN);
fip_ds_signal = interp1(fip_time, fip.signal, corrected_time, 'linear', NaN);
fip_ds_reference = interp1(fip_time, fip.reference, corrected_time, 'linear', NaN);

% Interpolate optional columns if they exist
if ismember('signal_artcorr', fip.Properties.VariableNames)
    fip_ds_signal_artcorr = interp1(fip_time, fip.signal_artcorr, corrected_time, 'linear', NaN);
else
    fip_ds_signal_artcorr = NaN(size(corrected_time));
end
if ismember('signal_corr_wo_norm', fip.Properties.VariableNames)
    fip_ds_signal_corr_wo_norm = interp1(fip_time, fip.signal_corr_wo_norm, corrected_time, 'linear', NaN);
else
    fip_ds_signal_corr_wo_norm = NaN(size(corrected_time));
end
if ismember('signal_corr', fip.Properties.VariableNames)
    fip_ds_signal_corr = interp1(fip_time, fip.signal_corr, corrected_time, 'linear', NaN);
else
    fip_ds_signal_corr = NaN(size(corrected_time));
end

% Boolean ttl_onset: find nearest corrected_time for each ref_onset
fip_ds_ttl = false(size(corrected_time));
for i = 1:length(ref_onsets)
    [~, idx] = min(abs(corrected_time - ref_onsets(i)));
    fip_ds_ttl(idx) = true;
end

% Add FIP columns to d_new
d_new = all_data(animal).data(day).d_new;
d_new.fip_time = fip_ds_time;
d_new.fip_signal = fip_ds_signal;
d_new.fip_reference = fip_ds_reference;
d_new.fip_signal_artcorr = fip_ds_signal_artcorr;
d_new.fip_signal_corr_wo_norm = fip_ds_signal_corr_wo_norm;
d_new.fip_signal_corr = fip_ds_signal_corr;
d_new.fip_ttl_onset = fip_ds_ttl;

% Add frame_idx (original frame index) before cutting
d_new.frame_idx = (1:height(d_new))';
d_new = movevars(d_new, 'frame_idx', 'After', 'time');

% Cut rows before first TTL
first_ttl_idx = find(d_new.ttl_meta, 1, 'first');
if ~isempty(first_ttl_idx) && first_ttl_idx > 1
    n_cut = first_ttl_idx - 1;
    d_new = d_new(first_ttl_idx:end, :);
    fprintf('Cut %d rows before first TTL\n', n_cut);
    if ~any(d_new.fip_ttl_onset(1:min(20, height(d_new))))
        d_new.fip_ttl_onset(1) = true;
    end
end

time_delay = 0.280; % seconds (AMUZA system delay)
frame_interval = median(diff(d_new.time));
frame_offset = round(time_delay / frame_interval);

% Shift FIP columns backwards (not TTL!)
fip_cols = {'fip_signal', 'fip_reference', 'fip_signal_artcorr', ...
            'fip_signal_corr_wo_norm', 'fip_signal_corr'};
for i = 1:length(fip_cols)
    col = fip_cols{i};
    d_new.(col) = [d_new.(col)(frame_offset+1:end); NaN(frame_offset, 1)];
end
fprintf('Time correction: shifted FIP by %d frames (%.3fs at %.1f Hz)\n', ...
    frame_offset, time_delay, 1/frame_interval);

all_data(animal).data(day).d_new = d_new;
fprintf('Added FIP to d_new: %d rows, %d with data, %d NaN\n', ...
    height(d_new), sum(~isnan(d_new.fip_signal)), sum(isnan(d_new.fip_signal)));

end
end

fprintf('\n=== Done ===\n');
