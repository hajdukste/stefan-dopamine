
skip_animals_days = [0 0];


for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end

        % Replace d_new with d and put as a first column
        all_data(animal).data(day).d = all_data(animal).data(day).d_new;
        all_data(animal).data(day).d_new = [];
        flds = fieldnames(all_data(animal).data);
        new_order = [{'d'}; flds(~strcmp(flds, 'd'))];
        all_data(animal).data = orderfields(all_data(animal).data, new_order);

        % Add zsc_exp
        all_data(animal).data(day).d.zsc_exp = all_data(animal).data(day).d.fip_signal_corr;

        % Remove last NaN rows
        last_valid = find(~isnan(all_data(animal).data(day).d.time), 1, 'last');
        all_data(animal).data(day).d = all_data(animal).data(day).d(1:last_valid, :);

        % Add speed
        dx = diff(all_data(animal).data(day).d.centroidX);
        dy = diff(all_data(animal).data(day).d.centroidY);
        dt = diff(all_data(animal).data(day).d.time);
        all_data(animal).data(day).d.speed = [0; sqrt(dx.^2 + dy.^2) ./ dt];
        all_data(animal).data(day).d.speed = all_data(animal).data(day).d.speed ./ 10;
        all_data(animal).data(day).d.speed_norm = 3+normalize(all_data(animal).data(day).d.speed);

    end
end


% find 20 most common motifs from d.syllable (all data)
all_syl = [];
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ismember('syllable', all_data(animal).data(day).d.Properties.VariableNames)
            all_syl = [all_syl; all_data(animal).data(day).d.syllable];
        end
    end
end
if ~isempty(all_syl)
    all_syl = all_syl(all_syl >= 0);
end
if ~isempty(all_syl)
    unique_syl = unique(all_syl);
    counts = histcounts(all_syl, [unique_syl; max(unique_syl)+1])';
    [~, sort_idx] = sort(counts, 'descend');
    most_common_motifs = unique_syl(sort_idx(1:min(20, length(unique_syl))));
    most_common_motifs_all = unique_syl(sort_idx(1:min(99, length(unique_syl))));
end

% find 20 most common motifs within trials only
all_syl_trial = [];
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ~ismember('syllable', all_data(animal).data(day).d.Properties.VariableNames); continue; end

        d = all_data(animal).data(day).d;
        d_old = all_data(animal).data(day).d_old;
        if isempty(d_old); continue; end

        start_mask = strcmp(d_old.type, 'start_of_trial');
        end_mask = strcmp(d_old.type, 'end_of_trial');
        start_times = d_old.time(start_mask);
        end_times = d_old.time(end_mask);

        for i_start = 1:length(start_times)
            t_start = start_times(i_start);
            t_end_idx = find(end_times > t_start, 1);
            if isempty(t_end_idx); continue; end
            t_end = end_times(t_end_idx);

            mask = d.time >= t_start & d.time <= t_end;
            all_syl_trial = [all_syl_trial; d.syllable(mask)];
        end
    end
end
if ~isempty(all_syl_trial)
    all_syl_trial = all_syl_trial(all_syl_trial >= 0);
end
if ~isempty(all_syl_trial)
    unique_syl = unique(all_syl_trial);
    counts = histcounts(all_syl_trial, [unique_syl; max(unique_syl)+1])';
    [~, sort_idx] = sort(counts, 'descend');
    most_common_trial_motifs = unique_syl(sort_idx(1:min(20, length(unique_syl))));
end

% 20-color distinct colormap
n_colors = 20;
cmap20 = [
    211, 211, 211;  % lightgray
    47,  79,  79;   % darkslategray
    46,  139, 87;   % seagreen
    25,  25,  112;  % midnightblue
    255, 255, 0;    % yellow
    128, 128, 0;    % olive
    178, 34,  34;   % firebrick
    255, 165, 0;    % orange
    255, 0,   0;    % red
    0,   0,   205;  % mediumblue
    0,   255, 0;    % lime
    186, 85,  211;  % mediumorchid
    0,   250, 154;  % mediumspringgreen
    233, 150, 122;  % darksalmon
    0,   255, 255;  % aqua
    0,   191, 255;  % deepskyblue
    255, 0,   255;  % fuchsia
    240, 230, 140;  % khaki
    221, 160, 221;  % plum
    255, 20,  147;  % deeppink
] / 255;
syl_to_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:length(most_common_motifs)
    syl_to_idx(most_common_motifs(i)) = i;
end
other_color = [0.15 0.15 0.15];

sorted_syllables = [29, 22, 14, 16, 32, 23, 13, 20, 26, 18, 12, 4, 19, 15, 11, 7, 3, 1, 2, 0, 8, 52, 47, 28, 40];

% now create cmap25 based on sorted_syllables, mapping colors from cmap20
cmap25 = zeros(25, 3);  % initialize all to black

% go through most_common_motifs and assign colors to corresponding positions in sorted_syllables
for i = 1:length(most_common_motifs)
    syl = most_common_motifs(i);
    pos_in_sorted = find(sorted_syllables == syl);
    if ~isempty(pos_in_sorted)
        cmap25(pos_in_sorted, :) = cmap20(i, :);
    end
end
cmap25(21, :) = [93, 64, 55]/255;
cmap25(22, :) = [121, 134, 203]/255;
cmap25(23, :) = [0, 96, 100]/255;
cmap25(24, :) = [191, 54, 12]/255;
cmap25(25, :) = [74, 20, 140]/255;


%
% Fix: remove unpaired start_of_trial in animal 1, day 3
d_old = all_data(1).data(3).d_old;
start_idx = find(strcmp(d_old.type, 'start_of_trial'));
end_idx = find(strcmp(d_old.type, 'end_of_trial'));
rows_to_remove = [];
for i = 1:length(start_idx)-1
    next_start = start_idx(i+1);
    has_end = any(end_idx > start_idx(i) & end_idx < next_start);
    if ~has_end
        rows_to_remove = [rows_to_remove; start_idx(i)];
    end
end
fprintf('Animal 1, Day 3: removed %d unpaired start_of_trial event(s)\n', length(rows_to_remove));
all_data(1).data(3).d_old(rows_to_remove, :) = [];

%%
% Load mouth keypoint from h5 files
h5_folder = '/Users/stefan/Downloads/berkeley_collab/stefan-models-data-code/h5_slp';
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        d = all_data(animal).data(day).d;
        if isempty(d); continue; end

        % get h5 filename from csv_path
        csv_path = all_data(animal).data(day).csv_path;
        [~, fname, ~] = fileparts(csv_path);
        h5_file = fullfile(h5_folder, [fname '_video.h5']);

        if ~isfile(h5_file)
            fprintf('H5 file not found for A%d D%d: %s\n', animal, day, h5_file);
            continue;
        end

        % read tracks: h5 is (n_tracks, xy, n_nodes, n_frames), MATLAB reverses to (n_frames, n_nodes, xy, n_tracks)
        tracks = h5read(h5_file, '/tracks');
        n_frames_h5 = size(tracks, 1);

        % mouth is node index 2 (1=bum, 2=mouth, 3=left hindpaw, etc.)
        mouthX = squeeze(tracks(:, 2, 1, 1));  % (n_frames, 1)
        mouthY = squeeze(tracks(:, 2, 2, 1));

        % check frame count
        last_frame = d.frame_idx(end);
        if n_frames_h5 < last_frame
            fprintf('Warning A%d D%d: h5 has %d frames, but last frame_idx is %d\n', animal, day, n_frames_h5, last_frame);
            continue;
        end

        % align to d frame indices
        mouthX_aligned = mouthX(d.frame_idx);
        mouthY_aligned = mouthY(d.frame_idx);

        % interpolate NaN values linearly
        nan_mask = isnan(mouthX_aligned) | isnan(mouthY_aligned);
        n_nans = sum(nan_mask);
        longest_nan = 0;
        if n_nans > 0
            % find longest NaN stretch
            nan_diff = diff([0; nan_mask; 0]);
            nan_starts = find(nan_diff == 1);
            nan_ends = find(nan_diff == -1) - 1;
            nan_lengths = nan_ends - nan_starts + 1;
            longest_nan = max(nan_lengths);

            % interpolate
            valid_idx = find(~nan_mask);
            if length(valid_idx) >= 2
                mouthX_aligned = interp1(valid_idx, mouthX_aligned(valid_idx), (1:length(mouthX_aligned))', 'linear', 'extrap');
                mouthY_aligned = interp1(valid_idx, mouthY_aligned(valid_idx), (1:length(mouthY_aligned))', 'linear', 'extrap');
            end
        end

        % add to d
        all_data(animal).data(day).d.mouthX = mouthX_aligned;
        all_data(animal).data(day).d.mouthY = mouthY_aligned;

        fprintf('A%d D%d: loaded mouth keypoint (%d frames, %d NaNs interpolated, longest stretch: %d)\n', animal, day, length(mouthX_aligned), n_nans, longest_nan);
    end
end

%%
% Add movement and trial metrics
valve_to_idx = containers.Map([0,1,2,3], [3,4,2,1]);  % valve_id -> light_pixels index
[b_filt, a_filt] = butter(2, 2/(60/2));  % 2Hz low-pass at 60Hz sampling

for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        d = all_data(animal).data(day).d;
        d_old = all_data(animal).data(day).d_old;
        if isempty(d) || ~ismember('mouthX', d.Properties.VariableNames); continue; end
        if isempty(d_old); continue; end

        % Remove existing final_approach_start events (allows re-running)
        fa_mask = strcmp(d_old.type, 'final_approach_start');
        if any(fa_mask)
            d_old(fa_mask, :) = [];
        end

        % Global metrics: cumulative distance
        dx = [0; diff(d.mouthX)];
        dy = [0; diff(d.mouthY)];
        d.total_distance = cumsum(sqrt(dx.^2 + dy.^2));

        % Global metrics: speed (2Hz low-pass filtered)
        raw_speed = [0; sqrt(diff(d.mouthX).^2 + diff(d.mouthY).^2)] * 60;
        d.mouth_speed = filtfilt(b_filt, a_filt, raw_speed);

        % Global metrics: dFF/dt
        d.dFF_dt = [0; diff(d.fip_signal_corr)] * 60;

        % Initialize trial-specific columns
        d.distance_to_reward = nan(height(d), 1);
        d.speed_to_reward = nan(height(d), 1);
        d.time_to_go = nan(height(d), 1);
        d.final_approach = false(height(d), 1);
        d.trial_number = nan(height(d), 1);
        d.trial_valve_id = nan(height(d), 1);
        d.trial_light_idx = nan(height(d), 1);
        d.trial_nearest_end_light_idx = nan(height(d), 1);
        d.trial_valve_match_ok = false(height(d), 1);
        d.trial_rotation_deg = nan(height(d), 1);

        % Get trial boundaries
        start_mask = strcmp(d_old.type, 'start_of_trial');
        end_mask = strcmp(d_old.type, 'end_of_trial');
        start_times = d_old.time(start_mask);
        start_valves = d_old.Valve_ID(start_mask);
        end_times = d_old.time(end_mask);

        % Get reward locations
        light_pixels = all_data(animal).data(day).ttl_roi2.light_pixels;
        valid_light_mask = cellfun(@(px) isnumeric(px) && numel(px) >= 2, light_pixels);
        valid_light_idx = find(valid_light_mask);
        if isempty(valid_light_idx)
            fprintf('WARNING A%d D%d: no valid light_pixels found, skipping trial metrics\n', animal, day);
            all_data(animal).data(day).d = d;
            continue;
        end

        light_pos_mat = cell2mat(cellfun(@(px) double(px(1:2)), light_pixels(valid_light_idx), 'UniformOutput', false)');
        arena_center = mean(light_pos_mat, 1);

        % New events to add
        new_events = table('Size', [0, width(d_old)], 'VariableTypes', varfun(@class, d_old, 'OutputFormat', 'cell'), 'VariableNames', d_old.Properties.VariableNames);

        for i_trial = 1:length(start_times)
            t_start = start_times(i_trial);
            valve_id = start_valves(i_trial);

            % Find matching end_of_trial
            t_end_idx = find(end_times > t_start, 1);
            if isempty(t_end_idx); continue; end
            t_end = end_times(t_end_idx);

            % Get reward location
            if ~isKey(valve_to_idx, valve_id); continue; end
            expected_valve_idx = valve_to_idx(valve_id);
            if expected_valve_idx < 1 || expected_valve_idx > numel(light_pixels); continue; end
            reward_pos = light_pixels{expected_valve_idx};
            if ~isnumeric(reward_pos) || numel(reward_pos) < 2; continue; end
            reward_pos = double(reward_pos(1:2));
            reward_x = reward_pos(1);
            reward_y = reward_pos(2);

            % Trial frame mask
            trial_mask = d.time >= t_start & d.time <= t_end;
            trial_idx = find(trial_mask);
            if isempty(trial_idx); continue; end

            reward_vec = reward_pos - arena_center;
            theta_reward = atan2(reward_vec(2), reward_vec(1));
            % Use image-top as the numeric target so the reward valve appears
            % at the visual bottom in MATLAB's y-up plotting coordinates.
            theta_target = -pi / 2;
            trial_rotation_deg = rad2deg(theta_target - theta_reward);

            d.trial_number(trial_mask) = i_trial;
            d.trial_valve_id(trial_mask) = valve_id;
            d.trial_light_idx(trial_mask) = expected_valve_idx;
            d.trial_rotation_deg(trial_mask) = trial_rotation_deg;

            % Distance to reward
            dist_to_reward = sqrt((d.mouthX(trial_mask) - reward_x).^2 + (d.mouthY(trial_mask) - reward_y).^2);
            d.distance_to_reward(trial_mask) = dist_to_reward;

            % Validation: check if mouth is closest to expected valve at trial end
            end_x = d.mouthX(trial_idx(end));
            end_y = d.mouthY(trial_idx(end));
            dists_to_all = nan(1, numel(light_pixels));
            for v = valid_light_idx(:)'
                vpos = light_pixels{v};
                dists_to_all(v) = sqrt((end_x - vpos(1))^2 + (end_y - vpos(2))^2);
            end
            [~, closest_valve_idx] = min(dists_to_all);
            if all(isnan(dists_to_all))
                closest_valve_idx = nan;
            end
            valve_match_ok = ~isnan(closest_valve_idx) && closest_valve_idx == expected_valve_idx;
            d.trial_nearest_end_light_idx(trial_mask) = closest_valve_idx;
            d.trial_valve_match_ok(trial_mask) = valve_match_ok;
            if ~valve_match_ok
                fprintf('WARNING A%d D%d Trial %d: nearest light idx %g, expected light idx %d (valve_id=%d)\n', ...
                    animal, day, i_trial, closest_valve_idx, expected_valve_idx, valve_id);
            end

            % Speed to reward (negative gradient = approaching)
            raw_speed_to_reward = -gradient(dist_to_reward) * 60;
            if length(raw_speed_to_reward) > 12  % need enough samples for filter
                d.speed_to_reward(trial_mask) = filtfilt(b_filt, a_filt, raw_speed_to_reward);
            else
                d.speed_to_reward(trial_mask) = raw_speed_to_reward;
            end

            % Time to go
            d.time_to_go(trial_mask) = d.distance_to_reward(trial_mask) ./ d.speed_to_reward(trial_mask);

            % Final approach detection
            speed_tr = d.speed_to_reward(trial_mask);
            dist_tr = d.distance_to_reward(trial_mask);
            n_frames_trial = length(speed_tr);

            % Find frames moving away (speed < 0) but not already at reward (dist > 5)
            moving_away = (speed_tr < 0) & (dist_tr > 5);

            % Count backwards from end to find consistent approach
            frames_away = flipud(cumsum(flipud(moving_away)));
            if n_frames_trial >= 10
                frames_away = frames_away - frames_away(end-9);
            end
            final_approach_mask = frames_away < 1;

            % Mark final approach in d
            d.final_approach(trial_idx(final_approach_mask)) = true;

            % Find final approach start time
            fa_start_idx = find(final_approach_mask, 1);
            if ~isempty(fa_start_idx)
                fa_start_time = d.time(trial_idx(fa_start_idx));

                % Create new event row
                new_row = d_old(1, :);
                new_row.type = {'final_approach_start'};
                new_row.time = fa_start_time;
                new_row.Valve_ID = valve_id;
                new_events = [new_events; new_row];
            end
        end

        % Add new events to d_old and sort by time
        if height(new_events) > 0
            d_old = [d_old; new_events];
            d_old = sortrows(d_old, 'time');
            all_data(animal).data(day).d_old = d_old;
        end

        all_data(animal).data(day).d = d;
        fprintf('A%d D%d: added movement metrics, %d final_approach events\n', animal, day, height(new_events));
    end
end

%
