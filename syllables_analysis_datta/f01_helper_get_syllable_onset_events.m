function events_table = f01_helper_get_syllable_onset_events(all_data, config, skip_animals_days, syllable_list)
% Extract and align syllable onset events from all_data
%
% config.align       - struct with .t_before, .t_after, .trace_types
% config.epoch_filter - 'all_data', 'trial', or 'final_approach' (default: 'all_data')
% syllable_list      - which syllables to include (e.g., most_common_motifs(1:20))

    events_table = table();
    epoch_filter = 'all_data';
    if isfield(config, 'epoch_filter') && ~isempty(config.epoch_filter)
        epoch_filter = config.epoch_filter;
    end

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], skip_animals_days, 'rows'); continue; end

            d = all_data(animal).data(day).d;
            if isempty(d); continue; end
            if ~ismember('syllable', d.Properties.VariableNames); continue; end

            syl = d.syllable;

            % find syllable onsets (transitions where syllable changes)
            syl_diff = [1; diff(syl)];  % first frame counts as onset
            onset_mask = syl_diff ~= 0;

            % filter for syllables in the list
            onset_idx = find(onset_mask);
            onset_syl = syl(onset_idx);
            valid_mask = ismember(onset_syl, syllable_list);
            onset_idx = onset_idx(valid_mask);
            onset_syl = onset_syl(valid_mask);

            if ~strcmp(epoch_filter, 'all_data')
                d_old = all_data(animal).data(day).d_old;
                if isempty(d_old); continue; end

                epoch_mask = f01_helper_build_epoch_mask(d, d_old, epoch_filter);
                onset_keep = epoch_mask(onset_idx);
                onset_idx = onset_idx(onset_keep);
                onset_syl = onset_syl(onset_keep);
            end

            if isempty(onset_idx); continue; end

            % build events struct and align signals
            events = struct();
            events.time_idx = onset_idx;
            events.syllable = onset_syl;
            events_aligned = f01_helper_align_signals(d, events, config.align);
            events_aligned = myStruct2Mat(events_aligned);

            n = height(events_aligned);
            if n == 0; continue; end

            events_aligned.animal = repmat(animal, n, 1);
            events_aligned.day = repmat(day, n, 1);
            events_aligned.region = repmat({all_data(animal).region}, n, 1);

            fprintf('A%d D%d: %d syllable onset events\n', animal, day, n);
            events_table = [events_table; events_aligned];
        end
    end

    if height(events_table) > 0
        events_table = movevars(events_table, {'animal', 'day', 'region', 'syllable'}, 'Before', 1);
    end
end

function epoch_mask = f01_helper_build_epoch_mask(d, d_old, epoch_filter)
    if strcmp(epoch_filter, 'all_data')
        epoch_mask = true(height(d), 1);
        return;
    end

    end_mask = strcmp(d_old.type, 'end_of_trial');
    end_times = d_old.time(end_mask);

    switch epoch_filter
        case 'trial'
            start_mask = strcmp(d_old.type, 'start_of_trial');
        case 'final_approach'
            start_mask = strcmp(d_old.type, 'final_approach_start');
        otherwise
            error('Unknown epoch_filter: %s', epoch_filter);
    end

    start_times = d_old.time(start_mask);
    epoch_mask = false(height(d), 1);
    for i_start = 1:length(start_times)
        t_start = start_times(i_start);
        t_end_idx = find(end_times > t_start, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);
        epoch_mask = epoch_mask | (d.time >= t_start & d.time <= t_end);
    end
end
