function events_table = f01_helper_get_time_to_go_events(all_data, config, skip_animals_days)
% Extract time-to-go aligned traces from final approach periods
%
% config.time_bins     - vector of time_to_go bin centers (e.g., 0.1:0.1:10)
% config.trace_types   - cell array of signals to extract (e.g., {'fip_signal_corr'})

    time_bins = config.time_bins;
    n_bins = length(time_bins);
    bin_width = time_bins(2) - time_bins(1);
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

            % Get trial boundaries
            start_mask = strcmp(d_old.type, 'start_of_trial');
            end_mask = strcmp(d_old.type, 'end_of_trial');
            start_times = d_old.time(start_mask);
            end_times = d_old.time(end_mask);

            n_trials_added = 0;
            for i_trial = 1:length(start_times)
                t_start = start_times(i_trial);
                t_end_idx = find(end_times > t_start, 1);
                if isempty(t_end_idx); continue; end
                t_end = end_times(t_end_idx);

                % Get final approach frames for this trial
                trial_mask = d.time >= t_start & d.time <= t_end & d.final_approach;
                if sum(trial_mask) < 10; continue; end  % skip short trials

                ttg = d.time_to_go(trial_mask);

                % Build row for this trial
                row = struct();
                row.animal = animal;
                row.day = day;
                row.region = {all_data(animal).region};
                row.trial = i_trial;

                % Bin each trace type by time_to_go
                for i_trace = 1:length(trace_types)
                    trace_name = trace_types{i_trace};
                    if ~ismember(trace_name, d.Properties.VariableNames); continue; end

                    signal = d.(trace_name)(trial_mask);
                    binned_trace = nan(1, n_bins);

                    for i_bin = 1:n_bins
                        bin_mask = abs(ttg - time_bins(i_bin)) < bin_width/2;
                        if any(bin_mask)
                            binned_trace(i_bin) = mean(signal(bin_mask), 'omitnan');
                        end
                    end

                    % Store as cell (matching f01_helper_get_trial_events format)
                    row.(trace_name) = {binned_trace};
                end

                % Convert struct to table row and append
                row_table = struct2table(row);
                events_table = [events_table; row_table];
                n_trials_added = n_trials_added + 1;
            end

            if n_trials_added > 0
                fprintf('A%d D%d: %d time-to-go trials\n', animal, day, n_trials_added);
            end
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region'}, 'Before', 1);
    end
end
