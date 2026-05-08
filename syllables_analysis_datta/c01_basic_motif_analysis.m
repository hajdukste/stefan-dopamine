function col = get_syl_color(syl, sorted_syllables, cmap25)
    % Get color for syllable from cmap25 (indexed by sorted_syllables)
    idx = find(sorted_syllables == syl, 1);
    if ~isempty(idx)
        col = cmap25(idx, :);
    else
        col = [0.5 0.5 0.5];  % gray for syllables not in sorted_syllables
    end
end

skip_animals_days = [0 0];
compare_mode = 'outside';  % 'all' = all data vs within-trial, 'outside' = outside-trial vs within-trial
show_animal_symbols = false;

n_animals = length(all_data);

% symbols for individual animal scatter points
animal_symbols = {'o', 's', 'd', '^', 'v', '>'};
animal_marker_size = 20;

% collect reference syllables (all data or outside-trial) and within-trial syllables
all_syl = [];
all_animal = [];
all_day = [];
all_syl_trial = [];
all_animal_trial = [];
all_day_trial = [];

for a = 1:n_animals
    for day = 1:length(all_data(a).data)
        if ismember([a, day], skip_animals_days, 'rows'); continue; end
        if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end

        d = all_data(a).data(day).d;
        d_old = all_data(a).data(day).d_old;

        if strcmp(compare_mode, 'all') || isempty(d_old)
            % all data mode or no trial info
            syl = d.syllable;
            all_syl = [all_syl; syl];
            all_animal = [all_animal; repmat(a, length(syl), 1)];
            all_day = [all_day; repmat(day, length(syl), 1)];
        else
            % find trial periods
            start_mask = strcmp(d_old.type, 'start_of_trial');
            end_mask = strcmp(d_old.type, 'end_of_trial');
            start_times = d_old.time(start_mask);
            end_times = d_old.time(end_mask);

            % build mask for all within-trial timepoints
            in_trial = false(height(d), 1);
            for i_start = 1:length(start_times)
                t_start = start_times(i_start);
                t_end_idx = find(end_times > t_start, 1);
                if isempty(t_end_idx); continue; end
                t_end = end_times(t_end_idx);
                in_trial = in_trial | (d.time >= t_start & d.time <= t_end);
            end

            % collect within-trial
            n_pts = sum(in_trial);
            all_syl_trial = [all_syl_trial; d.syllable(in_trial)];
            all_animal_trial = [all_animal_trial; repmat(a, n_pts, 1)];
            all_day_trial = [all_day_trial; repmat(day, n_pts, 1)];

            % collect outside-trial
            outside_trial = ~in_trial;
            n_pts_out = sum(outside_trial);
            all_syl = [all_syl; d.syllable(outside_trial)];
            all_animal = [all_animal; repmat(a, n_pts_out, 1)];
            all_day = [all_day; repmat(day, n_pts_out, 1)];
        end
    end
end

% for 'all' mode, still need to collect within-trial separately
if strcmp(compare_mode, 'all')
    for a = 1:n_animals
        for day = 1:length(all_data(a).data)
            if ismember([a, day], skip_animals_days, 'rows'); continue; end
            if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end

            d = all_data(a).data(day).d;
            d_old = all_data(a).data(day).d_old;
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
                n_pts = sum(mask);
                all_syl_trial = [all_syl_trial; d.syllable(mask)];
                all_animal_trial = [all_animal_trial; repmat(a, n_pts, 1)];
                all_day_trial = [all_day_trial; repmat(day, n_pts, 1)];
            end
        end
    end
end

valid_all = all_syl >= 0;
all_syl = all_syl(valid_all);
all_animal = all_animal(valid_all);
all_day = all_day(valid_all);

valid_trial = all_syl_trial >= 0;
all_syl_trial = all_syl_trial(valid_trial);
all_animal_trial = all_animal_trial(valid_trial);
all_day_trial = all_day_trial(valid_trial);

% labels based on mode
if strcmp(compare_mode, 'all')
    ref_label = 'All data';
else
    ref_label = 'Outside-trial';
end

% pooled counts sorted by frequency (all data)
unique_syl = unique(all_syl);
n_syl = length(unique_syl);
pooled_counts = histcounts(all_syl, [unique_syl; max(unique_syl)+1])';
[pooled_sorted, sort_idx] = sort(pooled_counts, 'descend');
syl_order = unique_syl(sort_idx);

% within-trial counts
unique_syl_trial = unique(all_syl_trial);
n_syl_trial = length(unique_syl_trial);
pooled_counts_trial_own = histcounts(all_syl_trial, [unique_syl_trial; max(unique_syl_trial)+1])';
[pooled_sorted_trial_own, sort_idx_trial] = sort(pooled_counts_trial_own, 'descend');
syl_order_trial = unique_syl_trial(sort_idx_trial);

top_n = min(20, n_syl);
top_n_trial = min(20, n_syl_trial);
top20_all = syl_order(1:top_n);
top20_trial = syl_order_trial(1:top_n_trial);

% day 1 vs day 5 within-trial counts
day1_mask = all_day_trial == 1;
day5_mask = all_day_trial == 5;
syl_day1 = all_syl_trial(day1_mask);
syl_day5 = all_syl_trial(day5_mask);

unique_syl_day1 = unique(syl_day1);
unique_syl_day5 = unique(syl_day5);
n_syl_day1 = length(unique_syl_day1);
n_syl_day5 = length(unique_syl_day5);

counts_day1 = histcounts(syl_day1, [unique_syl_day1; max(unique_syl_day1)+1])';
counts_day5 = histcounts(syl_day5, [unique_syl_day5; max(unique_syl_day5)+1])';
[sorted_day1, idx_day1] = sort(counts_day1, 'descend');
[sorted_day5, idx_day5] = sort(counts_day5, 'descend');
syl_order_day1 = unique_syl_day1(idx_day1);
syl_order_day5 = unique_syl_day5(idx_day5);

top_n_day1 = min(20, n_syl_day1);
top_n_day5 = min(20, n_syl_day5);
top20_day1 = syl_order_day1(1:top_n_day1);
top20_day5 = syl_order_day5(1:top_n_day5);

% all days all times (for column 3 top)
syl_all_days_all = [];
for a = 1:n_animals
    for day = 1:length(all_data(a).data)
        if ismember([a, day], skip_animals_days, 'rows'); continue; end
        if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end
        d = all_data(a).data(day).d;
        syl_all_days_all = [syl_all_days_all; d.syllable];
    end
end
syl_all_days_all = syl_all_days_all(syl_all_days_all >= 0);
unique_syl_all_days_all = unique(syl_all_days_all);
n_syl_all_days_all = length(unique_syl_all_days_all);
counts_all_days_all = histcounts(syl_all_days_all, [unique_syl_all_days_all; max(unique_syl_all_days_all)+1])';
[sorted_all_days_all, idx_all_days_all] = sort(counts_all_days_all, 'descend');
syl_order_all_days_all = unique_syl_all_days_all(idx_all_days_all);
top_n_all_days_all = min(20, n_syl_all_days_all);
top20_all_days_all = syl_order_all_days_all(1:top_n_all_days_all);

% day 1 all times (for column 3: day1 all vs day5 final approach)
syl_day1_all = [];
for a = 1:n_animals
    day = 1;
    if ismember([a, day], skip_animals_days, 'rows'); continue; end
    if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end
    d = all_data(a).data(day).d;
    syl_day1_all = [syl_day1_all; d.syllable];
end
syl_day1_all = syl_day1_all(syl_day1_all >= 0);
unique_syl_day1_all = unique(syl_day1_all);
n_syl_day1_all = length(unique_syl_day1_all);
counts_day1_all = histcounts(syl_day1_all, [unique_syl_day1_all; max(unique_syl_day1_all)+1])';
[sorted_day1_all, idx_day1_all] = sort(counts_day1_all, 'descend');
syl_order_day1_all = unique_syl_day1_all(idx_day1_all);
top_n_day1_all = min(20, n_syl_day1_all);
top20_day1_all = syl_order_day1_all(1:top_n_day1_all);

% day 5: final approach syllables
syl_day5_approach = [];
for a = 1:n_animals
    day = 5;
    if ismember([a, day], skip_animals_days, 'rows'); continue; end
    if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end

    d = all_data(a).data(day).d;
    d_old = all_data(a).data(day).d_old;
    if isempty(d_old); continue; end

    approach_mask = strcmp(d_old.type, 'final_approach_start');
    end_mask = strcmp(d_old.type, 'end_of_trial');
    approach_times = d_old.time(approach_mask);
    end_times = d_old.time(end_mask);

    for i_app = 1:length(approach_times)
        t_approach = approach_times(i_app);
        t_end_idx = find(end_times > t_approach, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);

        mask = d.time >= t_approach & d.time <= t_end;
        syl_day5_approach = [syl_day5_approach; d.syllable(mask)];
    end
end

syl_day5_approach = syl_day5_approach(syl_day5_approach >= 0);
unique_syl_day5_app = unique(syl_day5_approach);
n_syl_day5_app = length(unique_syl_day5_app);
counts_day5_app = histcounts(syl_day5_approach, [unique_syl_day5_app; max(unique_syl_day5_app)+1])';
[sorted_day5_app, idx_day5_app] = sort(counts_day5_app, 'descend');
syl_order_day5_app = unique_syl_day5_app(idx_day5_app);

top_n_day5_app = min(20, n_syl_day5_app);
top20_day5_app = syl_order_day5_app(1:top_n_day5_app);

% per-animal proportions for SEM error bars
% column 2: outside-trial vs within-trial
prop_all_per_animal = zeros(n_animals, top_n);
prop_trial_per_animal = zeros(n_animals, top_n_trial);
for a = 1:n_animals
    % outside-trial proportions
    mask_a = all_animal == a;
    syl_a = all_syl(mask_a);
    total_a = length(syl_a);
    if total_a > 0
        for i = 1:top_n
            prop_all_per_animal(a, i) = sum(syl_a == top20_all(i)) / total_a;
        end
    end
    % within-trial proportions
    mask_a_trial = all_animal_trial == a;
    syl_a_trial = all_syl_trial(mask_a_trial);
    total_a_trial = length(syl_a_trial);
    if total_a_trial > 0
        for i = 1:top_n_trial
            prop_trial_per_animal(a, i) = sum(syl_a_trial == top20_trial(i)) / total_a_trial;
        end
    end
end
mean_all = mean(prop_all_per_animal, 1);
sem_all = std(prop_all_per_animal, 0, 1) / sqrt(n_animals);
mean_trial = mean(prop_trial_per_animal, 1);
sem_trial = std(prop_trial_per_animal, 0, 1) / sqrt(n_animals);

% column 3: day1 vs day5 within-trial
prop_day1_per_animal = zeros(n_animals, top_n_day1);
prop_day5_per_animal = zeros(n_animals, top_n_day5);
for a = 1:n_animals
    % day 1
    mask_a_d1 = all_animal_trial == a & all_day_trial == 1;
    syl_a_d1 = all_syl_trial(mask_a_d1);
    total_a_d1 = length(syl_a_d1);
    if total_a_d1 > 0
        for i = 1:top_n_day1
            prop_day1_per_animal(a, i) = sum(syl_a_d1 == top20_day1(i)) / total_a_d1;
        end
    end
    % day 5
    mask_a_d5 = all_animal_trial == a & all_day_trial == 5;
    syl_a_d5 = all_syl_trial(mask_a_d5);
    total_a_d5 = length(syl_a_d5);
    if total_a_d5 > 0
        for i = 1:top_n_day5
            prop_day5_per_animal(a, i) = sum(syl_a_d5 == top20_day5(i)) / total_a_d5;
        end
    end
end
mean_day1 = mean(prop_day1_per_animal, 1);
sem_day1 = std(prop_day1_per_animal, 0, 1) / sqrt(n_animals);
mean_day5 = mean(prop_day5_per_animal, 1);
sem_day5 = std(prop_day5_per_animal, 0, 1) / sqrt(n_animals);

% column 3: all days all-times vs day 5 final approach per-animal proportions
prop_all_days_all_per_animal = zeros(n_animals, top_n_all_days_all);
prop_day5_app_per_animal = zeros(n_animals, top_n_day5_app);
syl_all_days_all_per_animal = cell(n_animals, 1);
syl_day5_app_per_animal = cell(n_animals, 1);
for a = 1:n_animals
    % all days all times
    syl_a_all_days = [];
    for day = 1:length(all_data(a).data)
        if ismember([a, day], skip_animals_days, 'rows'); continue; end
        if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end
        d = all_data(a).data(day).d;
        syl_a_all_days = [syl_a_all_days; d.syllable];
    end
    syl_a_all_days = syl_a_all_days(syl_a_all_days >= 0);
    syl_all_days_all_per_animal{a} = syl_a_all_days;
    total_a_all_days = length(syl_a_all_days);
    if total_a_all_days > 0
        for i = 1:top_n_all_days_all
            prop_all_days_all_per_animal(a, i) = sum(syl_a_all_days == top20_all_days_all(i)) / total_a_all_days;
        end
    end

    % day 5 final approach
    day = 5;
    if ismember([a, day], skip_animals_days, 'rows'); continue; end
    if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end

    d = all_data(a).data(day).d;
    d_old = all_data(a).data(day).d_old;
    if isempty(d_old); continue; end

    approach_mask = strcmp(d_old.type, 'final_approach_start');
    end_mask = strcmp(d_old.type, 'end_of_trial');
    approach_times = d_old.time(approach_mask);
    end_times = d_old.time(end_mask);

    syl_app_a = [];
    for i_app = 1:length(approach_times)
        t_approach = approach_times(i_app);
        t_end_idx = find(end_times > t_approach, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);
        mask = d.time >= t_approach & d.time <= t_end;
        syl_app_a = [syl_app_a; d.syllable(mask)];
    end
    syl_app_a = syl_app_a(syl_app_a >= 0);
    syl_day5_app_per_animal{a} = syl_app_a;
    total_app_a = length(syl_app_a);
    if total_app_a > 0
        for i = 1:top_n_day5_app
            prop_day5_app_per_animal(a, i) = sum(syl_app_a == top20_day5_app(i)) / total_app_a;
        end
    end
end
mean_all_days_all = mean(prop_all_days_all_per_animal, 1);
sem_all_days_all = std(prop_all_days_all_per_animal, 0, 1) / sqrt(n_animals);
mean_day5_app = mean(prop_day5_app_per_animal, 1);
sem_day5_app = std(prop_day5_app_per_animal, 0, 1) / sqrt(n_animals);

% column 4: day5 within-trial vs final approach
prop_day5_trial_per_animal = zeros(n_animals, top_n_day5);
for a = 1:n_animals
    day = 5;
    if ismember([a, day], skip_animals_days, 'rows'); continue; end
    if ~ismember('syllable', all_data(a).data(day).d.Properties.VariableNames); continue; end

    d = all_data(a).data(day).d;
    d_old = all_data(a).data(day).d_old;
    if isempty(d_old); continue; end

    % within-trial for day 5
    start_mask = strcmp(d_old.type, 'start_of_trial');
    end_mask = strcmp(d_old.type, 'end_of_trial');
    start_times = d_old.time(start_mask);
    end_times = d_old.time(end_mask);

    in_trial = false(height(d), 1);
    for i_start = 1:length(start_times)
        t_start = start_times(i_start);
        t_end_idx = find(end_times > t_start, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);
        in_trial = in_trial | (d.time >= t_start & d.time <= t_end);
    end
    syl_trial_a = d.syllable(in_trial);
    total_trial_a = length(syl_trial_a);
    if total_trial_a > 0
        for i = 1:top_n_day5
            prop_day5_trial_per_animal(a, i) = sum(syl_trial_a == top20_day5(i)) / total_trial_a;
        end
    end
end
mean_day5_trial = mean(prop_day5_trial_per_animal, 1);
sem_day5_trial = std(prop_day5_trial_per_animal, 0, 1) / sqrt(n_animals);

% helper to get bar colors using cmap25 (indexed by sorted_syllables)
get_bar_colors = @(syl_list) arrayfun(@(s) get_syl_color(s, sorted_syllables, cmap25), syl_list, 'UniformOutput', false);

% combined figure: 2 rows, 4 columns
[fig1, tl1] = myFigure(2, 4, 900, 300, true);
title(tl1, sprintf('Syllable distribution: %s vs Within-trial', ref_label));

% get colors for bars
colors_all = get_bar_colors(top20_all);
colors_trial = get_bar_colors(top20_trial);
colors_day1 = get_bar_colors(top20_day1);
colors_day5 = get_bar_colors(top20_day5);
colors_all_days_all = get_bar_colors(top20_all_days_all);
colors_day5_app = get_bar_colors(top20_day5_app);

% reference data - full (top-left)
ax = nexttile(tl1);
bar(ax, 1:n_syl, pooled_sorted, 'FaceColor', [0.5 0.5 0.5]);
xticks(ax, 1:n_syl);
xticklabels(ax, string(syl_order));
ylabel(ax, 'Timepoints');
title(ax, sprintf('%s - all syllables (n=%d)', ref_label, n_syl));

% rank comparison (right column, spanning 2 rows)
ax_cmp = nexttile(tl1, [2, 1]);
hold(ax_cmp, 'on');

% normalize counts for plotting
norm_all = pooled_sorted(1:top_n) / max(pooled_sorted(1:top_n));
norm_trial = pooled_sorted_trial_own(1:top_n_trial) / max(pooled_sorted_trial_own(1:top_n_trial));

% layout parameters
bar_width = 0.7;
max_bar_h = 0.8;  % max bar height in y-units
gap = 0.4;        % gap between bar rows for lines

% top bars go from y=gap/2 upward, bottom bars go from y=-gap/2 downward
y_top_base = gap/2;
y_bot_base = -gap/2;

% scale factor for error bars (proportion to bar height)
scale_all = max_bar_h / max(mean_all);
scale_trial = max_bar_h / max(mean_trial);

% draw top bars (all data) - bars grow upward
for i = 1:top_n
    h = norm_all(i) * max_bar_h;
    rectangle(ax_cmp, 'Position', [i - bar_width/2, y_top_base, bar_width, h], ...
        'FaceColor', colors_all{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_all(i) * scale_all;
    plot(ax_cmp, [i i], [y_top_base + h - err_h, y_top_base + h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_all_per_animal(a, i) > 0
                y_pt = y_top_base + prop_all_per_animal(a, i) * scale_all;
                scatter(ax_cmp, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw bottom bars (within-trial) - bars grow downward
for i = 1:top_n_trial
    h = norm_trial(i) * max_bar_h;
    rectangle(ax_cmp, 'Position', [i - bar_width/2, y_bot_base - h, bar_width, h], ...
        'FaceColor', colors_trial{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_trial(i) * scale_trial;
    plot(ax_cmp, [i i], [y_bot_base - h - err_h, y_bot_base - h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_trial_per_animal(a, i) > 0
                y_pt = y_bot_base - prop_trial_per_animal(a, i) * scale_trial;
                scatter(ax_cmp, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw connecting lines in the gap between bars
for i = 1:top_n
    syl = top20_all(i);
    j = find(top20_trial == syl, 1);
    if ~isempty(j)
        if i == j
            col = [0.6 0.6 0.6];
            lw = 1;
        else
            col = colors_all{i};
            lw = 1.5;
        end
        plot(ax_cmp, [i, j], [y_top_base, y_bot_base], '-', 'Color', [col 0.7], 'LineWidth', lw);
    end
end

% labels above top bars
for i = 1:top_n
    h = norm_all(i) * max_bar_h;
    syl = top20_all(i);
    marker = '';
    if ~ismember(syl, top20_trial)
        marker = ' v';  % dropped
    end
    text(ax_cmp, i, y_top_base + h + 0.05, [string(syl) + marker], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

% labels below bottom bars
for i = 1:top_n_trial
    h = norm_trial(i) * max_bar_h;
    syl = top20_trial(i);
    marker = '';
    if ~ismember(syl, top20_all)
        marker = ' ^';  % new
    end
    text(ax_cmp, i, y_bot_base - h - 0.05, [string(syl) + marker], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8);
end

xlim(ax_cmp, [0 max(top_n, top_n_trial) + 1]);
ylim(ax_cmp, [y_bot_base - max_bar_h - 0.3, y_top_base + max_bar_h + 0.3]);
set(ax_cmp, 'YTick', [y_bot_base - max_bar_h/2, y_top_base + max_bar_h/2], ...
    'YTickLabel', {'Within-trial', ref_label});
set(ax_cmp, 'XTick', []);
title(ax_cmp, 'Top 20 rank comparison (v=dropped from trial, ^=new in trial)');
hold(ax_cmp, 'off');

% within-trial - full (bottom-left)
ax = nexttile(tl1, 5);
bar(ax, 1:n_syl_trial, pooled_sorted_trial_own, 'FaceColor', [0.5 0.5 0.5]);
xticks(ax, 1:n_syl_trial);
xticklabels(ax, string(syl_order_trial));
ylabel(ax, 'Timepoints');
title(ax, sprintf('Within-trial - all syllables (n=%d)', n_syl_trial));

% all days (all times) vs day 5 (final approach) comparison (third column, spanning 2 rows)
ax_day = nexttile(tl1, 3, [2, 1]);
hold(ax_day, 'on');

% normalize counts for day comparison
norm_all_days_all = sorted_all_days_all(1:top_n_all_days_all) / max(sorted_all_days_all(1:top_n_all_days_all));
norm_day5_app_col3 = sorted_day5_app(1:top_n_day5_app) / max(sorted_day5_app(1:top_n_day5_app));

% scale factor for error bars
scale_all_days_all = max_bar_h / max(mean_all_days_all);
scale_day5_app_col3 = max_bar_h / max(mean_day5_app);

% draw top bars (all days all times) - bars grow upward
for i = 1:top_n_all_days_all
    h = norm_all_days_all(i) * max_bar_h;
    rectangle(ax_day, 'Position', [i - bar_width/2, y_top_base, bar_width, h], ...
        'FaceColor', colors_all_days_all{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_all_days_all(i) * scale_all_days_all;
    plot(ax_day, [i i], [y_top_base + h - err_h, y_top_base + h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_all_days_all_per_animal(a, i) > 0
                y_pt = y_top_base + prop_all_days_all_per_animal(a, i) * scale_all_days_all;
                scatter(ax_day, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw bottom bars (day 5 final approach) - bars grow downward
for i = 1:top_n_day5_app
    h = norm_day5_app_col3(i) * max_bar_h;
    rectangle(ax_day, 'Position', [i - bar_width/2, y_bot_base - h, bar_width, h], ...
        'FaceColor', colors_day5_app{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_day5_app(i) * scale_day5_app_col3;
    plot(ax_day, [i i], [y_bot_base - h - err_h, y_bot_base - h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_day5_app_per_animal(a, i) > 0
                y_pt = y_bot_base - prop_day5_app_per_animal(a, i) * scale_day5_app_col3;
                scatter(ax_day, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw connecting lines
for i = 1:top_n_all_days_all
    syl = top20_all_days_all(i);
    j = find(top20_day5_app == syl, 1);
    if ~isempty(j)
        if i == j
            col = [0.6 0.6 0.6];
            lw = 1;
        else
            col = colors_all_days_all{i};
            lw = 1.5;
        end
        plot(ax_day, [i, j], [y_top_base, y_bot_base], '-', 'Color', [col 0.7], 'LineWidth', lw);
    end
end

% labels above top bars (all days all times)
for i = 1:top_n_all_days_all
    h = norm_all_days_all(i) * max_bar_h;
    syl = top20_all_days_all(i);
    text(ax_day, i, y_top_base + h + 0.05, string(syl), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

% labels below bottom bars (day 5 final approach)
for i = 1:top_n_day5_app
    h = norm_day5_app_col3(i) * max_bar_h;
    syl = top20_day5_app(i);
    text(ax_day, i, y_bot_base - h - 0.05, string(syl), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8);
end

xlim(ax_day, [0 max(top_n_all_days_all, top_n_day5_app) + 1]);
ylim(ax_day, [y_bot_base - max_bar_h - 0.3, y_top_base + max_bar_h + 0.3]);
set(ax_day, 'YTick', [y_bot_base - max_bar_h/2, y_top_base + max_bar_h/2], ...
    'YTickLabel', {'Day 5 (approach)', 'All days (all)'});
set(ax_day, 'XTick', []);
title(ax_day, 'All days (all) vs Day 5 (final approach)');
hold(ax_day, 'off');

% day 5: within-trial vs final approach comparison (fourth column, spanning 2 rows)
ax_app = nexttile(tl1, 4, [2, 1]);
hold(ax_app, 'on');

% normalize counts for day5 comparison
norm_day5_trial = sorted_day5(1:top_n_day5) / max(sorted_day5(1:top_n_day5));
norm_day5_app = sorted_day5_app(1:top_n_day5_app) / max(sorted_day5_app(1:top_n_day5_app));

% scale factor for error bars
scale_day5_trial = max_bar_h / max(mean_day5_trial);
scale_day5_app = max_bar_h / max(mean_day5_app);

% draw top bars (day 5 within-trial) - bars grow upward
for i = 1:top_n_day5
    h = norm_day5_trial(i) * max_bar_h;
    rectangle(ax_app, 'Position', [i - bar_width/2, y_top_base, bar_width, h], ...
        'FaceColor', colors_day5{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_day5_trial(i) * scale_day5_trial;
    plot(ax_app, [i i], [y_top_base + h - err_h, y_top_base + h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_day5_trial_per_animal(a, i) > 0
                y_pt = y_top_base + prop_day5_trial_per_animal(a, i) * scale_day5_trial;
                scatter(ax_app, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw bottom bars (day 5 final approach) - bars grow downward
for i = 1:top_n_day5_app
    h = norm_day5_app(i) * max_bar_h;
    rectangle(ax_app, 'Position', [i - bar_width/2, y_bot_base - h, bar_width, h], ...
        'FaceColor', colors_day5_app{i}, 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    err_h = sem_day5_app(i) * scale_day5_app;
    plot(ax_app, [i i], [y_bot_base - h - err_h, y_bot_base - h + err_h], 'k-', 'LineWidth', 1);
    if show_animal_symbols
        % individual animal points
        for a = 1:n_animals
            if prop_day5_app_per_animal(a, i) > 0
                y_pt = y_bot_base - prop_day5_app_per_animal(a, i) * scale_day5_app;
                scatter(ax_app, i, y_pt, animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
            end
        end
    end
end

% draw connecting lines
for i = 1:top_n_day5
    syl = top20_day5(i);
    j = find(top20_day5_app == syl, 1);
    if ~isempty(j)
        if i == j
            col = [0.6 0.6 0.6];
            lw = 1;
        else
            col = colors_day5{i};
            lw = 1.5;
        end
        plot(ax_app, [i, j], [y_top_base, y_bot_base], '-', 'Color', [col 0.7], 'LineWidth', lw);
    end
end

% labels above top bars (day 5 within-trial)
for i = 1:top_n_day5
    h = norm_day5_trial(i) * max_bar_h;
    syl = top20_day5(i);
    marker = '';
    if ~ismember(syl, top20_day5_app)
        marker = ' v';
    end
    text(ax_app, i, y_top_base + h + 0.05, [string(syl) + marker], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

% labels below bottom bars (day 5 final approach)
for i = 1:top_n_day5_app
    h = norm_day5_app(i) * max_bar_h;
    syl = top20_day5_app(i);
    marker = '';
    if ~ismember(syl, top20_day5)
        marker = ' ^';
    end
    text(ax_app, i, y_bot_base - h - 0.05, [string(syl) + marker], ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8);
end

xlim(ax_app, [0 max(top_n_day5, top_n_day5_app) + 1]);
ylim(ax_app, [y_bot_base - max_bar_h - 0.3, y_top_base + max_bar_h + 0.3]);
set(ax_app, 'YTick', [y_bot_base - max_bar_h/2, y_top_base + max_bar_h/2], ...
    'YTickLabel', {'Final approach', 'Within-trial'});
set(ax_app, 'XTick', []);
title(ax_app, 'Day 5: Trial vs Final approach');
hold(ax_app, 'off');

%

%
% 2) per animal: day 1 (all) vs day 5 (final approach)
[fig2, tl2] = myFigure(n_animals, 2, 1500, 1200, true);
title(tl2, 'Per-animal syllable distributions: Day 1 (all) vs Day 5 (final approach)');

top_n_per_animal = 20;
counts_day1_all_panels = cell(n_animals, 1);
counts_day5_app_panels = cell(n_animals, 1);
order_day1_all_panels = cell(n_animals, 1);
order_day5_app_panels = cell(n_animals, 1);
max_day1_panel = 0;
max_day5_panel = 0;

for a = 1:n_animals
    syl_a_day1 = syl_day1_all_per_animal{a};
    syl_a_day5 = syl_day5_app_per_animal{a};

    if ~isempty(syl_a_day1)
        unique_day1_a = unique(syl_a_day1);
        counts_day1_a = histcounts(syl_a_day1, [unique_day1_a; max(unique_day1_a)+1])';
        [counts_day1_sorted, idx_day1_a] = sort(counts_day1_a, 'descend');
        syl_day1_sorted = unique_day1_a(idx_day1_a);
        keep_n_day1 = min(top_n_per_animal, numel(syl_day1_sorted));
        counts_day1_all_panels{a} = counts_day1_sorted(1:keep_n_day1);
        order_day1_all_panels{a} = syl_day1_sorted(1:keep_n_day1);
        max_day1_panel = max(max_day1_panel, max(counts_day1_all_panels{a}));
    else
        counts_day1_all_panels{a} = [];
        order_day1_all_panels{a} = [];
    end

    if ~isempty(syl_a_day5)
        unique_day5_a = unique(syl_a_day5);
        counts_day5_a = histcounts(syl_a_day5, [unique_day5_a; max(unique_day5_a)+1])';
        [counts_day5_sorted, idx_day5_a] = sort(counts_day5_a, 'descend');
        syl_day5_sorted = unique_day5_a(idx_day5_a);
        keep_n_day5 = min(top_n_per_animal, numel(syl_day5_sorted));
        counts_day5_app_panels{a} = counts_day5_sorted(1:keep_n_day5);
        order_day5_app_panels{a} = syl_day5_sorted(1:keep_n_day5);
        max_day5_panel = max(max_day5_panel, max(counts_day5_app_panels{a}));
    else
        counts_day5_app_panels{a} = [];
        order_day5_app_panels{a} = [];
    end
end

if max_day1_panel == 0
    max_day1_panel = 1;
end
if max_day5_panel == 0
    max_day5_panel = 1;
end

for a = 1:n_animals
    ax_left = nexttile(tl2);
    counts_day1_a = counts_day1_all_panels{a};
    syl_day1_a = order_day1_all_panels{a};
    if isempty(counts_day1_a)
        text(ax_left, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        xlim(ax_left, [0 1]);
        ylim(ax_left, [0 max_day1_panel * 1.1]);
        set(ax_left, 'XTick', []);
    else
        cols_day1_a = get_bar_colors(syl_day1_a);
        b = bar(ax_left, 1:numel(counts_day1_a), counts_day1_a, 'FaceColor', 'flat');
        b.CData = vertcat(cols_day1_a{:});
        xticks(ax_left, 1:numel(counts_day1_a));
        xticklabels(ax_left, string(syl_day1_a));
        xlim(ax_left, [0.25 numel(counts_day1_a) + 0.75]);
    end
    ylim(ax_left, [0 max_day1_panel * 1.1]);
    ylabel(ax_left, 'Timepoints');
    title(ax_left, sprintf('%s (%s) | Day 1 all', all_data(a).name, all_data(a).region), 'Interpreter', 'none');

    ax_right = nexttile(tl2);
    counts_day5_a = counts_day5_app_panels{a};
    syl_day5_a = order_day5_app_panels{a};
    if isempty(counts_day5_a)
        text(ax_right, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        xlim(ax_right, [0 1]);
        ylim(ax_right, [0 max_day5_panel * 1.1]);
        set(ax_right, 'XTick', []);
    else
        cols_day5_a = get_bar_colors(syl_day5_a);
        b = bar(ax_right, 1:numel(counts_day5_a), counts_day5_a, 'FaceColor', 'flat');
        b.CData = vertcat(cols_day5_a{:});
        xticks(ax_right, 1:numel(counts_day5_a));
        xticklabels(ax_right, string(syl_day5_a));
        xlim(ax_right, [0.25 numel(counts_day5_a) + 0.75]);
    end
    ylim(ax_right, [0 max_day5_panel * 1.1]);
    ylabel(ax_right, 'Timepoints');
    title(ax_right, sprintf('%s (%s) | Day 5 final approach', all_data(a).name, all_data(a).region), 'Interpreter', 'none');
end

xlabel(ax_left, 'Syllable');
xlabel(ax_right, 'Syllable');

% print comparison
fprintf('\n--- Top 20 syllables (%s) ---\n', ref_label);
fprintf('%s\n', mat2str(syl_order(1:top_n)'));
fprintf('\n--- Top 20 syllables (within-trial) ---\n');
fprintf('%s\n', mat2str(syl_order_trial(1:top_n_trial)'));

% syllables in top20 trial but not in top20 reference
trial_only = setdiff(top20_trial, top20_all);
fprintf('\n--- Trial-only top 20 (not in %s top 20) ---\n', ref_label);
fprintf('%s\n', mat2str(trial_only'));
