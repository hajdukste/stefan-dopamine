% a07e_sync_split_video.m
% Merge split video parts into all_data_backup(1).data(3)
% Requires: loading_split_video processing completed, all_data has 2 parts
%
% Part mapping (from a00_load_data.m):
%   day 1 = C57_51_9_2 = first part of session (video cut short)
%   day 2 = C57_51_9   = second part of session (recording restarted)

orig_animal = 1;
orig_day = 3;

fprintf('\n=== Merging split video parts ===\n');

% Sanity check: verify TTL data matches video frame counts
for day = 1:2
    if isfield(all_data(1).data(day), 'ttl_data2')
        ttl_frames = size(all_data(1).data(day).ttl_data2.ttl_traces, 1);
        d_new_frames = all_data(1).data(day).d_new.frame_idx(end);
        if ttl_frames == d_new_frames
            fprintf('Day %d: TTL frames (%d) matches d_new frames (%d) - OK\n', day, ttl_frames, d_new_frames);
        else
            fprintf('WARNING Day %d: TTL frames (%d) != d_new frames (%d) - MISMATCH!\n', day, ttl_frames, d_new_frames);
        end
    end
end

% Get the two processed parts
d_new1 = all_data(1).data(1).d_new;
d_new2 = all_data(1).data(2).d_new;
d_old1 = all_data(1).data(1).d_old;
d_old2 = all_data(1).data(2).d_old;
sync1 = all_data(1).data(1).sync;
sync2 = all_data(1).data(2).sync;

% Determine part order using is_cut_video flag from a07a
% Part 1 (cut video) should come first, Part 2 (full video) comes second
is_cut1 = sync1.is_cut_video;
is_cut2 = sync2.is_cut_video;
fprintf('Day 1 is_cut_video: %d, Day 2 is_cut_video: %d\n', is_cut1, is_cut2);

if is_cut2 && ~is_cut1
    % Day 2 is cut, Day 1 is full -> swap so cut comes first
    fprintf('Swapping: day 2 (cut) -> part 1, day 1 (full) -> part 2\n');
    [d_new1, d_new2] = deal(d_new2, d_new1);
    [d_old1, d_old2] = deal(d_old2, d_old1);
    [sync1, sync2] = deal(sync2, sync1);
elseif is_cut1 && ~is_cut2
    fprintf('Order correct: day 1 (cut) -> part 1, day 2 (full) -> part 2\n');
else
    fprintf('WARNING: unexpected cut pattern - both cut=%d/%d\n', is_cut1, is_cut2);
end

fprintf('Part 1 (day 1): %d video frames, time range %.1f - %.1f s\n', ...
    height(d_new1), min(d_new1.time), max(d_new1.time));
fprintf('Part 2 (day 2): %d video frames, time range %.1f - %.1f s\n', ...
    height(d_new2), min(d_new2.time), max(d_new2.time));

% Detect gap: time range not covered by either video
gap_start = max(d_new1.time);
gap_end = min(d_new2.time);
gap_duration = gap_end - gap_start;
fprintf('Gap: %.1f to %.1f s (%.1f s duration)\n', gap_start, gap_end, gap_duration);

% Merge based on mode
if strcmp(split_video_mode, 'remove_gap')
    fprintf('Mode: remove_gap - shifting part 2 times to follow part 1 continuously\n');

    % Shift d_new2 times to follow d_new1 continuously
    time_shift = gap_start - gap_end;
    d_new2.time = d_new2.time + time_shift;
    if ismember('fip_time', d_new2.Properties.VariableNames)
        d_new2.fip_time = d_new2.fip_time + time_shift;
    end
    d_old2.time = d_old2.time + time_shift;

    d_new = [d_new1; d_new2];
    d_old = [d_old1; d_old2];

else  % 'nan_gap'
    fprintf('Mode: nan_gap - inserting NaN rows for gap period\n');

    % Create NaN rows for gap
    frame_rate = 1 / median(diff(d_new1.time));
    gap_times = (gap_start + 1/frame_rate : 1/frame_rate : gap_end - 1/frame_rate)';
    n_gap_frames = length(gap_times);

    if n_gap_frames > 0
        % Create gap rows with NaN for all columns except time
        gap_rows = array2table(NaN(n_gap_frames, width(d_new1)));
        gap_rows.Properties.VariableNames = d_new1.Properties.VariableNames;
        gap_rows.time = gap_times;

        % Set boolean columns to false instead of NaN
        for col = d_new1.Properties.VariableNames
            if islogical(d_new1.(col{1}))
                gap_rows.(col{1}) = false(n_gap_frames, 1);
            end
        end

        d_new = [d_new1; gap_rows; d_new2];
        fprintf('Inserted %d NaN rows for gap\n', n_gap_frames);
    else
        d_new = [d_new1; d_new2];
    end

    d_old = [d_old1; d_old2];
end

% Sort by time (in case parts overlap slightly)
d_new = sortrows(d_new, 'time');
d_old = sortrows(d_old, 'time');

fprintf('Merged d_new: %d rows\n', height(d_new));
fprintf('Merged d_old: %d rows\n', height(d_old));

% Store in backup
all_data_backup(orig_animal).data(orig_day).d_new = d_new;
all_data_backup(orig_animal).data(orig_day).d_old = d_old;

% Also copy sync structs for reference
all_data_backup(orig_animal).data(orig_day).sync_part1 = all_data(1).data(1).sync;
all_data_backup(orig_animal).data(orig_day).sync_part2 = all_data(1).data(2).sync;

fprintf('Merged split video into all_data_backup(%d).data(%d)\n', orig_animal, orig_day);

% Verification plots
fip = all_data_backup(orig_animal).data(orig_day).fip;
ref_time = fip.time;
ref_signal = fip.reference;

[fig, tl] = myFigure(4, 1, 2400, 300, true);
title(tl, sprintf('Split Video Merge - A%d D%d (%s mode)', orig_animal, orig_day, split_video_mode));

% Row 1: FIP reference with TTL onsets marked
ax1 = nexttile(tl);
plot(ax1, ref_time, ref_signal, 'k', 'LineWidth', 0.5);
hold(ax1, 'on');
% Mark TTLs from merged d_new
if ismember('ttl_meta', d_new.Properties.VariableNames)
    ttl_times_merged = d_new.time(d_new.ttl_meta);
    plot(ax1, ttl_times_merged, 0.5*ones(size(ttl_times_merged)), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
end
% Mark gap region
if strcmp(split_video_mode, 'nan_gap')
    fill(ax1, [gap_start gap_end gap_end gap_start], [0 0 1 1], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end
hold(ax1, 'off');
ylabel(ax1, 'FIP reference');
title(ax1, sprintf('FIP reference + merged TTLs (%d TTLs)', sum(d_new.ttl_meta)));

% Row 2: Merged d_new time coverage
ax2 = nexttile(tl);
hold(ax2, 'on');
% Part 1 coverage (green)
plot(ax2, [min(d_new1.time) max(d_new1.time)], [1 1], 'g-', 'LineWidth', 10);
% Part 2 coverage (blue) - use original times before shift for visualization
part2_orig_start = min(d_new2.time);
if strcmp(split_video_mode, 'remove_gap')
    part2_orig_start = part2_orig_start - time_shift;  % undo shift for display
end
part2_orig_end = max(d_new2.time);
if strcmp(split_video_mode, 'remove_gap')
    part2_orig_end = part2_orig_end - time_shift;
end
plot(ax2, [part2_orig_start part2_orig_end], [0.5 0.5], 'b-', 'LineWidth', 10);
% Gap region
fill(ax2, [gap_start gap_end gap_end gap_start], [0 0 1.5 1.5], 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
hold(ax2, 'off');
ylim(ax2, [0 1.5]);
ylabel(ax2, 'Coverage');
title(ax2, sprintf('Part 1 (green): %.0f-%.0f s | Gap: %.0f s | Part 2 (blue): %.0f-%.0f s', ...
    min(d_new1.time), max(d_new1.time), gap_duration, part2_orig_start, part2_orig_end));

% Row 3: FIP signal from merged d_new (if available)
ax3 = nexttile(tl);
if ismember('fip_signal', d_new.Properties.VariableNames)
    valid = ~isnan(d_new.fip_signal);
    plot(ax3, d_new.time(valid), d_new.fip_signal(valid), 'k', 'LineWidth', 0.5);
    ylabel(ax3, 'FIP signal');
    title(ax3, sprintf('Merged FIP signal (%d valid, %d NaN)', sum(valid), sum(~valid)));
else
    title(ax3, 'No fip_signal in d_new');
end

% Row 4: Arduino events timeline
ax4 = nexttile(tl);
hold(ax4, 'on');
trial_mask = strcmp(d_old.type, 'start_of_trial');
trial_times_merged = d_old.time(trial_mask);
for tt = trial_times_merged'
    xline(ax4, tt, 'b-', 'LineWidth', 0.5);
end
% Mark gap
if strcmp(split_video_mode, 'nan_gap')
    fill(ax4, [gap_start gap_end gap_end gap_start], ylim, 'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
end
hold(ax4, 'off');
ylabel(ax4, 'Arduino');
xlabel(ax4, 'Time (s)');
title(ax4, sprintf('Merged start_of_trial events (%d total)', sum(trial_mask)));

linkaxes([ax1 ax2 ax3 ax4], 'x');
