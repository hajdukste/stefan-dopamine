function fig = f01_plot_syllable_psth_summary(all_data, varargin)
% F01_PLOT_SYLLABLE_PSTH_SUMMARY Plot multi-panel summary for syllables
%
% fig = f01_plot_syllable_psth_summary(all_data)
% fig = f01_plot_syllable_psth_summary(all_data, 'syllables', sorted_syllables(1:10))
% fig = f01_plot_syllable_psth_summary(all_data, 'panels', {'fip_psth', 'speed_psth', 'bout_hist'})
% fig = f01_plot_syllable_psth_summary(all_data, 'signal_layout', 'tiles', 'show_individual', true)
%
% Parameters:
%   all_data        - Data struct from a00_load_data pipeline
%   'syllables'     - Vector of syllable IDs to plot (default: sorted_syllables(1:20))
%   'panels'        - Cell array of panel types to show (default: all)
%                     Options: 'fip_psth', 'fip_psth_days', 'speed_psth',
%                     'speed_psth_days', 'bout_hist', 'daily_counts',
%                     'fa_counts', 'trajectory'
%   'signal_layout' - 'rows' forces one syllable per row (default)
%                     'tiles' uses a square-ish grid with panels grouped
%                     per syllable and alternating gray/white backgrounds
%   'show_individual' - Individual trace level: 'none', 'event', 'animal', 'session'
%                       'none': no individual traces (default)
%                       'event': show all individual event traces
%                       'animal': show average per animal
%                       'session': show average per session (animal+day)
%   'psth_aggregate' - Level for plotted PSTH mean/SEM: 'event', 'animal',
%                      or 'session' (default: 'event')
%   'suptitle'      - Overall figure title (default: '')
%   't_before'      - Samples before event for PSTH (default: 60 = ~2s at 30Hz)
%   't_after'       - Samples after event for PSTH (default: 60 = ~2s at 30Hz)
%   'fs'            - Sampling rate in Hz (default: 30)
%   'skip_animals_days' - [animal, day] pairs to skip (default: [0 0])
%   'trajectory_png_path' - Path to trajectory PNGs (default: kpms/trajectory_plots/pngs)

    p = inputParser;
    addParameter(p, 'syllables', []);
    addParameter(p, 'panels', {'fip_psth', 'bout_hist', 'daily_counts', 'fa_counts'});
    addParameter(p, 'signal_layout', 'rows');
    addParameter(p, 'show_individual', 'none');
    addParameter(p, 'psth_aggregate', 'event');
    addParameter(p, 'suptitle', '');
    addParameter(p, 't_before', 120);
    addParameter(p, 't_after', 120);
    addParameter(p, 'fs', 60);
    addParameter(p, 'skip_animals_days', [0 0]);
    addParameter(p, 'trajectory_png_path', '/Users/stefan/Downloads/berkeley_collab/kpms/trajectory_plots/pngs_cropped');
    parse(p, varargin{:});
    opts = p.Results;

    % Get syllables from workspace if not provided
    if isempty(opts.syllables)
        opts.syllables = evalin('base', 'sorted_syllables(1:20)');
    end
    syllables = opts.syllables;
    n_syllables = length(syllables);

    % Get cmap25 from workspace
    cmap25 = evalin('base', 'cmap25');
    sorted_syllables = evalin('base', 'sorted_syllables');

    panels = opts.panels;
    skip_animals_days = opts.skip_animals_days;

    % Expand panel_cols (some requested panels occupy multiple tiles)
    panel_cols = {};
    for k = 1:length(panels)
        switch panels{k}
            case 'fip_psth_days'
                panel_cols{end+1} = 'fip_psth_days_NAcMed';
                panel_cols{end+1} = 'fip_psth_days_NAcLat';
            case 'speed_psth_days'
                panel_cols{end+1} = 'speed_psth_days_NAcMed';
                panel_cols{end+1} = 'speed_psth_days_NAcLat';
            otherwise
                panel_cols{end+1} = panels{k};
        end
    end

    n_cols = length(panel_cols);
    n_animals = length(all_data);
    n_days = 5;

    % Panel labels for titles
    panel_labels = struct(...
        'fip_psth', 'FIP', ...
        'fip_psth_days_NAcMed', 'FIP Days Med', ...
        'fip_psth_days_NAcLat', 'FIP Days Lat', ...
        'speed_psth', 'Speed', ...
        'speed_psth_days_NAcMed', 'Speed Days Med', ...
        'speed_psth_days_NAcLat', 'Speed Days Lat', ...
        'bout_hist', 'Bout Len', ...
        'daily_counts', 'Daily', ...
        'fa_counts', 'Final App', ...
        'trajectory', 'Traj');

    % Colors
    bg_colors = [1 1 1; 0.95 0.95 0.95];

    region_colors = struct();
    region_colors.NAcLat = [17 113 190] / 255;
    region_colors.NAcMed = [221 84 0] / 255;

    animal_colors = [
        0.18 0.18 0.18;   % dark gray
        0.34 0.34 0.34;   % gray
        0.50 0.50 0.50;   % mid gray
        0.66 0.66 0.66;   % light gray
        0.82 0.82 0.82;   % pale gray
        0.20 0.48 0.52;   % muted teal accent
    ];

    mean_color = [0.1 0.3 0.7];
    sem_color = [0.5 0.6 0.9];
    indiv_color = [0.7 0.7 0.7];

    %----------------------------------------------------------------------
    % Pre-compute bout statistics
    %----------------------------------------------------------------------
    fprintf('Pre-computing bout statistics...\n');

    bout_lengths = cell(n_syllables, 1);
    bout_counts = zeros(n_syllables, n_days, n_animals);
    bout_counts_fa = zeros(n_syllables, n_days, n_animals);

    for animal = 1:n_animals
        for day = 1:n_days
            if ismember([animal, day], skip_animals_days, 'rows'); continue; end
            if day > length(all_data(animal).data); continue; end

            d = all_data(animal).data(day).d;
            if isempty(d); continue; end
            if ~ismember('syllable', d.Properties.VariableNames); continue; end

            syl_data = d.syllable;
            n_frames = height(d);

            % Detect syllable bouts
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; n_frames];
            run_syllables = syl_data(run_starts);
            run_lengths_frames = run_ends - run_starts + 1;

            has_fa = ismember('final_approach', d.Properties.VariableNames);

            for i_syl = 1:n_syllables
                syl = syllables(i_syl);
                bout_mask = run_syllables == syl;

                if ~any(bout_mask); continue; end

                lengths = run_lengths_frames(bout_mask);
                bout_lengths{i_syl} = [bout_lengths{i_syl}; lengths];
                bout_counts(i_syl, day, animal) = sum(bout_mask);

                if has_fa
                    bout_starts = run_starts(bout_mask);
                    fa_mask = d.final_approach(bout_starts);
                    bout_counts_fa(i_syl, day, animal) = sum(fa_mask);
                end
            end
        end
    end

    % Convert bout lengths from frames to seconds
    for i_syl = 1:n_syllables
        bout_lengths{i_syl} = bout_lengths{i_syl} / opts.fs;
    end

    % Shared histogram bin edges (in seconds)
    all_lengths = vertcat(bout_lengths{:});
    if ~isempty(all_lengths)
        max_len = prctile(all_lengths, 95);
        bin_edges = linspace(0, max_len, 21);
    else
        bin_edges = linspace(0, 3, 21);  % default 0-3 seconds
        max_len = 3;
    end
    fprintf('Bout statistics computed. Max length (95th pctl): %.2f s\n', max_len);

    %----------------------------------------------------------------------
    % Get syllable onset events for PSTH
    %----------------------------------------------------------------------
    fprintf('Extracting syllable onset events...\n');

    % time_axis in seconds, matching number of samples
    n_samples = opts.t_before + opts.t_after + 1;
    time_axis = linspace(-opts.t_before/opts.fs, opts.t_after/opts.fs, n_samples);

    config_syl = struct();
    config_syl.align = struct('t_before', opts.t_before, 't_after', opts.t_after, ...
        'trace_types', {{'zsc_exp', 'speed'}});

    events_table = f01_helper_get_syllable_onset_events(all_data, config_syl, skip_animals_days, syllables);
    fprintf('Total events: %d\n', height(events_table));

    %----------------------------------------------------------------------
    % Create figure
    %----------------------------------------------------------------------
    use_tiles = strcmp(opts.signal_layout, 'tiles');

    if use_tiles
        tiles_per_group = n_cols;
        n_tiles = n_syllables * tiles_per_group;
        ideal_cols = ceil(sqrt(n_tiles));
        grid_cols = round(ideal_cols / tiles_per_group) * tiles_per_group;
        grid_cols = max(grid_cols, tiles_per_group);
        grid_rows = ceil(n_tiles / grid_cols);
        syllables_per_row = grid_cols / n_cols;
        [fig, tl] = myFigure(grid_rows, grid_cols, 300, 250, true);
    else
        grid_rows = n_syllables;
        syllables_per_row = 1;
        [fig, tl] = myFigure(n_syllables, n_cols, 300, 250, true);
    end

    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';

    if ~isempty(opts.suptitle)
        title(tl, opts.suptitle, 'Interpreter', 'none');
    end

    %----------------------------------------------------------------------
    % Plot each syllable
    %----------------------------------------------------------------------
    for i_syl = 1:n_syllables
        syl = syllables(i_syl);
        syl_rank = find(sorted_syllables == syl, 1);
        if ~isempty(syl_rank) && syl_rank <= size(cmap25, 1)
            syl_color = cmap25(syl_rank, :);
        else
            syl_color = cmap25(min(i_syl, size(cmap25, 1)), :);
        end
        bg_idx = mod(i_syl - 1, 2) + 1;

        % Filter events for this syllable
        syl_mask = events_table.syllable == syl;
        syl_events = events_table(syl_mask, :);

        % For tiles mode: column-major ordering (fill columns first, then next column group)
        % For rows mode: row-major ordering (one syllable per row)
        if use_tiles
            col_group = floor((i_syl - 1) / grid_rows);  % which column group (0-indexed)
            row_in_group = mod(i_syl - 1, grid_rows) + 1;  % which row (1-indexed)
            is_first_row = row_in_group == 1;
            is_last_row = row_in_group == grid_rows;
        else
            row_in_group = i_syl;
            col_group = 0;
            is_first_row = i_syl == 1;
            is_last_row = i_syl == n_syllables;
        end

        shared_day_axes = struct( ...
            'fip', gobjects(1, 2), ...
            'speed', gobjects(1, 2));
        shared_day_has_data = struct( ...
            'fip', false(1, 2), ...
            'speed', false(1, 2));

        for i_col = 1:n_cols
            panel_type = panel_cols{i_col};

            if use_tiles
                % Calculate tile index for column-major syllable ordering
                actual_col = col_group * n_cols + i_col;
                tile_idx = (row_in_group - 1) * grid_cols + actual_col;
                ax = nexttile(tl, tile_idx);
                set(ax, 'Color', bg_colors(bg_idx, :));
            else
                ax = nexttile(tl);
            end

            hold(ax, 'on');

            % Title includes syllable number for all panels
            tile_title = sprintf('Syl %d', syl);
            if is_first_row
                tile_title = sprintf('Syl %d - %s', syl, panel_labels.(panel_type));
            end

            switch panel_type
                case 'fip_psth'
                    plot_psth(ax, syl_events, 'zsc_exp', 'region', time_axis, ...
                        region_colors, opts.show_individual, indiv_color, opts.psth_aggregate);
                    xline(ax, 0, 'k:', 'LineWidth', 0.5);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_first_row
                        ylabel(ax, 'zsc\_exp');
                    end
                    if is_last_row
                        xlabel(ax, 'Time (s)');
                    end

                case 'speed_psth'
                    plot_psth(ax, syl_events, 'speed', '', time_axis, ...
                        syl_color, opts.show_individual, indiv_color, opts.psth_aggregate);
                    xline(ax, 0, 'k:', 'LineWidth', 0.5);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_first_row
                        ylabel(ax, 'Speed');
                    end
                    if is_last_row
                        xlabel(ax, 'Time (s)');
                    end

                case {'speed_psth_days_NAcMed', 'speed_psth_days_NAcLat'}
                    region_name = strrep(panel_type, 'speed_psth_days_', '');
                    has_data = plot_speed_psth_days(ax, syl_events, region_name, time_axis, is_first_row);
                    xline(ax, 0, 'k:', 'LineWidth', 0.5);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_first_row
                        ylabel(ax, 'Speed');
                    end
                    if is_last_row
                        xlabel(ax, 'Time (s)');
                    end
                    region_idx = 1 + strcmp(region_name, 'NAcLat');
                    shared_day_axes.speed(region_idx) = ax;
                    shared_day_has_data.speed(region_idx) = has_data;

                case {'fip_psth_days_NAcMed', 'fip_psth_days_NAcLat'}
                    region_name = strrep(panel_type, 'fip_psth_days_', '');
                    has_data = plot_fip_psth_days(ax, syl_events, region_name, time_axis, is_first_row);
                    xline(ax, 0, 'k:', 'LineWidth', 0.5);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_first_row
                        ylabel(ax, 'zsc\_exp');
                    end
                    if is_last_row
                        xlabel(ax, 'Time (s)');
                    end
                    region_idx = 1 + strcmp(region_name, 'NAcLat');
                    shared_day_axes.fip(region_idx) = ax;
                    shared_day_has_data.fip(region_idx) = has_data;

                case 'bout_hist'
                    if ~isempty(bout_lengths{i_syl})
                        histogram(ax, bout_lengths{i_syl}, bin_edges, ...
                            'FaceColor', syl_color, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
                    end
                    xlim(ax, [bin_edges(1), bin_edges(end)]);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_last_row
                        xlabel(ax, 'Duration (s)');
                    end

                case 'daily_counts'
                    counts_matrix = squeeze(bout_counts(i_syl, :, :));
                    plot_stacked_bar(ax, counts_matrix, animal_colors, n_days);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_last_row
                        set(ax, 'XTickLabel', {'D1','D2','D3','D4','D5'});
                    else
                        set(ax, 'XTickLabel', {});
                    end

                case 'fa_counts'
                    counts_matrix = squeeze(bout_counts_fa(i_syl, :, :));
                    plot_stacked_bar(ax, counts_matrix, animal_colors, n_days);
                    title(ax, tile_title, 'FontSize', 9);
                    if is_last_row
                        set(ax, 'XTickLabel', {'D1','D2','D3','D4','D5'});
                    else
                        set(ax, 'XTickLabel', {});
                    end

                case 'trajectory'
                    % Load and display trajectory PNG
                    png_file = fullfile(opts.trajectory_png_path, sprintf('Syllable%d.png', syl));
                    if isfile(png_file)
                        img = imread(png_file);
                        imshow(img, 'Parent', ax);
                        xl = xlim(ax);
                        yl = ylim(ax);
                    else
                        text(ax, 0.5, 0.5, 'No PNG', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                        xl = [0, 1];
                        yl = [0, 1];
                        xlim(ax, xl);
                        ylim(ax, yl);
                    end
                    strip_height_frac = 0.06;
                    strip_height = diff(yl) * strip_height_frac;
                    strip_y = min(yl);
                    rectangle(ax, ...
                        'Position', [xl(1), strip_y, diff(xl), strip_height], ...
                        'FaceColor', syl_color, ...
                        'EdgeColor', 'none');
                    title(ax, tile_title, 'FontSize', 9);
                    axis(ax, 'off');
            end

            hold(ax, 'off');
        end

        sync_shared_day_axes(shared_day_axes.fip, shared_day_has_data.fip);
        sync_shared_day_axes(shared_day_axes.speed, shared_day_has_data.speed);
    end

    fprintf('Figure complete: %d syllables x %d panels\n', n_syllables, n_cols);
end

%--------------------------------------------------------------------------
% Helper: plot FIP PSTH by day with animal-balanced mean/SEM
%--------------------------------------------------------------------------
function has_data = plot_fip_psth_days(ax, events, region_name, time_axis, show_legend)
    region_mask = strcmp(events.region, region_name);
    region_events = events(region_mask, :);

    if height(region_events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        has_data = false;
        return;
    end

    has_data = plot_signal_psth_days(ax, region_events, 'zsc_exp', time_axis, show_legend);
end

%--------------------------------------------------------------------------
% Helper: plot speed PSTH by day, split by region
%--------------------------------------------------------------------------
function has_data = plot_speed_psth_days(ax, events, region_name, time_axis, show_legend)
    region_mask = strcmp(events.region, region_name);
    region_events = events(region_mask, :);

    if height(region_events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        has_data = false;
        return;
    end

    has_data = plot_signal_psth_days(ax, region_events, 'speed', time_axis, show_legend);
end

%--------------------------------------------------------------------------
% Helper: plot signal PSTH by day with animal-balanced mean/SEM
%--------------------------------------------------------------------------
function has_data = plot_signal_psth_days(ax, events, signal_name, time_axis, show_legend)
    n_days = 5;
    day_colors = cool(n_days);
    day_colors = 0.65 * day_colors + 0.35 * repmat([0.45 0.45 0.45], n_days, 1);
    legend_handles = gobjects(0);
    legend_labels = {};
    has_data = false;

    for day = 1:n_days
        day_events = events(events.day == day, :);
        if height(day_events) == 0
            continue;
        end

        day_traces = stack_traces(day_events.(signal_name));
        if isempty(day_traces)
            continue;
        end
        day_traces = interp_traces(day_traces, time_axis);

        animals = unique(day_events.animal);
        animal_means = nan(length(animals), size(day_traces, 2));
        for ia = 1:length(animals)
            animal_mask = day_events.animal == animals(ia);
            animal_means(ia, :) = nanmean(day_traces(animal_mask, :), 1);
        end

        mean_trace = nanmean(animal_means, 1);
        n_valid = sum(~isnan(animal_means), 1);
        sem_trace = nanstd(animal_means, 0, 1) ./ sqrt(n_valid);
        sem_trace(n_valid <= 1) = 0;

        col = day_colors(day, :);
        fill(ax, [time_axis, fliplr(time_axis)], ...
            [mean_trace + sem_trace, fliplr(mean_trace - sem_trace)], ...
            col, 'FaceAlpha', 0.10, 'EdgeColor', 'none');
        h = plot(ax, time_axis, mean_trace, 'Color', col, 'LineWidth', 1.2);
        has_data = true;

        legend_handles(end+1) = h;
        legend_labels{end+1} = sprintf('D%d (n=%d)', day, length(animals));
    end

    if ~has_data
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, ...
            'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end

    xlim(ax, [time_axis(1), time_axis(end)]);
end

%--------------------------------------------------------------------------
% Helper: use a shared y-range for paired day PSTH axes
%--------------------------------------------------------------------------
function sync_shared_day_axes(ax_pair, has_data)
    ax_pair = ax_pair(isgraphics(ax_pair, 'axes'));
    if isempty(ax_pair)
        return;
    end

    valid_mask = has_data(1:min(end, numel(has_data)));
    valid_mask = valid_mask(1:numel(ax_pair));
    valid_axes = ax_pair(valid_mask);
    if isempty(valid_axes)
        return;
    end

    y_limits = cell2mat(get(valid_axes, 'YLim'));
    if isempty(y_limits)
        return;
    end

    if size(y_limits, 2) ~= 2
        y_limits = reshape(y_limits, [], 2);
    end

    shared_ylim = [min(y_limits(:, 1)), max(y_limits(:, 2))];
    if ~all(isfinite(shared_ylim))
        return;
    end

    if shared_ylim(1) == shared_ylim(2)
        pad = max(abs(shared_ylim(1)) * 0.05, 1e-3);
        shared_ylim = shared_ylim + [-pad, pad];
    end

    set(ax_pair, 'YLim', shared_ylim);
    if numel(ax_pair) > 1
        linkaxes(ax_pair, 'y');
    end
end

%--------------------------------------------------------------------------
% Helper: plot PSTH with mean/SEM
%--------------------------------------------------------------------------
function plot_psth(ax, events, signal_name, color_var, time_axis, colors, show_individual, indiv_color, psth_aggregate)
    if height(events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    n_t = length(time_axis);

    if isempty(color_var)
        % Single trace - no color split
        all_traces = stack_traces(events.(signal_name));
        if isempty(all_traces); return; end
        all_traces = interp_traces(all_traces, time_axis);

        [mean_trace, sem_trace] = compute_psth_stats(events, all_traces, psth_aggregate);

        if isstruct(colors)
            col = [0.3 0.3 0.3];
        else
            col = colors;
        end

        % Plot individual traces based on show_individual mode
        plot_individual_traces(ax, events, signal_name, time_axis, show_individual, indiv_color);

        fill(ax, [time_axis, fliplr(time_axis)], ...
            [mean_trace + sem_trace, fliplr(mean_trace - sem_trace)], ...
            col, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        plot(ax, time_axis, mean_trace, 'Color', col, 'LineWidth', 1.5);
        xlim(ax, [time_axis(1), time_axis(end)]);
    else
        % Split by color variable
        groups = unique(events.(color_var));
        for ig = 1:length(groups)
            g_name = groups{ig};
            g_mask = strcmp(events.(color_var), g_name);
            g_events = events(g_mask, :);
            g_traces = stack_traces(g_events.(signal_name));

            if isempty(g_traces); continue; end
            g_traces = interp_traces(g_traces, time_axis);

            [mean_trace, sem_trace] = compute_psth_stats(g_events, g_traces, psth_aggregate);

            if isstruct(colors) && isfield(colors, g_name)
                col = colors.(g_name);
            else
                col = [0.5 0.5 0.5];
            end

            % Plot individual traces based on show_individual mode
            % Use region color (col) for individual traces when split by color
            plot_individual_traces(ax, g_events, signal_name, time_axis, show_individual, col);

            fill(ax, [time_axis, fliplr(time_axis)], ...
                [mean_trace + sem_trace, fliplr(mean_trace - sem_trace)], ...
                col, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
            plot(ax, time_axis, mean_trace, 'Color', col, 'LineWidth', 1.2);
        end
        xlim(ax, [time_axis(1), time_axis(end)]);
    end
end

%--------------------------------------------------------------------------
% Helper: compute plotted PSTH mean/SEM at requested aggregation level
%--------------------------------------------------------------------------
function [mean_trace, sem_trace] = compute_psth_stats(events, traces, aggregate_level)
    switch aggregate_level
        case 'event'
            aggregate_traces = traces;

        case 'animal'
            animals = unique(events.animal);
            aggregate_traces = nan(length(animals), size(traces, 2));
            for ia = 1:length(animals)
                mask = events.animal == animals(ia);
                aggregate_traces(ia, :) = nanmean(traces(mask, :), 1);
            end

        case 'session'
            sessions = unique([events.animal, events.day], 'rows');
            aggregate_traces = nan(size(sessions, 1), size(traces, 2));
            for is = 1:size(sessions, 1)
                mask = events.animal == sessions(is, 1) & events.day == sessions(is, 2);
                aggregate_traces(is, :) = nanmean(traces(mask, :), 1);
            end

        otherwise
            error('Unknown PSTH aggregation level: %s', aggregate_level);
    end

    mean_trace = nanmean(aggregate_traces, 1);
    n_valid = sum(~isnan(aggregate_traces), 1);
    sem_trace = nanstd(aggregate_traces, 0, 1) ./ sqrt(n_valid);
    sem_trace(n_valid <= 1) = 0;
end

%--------------------------------------------------------------------------
% Helper: plot individual traces based on mode
%--------------------------------------------------------------------------
function plot_individual_traces(ax, events, signal_name, time_axis, mode, indiv_color)
    if strcmp(mode, 'none')
        return;
    end

    all_traces = stack_traces(events.(signal_name));
    if isempty(all_traces); return; end
    all_traces = interp_traces(all_traces, time_axis);

    if strcmp(mode, 'event')
        % Plot all individual event traces
        plot(ax, time_axis, all_traces', 'Color', [indiv_color 0.3], 'LineWidth', 0.5);

    elseif strcmp(mode, 'animal')
        % Average per animal, then plot
        animals = unique(events.animal);
        for ia = 1:length(animals)
            a_mask = events.animal == animals(ia);
            a_traces = all_traces(a_mask, :);
            if isempty(a_traces); continue; end
            a_mean = nanmean(a_traces, 1);
            plot(ax, time_axis, a_mean, 'Color', [indiv_color 0.3], 'LineWidth', 0.8);
        end

    elseif strcmp(mode, 'session')
        % Average per session (animal+day), then plot
        sessions = unique([events.animal, events.day], 'rows');
        for is = 1:size(sessions, 1)
            s_mask = events.animal == sessions(is, 1) & events.day == sessions(is, 2);
            s_traces = all_traces(s_mask, :);
            if isempty(s_traces); continue; end
            s_mean = nanmean(s_traces, 1);
            plot(ax, time_axis, s_mean, 'Color', [indiv_color 0.5], 'LineWidth', 0.8);
        end
    end
end

%--------------------------------------------------------------------------
% Helper: plot stacked bar
%--------------------------------------------------------------------------
function plot_stacked_bar(ax, counts_matrix, colors, n_days)
    if any(counts_matrix(:) > 0)
        b = bar(ax, 1:n_days, counts_matrix, 'stacked', 'EdgeColor', 'k', 'LineWidth', 0.5);
        for ia = 1:size(counts_matrix, 2)
            b(ia).FaceColor = colors(ia, :);
        end
    end
    xlim(ax, [0.5, n_days + 0.5]);
    set(ax, 'XTick', 1:n_days);
end

%--------------------------------------------------------------------------
% Helper: stack cell array of traces into matrix
%--------------------------------------------------------------------------
function traces = stack_traces(traces_cell)
    if isempty(traces_cell)
        traces = [];
        return;
    end
    n_events = length(traces_cell);
    n_samples = length(traces_cell{1});
    traces = zeros(n_events, n_samples);
    for i = 1:n_events
        traces(i, :) = traces_cell{i}(:)';
    end
end

%--------------------------------------------------------------------------
% Helper: interpolate traces to match time axis
%--------------------------------------------------------------------------
function traces = interp_traces(traces, time_axis)
    n_t = length(time_axis);
    if size(traces, 2) == n_t
        return;
    end
    old_t = linspace(time_axis(1), time_axis(end), size(traces, 2));
    traces_interp = zeros(size(traces, 1), n_t);
    for i = 1:size(traces, 1)
        traces_interp(i, :) = interp1(old_t, traces(i, :), time_axis, 'linear', 'extrap');
    end
    traces = traces_interp;
end
