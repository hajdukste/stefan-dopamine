function [fig, out] = f01_plot_syllable_onset_heatmap_summary(all_data, varargin)
% F01_PLOT_SYLLABLE_ONSET_HEATMAP_SUMMARY Plot multi-syllable heatmap summaries.
%
% Supported panels in v1:
%   Unsplit mode:
%     'fip_psth'    -> expands to NAcMed and NAcLat heatmaps
%     'speed_psth'  -> single speed heatmap
%     'daily_counts'
%     'fa_counts'
%     'bout_hist'
%
%   Split mode ('split' ~= ''):
%     'fip_psth'    -> one heatmap per split group x region
%     'speed_psth'  -> one heatmap per split group
%     'daily_counts'/'fa_counts'/'bout_hist' -> one heatmap per split group
%
%   Special layout:
%     'split', 'trial_outside_trial' keeps the usual panel columns but
%     plots one subplot row per split group (inside vs outside trial)
%     and automatically adds a "time to end_of_trial" density heatmap panel
%
% Supported split modes:
%   'active_nonactive_valve': bout start time is near end_of_trial vs not
%   'active_nonactive_valve_within_roi': same split, but only for ROI bouts
%   'region1': bout start row or end row is inside a fixed ROI vs not
%   'trial_outside_trial': bout starts and ends inside a trial vs outside;
%       boundary-crossing bouts are excluded
%
% Unsupported panels are skipped with a warning:
%   'trajectory', 'fip_psth_days', 'speed_psth_days'
%
% Color limit options:
%   'fip_clim' applies only to FIP heatmaps
%   'clim' can still be a struct with fields such as .fip, .speed, .counts
%
% Time window options:
%   't_before'/'t_after' are sample counts
%   't_before_after' overrides them using seconds as [t_min t_max]
%   Example: [-1.5 1.5] or [-2 2]

    p = inputParser;
    addParameter(p, 'syllables', []);
    addParameter(p, 'signal', 'zsc_exp');
    addParameter(p, 'panels', {'fip_psth', 'speed_psth'});
    addParameter(p, 'aggregate', 'animal');
    addParameter(p, 't_before', 120);
    addParameter(p, 't_after', 120);
    addParameter(p, 't_before_after', []);
    addParameter(p, 'fs', 60);
    addParameter(p, 'skip_animals_days', [0 0]);
    addParameter(p, 'days', []);
    addParameter(p, 'speed_window', [0 0.5]);
    addParameter(p, 'sort_mode', 'input');
    addParameter(p, 'sort_direction', 'descend');
    addParameter(p, 'clim', struct());
    addParameter(p, 'fip_clim', []);
    addParameter(p, 'suptitle', '');
    addParameter(p, 'split', 'none');
    addParameter(p, 'end_window', [-0.5 2]);
    parse(p, varargin{:});
    opts = p.Results;

    if isempty(opts.syllables)
        error('f01_plot_syllable_onset_heatmap_summary requires a ''syllables'' list.');
    end

    if ischar(opts.panels) || isstring(opts.panels)
        opts.panels = cellstr(opts.panels);
    elseif iscell(opts.panels)
        opts.panels = cellfun(@char, opts.panels, 'UniformOutput', false);
    else
        error('''panels'' must be a char, string, or cell array.');
    end

    opts.sort_mode = char(string(opts.sort_mode));
    opts.sort_direction = char(string(opts.sort_direction));
    opts.split = char(string(opts.split));
    validateattributes(opts.speed_window, {'numeric'}, {'vector', 'numel', 2});
    opts = f01h_apply_time_window_override(opts);

    day_list = f01h_resolve_day_list(opts.days);
    if isempty(opts.split)
        opts.split = 'none';
    end

    split_info = [];
    if ~strcmp(opts.split, 'none')
        split_info = f01h_get_split_info(opts.split);
    end

    facet_split_rows = strcmp(opts.split, 'trial_outside_trial');
    plot_split_groups = f01h_get_plot_split_groups(split_info, facet_split_rows);
    panel_specs = f01h_expand_panel_specs(opts.panels, split_info, facet_split_rows);
    if isempty(panel_specs)
        error('No supported panels remain after filtering unsupported requests.');
    end

    sample_axis = -opts.t_before:opts.t_after;
    time_axis = sample_axis / opts.fs;

    if isempty(split_info)
        trace_types = unique([{opts.signal}, {'speed'}], 'stable');
        config_syl = struct();
        config_syl.align = struct( ...
            't_before', opts.t_before, ...
            't_after', opts.t_after, ...
            'trace_types', {trace_types});

        events_table = f01_helper_get_syllable_onset_events(all_data, config_syl, ...
            opts.skip_animals_days, opts.syllables);

        if ~isempty(day_list)
            events_table = events_table(ismember(events_table.day, day_list), :);
        end

        bout_info = f01h_collect_bout_info(all_data, opts.syllables, opts.fs, ...
            opts.skip_animals_days, day_list);
    else
        [events_table, bout_info] = f01h_get_split_events(all_data, opts, split_info, day_list);
    end

    sort_metric_all = f01h_compute_syllable_window_speed(events_table, ...
        opts.syllables, time_axis, opts.speed_window);
    [row_order, row_idx] = f01h_get_row_order(opts.syllables, sort_metric_all, ...
        opts.sort_mode, opts.sort_direction);
    row_labels = arrayfun(@num2str, row_order, 'UniformOutput', false);
    sort_metric = sort_metric_all(row_idx);

    panel_names = cell(1, numel(panel_specs));
    panel_titles = cell(1, numel(panel_specs));
    panel_matrices = struct();
    panel_x = struct();
    panel_has_data = struct();

    for i_plot_row = 1:numel(plot_split_groups)
        split_group = plot_split_groups{i_plot_row};
        row_events = f01h_filter_events_by_plot_group(events_table, split_group);
        row_bout_info = f01h_filter_bout_info_by_plot_group(bout_info, split_group);
        for i_panel = 1:numel(panel_specs)
            spec = panel_specs(i_panel);
            panel_names{i_panel} = spec.name;
            panel_titles{i_panel} = spec.title;

            [this_matrix, this_x, has_data] = f01h_build_panel_matrix( ...
                spec, row_events, row_bout_info, opts, time_axis, day_list, row_order);

            field_name = f01h_get_row_panel_field_name(split_group, spec.name, facet_split_rows);
            panel_matrices.(field_name) = this_matrix;
            panel_x.(field_name) = this_x;
            panel_has_data.(field_name) = has_data;
        end
    end

    resolved_clim = f01h_resolve_clim(panel_matrices, panel_specs, plot_split_groups, ...
        facet_split_rows, opts.clim, opts.fip_clim);

    [fig, tl] = myFigure(numel(plot_split_groups), numel(panel_specs), 460, 480, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    for i_plot_row = 1:numel(plot_split_groups)
        split_group = plot_split_groups{i_plot_row};
        row_prefix = f01h_get_plot_group_prefix(split_group, facet_split_rows);
        for i_panel = 1:numel(panel_specs)
            spec = panel_specs(i_panel);
            field_name = f01h_get_row_panel_field_name(split_group, spec.name, facet_split_rows);
            ax = nexttile(tl);
            f01h_plot_heatmap_panel(ax, spec, panel_matrices.(field_name), ...
                panel_x.(field_name), row_labels, resolved_clim, panel_has_data.(field_name));
            title(ax, f01h_format_row_panel_title(row_prefix, panel_titles{i_panel}), 'Interpreter', 'none');
        end
    end

    out = struct();
    out.row_order = row_order;
    out.row_labels = row_labels;
    out.sort_metric = sort_metric;
    out.time_axis = time_axis;
    out.panel_names = panel_names;
    out.panel_matrices = panel_matrices;
    out.panel_x = panel_x;
    out.clim = resolved_clim;
    out.day_list = day_list;
    out.split = opts.split;
    out.split_info = split_info;
    out.plot_split_groups = plot_split_groups;
    out.t_before_samples = opts.t_before;
    out.t_after_samples = opts.t_after;
end

%--------------------------------------------------------------------------
% Panel setup
%--------------------------------------------------------------------------
function panel_specs = f01h_expand_panel_specs(requested_panels, split_info, facet_split_rows)
    panel_specs = struct('name', {}, 'family', {}, 'source', {}, 'title', {}, ...
        'region', {}, 'signal', {}, 'is_time', {}, 'split_group', {}, ...
        'split_label', {});

    is_split_mode = ~isempty(split_info) && ~facet_split_rows;

    unsupported = {};
    for i_panel = 1:numel(requested_panels)
        panel_name = requested_panels{i_panel};
        switch panel_name
            case 'fip_psth'
                if is_split_mode
                    for i_group = 1:numel(split_info.ids)
                        group_id = split_info.ids{i_group};
                        group_label = split_info.labels{i_group};
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('fip_psth_%s_NAcMed', group_id), ...
                            'family', 'fip', ...
                            'source', 'fip_psth', ...
                            'title', sprintf('%s FIP NAcMed', group_label), ...
                            'region', 'NAcMed', ...
                            'signal', 'signal', ...
                            'is_time', true, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('fip_psth_%s_NAcLat', group_id), ...
                            'family', 'fip', ...
                            'source', 'fip_psth', ...
                            'title', sprintf('%s FIP NAcLat', group_label), ...
                            'region', 'NAcLat', ...
                            'signal', 'signal', ...
                            'is_time', true, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                    end
                else
                    panel_specs(end + 1) = struct( ...
                        'name', 'fip_psth_NAcMed', ...
                        'family', 'fip', ...
                        'source', 'fip_psth', ...
                        'title', 'FIP NAcMed', ...
                        'region', 'NAcMed', ...
                        'signal', 'signal', ...
                        'is_time', true, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                    panel_specs(end + 1) = struct( ...
                        'name', 'fip_psth_NAcLat', ...
                        'family', 'fip', ...
                        'source', 'fip_psth', ...
                        'title', 'FIP NAcLat', ...
                        'region', 'NAcLat', ...
                        'signal', 'signal', ...
                        'is_time', true, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                end

            case 'speed_psth'
                if is_split_mode
                    for i_group = 1:numel(split_info.ids)
                        group_id = split_info.ids{i_group};
                        group_label = split_info.labels{i_group};
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('speed_psth_%s', group_id), ...
                            'family', 'speed', ...
                            'source', 'speed_psth', ...
                            'title', sprintf('%s Speed', group_label), ...
                            'region', '', ...
                            'signal', 'speed', ...
                            'is_time', true, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                    end
                else
                    panel_specs(end + 1) = struct( ...
                        'name', 'speed_psth', ...
                        'family', 'speed', ...
                        'source', 'speed_psth', ...
                        'title', 'Speed', ...
                        'region', '', ...
                        'signal', 'speed', ...
                        'is_time', true, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                end

            case 'daily_counts'
                if is_split_mode
                    for i_group = 1:numel(split_info.ids)
                        group_id = split_info.ids{i_group};
                        group_label = split_info.labels{i_group};
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('daily_counts_%s', group_id), ...
                            'family', 'counts', ...
                            'source', 'daily_counts', ...
                            'title', sprintf('%s Daily Counts', group_label), ...
                            'region', '', ...
                            'signal', '', ...
                            'is_time', false, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                    end
                else
                    panel_specs(end + 1) = struct( ...
                        'name', 'daily_counts', ...
                        'family', 'counts', ...
                        'source', 'daily_counts', ...
                        'title', 'Daily Counts', ...
                        'region', '', ...
                        'signal', '', ...
                        'is_time', false, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                end

            case 'fa_counts'
                if is_split_mode
                    for i_group = 1:numel(split_info.ids)
                        group_id = split_info.ids{i_group};
                        group_label = split_info.labels{i_group};
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('fa_counts_%s', group_id), ...
                            'family', 'counts', ...
                            'source', 'fa_counts', ...
                            'title', sprintf('%s Final Approach Counts', group_label), ...
                            'region', '', ...
                            'signal', '', ...
                            'is_time', false, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                    end
                else
                    panel_specs(end + 1) = struct( ...
                        'name', 'fa_counts', ...
                        'family', 'counts', ...
                        'source', 'fa_counts', ...
                        'title', 'Final Approach Counts', ...
                        'region', '', ...
                        'signal', '', ...
                        'is_time', false, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                end

            case 'bout_hist'
                if is_split_mode
                    for i_group = 1:numel(split_info.ids)
                        group_id = split_info.ids{i_group};
                        group_label = split_info.labels{i_group};
                        panel_specs(end + 1) = struct( ...
                            'name', sprintf('bout_hist_%s', group_id), ...
                            'family', 'bout_hist', ...
                            'source', 'bout_hist', ...
                            'title', sprintf('%s Bout Length Density', group_label), ...
                            'region', '', ...
                            'signal', '', ...
                            'is_time', false, ...
                            'split_group', group_id, ...
                            'split_label', group_label); %#ok<AGROW>
                    end
                else
                    panel_specs(end + 1) = struct( ...
                        'name', 'bout_hist', ...
                        'family', 'bout_hist', ...
                        'source', 'bout_hist', ...
                        'title', 'Bout Length Density', ...
                        'region', '', ...
                        'signal', '', ...
                        'is_time', false, ...
                        'split_group', '', ...
                        'split_label', ''); %#ok<AGROW>
                end

            case {'trajectory', 'fip_psth_days', 'speed_psth_days'}
                unsupported{end + 1} = panel_name; %#ok<AGROW>

            otherwise
                unsupported{end + 1} = panel_name; %#ok<AGROW>
        end
    end

    unsupported = unique(unsupported, 'stable');
    for i_name = 1:numel(unsupported)
        warning('f01_plot_syllable_onset_heatmap_summary:UnsupportedPanel', ...
            'Skipping unsupported heatmap panel ''%s''.', unsupported{i_name});
    end

    if facet_split_rows && ~isempty(split_info) && strcmp(split_info.name, 'trial_outside_trial')
        panel_specs(end + 1) = struct( ...
            'name', 'trial_time_remaining', ...
            'family', 'trial_remaining', ...
            'source', 'trial_time_remaining', ...
            'title', 'Time To End', ...
            'region', '', ...
            'signal', '', ...
            'is_time', true, ...
            'split_group', '', ...
            'split_label', ''); %#ok<AGROW>
    end
end

function day_list = f01h_resolve_day_list(days_opt)
    if isempty(days_opt)
        day_list = 1:5;
    else
        day_list = unique(days_opt(:)');
    end
end

function plot_split_groups = f01h_get_plot_split_groups(split_info, facet_split_rows)
    if facet_split_rows && ~isempty(split_info)
        plot_split_groups = split_info.ids;
    else
        plot_split_groups = {''};
    end
end

function field_name = f01h_get_row_panel_field_name(split_group, panel_name, facet_split_rows)
    if ~facet_split_rows || isempty(split_group)
        field_name = panel_name;
    else
        field_name = sprintf('%s__%s', split_group, panel_name);
    end
end

function row_prefix = f01h_get_plot_group_prefix(split_group, facet_split_rows)
    row_prefix = '';
    if ~facet_split_rows
        return;
    end

    switch split_group
        case 'inside_trial'
            row_prefix = 'Inside Trial';
        case 'outside_trial'
            row_prefix = 'Outside Trial';
        otherwise
            row_prefix = char(string(split_group));
    end
end

function title_text = f01h_format_row_panel_title(row_prefix, base_title)
    if isempty(row_prefix)
        title_text = base_title;
    else
        title_text = sprintf('%s - %s', row_prefix, base_title);
    end
end

function events_out = f01h_filter_events_by_plot_group(events_in, split_group)
    if isempty(split_group) || height(events_in) == 0 || ...
            ~ismember('split_group', events_in.Properties.VariableNames)
        events_out = events_in;
    else
        events_out = events_in(strcmp(events_in.split_group, split_group), :);
    end
end

function bout_info_out = f01h_filter_bout_info_by_plot_group(bout_info_in, split_group)
    bout_info_out = bout_info_in;
    if isempty(split_group) || ~isfield(bout_info_in, 'split_ids') || isempty(bout_info_in.split_ids)
        return;
    end

    group_idx = find(strcmp(bout_info_in.split_ids, split_group), 1);
    if isempty(group_idx)
        error('Unknown split group: %s', split_group);
    end

    if ndims(bout_info_in.bout_lengths) == 3
        bout_info_out.bout_lengths = bout_info_in.bout_lengths(:, :, group_idx);
    end
    if ndims(bout_info_in.daily_counts) == 3
        bout_info_out.daily_counts = bout_info_in.daily_counts(:, :, group_idx);
    end
    if ndims(bout_info_in.fa_counts) == 3
        bout_info_out.fa_counts = bout_info_in.fa_counts(:, :, group_idx);
    end
    bout_info_out.split_ids = {};
    bout_info_out.split_labels = {};
end

function opts = f01h_apply_time_window_override(opts)
    if isempty(opts.t_before_after)
        return;
    end

    validateattributes(opts.t_before_after, {'numeric'}, {'vector', 'numel', 2, 'finite'});

    t_bounds = double(opts.t_before_after(:)');
    if t_bounds(1) >= 0 || t_bounds(2) <= 0
        error('t_before_after must bracket onset, e.g. [-2 2] or [-1.5 1].');
    end
    if t_bounds(1) >= t_bounds(2)
        error('t_before_after must be increasing: [t_min t_max].');
    end

    opts.t_before = round(abs(t_bounds(1)) * opts.fs);
    opts.t_after = round(abs(t_bounds(2)) * opts.fs);
end

%--------------------------------------------------------------------------
% Matrix builders
%--------------------------------------------------------------------------
function [panel_matrix, panel_x, has_data] = f01h_build_panel_matrix( ...
    spec, events_table, bout_info, opts, time_axis, day_list, row_order)

    switch spec.source
        case 'fip_psth'
            if isempty(spec.region) || height(events_table) == 0 || ...
                    ~ismember('region', events_table.Properties.VariableNames)
                region_events = events_table([], :);
            else
                region_events = events_table(strcmp(events_table.region, spec.region), :);
            end
            if ~isempty(spec.split_group) && ismember('split_group', region_events.Properties.VariableNames)
                region_events = region_events(strcmp(region_events.split_group, spec.split_group), :);
            end
            panel_matrix = f01h_build_psth_matrix(region_events, row_order, ...
                opts.signal, opts.aggregate, time_axis);
            panel_x = time_axis;
            has_data = any(~isnan(panel_matrix(:)));

        case 'speed_psth'
            group_events = events_table;
            if ~isempty(spec.split_group) && ismember('split_group', group_events.Properties.VariableNames)
                group_events = group_events(strcmp(group_events.split_group, spec.split_group), :);
            end
            panel_matrix = f01h_build_psth_matrix(group_events, row_order, ...
                'speed', opts.aggregate, time_axis);
            panel_x = time_axis;
            has_data = any(~isnan(panel_matrix(:)));

        case 'daily_counts'
            panel_matrix = f01h_reorder_rows( ...
                f01h_select_group_counts(bout_info.daily_counts, spec.split_group, bout_info), ...
                row_order, bout_info.syllables);
            panel_x = day_list;
            has_data = any(panel_matrix(:) > 0);

        case 'fa_counts'
            panel_matrix = f01h_reorder_rows( ...
                f01h_select_group_counts(bout_info.fa_counts, spec.split_group, bout_info), ...
                row_order, bout_info.syllables);
            panel_x = day_list;
            has_data = any(panel_matrix(:) > 0);

        case 'bout_hist'
            panel_matrix = f01h_build_bout_hist_matrix(bout_info, row_order, spec.split_group);
            panel_x = bout_info.hist_centers;
            has_data = any(~isnan(panel_matrix(:)));

        case 'trial_time_remaining'
            panel_matrix = f01h_build_trial_remaining_density_matrix(events_table, row_order, time_axis);
            panel_x = time_axis;
            has_data = any(~isnan(panel_matrix(:)));

        otherwise
            error('Unknown panel source: %s', spec.source);
    end
end

function panel_matrix = f01h_build_psth_matrix(events_table, syllables, signal_name, aggregate_level, time_axis)
    panel_matrix = nan(numel(syllables), numel(time_axis));

    for i_syl = 1:numel(syllables)
        syl_events = events_table(events_table.syllable == syllables(i_syl), :);
        [mean_trace, ~, ~] = f01h_compute_trace_stats_for_aggregate( ...
            syl_events, signal_name, aggregate_level);
        if isempty(mean_trace)
            continue;
        end

        mean_trace = f01h_interp_trace_to_axis(mean_trace, time_axis);
        panel_matrix(i_syl, 1:numel(mean_trace)) = mean_trace;
    end
end

function bout_hist_matrix = f01h_build_bout_hist_matrix(bout_info, row_order, split_group)
    n_rows = numel(row_order);
    n_cols = numel(bout_info.hist_centers);
    bout_hist_matrix = nan(n_rows, n_cols);

    group_idx = f01h_get_optional_group_idx(bout_info, split_group);

    for i_row = 1:n_rows
        syl = row_order(i_row);
        syl_idx = find(bout_info.syllables == syl, 1);
        if isempty(syl_idx)
            continue;
        end

        animal_densities = nan(size(bout_info.bout_lengths, 2), n_cols);
        for i_animal = 1:size(bout_info.bout_lengths, 2)
            if isempty(group_idx)
                lengths = bout_info.bout_lengths{syl_idx, i_animal};
            else
                lengths = bout_info.bout_lengths{syl_idx, i_animal, group_idx};
            end
            lengths = lengths(~isnan(lengths));
            if isempty(lengths)
                continue;
            end

            if numel(bout_info.hist_edges) > 1
                density = histcounts(lengths, bout_info.hist_edges, 'Normalization', 'pdf');
                animal_densities(i_animal, :) = density;
            end
        end

        valid_animals = any(~isnan(animal_densities), 2);
        if any(valid_animals)
            bout_hist_matrix(i_row, :) = mean(animal_densities(valid_animals, :), 1, 'omitnan');
        end
    end
end

function panel_matrix = f01h_build_trial_remaining_density_matrix(events_table, row_order, time_axis)
    panel_matrix = nan(numel(row_order), numel(time_axis));

    if height(events_table) == 0 || ~ismember('trial_time_remaining', events_table.Properties.VariableNames)
        return;
    end

    t_min = min(time_axis);
    t_max = max(time_axis);
    for i_row = 1:numel(row_order)
        syl_events = events_table(events_table.syllable == row_order(i_row), :);
        if height(syl_events) == 0
            continue;
        end

        remaining = syl_events.trial_time_remaining;
        remaining = remaining(isfinite(remaining) & remaining >= t_min & remaining <= t_max);
        if isempty(remaining)
            continue;
        end

        panel_matrix(i_row, :) = f01h_compute_time_density(remaining, time_axis);
    end
end

function density = f01h_compute_time_density(values, x_grid)
    if exist('ksdensity', 'file') == 2 && numel(values) > 1
        density = ksdensity(values, x_grid);
    else
        if numel(x_grid) > 1
            dx = median(diff(x_grid));
        else
            dx = 1;
        end
        edges = [x_grid(1) - dx / 2, x_grid(1:end-1) + diff(x_grid) / 2, x_grid(end) + dx / 2];
        density = histcounts(values, edges, 'Normalization', 'pdf');
    end
end

function counts_out = f01h_select_group_counts(counts_in, split_group, bout_info)
    group_idx = f01h_get_optional_group_idx(bout_info, split_group);
    if isempty(group_idx)
        counts_out = counts_in;
    else
        counts_out = counts_in(:, :, group_idx);
    end
end

function group_idx = f01h_get_optional_group_idx(bout_info, split_group)
    if isempty(split_group) || ~isfield(bout_info, 'split_ids') || isempty(bout_info.split_ids)
        group_idx = [];
        return;
    end

    group_idx = find(strcmp(bout_info.split_ids, split_group), 1);
    if isempty(group_idx)
        error('Unknown split group: %s', split_group);
    end
end

function reordered = f01h_reorder_rows(matrix_in, row_order, syllables_all)
    reordered = zeros(numel(row_order), size(matrix_in, 2));
    for i_row = 1:numel(row_order)
        src_idx = find(syllables_all == row_order(i_row), 1);
        if isempty(src_idx)
            reordered(i_row, :) = NaN;
        else
            reordered(i_row, :) = matrix_in(src_idx, :);
        end
    end
end

%--------------------------------------------------------------------------
% Bout summaries
%--------------------------------------------------------------------------
function bout_info = f01h_collect_bout_info(all_data, syllables, fs, skip_animals_days, day_list)
    n_syllables = numel(syllables);
    n_animals = numel(all_data);
    n_days = numel(day_list);

    bout_lengths = cell(n_syllables, n_animals);
    daily_counts = zeros(n_syllables, n_days);
    fa_counts = zeros(n_syllables, n_days);

    for animal = 1:n_animals
        for i_day = 1:n_days
            day = day_list(i_day);
            if ismember([animal, day], skip_animals_days, 'rows')
                continue;
            end
            if day > numel(all_data(animal).data)
                continue;
            end

            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames)
                continue;
            end

            syl_data = d.syllable;
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; height(d)];
            run_syllables = syl_data(run_starts);
            run_lengths_sec = (run_ends - run_starts + 1) / fs;
            has_fa = ismember('final_approach', d.Properties.VariableNames);

            for i_syl = 1:n_syllables
                bout_mask = run_syllables == syllables(i_syl);
                if ~any(bout_mask)
                    continue;
                end

                bout_lengths{i_syl, animal} = [bout_lengths{i_syl, animal}; run_lengths_sec(bout_mask)];
                daily_counts(i_syl, i_day) = daily_counts(i_syl, i_day) + sum(bout_mask);

                if has_fa
                    bout_starts = run_starts(bout_mask);
                    fa_counts(i_syl, i_day) = fa_counts(i_syl, i_day) + sum(d.final_approach(bout_starts));
                end
            end
        end
    end

    all_lengths = vertcat(bout_lengths{:});
    all_lengths = all_lengths(~isnan(all_lengths));
    if isempty(all_lengths)
        hist_edges = linspace(0, 3, 21);
    else
        max_len = prctile(all_lengths, 95);
        if ~isfinite(max_len) || max_len <= 0
            max_len = max(all_lengths);
        end
        if ~isfinite(max_len) || max_len <= 0
            max_len = 1;
        end
        hist_edges = linspace(0, max_len, 21);
    end

    bout_info = struct();
    bout_info.syllables = syllables;
    bout_info.bout_lengths = bout_lengths;
    bout_info.daily_counts = daily_counts;
    bout_info.fa_counts = fa_counts;
    bout_info.hist_edges = hist_edges;
    bout_info.hist_centers = hist_edges(1:end-1) + diff(hist_edges) / 2;
    bout_info.split_ids = {};
end

function [events_table, bout_info] = f01h_get_split_events(all_data, opts, split_info, day_list)
    events_table = table();
    n_animals = numel(all_data);
    n_syllables = numel(opts.syllables);
    n_groups = numel(split_info.ids);
    n_days = numel(day_list);

    bout_lengths = cell(n_syllables, n_animals, n_groups);
    daily_counts = zeros(n_syllables, n_days, n_groups);
    fa_counts = zeros(n_syllables, n_days, n_groups);

    config_syl = struct();
    config_syl.t_before = opts.t_before;
    config_syl.t_after = opts.t_after;
    config_syl.trace_types = {opts.signal, 'speed'};

    for animal = 1:n_animals
        for i_day = 1:n_days
            day = day_list(i_day);
            if ismember([animal, day], opts.skip_animals_days, 'rows')
                continue;
            end
            if day > numel(all_data(animal).data)
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
            end_times = f01h_get_end_times(d_old);

            syl_data = d.syllable;
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; height(d)];
            run_syllables = syl_data(run_starts);
            run_lengths_sec = (run_ends - run_starts + 1) / opts.fs;
            onset_time_all = d.time(run_starts);

            [split_group_all, include_mask] = f01h_assign_split_groups( ...
                d, d_old, run_starts, run_ends, onset_time_all, end_times, opts, split_info);

            selected_mask = include_mask & ismember(run_syllables, opts.syllables);
            if ~any(selected_mask)
                continue;
            end

            run_starts_sel = run_starts(selected_mask);
            run_syllables_sel = run_syllables(selected_mask);
            onset_time_sel = onset_time_all(selected_mask);
            split_group_sel = split_group_all(selected_mask);
            run_lengths_sel = run_lengths_sec(selected_mask);

            has_fa = ismember('final_approach', d.Properties.VariableNames);
            for i_group = 1:n_groups
                group_mask = strcmp(split_group_sel, split_info.ids{i_group});
                if ~any(group_mask)
                    continue;
                end

                for i_syl = 1:n_syllables
                    syl = opts.syllables(i_syl);
                    syl_mask = group_mask & run_syllables_sel == syl;
                    if ~any(syl_mask)
                        continue;
                    end

                    bout_lengths{i_syl, animal, i_group} = [ ...
                        bout_lengths{i_syl, animal, i_group}; run_lengths_sel(syl_mask)];
                    daily_counts(i_syl, i_day, i_group) = daily_counts(i_syl, i_day, i_group) + sum(syl_mask);

                    if has_fa
                        fa_counts(i_syl, i_day, i_group) = fa_counts(i_syl, i_day, i_group) + ...
                            sum(d.final_approach(run_starts_sel(syl_mask)));
                    end
                end
            end

            events = struct();
            events.time_idx = run_starts_sel;
            events.syllable = run_syllables_sel;
            events.onset_time = onset_time_sel;
            events.split_group = split_group_sel;
            events.trial_time_remaining = f01h_compute_trial_time_remaining(onset_time_sel, end_times, split_group_sel);
            events_aligned = f01_helper_align_signals(d, events, config_syl);
            events_aligned = myStruct2Mat(events_aligned);

            if height(events_aligned) == 0
                continue;
            end

            n_rows = height(events_aligned);
            events_aligned.animal = repmat(animal, n_rows, 1);
            events_aligned.day = repmat(day, n_rows, 1);
            events_aligned.region = repmat({all_data(animal).region}, n_rows, 1);
            events_table = [events_table; events_aligned]; %#ok<AGROW>
        end
    end

    if height(events_table) > 0
        move_vars = {'animal', 'day', 'region', 'syllable', 'split_group'};
        move_vars = move_vars(ismember(move_vars, events_table.Properties.VariableNames));
        events_table = movevars(events_table, move_vars, 'Before', 1);
    end

    all_lengths = bout_lengths(:);
    all_lengths = vertcat(all_lengths{:});
    all_lengths = all_lengths(~isnan(all_lengths));
    if isempty(all_lengths)
        hist_edges = linspace(0, 3, 21);
    else
        max_len = prctile(all_lengths, 95);
        if ~isfinite(max_len) || max_len <= 0
            max_len = max(all_lengths);
        end
        if ~isfinite(max_len) || max_len <= 0
            max_len = 1;
        end
        hist_edges = linspace(0, max_len, 21);
    end

    bout_info = struct();
    bout_info.syllables = opts.syllables;
    bout_info.bout_lengths = bout_lengths;
    bout_info.daily_counts = daily_counts;
    bout_info.fa_counts = fa_counts;
    bout_info.hist_edges = hist_edges;
    bout_info.hist_centers = hist_edges(1:end-1) + diff(hist_edges) / 2;
    bout_info.split_ids = split_info.ids;
    bout_info.split_labels = split_info.labels;
end

function time_remaining = f01h_compute_trial_time_remaining(onset_times, end_times, split_group)
    time_remaining = nan(size(onset_times));
    if isempty(end_times)
        return;
    end

    for i_onset = 1:numel(onset_times)
        if nargin >= 3 && ~isempty(split_group) && ~strcmp(split_group{i_onset}, 'inside_trial')
            continue;
        end

        next_end_idx = find(end_times >= onset_times(i_onset), 1);
        if ~isempty(next_end_idx)
            time_remaining(i_onset) = end_times(next_end_idx) - onset_times(i_onset);
        end
    end
end

function [split_group_all, include_mask] = f01h_assign_split_groups(d, d_old, onset_idx_all, end_idx_all, onset_time_all, end_times, opts, split_info)
    split_group_all = repmat(split_info.ids(2), length(onset_idx_all), 1);
    include_mask = true(size(onset_idx_all));
    roi_mask = f01h_classify_region1_bouts(d, onset_idx_all, end_idx_all);

    switch split_info.classification_mode
        case 'active_nonactive_valve'
            in_group1 = f01h_classify_near_end(onset_time_all, end_times, opts.end_window);
        case 'region1'
            in_group1 = roi_mask;
        case 'trial_membership'
            in_trial = f01h_get_trial_membership_mask(d, d_old);
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

function end_times = f01h_get_end_times(d_old)
    end_times = [];
    if isempty(d_old) || ~ismember('type', d_old.Properties.VariableNames) || ...
            ~ismember('time', d_old.Properties.VariableNames)
        return;
    end

    end_times = d_old.time(strcmp(d_old.type, 'end_of_trial'));
end

function is_near_end = f01h_classify_near_end(onset_times, end_times, end_window)
    is_near_end = false(size(onset_times));
    if isempty(end_times)
        return;
    end

    for i_onset = 1:length(onset_times)
        is_near_end(i_onset) = any(onset_times(i_onset) >= end_times + end_window(1) & ...
            onset_times(i_onset) <= end_times + end_window(2));
    end
end

function in_trial = f01h_get_trial_membership_mask(d, d_old)
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

function in_group1 = f01h_classify_region1_bouts(d, start_idx, end_idx)
    if ~ismember('centroidX', d.Properties.VariableNames) || ~ismember('centroidY', d.Properties.VariableNames)
        in_group1 = false(size(start_idx));
        return;
    end

    start_in_roi = f01h_is_region1_point_in_roi(d.centroidX(start_idx), d.centroidY(start_idx));
    end_in_roi = f01h_is_region1_point_in_roi(d.centroidX(end_idx), d.centroidY(end_idx));
    in_group1 = start_in_roi | end_in_roi;
end

function in_roi = f01h_is_region1_point_in_roi(x, y)
    in_roi = isfinite(x) & isfinite(y) & ( ...
        ((x >= 500) & (x <= 700) & (y >= 0) & (y <= 250)) | ...
        ((x >= 500) & (x <= 700) & (y >= 950) & (y <= 1200)) | ...
        ((x >= 0) & (x <= 250) & (y >= 500) & (y <= 700)) | ...
        ((x >= 950) & (x <= 1200) & (y >= 500) & (y <= 700)));
end

function split_info = f01h_get_split_info(split_name)
    split_info = struct();
    split_info.name = split_name;
    switch split_name
        case 'active_nonactive_valve'
            split_info.ids = {'near_end', 'other'};
            split_info.labels = {'Active V', 'Nonactive V'};
            split_info.classification_mode = 'active_nonactive_valve';
            split_info.restrict_to_roi = false;
        case 'active_nonactive_valve_within_roi'
            split_info.ids = {'near_end', 'other'};
            split_info.labels = {'Active V', 'Nonactive V'};
            split_info.classification_mode = 'active_nonactive_valve';
            split_info.restrict_to_roi = true;
        case 'region1'
            split_info.ids = {'roi', 'nonroi'};
            split_info.labels = {'ROI', 'Non-ROI'};
            split_info.classification_mode = 'region1';
            split_info.restrict_to_roi = false;
        case 'trial_outside_trial'
            split_info.ids = {'inside_trial', 'outside_trial'};
            split_info.labels = {'Inside Trial', 'Outside Trial'};
            split_info.classification_mode = 'trial_membership';
            split_info.restrict_to_roi = false;
        otherwise
            error('Unknown split mode: %s', split_name);
    end
end

%--------------------------------------------------------------------------
% Sorting and summary metrics
%--------------------------------------------------------------------------
function [row_order, row_idx] = f01h_get_row_order(syllables, sort_metric, sort_mode, sort_direction)
    switch sort_mode
        case 'input'
            row_idx = 1:numel(syllables);

        case 'speed'
            valid_mask = ~isnan(sort_metric(:));
            valid_idx = find(valid_mask);
            invalid_idx = find(~valid_mask);

            if strcmp(sort_direction, 'descend')
                [~, order_valid] = sort(sort_metric(valid_mask), 'descend');
            elseif strcmp(sort_direction, 'ascend')
                [~, order_valid] = sort(sort_metric(valid_mask), 'ascend');
            else
                error('Unknown sort_direction: %s', sort_direction);
            end

            row_idx = [valid_idx(order_valid); invalid_idx(:)]';

        otherwise
            error('Unknown sort_mode: %s', sort_mode);
    end

    row_order = syllables(row_idx);
end

function mean_speed = f01h_compute_syllable_window_speed(events_table, syllables, time_axis, speed_window)
    speed_mask = time_axis >= speed_window(1) & time_axis <= speed_window(2);
    mean_speed = nan(numel(syllables), 1);

    if ~ismember('speed', events_table.Properties.VariableNames) || ~any(speed_mask)
        return;
    end

    for i_syl = 1:numel(syllables)
        syl_events = events_table(events_table.syllable == syllables(i_syl), :);
        [mean_trace, ~, ~] = f01h_compute_trace_stats_for_aggregate(syl_events, 'speed', 'animal');
        if isempty(mean_trace)
            continue;
        end

        mean_trace = f01h_interp_trace_to_axis(mean_trace, time_axis);
        mean_speed(i_syl) = mean(mean_trace(speed_mask), 'omitnan');
    end
end

%--------------------------------------------------------------------------
% Plotting
%--------------------------------------------------------------------------
function f01h_plot_heatmap_panel(ax, spec, panel_matrix, panel_x, row_labels, resolved_clim, has_data)
    hold(ax, 'on');

    n_rows = size(panel_matrix, 1);
    n_cols = size(panel_matrix, 2);
    family_clim = resolved_clim.(spec.family);
    image_x = f01h_get_image_x(panel_x, n_cols, spec.is_time);

    if has_data
        imagesc(ax, image_x, [1 n_rows], panel_matrix);
        set(ax, 'YDir', 'reverse');
        if ~isempty(family_clim)
            caxis(ax, family_clim);
        end
    else
        imagesc(ax, image_x, [1 max(n_rows, 1)], nan(max(n_rows, 1), max(n_cols, 1)));
        set(ax, 'YDir', 'reverse');
        if ~isempty(family_clim)
            caxis(ax, family_clim);
        end
        text(ax, 0.5, 0.5, 'No data', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
    end

    colormap(ax, f01h_get_colormap(spec.family));
    colorbar(ax, 'eastoutside');

    if spec.is_time
        xline(ax, 0, 'k:', 'LineWidth', 0.75);
        xlabel(ax, 'Time (s)');
        xlim(ax, [panel_x(1), panel_x(end)]);
    elseif strcmp(spec.source, 'bout_hist')
        xlabel(ax, 'Duration (s)');
        xlim(ax, [panel_x(1), panel_x(end)]);
    elseif any(strcmp(spec.source, {'daily_counts', 'fa_counts'}))
        xlabel(ax, 'Day');
        xlim(ax, [panel_x(1) - 0.5, panel_x(end) + 0.5]);
    end

    set(ax, 'YTick', 1:n_rows, 'YTickLabel', row_labels);
    ylabel(ax, 'Syllable');

    if any(strcmp(spec.source, {'daily_counts', 'fa_counts'}))
        set(ax, 'XTick', panel_x, ...
            'XTickLabel', arrayfun(@(d) sprintf('D%d', d), panel_x, 'UniformOutput', false));
    elseif strcmp(spec.source, 'bout_hist')
        xticks(ax, linspace(panel_x(1), panel_x(end), min(5, numel(panel_x))));
    end

    box(ax, 'off');
    hold(ax, 'off');
end

function image_x = f01h_get_image_x(panel_x, n_cols, is_time)
    if isempty(panel_x)
        image_x = [0 1];
        return;
    end

    if is_time
        image_x = [panel_x(1), panel_x(end)];
        return;
    end

    if numel(panel_x) == n_cols
        if numel(panel_x) > 1
            dx = median(diff(panel_x));
        else
            dx = 1;
        end
        image_x = [panel_x(1) - dx / 2, panel_x(end) + dx / 2];
    else
        image_x = [panel_x(1), panel_x(end)];
    end
end

function cmap = f01h_get_colormap(family)
    switch family
        case {'fip', 'speed'}
            cmap = f01h_blue_white_red_colormap(256);
        case {'counts', 'bout_hist', 'trial_remaining'}
            cmap = parula(256);
        otherwise
            cmap = parula(256);
    end
end

function cmap = f01h_blue_white_red_colormap(n_colors)
    if nargin < 1
        n_colors = 256;
    end

    n_half = ceil(n_colors / 2);
    blue = [0.18 0.45 0.78];
    white = [1 1 1];
    red = [0.82 0.29 0.21];

    low = [ ...
        linspace(blue(1), white(1), n_half)', ...
        linspace(blue(2), white(2), n_half)', ...
        linspace(blue(3), white(3), n_half)'];
    high = [ ...
        linspace(white(1), red(1), n_colors - n_half + 1)', ...
        linspace(white(2), red(2), n_colors - n_half + 1)', ...
        linspace(white(3), red(3), n_colors - n_half + 1)'];

    cmap = [low; high(2:end, :)];
end

%--------------------------------------------------------------------------
% CLim helpers
%--------------------------------------------------------------------------
function resolved_clim = f01h_resolve_clim(panel_matrices, panel_specs, plot_split_groups, facet_split_rows, clim_opt, fip_clim_opt)
    families = {'fip', 'speed', 'counts', 'bout_hist', 'trial_remaining'};
    resolved_clim = struct('fip', [], 'speed', [], 'counts', [], 'bout_hist', [], 'trial_remaining', []);

    if ~isempty(fip_clim_opt)
        resolved_clim.fip = fip_clim_opt;
    elseif isnumeric(clim_opt) && numel(clim_opt) == 2
        % Backward-friendly shortcut: a numeric clim applies to FIP only.
        resolved_clim.fip = clim_opt(:)';
    end

    for i_family = 1:numel(families)
        family = families{i_family};

        if ~isempty(resolved_clim.(family))
            continue;
        end

        if isstruct(clim_opt) && isfield(clim_opt, family) && ~isempty(clim_opt.(family))
            resolved_clim.(family) = clim_opt.(family);
            continue;
        end

        family_values = [];
        for i_panel = 1:numel(panel_specs)
            if strcmp(panel_specs(i_panel).family, family)
                for i_group = 1:numel(plot_split_groups)
                    field_name = f01h_get_row_panel_field_name(plot_split_groups{i_group}, ...
                        panel_specs(i_panel).name, facet_split_rows);
                    if isfield(panel_matrices, field_name)
                        family_values = [family_values; panel_matrices.(field_name)(:)]; %#ok<AGROW>
                    end
                end
            end
        end

        family_values = family_values(isfinite(family_values));
        if isempty(family_values)
            resolved_clim.(family) = [];
            continue;
        end

        if any(strcmp(family, {'fip', 'speed'}))
            max_abs = max(abs(family_values));
            if max_abs == 0
                max_abs = 1;
            end
            resolved_clim.(family) = [-max_abs, max_abs];
        else
            clim_now = [min(family_values), max(family_values)];
            if clim_now(1) == clim_now(2)
                pad = max(abs(clim_now(1)) * 0.05, 1e-3);
                clim_now = clim_now + [-pad, pad];
            end
            resolved_clim.(family) = clim_now;
        end
    end
end

%--------------------------------------------------------------------------
% Trace helpers
%--------------------------------------------------------------------------
function [mean_trace, sem_trace, n_groups] = f01h_compute_trace_stats_for_aggregate(events_subset, signal_name, aggregate_level)
    mean_trace = [];
    sem_trace = [];
    n_groups = 0;

    if height(events_subset) == 0 || ~ismember(signal_name, events_subset.Properties.VariableNames)
        return;
    end

    traces = f01h_stack_event_traces(events_subset.(signal_name));
    if isempty(traces)
        return;
    end

    switch aggregate_level
        case 'event'
            mean_trace = mean(traces, 1, 'omitnan');
            n_groups = size(traces, 1);
            if n_groups > 1
                sem_trace = std(traces, 0, 1, 'omitnan') / sqrt(n_groups);
            else
                sem_trace = zeros(1, size(traces, 2));
            end

        case 'animal'
            [mean_trace, sem_trace, n_groups] = f01h_compute_group_trace_stats(events_subset, signal_name, 'animal');

        case 'session'
            session_id = events_subset.animal * 100 + events_subset.day;
            temp_table = events_subset;
            temp_table.session_id = session_id;
            [mean_trace, sem_trace, n_groups] = f01h_compute_group_trace_stats(temp_table, signal_name, 'session_id');

        otherwise
            error('Unknown aggregation level: %s', aggregate_level);
    end
end

function [mean_trace, sem_trace, n_groups] = f01h_compute_group_trace_stats(events_subset, signal_name, group_var)
    mean_trace = [];
    sem_trace = [];
    n_groups = 0;

    traces = f01h_stack_event_traces(events_subset.(signal_name));
    if isempty(traces)
        return;
    end

    groups = unique(events_subset.(group_var));
    group_means = nan(numel(groups), size(traces, 2));

    for i_group = 1:numel(groups)
        mask = events_subset.(group_var) == groups(i_group);
        if any(mask)
            group_means(i_group, :) = mean(traces(mask, :), 1, 'omitnan');
        end
    end

    valid_rows = any(~isnan(group_means), 2);
    group_means = group_means(valid_rows, :);
    n_groups = size(group_means, 1);
    if n_groups == 0
        return;
    end

    mean_trace = mean(group_means, 1, 'omitnan');
    if n_groups > 1
        sem_trace = std(group_means, 0, 1, 'omitnan') / sqrt(n_groups);
    else
        sem_trace = zeros(1, size(group_means, 2));
    end
end

function traces = f01h_stack_event_traces(trace_cells)
    if isempty(trace_cells)
        traces = [];
        return;
    end

    lengths = cellfun(@numel, trace_cells);
    max_len = max(lengths);
    traces = nan(numel(trace_cells), max_len);

    for i_trace = 1:numel(trace_cells)
        if isempty(trace_cells{i_trace})
            continue;
        end
        this_trace = trace_cells{i_trace}(:)';
        traces(i_trace, 1:numel(this_trace)) = this_trace;
    end
end

function trace_out = f01h_interp_trace_to_axis(trace_in, time_axis)
    trace_in = trace_in(:)';
    if numel(trace_in) == numel(time_axis)
        trace_out = trace_in;
        return;
    end

    old_t = linspace(time_axis(1), time_axis(end), numel(trace_in));
    trace_out = interp1(old_t, trace_in, time_axis, 'linear', 'extrap');
end
