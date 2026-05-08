
skip_animals_days = [0 0];

t_before = 60;  % samples (~2s at 30 Hz)
t_after = 60;

plot_info = struct();

% config for start_of_trial
config_start = struct();
config_start.event_type = 'start_of_trial';
config_start.align = struct('t_before', t_before, 't_after', t_after, ...
    'trace_types', {{'zsc_exp', 'speed'}});

% config for end_of_trial
config_end = struct();
config_end.event_type = 'end_of_trial';
config_end.align = struct('t_before', t_before, 't_after', t_after, ...
    'trace_types', {{'zsc_exp', 'speed'}});

% get events
start_table = f01_helper_get_trial_events(all_data, config_start, skip_animals_days);
start_table.event_type = repmat({'start'}, height(start_table), 1);

end_table = f01_helper_get_trial_events(all_data, config_end, skip_animals_days);
end_table.event_type = repmat({'end'}, height(end_table), 1);

% Pick one event table for the day-by-day region plot.
% event_table = [start_table; end_table];
% event_table = start_table; event_label = 'Start of Trial';
event_table = end_table;
event_label = 'End of Trial';

time_axis = linspace(-t_before/30, t_after/30, t_before + t_after + 1);

% --- Plot 1: FIP PSTH across days, split by region ---
[fig1, event_days_out] = f01_helper_plot_event_psth_days_by_region(event_table, ...
    'signal', 'zsc_exp', ...
    'time_axis', time_axis, ...
    'days', 1:5, ...
    'aggregate', 'animal', ...
    'suptitle', sprintf('%s - FIP Days', event_label));

%%
%--- Plot 2: Day 5 only, across animals ---
day5 = event_table(event_table.day == 5, :);
if height(day5) > 0
    [traces2, pinfo2] = f01_helper_prepare_psth_data(day5, plot_info, ...
        'signals', {'zsc_exp', 'speed'}, ...
        'color', 'region', ...
        'facet', {'event_type'}, ...
        'aggregate', 'animal', ...
        'signal_layout', 'rows', ...
        'individual_level', 'animal', ...
        'time_axis', time_axis);
    fig2 = f01_helper_plot_psth(traces2, pinfo2, ...
        'suptitle', 'Day 5 across animals', ...
        'sem_alpha', 0.1);
end


%%
%--------------------------------------------------------------------------
% Plot: FIP vs stitched hybrid time-to-go
%--------------------------------------------------------------------------
plot_info = struct();

config_hybrid = struct();
config_hybrid.pre_bins = 0.1:0.1:4;
config_hybrid.post_bins = 0:0.1:1;
config_hybrid.trace_types = {'zsc_exp'};

hybrid_table = f01_helper_get_hybrid_time_to_go_events(all_data, config_hybrid, skip_animals_days);
time_axis_hybrid = [-fliplr(config_hybrid.post_bins(2:end)), 0, config_hybrid.pre_bins];

hybrid_table = hybrid_table(hybrid_table.day == 5, :);

[traces_hybrid, pinfo_hybrid] = f01_helper_prepare_psth_data(hybrid_table, plot_info, ...
    'signals', {'zsc_exp'}, ...
    'color', 'region', ...
    'facet', {}, ...
    'aggregate', 'animal', ...
    'signal_layout', 'rows', ...
    'individual_level', 'animal', ...
    'time_axis', time_axis_hybrid);

fig_hybrid = f01_helper_plot_psth(traces_hybrid, pinfo_hybrid, ...
    'suptitle', 'FIP vs Time-to-go', ...
    'sem_alpha', 0.1, ...
    'x_reverse', true, ...
    'xlim', [-1 4], ...
    'xlabel', 'Distance/Speed (s)', ...
    'ylabel', 'FIP (z-score)');


%%
%--------------------------------------------------------------------------
% Plot 3: Syllable onset PSTH - 4x5 grid by region
%--------------------------------------------------------------------------
config_syl = struct();
config_syl.align = struct('t_before', t_before, 't_after', t_after, ...
    'trace_types', {{'zsc_exp'}});

% get syllable onset events for top 20 syllables
events_table = f01_helper_get_syllable_onset_events(all_data, config_syl, skip_animals_days, sorted_syllables(1:25));


events_table = events_table(events_table.day == 1, :);

% create syllable rank for grid layout (4 rows x 5 cols)
syl_rank = arrayfun(@(s) find(sorted_syllables(1:25) == s, 1), events_table.syllable);
events_table.syllable_row = ceil(syl_rank / 5);
events_table.syllable_col = mod(syl_rank - 1, 5) + 1;

% add syllable label for tile titles
events_table.syllable_label = arrayfun(@(s) sprintf('Syl %d', s), events_table.syllable, 'UniformOutput', false);

[traces3, pinfo3] = f01_helper_prepare_psth_data(events_table, plot_info, ...
    'signals', {'zsc_exp'}, ...
    'color', 'region', ...
    'facet', {'syllable_row', 'syllable_col'}, ...
    'aggregate', 'animal', ...
    'signal_layout', 'rows', ...
    'individual_level', 'animal', ...
    'time_axis', time_axis);

% update facet labels to show syllable IDs
for i = 1:length(pinfo3.facet_labels)
    r = ceil(i / 5);
    c = mod(i - 1, 5) + 1;
    syl_idx = (r - 1) * 5 + c;
    if syl_idx <= 20
        pinfo3.facet_labels{i} = sprintf('Syl %d', sorted_syllables(syl_idx));
    end
end

fig3 = f01_helper_plot_psth(traces3, pinfo3, ...
    'suptitle', 'Syllable onset PSTH by region (top 20)', ...
    'sem_alpha', 0.1);
%%
%--------------------------------------------------------------------------
% Plot 4: Multi-panel syllable summary (f01_plot_syllable_psth_summary)
%--------------------------------------------------------------------------
% Basic usage - top 20 syllables, all panels
% fig4 = f01_plot_syllable_psth_summary(all_data);

% Select specific syllables
plot_syllables = sorted_syllables;  % pick by rank
plot_syllables = [18, 20, 29, 22, 14, 16];
% plot_syllables = [0, 1, 2, 3, 4];              % pick by ID

% Select panels: 'fip_psth', 'fip_psth_days', 'speed_psth', 'speed_psth_days', 'bout_hist', 'daily_counts', 'fa_counts'
plot_panels = {'trajectory','fip_psth', 'fip_psth_days', 'speed_psth', 'speed_psth_days', 'daily_counts', 'fa_counts', 'bout_hist'};

% show_individual: 'none', 'event', 'animal', 'session'
% psth_aggregate applies to both FIP and speed PSTH mean/SEM
fig4 = f01_plot_syllable_psth_summary(all_data, ...
    'syllables', plot_syllables, ...
    'panels', plot_panels, ...
    'signal_layout', 'tiles', ...
    'show_individual', 'animal', ...
    'psth_aggregate', 'animal', ...
    'suptitle', 'Syllable Summary');
%%
%--------------------------------------------------------------------------
% Plot 4a: One-syllable summary split by active valve or region1
%--------------------------------------------------------------------------
plot_syllable_4a = [18, 20, 29, 22, 14, 16];;
plot_panels = {'trajectory','fip_psth', 'fip_psth_days', 'speed_psth', 'speed_psth_days', 'daily_counts', 'bout_hist'};
plot_panels = {'daily_counts'};
split_4a = 'active_nonactive_valve';
% split_4a = 'active_nonactive_valve_within_roi';
% split_4a = 'region1';
split_4a = 'trial_outside_trial';

fig4a = f01_plot_syllable_psth_split_summary(all_data, ...
    'syllables', plot_syllable_4a, ...
    'panels', plot_panels, ...
    'signal_layout', 'tiles', ...
    'show_individual', 'animal', ...
    'psth_aggregate', 'animal', ...
    'split', split_4a, ...
    'suptitle', 'Syllable Summary');

%%
%--------------------------------------------------------------------------
% Plot 5: Reusable syllable-onset PSTH summary
%--------------------------------------------------------------------------

% plot_syllables = [ 29, 22, 14, 16, 20, 18]; color_mode_now = 'syllable';
% plot_syllables = [0, 1, 2, 3, 4];  color_mode_now = 'syllable';
% plot_syllables = [0, 2, 1, 3, 4, 16, 18, 14, 23, 13, 7, 11, 22, 12, 15, 20, 26, 32, 29, 19]; color_mode_now = 'speed';
plot_syllables = most_common_motifs_all(1:95); color_mode_now = 'speed';
% plot_syllables = sorted_syllables(13:25);
% plot_syllables = sorted_syllables; color_mode_now = 'speed';

plot_panels = {'speed_psth', 'fip_psth', 'bout_hist'};
% plot_panels = {'speed_psth'};
split_now = 'trial_outside_trial';

% fig5a = f01_plot_syllable_onset_psth_summary(all_data, ...
%     'syllables', plot_syllables, ...
%     'plot_mode', 'region_facets', ...
%     'panels', plot_panels, ...
%     'aggregate', 'animal', ...
%     'individual_level', 'none', ...
%     'color_mode', color_mode_now, ...
%     'split', split_now, ...
%     'ci_hide', false);

heatmap_panels = {'speed_psth', 'fip_psth', 'daily_counts', 'bout_hist'};
heatmap_sort_mode = 'input';
if strcmp(color_mode_now, 'speed')
    heatmap_sort_mode = 'speed';
end

fig5_heat = f01_plot_syllable_onset_heatmap_summary(all_data, ...
    'syllables', plot_syllables, ...
    'panels', heatmap_panels, ...
    'aggregate', 'animal', ...
    'fip_clim', [-0.5 0.5], ...
    't_before_after', [-4 4], ...
    'sort_mode', heatmap_sort_mode, ...
    'split', split_now, ...
    'suptitle', 'Syllable Heatmap Summary');

% fig5b = f01_plot_syllable_onset_psth_summary(all_data, ...
%     'syllables', plot_syllables, ...
%     'plot_mode', 'region_difference', ...
%     'color_mode', 'syllable');

%--------------------------------------------------------------------------
% Local function: Reusable syllable-onset PSTH summary
%--------------------------------------------------------------------------
function [fig, out] = f01_plot_syllable_onset_psth_summary(all_data, varargin)
    p = inputParser;
    addParameter(p, 'syllables', []);
    addParameter(p, 'signal', 'zsc_exp');
    addParameter(p, 't_before', 120);
    addParameter(p, 't_after', 120);
    addParameter(p, 'fs', 60);
    addParameter(p, 'skip_animals_days', [0 0]);
    addParameter(p, 'plot_mode', 'region_facets');
    addParameter(p, 'panels', {'fip_psth'});
    addParameter(p, 'color_mode', 'syllable');
    addParameter(p, 'aggregate', 'animal');
    addParameter(p, 'individual_level', 'animal');
    addParameter(p, 'speed_window', [0 0.5]);
    addParameter(p, 'days', []);
    addParameter(p, 'suptitle', '');
    addParameter(p, 'ci_hide', false);
    addParameter(p, 'split', 'none');
    parse(p, varargin{:});
    opts = p.Results;
    if ischar(opts.panels) || isstring(opts.panels)
        opts.panels = cellstr(opts.panels);
    elseif iscell(opts.panels)
        opts.panels = cellfun(@char, opts.panels, 'UniformOutput', false);
    end
    opts.split = char(string(opts.split));

    if isempty(opts.syllables)
        error('f01_plot_syllable_onset_psth_summary requires a ''syllables'' list.');
    end

    sorted_syllables = evalin('base', 'sorted_syllables');
    cmap25 = evalin('base', 'cmap25');

    trace_types = unique([{opts.signal}, {'speed'}], 'stable');
    config_syl = struct();
    config_syl.align = struct('t_before', opts.t_before, 't_after', opts.t_after, ...
        'trace_types', {trace_types});

    if strcmp(opts.split, 'none')
        events_table = f01_helper_get_syllable_onset_events(all_data, config_syl, ...
            opts.skip_animals_days, opts.syllables);
    elseif strcmp(opts.split, 'trial_outside_trial')
        events_table = f01_get_trial_outside_trial_syllable_onset_events(all_data, config_syl, ...
            opts.skip_animals_days, opts.syllables);
    else
        error('Unsupported split for f01_plot_syllable_onset_psth_summary: %s', opts.split);
    end

    if ~isempty(opts.days)
        events_table = events_table(ismember(events_table.day, opts.days), :);
    end

    if height(events_table) == 0
        error('No syllable onset events found for the requested filters.');
    end

    time_axis = linspace(-opts.t_before / opts.fs, opts.t_after / opts.fs, ...
        opts.t_before + opts.t_after + 1);

    syllable_labels = arrayfun(@(s) sprintf('Syl %d', s), opts.syllables, 'UniformOutput', false);
    events_table.syllable_label = categorical( ...
        arrayfun(@(s) sprintf('Syl %d', s), events_table.syllable, 'UniformOutput', false), ...
        syllable_labels, 'Ordinal', true);

    trace_colors = f01_get_syllable_trace_colors(events_table, opts.syllables, ...
        sorted_syllables, cmap25, time_axis, opts.color_mode, opts.speed_window);
    sem_alpha_now = 0.1;
    if opts.ci_hide
        sem_alpha_now = 0;
    end

    switch opts.plot_mode
        case 'region_facets'
            if isequal(opts.panels, {'fip_psth'})
                if strcmp(opts.split, 'none')
                    plot_info_local = struct();
                    [traces, pinfo] = f01_helper_prepare_psth_data(events_table, plot_info_local, ...
                        'signals', {opts.signal}, ...
                        'color', 'syllable_label', ...
                        'facet', {'region'}, ...
                        'aggregate', opts.aggregate, ...
                        'signal_layout', 'rows', ...
                        'individual_level', opts.individual_level, ...
                        'time_axis', time_axis);

                    fig = f01_helper_plot_psth(traces, pinfo, ...
                        'colors', trace_colors, ...
                        'suptitle', opts.suptitle, ...
                        'sem_alpha', sem_alpha_now);

                    out = struct();
                    out.events_table = events_table;
                    out.time_axis = time_axis;
                    out.trace_colors = trace_colors;
                    out.traces = traces;
                    out.plot_info = pinfo;
                else
                    [fig, out] = f01_plot_syllable_summary_panels(all_data, events_table, opts, ...
                        time_axis, trace_colors, sem_alpha_now);
                end
            else
                [fig, out] = f01_plot_syllable_summary_panels(all_data, events_table, opts, ...
                    time_axis, trace_colors, sem_alpha_now);
            end

        case 'region_difference'
            [fig, out] = f01_plot_syllable_region_difference(events_table, opts, ...
                time_axis, trace_colors, sem_alpha_now);

        otherwise
            error('Unknown plot_mode: %s', opts.plot_mode);
    end
end

function [fig, out] = f01_plot_syllable_summary_panels(all_data, events_table, opts, time_axis, trace_colors, sem_alpha_now)
    panel_cols = {};
    for i_panel = 1:length(opts.panels)
        switch opts.panels{i_panel}
            case 'fip_psth'
                panel_cols{end + 1} = 'fip_psth_NAcMed';
                panel_cols{end + 1} = 'fip_psth_NAcLat';
            case {'speed_psth', 'bout_hist', 'bout_kde'}
                panel_cols{end + 1} = opts.panels{i_panel};
            otherwise
                error('Unknown summary panel: %s', opts.panels{i_panel});
        end
    end

    split_groups = f01_get_summary_split_groups(opts, events_table);
    n_rows = numel(split_groups);

    [fig, tl] = myFigure(n_rows, length(panel_cols), 360, 300, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';

    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    bout_lengths = [];
    if any(strcmp(panel_cols, 'bout_hist')) || any(strcmp(panel_cols, 'bout_kde'))
        if strcmp(opts.split, 'trial_outside_trial')
            bout_lengths = f01_collect_split_syllable_bout_lengths(all_data, opts);
        else
            bout_lengths = f01_collect_syllable_bout_lengths(all_data, opts);
        end
    end

    shared_axes = struct( ...
        'speed', gobjects(0), ...
        'fip_med', gobjects(0), ...
        'fip_lat', gobjects(0));
    shared_has_data = struct( ...
        'speed', false(0), ...
        'fip_med', false(0), ...
        'fip_lat', false(0));

    for i_row = 1:n_rows
        split_group = split_groups{i_row};
        row_events = f01_filter_events_by_split_group(events_table, split_group);
        row_bout_lengths = f01_filter_bout_lengths_by_split_group(bout_lengths, split_group);
        row_prefix = f01_get_split_group_label(split_group);

        for i_col = 1:length(panel_cols)
            ax = nexttile(tl);
            hold(ax, 'on');

            panel_type = panel_cols{i_col};
            switch panel_type
                case {'fip_psth_NAcMed', 'fip_psth_NAcLat'}
                    region_name = strrep(panel_type, 'fip_psth_', '');
                    region_events = row_events(strcmp(row_events.region, region_name), :);
                    has_data = f01_plot_colored_syllable_psth(ax, region_events, opts, opts.signal, ...
                        time_axis, trace_colors, i_col == 1, sem_alpha_now);
                    title(ax, f01_format_split_panel_title(row_prefix, sprintf('FIP %s', region_name)), 'Interpreter', 'none');
                    ylabel(ax, opts.signal, 'Interpreter', 'none');
                    xlabel(ax, 'Time (s)');
                    if strcmp(region_name, 'NAcMed')
                        shared_axes.fip_med(end + 1) = ax;
                        shared_has_data.fip_med(end + 1) = has_data;
                    else
                        shared_axes.fip_lat(end + 1) = ax;
                        shared_has_data.fip_lat(end + 1) = has_data;
                    end

                case 'speed_psth'
                    has_data = f01_plot_colored_syllable_psth(ax, row_events, opts, 'speed', ...
                        time_axis, trace_colors, i_col == 1, sem_alpha_now);
                    title(ax, f01_format_split_panel_title(row_prefix, 'Speed'), 'Interpreter', 'none');
                    ylabel(ax, 'Speed');
                    xlabel(ax, 'Time (s)');
                    shared_axes.speed(end + 1) = ax;
                    shared_has_data.speed(end + 1) = has_data;

                case {'bout_hist', 'bout_kde'}
                    f01_plot_colored_bout_density(ax, row_bout_lengths, opts.syllables, trace_colors, i_col == 1, sem_alpha_now);
                    title(ax, f01_format_split_panel_title(row_prefix, 'Bout Lengths'), 'Interpreter', 'none');
                    ylabel(ax, 'Density');
                    xlabel(ax, 'Duration (s)');
            end

            hold(ax, 'off');
        end
    end

    if strcmp(opts.split, 'trial_outside_trial')
        f01_sync_axis_group_ylim(shared_axes.speed, shared_has_data.speed);
        f01_sync_axis_group_ylim(shared_axes.fip_med, shared_has_data.fip_med);
        f01_sync_axis_group_ylim(shared_axes.fip_lat, shared_has_data.fip_lat);
    end

    out = struct();
    out.events_table = events_table;
    out.time_axis = time_axis;
    out.trace_colors = trace_colors;
    out.panels = panel_cols;
    out.bout_lengths = bout_lengths;
    out.split_groups = split_groups;
end

function split_groups = f01_get_summary_split_groups(opts, events_table)
    switch opts.split
        case 'none'
            split_groups = {'none'};
        case 'trial_outside_trial'
            if ~ismember('split_group', events_table.Properties.VariableNames)
                error('split_group column missing for split mode: %s', opts.split);
            end
            split_groups = {'inside_trial', 'outside_trial'};
        otherwise
            error('Unsupported split for summary panels: %s', opts.split);
    end
end

function row_events = f01_filter_events_by_split_group(events_table, split_group)
    if strcmp(split_group, 'none')
        row_events = events_table;
    else
        row_events = events_table(strcmp(events_table.split_group, split_group), :);
    end
end

function row_bout_lengths = f01_filter_bout_lengths_by_split_group(bout_lengths, split_group)
    if isempty(bout_lengths)
        row_bout_lengths = bout_lengths;
        return;
    end

    if strcmp(split_group, 'none')
        row_bout_lengths = bout_lengths;
        return;
    end

    group_idx = 1;
    if strcmp(split_group, 'outside_trial')
        group_idx = 2;
    end

    row_bout_lengths = bout_lengths(:, :, group_idx);
end

function label = f01_get_split_group_label(split_group)
    switch split_group
        case 'none'
            label = '';
        case 'inside_trial'
            label = 'Inside Trial';
        case 'outside_trial'
            label = 'Outside Trial';
        otherwise
            label = char(string(split_group));
    end
end

function title_text = f01_format_split_panel_title(prefix, base_title)
    if isempty(prefix)
        title_text = base_title;
    else
        title_text = sprintf('%s - %s', prefix, base_title);
    end
end

function has_data = f01_plot_colored_syllable_psth(ax, events_table, opts, signal_name, time_axis, trace_colors, show_legend, sem_alpha_now)
    legend_handles = gobjects(0);
    legend_labels = {};
    has_data = false;

    for i_syl = 1:length(opts.syllables)
        syl = opts.syllables(i_syl);
        syl_events = events_table(events_table.syllable == syl, :);
        [mean_trace, sem_trace, n_groups] = f01_compute_trace_stats_for_aggregate( ...
            syl_events, signal_name, opts.aggregate);

        if isempty(mean_trace)
            continue;
        end

        h = f01_plot_shaded(ax, time_axis, mean_trace, sem_trace, trace_colors(i_syl, :), sem_alpha_now, 1.2);
        legend_handles(end + 1) = h;
        legend_labels{end + 1} = sprintf('Syl %d (n=%d)', syl, n_groups);
        has_data = true;
    end

    xline(ax, 0, 'k:', 'LineWidth', 0.75);
    yline(ax, 0, 'k:', 'LineWidth', 0.25);
    xlim(ax, [time_axis(1), time_axis(end)]);

    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', ...
            'Box', 'off', 'FontSize', 6);
    end
end

function f01_sync_axis_group_ylim(ax_list, has_data)
    valid_axes = ax_list(isgraphics(ax_list, 'axes'));
    if isempty(valid_axes)
        return;
    end

    valid_mask = has_data(1:min(numel(has_data), numel(valid_axes)));
    valid_mask = valid_mask(:)';
    valid_axes = valid_axes(valid_mask);
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

function f01_plot_colored_bout_density(ax, bout_lengths, syllables, trace_colors, show_legend, sem_alpha_now)
    legend_handles = gobjects(0);
    legend_labels = {};
    all_lengths = vertcat(bout_lengths{:});

    if isempty(all_lengths)
        text(ax, 0.5, 0.5, 'No bouts', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
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

    for i_syl = 1:length(syllables)
        animal_densities = nan(size(bout_lengths, 2), length(x_grid));

        for i_animal = 1:size(bout_lengths, 2)
            lengths = bout_lengths{i_syl, i_animal};
            lengths = lengths(~isnan(lengths) & lengths >= 0 & lengths <= max_len);
            if isempty(lengths)
                continue;
            end

            animal_densities(i_animal, :) = f01_compute_length_density(lengths, x_grid, max_len);
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

        h = f01_plot_shaded(ax, x_grid, mean_density, sem_density, trace_colors(i_syl, :), sem_alpha_now, 1.2);
        legend_handles(end + 1) = h;
        legend_labels{end + 1} = sprintf('Syl %d (n=%d)', syllables(i_syl), n_animals);
    end

    xlim(ax, [0, max_len]);
    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', ...
            'Box', 'off', 'FontSize', 6);
    end
end

function density = f01_compute_length_density(lengths, x_grid, max_len)
    if exist('ksdensity', 'file') == 2 && numel(lengths) > 1
        density = ksdensity(lengths, x_grid, 'Support', 'positive');
    else
        edges = linspace(0, max_len, 25);
        density = histcounts(lengths, edges, 'Normalization', 'pdf');
        x_grid_local = edges(1:end-1) + diff(edges) / 2;
        density = interp1(x_grid_local, density, x_grid, 'linear', 0);
    end
end

function bout_lengths = f01_collect_syllable_bout_lengths(all_data, opts)
    bout_lengths = cell(length(opts.syllables), length(all_data));

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], opts.skip_animals_days, 'rows')
                continue;
            end
            if ~isempty(opts.days) && ~ismember(day, opts.days)
                continue;
            end

            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames)
                continue;
            end

            syl_data = d.syllable;
            n_frames = height(d);
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; n_frames];
            run_syllables = syl_data(run_starts);
            run_lengths_sec = (run_ends - run_starts + 1) / opts.fs;

            for i_syl = 1:length(opts.syllables)
                bout_lengths{i_syl, animal} = [bout_lengths{i_syl, animal}; ...
                    run_lengths_sec(run_syllables == opts.syllables(i_syl))];
            end
        end
    end
end

function bout_lengths = f01_collect_split_syllable_bout_lengths(all_data, opts)
    bout_lengths = cell(length(opts.syllables), length(all_data), 2);

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], opts.skip_animals_days, 'rows')
                continue;
            end
            if ~isempty(opts.days) && ~ismember(day, opts.days)
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

            syl_data = d.syllable;
            n_frames = height(d);
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; n_frames];
            run_syllables = syl_data(run_starts);
            run_lengths_sec = (run_ends - run_starts + 1) / opts.fs;

            split_group = f01_classify_trial_outside_trial_bouts(d, d_old, run_starts, run_ends);
            valid_mask = ~strcmp(split_group, 'exclude');

            run_syllables = run_syllables(valid_mask);
            run_lengths_sec = run_lengths_sec(valid_mask);
            split_group = split_group(valid_mask);

            for i_syl = 1:length(opts.syllables)
                syl_mask = run_syllables == opts.syllables(i_syl);
                if ~any(syl_mask)
                    continue;
                end

                inside_mask = syl_mask & strcmp(split_group, 'inside_trial');
                outside_mask = syl_mask & strcmp(split_group, 'outside_trial');

                bout_lengths{i_syl, animal, 1} = [bout_lengths{i_syl, animal, 1}; run_lengths_sec(inside_mask)];
                bout_lengths{i_syl, animal, 2} = [bout_lengths{i_syl, animal, 2}; run_lengths_sec(outside_mask)];
            end
        end
    end
end

function events_table = f01_get_trial_outside_trial_syllable_onset_events(all_data, config_syl, skip_animals_days, syllable_list)
    events_table = table();

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], skip_animals_days, 'rows')
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

            syl_data = d.syllable;
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; height(d)];
            run_syllables = syl_data(run_starts);

            valid_syl_mask = ismember(run_syllables, syllable_list);
            if ~any(valid_syl_mask)
                continue;
            end

            run_starts = run_starts(valid_syl_mask);
            run_ends = run_ends(valid_syl_mask);
            run_syllables = run_syllables(valid_syl_mask);

            split_group = f01_classify_trial_outside_trial_bouts(d, d_old, run_starts, run_ends);
            keep_mask = ~strcmp(split_group, 'exclude');
            if ~any(keep_mask)
                continue;
            end

            events = struct();
            events.time_idx = run_starts(keep_mask);
            events.syllable = run_syllables(keep_mask);
            events.split_group = split_group(keep_mask);
            events_aligned = f01_helper_align_signals(d, events, config_syl.align);
            events_aligned = myStruct2Mat(events_aligned);

            n = height(events_aligned);
            if n == 0
                continue;
            end

            events_aligned.animal = repmat(animal, n, 1);
            events_aligned.day = repmat(day, n, 1);
            events_aligned.region = repmat({all_data(animal).region}, n, 1);
            events_table = [events_table; events_aligned]; %#ok<AGROW>
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region', 'syllable', 'split_group'}, 'Before', 1);
    end
end

function split_group = f01_classify_trial_outside_trial_bouts(d, d_old, start_idx, end_idx)
    in_trial = f01_get_trial_membership_mask_local(d, d_old);
    start_in_trial = in_trial(start_idx);
    end_in_trial = in_trial(end_idx);

    split_group = repmat({'exclude'}, size(start_idx));
    inside_mask = start_in_trial & end_in_trial;
    outside_mask = ~start_in_trial & ~end_in_trial;
    split_group(inside_mask) = {'inside_trial'};
    split_group(outside_mask) = {'outside_trial'};
end

function in_trial = f01_get_trial_membership_mask_local(d, d_old)
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

function [fig, out] = f01_plot_syllable_region_difference(events_table, opts, time_axis, trace_colors, sem_alpha_now)
    [fig, tl] = myFigure(1, 1, 700, 450, true);
    ax = nexttile(tl);
    hold(ax, 'on');

    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    summary_rows = struct('syllable', {}, 'n_med', {}, 'n_lat', {}, ...
        'mean_trace', {}, 'sem_trace', {});
    legend_handles = gobjects(0);
    legend_labels = {};

    for i_syl = 1:length(opts.syllables)
        syl = opts.syllables(i_syl);
        syl_events = events_table(events_table.syllable == syl, :);

        med_events = syl_events(strcmp(syl_events.region, 'NAcMed'), :);
        lat_events = syl_events(strcmp(syl_events.region, 'NAcLat'), :);

        [med_mean, med_sem, n_med] = f01_compute_group_trace_stats(med_events, opts.signal, 'animal');
        [lat_mean, lat_sem, n_lat] = f01_compute_group_trace_stats(lat_events, opts.signal, 'animal');

        if isempty(med_mean) || isempty(lat_mean)
            continue;
        end

        diff_mean = med_mean - lat_mean;
        diff_sem = sqrt(med_sem .^ 2 + lat_sem .^ 2);

        h = f01_plot_shaded(ax, time_axis, diff_mean, diff_sem, trace_colors(i_syl, :), sem_alpha_now, 1.6);
        legend_handles(end + 1) = h;
        legend_labels{end + 1} = sprintf('Syl %d', syl);

        summary_rows(end + 1).syllable = syl;
        summary_rows(end).n_med = n_med;
        summary_rows(end).n_lat = n_lat;
        summary_rows(end).mean_trace = diff_mean;
        summary_rows(end).sem_trace = diff_sem;
    end

    xline(ax, 0, 'k:', 'LineWidth', 0.75);
    yline(ax, 0, 'k-', 'LineWidth', 0.5);
    xlabel(ax, 'Time (s)');
    ylabel(ax, sprintf('%s (NAcMed - NAcLat)', opts.signal), 'Interpreter', 'none');
    title(ax, 'NAcMed - NAcLat', 'Interpreter', 'none');
    xlim(ax, [time_axis(1), time_axis(end)]);

    if ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'FontSize', 8);
    else
        text(ax, 0.5, 0.5, 'No region overlap for requested syllables', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center');
    end

    hold(ax, 'off');

    out = struct();
    out.events_table = events_table;
    out.time_axis = time_axis;
    out.trace_colors = trace_colors;
    out.summary = summary_rows;
end

function colors = f01_get_syllable_trace_colors(events_table, syllables, sorted_syllables, cmap25, ...
    time_axis, color_mode, speed_window)

    switch color_mode
        case 'syllable'
            colors = zeros(length(syllables), 3);
            for i_syl = 1:length(syllables)
                colors(i_syl, :) = f01_get_syllable_color(syllables(i_syl), sorted_syllables, cmap25);
            end

        case 'speed'
            mean_speed = f01_compute_syllable_window_speed(events_table, syllables, time_axis, speed_window);
            valid_mask = ~isnan(mean_speed);
            colors = repmat([0.5 0.5 0.5], length(syllables), 1);

            if any(valid_mask)
                cmap_speed = cool(25);
                valid_speed = mean_speed(valid_mask);
                speed_low = prctile(valid_speed, 10);
                speed_high = prctile(valid_speed, 90);

                if speed_high == speed_low
                    speed_low = min(valid_speed);
                    speed_high = max(valid_speed);
                end

                if speed_high == speed_low
                    speed_idx = ones(size(mean_speed)) * round(size(cmap_speed, 1) / 2);
                else
                    speed_clipped = min(max(mean_speed, speed_low), speed_high);
                    speed_norm = (speed_clipped - speed_low) / (speed_high - speed_low);
                    speed_idx = round(speed_norm * (size(cmap_speed, 1) - 1)) + 1;
                end

                speed_idx = max(1, min(size(cmap_speed, 1), speed_idx));
                for i_syl = 1:length(syllables)
                    if valid_mask(i_syl)
                        colors(i_syl, :) = cmap_speed(speed_idx(i_syl), :);
                    end
                end
            end

        otherwise
            error('Unknown color_mode: %s', color_mode);
    end
end

function mean_speed = f01_compute_syllable_window_speed(events_table, syllables, time_axis, speed_window)
    speed_mask = time_axis >= speed_window(1) & time_axis <= speed_window(2);
    mean_speed = nan(length(syllables), 1);

    if ~ismember('speed', events_table.Properties.VariableNames)
        return;
    end

    for i_syl = 1:length(syllables)
        syl_events = events_table(events_table.syllable == syllables(i_syl), :);
        if height(syl_events) == 0
            continue;
        end

        if ~any(speed_mask)
            continue;
        end

        [mean_speed_trace, ~, ~] = f01_compute_trace_stats_for_aggregate(syl_events, 'speed', 'animal');
        if isempty(mean_speed_trace)
            continue;
        end

        mean_speed(i_syl) = mean(mean_speed_trace(speed_mask), 'omitnan');
    end
end

function [mean_trace, sem_trace, n_groups] = f01_compute_group_trace_stats(events_subset, signal_name, group_var)
    mean_trace = [];
    sem_trace = [];
    n_groups = 0;

    if height(events_subset) == 0 || ~ismember(signal_name, events_subset.Properties.VariableNames)
        return;
    end

    traces = f01_stack_event_traces(events_subset.(signal_name));
    if isempty(traces)
        return;
    end

    groups = unique(events_subset.(group_var));
    group_means = nan(length(groups), size(traces, 2));

    for i_group = 1:length(groups)
        if iscell(groups)
            mask = strcmp(events_subset.(group_var), groups{i_group});
        else
            mask = events_subset.(group_var) == groups(i_group);
        end
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

function [mean_trace, sem_trace, n_groups] = f01_compute_trace_stats_for_aggregate(events_subset, signal_name, aggregate_level)
    mean_trace = [];
    sem_trace = [];
    n_groups = 0;

    if height(events_subset) == 0 || ~ismember(signal_name, events_subset.Properties.VariableNames)
        return;
    end

    traces = f01_stack_event_traces(events_subset.(signal_name));
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

        case 'none'
            mean_trace = mean(traces, 1, 'omitnan');
            sem_trace = zeros(1, size(traces, 2));
            n_groups = size(traces, 1);

        otherwise
            if ismember(aggregate_level, events_subset.Properties.VariableNames)
                [mean_trace, sem_trace, n_groups] = f01_compute_group_trace_stats( ...
                    events_subset, signal_name, aggregate_level);
            else
                error('Unknown aggregation level: %s', aggregate_level);
            end
    end
end

function traces = f01_stack_event_traces(trace_cells)
    if isempty(trace_cells)
        traces = [];
        return;
    end

    lengths = cellfun(@numel, trace_cells);
    max_len = max(lengths);
    traces = nan(length(trace_cells), max_len);

    for i_trace = 1:length(trace_cells)
        if isempty(trace_cells{i_trace})
            continue;
        end
        this_trace = trace_cells{i_trace}(:)';
        traces(i_trace, 1:numel(this_trace)) = this_trace;
    end
end

function color = f01_get_syllable_color(syl, sorted_syllables, cmap25)
    syl_idx = find(sorted_syllables == syl, 1);
    if ~isempty(syl_idx) && syl_idx <= size(cmap25, 1)
        color = cmap25(syl_idx, :);
    else
        color = [0.5 0.5 0.5];
    end
end

function h = f01_plot_shaded(ax, x, mean_y, sem_y, color, sem_alpha, line_width)
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

    if sem_alpha > 0
        fill(ax, [x, fliplr(x)], [mean_y + sem_y, fliplr(mean_y - sem_y)], ...
            color, 'FaceAlpha', sem_alpha, 'EdgeColor', 'none');
    end
    h = plot(ax, x, mean_y, 'Color', color, 'LineWidth', line_width);
end

function [fig, out] = f01_helper_plot_event_psth_days_by_region(events_table, varargin)
    p = inputParser;
    addParameter(p, 'signal', 'zsc_exp');
    addParameter(p, 'time_axis', []);
    addParameter(p, 'days', 1:5);
    addParameter(p, 'regions', {'NAcMed', 'NAcLat'});
    addParameter(p, 'aggregate', 'animal');
    addParameter(p, 'suptitle', '');
    parse(p, varargin{:});
    opts = p.Results;

    if isempty(opts.time_axis)
        error('f01_helper_plot_event_psth_days_by_region requires a time_axis.');
    end

    [fig, tl] = myFigure(1, numel(opts.regions), 320, 260, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    all_day_colors = f01_get_day_colors(max([opts.days(:); 5]));
    ax_handles = gobjects(1, numel(opts.regions));
    has_data = false(1, numel(opts.regions));

    for i_region = 1:numel(opts.regions)
        ax = nexttile(tl);
        ax_handles(i_region) = ax;
        hold(ax, 'on');

        region_name = opts.regions{i_region};
        if height(events_table) > 0 && ismember('region', events_table.Properties.VariableNames)
            region_events = events_table(strcmp(events_table.region, region_name), :);
        else
            region_events = events_table;
        end

        has_data(i_region) = f01_plot_event_days_on_axis(ax, region_events, opts.signal, ...
            opts.time_axis, opts.days, all_day_colors, opts.aggregate, true);

        xline(ax, 0, 'k:', 'LineWidth', 0.5);
        yline(ax, 0, 'k:', 'LineWidth', 0.25);
        xlim(ax, [opts.time_axis(1), opts.time_axis(end)]);
        xlabel(ax, 'Time (s)');
        ylabel(ax, opts.signal, 'Interpreter', 'none');
        title(ax, region_name, 'Interpreter', 'none');
        hold(ax, 'off');
    end

    f01_sync_shared_ylim(ax_handles, has_data);

    out = struct();
    out.time_axis = opts.time_axis;
    out.days = opts.days;
    out.regions = opts.regions;
    out.signal = opts.signal;
end

function has_data = f01_plot_event_days_on_axis(ax, events_subset, signal_name, time_axis, days, day_colors, aggregate_level, show_legend)
    has_data = false;
    legend_handles = gobjects(0);
    legend_labels = {};

    if height(events_subset) == 0 || ~ismember(signal_name, events_subset.Properties.VariableNames)
        text(ax, 0.5, 0.5, 'No data', 'Units', 'normalized', 'HorizontalAlignment', 'center');
        return;
    end

    for i_day = 1:numel(days)
        day_val = days(i_day);
        day_events = events_subset(events_subset.day == day_val, :);
        [mean_trace, sem_trace, n_groups] = f01_compute_trace_stats_for_aggregate( ...
            day_events, signal_name, aggregate_level);

        if isempty(mean_trace)
            continue;
        end

        if numel(mean_trace) ~= numel(time_axis)
            mean_trace = f01_interp_trace_to_time_axis(mean_trace, time_axis);
            sem_trace = f01_interp_trace_to_time_axis(sem_trace, time_axis);
        end

        h = f01_plot_shaded(ax, time_axis, mean_trace, sem_trace, day_colors(day_val, :), 0.10, 1.2);
        legend_handles(end + 1) = h;
        legend_labels{end + 1} = sprintf('D%d (n=%d)', day_val, n_groups);
        has_data = true;
    end

    if ~has_data
        text(ax, 0.5, 0.5, 'No data', 'Units', 'normalized', 'HorizontalAlignment', 'center');
        return;
    end

    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end
end

function trace_interp = f01_interp_trace_to_time_axis(trace_in, time_axis)
    trace_in = trace_in(:)';
    if numel(trace_in) == numel(time_axis)
        trace_interp = trace_in;
        return;
    end

    old_t = linspace(time_axis(1), time_axis(end), numel(trace_in));
    trace_interp = interp1(old_t, trace_in, time_axis, 'linear', 'extrap');
end

function day_colors = f01_get_day_colors(n_days)
    day_colors = cool(n_days);
    day_colors = 0.65 * day_colors + 0.35 * repmat([0.45 0.45 0.45], n_days, 1);
end

function f01_sync_shared_ylim(ax_pair, has_data)
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
