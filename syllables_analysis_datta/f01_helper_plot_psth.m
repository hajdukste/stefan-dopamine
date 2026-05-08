function [fig, axes_handles] = f01_helper_plot_psth(traces_table, plot_info, varargin)
% PLOT_PSTH Plot peri-stimulus time histogram from prepared data
%
% [fig, axes] = f01_helper_plot_psth(traces_table, plot_info, 'ylims', {[-1, 3]}, 'colors', [...])
%
% Parameters:
%   traces_table - Table from f01_helper_prepare_psth_data with trace data
%   plot_info    - Struct from f01_helper_prepare_psth_data with plotting metadata
%   'event_line'- Time point(s) for vertical event line (default: 0)
%   'xlim'      - X-axis limits [min max]
%   'ylims'     - Y-axis limits per signal (cell array or single [min max])
%   'colors'    - Custom color matrix (n_colors × 3)
%   'titles'    - Custom titles for facets (cell array)
%   'suptitle'  - Overall title for the entire figure (string)
%   'fig'       - Existing figure handle to plot into
%   'show_n'    - Show sample size in legends/titles (default: true)
%   'line_width'- Line width for mean traces (default: 1.5)
%   'sem_alpha' - Transparency for SEM shading (default: 0.2)
%   'individual_alpha' - Transparency for individual traces (default: 0.3)
%   'individual_width' - Line width for individual traces (default: 0.5)
%   'show_raster' - Show spike raster above PSTH (default: false)
%   'raster_height_ratio' - Height ratio of raster to PSTH (default: 0.4)
%   'spike_line_width' - Line width for spike ticks (default: 0.5)
%   'raster_trial_height' - Height of each trial in raster (default: 0.8)
%   'raster_color_by' - Color trials by: 'color_idx' or 'uniform' (default: 'color_idx')
%
% Output:
%   fig         - Figure handle
%   axes_handles - Matrix of axes handles

    %-------------------------------- Parse inputs
    p = inputParser;
    addParameter(p, 'event_line', 0);
    addParameter(p, 'xlim', []);
    addParameter(p, 'ylims', {});
    addParameter(p, 'colors', []);
    addParameter(p, 'titles', {});
    addParameter(p, 'suptitle', '');
    addParameter(p, 'fig', []);
    addParameter(p, 'show_n', true);
    addParameter(p, 'line_width', 1);
    addParameter(p, 'sem_alpha', 0.1);
    addParameter(p, 'individual_alpha', 0.3);
    addParameter(p, 'individual_width', 0.5);
    addParameter(p, 'ylabel', '');  % empty = use plot_info.ylabel if exists, else 'Value'
    addParameter(p, 'xlabel', '');  % empty = use plot_info.xlabel if exists, else 'Time (s)'
    addParameter(p, 'show_raster', false);
    addParameter(p, 'raster_height_ratio', 0.4);
    addParameter(p, 'spike_line_width', 0.5);
    addParameter(p, 'raster_trial_height', 0.8);
    addParameter(p, 'raster_color_by', 'color_idx');
    addParameter(p, 'x_reverse', false);  % reverse x-axis direction
    parse(p, varargin{:});
    opts = p.Results;

    % Use plot_info.ylabel if available and no explicit ylabel provided
    if isempty(opts.ylabel)
        if isfield(plot_info, 'ylabel') && ~isempty(plot_info.ylabel)
            opts.ylabel = plot_info.ylabel;
        else
            opts.ylabel = 'Value';
        end
    end

    % Use plot_info.xlabel if available and no explicit xlabel provided
    if isempty(opts.xlabel)
        if isfield(plot_info, 'xlabel') && ~isempty(plot_info.xlabel)
            opts.xlabel = plot_info.xlabel;
        else
            opts.xlabel = 'Time (s)';
        end
    end

    if isfield(plot_info, 'xlim') && ~isempty(plot_info.xlim)
        opts.xlim = plot_info.xlim;
    end

    % If xlim still empty, use time_axis range
    if isempty(opts.xlim) && isfield(plot_info, 'time_axis')
        opts.xlim = [min(plot_info.time_axis), max(plot_info.time_axis)];
    end

    %-------------------------------- Extract from plot_info
    time_axis = plot_info.time_axis;
    signals = plot_info.signals;
    facet_labels = plot_info.facet_labels;
    color_labels = plot_info.color_labels;
    n_rows_data = plot_info.n_rows;
    n_cols = plot_info.n_cols;

    n_facets = max(traces_table.facet_idx);
    n_colors = max(traces_table.color_idx);
    n_signals = length(signals);

    overlay_signals = strcmp(plot_info.signal_layout, 'overlay');
    tiles_signals = strcmp(plot_info.signal_layout, 'tiles');
    aggregate_mode = plot_info.aggregate;

    % Helper to get trace data from table
    get_trace = @(i_facet, i_color, i_signal) get_trace_from_table(traces_table, i_facet, i_color, i_signal);

    %-------------------------------- Validate raster parameters
    if opts.show_raster
        has_spike_data = ismember('spike_times_per_trial', traces_table.Properties.VariableNames) && ...
                         any(cellfun(@(x) ~isempty(x) && iscell(x), traces_table.spike_times_per_trial));
        if ~has_spike_data
            warning('show_raster=true but no spike data found in traces_table');
            opts.show_raster = false;
        end
    end

    %-------------------------------- Determine plot layout
    if overlay_signals
        % Signals as colors, ignore color variable
        total_rows = n_rows_data;
        total_cols = n_cols;
        n_color_lines = n_signals;
    elseif tiles_signals
        % Signals as separate tiles in a grid (only when no facet)
        total_cols = ceil(sqrt(n_signals));
        total_rows = ceil(n_signals / total_cols);
        n_color_lines = n_colors;
    else
        % Signals as separate rows
        total_rows = n_signals * n_rows_data;
        total_cols = n_cols;
        n_color_lines = n_colors;
    end

    %-------------------------------- Default colors
    if isempty(opts.colors)
        if n_color_lines <= 7
            opts.colors = lines(n_color_lines);
        else
            opts.colors = turbo(n_color_lines);
        end
    end

    %-------------------------------- Create figure
    if isempty(opts.fig)
        [fig, tl] = myFigure(total_rows, total_cols, 320, 260);
    else
        fig = opts.fig;
        figure(fig);
        tl = tiledlayout(total_rows, total_cols, 'TileSpacing', 'compact', 'Padding', 'compact');
    end
    axes_handles = gobjects(total_rows, total_cols);

    % Set overall figure title
    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    %-------------------------------- Storage for smart legend placement
    legend_info = cell(total_rows, n_cols);  % {handles, labels} per tile

    %-------------------------------- Plot
    if overlay_signals
        % OVERLAY MODE: signals as different colors in same tile
        for i_facet = 1:n_facets
            % Compute tile position
            if n_rows_data == 1
                tile_row = 1;
                tile_col = i_facet;
            else
                tile_row = floor((i_facet - 1) / n_cols) + 1;
                tile_col = mod(i_facet - 1, n_cols) + 1;
            end
            tile_idx = (tile_row - 1) * n_cols + tile_col;

            ax = nexttile(tl, tile_idx);
            axes_handles(tile_row, tile_col) = ax;
            hold(ax, 'on');

            legend_handles = gobjects(n_signals, 1);
            legend_labels_used = {};

            % Plot each signal as different color
            for i_signal = 1:n_signals
                trace_data = get_trace(i_facet, 1, i_signal);  % color=1 for overlay mode

                if isempty(trace_data)
                    continue;
                end

                signal_name = signals{i_signal};
                color = opts.colors(i_signal, :);

                % Plot individual traces (if available)
                if ~isempty(trace_data.individual_traces)
                    plot_individual_traces(ax, time_axis, trace_data.individual_traces, ...
                        color, opts.individual_alpha, opts.individual_width);
                end

                % Plot mean + SEM (unless aggregate='none')
                if ~strcmp(aggregate_mode, 'none')
                    h = plot_shaded(ax, time_axis, trace_data.mean_trace, trace_data.sem_trace, ...
                        color, opts.sem_alpha, opts.line_width);
                    legend_handles(i_signal) = h;
                    n = trace_data.n_agg;
                else
                    % Create invisible line for legend when no mean trace
                    h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', opts.line_width);
                    legend_handles(i_signal) = h;
                    n = trace_data.n_events;
                end

                if opts.show_n
                    legend_labels_used{end+1} = sprintf('%s (n=%d)', signal_name, n);
                else
                    legend_labels_used{end+1} = signal_name;
                end
            end

            % Plot raster if requested
            if opts.show_raster
                % Find first signal with spike data
                for i_signal = 1:n_signals
                    trace_data = get_trace(i_facet, 1, i_signal);
                    if isempty(trace_data) || isempty(trace_data.spike_times_per_trial)
                        continue;
                    end

                    spike_times = trace_data.spike_times_per_trial;
                    if ~iscell(spike_times) || isempty(spike_times)
                        continue;
                    end

                    % Compute layout
                    current_ylim = ylim(ax);
                    n_trials = length(spike_times);
                    [y_lim_new, y_raster_range, adjusted_height] = compute_raster_layout(...
                        current_ylim, n_trials, opts.raster_trial_height);

                    % Create color index for trials (all same color in overlay mode)
                    trial_color_idx = ones(n_trials, 1) * i_signal;

                    % Plot raster
                    plot_raster_on_axes(ax, spike_times, opts.xlim, y_raster_range(1), ...
                        adjusted_height, opts.colors, trial_color_idx, opts.spike_line_width);

                    % Adjust y-limits
                    ylim(ax, y_lim_new);

                    % Only plot raster for first signal with spike data
                    break;
                end
            end

            % Event line and zero line
            if ~isempty(opts.event_line)
                for ev = opts.event_line(:)'
                    xline(ax, ev, 'k:', 'LineWidth', 0.5);
                end
            end
            yline(ax, 0, 'k:', 'LineWidth', 0.25);
            draw_window_shading(ax, plot_info);

            % Title
            if ~isempty(opts.titles) && i_facet <= length(opts.titles)
                title_str = opts.titles{i_facet};
            else
                title_str = facet_labels{i_facet};
            end
            title(ax, title_str, 'FontWeight', 'normal', 'Interpreter', 'none');

            % Labels
            ylabel(ax, opts.ylabel);
            xlabel(ax, opts.xlabel);

            % Axis limits
            if ~isempty(opts.ylims)
                ylim(ax, opts.ylims);
            end
            if ~isempty(opts.xlim)
                xlim(ax, opts.xlim);
            end
            if opts.x_reverse
                set(ax, 'XDir', 'reverse');
            end

            % Store legend info for smart placement later
            if n_signals > 1 && ~isempty(legend_handles)
                legend_info{tile_row, tile_col} = {legend_handles, legend_labels_used};
            end
        end
    elseif tiles_signals
        % TILES MODE: each signal gets its own tile in a grid
        for i_signal = 1:n_signals
            signal_name = signals{i_signal};

            % Compute tile position in grid
            tile_row = floor((i_signal - 1) / total_cols) + 1;
            tile_col = mod(i_signal - 1, total_cols) + 1;
            tile_idx = (tile_row - 1) * total_cols + tile_col;

            ax = nexttile(tl, tile_idx);
            axes_handles(tile_row, tile_col) = ax;
            hold(ax, 'on');

            legend_handles = [];
            legend_labels_used = {};

            % Plot each color group (use facet=1 since no faceting in tiles mode)
            for i_color = 1:n_colors
                trace_data = get_trace(1, i_color, i_signal);

                if isempty(trace_data)
                    continue;
                end

                color = opts.colors(i_color, :);

                % Plot individual traces (if available)
                if ~isempty(trace_data.individual_traces)
                    plot_individual_traces(ax, time_axis, trace_data.individual_traces, ...
                        color, opts.individual_alpha, opts.individual_width);
                end

                % Plot mean + SEM (unless aggregate='none')
                if ~strcmp(aggregate_mode, 'none')
                    h = plot_shaded(ax, time_axis, trace_data.mean_trace, trace_data.sem_trace, ...
                        color, opts.sem_alpha, opts.line_width);
                    legend_handles(end+1) = h;
                    n = trace_data.n_agg;
                else
                    h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', opts.line_width);
                    legend_handles(end+1) = h;
                    n = trace_data.n_events;
                end

                if opts.show_n && n_colors > 1
                    legend_labels_used{end+1} = sprintf('%s (n=%d)', color_labels{i_color}, n);
                elseif n_colors > 1
                    legend_labels_used{end+1} = color_labels{i_color};
                end
            end

            % Plot raster if requested
            if opts.show_raster
                % Collect spike data from all color groups
                all_spike_times = {};
                all_color_idx = [];

                for i_color = 1:n_colors
                    trace_data = get_trace(1, i_color, i_signal);
                    if isempty(trace_data) || isempty(trace_data.spike_times_per_trial)
                        continue;
                    end

                    spike_times = trace_data.spike_times_per_trial;
                    if ~iscell(spike_times) || isempty(spike_times)
                        continue;
                    end

                    n_trials_this_color = length(spike_times);
                    all_spike_times = [all_spike_times; spike_times];
                    all_color_idx = [all_color_idx; ones(n_trials_this_color, 1) * i_color];
                end

                if ~isempty(all_spike_times)
                    % Compute layout
                    current_ylim = ax.YLim;
                    n_trials = length(all_spike_times);
                    [y_lim_new, y_raster_range, adjusted_height] = compute_raster_layout(...
                        current_ylim, n_trials, opts.raster_trial_height);

                    % Plot raster
                    plot_raster_on_axes(ax, all_spike_times, opts.xlim, y_raster_range(1), ...
                        adjusted_height, opts.colors, all_color_idx, opts.spike_line_width);

                    % Adjust y-limits
                    ylim(ax, y_lim_new);
                end
            end

            % Event line and zero line
            if ~isempty(opts.event_line)
                for ev = opts.event_line(:)'
                    xline(ax, ev, 'k:', 'LineWidth', 0.5);
                end
            end
            yline(ax, 0, 'k:', 'LineWidth', 0.25);
            draw_window_shading(ax, plot_info);

            % Title with signal name, n, and xcorr peak diff if available
            title_str = signal_name;
            if n_colors == 1 && opts.show_n
                trace_data = get_trace(1, 1, i_signal);
                if ~isempty(trace_data)
                    if strcmp(aggregate_mode, 'none')
                        n = trace_data.n_events;
                    else
                        n = trace_data.n_agg;
                    end
                    title_str = sprintf('%s (n=%d)', signal_name, n);
                end
            end
            % Add xcorr peak diff to title if available
            if isfield(plot_info, 'xcorr_peak_diff') && i_signal <= length(plot_info.xcorr_peak_diff)
                peak_diff = plot_info.xcorr_peak_diff{i_signal};
                if ~any(isnan(peak_diff))
                    title_str = sprintf('%s  d: [%.2f, %.2f]', title_str, peak_diff(1), peak_diff(2));
                end
            end
            % Add shuffle stats (mean_group1 - mean_group2 (diff), p_value) if available
            if isfield(plot_info, 'shuffle_stats') && i_signal <= height(plot_info.shuffle_stats)
                ss = plot_info.shuffle_stats(i_signal, :);
                % title_str = sprintf('%s  obs: %.1f - %.1f (%.1f) p:%.2f', title_str, ...
                %     ss.mean_group1, ss.mean_group2, ss.observed_diff, ss.p_value);
                if isfield(ss, 'p_value')
                    title_str = sprintf('%s  p:%.2f', title_str, ss.p_value);
                else
                    title_str = sprintf('%s  p:%.2f', title_str, ss.p_interaction);
                end
            end
            title(ax, title_str, 'FontWeight', 'normal', 'Interpreter', 'none');

            % Labels
            ylabel(ax, opts.ylabel);
            xlabel(ax, opts.xlabel);

            % Axis limits
            if ~isempty(opts.ylims)
                if iscell(opts.ylims) && length(opts.ylims) >= i_signal
                    ylim(ax, opts.ylims{i_signal});
                elseif ~iscell(opts.ylims)
                    ylim(ax, opts.ylims);
                end
            end
            if ~isempty(opts.xlim)
                xlim(ax, opts.xlim);
            end
            if opts.x_reverse
                set(ax, 'XDir', 'reverse');
            end

            % Store legend info
            if n_colors > 1 && ~isempty(legend_handles)
                legend_info{tile_row, tile_col} = {legend_handles, legend_labels_used};
            end
        end
    else
        % ROWS MODE: each signal gets its own row(s)
        for i_signal = 1:n_signals
            signal_name = signals{i_signal};

            for i_facet = 1:n_facets
                % Compute tile position
                if n_rows_data == 1
                    tile_row = i_signal;
                    tile_col = i_facet;
                else
                    facet_row = floor((i_facet - 1) / n_cols) + 1;
                    facet_col = mod(i_facet - 1, n_cols) + 1;
                    tile_row = (i_signal - 1) * n_rows_data + facet_row;
                    tile_col = facet_col;
                end
                tile_idx = (tile_row - 1) * total_cols + tile_col;

                ax = nexttile(tl, tile_idx);
                axes_handles(tile_row, tile_col) = ax;
                hold(ax, 'on');

                legend_handles = [];
                legend_labels_used = {};

                % Plot each color group
                for i_color = 1:n_colors
                    trace_data = get_trace(i_facet, i_color, i_signal);

                    if isempty(trace_data)
                        continue;
                    end

                    color = opts.colors(i_color, :);

                    % Plot individual traces (if available)
                    if ~isempty(trace_data.individual_traces)
                        plot_individual_traces(ax, time_axis, trace_data.individual_traces, ...
                            color, opts.individual_alpha, opts.individual_width);
                    end

                    % Plot mean + SEM (unless aggregate='none')
                    if ~strcmp(aggregate_mode, 'none')
                        h = plot_shaded(ax, time_axis, trace_data.mean_trace, trace_data.sem_trace, ...
                            color, opts.sem_alpha, opts.line_width);
                        legend_handles(end+1) = h;
                        n = trace_data.n_agg;
                    else
                        % Create invisible line for legend when no mean trace
                        h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', opts.line_width);
                        legend_handles(end+1) = h;
                        n = trace_data.n_events;
                    end

                    if opts.show_n && n_colors > 1
                        legend_labels_used{end+1} = sprintf('%s (n=%d)', color_labels{i_color}, n);
                    elseif n_colors > 1
                        legend_labels_used{end+1} = color_labels{i_color};
                    end
                end

                % Plot raster if requested
                if opts.show_raster
                    % Collect spike data from all color groups for this facet/signal
                    all_spike_times = {};
                    all_color_idx = [];

                    for i_color = 1:n_colors
                        trace_data = get_trace(i_facet, i_color, i_signal);
                        if isempty(trace_data) || isempty(trace_data.spike_times_per_trial)
                            continue;
                        end

                        spike_times = trace_data.spike_times_per_trial;
                        if ~iscell(spike_times) || isempty(spike_times)
                            continue;
                        end

                        n_trials_this_color = length(spike_times);
                        all_spike_times = [all_spike_times; spike_times];
                        all_color_idx = [all_color_idx; ones(n_trials_this_color, 1) * i_color];
                    end

                    if ~isempty(all_spike_times)
                        % Compute layout
                        current_ylim = ax.YLim;
                        n_trials = length(all_spike_times);
                        [y_lim_new, y_raster_range, adjusted_height] = compute_raster_layout(...
                            current_ylim, n_trials, opts.raster_trial_height);

                        % Plot raster
                        plot_raster_on_axes(ax, all_spike_times, opts.xlim, y_raster_range(1), ...
                            adjusted_height, opts.colors, all_color_idx, opts.spike_line_width);

                        % Adjust y-limits
                        ylim(ax, y_lim_new);
                    end
                end

                % Event line and zero line
                if ~isempty(opts.event_line)
                    for ev = opts.event_line(:)'
                        xline(ax, ev, 'k:', 'LineWidth', 0.5);
                    end
                end
                yline(ax, 0, 'k:', 'LineWidth', 0.25);
                draw_window_shading(ax, plot_info);

                % Title (first signal row only)
                if i_signal == 1
                    if ~isempty(opts.titles) && i_facet <= length(opts.titles)
                        title_str = opts.titles{i_facet};
                    else
                        title_str = facet_labels{i_facet};
                    end

                    % Add n if single color group
                    if n_colors == 1 && opts.show_n
                        trace_data = get_trace(i_facet, 1, i_signal);
                        if ~isempty(trace_data)
                            if strcmp(aggregate_mode, 'none')
                                n = trace_data.n_events;
                            else
                                n = trace_data.n_agg;
                            end
                            if ~isempty(title_str)
                                title_str = sprintf('%s (n=%d)', title_str, n);
                            else
                                title_str = sprintf('n=%d', n);
                            end
                        end
                    end
                    title(ax, title_str, 'FontWeight', 'normal', 'Interpreter', 'none');
                end

                % Y label (append shuffle p-value for unit signals)
                y_label_str = signal_name;
                if i_facet == 1 && isfield(plot_info, 'shuffle_stats') && ...
                        startsWith(signal_name, 'unit_') && i_signal <= height(plot_info.shuffle_stats)
                    ss = plot_info.shuffle_stats(i_signal, :);
                    if isfield(ss, 'p_value')
                        y_label_str = sprintf('%s  p:%.2f', y_label_str, ss.p_value);
                    else
                        y_label_str = sprintf('%s  p:%.2f', y_label_str, ss.p_interaction);
                    end
                end
                ylabel(ax, y_label_str, 'Interpreter', 'none');

                % X label
                xlabel(ax, opts.xlabel);

                % Axis limits
                if ~isempty(opts.ylims)
                    if iscell(opts.ylims) && length(opts.ylims) >= i_signal
                        ylim(ax, opts.ylims{i_signal});
                    elseif ~iscell(opts.ylims)
                        ylim(ax, opts.ylims);
                    end
                end
                if ~isempty(opts.xlim)
                    xlim(ax, opts.xlim);
                end
                if opts.x_reverse
                    set(ax, 'XDir', 'reverse');
                end

                % Store legend info for smart placement later
                if n_colors > 1 && ~isempty(legend_handles)
                    legend_info{tile_row, tile_col} = {legend_handles, legend_labels_used};
                end
            end
        end
    end

    %-------------------------------- Smart legend placement
    place_legends_smart(axes_handles, legend_info);
    % saveImage(fig, mfilename);
end

%-------------------------------- Helper functions

function plot_raster_on_axes(ax, spike_times_per_trial, x_lim, y_base, trial_height, colors, trial_color_idx, line_width)
    % Plot spike raster for trials above PSTH trace
    % ax: axes handle
    % spike_times_per_trial: {n_trials × 1} cell of spike time vectors
    % x_lim: [min max] time window for filtering spikes
    % y_base: Y-coordinate for bottom of raster
    % trial_height: Height of each trial tick
    % colors: Color matrix (n_colors × 3)
    % trial_color_idx: Color index for each trial (n_trials × 1)
    % line_width: Width of spike ticks

    n_trials = length(spike_times_per_trial);
    if n_trials == 0
        return;
    end

    hold(ax, 'on');

    for i_trial = 1:n_trials
        spk_times = spike_times_per_trial{i_trial};

        if isempty(spk_times)
            continue;
        end

        % Filter spikes within time window
        in_window = spk_times >= x_lim(1) & spk_times <= x_lim(2);
        spk_times = spk_times(in_window);

        if isempty(spk_times)
            continue;
        end

        % Y position for this trial
        % Center of trial i should be at: y_base + (i - 0.5) * trial_height
        % This makes trial 1 start at y_base, trial n end at y_base + n*trial_height
        y_trial = y_base + (i_trial - 0.5) * trial_height;

        % Get color for this trial
        color = colors(trial_color_idx(i_trial), :);

        % Plot vertical lines for each spike
        x_lines = [spk_times(:)'; spk_times(:)'];
        y_half_height = trial_height / 2;
        y_lines = [(y_trial - y_half_height) * ones(1, length(spk_times)); ...
                   (y_trial + y_half_height) * ones(1, length(spk_times))];

        line(ax, x_lines, y_lines, 'Color', color, 'LineWidth', line_width);
    end
end

function [y_lim_combined, y_raster_range, adjusted_trial_height] = compute_raster_layout(current_ylim, n_trials, trial_height)
    % Compute y-axis layout for PSTH + raster (50/50 split)
    % Returns adjusted trial_height to fit all trials in fixed raster space
    %
    % current_ylim: [ymin ymax] current axes y-limits
    % n_trials: Total number of trials
    % trial_height: Height per trial (ignored, computed dynamically)
    %
    % Returns:
    % y_lim_combined: [ymin_new ymax_new] new y-limits to accommodate raster
    % y_raster_range: [y_base y_top] y-coordinate range for raster
    % adjusted_trial_height: Dynamically computed trial height

    psth_ymin = current_ylim(1);
    psth_ymax = current_ylim(2);
    psth_range = psth_ymax - psth_ymin;

    % Small gap between PSTH and raster (5 percent of PSTH range)
    gap = psth_range * 0.05;

    % Raster takes same height as PSTH (50/50 split)
    raster_height = psth_range;

    % Adjust trial height to fit all trials in fixed raster space
    if n_trials > 0
        adjusted_trial_height = raster_height / n_trials;
    else
        adjusted_trial_height = trial_height;  % Fallback (shouldn't happen)
    end

    % Raster y-range (always uses full raster_height)
    y_raster_base = psth_ymax + gap;
    y_raster_top = y_raster_base + raster_height;

    % Combined y-limits (5 percent margin at top)
    y_lim_combined = [psth_ymin, y_raster_top * 1.05];
    y_raster_range = [y_raster_base, y_raster_top];
end

function plot_individual_traces(ax, x, traces, color, sem_alpha, line_width)
    % Plot individual traces as thin semi-transparent lines
    x = x(:)';
    n_traces = size(traces, 1);

    for i = 1:n_traces
        y = traces(i, :);
        plot(ax, x, y, 'Color', [color, sem_alpha], 'LineWidth', line_width);
    end
end

function h = plot_shaded(ax, x, mean_y, sem_y, color, sem_alpha, line_width)
    % Plot shaded error region + mean line
    x = x(:)';
    mean_y = mean_y(:)';
    sem_y = sem_y(:)';

    upper = mean_y + sem_y;
    lower = mean_y - sem_y;

    % Remove NaN segments for clean fill
    valid = ~isnan(mean_y) & ~isnan(sem_y);
    if ~all(valid)
        x = x(valid);
        mean_y = mean_y(valid);
        upper = upper(valid);
        lower = lower(valid);
    end

    fill(ax, [x, fliplr(x)], [upper, fliplr(lower)], ...
        color, 'FaceAlpha', sem_alpha, 'EdgeColor', 'none');
    h = plot(ax, x, mean_y, 'Color', color, 'LineWidth', line_width);
end

function place_legends_smart(axes_handles, legend_info)
    % Analyze legend patterns and place legends only where needed
    % - All same: show on first tile only
    % - Same within rows: show once per row (first column)
    % - Same within columns: show once per column (first row)
    % - All different: show on all tiles

    [n_rows, n_cols] = size(legend_info);

    % Find tiles that have legend info
    has_legend = ~cellfun(@isempty, legend_info);
    if ~any(has_legend(:))
        return;
    end

    % Convert labels to string for comparison
    label_strings = cell(n_rows, n_cols);
    for r = 1:n_rows
        for c = 1:n_cols
            if has_legend(r, c)
                label_strings{r, c} = strjoin(legend_info{r, c}{2}, '|');
            else
                label_strings{r, c} = '';
            end
        end
    end

    % Check if all legends are identical
    non_empty_labels = label_strings(has_legend);
    all_same = all(strcmp(non_empty_labels, non_empty_labels{1}));

    if all_same
        % Show legend only on first tile that has one
        [r, c] = find(has_legend, 1, 'first');
        show_legend_on_tile(axes_handles, legend_info, r, c);
        return;
    end

    % Check if legends are same within each row (vary by row only)
    same_within_rows = true;
    for r = 1:n_rows
        row_labels = label_strings(r, has_legend(r, :));
        if ~isempty(row_labels) && ~all(strcmp(row_labels, row_labels{1}))
            same_within_rows = false;
            break;
        end
    end

    % Check if legends are same within each column (vary by column only)
    same_within_cols = true;
    for c = 1:n_cols
        col_labels = label_strings(has_legend(:, c), c);
        if ~isempty(col_labels) && ~all(strcmp(col_labels, col_labels{1}))
            same_within_cols = false;
            break;
        end
    end

    if same_within_rows && ~same_within_cols
        % Legends vary by row only - show once per row (first column with legend)
        for r = 1:n_rows
            c = find(has_legend(r, :), 1, 'first');
            if ~isempty(c)
                show_legend_on_tile(axes_handles, legend_info, r, c);
            end
        end
    elseif same_within_cols && ~same_within_rows
        % Legends vary by column only - show once per column (first row with legend)
        for c = 1:n_cols
            r = find(has_legend(:, c), 1, 'first');
            if ~isempty(r)
                show_legend_on_tile(axes_handles, legend_info, r, c);
            end
        end
    else
        % Legends vary by both row and column - show on all tiles
        for r = 1:n_rows
            for c = 1:n_cols
                if has_legend(r, c)
                    show_legend_on_tile(axes_handles, legend_info, r, c);
                end
            end
        end
    end
end

function show_legend_on_tile(axes_handles, legend_info, r, c)
    ax = axes_handles(r, c);
    handles = legend_info{r, c}{1};
    labels = legend_info{r, c}{2};
    legend(ax, handles, labels, 'Location', 'best', 'FontSize', 8, 'Interpreter', 'none');
end

function trace_data = get_trace_from_table(traces_table, i_facet, i_color, i_signal)
    % Find row matching the indices
    mask = traces_table.facet_idx == i_facet & ...
           traces_table.color_idx == i_color & ...
           traces_table.signal_idx == i_signal;

    if ~any(mask)
        trace_data = [];
        return;
    end

    row = traces_table(mask, :);
    trace_data = struct();
    trace_data.mean_trace = row.mean_trace{1};
    trace_data.sem_trace = row.sem_trace{1};
    trace_data.individual_traces = row.individual_traces{1};
    trace_data.n_agg = row.n_agg;
    trace_data.n_events = row.n_events;

    % Add spike times if available
    if ismember('spike_times_per_trial', traces_table.Properties.VariableNames)
        trace_data.spike_times_per_trial = row.spike_times_per_trial{1};
    else
        trace_data.spike_times_per_trial = {};
    end
end

function draw_window_shading(ax, plot_info)
    if ~isfield(plot_info, 'window_before') || ~isfield(plot_info, 'window_after')
        return;
    end
    yl = ylim(ax);
    windows = {plot_info.window_before, plot_info.window_after};
    for i = 1:2
        w = windows{i};
        fill(ax, [w(1) w(2) w(2) w(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.4, 'HandleVisibility', 'off');
    end
    uistack(findobj(ax, 'Type', 'patch'), 'bottom');
end
