function [fig, out] = f01_helper_plot_event_psth_days_by_region(events_table, varargin)
% Plot day-colored PSTHs split by recording region.

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

    fill(ax, [x, fliplr(x)], [mean_y + sem_y, fliplr(mean_y - sem_y)], ...
        color, 'FaceAlpha', sem_alpha, 'EdgeColor', 'none');
    h = plot(ax, x, mean_y, 'Color', color, 'LineWidth', line_width);
end
