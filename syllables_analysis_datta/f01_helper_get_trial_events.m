function events_table = f01_helper_get_trial_events(all_data, config, skip_animals_days)
% Extract and align events from all_data
%
% config.event_type  - string, e.g. 'start_of_trial' or 'end_of_trial'
% config.align       - struct with .t_before, .t_after, .trace_types

    events_table = table();

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], skip_animals_days, 'rows'); continue; end

            d_old = all_data(animal).data(day).d_old;
            d = all_data(animal).data(day).d;

            if isempty(d_old) || isempty(d); continue; end
            if ~ismember('type', d_old.Properties.VariableNames); continue; end

            % find events in d_old
            event_mask = strcmp(d_old.type, config.event_type);
            if ~any(event_mask); continue; end
            event_times = d_old.time(event_mask);

            % find nearest indices in d
            time_idx = f01_helper_map_event_times_to_indices(d.time, event_times);

            if isempty(time_idx); continue; end

            % build events struct and align signals
            events = struct();
            events.time_idx = time_idx;
            events_aligned = f01_helper_align_signals(d, events, config.align);
            events_aligned = myStruct2Mat(events_aligned);

            n = height(events_aligned);
            if n == 0; continue; end

            events_aligned.animal = repmat(animal, n, 1);
            events_aligned.day = repmat(day, n, 1);
            events_aligned.region = repmat({all_data(animal).region}, n, 1);

            fprintf('A%d D%d: %d %s events\n', animal, day, n, config.event_type);
            events_table = [events_table; events_aligned];
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region'}, 'Before', 1);
    end
end

function time_idx = f01_helper_map_event_times_to_indices(sample_times, event_times)
    sample_times = sample_times(:);
    event_times = event_times(:);

    valid_mask = isfinite(sample_times);
    if ~any(valid_mask) || isempty(event_times)
        time_idx = zeros(0, 1);
        return;
    end

    valid_times = sample_times(valid_mask);
    valid_idx = find(valid_mask);

    [unique_times, unique_pos] = unique(valid_times, 'stable');
    unique_idx = valid_idx(unique_pos);

    [unique_times, sort_order] = sort(unique_times);
    unique_idx = unique_idx(sort_order);

    if isempty(unique_times)
        time_idx = zeros(0, 1);
    elseif numel(unique_times) == 1
        time_idx = repmat(unique_idx, size(event_times));
    else
        time_idx = interp1(unique_times, unique_idx, event_times, 'nearest', NaN);
    end

    time_idx = round(time_idx);
    time_idx = time_idx(isfinite(time_idx));
end
