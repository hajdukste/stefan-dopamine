function stats_out = c03_syllable_region_stats(all_data, varargin)
% c03_syllable_region_stats.m
% Screen syllable-aligned region differences with pooled day-set tests.
%
% Example:
% stats_out = c03_syllable_region_stats(all_data, ...
%     'syllables', [29, 22, 14, 16, 20, 18], ...
%     'analysis_modes', {'all_data', 'trial_outside_trial'});

    if nargin < 1 || isempty(all_data)
        if evalin('base', 'exist(''all_data'', ''var'')')
            all_data = evalin('base', 'all_data');
        else
            error('c03_syllable_region_stats requires all_data.');
        end
    end

    p = inputParser;
    addParameter(p, 'syllables', []);
    addParameter(p, 'analysis_modes', {'all_data'});
    addParameter(p, 'analysis_parts', {'pooled', 'lme'});
    addParameter(p, 'days', 1:5);
    addParameter(p, 'pooled_day_sets', {1:5, 1, 4:5});
    addParameter(p, 'pooled_day_labels', {'All days', 'Day 1', 'Days 4-5'});
    addParameter(p, 'top_n_followup', 8);
    addParameter(p, 'plot_p_values_corr', false);
    addParameter(p, 'show_sorted_p_values', true);
    addParameter(p, 'skip_animals_days', [0 0]);
    addParameter(p, 'signal', 'zsc_exp');
    addParameter(p, 't_before', 120);
    addParameter(p, 't_after', 120);
    addParameter(p, 'fs', 60);
    addParameter(p, 'pre_window', [-1.5, -0.5]);
    addParameter(p, 'post_window', [0, 1.5]);
    addParameter(p, 'min_events_per_animal_day', 3);
    addParameter(p, 'require_complete_animal_days', false);
    addParameter(p, 'region_order', {'NAcLat', 'NAcMed'});
    parse(p, varargin{:});
    opts = p.Results;

    opts.analysis_modes = c03_normalize_cellstr(opts.analysis_modes);
    opts.analysis_parts = c03_normalize_cellstr(opts.analysis_parts);
    opts.pooled_day_labels = c03_normalize_cellstr(opts.pooled_day_labels);
    opts.region_order = c03_normalize_cellstr(opts.region_order);
    opts.signal = char(string(opts.signal));
    opts.days = opts.days(:)';
    if ~iscell(opts.pooled_day_sets)
        opts.pooled_day_sets = {opts.pooled_day_sets};
    end
    if isempty(opts.skip_animals_days)
        opts.skip_animals_days = zeros(0, 2);
    end

    if isempty(opts.syllables)
        if evalin('base', 'exist(''sorted_syllables'', ''var'')')
            opts.syllables = evalin('base', 'sorted_syllables(1:min(25, numel(sorted_syllables)))');
        else
            error('Provide ''syllables'' or define sorted_syllables in the base workspace.');
        end
    end
    opts.syllables = opts.syllables(:)';

    if numel(opts.pooled_day_sets) ~= numel(opts.pooled_day_labels)
        error('pooled_day_sets and pooled_day_labels must have the same length.');
    end
    unknown_parts = setdiff(opts.analysis_parts, {'pooled', 'lme'}, 'stable');
    if ~isempty(unknown_parts)
        error('Unknown analysis_parts: %s', strjoin(unknown_parts, ', '));
    end
    do_pooled = any(strcmp(opts.analysis_parts, 'pooled'));
    do_lme = any(strcmp(opts.analysis_parts, 'lme'));
    if ~isempty(opts.pre_window) && numel(opts.pre_window) ~= 2
        error('pre_window must be empty [] or a two-element window [start end].');
    end
    if isempty(opts.post_window) || numel(opts.post_window) ~= 2
        error('post_window must be a two-element window [start end].');
    end

    [sorted_syllables, cmap25] = c03_get_syllable_colormap();
    region_colors = c03_region_colors();
    time_axis = linspace(-opts.t_before / opts.fs, opts.t_after / opts.fs, ...
        opts.t_before + opts.t_after + 1);
    if isempty(opts.pre_window)
        pre_mask = false(size(time_axis));
        opts.metric_name = 'post_mean';
    else
        pre_mask = time_axis >= opts.pre_window(1) & time_axis <= opts.pre_window(2);
        opts.metric_name = 'post_minus_pre';
    end
    post_mask = time_axis >= opts.post_window(1) & time_axis <= opts.post_window(2);
    if ~any(post_mask)
        error('post_window does not overlap the aligned time axis.');
    end
    if ~isempty(opts.pre_window) && ~any(pre_mask)
        error('pre_window does not overlap the aligned time axis.');
    end

    fprintf('Extracting syllable onset events for modes: %s\n', strjoin(opts.analysis_modes, ', '));
    condition_tables = c03_extract_condition_tables(all_data, opts);

    stats_out = struct();
    stats_out.config = opts;
    stats_out.config.pre_mask = pre_mask;
    stats_out.config.post_mask = post_mask;
    stats_out.config.time_axis = time_axis;
    stats_out.conditions = repmat(c03_empty_condition_result(), 0, 1);

    for i_cond = 1:numel(condition_tables)
        cond = condition_tables(i_cond);
        fprintf('Analyzing %s: %d events\n', cond.condition_id, height(cond.events_table));

        cond_out = c03_empty_condition_result();
        cond_out.condition_id = cond.condition_id;
        cond_out.condition_label = cond.condition_label;
        cond_out.events_table = cond.events_table;

        if height(cond.events_table) == 0
            cond_out.warning = 'No events for this condition.';
            stats_out.conditions(end + 1) = cond_out; %#ok<AGROW>
            continue;
        end

        metric_table = c03_build_metric_table(cond.events_table, opts.signal, pre_mask, post_mask, ...
            opts.metric_name);
        metric_table = metric_table(~isnan(metric_table.delta), :);
        cond_out.metric_table = metric_table;

        if height(metric_table) == 0
            cond_out.warning = 'No valid event-level metrics for this condition.';
            stats_out.conditions(end + 1) = cond_out; %#ok<AGROW>
            continue;
        end

        cond_out.animal_day_summary = c03_summarize_metrics(metric_table, ...
            {'animal', 'day', 'region', 'syllable'}, opts.min_events_per_animal_day);
        if opts.require_complete_animal_days
            [complete_syllables, excluded_syllables] = c03_find_complete_syllables( ...
                cond_out.animal_day_summary, cond.events_table, opts.syllables, opts.days);
            cond_out.complete_syllables = complete_syllables;
            cond_out.excluded_syllables = excluded_syllables;
            fprintf('%s complete syllables: %d kept, %d excluded\n', cond.condition_id, ...
                numel(complete_syllables), numel(excluded_syllables));
            metric_table = metric_table(ismember(metric_table.syllable, complete_syllables), :);
            cond_out.metric_table = metric_table;
            if height(metric_table) == 0
                cond_out.warning = 'No syllables passed the complete animal-day filter.';
                stats_out.conditions(end + 1) = cond_out; %#ok<AGROW>
                continue;
            end
            cond_out.events_table = cond_out.events_table( ...
                ismember(cond_out.events_table.syllable, complete_syllables), :);
            cond_out.animal_day_summary = c03_summarize_metrics(metric_table, ...
                {'animal', 'day', 'region', 'syllable'}, opts.min_events_per_animal_day);
        else
            cond_out.complete_syllables = opts.syllables;
            cond_out.excluded_syllables = [];
        end
        condition_syllables = cond_out.complete_syllables;
        cond_out.animal_summary = c03_summarize_metrics(metric_table, ...
            {'animal', 'region', 'syllable'}, opts.min_events_per_animal_day);
        if do_pooled
            cond_out.pooled_screens = c03_run_pooled_dayset_screens(metric_table, ...
                condition_syllables, opts.pooled_day_sets, opts.pooled_day_labels, ...
                opts.region_order, opts.min_events_per_animal_day);
            fig_pooled = c03_plot_pooled_screen(cond_out.pooled_screens, opts, ...
                cond.condition_label, sorted_syllables, cmap25);
        else
            fig_pooled = [];
        end

        if do_lme
            cond_out.lme = c03_run_lme(metric_table, condition_syllables, opts.region_order);
            fig_lme = c03_plot_lme_screen(cond_out.lme, cond.condition_label, ...
                sorted_syllables, cmap25, opts.show_sorted_p_values);
            if opts.plot_p_values_corr
                fig_p_values_corr = c03_plot_p_values_corr_figure(cond_out, opts, ...
                    region_colors, sorted_syllables, cmap25, cond.condition_label);
            else
                fig_p_values_corr = [];
            end
        else
            fig_lme = [];
            fig_p_values_corr = [];
        end

        selected_region = c03_select_lme_syllables(cond_out.lme, 'p_region', ...
            opts.top_n_followup, cond_out.pooled_screens.table);
        selected_interaction = c03_select_lme_syllables(cond_out.lme, 'p_interaction', ...
            opts.top_n_followup, cond_out.pooled_screens.table);
        selected_day = c03_select_lme_syllables(cond_out.lme, 'p_day', ...
            opts.top_n_followup, cond_out.pooled_screens.table);

        if do_lme
            fig_region = c03_plot_followup_figure(selected_region, cond_out, opts, ...
                time_axis, region_colors, sorted_syllables, cmap25, ...
                sprintf('%s: top region effects', cond.condition_label));
            fig_interaction = c03_plot_followup_figure(selected_interaction, cond_out, opts, ...
                time_axis, region_colors, sorted_syllables, cmap25, ...
                sprintf('%s: top region x day interactions', cond.condition_label));
            fig_day = c03_plot_followup_figure(selected_day, cond_out, opts, ...
                time_axis, region_colors, sorted_syllables, cmap25, ...
                sprintf('%s: top day effects', cond.condition_label));
        else
            fig_region = [];
            fig_interaction = [];
            fig_day = [];
        end

        cond_out.selected_syllables_region = selected_region;
        cond_out.selected_syllables_interaction = selected_interaction;
        cond_out.selected_syllables_day = selected_day;
        cond_out.figures = struct( ...
            'pooled_screen', fig_pooled, ...
            'lme_screen', fig_lme, ...
            'followup_region', fig_region, ...
            'followup_interaction', fig_interaction, ...
            'followup_day', fig_day, ...
            'p_values_corr', fig_p_values_corr);

        stats_out.conditions(end + 1) = cond_out; %#ok<AGROW>
    end

    if nargout == 0
        assignin('base', 'stats_out', stats_out);
    end
end

%--------------------------------------------------------------------------
function condition_tables = c03_extract_condition_tables(all_data, opts)
    condition_tables = struct('condition_id', {}, 'condition_label', {}, 'events_table', {});

    if any(strcmp(opts.analysis_modes, 'all_data'))
        events_table = c03_extract_all_data_events(all_data, opts);
        condition_tables(end + 1) = struct( ...
            'condition_id', 'all_data', ...
            'condition_label', 'All data', ...
            'events_table', events_table); %#ok<AGROW>
    end

    if any(strcmp(opts.analysis_modes, 'trial_outside_trial'))
        split_events = c03_extract_trial_split_events(all_data, opts);
        split_ids = {'inside_trial', 'outside_trial'};
        split_labels = {'Inside trial', 'Outside trial'};
        for i_split = 1:numel(split_ids)
            if height(split_events) == 0
                sub = split_events;
            else
                sub = split_events(strcmp(split_events.condition_id, split_ids{i_split}), :);
            end
            condition_tables(end + 1) = struct( ...
                'condition_id', split_ids{i_split}, ...
                'condition_label', split_labels{i_split}, ...
                'events_table', sub); %#ok<AGROW>
        end
    end

    unknown_modes = setdiff(opts.analysis_modes, {'all_data', 'trial_outside_trial'}, 'stable');
    if ~isempty(unknown_modes)
        error('Unknown analysis_modes: %s', strjoin(unknown_modes, ', '));
    end
end

function events_table = c03_extract_all_data_events(all_data, opts)
    events_table = table();
    config_syl = struct('t_before', opts.t_before, 't_after', opts.t_after, ...
        'trace_types', {{opts.signal}});

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ~ismember(day, opts.days); continue; end
            if ismember([animal, day], opts.skip_animals_days, 'rows'); continue; end

            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames); continue; end
            if ~ismember(opts.signal, d.Properties.VariableNames); continue; end

            syl = d.syllable(:);
            run_starts = [1; find(diff(syl) ~= 0) + 1];
            run_syllables = syl(run_starts);
            keep = ismember(run_syllables, opts.syllables);
            onset_idx = run_starts(keep);
            onset_syl = run_syllables(keep);
            if isempty(onset_idx); continue; end

            events = struct();
            events.time_idx = onset_idx;
            events.syllable = onset_syl;
            events.condition_id = repmat({'all_data'}, numel(onset_idx), 1);
            events_aligned = f01_helper_align_signals(d, events, config_syl);
            events_aligned = myStruct2Mat(events_aligned);
            if height(events_aligned) == 0; continue; end

            events_aligned.animal = repmat(animal, height(events_aligned), 1);
            events_aligned.day = repmat(day, height(events_aligned), 1);
            events_aligned.region = repmat({all_data(animal).region}, height(events_aligned), 1);
            events_table = [events_table; events_aligned]; %#ok<AGROW>
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region', 'syllable', 'condition_id'}, 'Before', 1);
    end
end

function events_table = c03_extract_trial_split_events(all_data, opts)
    events_table = table();
    config_syl = struct('t_before', opts.t_before, 't_after', opts.t_after, ...
        'trace_types', {{opts.signal}});

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ~ismember(day, opts.days); continue; end
            if ismember([animal, day], opts.skip_animals_days, 'rows'); continue; end

            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames); continue; end
            if ~ismember(opts.signal, d.Properties.VariableNames); continue; end

            d_old = [];
            if isfield(all_data(animal).data(day), 'd_old')
                d_old = all_data(animal).data(day).d_old;
            end

            syl = d.syllable(:);
            run_starts = [1; find(diff(syl) ~= 0) + 1];
            run_ends = [run_starts(2:end) - 1; height(d)];
            run_syllables = syl(run_starts);
            keep = ismember(run_syllables, opts.syllables);
            onset_idx = run_starts(keep);
            end_idx = run_ends(keep);
            onset_syl = run_syllables(keep);
            if isempty(onset_idx); continue; end

            in_trial = c03_get_trial_membership_mask(d, d_old);
            start_in_trial = in_trial(onset_idx);
            end_in_trial = in_trial(end_idx);
            include_mask = start_in_trial == end_in_trial;

            onset_idx = onset_idx(include_mask);
            onset_syl = onset_syl(include_mask);
            start_in_trial = start_in_trial(include_mask);
            if isempty(onset_idx); continue; end

            condition_id = repmat({'outside_trial'}, numel(onset_idx), 1);
            condition_id(start_in_trial) = repmat({'inside_trial'}, sum(start_in_trial), 1);

            events = struct();
            events.time_idx = onset_idx;
            events.syllable = onset_syl;
            events.condition_id = condition_id;
            events_aligned = f01_helper_align_signals(d, events, config_syl);
            events_aligned = myStruct2Mat(events_aligned);
            if height(events_aligned) == 0; continue; end

            events_aligned.animal = repmat(animal, height(events_aligned), 1);
            events_aligned.day = repmat(day, height(events_aligned), 1);
            events_aligned.region = repmat({all_data(animal).region}, height(events_aligned), 1);
            events_table = [events_table; events_aligned]; %#ok<AGROW>
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region', 'syllable', 'condition_id'}, 'Before', 1);
    end
end

function in_trial = c03_get_trial_membership_mask(d, d_old)
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
function metric_table = c03_build_metric_table(events_table, signal_name, pre_mask, post_mask, metric_name)
    traces = c03_stack_trace_cells(events_table.(signal_name));
    if isempty(traces)
        metric_table = table();
        return;
    end

    if any(pre_mask)
        pre_mean = mean(traces(:, pre_mask), 2, 'omitnan');
        n_pre_samples = sum(~isnan(traces(:, pre_mask)), 2);
    else
        pre_mean = nan(size(traces, 1), 1);
        n_pre_samples = zeros(size(traces, 1), 1);
    end
    post_mean = mean(traces(:, post_mask), 2, 'omitnan');
    n_post_samples = sum(~isnan(traces(:, post_mask)), 2);
    if strcmp(metric_name, 'post_mean')
        response = post_mean;
    else
        response = post_mean - pre_mean;
    end

    metric_table = table();
    metric_table.animal = events_table.animal;
    metric_table.day = events_table.day;
    metric_table.region = events_table.region;
    metric_table.syllable = events_table.syllable;
    metric_table.condition_id = events_table.condition_id;
    metric_table.pre_mean = pre_mean;
    metric_table.post_mean = post_mean;
    metric_table.delta = response;
    metric_table.metric_name = repmat({metric_name}, height(metric_table), 1);
    metric_table.n_pre_samples = n_pre_samples;
    metric_table.n_post_samples = n_post_samples;
end

function summary_table = c03_summarize_metrics(metric_table, group_vars, min_events)
    if height(metric_table) == 0
        summary_table = table();
        return;
    end
    [group_idx, group_values] = findgroups(metric_table(:, group_vars));
    summary_table = group_values;
    summary_table.mean_delta = splitapply(@(x) mean(x, 'omitnan'), metric_table.delta, group_idx);
    summary_table.n_events = splitapply(@numel, metric_table.delta, group_idx);
    summary_table = summary_table(summary_table.n_events >= min_events, :);
end

function [complete_syllables, excluded_syllables] = c03_find_complete_syllables( ...
        animal_day_summary, events_table, syllables, days)
    complete_syllables = [];
    syllables = syllables(:)';
    days = days(:)';

    if isempty(animal_day_summary) || height(animal_day_summary) == 0 || ...
            isempty(events_table) || height(events_table) == 0
        excluded_syllables = syllables;
        return;
    end

    expected_animals = unique(events_table.animal)';
    n_expected = numel(expected_animals) * numel(days);
    if n_expected == 0
        excluded_syllables = syllables;
        return;
    end

    for syl = syllables
        sub = animal_day_summary(animal_day_summary.syllable == syl, :);
        if height(sub) ~= n_expected
            continue;
        end

        observed = unique([sub.animal, sub.day], 'rows');
        expected = zeros(n_expected, 2);
        row_idx = 0;
        for animal = expected_animals
            for day = days
                row_idx = row_idx + 1;
                expected(row_idx, :) = [animal, day];
            end
        end

        if size(observed, 1) == n_expected && all(ismember(expected, observed, 'rows'))
            complete_syllables(end + 1) = syl; %#ok<AGROW>
        end
    end

    excluded_syllables = setdiff(syllables, complete_syllables, 'stable');
end

function pooled_screens = c03_run_pooled_dayset_screens(metric_table, syllables, day_sets, ...
        day_labels, region_order, min_events)
    all_table = table();
    screen_tables = cell(numel(day_sets), 1);

    for i_set = 1:numel(day_sets)
        screen_table = c03_run_pooled_dayset_permutation(metric_table, syllables, ...
            day_sets{i_set}, i_set, day_labels{i_set}, region_order, min_events);
        screen_tables{i_set} = screen_table;
        if isempty(all_table)
            all_table = screen_table;
        else
            all_table = [all_table; screen_table]; %#ok<AGROW>
        end
    end

    pooled_screens = struct();
    pooled_screens.table = all_table;
    pooled_screens.by_dayset = screen_tables;
    pooled_screens.day_sets = day_sets;
    pooled_screens.day_labels = day_labels;
    pooled_screens.syllables = syllables(:)';
end

function results_table = c03_run_pooled_dayset_permutation(metric_table, syllables, day_set, ...
        day_set_idx, day_set_label, region_order, min_events)
    result_rows = repmat(c03_empty_perm_row(), numel(syllables), 1);
    sub_metric = metric_table(ismember(metric_table.day, day_set), :);
    animal_summary = c03_summarize_metrics(sub_metric, {'animal', 'region', 'syllable'}, min_events);

    for i_syl = 1:numel(syllables)
        syl = syllables(i_syl);
        row = c03_empty_perm_row();
        row.day_set_idx = day_set_idx;
        row.day_set_label = day_set_label;
        row.days = {day_set(:)'};
        row.syllable = syl;

        if height(animal_summary) == 0
            result_rows(i_syl) = row;
            continue;
        end

        syl_data = animal_summary(animal_summary.syllable == syl, :);
        lat_mask = strcmp(syl_data.region, region_order{1});
        med_mask = strcmp(syl_data.region, region_order{2});
        lat_vals = syl_data.mean_delta(lat_mask);
        med_vals = syl_data.mean_delta(med_mask);

        row.values_lat = {lat_vals(:)'};
        row.values_med = {med_vals(:)'};
        row.animals_lat = {syl_data.animal(lat_mask)'};
        row.animals_med = {syl_data.animal(med_mask)'};
        row.n_lat = numel(lat_vals);
        row.n_med = numel(med_vals);

        if ~isempty(lat_vals)
            row.mean_lat = mean(lat_vals, 'omitnan');
        end
        if ~isempty(med_vals)
            row.mean_med = mean(med_vals, 'omitnan');
        end
        if ~isempty(lat_vals) && ~isempty(med_vals)
            row.mean_diff = row.mean_med - row.mean_lat;
            row.abs_mean_diff = abs(row.mean_diff);
            row.effect_size = c03_pooled_effect_size(lat_vals, med_vals);
            [row.p_perm, row.n_perm, row.min_p_perm] = c03_exact_permutation_test(lat_vals, med_vals);
        end

        result_rows(i_syl) = row;
    end

    results_table = struct2table(result_rows);
    results_table.q_perm = c03_bh_fdr(results_table.p_perm);
end

function row = c03_empty_perm_row()
    row = struct();
    row.day_set_idx = NaN;
    row.day_set_label = '';
    row.days = {[]};
    row.syllable = NaN;
    row.n_lat = 0;
    row.n_med = 0;
    row.animals_lat = {[]};
    row.animals_med = {[]};
    row.values_lat = {[]};
    row.values_med = {[]};
    row.mean_lat = NaN;
    row.mean_med = NaN;
    row.mean_diff = NaN;
    row.abs_mean_diff = NaN;
    row.effect_size = NaN;
    row.p_perm = NaN;
    row.q_perm = NaN;
    row.min_p_perm = NaN;
    row.n_perm = 0;
end

function [p_value, n_perm, min_p_perm] = c03_exact_permutation_test(lat_vals, med_vals)
    n_lat = numel(lat_vals);
    n_med = numel(med_vals);
    all_vals = [lat_vals(:); med_vals(:)];

    if n_lat == 0 || n_med == 0
        p_value = NaN;
        n_perm = 0;
        min_p_perm = NaN;
        return;
    end

    obs_stat = mean(med_vals, 'omitnan') - mean(lat_vals, 'omitnan');
    med_combos = nchoosek(1:numel(all_vals), n_med);
    n_perm = size(med_combos, 1);
    perm_stats = nan(n_perm, 1);

    for i_perm = 1:n_perm
        med_idx = med_combos(i_perm, :);
        lat_idx = true(numel(all_vals), 1);
        lat_idx(med_idx) = false;
        perm_stats(i_perm) = mean(all_vals(med_idx), 'omitnan') - mean(all_vals(lat_idx), 'omitnan');
    end

    p_value = mean(abs(perm_stats) >= abs(obs_stat) - eps(abs(obs_stat)));
    max_abs_stat = max(abs(perm_stats));
    min_p_perm = mean(abs(perm_stats) >= max_abs_stat - eps(max_abs_stat));
end

function effect_size = c03_pooled_effect_size(lat_vals, med_vals)
    n_lat = numel(lat_vals);
    n_med = numel(med_vals);
    if n_lat == 0 || n_med == 0
        effect_size = NaN;
        return;
    end

    denom_df = n_lat + n_med - 2;
    if denom_df <= 0
        pooled_sd = std([lat_vals(:); med_vals(:)], 0, 1, 'omitnan');
    else
        pooled_sd = sqrt(((n_lat - 1) * var(lat_vals, 0, 1, 'omitnan') + ...
            (n_med - 1) * var(med_vals, 0, 1, 'omitnan')) / denom_df);
    end

    if isempty(pooled_sd) || isnan(pooled_sd) || pooled_sd == 0
        effect_size = NaN;
    else
        effect_size = (mean(med_vals, 'omitnan') - mean(lat_vals, 'omitnan')) / pooled_sd;
    end
end

%--------------------------------------------------------------------------
function lme_out = c03_run_lme(metric_table, syllables, region_order)
    lme_out = struct('requested', true, 'available', exist('fitlme', 'file') == 2, ...
        'warning', '', 'results', table());

    if ~lme_out.available
        lme_out.warning = 'fitlme is unavailable. Skipping LME analysis.';
        fprintf('%s\n', lme_out.warning);
        return;
    end

    result_rows = repmat(c03_empty_lme_row(), numel(syllables), 1);
    for i_syl = 1:numel(syllables)
        syl = syllables(i_syl);
        row = c03_empty_lme_row();
        row.syllable = syl;

        sub = metric_table(metric_table.syllable == syl, :);
        row.n_events = height(sub);
        row.n_animals = numel(unique(sub.animal));
        row.n_sessions = numel(unique(strcat("A", string(sub.animal), "_D", string(sub.day))));

        if height(sub) == 0
            row.status = 'no_events';
            result_rows(i_syl) = row;
            continue;
        end
        if numel(unique(string(sub.region))) < 2
            row.status = 'single_region_only';
            result_rows(i_syl) = row;
            continue;
        end
        if numel(unique(sub.animal)) < 2
            row.status = 'single_animal_only';
            result_rows(i_syl) = row;
            continue;
        end

        try
            sub.region = categorical(string(sub.region), region_order, region_order);
            sub.day = categorical(sub.day);
            sub.animal = categorical(sub.animal);
            sub.animal_day = categorical(strcat("A", string(sub.animal), "_D", string(sub.day)));

            lme = fitlme(sub, 'delta ~ region * day + (1|animal) + (1|animal_day)');
            a_tbl = anova(lme, 'DFMethod', 'Satterthwaite');
            term_labels = string(a_tbl.Term);
            region_idx = find(term_labels == "region", 1);
            day_idx = find(term_labels == "day", 1);
            interaction_idx = find(contains(term_labels, "region") & contains(term_labels, "day") & ...
                contains(term_labels, ":"), 1);

            row.fit_ok = true;
            row.status = 'ok';
            row.coefficients = {lme.Coefficients};
            row.anova_table = {a_tbl};
            if ~isempty(region_idx)
                row.p_region = a_tbl.pValue(region_idx);
            end
            if ~isempty(day_idx)
                row.p_day = a_tbl.pValue(day_idx);
            end
            if ~isempty(interaction_idx)
                row.p_interaction = a_tbl.pValue(interaction_idx);
            end
        catch ME
            row.status = ME.message;
        end

        result_rows(i_syl) = row;
    end

    results_table = struct2table(result_rows);
    results_table.q_region = c03_bh_fdr(results_table.p_region);
    results_table.q_day = c03_bh_fdr(results_table.p_day);
    results_table.q_interaction = c03_bh_fdr(results_table.p_interaction);
    lme_out.results = results_table;
end

function row = c03_empty_lme_row()
    row = struct( ...
        'syllable', NaN, ...
        'n_events', 0, ...
        'n_animals', 0, ...
        'n_sessions', 0, ...
        'fit_ok', false, ...
        'p_region', NaN, ...
        'p_day', NaN, ...
        'p_interaction', NaN, ...
        'q_region', NaN, ...
        'q_day', NaN, ...
        'q_interaction', NaN, ...
        'status', '', ...
        'coefficients', {{}}, ...
        'anova_table', {{}});
end

%--------------------------------------------------------------------------
function fig = c03_plot_pooled_screen(pooled_screens, opts, condition_label, sorted_syllables, cmap25)
    n_sets = numel(pooled_screens.by_dayset);
    [fig, tl] = myFigure(4, n_sets, 860, 820, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    title(tl, sprintf('%s pooled permutation screens', condition_label), 'Interpreter', 'none');

    for i_set = 1:n_sets
        tbl = pooled_screens.by_dayset{i_set};
        label = opts.pooled_day_labels{i_set};

        ax = nexttile(tl, i_set);
        p_tbl = c03_sort_valid(tbl, 'p_perm', 'ascend');
        c03_plot_pvalue_bars(ax, p_tbl, 'p_perm', sorted_syllables, cmap25);
        title(ax, sprintf('%s: p sorted', label), 'Interpreter', 'none');
        ylabel(ax, '-log10(p_{perm})');

        ax = nexttile(tl, n_sets + i_set);
        c03_plot_diff_bars(ax, p_tbl, sorted_syllables, cmap25);
        title(ax, sprintf('%s: diff in p order', label), 'Interpreter', 'none');
        ylabel(ax, sprintf('%s - %s', opts.region_order{2}, opts.region_order{1}), 'Interpreter', 'none');

        ax = nexttile(tl, 2 * n_sets + i_set);
        pos_tbl = c03_sort_valid(tbl, 'mean_diff', 'descend');
        c03_plot_diff_bars(ax, pos_tbl, sorted_syllables, cmap25);
        title(ax, sprintf('%s: positive first', label), 'Interpreter', 'none');
        ylabel(ax, 'Mean diff');

        ax = nexttile(tl, 3 * n_sets + i_set);
        neg_tbl = c03_sort_valid(tbl, 'mean_diff', 'ascend');
        c03_plot_diff_bars(ax, neg_tbl, sorted_syllables, cmap25);
        title(ax, sprintf('%s: negative first', label), 'Interpreter', 'none');
        ylabel(ax, 'Mean diff');
    end
end

function fig = c03_plot_lme_screen(lme_out, condition_label, sorted_syllables, cmap25, show_sorted_p_values)
    if show_sorted_p_values
        n_rows = 5;
    else
        n_rows = 3;
    end
    [fig, tl] = myFigure(n_rows, 1, 750, 630, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    title(tl, sprintf('%s LME screens', condition_label), 'Interpreter', 'none');

    if ~lme_out.available || isempty(lme_out.results)
        ax = nexttile(tl);
        text(ax, 0.5, 0.5, 'LME unavailable', 'HorizontalAlignment', 'center', ...
            'Units', 'normalized');
        return;
    end

    region_tbl = c03_sort_valid(lme_out.results, 'p_region', 'ascend');
    ax = nexttile(tl);
    c03_plot_pvalue_bars(ax, region_tbl, 'p_region', sorted_syllables, cmap25);
    title(ax, 'Region p sorted by region p');
    ylabel(ax, '-log10(region p)');

    if ~show_sorted_p_values
        day_tbl = c03_sort_valid(lme_out.results, 'p_day', 'ascend');
        ax = nexttile(tl);
        c03_plot_pvalue_bars(ax, day_tbl, 'p_day', sorted_syllables, cmap25);
        title(ax, 'Day p sorted by day p');
        ylabel(ax, '-log10(day p)');

        interaction_tbl = c03_sort_valid(lme_out.results, 'p_interaction', 'ascend');
        ax = nexttile(tl);
        c03_plot_pvalue_bars(ax, interaction_tbl, 'p_interaction', sorted_syllables, cmap25);
        title(ax, 'Interaction p sorted by interaction p');
        ylabel(ax, '-log10(interaction p)');
        return;
    end

    ax = nexttile(tl);
    c03_plot_pvalue_bars(ax, region_tbl, 'p_interaction', sorted_syllables, cmap25);
    title(ax, 'Interaction p in region-p order');
    ylabel(ax, '-log10(interaction p)');

    interaction_tbl = c03_sort_valid(lme_out.results, 'p_interaction', 'ascend');
    ax = nexttile(tl);
    c03_plot_pvalue_bars(ax, interaction_tbl, 'p_interaction', sorted_syllables, cmap25);
    title(ax, 'Interaction p sorted by interaction p');
    ylabel(ax, '-log10(interaction p)');

    ax = nexttile(tl);
    c03_plot_pvalue_bars(ax, region_tbl, 'p_day', sorted_syllables, cmap25);
    title(ax, 'Day p in region-p order');
    ylabel(ax, '-log10(day p)');

    day_tbl = c03_sort_valid(lme_out.results, 'p_day', 'ascend');
    ax = nexttile(tl);
    c03_plot_pvalue_bars(ax, day_tbl, 'p_day', sorted_syllables, cmap25);
    title(ax, 'Day p sorted by day p');
    ylabel(ax, '-log10(day p)');
end

function fig = c03_plot_followup_figure(selected_syllables, cond_out, opts, time_axis, ...
        region_colors, sorted_syllables, cmap25, fig_title)
    if isempty(selected_syllables)
        fig = [];
        return;
    end

    n_cols = 5;
    [fig, tl] = myFigure(numel(selected_syllables), n_cols, 310, 230, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    title(tl, fig_title, 'Interpreter', 'none');

    pooled_table = cond_out.pooled_screens.table;
    animal_colors = c03_animal_colors();

    for i_syl = 1:numel(selected_syllables)
        syl = selected_syllables(i_syl);
        syl_color = c03_get_syllable_color(syl, sorted_syllables, cmap25);
        syl_events = cond_out.events_table(cond_out.events_table.syllable == syl, :);

        ax = nexttile(tl);
        c03_plot_review_psth(ax, syl_events, opts.signal, time_axis, opts.region_order, region_colors);
        title(ax, sprintf('Syl %d PSTH', syl), 'Color', syl_color, 'Interpreter', 'none');

        ax_med = nexttile(tl);
        has_med = c03_plot_fip_psth_days(ax_med, syl_events, opts.signal, opts.region_order{2}, ...
            time_axis, true);
        title(ax_med, sprintf('Syl %d FIP Days Med', syl), 'Color', syl_color, 'Interpreter', 'none');
        ylabel(ax_med, opts.signal, 'Interpreter', 'none');

        ax_lat = nexttile(tl);
        has_lat = c03_plot_fip_psth_days(ax_lat, syl_events, opts.signal, opts.region_order{1}, ...
            time_axis, true);
        title(ax_lat, sprintf('Syl %d FIP Days Lat', syl), 'Color', syl_color, 'Interpreter', 'none');
        ylabel(ax_lat, opts.signal, 'Interpreter', 'none');
        c03_sync_axes([ax_med, ax_lat], [has_med, has_lat]);

        ax = nexttile(tl);
        c03_plot_daily_count_stack(ax, syl_events, opts.days, animal_colors);
        title(ax, sprintf('Syl %d daily counts', syl), 'Color', syl_color, 'Interpreter', 'none');

        ax = nexttile(tl);
        c03_plot_day_trajectory(ax, cond_out.animal_day_summary, pooled_table, ...
            cond_out.lme, syl, opts.region_order, region_colors);
        title(ax, sprintf('Syl %d across days', syl), 'Color', syl_color, 'Interpreter', 'none');
    end
end

function fig = c03_plot_p_values_corr_figure(cond_out, opts, region_colors, sorted_syllables, ...
        cmap25, condition_label)
    syllables_to_plot = opts.syllables(1:min(6, numel(opts.syllables)));
    if isempty(syllables_to_plot)
        fig = [];
        return;
    end

    [fig, tl] = myFigure(numel(syllables_to_plot), 1, 360, 220, true);
    tl.TileSpacing = 'compact';
    tl.Padding = 'compact';
    title(tl, sprintf('%s LME p/q across days', condition_label), 'Interpreter', 'none');

    pooled_table = cond_out.pooled_screens.table;
    for i_syl = 1:numel(syllables_to_plot)
        syl = syllables_to_plot(i_syl);
        syl_color = c03_get_syllable_color(syl, sorted_syllables, cmap25);
        ax = nexttile(tl);
        c03_plot_day_trajectory(ax, cond_out.animal_day_summary, pooled_table, ...
            cond_out.lme, syl, opts.region_order, region_colors);
        title(ax, sprintf('Syl %d across days', syl), 'Color', syl_color, ...
            'Interpreter', 'none');
    end
end

%--------------------------------------------------------------------------
function c03_plot_pvalue_bars(ax, tbl, p_field, sorted_syllables, cmap25)
    if isempty(tbl) || height(tbl) == 0
        text(ax, 0.5, 0.5, 'No valid p-values', 'HorizontalAlignment', 'center', ...
            'Units', 'normalized');
        return;
    end

    y_vals = -log10(max(tbl.(p_field), realmin));
    colors = c03_syllable_colors(tbl.syllable, sorted_syllables, cmap25);
    b = bar(ax, 1:height(tbl), y_vals, 'FaceColor', 'flat', 'EdgeColor', 'none');
    b.CData = colors;
    c03_label_syllable_axis(ax, tbl.syllable);
    yline(ax, -log10(0.05), 'k:', 'LineWidth', 0.75);
end

function c03_plot_diff_bars(ax, tbl, sorted_syllables, cmap25)
    if isempty(tbl) || height(tbl) == 0
        text(ax, 0.5, 0.5, 'No valid differences', 'HorizontalAlignment', 'center', ...
            'Units', 'normalized');
        return;
    end

    colors = c03_syllable_colors(tbl.syllable, sorted_syllables, cmap25);
    b = bar(ax, 1:height(tbl), tbl.mean_diff, 'FaceColor', 'flat', 'EdgeColor', 'none');
    b.CData = colors;
    yline(ax, 0, 'k-', 'LineWidth', 0.75);
    c03_label_syllable_axis(ax, tbl.syllable);
end

function c03_label_syllable_axis(ax, syllables)
    xticks(ax, 1:numel(syllables));
    xticklabels(ax, arrayfun(@(s) sprintf('%d', s), syllables, 'UniformOutput', false));
    xtickangle(ax, 45);
    xlim(ax, [0.25, numel(syllables) + 0.75]);
    set(ax, 'FontSize', 8);
end

function sorted_tbl = c03_sort_valid(tbl, field_name, direction)
    if isempty(tbl) || height(tbl) == 0 || ~ismember(field_name, tbl.Properties.VariableNames)
        sorted_tbl = table();
        return;
    end
    valid = ~isnan(tbl.(field_name));
    sorted_tbl = tbl(valid, :);
    if ~isempty(sorted_tbl)
        sorted_tbl = sortrows(sorted_tbl, field_name, direction);
    end
end

function selected_syllables = c03_select_lme_syllables(lme_out, p_field, top_n, fallback_table)
    selected_syllables = [];
    if lme_out.available && ~isempty(lme_out.results) && ismember(p_field, lme_out.results.Properties.VariableNames)
        valid_tbl = c03_sort_valid(lme_out.results, p_field, 'ascend');
        if ~isempty(valid_tbl)
            selected_syllables = valid_tbl.syllable(1:min(top_n, height(valid_tbl)))';
        end
    end

    if isempty(selected_syllables) && ~isempty(fallback_table) && ...
            ismember('day_set_idx', fallback_table.Properties.VariableNames)
        fallback = fallback_table(fallback_table.day_set_idx == 1, :);
        fallback = c03_sort_valid(fallback, 'p_perm', 'ascend');
        if ~isempty(fallback)
            selected_syllables = fallback.syllable(1:min(top_n, height(fallback)))';
        end
    end
end

function c03_plot_review_psth(ax, events_table, signal_name, time_axis, region_order, region_colors)
    if isempty(events_table) || ~ismember('day', events_table.Properties.VariableNames)
        text(ax, 0.5, 0.5, 'No events', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        return;
    end
    day1_events = events_table(events_table.day == 1, :);
    if height(day1_events) == 0
        text(ax, 0.5, 0.5, 'No day 1 events', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        return;
    end

    hold(ax, 'on');
    legend_handles = gobjects(0);
    legend_labels = {};
    for i_region = 1:numel(region_order)
        region_name = region_order{i_region};
        region_events = day1_events(strcmp(day1_events.region, region_name), :);
        if height(region_events) == 0; continue; end

        traces = c03_stack_trace_cells(region_events.(signal_name));
        if isempty(traces); continue; end
        [mean_trace, sem_trace, individual_traces] = c03_compute_animal_psth(region_events, traces);
        color = region_colors.(region_name);
        if ~isempty(individual_traces)
            plot(ax, time_axis, individual_traces', 'Color', [color 0.22], 'LineWidth', 0.6);
        end
        legend_handles(end + 1) = c03_plot_shaded(ax, time_axis, mean_trace, sem_trace, color, 0.14, 1.5); %#ok<AGROW>
        legend_labels{end + 1} = region_name; %#ok<AGROW>
    end
    xline(ax, 0, 'k:', 'LineWidth', 0.75);
    xlabel(ax, 'Time (s)');
    ylabel(ax, signal_name, 'Interpreter', 'none');
    xlim(ax, [time_axis(1), time_axis(end)]);
    if ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'FontSize', 8);
    end
    hold(ax, 'off');
end

function has_data = c03_plot_fip_psth_days(ax, events, signal_name, region_name, time_axis, show_legend)
    has_data = false;
    if height(events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    region_events = events(strcmp(events.region, region_name), :);
    if height(region_events) == 0
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    n_days = 5;
    day_colors = cool(n_days);
    day_colors = 0.65 * day_colors + 0.35 * repmat([0.45 0.45 0.45], n_days, 1);
    legend_handles = gobjects(0);
    legend_labels = {};

    hold(ax, 'on');
    for day = 1:n_days
        day_events = region_events(region_events.day == day, :);
        if height(day_events) == 0; continue; end
        traces = c03_stack_trace_cells(day_events.(signal_name));
        if isempty(traces); continue; end

        [mean_trace, sem_trace, animal_traces] = c03_compute_animal_psth(day_events, traces);
        n_animals = size(animal_traces, 1);
        h = c03_plot_shaded(ax, time_axis, mean_trace, sem_trace, day_colors(day, :), 0.10, 1.2);
        has_data = true;
        legend_handles(end + 1) = h; %#ok<AGROW>
        legend_labels{end + 1} = sprintf('D%d (n=%d)', day, n_animals); %#ok<AGROW>
    end

    if ~has_data
        text(ax, 0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end
    yline(ax, 0, 'k:', 'LineWidth', 0.25);
    xline(ax, 0, 'k:', 'LineWidth', 0.5);
    xlim(ax, [time_axis(1), time_axis(end)]);
    xlabel(ax, 'Time (s)');
    if show_legend && ~isempty(legend_handles)
        legend(ax, legend_handles, legend_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
    end
    hold(ax, 'off');
end

function c03_plot_daily_count_stack(ax, events, days, animal_colors)
    if isempty(events) || height(events) == 0
        text(ax, 0.5, 0.5, 'No events', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        return;
    end

    animals = unique(events.animal)';
    counts_matrix = c03_count_events_by_day_animal(events, days, animals);
    c03_plot_stacked_bar(ax, counts_matrix, animal_colors, days);
    ylabel(ax, 'Count');
    xlabel(ax, 'Day');
end

function counts_matrix = c03_count_events_by_day_animal(events, days, animals)
    counts_matrix = zeros(numel(days), numel(animals));
    if isempty(events) || height(events) == 0
        return;
    end
    for i_day = 1:numel(days)
        for i_animal = 1:numel(animals)
            counts_matrix(i_day, i_animal) = sum(events.day == days(i_day) & ...
                events.animal == animals(i_animal));
        end
    end
end

function c03_plot_stacked_bar(ax, counts_matrix, animal_colors, days)
    if any(counts_matrix(:) > 0)
        b = bar(ax, days, counts_matrix, 'stacked', 'EdgeColor', 'k', 'LineWidth', 0.5);
        for i_animal = 1:numel(b)
            b(i_animal).FaceColor = animal_colors(min(i_animal, size(animal_colors, 1)), :);
        end
    end
    xlim(ax, [min(days) - 0.5, max(days) + 0.5]);
    xticks(ax, days);
end

function c03_plot_day_trajectory(ax, animal_day_summary, pooled_table, lme_out, syllable_id, ...
        region_order, region_colors)
    if isempty(animal_day_summary) || ~ismember('syllable', animal_day_summary.Properties.VariableNames)
        text(ax, 0.5, 0.5, 'No day summaries', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        return;
    end
    sub = animal_day_summary(animal_day_summary.syllable == syllable_id, :);
    if isempty(sub)
        text(ax, 0.5, 0.5, 'No day summaries', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center');
        return;
    end

    day_vals = unique(sub.day)';
    hold(ax, 'on');
    for i_region = 1:numel(region_order)
        region_name = region_order{i_region};
        region_sub = sub(strcmp(sub.region, region_name), :);
        color = region_colors.(region_name);

        animals = unique(region_sub.animal)';
        for animal_id = animals
            animal_sub = region_sub(region_sub.animal == animal_id, :);
            [animal_days, order_idx] = sort(animal_sub.day);
            animal_mean = animal_sub.mean_delta(order_idx);
            plot(ax, animal_days, animal_mean, '-', 'Color', [color 0.2], 'LineWidth', 0.8);
        end

        mean_vals = nan(size(day_vals));
        sem_vals = nan(size(day_vals));
        for i_day = 1:numel(day_vals)
            dmask = region_sub.day == day_vals(i_day);
            vals = region_sub.mean_delta(dmask);
            if isempty(vals); continue; end
            mean_vals(i_day) = mean(vals, 'omitnan');
            if numel(vals) > 1
                sem_vals(i_day) = std(vals, 0, 1, 'omitnan') / sqrt(numel(vals));
            else
                sem_vals(i_day) = 0;
            end
        end
        errorbar(ax, day_vals, mean_vals, sem_vals, '-o', 'Color', color, ...
            'LineWidth', 1.6, 'MarkerFaceColor', color, 'CapSize', 0);
    end

    if ~isempty(pooled_table) && all(ismember({'day_set_idx', 'syllable', 'q_perm'}, ...
            pooled_table.Properties.VariableNames))
        day1_rows = pooled_table(pooled_table.day_set_idx == 2 & pooled_table.syllable == syllable_id, :);
        if ~isempty(day1_rows) && day1_rows.q_perm < 0.05
            yl = ylim(ax);
            plot(ax, 1, yl(2) - 0.05 * range(yl), 'k*', 'MarkerSize', 6, 'LineWidth', 0.8);
        end
    end

    text(ax, 0.03, 0.97, c03_lme_text(lme_out, syllable_id), 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 8);
    xlabel(ax, 'Day');
    ylabel(ax, 'Animal mean response');
    xticks(ax, day_vals);
    hold(ax, 'off');
end

function txt = c03_lme_text(lme_out, syllable_id)
    if ~lme_out.requested
        txt = 'LME not requested';
        return;
    end
    if ~lme_out.available
        txt = 'LME unavailable';
        return;
    end
    row = lme_out.results(lme_out.results.syllable == syllable_id, :);
    if isempty(row)
        txt = 'LME: no row';
        return;
    end
    txt = sprintf('region p=%.3g q=%.3g\nday p=%.3g q=%.3g\ninteraction p=%.3g q=%.3g', ...
        row.p_region, row.q_region, row.p_day, row.q_day, ...
        row.p_interaction, row.q_interaction);
end

%--------------------------------------------------------------------------
function [mean_trace, sem_trace, animal_traces] = c03_compute_animal_psth(events, traces)
    animals = unique(events.animal);
    animal_traces = nan(numel(animals), size(traces, 2));
    for i_animal = 1:numel(animals)
        mask = events.animal == animals(i_animal);
        animal_traces(i_animal, :) = mean(traces(mask, :), 1, 'omitnan');
    end
    mean_trace = mean(animal_traces, 1, 'omitnan');
    n_valid = sum(~isnan(animal_traces), 1);
    sem_trace = std(animal_traces, 0, 1, 'omitnan') ./ sqrt(n_valid);
    sem_trace(n_valid <= 1) = 0;
end

function traces = c03_stack_trace_cells(trace_cells)
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

function h = c03_plot_shaded(ax, x, mean_y, sem_y, color, sem_alpha, line_width)
    x = x(:)';
    mean_y = mean_y(:)';
    sem_y = sem_y(:)';
    valid_mask = ~isnan(x) & ~isnan(mean_y) & ~isnan(sem_y);
    x = x(valid_mask);
    mean_y = mean_y(valid_mask);
    sem_y = sem_y(valid_mask);

    if isempty(x)
        h = plot(ax, NaN, NaN, 'Color', color, 'LineWidth', line_width);
        return;
    end

    fill(ax, [x, fliplr(x)], [mean_y + sem_y, fliplr(mean_y - sem_y)], ...
        color, 'FaceAlpha', sem_alpha, 'EdgeColor', 'none');
    h = plot(ax, x, mean_y, 'Color', color, 'LineWidth', line_width);
end

function c03_sync_axes(ax_list, has_data)
    ax_list = ax_list(isgraphics(ax_list, 'axes'));
    if isempty(ax_list); return; end
    has_data = has_data(1:min(numel(has_data), numel(ax_list)));
    valid_axes = ax_list(has_data);
    if isempty(valid_axes); return; end
    y_limits = get(valid_axes, 'YLim');
    if iscell(y_limits)
        y_limits = cell2mat(y_limits);
    end
    if size(y_limits, 2) ~= 2
        y_limits = reshape(y_limits, [], 2);
    end
    shared_ylim = [min(y_limits(:, 1)), max(y_limits(:, 2))];
    if ~all(isfinite(shared_ylim)); return; end
    if shared_ylim(1) == shared_ylim(2)
        pad = max(abs(shared_ylim(1)) * 0.05, 1e-3);
        shared_ylim = shared_ylim + [-pad, pad];
    end
    set(valid_axes, 'YLim', shared_ylim);
    if numel(valid_axes) > 1
        linkaxes(valid_axes, 'y');
    end
end

function jitter = c03_spread_jitter(n_points, max_width)
    if n_points <= 1
        jitter = 0;
    else
        jitter = linspace(-max_width, max_width, n_points)';
    end
end

function q_values = c03_bh_fdr(p_values)
    q_values = nan(size(p_values));
    valid_mask = ~isnan(p_values);
    if ~any(valid_mask)
        return;
    end

    p_valid = p_values(valid_mask);
    [p_sorted, sort_idx] = sort(p_valid(:));
    n_tests = numel(p_sorted);
    q_sorted = p_sorted .* n_tests ./ (1:n_tests)';
    q_sorted = flipud(cummin(flipud(q_sorted)));
    q_sorted = min(q_sorted, 1);

    q_valid = nan(size(p_valid));
    q_valid(sort_idx) = q_sorted;
    q_values(valid_mask) = q_valid;
end

function out = c03_empty_condition_result()
    pooled_screens = struct();
    pooled_screens.table = table();
    pooled_screens.by_dayset = {};
    pooled_screens.day_sets = {};
    pooled_screens.day_labels = {};
    pooled_screens.syllables = [];

    lme = struct();
    lme.requested = true;
    lme.available = false;
    lme.warning = '';
    lme.results = table();

    figures = struct();
    figures.pooled_screen = [];
    figures.lme_screen = [];
    figures.followup_region = [];
    figures.followup_interaction = [];
    figures.followup_day = [];
    figures.p_values_corr = [];

    out = struct();
    out.condition_id = '';
    out.condition_label = '';
    out.warning = '';
    out.events_table = table();
    out.metric_table = table();
    out.animal_day_summary = table();
    out.animal_summary = table();
    out.complete_syllables = [];
    out.excluded_syllables = [];
    out.pooled_screens = pooled_screens;
    out.lme = lme;
    out.selected_syllables_region = [];
    out.selected_syllables_interaction = [];
    out.selected_syllables_day = [];
    out.figures = figures;
end

function [sorted_syllables, cmap25] = c03_get_syllable_colormap()
    if evalin('base', 'exist(''sorted_syllables'', ''var'')')
        sorted_syllables = evalin('base', 'sorted_syllables');
    else
        sorted_syllables = [];
    end
    if evalin('base', 'exist(''cmap25'', ''var'')')
        cmap25 = evalin('base', 'cmap25');
    else
        cmap25 = lines(25);
    end
end

function colors = c03_syllable_colors(syllables, sorted_syllables, cmap25)
    colors = zeros(numel(syllables), 3);
    for i_syl = 1:numel(syllables)
        colors(i_syl, :) = c03_get_syllable_color(syllables(i_syl), sorted_syllables, cmap25);
    end
end

function color = c03_get_syllable_color(syllable_id, sorted_syllables, cmap25)
    idx = find(sorted_syllables == syllable_id, 1);
    if ~isempty(idx) && idx <= size(cmap25, 1)
        color = cmap25(idx, :);
    else
        color = [0.5, 0.5, 0.5];
    end
end

function region_colors = c03_region_colors()
    region_colors = struct();
    region_colors.NAcLat = [17, 113, 190] / 255;
    region_colors.NAcMed = [221, 84, 0] / 255;
end

function animal_colors = c03_animal_colors()
    animal_colors = [
        0.18 0.18 0.18;
        0.34 0.34 0.34;
        0.50 0.50 0.50;
        0.66 0.66 0.66;
        0.82 0.82 0.82;
        0.20 0.48 0.52];
end

function values = c03_normalize_cellstr(values)
    if ischar(values) || isstring(values)
        values = cellstr(values);
    elseif iscell(values)
        values = cellfun(@char, values, 'UniformOutput', false);
    else
        error('Expected char, string, or cell array of strings.');
    end
end
