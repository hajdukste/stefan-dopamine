skip_animals_days = [0 0];

valve_id = 0;
plot_mode = 'per_animal';  % 'per_animal' = 6 tiles for day 5, 'pooled' = all animals together
day_filter = 5;
iterate_over = 'animals';  % 'animals', 'valves', or 'days'
animals = 1;  % animal(s) to plot

% plot types: any combination of 'gray', 'phase', 'cluster', 'col_syl'
plot_types = {'col_syl'};  % which tiles to show per animal/valve
pooled_plot_type = 'gray';  % 'gray' or 'phase' for pooled mode

% clustering parameters
n_smp = 20;                % number of points to downsample trajectories to
cluster_cutoff = 1000;      % distance cutoff for hierarchical clustering (in pixels)
min_cluster_size = 3;      % minimum trajectories per cluster (smaller -> outlier)

% collect trajectories
trajectories = table();

for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ~strcmp(iterate_over, 'days') && ~isnan(day_filter) && day ~= day_filter; continue; end

        d_old = all_data(animal).data(day).d_old;
        d = all_data(animal).data(day).d;
        if isempty(d_old) || isempty(d); continue; end

        % find start and end of trial times
        start_mask = strcmp(d_old.type, 'start_of_trial');
        end_mask = strcmp(d_old.type, 'end_of_trial');
        final_approach_mask = strcmp(d_old.type, 'final_approach_start');
        start_times = d_old.time(start_mask);
        end_times = d_old.time(end_mask);
        final_approach_times = d_old.time(final_approach_mask);

        % get valve IDs for each start_of_trial
        start_valves = d_old.Valve_ID(start_mask);

        % pair each start with the next end
        for i_start = 1:length(start_times)
            t_start = start_times(i_start);
            % find first end_time after this start
            t_end_idx = find(end_times > t_start, 1);
            if isempty(t_end_idx); continue; end
            t_end = end_times(t_end_idx);

            % extract trajectory from d
            mask = d.time >= t_start & d.time <= t_end;
            if sum(mask) < 2; continue; end

            traj = table();
            traj.x = {d.centroidX(mask)};
            traj.y = {d.centroidY(mask)};
            if ismember('syllable', d.Properties.VariableNames)
                traj.syllable = {d.syllable(mask)};
            end
            traj.animal = animal;
            traj.day = day;
            traj.valve = start_valves(i_start);

            % find final_approach_start index within this trial trajectory
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

% filter trajectories based on mode
if strcmp(iterate_over, 'animals')
    trajectories = trajectories(trajectories.valve == valve_id, :);
    fprintf('%d trajectories after valve %d filter\n', height(trajectories), valve_id);
elseif strcmp(iterate_over, 'days')
    trajectories = trajectories(trajectories.valve == valve_id & trajectories.animal == animals(1), :);
    fprintf('%d trajectories after animal %d + valve %d filter\n', height(trajectories), animals(1), valve_id);
end

% cluster trajectories per animal
if ismember('cluster', plot_types)
    trajectories.cluster = zeros(height(trajectories), 1);
    animals_in_data = unique(trajectories.animal);
    for a = animals_in_data'
        a_idx = find(trajectories.animal == a);
        n_traj = length(a_idx);
        if n_traj < 3
            trajectories.cluster(a_idx) = -1;
            continue;
        end

        % downsample all trajectories to n_smp points
        traj_ds = zeros(n_traj, n_smp * 2);  % [x1..xn, y1..yn]
        for i = 1:n_traj
            x = trajectories.x{a_idx(i)};
            y = trajectories.y{a_idx(i)};
            t_orig = linspace(0, 1, length(x));
            t_new = linspace(0, 1, n_smp);
            x_ds = interp1(t_orig, x, t_new, 'linear');
            y_ds = interp1(t_orig, y, t_new, 'linear');
            traj_ds(i, :) = [x_ds, y_ds];
        end

        % compute pairwise Euclidean distances
        D = pdist(traj_ds, 'euclidean');

        % hierarchical clustering
        Z = linkage(D, 'average');
        clu_idx = cluster(Z, 'cutoff', cluster_cutoff, 'criterion', 'distance');

        % filter small clusters -> mark as -1 (outlier)
        for c = unique(clu_idx)'
            if sum(clu_idx == c) < min_cluster_size
                clu_idx(clu_idx == c) = -1;
            end
        end

        % renumber clusters 1, 2, 3, ... (keeping -1 for outliers)
        valid_clusters = unique(clu_idx(clu_idx > 0));
        for i_c = 1:length(valid_clusters)
            clu_idx(clu_idx == valid_clusters(i_c)) = i_c + 1000;
        end
        clu_idx(clu_idx > 1000) = clu_idx(clu_idx > 1000) - 1000;

        trajectories.cluster(a_idx) = clu_idx;
        fprintf('A%d: %d trajectories -> %d clusters\n', a, n_traj, length(valid_clusters));
    end
end

%
if strcmp(plot_mode, 'per_animal')
    if strcmp(iterate_over, 'animals')
        iter_vals = animals;
        iter_label = 'A';
        filter_field = 'animal';
        title_str = sprintf('Trial trajectories - Day %d - Valve %d', day_filter, valve_id);
    elseif strcmp(iterate_over, 'valves')
        iter_vals = 0:3;
        iter_label = 'V';
        filter_field = 'valve';
        trajectories = trajectories(trajectories.animal == animals(1), :);
        title_str = sprintf('Trial trajectories - Day %d - Animal %d', day_filter, animals(1));
    elseif strcmp(iterate_over, 'days')
        iter_vals = 1:5;
        iter_label = 'D';
        filter_field = 'day';
        title_str = sprintf('Trial trajectories - Animal %d - Valve %d', animals(1), valve_id);
    end

    n_iter = length(iter_vals);
    n_types = length(plot_types);
    [fig, tl] = myFigure(n_types, n_iter, 400, 400, true);
    title(tl, title_str);
    clear lines;
    colors = lines(10);  % colormap for clusters

    for i_iter = 1:n_iter
        v = iter_vals(i_iter);
        a_traj = trajectories(trajectories.(filter_field) == v, :);
        if strcmp(iterate_over, 'days')
            iter_title = sprintf('Day %d', v);
        elseif strcmp(iterate_over, 'animals')
            iter_title = sprintf('Animal %d', v);
        else
            iter_title = sprintf('%s%d', iter_label, v);
        end

        for i_type = 1:n_types
            ptype = plot_types{i_type};
            ax = nexttile(tl);
            hold(ax, 'on');

            if strcmp(ptype, 'gray')
                % plain gray trajectories
                for i_t = 1:height(a_traj)
                    x = a_traj.x{i_t};
                    y = a_traj.y{i_t};
                    plot(ax, x, y, 'Color', [0 0 0 0.3], 'LineWidth', 0.5);
                    plot(ax, x(1), y(1), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                    plot(ax, x(end), y(end), 'ro', 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                end
                title(ax, sprintf('%s (n=%d)', iter_title, height(a_traj)));

            elseif strcmp(ptype, 'phase')
                % trajectories colored by phase: green before final_approach, magenta after
                for i_t = 1:height(a_traj)
                    x = a_traj.x{i_t};
                    y = a_traj.y{i_t};
                    fa_idx = a_traj.fa_idx(i_t);
                    if ~isnan(fa_idx)
                        plot(ax, x(1:fa_idx), y(1:fa_idx), 'Color', [0 0.7 0 0.5], 'LineWidth', 0.8);
                        plot(ax, x(fa_idx:end), y(fa_idx:end), 'Color', [0.8 0 0.8 0.5], 'LineWidth', 0.8);
                    else
                        plot(ax, x, y, 'Color', [0 0 0 0.3], 'LineWidth', 0.5);
                    end
                    plot(ax, x(1), y(1), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                    plot(ax, x(end), y(end), 'ro', 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                end
                title(ax, sprintf('%s phase', iter_title));

            elseif strcmp(ptype, 'cluster')
                % color by cluster
                cluster_ids = unique(a_traj.cluster);
                legend_handles = [];
                legend_labels = {};
                for c = cluster_ids'
                    c_traj = a_traj(a_traj.cluster == c, :);
                    if c <= 0
                        col = [0.7 0.7 0.7];
                        alph = 0.2;
                        lbl = 'outlier';
                    else
                        col = colors(mod(c-1, size(colors,1)) + 1, :);
                        alph = 0.6;
                        lbl = sprintf('C%d (n=%d)', c, height(c_traj));
                    end
                    for i_t = 1:height(c_traj)
                        x = c_traj.x{i_t};
                        y = c_traj.y{i_t};
                        h = plot(ax, x, y, 'Color', col, 'LineWidth', 1);
                        h.Color(4) = alph;
                        plot(ax, x(1), y(1), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                        plot(ax, x(end), y(end), 'ro', 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                        fa_idx = c_traj.fa_idx(i_t);
                        if ~isnan(fa_idx)
                            plot(ax, x(fa_idx), y(fa_idx), 'mo', 'MarkerSize', 4, 'MarkerFaceColor', 'm');
                        end
                    end
                    hleg = plot(ax, NaN, NaN, 'Color', col, 'LineWidth', 2);
                    legend_handles = [legend_handles, hleg];
                    legend_labels{end+1} = lbl;
                end
                n_clusters = length(unique(a_traj.cluster(a_traj.cluster > 0)));
                title(ax, sprintf('%s cluster (%d)', iter_title, n_clusters));
                legend(ax, legend_handles, legend_labels, 'Location', 'best', 'FontSize', 7);

            elseif strcmp(ptype, 'col_syl') && ismember('syllable', a_traj.Properties.VariableNames)
                % color by syllable
                for i_t = 1:height(a_traj)
                    x = a_traj.x{i_t};
                    y = a_traj.y{i_t};
                    syl = a_traj.syllable{i_t};
                    for i_p = 1:length(x)-1
                        s = syl(i_p);
                        if isnan(s) || s < 0
                            col = [0.9 0.9 0.9];
                        elseif syl_to_idx.isKey(s)
                            col = cmap20(syl_to_idx(s), :);
                        else
                            col = other_color;
                        end
                        plot(ax, x(i_p:i_p+1), y(i_p:i_p+1), 'Color', col, 'LineWidth', 1);
                    end
                    plot(ax, x(1), y(1), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                    plot(ax, x(end), y(end), 'ro', 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                    fa_idx = a_traj.fa_idx(i_t);
                    if ~isnan(fa_idx)
                        plot(ax, x(fa_idx), y(fa_idx), 'mo', 'MarkerSize', 4, 'MarkerFaceColor', 'm');
                    end
                end
                title(ax, sprintf('%s syllables', iter_title));
            end

            xlim(ax, [0 1200]); ylim(ax, [0 1200]);
            axis(ax, 'square');
        end
    end

elseif strcmp(plot_mode, 'pooled')
    [fig, tl] = myFigure(1, 1, 600, 600, true);
    title(tl, sprintf('All animals - Valve %d', valve_id));
    ax = nexttile(tl);
    hold(ax, 'on');
    for i_t = 1:height(trajectories)
        x = trajectories.x{i_t};
        y = trajectories.y{i_t};
        fa_idx = trajectories.fa_idx(i_t);
        if strcmp(pooled_plot_type, 'phase') && ~isnan(fa_idx)
            plot(ax, x(1:fa_idx), y(1:fa_idx), 'Color', [0 0.7 0 0.3], 'LineWidth', 0.5);
            plot(ax, x(fa_idx:end), y(fa_idx:end), 'Color', [0.8 0 0.8 0.3], 'LineWidth', 0.5);
            plot(ax, x(fa_idx), y(fa_idx), 'mo', 'MarkerSize', 3, 'MarkerFaceColor', 'm');
        else
            plot(ax, x, y, 'Color', [0 0 0 0.15], 'LineWidth', 0.5);
        end
        plot(ax, x(1), y(1), 'go', 'MarkerSize', 3, 'MarkerFaceColor', 'g');
        plot(ax, x(end), y(end), 'ro', 'MarkerSize', 3, 'MarkerFaceColor', 'r');
    end
    xlim(ax, [0 1200]); ylim(ax, [0 1200]);
    axis(ax, 'square');
    title(ax, sprintf('n=%d trials', height(trajectories)));
end
