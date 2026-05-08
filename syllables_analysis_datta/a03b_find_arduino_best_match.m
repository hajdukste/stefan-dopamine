% a03b_find_arduino_best_match.m
% Compare start_of_trial matching with two TTL sources:
% 1. ttl_onset_4lights from d_new (video frame timing)
% 2. ttl_onset from fip (fiber photometry timing)
% Uses anchor-based alignment (same as a07a_find_sync)

animals = 1;
days = 4;

params = struct();
params.match_tolerance = 5;  % seconds

[fig, tl] = myFigure(4, 1, 1600, 300, true);

for animal = animals
for day = days

fprintf('\n=== A%d D%d ===\n', animal, day);

% Check required data exists
if ~isfield(all_data(animal).data(day), 'sync_arduino')
    fprintf('Skipping: no sync_arduino\n');
    continue;
end
if ~isfield(all_data(animal).data(day), 'd_new')
    fprintf('Skipping: no d_new\n');
    continue;
end
if ~isfield(all_data(animal).data(day), 'fip')
    fprintf('Skipping: no fip\n');
    continue;
end

% Get start_of_trial times (already mapped to ref time)
sync_arduino = all_data(animal).data(day).sync_arduino;
trial_times = sync_arduino.trial_time_mapped;

% Get TTL onsets from d_new (video frames, 4-lights detection)
d_new = all_data(animal).data(day).d_new;
video_ttl_times = d_new.video_time(d_new.ttl_onset_4lights);

% Get TTL onsets from fip
fip = all_data(animal).data(day).fip;
fip_ttl_times = fip.time(fip.ttl_onset);

fprintf('start_of_trial: %d events\n', length(trial_times));
fprintf('d_new ttl_onset_4lights: %d events\n', length(video_ttl_times));
fprintf('fip ttl_onset: %d events\n', length(fip_ttl_times));

% Row 1: Match trial_times with video TTL using anchor-based alignment
ax1 = nexttile(tl);
hold(ax1, 'on');
[matched_trial_v, matched_ttl_v, a_v, b_v] = anchor_match(trial_times, video_ttl_times, params.match_tolerance);
if ~isempty(matched_trial_v)
    % Compute error: mapped trial - matched ttl
    trial_mapped_v = a_v * matched_trial_v + b_v;
    error_video_ms = (trial_mapped_v - matched_ttl_v) * 1000;
    scatter(ax1, matched_ttl_v, error_video_ms, 15, 'k', 'filled');
    yline(ax1, 0, 'k--');
    ylabel(ax1, 'trial (mapped) - video TTL (ms)');
    title(ax1, sprintf('A%d D%d: video TTL - matched %d/%d, median=%.1fms, std=%.1fms', ...
        animal, day, length(matched_trial_v), length(trial_times), median(error_video_ms), std(error_video_ms)));
    fprintf('Video TTL: matched %d/%d, a=%.6f, b=%.3f\n', length(matched_trial_v), length(trial_times), a_v, b_v);
else
    title(ax1, sprintf('A%d D%d: video TTL - no matches', animal, day));
end
xlabel(ax1, 'Time (s)');
hold(ax1, 'off');

% Row 2: Match trial_times with fip TTL using anchor-based alignment
ax2 = nexttile(tl);
hold(ax2, 'on');
[matched_trial_f, matched_ttl_f, a_f, b_f] = anchor_match(trial_times, fip_ttl_times, params.match_tolerance);
if ~isempty(matched_trial_f)
    % Compute error: mapped trial - matched ttl
    trial_mapped_f = a_f * matched_trial_f + b_f;
    error_fip_ms = (trial_mapped_f - matched_ttl_f) * 1000;
    scatter(ax2, matched_ttl_f, error_fip_ms, 15, 'k', 'filled');
    yline(ax2, 0, 'k--');
    ylabel(ax2, 'trial (mapped) - fip TTL (ms)');
    title(ax2, sprintf('A%d D%d: fip TTL - matched %d/%d, median=%.1fms, std=%.1fms', ...
        animal, day, length(matched_trial_f), length(trial_times), median(error_fip_ms), std(error_fip_ms)));
    fprintf('Fip TTL: matched %d/%d, a=%.6f, b=%.3f\n', length(matched_trial_f), length(trial_times), a_f, b_f);
else
    title(ax2, sprintf('A%d D%d: fip TTL - no matches', animal, day));
end
xlabel(ax2, 'Time (s)');
hold(ax2, 'off');

% Row 3: Video TTL - good matches only (<500ms)
ax3 = nexttile(tl);
hold(ax3, 'on');
if ~isempty(matched_trial_v)
    good_v = abs(error_video_ms) < 500;
    if sum(good_v) > 0
        scatter(ax3, matched_ttl_v(good_v), error_video_ms(good_v), 15, 'k', 'filled');
        yline(ax3, 0, 'k--');
        ylabel(ax3, 'trial (mapped) - video TTL (ms)');
        title(ax3, sprintf('A%d D%d: video TTL (<500ms) - %d/%d, median=%.1fms, std=%.1fms', ...
            animal, day, sum(good_v), length(matched_trial_v), median(error_video_ms(good_v)), std(error_video_ms(good_v))));
    else
        title(ax3, sprintf('A%d D%d: video TTL (<500ms) - no good matches', animal, day));
    end
else
    title(ax3, sprintf('A%d D%d: video TTL (<500ms) - no data', animal, day));
end
xlabel(ax3, 'Time (s)');
hold(ax3, 'off');

% Row 4: Fip TTL - good matches only (<500ms)
ax4 = nexttile(tl);
hold(ax4, 'on');
if ~isempty(matched_trial_f)
    good_f = abs(error_fip_ms) < 500;
    if sum(good_f) > 0
        scatter(ax4, matched_ttl_f(good_f), error_fip_ms(good_f), 15, 'k', 'filled');
        yline(ax4, 0, 'k--');
        ylabel(ax4, 'trial (mapped) - fip TTL (ms)');
        title(ax4, sprintf('A%d D%d: fip TTL (<500ms) - %d/%d, median=%.1fms, std=%.1fms', ...
            animal, day, sum(good_f), length(matched_trial_f), median(error_fip_ms(good_f)), std(error_fip_ms(good_f))));
    else
        title(ax4, sprintf('A%d D%d: fip TTL (<500ms) - no good matches', animal, day));
    end
else
    title(ax4, sprintf('A%d D%d: fip TTL (<500ms) - no data', animal, day));
end
xlabel(ax4, 'Time (s)');
hold(ax4, 'off');

end
end

function [matched_src, matched_tgt, a, b] = anchor_match(src_times, tgt_times, match_tolerance)
% Anchor-based matching: find best linear mapping from src_times to tgt_times
% Returns matched pairs and linear coefficients (tgt = a * src + b)

matched_src = [];
matched_tgt = [];
a = 1;
b = 0;

n_src = length(src_times);
n_tgt = length(tgt_times);

if n_src < 2 || n_tgt < 2
    return;
end

best_error = Inf;
best_matched_src = [];
best_matched_tgt = [];
best_a = 1;
best_b = 0;

n_try = min(5, n_src);

% Try combinations: src[first_idx] -> tgt[1], src[last_idx] -> tgt[end]
for first_idx = 1:n_try
    for last_offset = 0:(n_try-1)
        last_idx = n_src - last_offset;

        if last_idx <= first_idx
            continue;
        end

        % Fit linear model from anchor points
        anchor_src = [src_times(first_idx); src_times(last_idx)];
        anchor_tgt = [tgt_times(1); tgt_times(end)];
        p = polyfit(anchor_src, anchor_tgt, 1);

        % For each target, find closest source using the model
        candidate_src = [];
        candidate_tgt = [];
        used = false(n_src, 1);

        for i = 1:n_tgt
            % Expected source time for this target
            expected_src = (tgt_times(i) - p(2)) / p(1);

            % Find closest unused source
            diffs = abs(src_times - expected_src);
            diffs(used) = Inf;
            [min_diff, idx] = min(diffs);

            if min_diff < match_tolerance
                candidate_src = [candidate_src; src_times(idx)];
                candidate_tgt = [candidate_tgt; tgt_times(i)];
                used(idx) = true;
            end
        end

        if length(candidate_src) < 2
            continue;
        end

        % Refit with all matched pairs
        p = polyfit(candidate_src, candidate_tgt, 1);
        predicted = p(1) * candidate_src + p(2);
        residuals = abs(candidate_tgt - predicted);

        % Score: median error + penalty for missing + scale penalty
        median_error = median(residuals);
        missing_penalty = (n_tgt - length(candidate_src)) * 1.0;
        scale_penalty = abs(p(1) - 1) * 10;
        score = median_error + missing_penalty + scale_penalty;

        if score < best_error
            best_error = score;
            best_matched_src = candidate_src;
            best_matched_tgt = candidate_tgt;
            best_a = p(1);
            best_b = p(2);
        end
    end
end

matched_src = best_matched_src;
matched_tgt = best_matched_tgt;
a = best_a;
b = best_b;
end
