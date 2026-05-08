
% Plot single syllable occurrences within trials across days or animals
% Requires: all_data from a00_load_data.m pipeline
%           sorted_syllables, cmap25 from a00_process_data.m

mode = 'across_days';       % 'across_days' or 'across_animals'
selected_syllables = [14, 16, 22, 20, 29];  % syllable ID(s) to highlight, can be array
animal_filter = 4:6;        % animal(s) to plot (for 'across_days' mode), can be array e.g. 1:6
valve_filter = 0;           % valve to filter by (0 = all valves, or specific valve 1-3)
trial_height = 2;
trial_gap = 0.3;
fs = 60;                    % frame rate (fps)
cap_filter = 3;             % max x-axis limit in seconds (0 = no cap, use actual max)
show_trial_edge = false;    % show gray edge around trial rectangles
skip_animals_days = [0 0];  % [animal, day] pairs to skip

% build trajectories table from all_data
trajectories = table();

for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end

        d_old = all_data(animal).data(day).d_old;
        d = all_data(animal).data(day).d;
        if isempty(d_old) || isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end

        % find trial boundaries and final approach times
        start_mask = strcmp(d_old.type, 'start_of_trial');
        end_mask = strcmp(d_old.type, 'end_of_trial');
        final_approach_mask = strcmp(d_old.type, 'final_approach_start');
        start_times = d_old.time(start_mask);
        end_times = d_old.time(end_mask);
        final_approach_times = d_old.time(final_approach_mask);
        start_valves = d_old.Valve_ID(start_mask);

        % pair each start with the next end
        for i_start = 1:length(start_times)
            t_start = start_times(i_start);
            t_end_idx = find(end_times > t_start, 1);
            if isempty(t_end_idx); continue; end
            t_end = end_times(t_end_idx);

            % extract trial data
            mask = d.time >= t_start & d.time <= t_end;
            if sum(mask) < 2; continue; end

            traj = table();
            traj.syllable = {d.syllable(mask)};
            traj.animal = animal;
            traj.day = day;
            traj.valve = start_valves(i_start);

            % find final_approach_start index within this trial
            fa_event_idx = find(final_approach_times > t_start & final_approach_times < t_end, 1);
            if ~isempty(fa_event_idx)
                fa_time = final_approach_times(fa_event_idx);
                trial_times = d.time(mask);
                [~, fa_traj_idx] = min(abs(trial_times - fa_time));
                traj.fa_idx = fa_traj_idx;
            else
                traj.fa_idx = NaN;
            end

            trajectories = [trajectories; traj];
        end
    end
end

fprintf('%d total trajectories found\n', height(trajectories));

% get colors for selected syllables from cmap25
syl_colors = zeros(length(selected_syllables), 3);
for i_syl = 1:length(selected_syllables)
    syl_idx = find(sorted_syllables == selected_syllables(i_syl), 1);
    if ~isempty(syl_idx)
        syl_colors(i_syl, :) = cmap25(syl_idx, :);
    else
        syl_colors(i_syl, :) = [0.5 0.5 0.5];  % gray for syllables not in sorted_syllables
    end
end

% set edge color for trial rectangles
if show_trial_edge
    trial_edge_color = [0.8 0.8 0.8];
else
    trial_edge_color = 'none';
end

% filter trajectories based on mode
if strcmp(mode, 'across_days')
    traj_filt = trajectories(ismember(trajectories.animal, animal_filter), :);
    if valve_filter > 0
        traj_filt = traj_filt(traj_filt.valve == valve_filter, :);
    end
    traj_filt = traj_filt(traj_filt.day >= 1 & traj_filt.day <= 5, :);
    col_vals = 1:5;
    col_field = 'day';
    col_label = 'Day';
    syl_str = strjoin(string(selected_syllables), ',');
    if length(animal_filter) == 1
        title_str = sprintf('Syllables [%s] - Animal %d', syl_str, animal_filter);
    else
        title_str = sprintf('Syllables [%s] - Animals %d-%d', syl_str, min(animal_filter), max(animal_filter));
    end
    group_field = 'animal';  % group trials by animal within each day
    group_vals = animal_filter;
elseif strcmp(mode, 'across_animals')
    traj_filt = trajectories(trajectories.day == 5, :);
    if valve_filter > 0
        traj_filt = traj_filt(traj_filt.valve == valve_filter, :);
    end
    col_vals = 1:6;
    col_field = 'animal';
    col_label = 'A';
    syl_str = strjoin(string(selected_syllables), ',');
    title_str = sprintf('Syllables [%s] - Day 5', syl_str);
    group_field = '';  % no grouping for across_animals
    group_vals = [];
else
    error('Invalid mode: use ''across_days'' or ''across_animals''');
end

n_cols = length(col_vals);
fprintf('%d trajectories for %s mode\n', height(traj_filt), mode);

if height(traj_filt) == 0
    error('No trajectories match filter');
end

% find max trial length across all columns for consistent x-axis (in seconds)
max_len_frames = max(cellfun(@length, traj_filt.syllable));
max_len = max_len_frames / fs;
if cap_filter > 0
    max_len = min(max_len, cap_filter);
end

% count max trials per column for figure sizing
max_trials_per_col = 0;
for i_col = 1:n_cols
    col_traj = traj_filt(traj_filt.(col_field) == col_vals(i_col), :);
    max_trials_per_col = max(max_trials_per_col, height(col_traj));
end

trial_step = trial_height + trial_gap;
fig_height = max(300, trial_step * max_trials_per_col * 15);
[fig, tl] = myFigure(1, n_cols, 600, fig_height, true);
title(tl, title_str);

for i_col = 1:n_cols
    col_val = col_vals(i_col);
    col_traj = traj_filt(traj_filt.(col_field) == col_val, :);
    n_trials = height(col_traj);

    ax = nexttile(tl);
    hold(ax, 'on');

    y_pos = n_trials * trial_step;

    % check if we need to group by another field (e.g., animals within days)
    if ~isempty(group_field)
        for i_grp = 1:length(group_vals)
            grp_val = group_vals(i_grp);
            grp_traj = col_traj(col_traj.(group_field) == grp_val, :);
            n_grp = height(grp_traj);

            for i_t = 1:n_grp
                y_pos = y_pos - trial_step;
                syl = grp_traj.syllable{i_t};
                len_frames = length(syl);
                len_sec = len_frames / fs;
                x_offset = max_len - len_sec;
                fa_idx = grp_traj.fa_idx(i_t);

                % draw white background for full trial
                rectangle(ax, 'Position', [x_offset, y_pos, len_sec, trial_height], ...
                    'FaceColor', [1 1 1], 'EdgeColor', trial_edge_color);

                % find runs of each selected syllable
                for i_syl = 1:length(selected_syllables)
                    sel_syl = selected_syllables(i_syl);
                    syl_color = syl_colors(i_syl, :);

                    mask = (syl == sel_syl);
                    if any(mask)
                        mask_diff = diff([0; mask(:); 0]);
                        run_starts = find(mask_diff == 1);
                        run_ends = find(mask_diff == -1) - 1;

                        for i_run = 1:length(run_starts)
                            rs = run_starts(i_run);
                            re = run_ends(i_run);
                            rl = re - rs + 1;

                            x = x_offset + (rs - 1) / fs;
                            rectangle(ax, 'Position', [x, y_pos, rl / fs, trial_height], ...
                                'FaceColor', syl_color, 'EdgeColor', 'none');
                        end
                    end
                end

                % draw red vertical line at final_approach_start
                if ~isnan(fa_idx) && fa_idx > 0 && fa_idx <= len_frames
                    fa_x = x_offset + (fa_idx - 1) / fs;
                    plot(ax, [fa_x fa_x], [y_pos, y_pos + trial_height], 'r-', 'LineWidth', 1.5);
                end
            end

            % add animal label on left side (above separator line position)
            if n_grp > 0
                text(ax, 0.02, y_pos + trial_step * 0.3, sprintf('A%d', grp_val), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
            end

            % add separator line after each group (except last)
            if i_grp < length(group_vals) && n_grp > 0
                plot(ax, [0 max_len], [y_pos y_pos], 'k-', 'LineWidth', 1.5);
            end
        end
    else
        % no grouping - plot all trials directly
        for i_t = 1:n_trials
            y_pos = y_pos - trial_step;
            syl = col_traj.syllable{i_t};
            len_frames = length(syl);
            len_sec = len_frames / fs;
            x_offset = max_len - len_sec;
            fa_idx = col_traj.fa_idx(i_t);

            % draw white background for full trial
            rectangle(ax, 'Position', [x_offset, y_pos, len_sec, trial_height], ...
                'FaceColor', [1 1 1], 'EdgeColor', trial_edge_color);

            % find runs of each selected syllable
            for i_syl = 1:length(selected_syllables)
                sel_syl = selected_syllables(i_syl);
                syl_color = syl_colors(i_syl, :);

                mask = (syl == sel_syl);
                if any(mask)
                    mask_diff = diff([0; mask(:); 0]);
                    run_starts = find(mask_diff == 1);
                    run_ends = find(mask_diff == -1) - 1;

                    for i_run = 1:length(run_starts)
                        rs = run_starts(i_run);
                        re = run_ends(i_run);
                        rl = re - rs + 1;

                        x = x_offset + (rs - 1) / fs;
                        rectangle(ax, 'Position', [x, y_pos, rl / fs, trial_height], ...
                            'FaceColor', syl_color, 'EdgeColor', 'none');
                    end
                end
            end

            % draw red vertical line at final_approach_start
            if ~isnan(fa_idx) && fa_idx > 0 && fa_idx <= len_frames
                fa_x = x_offset + (fa_idx - 1) / fs;
                plot(ax, [fa_x fa_x], [y_pos, y_pos + trial_height], 'r-', 'LineWidth', 1.5);
            end
        end
    end

    xlim(ax, [0 max_len]);
    ylim(ax, [0 max_trials_per_col * trial_step]);
    set(ax, 'YDir', 'normal');
    set(ax, 'YTick', []);
    xlabel(ax, 'Time (s)');
    title(ax, sprintf('%s%d (n=%d)', col_label, col_val, n_trials));
end

% add legend
syl_str = strjoin(string(selected_syllables), ', ');
annotation(fig, 'textbox', [0.01 0.01 0.4 0.03], ...
    'String', sprintf('Syllables: %s | Red line = final approach', syl_str), ...
    'EdgeColor', 'none', 'FontSize', 9);
