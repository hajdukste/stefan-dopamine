function [fig, out] = f01_plot_syllable_psth_split_summary(all_data, varargin)
% F01_PLOT_SYLLABLE_PSTH_SPLIT_SUMMARY Compare one or more syllables across two split groups.
%
% Supported split modes:
%   'active_nonactive_valve': bout start time is near end_of_trial vs not
%   'active_nonactive_valve_within_roi': same split, but only for ROI bouts
%   'region1': bout start row or end row is inside a fixed ROI vs not
%   'trial_outside_trial': bout starts and ends inside a trial vs outside;
%       boundary-crossing bouts are excluded

    p = inputParser;
    addParameter(p, 'syllables', []);
    addParameter(p, 'panels', {'fip_psth', 'fip_psth_days', 'speed_psth', ...
        'speed_psth_days', 'daily_counts', 'fa_counts', 'bout_hist'});
    addParameter(p, 'signal_layout', 'tiles');
    addParameter(p, 'show_individual', 'none');
    addParameter(p, 'psth_aggregate', 'animal');
    addParameter(p, 'suptitle', '');
    addParameter(p, 't_before', 120);
    addParameter(p, 't_after', 120);
    addParameter(p, 'fs', 60);
    addParameter(p, 'skip_animals_days', [0 0]);
    addParameter(p, 'split', 'active_nonactive_valve');
    addParameter(p, 'end_window', [-0.5 2]);
    addParameter(p, 'trajectory_png_path', '/Users/stefan/Downloads/berkeley_collab/kpms/trajectory_plots/pngs_cropped');
    parse(p, varargin{:});
    opts = p.Results;

    if isempty(opts.syllables)
        opts.syllables = evalin('base', 'sorted_syllables(1)');
    end
    if ischar(opts.panels) || isstring(opts.panels)
        opts.panels = cellstr(opts.panels);
    elseif iscell(opts.panels)
        opts.panels = cellfun(@char, opts.panels, 'UniformOutput', false);
    end
    opts.split = char(string(opts.split));
    opts.syllables = opts.syllables(:)';

    n_days = 5;
    n_animals = length(all_data);
    n_rows = numel(opts.syllables);
    split_info = get_split_info(opts.split);

    cmap25 = evalin('base', 'cmap25');
    sorted_syllables = evalin('base', 'sorted_syllables');

    colors = struct();
    colors.groups = split_info.group_colors;
    colors.animal = [
        0.18 0.18 0.18;
        0.34 0.34 0.34;
        0.50 0.50 0.50;
        0.66 0.66 0.66;
        0.82 0.82 0.82;
        0.20 0.48 0.52;
    ];
    colors.day = cool(n_days);
    colors.day = 0.65 * colors.day + 0.35 * repmat([0.45 0.45 0.45], n_days, 1);

    panel_cols = expand_panel_columns(opts.panels, split_info);
    panel_labels = get_panel_labels(split_info);
    n_cols = length(panel_cols);
    n_groups = length(split_info.ids);

    n_samples = opts.t_before + opts.t_after + 1;
    time_axis = linspace(-opts.t_before / opts.fs, opts.t_after / opts.fs, n_samples);

    [fig, tl] = myFigure(n_rows, n_cols, 300, 250, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    all_events_table = table();
    events_table_by_syllable = cell(1, n_rows);
    bout_info_by_syllable = cell(1, n_rows);

    for i_row = 1:n_rows
        syl = opts.syllables(i_row);
        syl_color = get_syllable_color(syl, sorted_syllables, cmap25);
        fprintf('Extracting %s syllable events for syllable %d...\n', opts.split, syl);
        [events_table, bout_info] = get_split_events(all_data, opts, syl, n_animals, n_days, split_info);
        events_table_by_syllable{i_row} = events_table;
        bout_info_by_syllable{i_row} = bout_info;
        all_events_table = [all_events_table; events_table]; %#ok<AGROW>

        shared_axes = struct( ...
            'fip', gobjects(1, 2), ...
            'speed_days', gobjects(1, n_groups), ...
            'fip_days', gobjects(n_groups, 2));
        shared_has_data = struct( ...
            'fip', false(1, 2), ...
            'speed_days', false(1, n_groups), ...
            'fip_days', false(n_groups, 2));

        for i_col = 1:n_cols
            panel_type = panel_cols{i_col};
            ax = nexttile(tl);
            hold(ax, 'on');

            tile_title = sprintf('Syl %d - %s', syl, panel_labels.(panel_type));
            if strcmp(panel_type, 'trajectory')
                plot_trajectory_panel(ax, opts, syl, syl_color);

            elseif strcmp(panel_type, 'fip_psth_NAcMed') || strcmp(panel_type, 'fip_psth_NAcLat')
                region_name = strrep(panel_type, 'fip_psth_', '');
                if height(events_table) == 0 || ~ismember('region', events_table.Properties.VariableNames)
                    region_events = events_table;
                else
                    region_events = events_table(strcmp(events_table.region, region_name), :);
                end
                has_data = plot_split_group_psth(ax, region_events, 'zsc_exp', time_axis, ...
                    split_info, colors, opts.show_individual, opts.psth_aggregate, true);
                xline(ax, 0, 'k:', 'LineWidth', 0.5);
                ylabel(ax, 'zsc\_exp');
                xlabel(ax, 'Time (s)');
                region_idx = 1 + strcmp(region_name, 'NAcLat');
                shared_axes.fip(region_idx) = ax;
                shared_has_data.fip(region_idx) = has_data;

            elseif strcmp(panel_type, 'speed_psth')
                plot_split_group_psth(ax, events_table, 'speed', time_axis, ...
                    split_info, colors, opts.show_individual, opts.psth_aggregate, true);
                xline(ax, 0, 'k:', 'LineWidth', 0.5);
                ylabel(ax, 'Speed');
                xlabel(ax, 'Time (s)');

            elseif startsWith(panel_type, 'fip_psth_days_')
                if endsWith(panel_type, '_NAcMed')
                    region_name = 'NAcMed';
                    split_group = erase(panel_type, 'fip_psth_days_');
                    split_group = erase(split_group, '_NAcMed');
                else
                    region_name = 'NAcLat';
                    split_group = erase(panel_type, 'fip_psth_days_');
                    split_group = erase(split_group, '_NAcLat');
                end
                has_data = plot_split_group_day_psth(ax, events_table, 'zsc_exp', split_group, ...
                    region_name, time_axis, colors.day, true);
                xline(ax, 0, 'k:', 'LineWidth', 0.5);
                ylabel(ax, 'zsc\_exp');
                xlabel(ax, 'Time (s)');
                group_idx = get_split_group_index(split_info, split_group);
                region_idx = 1 + strcmp(region_name, 'NAcLat');
                shared_axes.fip_days(group_idx, region_idx) = ax;
                shared_has_data.fip_days(group_idx, region_idx) = has_data;

            elseif startsWith(panel_type, 'speed_psth_days_')
                split_group = erase(panel_type, 'speed_psth_days_');
                has_data = plot_split_group_day_psth(ax, events_table, 'speed', split_group, ...
                    '', time_axis, colors.day, true);
                xline(ax, 0, 'k:', 'LineWidth', 0.5);
                ylabel(ax, 'Speed');
                xlabel(ax, 'Time (s)');
                group_idx = get_split_group_index(split_info, split_group);
                shared_axes.speed_days(group_idx) = ax;
                shared_has_data.speed_days(group_idx) = has_data;

            elseif strcmp(panel_type, 'bout_hist')
                plot_bout_density_by_split_group(ax, bout_info.lengths, split_info, colors);
                xlabel(ax, 'Duration (s)');
                ylabel(ax, 'Density');

            elseif strcmp(panel_type, 'daily_counts')
                plot_split_stacked_counts(ax, bout_info.counts, colors.animal, n_days);
                ylabel(ax, 'Count');
                xlabel(ax, split_info.count_xlabel);

            elseif startsWith(panel_type, 'daily_counts_')
                split_group = erase(panel_type, 'daily_counts_');
                plot_single_split_stacked_counts(ax, bout_info.counts, split_info, split_group, colors.animal, n_days);
                ylabel(ax, 'Count');
                xlabel(ax, 'Day');

            elseif strcmp(panel_type, 'fa_counts')
                plot_split_stacked_counts(ax, bout_info.fa_counts, colors.animal, n_days);
                ylabel(ax, 'Count');
                xlabel(ax, split_info.count_xlabel);
            end

            title(ax, tile_title, 'FontSize', 9, 'Interpreter', 'none');
            hold(ax, 'off');
        end

        sync_shared_ylim(shared_axes.fip, shared_has_data.fip);
        for i_group = 1:n_groups
            sync_shared_ylim(shared_axes.fip_days(i_group, :), shared_has_data.fip_days(i_group, :));
        end
        sync_shared_ylim(shared_axes.speed_days, shared_has_data.speed_days);
    end

    out = struct();
    out.events_table = all_events_table;
    out.events_table_by_syllable = events_table_by_syllable;
    if n_rows == 1
        out.bout_info = bout_info_by_syllable{1};
    else
        out.bout_info = bout_info_by_syllable;
    end
    out.bout_info_by_syllable = bout_info_by_syllable;
    out.time_axis = time_axis;
    out.panel_cols = panel_cols;
    out.split = opts.split;
    out.group_labels = split_info.labels;
    out.syllables = opts.syllables;

    fprintf('Plot 4a complete: %d syllables, %d total events, %d panels per row\n', ...
        n_rows, height(all_events_table), n_cols);
end

%--------------------------------------------------------------------------
% Event extraction and bout summaries
%--------------------------------------------------------------------------
function [events_table, bout_info] = get_split_events(all_data, opts, syl, n_animals, n_days, split_info)
    events_table = table();
    n_groups = length(split_info.ids);
    bout_info.lengths = cell(n_groups, n_animals);
    bout_info.counts = zeros(n_groups, n_days, n_animals);
    bout_info.fa_counts = zeros(n_groups, n_days, n_animals);

    config_syl = struct();
    config_syl.t_before = opts.t_before;
    config_syl.t_after = opts.t_after;
    config_syl.trace_types = {'zsc_exp', 'speed'};

    for animal = 1:n_animals
        for day = 1:min(n_days, length(all_data(animal).data))
            if ismember([animal, day], opts.skip_animals_days, 'rows')
                continue;
            end

            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames)
                continue;
            end

            d_old = [];
            if isfield(all_data(animal).data(day), 'd_old')
                d_old = all_data(animal).data(day).d_old;
            end
            end_times = get_end_times(d_old);

            syl_data = d.syllable;
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; height(d)];
            run_syllables = syl_data(run_starts);
            syl_run_mask = run_syllables == syl;
            if ~any(syl_run_mask)
                continue;
            end

            onset_idx_all = run_starts(syl_run_mask);
            end_idx_all = run_ends(syl_run_mask);
            onset_time_all = d.time(onset_idx_all);
            [split_group_all, include_mask] = assign_split_groups(d, d_old, onset_idx_all, end_idx_all, ...
                onset_time_all, end_times, opts, split_info);
            onset_idx_all = onset_idx_all(include_mask);
            end_idx_all = end_idx_all(include_mask);
            onset_time_all = onset_time_all(include_mask);
            split_group_all = split_group_all(include_mask);

            if isempty(onset_idx_all)
                continue;
            end

            run_lengths_sec = (run_ends(syl_run_mask) - run_starts(syl_run_mask) + 1) / opts.fs;
            run_lengths_sec = run_lengths_sec(include_mask);
            has_fa = ismember('final_approach', d.Properties.VariableNames);
            for i_group = 1:n_groups
                group_mask = strcmp(split_group_all, split_info.ids{i_group});
                bout_info.lengths{i_group, animal} = [bout_info.lengths{i_group, animal}; run_lengths_sec(group_mask)];
                bout_info.counts(i_group, day, animal) = sum(group_mask);
                if has_fa
                    bout_info.fa_counts(i_group, day, animal) = sum(d.final_approach(onset_idx_all(group_mask)));
                end
            end

            events = struct();
            events.time_idx = onset_idx_all;
            events.syllable = repmat(syl, length(onset_idx_all), 1);
            events.onset_time = onset_time_all;
            events.split_group = split_group_all;
            events_aligned = f01_helper_align_signals(d, events, config_syl);
            events_aligned = myStruct2Mat(events_aligned);

            n = height(events_aligned);
            if n == 0
                continue;
            end

            events_aligned.animal = repmat(animal, n, 1);
            events_aligned.day = repmat(day, n, 1);
            events_aligned.region = repmat({all_data(animal).region}, n, 1);
            events_table = [events_table; events_aligned];
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region', 'syllable', 'split_group'}, 'Before', 1);
    end
end

function [split_group_all, include_mask] = assign_split_groups(d, d_old, onset_idx_all, end_idx_all, onset_time_all, end_times, opts, split_info)
    split_group_all = repmat(split_info.ids(2), length(onset_idx_all), 1);
    include_mask = true(size(onset_idx_all));
    roi_mask = classify_region1_bouts(d, onset_idx_all, end_idx_all);

    switch split_info.classification_mode
        case 'active_nonactive_valve'
            in_group1 = classify_near_end(onset_time_all, end_times, opts.end_window);
        case 'region1'
            in_group1 = roi_mask;
        case 'trial_membership'
            in_trial = get_trial_membership_mask(d, d_old);
            start_in_trial = in_trial(onset_idx_all);
            end_in_trial = in_trial(end_idx_all);
            in_group1 = start_in_trial & end_in_trial;
            include_mask = start_in_trial == end_in_trial;
        otherwise
            error('Unknown split classification mode: %s', split_info.classification_mode);
    end

    if split_info.restrict_to_roi
        include_mask = roi_mask;
    end

    split_group_all(in_group1) = split_info.ids(1);
end

function end_times = get_end_times(d_old)
    end_times = [];
    if isempty(d_old) || ~ismember('type', d_old.Properties.VariableNames) || ...
            ~ismember('time', d_old.Properties.VariableNames)
        return;
    end

    end_mask = strcmp(d_old.type, 'end_of_trial');
    end_times = d_old.time(end_mask);
end

function is_near_end = classify_near_end(onset_times, end_times, end_window)
    is_near_end = false(size(onset_times));
    if isempty(end_times)
        return;
    end

    for i_onset = 1:length(onset_times)
        is_near_end(i_onset) = any(onset_times(i_onset) >= end_times + end_window(1) & ...
            onset_times(i_onset) <= end_times + end_window(2));
    end
end

function in_trial = get_trial_membership_mask(d, d_old)
    in_trial = false(height(d), 1);

    if ismember('trial_number', d.Properties.VariableNames)
        trial_number = d.trial_number;
        if isnumeric(trial_number) || islogical(trial_number)
            in_trial = isfinite(double(trial_number));
            return;
        end
    end

    if isempty(d_old) || ~all(ismember({'type', 'time'}, d_old.Properties.VariableNames))
        return;
    end

    start_times = d_old.time(strcmp(d_old.type, 'start_of_trial'));
    end_times = d_old.time(strcmp(d_old.type, 'end_of_trial'));
    next_end_idx = 1;

    for i_start = 1:numel(start_times)
        while next_end_idx <= numel(end_times) && end_times(next_end_idx) <= start_times(i_start)
            next_end_idx = next_end_idx + 1;
        end

        if next_end_idx > numel(end_times)
            break;
        end

        in_trial = in_trial | (d.time >= start_times(i_start) & d.time <= end_times(next_end_idx));
        next_end_idx = next_end_idx + 1;
    end
end

%--------------------------------------------------------------------------
% Panel plotting
%--------------------------------------------------------------------------
function panel_cols = expand_panel_columns(panels, split_info)
    panel_cols = {};
    for i_panel = 1:length(panels)
        switch panels{i_panel}
            case 'fip_psth'
                panel_cols{end+1} = 'fip_psth_NAcMed';
                panel_cols{end+1} = 'fip_psth_NAcLat';
            case 'fip_psth_days'
                for i_group = 1:length(split_info.ids)
                    panel_cols{end+1} = sprintf('fip_psth_days_%s_NAcMed', split_info.ids{i_group});
                    panel_cols{end+1} = sprintf('fip_psth_days_%s_NAcLat', split_info.ids{i_group});
                end
            case 'speed_psth_days'
                for i_group = 1:length(split_info.ids)
                    panel_cols{end+1} = sprintf('speed_psth_days_%s', split_info.ids{i_group});
                end
            case 'daily_counts'
                if strcmp(split_info.name, 'trial_outside_trial')
                    for i_group = 1:length(split_info.ids)
                        panel_cols{end+1} = sprintf('daily_counts_%s', split_info.ids{i_group});
                    end
                else
                    panel_cols{end+1} = panels{i_panel};
                end
            otherwise
                panel_cols{end+1} = panels{i_panel};
        end
    end
end

function labels = get_panel_labels(split_info)
    labels = struct( ...
        'trajectory', 'Traj', ...
        'fip_psth_NAcMed', 'FIP NAcMed', ...
        'fip_psth_NAcLat', 'FIP NAcLat', ...
        'speed_psth', 'Speed', ...
        'bout_hist', 'Bout Len', ...
        'daily_counts', 'Daily', ...
        'fa_counts', 'Final App');

    for i_group = 1:length(split_info.ids)
        group_id = split_info.ids{i_group};
        group_label = split_info.labels{i_group};
        labels.(sprintf('fip_psth_days_%s_NAcMed', group_id)) = sprintf('%s Med Days', group_label);
        labels.(sprintf('fip_psth_days_%s_NAcLat', group_id)) = sprintf('%s Lat Days', group_label);
        labels.(sprintf('speed_psth_days_%s', group_id)) = sprintf('%s Speed Days', group_label);
        labels.(sprintf('daily_counts_%s', group_id)) = group_label;
    end
end

function has_data = plot_split_group_psth(ax, events, signal_name, time_axis, split_info, colors, show_individual, aggregate_level, show_legend)
    legend_handles = gobjects(0);
    legend_labels = {};
    has_data = false;

    if height(events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    for i_group = 1:length(split_info.ids)
        group_id = split_info.ids{i_group};
        group_events = events(strcmp(events.split_group, group_id), :);
        if height(group_events) == 0
            continue;
        end

        traces = stack_traces(group_events.(signal_name));
        if isempty(traces)
            continue;
        end
        traces = interp_traces(traces, time_axis);
        [mean_trace, sem_trace, n_groups] = compute_psth_stats(group_events, traces, aggregate_level);

        col = colors.groups.(group_id);
        plot_individual_traces(ax, group_events, signal_name, time_axis, show_individual, col);
        h = plot_shaded(ax, time_axis, mean_trace, sem_trace, col, 0.12, 1.4);
        has_data = true;
        legend_handles(end+1) = h;
        legend_labels{end+1} = sprintf('%s (n=%d)', split_info.labels{i_group}, n_groups);
    end

    if ~has_data
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    yline(ax, 0, 'k:', 'LineWidth', 0.25);
    xlim(ax, [time_axis(1), time_axis(end)]);
    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end
end

function has_data = plot_split_group_day_psth(ax, events, signal_name, split_group, region_name, time_axis, day_colors, show_legend)
    has_data = false;
    if height(events) == 0 || ~ismember('split_group', events.Properties.VariableNames)
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end
    if ~isempty(region_name)
        if ~ismember('region', events.Properties.VariableNames)
            text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
            return;
        end
        events = events(strcmp(events.region, region_name), :);
    end
    events = events(strcmp(events.split_group, split_group), :);

    if height(events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    legend_handles = gobjects(0);
    legend_labels = {};
    for day = 1:5
        day_events = events(events.day == day, :);
        if height(day_events) == 0
            continue;
        end

        traces = stack_traces(day_events.(signal_name));
        if isempty(traces)
            continue;
        end
        traces = interp_traces(traces, time_axis);
        [mean_trace, sem_trace, n_animals] = compute_psth_stats(day_events, traces, 'animal');

        h = plot_shaded(ax, time_axis, mean_trace, sem_trace, day_colors(day, :), 0.10, 1.2);
        has_data = true;
        legend_handles(end+1) = h;
        legend_labels{end+1} = sprintf('D%d (n=%d)', day, n_animals);
    end

    if ~has_data
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    yline(ax, 0, 'k:', 'LineWidth', 0.25);
    xlim(ax, [time_axis(1), time_axis(end)]);
    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end
end

function plot_bout_density_by_split_group(ax, bout_lengths, split_info, colors)
    all_lengths = vertcat(bout_lengths{:});
    if isempty(all_lengths)
        text(ax, 0.5, 0.5, 'No bouts', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    max_len = prctile(all_lengths, 95);
    if max_len <= 0
        max_len = max(all_lengths);
    end
    if max_len <= 0
        max_len = 1;
    end

    x_grid = linspace(0, max_len, 120);
    legend_handles = gobjects(0);
    legend_labels = {};

    for i_group = 1:length(split_info.ids)
        animal_densities = nan(size(bout_lengths, 2), length(x_grid));
        for animal = 1:size(bout_lengths, 2)
            lengths = bout_lengths{i_group, animal};
            lengths = lengths(~isnan(lengths) & lengths >= 0 & lengths <= max_len);
            if isempty(lengths)
                continue;
            end
            animal_densities(animal, :) = compute_length_density(lengths, x_grid, max_len);
        end

        valid_animals = any(~isnan(animal_densities), 2);
        animal_densities = animal_densities(valid_animals, :);
        n_animals = size(animal_densities, 1);
        if n_animals == 0
            continue;
        end

        mean_density = mean(animal_densities, 1, 'omitnan');
        if n_animals > 1
            sem_density = std(animal_densities, 0, 1, 'omitnan') / sqrt(n_animals);
        else
            sem_density = zeros(size(mean_density));
        end

        h = plot_shaded(ax, x_grid, mean_density, sem_density, ...
            colors.groups.(split_info.ids{i_group}), 0.10, 1.4);
        legend_handles(end+1) = h;
        legend_labels{end+1} = sprintf('%s (n=%d)', split_info.labels{i_group}, n_animals);
    end

    xlim(ax, [0 max_len]);
    if ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end
end

function split_info = get_split_info(split_name)
    split_info = struct();
    split_info.name = split_name;
    switch split_name
        case 'active_nonactive_valve'
            split_info.ids = {'near_end', 'other'};
            split_info.labels = {'Active V', 'Nonactive V'};
            split_info.group_colors = struct( ...
                'near_end', [0.68 0.20 0.18], ...
                'other', [0.22 0.22 0.22]);
            split_info.classification_mode = 'active_nonactive_valve';
            split_info.restrict_to_roi = false;
        case 'active_nonactive_valve_within_roi'
            split_info.ids = {'near_end', 'other'};
            split_info.labels = {'Active V', 'Nonactive V'};
            split_info.group_colors = struct( ...
                'near_end', [0.68 0.20 0.18], ...
                'other', [0.22 0.22 0.22]);
            split_info.classification_mode = 'active_nonactive_valve';
            split_info.restrict_to_roi = true;
        case 'region1'
            split_info.ids = {'roi', 'nonroi'};
            split_info.labels = {'ROI', 'Non-ROI'};
            split_info.group_colors = struct( ...
                'roi', [0.16 0.53 0.33], ...
                'nonroi', [0.22 0.22 0.22]);
            split_info.classification_mode = 'region1';
            split_info.restrict_to_roi = false;
        case 'trial_outside_trial'
            split_info.ids = {'inside_trial', 'outside_trial'};
            split_info.labels = {'Inside Trial', 'Outside Trial'};
            split_info.group_colors = struct( ...
                'inside_trial', [0.15 0.45 0.72], ...
                'outside_trial', [0.22 0.22 0.22]);
            split_info.classification_mode = 'trial_membership';
            split_info.restrict_to_roi = false;
        otherwise
            error('Unknown split mode: %s', split_name);
    end
    split_info.count_xlabel = sprintf('%s / %s', split_info.labels{1}, split_info.labels{2});
end

function group_idx = get_split_group_index(split_info, group_id)
    group_idx = find(strcmp(split_info.ids, group_id), 1);
    if isempty(group_idx)
        error('Unknown split group: %s', group_id);
    end
end

function in_group1 = classify_region1_bouts(d, start_idx, end_idx)
    if ~ismember('centroidX', d.Properties.VariableNames) || ~ismember('centroidY', d.Properties.VariableNames)
        in_group1 = false(size(start_idx));
        return;
    end

    start_in_roi = is_region1_point_in_roi(d.centroidX(start_idx), d.centroidY(start_idx));
    end_in_roi = is_region1_point_in_roi(d.centroidX(end_idx), d.centroidY(end_idx));
    in_group1 = start_in_roi | end_in_roi;
end

function in_roi = is_region1_point_in_roi(x, y)
    in_roi = isfinite(x) & isfinite(y) & ( ...
        ((x >= 500) & (x <= 700) & (y >= 0) & (y <= 250)) | ...
        ((x >= 500) & (x <= 700) & (y >= 950) & (y <= 1200)) | ...
        ((x >= 0) & (x <= 250) & (y >= 500) & (y <= 700)) | ...
        ((x >= 950) & (x <= 1200) & (y >= 500) & (y <= 700)));
end

function sync_shared_ylim(ax_pair, has_data)
    valid_axes = ax_pair(isgraphics(ax_pair, 'axes') & has_data);
    if isempty(valid_axes)
        return;
    end

    y_limits = nan(numel(valid_axes), 2);
    for i_ax = 1:numel(valid_axes)
        y_limits(i_ax, :) = ylim(valid_axes(i_ax));
    end

    shared_ylim = [min(y_limits(:, 1)), max(y_limits(:, 2))];
    if ~all(isfinite(shared_ylim))
        return;
    end

    if shared_ylim(1) == shared_ylim(2)
        pad = max(abs(shared_ylim(1)) * 0.05, 1e-3);
        shared_ylim = shared_ylim + [-pad, pad];
    end

    set(valid_axes, 'YLim', shared_ylim);
    if numel(valid_axes) > 1
        linkaxes(valid_axes, 'y');
    end
end

function plot_split_stacked_counts(ax, counts, animal_colors, n_days)
    if isempty(counts)
        text(ax, 0.5, 0.5, 'No counts', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    x = [1:n_days; (1:n_days) + 0.35]';
    for i_type = 1:2
        counts_matrix = squeeze(counts(i_type, :, :));
        if size(counts_matrix, 1) ~= n_days
            counts_matrix = counts_matrix';
        end
        if any(counts_matrix(:) > 0)
            b = bar(ax, x(:, i_type), counts_matrix, 0.32, 'stacked', ...
                'EdgeColor', 'k', 'LineWidth', 0.4);
            for ia = 1:length(b)
                b(ia).FaceColor = animal_colors(min(ia, size(animal_colors, 1)), :);
            end
        end
    end

    xlim(ax, [0.6 n_days + 0.75]);
    set(ax, 'XTick', (1:n_days) + 0.175, 'XTickLabel', {'D1','D2','D3','D4','D5'});
end

function plot_single_split_stacked_counts(ax, counts, split_info, split_group, animal_colors, n_days)
    if isempty(counts)
        text(ax, 0.5, 0.5, 'No counts', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    group_idx = get_split_group_index(split_info, split_group);
    counts_matrix = squeeze(counts(group_idx, :, :));
    if isempty(counts_matrix)
        text(ax, 0.5, 0.5, 'No counts', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end
    if size(counts_matrix, 1) ~= n_days
        counts_matrix = counts_matrix';
    end

    if any(counts_matrix(:) > 0)
        b = bar(ax, 1:n_days, counts_matrix, 0.65, 'stacked', ...
            'EdgeColor', 'k', 'LineWidth', 0.4);
        for ia = 1:length(b)
            b(ia).FaceColor = animal_colors(min(ia, size(animal_colors, 1)), :);
        end
    else
        text(ax, 0.5, 0.5, 'No counts', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    xlim(ax, [0.4 n_days + 0.6]);
    set(ax, 'XTick', 1:n_days, 'XTickLabel', {'D1','D2','D3','D4','D5'});
end

function plot_trajectory_panel(ax, opts, syl, syl_color)
    png_file = fullfile(opts.trajectory_png_path, sprintf('Syllable%d.png', syl));
    if isfile(png_file)
        img = imread(png_file);
        imshow(img, 'Parent', ax);
        xl = xlim(ax);
        yl = ylim(ax);
    else
        text(ax, 0.5, 0.5, 'No PNG', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        xl = [0 1];
        yl = [0 1];
        xlim(ax, xl);
        ylim(ax, yl);
    end
    strip_height = diff(yl) * 0.06;
    rectangle(ax, 'Position', [xl(1), min(yl), diff(xl), strip_height], ...
        'FaceColor', syl_color, 'EdgeColor', 'none');
    axis(ax, 'off');
end

%--------------------------------------------------------------------------
% Shared numeric helpers
%--------------------------------------------------------------------------
function [mean_trace, sem_trace, n_groups] = compute_psth_stats(events, traces, aggregate_level)
    switch aggregate_level
        case 'event'
            aggregate_traces = traces;
        case 'animal'
            animals = unique(events.animal);
            aggregate_traces = nan(length(animals), size(traces, 2));
            for i_animal = 1:length(animals)
                mask = events.animal == animals(i_animal);
                aggregate_traces(i_animal, :) = nanmean(traces(mask, :), 1);
            end
        case 'session'
            sessions = unique([events.animal, events.day], 'rows');
            aggregate_traces = nan(size(sessions, 1), size(traces, 2));
            for i_session = 1:size(sessions, 1)
                mask = events.animal == sessions(i_session, 1) & events.day == sessions(i_session, 2);
                aggregate_traces(i_session, :) = nanmean(traces(mask, :), 1);
            end
        otherwise
            error('Unknown PSTH aggregation level: %s', aggregate_level);
    end

    valid_rows = any(~isnan(aggregate_traces), 2);
    aggregate_traces = aggregate_traces(valid_rows, :);
    n_groups = size(aggregate_traces, 1);
    if n_groups == 0
        mean_trace = [];
        sem_trace = [];
        return;
    end

    mean_trace = nanmean(aggregate_traces, 1);
    if n_groups > 1
        sem_trace = nanstd(aggregate_traces, 0, 1) / sqrt(n_groups);
    else
        sem_trace = zeros(1, size(aggregate_traces, 2));
    end
end

function plot_individual_traces(ax, events, signal_name, time_axis, mode, color)
    if strcmp(mode, 'none') || height(events) == 0
        return;
    end

    traces = stack_traces(events.(signal_name));
    if isempty(traces)
        return;
    end
    traces = interp_traces(traces, time_axis);

    switch mode
        case 'event'
            plot(ax, time_axis, traces', 'Color', [color 0.25], 'LineWidth', 0.5);
        case 'animal'
            animals = unique(events.animal);
            for i_animal = 1:length(animals)
                mask = events.animal == animals(i_animal);
                plot(ax, time_axis, nanmean(traces(mask, :), 1), ...
                    'Color', [color 0.25], 'LineWidth', 0.7);
            end
        case 'session'
            sessions = unique([events.animal, events.day], 'rows');
            for i_session = 1:size(sessions, 1)
                mask = events.animal == sessions(i_session, 1) & events.day == sessions(i_session, 2);
                plot(ax, time_axis, nanmean(traces(mask, :), 1), ...
                    'Color', [color 0.35], 'LineWidth', 0.7);
            end
    end
end

function traces = stack_traces(trace_cells)
    if isempty(trace_cells)
        traces = [];
        return;
    end

    lengths = cellfun(@numel, trace_cells);
    if isempty(lengths) || max(lengths) == 0
        traces = [];
        return;
    end

    traces = nan(length(trace_cells), max(lengths));
    for i_trace = 1:length(trace_cells)
        if isempty(trace_cells{i_trace})
            continue;
        end
        traces(i_trace, 1:lengths(i_trace)) = trace_cells{i_trace}(:)';
    end
end

function traces = interp_traces(traces, time_axis)
    n_t = length(time_axis);
    if size(traces, 2) == n_t
        return;
    end

    old_t = linspace(time_axis(1), time_axis(end), size(traces, 2));
    traces_interp = nan(size(traces, 1), n_t);
    for i_trace = 1:size(traces, 1)
        traces_interp(i_trace, :) = interp1(old_t, traces(i_trace, :), time_axis, 'linear', 'extrap');
    end
    traces = traces_interp;
end

function h = plot_shaded(ax, x, mean_y, sem_y, color, alpha, line_width)
    x = x(:)';
    mean_y = mean_y(:)';
    sem_y = sem_y(:)';
    valid = ~isnan(mean_y) & ~isnan(sem_y);
    x = x(valid);
    mean_y = mean_y(valid);
    sem_y = sem_y(valid);

    if isempty(x)
        h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', line_width);
        return;
    end

    fill(ax, [x fliplr(x)], [mean_y + sem_y fliplr(mean_y - sem_y)], ...
        color, 'FaceAlpha', alpha, 'EdgeColor', 'none');
    h = plot(ax, x, mean_y, 'Color', color, 'LineWidth', line_width);
end

function density = compute_length_density(lengths, x_grid, max_len)
    if exist('ksdensity', 'file') == 2 && numel(lengths) > 1
        density = ksdensity(lengths, x_grid, 'Support', 'positive');
    else
        edges = linspace(0, max_len, 25);
        density = histcounts(lengths, edges, 'Normalization', 'pdf');
        x_grid_local = edges(1:end-1) + diff(edges) / 2;
        density = interp1(x_grid_local, density, x_grid, 'linear', 0);
    end
end

function color = get_syllable_color(syl, sorted_syllables, cmap25)
    syl_idx = find(sorted_syllables == syl, 1);
    if ~isempty(syl_idx) && syl_idx <= size(cmap25, 1)
        color = cmap25(syl_idx, :);
    else
        color = [0.5 0.5 0.5];
    end
end
