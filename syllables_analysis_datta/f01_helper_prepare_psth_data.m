function [traces_table, plot_info] = f01_helper_prepare_psth_data(events, plot_info, varargin)
% PREPARE_PSTH_DATA Prepare and aggregate data for PSTH plotting
%
% [traces_table, plot_info] = f01_helper_prepare_psth_data(events, 'facet', 'bat', 'color', 'condition', 'aggregate', 'bat')
%
% Parameters:
%   events      - Table with columns for metadata and trace data
%   'facet'     - Variable(s) to create separate tiles (string, cell array, or empty)
%   'color'     - Variable to overlay within tiles with different colors (string or empty)
%   'aggregate' - Level for SEM computation: 'event', 'unit', 'session', 'bat', or 'none'
%                 For multi-unit data (events × time × units):
%                   'event': mean/SEM across events (n=65 events)
%                   'unit': mean/SEM across units (n=251 units)
%                 For single-trace data: 'event' computes mean/SEM across events
%   'signals'   - Which trace columns to process (cell array, default: first numeric matrix column)
%   'time_axis' - Time vector for x-axis (default: centered on 0)
%   'signal_layout' - 'rows' (one row per signal) or 'overlay' (same tile, different colors)
%   'individual_level' - Level for individual traces: 'none', 'unit', 'event', 'session', 'bat'
%                        For multi-unit data: 'unit' shows individual units, 'event' shows individual events
%                        For single-trace data: 'event' shows individual events
%   'min_nonzero' - Filter signals based on non-zero traces: 'none', 'half', 'third', 'full'
%                   'none': keep all signals (default)
%                   'half': only keep signals where at least half (50%) of traces are non-zero
%                   'third': only keep signals where at least three-quarters (75%) of traces are non-zero
%                   'full': only keep signals where all traces are non-zero
%
% Output:
%   traces_table - Table with columns:
%                  .facet_idx, .color_idx, .signal_idx - indices for tile position
%                  .facet_label, .color_label, .signal_name - labels
%                  .mean_trace - mean across aggregation level (1 × timepoints)
%                  .sem_trace - SEM across aggregation level (1 × timepoints)
%                  .individual_traces - traces at individual_level (n × timepoints)
%                  .raw_traces - raw trace data (events × timepoints or events × timepoints × units)
%                  .n_agg - number of aggregation units
%                  .n_events - number of events
%   plot_info   - Struct with plotting metadata:
%                 .time_axis, .signals, .facet_labels, .color_labels
%                 .n_rows, .n_cols, .signal_layout, .aggregate

    %-------------------------------- Parse inputs
    p = inputParser;
    addParameter(p, 'facet', {});
    addParameter(p, 'color', '');
    addParameter(p, 'aggregate', 'event');
    addParameter(p, 'signals', {});
    addParameter(p, 'time_axis', []);
    addParameter(p, 'signal_layout', 'rows');  % 'rows', 'overlay', or 'tiles'
    addParameter(p, 'individual_level', 'event'); % 'event', 'session', 'bat', or any grouping variable
    addParameter(p, 'min_nonzero', 'none');  % 'none', 'half', 'full' - filter signals with zero traces
    parse(p, varargin{:});
    opts = p.Results;

    % Initialize plot_info structure
    if ~isfield(plot_info, 'time_axis')
        plot_info.time_axis = [];
    end
    plot_info.signals = opts.signals;
    plot_info.facet_labels = {};
    plot_info.color_labels = {};
    plot_info.signal_layout = opts.signal_layout;
    plot_info.aggregate = opts.aggregate;

    % Check for xcorr-specific fields from f12_calculateXcorr
    if isfield(events, 'xcorr_ylabel')
        plot_info.ylabel = events.xcorr_ylabel;
    end

    % Initialize cell arrays for table construction
    table_data = struct();
    table_data.facet_idx = {};
    table_data.color_idx = {};
    table_data.signal_idx = {};
    table_data.facet_label = {};
    table_data.color_label = {};
    table_data.signal_name = {};
    table_data.mean_trace = {};
    table_data.sem_trace = {};
    table_data.individual_traces = {};
    table_data.raw_traces = {};
    table_data.spike_times_per_trial = {};
    table_data.n_agg = {};
    table_data.n_events = {};
    table_data.n_nonzero = {};
    % Initialize cell arrays for individual facet variable values
    % (will be populated after opts.facet is normalized)

    % Normalize inputs
    % Facet: ensure cell array
    if ischar(opts.facet) || isstring(opts.facet)
        if opts.facet == ""
            opts.facet = {};
        else
            opts.facet = {char(opts.facet)};
        end
    end

    % Color: ensure char
    if isstring(opts.color)
        opts.color = char(opts.color);
    end

    % Now initialize facet and color variable columns after normalization
    for i_fv = 1:length(opts.facet)
        table_data.(opts.facet{i_fv}) = {};
    end
    if ~isempty(opts.color)
        table_data.(opts.color) = {};
    end

    % Signals: auto-detect if not provided
    if isempty(opts.signals)
        opts.signals = find_trace_columns(events);
    elseif ischar(opts.signals) || isstring(opts.signals)
        opts.signals = {char(opts.signals)};
    end

    if isempty(opts.signals)
        error('No trace columns found. Specify ''signals'' parameter.');
    end

    % Remove spktimes_ signals from opts.signals (they'll be added to unit rows)
    signals_filtered = {};
    for i = 1:length(opts.signals)
        if ~startsWith(opts.signals{i}, 'spktimes_')
            signals_filtered{end+1} = opts.signals{i};
        end
    end
    opts.signals = signals_filtered;

    plot_info.signals = opts.signals;

    %-------------------------------- Determine trace length and time axis
    first_signal = opts.signals{1};
    trace_len = get_trace_length(events, first_signal);

    if isempty(opts.time_axis)
        % Use xcorr_time_axis if available (from f12_calculateXcorr)
        if isfield(events, 'xcorr_time_axis')
            opts.time_axis = events.xcorr_time_axis(:)';
        else
            % Center on 0, assume 100 Hz,
            % 200 because of 2*100. i want to look at half only
            opts.time_axis = linspace(-trace_len/200, trace_len/200, trace_len);
        end
    end

    if isempty(plot_info.time_axis)
        plot_info.time_axis = opts.time_axis;
    end

    %-------------------------------- Check signals for min_nonzero (mark for zeroing, don't filter)
    signals_to_zero = false(size(opts.signals));
    n_nonzero_per_signal = zeros(size(opts.signals));
    for i_sig = 1:length(opts.signals)
        sig_name = opts.signals{i_sig};
        traces = events.(sig_name);
        n_traces = length(traces);
        n_nz = 0;
        for i_tr = 1:n_traces
            tr = traces{i_tr};
            if ~isempty(tr) && any(tr ~= 0)
                n_nz = n_nz + 1;
            end
        end
        n_nonzero_per_signal(i_sig) = n_nz;

        % Determine required minimum
        if isnumeric(opts.min_nonzero)
            min_required = opts.min_nonzero;
        else
            switch opts.min_nonzero
                case 'none'
                    min_required = 0;
                case 'half'
                    min_required = n_traces / 2;
                case 'third'
                    min_required = n_traces * 0.75;
                case 'full'
                    min_required = n_traces;
                otherwise
                    min_required = 0;
            end
        end

        if min_required > 0 && n_nz < min_required
            signals_to_zero(i_sig) = true;
            fprintf('Signal %s: only %d/%d non-zero traces (need %s) - setting mean to zero\n', ...
                sig_name, n_nz, n_traces, string(opts.min_nonzero));
        end
    end

    %-------------------------------- Compute facet groups
    [facet_masks, facet_labels, n_rows, n_cols, facet_values] = compute_facet_groups(events, opts.facet);
    n_facets = length(facet_masks);

    plot_info.facet_labels = facet_labels;
    plot_info.n_rows = n_rows;
    plot_info.n_cols = n_cols;

    %-------------------------------- Compute color groups
    [color_masks, color_labels, ~, color_values] = compute_color_groups(events, opts.color);
    n_colors = length(color_masks);

    plot_info.color_labels = color_labels;

    %-------------------------------- Process data
    n_signals = length(opts.signals);
    overlay_signals = strcmp(opts.signal_layout, 'overlay');

    if overlay_signals
        % OVERLAY MODE: signals as different colors in same tile
        for i_facet = 1:n_facets
            facet_mask = facet_masks{i_facet};
            subset = events(facet_mask, :);

            if height(subset) == 0
                continue;
            end

            % Process each signal
            for i_signal = 1:n_signals
                signal_name = opts.signals{i_signal};
                raw_traces = get_traces(subset, signal_name);
                n = size(raw_traces, 1);

                % Individual traces (skip if individual_level='none')
                if ~strcmp(opts.individual_level, 'none')
                    individual_traces = get_individual_traces(subset, raw_traces, opts.individual_level);
                else
                    individual_traces = [];
                end

                % Aggregated traces
                if ~strcmp(opts.aggregate, 'none')
                    [mean_trace, sem_trace, n_agg] = aggregate_traces(subset, raw_traces, opts.aggregate);
                    % Zero out if signal didn't pass min_nonzero
                    if signals_to_zero(i_signal)
                        mean_trace = zeros(size(mean_trace));
                        sem_trace = zeros(size(sem_trace));
                    end
                else
                    mean_trace = [];
                    sem_trace = [];
                    n_agg = n;
                end

                % Check if spike times exist for this unit
                spike_times_per_trial = [];
                if startsWith(signal_name, 'unit_')
                    spktimes_name = sprintf('spktimes_%s', signal_name);
                    if ismember(spktimes_name, subset.Properties.VariableNames)
                        spike_times_per_trial = get_traces(subset, spktimes_name);
                    end
                end

                % Add row to table_data (color=1 for overlay mode)
                table_data.facet_idx{end+1} = i_facet;
                table_data.color_idx{end+1} = 1;
                table_data.signal_idx{end+1} = i_signal;
                table_data.facet_label{end+1} = facet_labels{i_facet};
                table_data.color_label{end+1} = '';
                table_data.signal_name{end+1} = signal_name;
                table_data.mean_trace{end+1} = mean_trace;
                table_data.sem_trace{end+1} = sem_trace;
                table_data.individual_traces{end+1} = individual_traces;
                table_data.raw_traces{end+1} = raw_traces;
                table_data.spike_times_per_trial{end+1} = spike_times_per_trial;
                table_data.n_agg{end+1} = n_agg;
                table_data.n_events{end+1} = n;
                table_data.n_nonzero{end+1} = n_nonzero_per_signal(i_signal);
                % Add individual facet variable values
                for i_fv = 1:length(opts.facet)
                    table_data.(opts.facet{i_fv}){end+1} = facet_values{i_facet, i_fv};
                end
            end
        end
    else
        % ROWS MODE: each signal gets its own row(s)
        for i_signal = 1:n_signals
            signal_name = opts.signals{i_signal};

            for i_facet = 1:n_facets
                facet_mask = facet_masks{i_facet};

                % Process each color group
                for i_color = 1:n_colors
                    combined_mask = facet_mask & color_masks{i_color};
                    subset = events(combined_mask, :);

                    if height(subset) == 0
                        continue;
                    end

                    % Get traces
                    raw_traces = get_traces(subset, signal_name);
                    n = size(raw_traces, 1);

                    % Individual traces (skip if individual_level='none')
                    if ~strcmp(opts.individual_level, 'none')
                        individual_traces = get_individual_traces(subset, raw_traces, opts.individual_level);
                    else
                        individual_traces = [];
                    end

                    % Aggregated traces
                    if ~strcmp(opts.aggregate, 'none')
                        [mean_trace, sem_trace, n_agg] = aggregate_traces(subset, raw_traces, opts.aggregate);
                        % Zero out if signal didn't pass min_nonzero
                        if signals_to_zero(i_signal)
                            mean_trace = zeros(size(mean_trace));
                            sem_trace = zeros(size(sem_trace));
                        end
                    else
                        mean_trace = [];
                        sem_trace = [];
                        n_agg = n;
                    end

                    % Check if spike times exist for this unit
                    spike_times_per_trial = [];
                    if startsWith(signal_name, 'unit_')
                        spktimes_name = sprintf('spktimes_%s', signal_name);
                        if ismember(spktimes_name, subset.Properties.VariableNames)
                            spike_times_per_trial = get_traces(subset, spktimes_name);
                        end
                    end

                    % Add row to table_data
                    table_data.facet_idx{end+1} = i_facet;
                    table_data.color_idx{end+1} = i_color;
                    table_data.signal_idx{end+1} = i_signal;
                    table_data.facet_label{end+1} = facet_labels{i_facet};
                    table_data.color_label{end+1} = color_labels{i_color};
                    table_data.signal_name{end+1} = signal_name;
                    table_data.mean_trace{end+1} = mean_trace;
                    table_data.sem_trace{end+1} = sem_trace;
                    table_data.individual_traces{end+1} = individual_traces;
                    table_data.raw_traces{end+1} = raw_traces;
                    table_data.spike_times_per_trial{end+1} = spike_times_per_trial;
                    table_data.n_agg{end+1} = n_agg;
                    table_data.n_events{end+1} = n;
                    table_data.n_nonzero{end+1} = n_nonzero_per_signal(i_signal);
                    % Add individual facet variable values
                    for i_fv = 1:length(opts.facet)
                        table_data.(opts.facet{i_fv}){end+1} = facet_values{i_facet, i_fv};
                    end
                    % Add color variable value
                    if ~isempty(opts.color) && ~isempty(color_values)
                        table_data.(opts.color){end+1} = color_values{i_color};
                    end
                end
            end
        end
    end

    %-------------------------------- Build output table
    traces_table = table( ...
        cell2mat(table_data.facet_idx)', ...
        cell2mat(table_data.color_idx)', ...
        cell2mat(table_data.signal_idx)', ...
        table_data.facet_label', ...
        table_data.color_label', ...
        table_data.signal_name', ...
        table_data.mean_trace', ...
        table_data.sem_trace', ...
        table_data.individual_traces', ...
        table_data.raw_traces', ...
        table_data.spike_times_per_trial', ...
        cell2mat(table_data.n_agg)', ...
        cell2mat(table_data.n_events)', ...
        cell2mat(table_data.n_nonzero)', ...
        'VariableNames', {'facet_idx', 'color_idx', 'signal_idx', ...
                         'facet_label', 'color_label', 'signal_name', ...
                         'mean_trace', 'sem_trace', 'individual_traces', ...
                         'raw_traces', 'spike_times_per_trial', ...
                         'n_agg', 'n_events', 'n_nonzero'});

    % Add individual facet variable columns
    for i_fv = 1:length(opts.facet)
        var_name = opts.facet{i_fv};
        traces_table.(var_name) = table_data.(var_name)';
    end

    % Add color variable column
    if ~isempty(opts.color) && isfield(table_data, opts.color)
        traces_table.(opts.color) = table_data.(opts.color)';
    end
end

%-------------------------------- Helper functions

function cols = find_trace_columns(events)
    % Find columns that look like traces (numeric matrices or cell arrays of vectors)
    cols = {};
    names = events.Properties.VariableNames;
    for i = 1:length(names)
        data = events.(names{i});
        if iscell(data) && ~isempty(data) && isnumeric(data{1}) && length(data{1}) > 10
            cols{end+1} = names{i};
        elseif isnumeric(data) && size(data, 2) > 10
            cols{end+1} = names{i};
        end
    end
end

function len = get_trace_length(events, signal_name)
    data = events.(signal_name);
    if iscell(data)
        len = length(data{1});
    else
        len = size(data, 2);
    end
end

function [masks, labels, n_rows, n_cols, facet_values] = compute_facet_groups(events, facet_vars)
    n = height(events);

    if isempty(facet_vars)
        masks = {true(n, 1)};
        labels = {''};
        n_rows = 1;
        n_cols = 1;
        facet_values = {};  % Empty cell array when no facet variables
        return;
    end

    if length(facet_vars) == 1
        [masks, labels, vals] = get_unique_groups(events, facet_vars{1});
        n_rows = 1;
        n_cols = length(masks);
        % facet_values is n_facets × 1 cell array
        facet_values = vals(:);
    else
        % Two facet variables → grid (first = rows, second = cols)
        [masks1, labels1, vals1] = get_unique_groups(events, facet_vars{1});
        [masks2, labels2, vals2] = get_unique_groups(events, facet_vars{2});
        n_rows = length(masks1);
        n_cols = length(masks2);

        masks = {};
        labels = {};
        facet_values = {};  % Will be n_facets × 2 cell array
        for i = 1:n_rows
            for j = 1:n_cols
                masks{end+1} = masks1{i} & masks2{j};
                labels{end+1} = sprintf('%s, %s', labels1{i}, labels2{j});
                facet_values{end+1, 1} = vals1{i};
                facet_values{end, 2} = vals2{j};
            end
        end
    end
end

function [masks, labels, is_numeric, values] = compute_color_groups(events, color_var)
    if isempty(color_var) || color_var == ""
        masks = {true(height(events), 1)};
        labels = {''};
        is_numeric = false;
        values = {};
    else
        [masks, labels, values] = get_unique_groups(events, color_var);
        is_numeric = isnumeric(events.(color_var));
    end
end

function [masks, labels, values] = get_unique_groups(events, var_name)
    vals = events.(var_name);

    if iscategorical(vals)
        unique_vals = categories(vals);
        masks = cell(length(unique_vals), 1);
        labels = cell(length(unique_vals), 1);
        values = cell(length(unique_vals), 1);
        for i = 1:length(unique_vals)
            masks{i} = vals == unique_vals{i};
            labels{i} = sprintf('%s', unique_vals{i});
            values{i} = unique_vals{i};
        end
    elseif iscell(vals) || isstring(vals)
        unique_vals = unique(vals);
        masks = cell(length(unique_vals), 1);
        labels = cell(length(unique_vals), 1);
        values = cell(length(unique_vals), 1);
        for i = 1:length(unique_vals)
            if iscell(unique_vals)
                masks{i} = strcmp(vals, unique_vals{i});
                labels{i} = sprintf('%s', unique_vals{i});
                values{i} = unique_vals{i};
            else
                masks{i} = vals == unique_vals(i);
                labels{i} = sprintf('%s', unique_vals(i));
                values{i} = unique_vals(i);
            end
        end
    else
        unique_vals = unique(vals);
        masks = cell(length(unique_vals), 1);
        labels = cell(length(unique_vals), 1);
        values = cell(length(unique_vals), 1);
        for i = 1:length(unique_vals)
            masks{i} = vals == unique_vals(i);
            labels{i} = sprintf('%s=%g', var_name, unique_vals(i));
            values{i} = unique_vals(i);  % Store actual numeric value
        end
    end
end

function traces = get_traces(events, signal_name)
    data = events.(signal_name);

    % Check if this is spike times data - keep as cell array
    if startsWith(signal_name, 'spktimes_')
        if iscell(data)
            traces = data;
        else
            error('spktimes_ field should be a cell array');
        end
        return;
    end

    % Regular trace processing
    if iscell(data)
        first_valid = find(~cellfun(@isempty, data), 1);
        if isempty(first_valid)
            traces = [];
            return;
        end
        first = data{first_valid};

        if isvector(first)
            % 1D: convert to matrix (n_events × trace_len)
            % Handle variable-length traces by NaN-padding to max length
            lengths = cellfun(@(x) numel(x), data);
            max_len = max(lengths);
            if all(lengths == max_len)
                traces = cell2mat(cellfun(@(x) x(:)', data, 'UniformOutput', false));
            else
                traces = nan(length(data), max_len);
                for i = 1:length(data)
                    if ~isempty(data{i})
                        traces(i, 1:lengths(i)) = data{i}(:)';
                    end
                end
            end
        else
            % 2D: convert to 3D array (n_events × trace_len × n_units)
            n_events = length(data);
            [trace_len, n_units] = size(first);
            traces = nan(n_events, trace_len, n_units);
            for i = 1:n_events
                if ~isempty(data{i})
                    traces(i, :, :) = data{i};
                end
            end
        end
    else
        traces = data;
    end
end

function [mean_trace, sem_trace, n] = aggregate_traces(events, traces, level)
    % Handle 3D arrays (events × timepoints × units)
    is_3d = ndims(traces) == 3;

    switch level
        case 'event'
            if is_3d
                % For 3D arrays, average across units first → (events × timepoints)
                traces = squeeze(mean(traces, 3, 'omitnan'));
            end
            % Now compute mean/SEM across events
            mean_trace = mean(traces, 1, 'omitnan');
            sem_trace = std(traces, 0, 1, 'omitnan') / sqrt(size(traces, 1));
            n = size(traces, 1);

        case 'unit'
            if is_3d
                % For 3D arrays, average across events first → (units × timepoints)
                traces = squeeze(mean(traces, 1, 'omitnan'))';
            end
            % Now compute mean/SEM across units
            mean_trace = mean(traces, 1, 'omitnan');
            sem_trace = std(traces, 0, 1, 'omitnan') / sqrt(size(traces, 1));
            n = size(traces, 1);

        case 'session'
            % First average per session, then SEM across sessions
            [mean_trace, sem_trace, n] = aggregate_by_variable(events, traces, 'session');

        case 'bat'
            % First average per bat, then SEM across bats
            [mean_trace, sem_trace, n] = aggregate_by_variable(events, traces, 'bat');

        otherwise
            % Try to use it as a variable name
            if ismember(level, events.Properties.VariableNames)
                [mean_trace, sem_trace, n] = aggregate_by_variable(events, traces, level);
            else
                error('Unknown aggregation level: %s', level);
            end
    end
end

function [mean_trace, sem_trace, n] = aggregate_by_variable(events, traces, var_name)
    groups = events.(var_name);
    unique_groups = unique(groups);
    n = length(unique_groups);

    is_3d = ndims(traces) == 3;

    group_means = nan(n, size(traces, 2));
    for i = 1:n
        if iscell(unique_groups)
            mask = strcmp(groups, unique_groups{i});
        else
            mask = groups == unique_groups(i);
        end

        if is_3d
            % For 3D: average across both events (dim 1) and units (dim 3)
            group_data = traces(mask, :, :);  % subset of events
            group_means(i, :) = mean(group_data, [1, 3], 'omitnan');
        else
            % For 2D: average across events only
            group_means(i, :) = mean(traces(mask, :), 1, 'omitnan');
        end
    end

    mean_trace = mean(group_means, 1, 'omitnan');
    sem_trace = std(group_means, 0, 1, 'omitnan') / sqrt(n);
end

function individual_traces = get_individual_traces(events, traces, level)
    % Handle 3D arrays (events × timepoints × units)
    is_3d = ndims(traces) == 3;

    % Get traces at the specified level for individual plotting
    if strcmp(level, 'unit')
        % Show individual units (only makes sense for 3D data)
        if is_3d
            % Average across events first → (units × timepoints)
            individual_traces = squeeze(mean(traces, 1, 'omitnan'))';
        else
            warning('individual_level="unit" specified but data is not multi-unit. Using events instead.');
            individual_traces = traces;
        end

    elseif strcmp(level, 'event')
        % Show individual events
        if is_3d
            % Average across units first → (events × timepoints)
            individual_traces = squeeze(mean(traces, 3, 'omitnan'));
        else
            % Already 2D (events × timepoints)
            individual_traces = traces;
        end

    else
        % Aggregate by a grouping variable (session, bat, etc.)
        if ~ismember(level, events.Properties.VariableNames)
            warning('Individual level variable "%s" not found. Using raw events.', level);
            if is_3d
                individual_traces = squeeze(mean(traces, 3, 'omitnan'));
            else
                individual_traces = traces;
            end
            return;
        end

        % First reduce 3D to 2D by averaging across units
        if is_3d
            traces = squeeze(mean(traces, 3, 'omitnan'));
        end

        groups = events.(level);
        unique_groups = unique(groups);
        n_groups = length(unique_groups);

        individual_traces = nan(n_groups, size(traces, 2));
        for i = 1:n_groups
            if iscell(unique_groups)
                mask = strcmp(groups, unique_groups{i});
            else
                mask = groups == unique_groups(i);
            end
            individual_traces(i, :) = mean(traces(mask, :), 1, 'omitnan');
        end
    end
end
