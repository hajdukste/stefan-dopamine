function events_table = f01_helper_get_hybrid_time_to_go_events(all_data, config, skip_animals_days)
% Extract hybrid time-to-go traces with a stitched reward-aligned tail
%
% config.pre_bins    - vector of positive time_to_go bin centers (e.g., 0.1:0.1:4)
% config.post_bins   - vector of post-reward elapsed bin centers (e.g., 0:0.1:1)
% config.trace_types - cell array of signals to extract (e.g., {'zsc_exp'})

    pre_bins = config.pre_bins(:)';
    post_bins = config.post_bins(:)';
    pre_bin_width = pre_bins(2) - pre_bins(1);
    post_bin_width = post_bins(2) - post_bins(1);
    trace_types = config.trace_types;

    events_table = table();

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], skip_animals_days, 'rows'); continue; end

            d = all_data(animal).data(day).d;
            d_old = all_data(animal).data(day).d_old;
            if isempty(d) || isempty(d_old); continue; end
            if ~ismember('time_to_go', d.Properties.VariableNames); continue; end
            if ~ismember('final_approach', d.Properties.VariableNames); continue; end
            if ~ismember('time', d.Properties.VariableNames); continue; end

            start_mask = strcmp(d_old.type, 'start_of_trial');
            end_mask = strcmp(d_old.type, 'end_of_trial');
            start_times = d_old.time(start_mask);
            end_times = d_old.time(end_mask);

            valid_sample_times = d.time(isfinite(d.time));
            if isempty(valid_sample_times); continue; end
            last_sample_time = valid_sample_times(end);

            n_trials_added = 0;
            for i_trial = 1:length(start_times)
                t_start = start_times(i_trial);
                t_end_idx = find(end_times > t_start, 1);
                if isempty(t_end_idx); continue; end
                t_end = end_times(t_end_idx);

                next_start_idx = find(start_times > t_end, 1);
                if isempty(next_start_idx)
                    next_trial_start = inf;
                else
                    next_trial_start = start_times(next_start_idx);
                end

                final_approach_mask = d.time >= t_start & d.time <= t_end & d.final_approach;
                if sum(final_approach_mask) < 10; continue; end

                post_limit = min([t_end + post_bins(end), next_trial_start, last_sample_time]);
                post_mask = d.time >= t_end & d.time <= post_limit;
                if isfinite(next_trial_start)
                    post_mask = post_mask & d.time < next_trial_start;
                end

                ttg = d.time_to_go(final_approach_mask);
                post_elapsed = d.time(post_mask) - t_end;

                row = struct();
                row.animal = animal;
                row.day = day;
                row.region = {all_data(animal).region};
                row.trial = i_trial;

                for i_trace = 1:length(trace_types)
                    trace_name = trace_types{i_trace};
                    if ~ismember(trace_name, d.Properties.VariableNames); continue; end

                    pre_signal = d.(trace_name)(final_approach_mask);
                    post_signal = d.(trace_name)(post_mask);

                    pre_binned = f01_helper_bin_hybrid_trace(ttg, pre_signal, pre_bins, pre_bin_width);
                    post_binned = f01_helper_bin_hybrid_trace(post_elapsed, post_signal, post_bins, post_bin_width);

                    % Negative x uses real post-reward seconds; positive x uses artificial time-to-go.
                    hybrid_trace = [fliplr(post_binned), pre_binned];
                    row.(trace_name) = {hybrid_trace};
                end

                row_table = struct2table(row);
                events_table = [events_table; row_table];
                n_trials_added = n_trials_added + 1;
            end

            if n_trials_added > 0
                fprintf('A%d D%d: %d hybrid time-to-go trials\n', animal, day, n_trials_added);
            end
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region'}, 'Before', 1);
    end
end

function binned_trace = f01_helper_bin_hybrid_trace(x_vals, signal, bin_centers, bin_width)
    binned_trace = nan(1, length(bin_centers));

    for i_bin = 1:length(bin_centers)
        bin_mask = abs(x_vals - bin_centers(i_bin)) < bin_width / 2;
        if any(bin_mask)
            binned_trace(i_bin) = mean(signal(bin_mask), 'omitnan');
        end
    end
end
