% c01c_trial_end_motif_analysis.m
% Analyzes syllable behavior relative to trial completion
% Focuses on day 5 only, within-trial periods only
% Uses top 25 sorted_syllables with cmap25 colors
%
% Metrics (5 rows):
% 1. Average syllable transitions to trial end
% 2. Percentage of trials where syllable was present
% 3. Average FIP activity (NAcLat vs NAcMed clustered bars)
% 4. Time from syllable middle to reward (trial end)
% 5. Trajectory distance from syllable middle to reward

skip_animals_days = [0 0];
top_n = 25;
top25 = sorted_syllables(1:top_n);
day_to_analyze = 5;
n_animals = length(all_data);

% symbols for individual animal scatter points
animal_symbols = {'o', 's', 'd', '^', 'v', '>'};
animal_marker_size = 20;

% per-animal means for each metric (for SEM calculation)
transitions_per_animal = NaN(n_animals, top_n);
presence_per_animal = NaN(n_animals, top_n);
fip_naclat_per_animal = NaN(n_animals, top_n);
fip_nacmed_per_animal = NaN(n_animals, top_n);
time_to_reward_per_animal = NaN(n_animals, top_n);
dist_to_reward_per_animal = NaN(n_animals, top_n);
trials_per_animal = zeros(n_animals, 1);

% main loop: animals -> day 5 -> trials
for animal = 1:n_animals
    if ismember([animal, day_to_analyze], skip_animals_days, 'rows'); continue; end

    if day_to_analyze > length(all_data(animal).data); continue; end
    d = all_data(animal).data(day_to_analyze).d;
    d_old = all_data(animal).data(day_to_analyze).d_old;

    if isempty(d) || isempty(d_old); continue; end
    if ~ismember('syllable', d.Properties.VariableNames); continue; end

    region = all_data(animal).region;
    is_naclat = strcmp(region, 'NAcLat');

    % get trial boundaries
    start_mask = strcmp(d_old.type, 'start_of_trial');
    end_mask = strcmp(d_old.type, 'end_of_trial');
    start_times = d_old.time(start_mask);
    end_times = d_old.time(end_mask);

    % temporary storage for this animal's trials
    animal_transitions = cell(top_n, 1);
    animal_presence = cell(top_n, 1);
    animal_fip = cell(top_n, 1);
    animal_time = cell(top_n, 1);
    animal_dist = cell(top_n, 1);
    for i = 1:top_n
        animal_transitions{i} = [];
        animal_presence{i} = [];
        animal_fip{i} = [];
        animal_time{i} = [];
        animal_dist{i} = [];
    end
    animal_trial_count = 0;

    % process each trial
    for i_trial = 1:length(start_times)
        t_start = start_times(i_trial);
        t_end_idx = find(end_times > t_start, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);

        % get trial data mask
        trial_mask = d.time >= t_start & d.time <= t_end;
        if sum(trial_mask) < 2; continue; end

        trial_syllables = d.syllable(trial_mask);
        trial_times = d.time(trial_mask);
        trial_x = d.centroidX(trial_mask);
        trial_y = d.centroidY(trial_mask);
        trial_fip = d.fip_signal_corr(trial_mask);

        n_frames = length(trial_syllables);
        trial_end_time = trial_times(end);

        % build syllable run sequence for this trial
        run_starts = [1; find(diff(trial_syllables) ~= 0) + 1];
        run_ends = [run_starts(2:end) - 1; n_frames];
        run_syllables = trial_syllables(run_starts);
        n_runs = length(run_starts);

        animal_trial_count = animal_trial_count + 1;

        % for each top-25 syllable, compute metrics
        for i_syl = 1:top_n
            syl = top25(i_syl);

            % find all bouts of this syllable in this trial
            bout_indices = find(run_syllables == syl);

            if isempty(bout_indices)
                animal_presence{i_syl} = [animal_presence{i_syl}; 0];
                continue;
            end

            animal_presence{i_syl} = [animal_presence{i_syl}; 1];

            % compute metrics for each bout, then average for this trial
            bout_transitions = [];
            bout_fip = [];
            bout_time_to_reward = [];
            bout_dist_to_reward = [];

            for i_bout = 1:length(bout_indices)
                bout_idx = bout_indices(i_bout);
                bout_start_frame = run_starts(bout_idx);
                bout_end_frame = run_ends(bout_idx);
                bout_mid_frame = round((bout_start_frame + bout_end_frame) / 2);

                % 1. transitions to trial end
                transitions_remaining = n_runs - bout_idx;
                bout_transitions = [bout_transitions; transitions_remaining];

                % 2. FIP activity during this bout
                bout_fip_vals = trial_fip(bout_start_frame:bout_end_frame);
                bout_fip_vals = bout_fip_vals(~isnan(bout_fip_vals));
                if ~isempty(bout_fip_vals)
                    bout_fip = [bout_fip; mean(bout_fip_vals)];
                end

                % 3. time from middle of bout to trial end
                mid_time = trial_times(bout_mid_frame);
                time_to_end = trial_end_time - mid_time;
                bout_time_to_reward = [bout_time_to_reward; time_to_end];

                % 4. trajectory distance from middle of bout to trial end
                if bout_mid_frame < n_frames
                    traj_x = trial_x(bout_mid_frame:end);
                    traj_y = trial_y(bout_mid_frame:end);
                    dx = diff(traj_x);
                    dy = diff(traj_y);
                    traj_dist = sum(sqrt(dx.^2 + dy.^2));
                else
                    traj_dist = 0;
                end
                bout_dist_to_reward = [bout_dist_to_reward; traj_dist];
            end

            % average across bouts for this trial
            if ~isempty(bout_transitions)
                animal_transitions{i_syl} = [animal_transitions{i_syl}; mean(bout_transitions)];
            end
            if ~isempty(bout_fip)
                animal_fip{i_syl} = [animal_fip{i_syl}; mean(bout_fip)];
            end
            if ~isempty(bout_time_to_reward)
                animal_time{i_syl} = [animal_time{i_syl}; mean(bout_time_to_reward)];
            end
            if ~isempty(bout_dist_to_reward)
                animal_dist{i_syl} = [animal_dist{i_syl}; mean(bout_dist_to_reward)];
            end
        end
    end

    % compute per-animal means
    trials_per_animal(animal) = animal_trial_count;
    for i_syl = 1:top_n
        if ~isempty(animal_transitions{i_syl})
            transitions_per_animal(animal, i_syl) = mean(animal_transitions{i_syl});
        end
        if ~isempty(animal_presence{i_syl})
            presence_per_animal(animal, i_syl) = sum(animal_presence{i_syl}) / animal_trial_count * 100;
        end
        if ~isempty(animal_fip{i_syl})
            if is_naclat
                fip_naclat_per_animal(animal, i_syl) = mean(animal_fip{i_syl});
            else
                fip_nacmed_per_animal(animal, i_syl) = mean(animal_fip{i_syl});
            end
        end
        if ~isempty(animal_time{i_syl})
            time_to_reward_per_animal(animal, i_syl) = mean(animal_time{i_syl});
        end
        if ~isempty(animal_dist{i_syl})
            dist_to_reward_per_animal(animal, i_syl) = mean(animal_dist{i_syl});
        end
    end
end

total_trials = sum(trials_per_animal);

% compute means and SEM across animals
mean_transitions = nanmean(transitions_per_animal, 1)';
sem_transitions = nanstd(transitions_per_animal, 0, 1)' / sqrt(sum(~isnan(transitions_per_animal(:,1))));

pct_presence = nanmean(presence_per_animal, 1)';
sem_presence = nanstd(presence_per_animal, 0, 1)' / sqrt(n_animals);

n_naclat = sum(~isnan(fip_naclat_per_animal(:,1)));
n_nacmed = sum(~isnan(fip_nacmed_per_animal(:,1)));
mean_naclat = nanmean(fip_naclat_per_animal, 1)';
mean_nacmed = nanmean(fip_nacmed_per_animal, 1)';
sem_naclat = nanstd(fip_naclat_per_animal, 0, 1)' / sqrt(n_naclat);
sem_nacmed = nanstd(fip_nacmed_per_animal, 0, 1)' / sqrt(n_nacmed);

mean_time_to_reward = nanmean(time_to_reward_per_animal, 1)';
sem_time_to_reward = nanstd(time_to_reward_per_animal, 0, 1)' / sqrt(sum(~isnan(time_to_reward_per_animal(:,1))));

mean_dist_to_reward = nanmean(dist_to_reward_per_animal, 1)';
sem_dist_to_reward = nanstd(dist_to_reward_per_animal, 0, 1)' / sqrt(sum(~isnan(dist_to_reward_per_animal(:,1))));

%--------------------------------------------------------------------------
% Figure: 5 rows of bar plots

bar_width = 0.35;
color_naclat = [17 113 190] / 255;   % #1171BE blue
color_nacmed = [221 84 0] / 255;     % #DD5400 orange

[fig, tl] = myFigure(5, 1, 1200, 200, true);
title(tl, sprintf('Trial-end motif analysis (Day %d, n=%d trials, top 25 syllables)', day_to_analyze, total_trials));

%--------------------------------------------------------------------------
% Row 1: Average syllable transitions to trial end
ax1 = nexttile(tl);
hold(ax1, 'on');
for i = 1:top_n
    bar(ax1, i, mean_transitions(i), bar_width*2, 'FaceColor', cmap25(i, :), 'EdgeColor', 'k', 'LineWidth', 0.5);
    plot(ax1, [i i], [mean_transitions(i) - sem_transitions(i), mean_transitions(i) + sem_transitions(i)], 'k-', 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(transitions_per_animal(a, i))
            scatter(ax1, i, transitions_per_animal(a, i), animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax1, 'off');
xlim(ax1, [0 top_n + 1]);
set(ax1, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax1, '# transitions');
title(ax1, 'Avg syllable transitions to trial end (0 = last syllable)');

%--------------------------------------------------------------------------
% Row 2: Percentage of trials with syllable present
ax2 = nexttile(tl);
hold(ax2, 'on');
for i = 1:top_n
    bar(ax2, i, pct_presence(i), bar_width*2, 'FaceColor', cmap25(i, :), 'EdgeColor', 'k', 'LineWidth', 0.5);
    plot(ax2, [i i], [pct_presence(i) - sem_presence(i), pct_presence(i) + sem_presence(i)], 'k-', 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(presence_per_animal(a, i))
            scatter(ax2, i, presence_per_animal(a, i), animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax2, 'off');
xlim(ax2, [0 top_n + 1]);
ylim(ax2, [0 100]);
set(ax2, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax2, '% trials');
title(ax2, 'Percentage of trials where syllable was present');

%--------------------------------------------------------------------------
% Row 3: Average FIP activity (NAcLat vs NAcMed clustered)
ax3 = nexttile(tl);
hold(ax3, 'on');
for i = 1:top_n
    % NAcLat bar (left)
    bar(ax3, i - bar_width/2, mean_naclat(i), bar_width, 'FaceColor', cmap25(i, :), 'EdgeColor', color_naclat, 'LineWidth', 2);
    plot(ax3, [i - bar_width/2, i - bar_width/2], [mean_naclat(i) - sem_naclat(i), mean_naclat(i) + sem_naclat(i)], '-', 'Color', color_naclat, 'LineWidth', 1);
    % NAcMed bar (right)
    bar(ax3, i + bar_width/2, mean_nacmed(i), bar_width, 'FaceColor', cmap25(i, :), 'EdgeColor', color_nacmed, 'LineWidth', 2);
    plot(ax3, [i + bar_width/2, i + bar_width/2], [mean_nacmed(i) - sem_nacmed(i), mean_nacmed(i) + sem_nacmed(i)], '-', 'Color', color_nacmed, 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(fip_naclat_per_animal(a, i))
            scatter(ax3, i - bar_width/2, fip_naclat_per_animal(a, i), animal_marker_size, color_naclat, animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
        if ~isnan(fip_nacmed_per_animal(a, i))
            scatter(ax3, i + bar_width/2, fip_nacmed_per_animal(a, i), animal_marker_size, color_nacmed, animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax3, 'off');
xlim(ax3, [0 top_n + 1]);
set(ax3, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax3, 'dF/F (z)');
title(ax3, 'Avg FIP activity during syllable (NAcLat=blue edge, NAcMed=orange edge)');

%--------------------------------------------------------------------------
% Row 4: Time to reward from syllable middle
ax4 = nexttile(tl);
hold(ax4, 'on');
for i = 1:top_n
    bar(ax4, i, mean_time_to_reward(i), bar_width*2, 'FaceColor', cmap25(i, :), 'EdgeColor', 'k', 'LineWidth', 0.5);
    plot(ax4, [i i], [mean_time_to_reward(i) - sem_time_to_reward(i), mean_time_to_reward(i) + sem_time_to_reward(i)], 'k-', 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(time_to_reward_per_animal(a, i))
            scatter(ax4, i, time_to_reward_per_animal(a, i), animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax4, 'off');
xlim(ax4, [0 top_n + 1]);
set(ax4, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax4, 'Time (s)');
title(ax4, 'Avg time from syllable middle to trial end');

%--------------------------------------------------------------------------
% Row 5: Distance to reward (trajectory length)
ax5 = nexttile(tl);
hold(ax5, 'on');
for i = 1:top_n
    bar(ax5, i, mean_dist_to_reward(i), bar_width*2, 'FaceColor', cmap25(i, :), 'EdgeColor', 'k', 'LineWidth', 0.5);
    plot(ax5, [i i], [mean_dist_to_reward(i) - sem_dist_to_reward(i), mean_dist_to_reward(i) + sem_dist_to_reward(i)], 'k-', 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(dist_to_reward_per_animal(a, i))
            scatter(ax5, i, dist_to_reward_per_animal(a, i), animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax5, 'off');
xlim(ax5, [0 top_n + 1]);
set(ax5, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax5, 'Distance (px)');
title(ax5, 'Avg trajectory distance from syllable middle to trial end');

%--------------------------------------------------------------------------
% print summary
fprintf('\n=== Trial-end motif analysis (Day %d) ===\n', day_to_analyze);
fprintf('Total trials: %d\n', total_trials);
fprintf('\nTop 5 syllables closest to trial end (fewest transitions):\n');
[~, sorted_idx] = sort(mean_transitions);
for i = 1:min(5, top_n)
    idx = sorted_idx(i);
    fprintf('  Syl %d: %.2f transitions, %.1f%% presence, %.2fs to end\n', ...
        top25(idx), mean_transitions(idx), pct_presence(idx), mean_time_to_reward(idx));
end
