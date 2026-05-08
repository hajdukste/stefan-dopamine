%% a07_show_4lights_timeseries
% Plot TTL traces (4 lights) grouped by recording date
% Each figure = one date, each row = one animal/day recording

% Collect all recordings and group by date

% gather all recordings with their dates
recordings = struct('animal', {}, 'day', {}, 'date', {});
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if isfield(all_data(animal).data(day), 'date') && ...
           isfield(all_data(animal).data(day), 'ttl_data2')
            rec.animal = animal;
            rec.day = day;
            rec.date = all_data(animal).data(day).date;
            recordings(end+1) = rec;
        end
    end
end

% get unique dates
all_dates = {recordings.date};
unique_dates = unique(all_dates);
fprintf('Found %d unique recording dates\n', length(unique_dates));

% Plot one figure per date

% for d = 1:length(unique_dates)
for d = 2
    this_date = unique_dates{d};

    % find all recordings on this date
    date_mask = strcmp({recordings.date}, this_date);
    date_recs = recordings(date_mask);
    n_recs = length(date_recs);

    fprintf('\nDate %s: %d recordings\n', this_date, n_recs);

    % create figure with one row per recording
    [fig, tl] = myFigure(n_recs, 1, 3800, 500, true);
    title(tl, sprintf('Date: %s', this_date));

    for r = 1:n_recs
        animal = date_recs(r).animal;
        day = date_recs(r).day;

        ttl_traces = all_data(animal).data(day).ttl_data2.ttl_traces;
        ttl_time = all_data(animal).data(day).ttl_data2.ttl_time;
        n_lights = size(ttl_traces, 2);

        % detect TTL onsets from d.reference (if available)
        d_table = all_data(animal).data(day).d;
        if ismember('reference', d_table.Properties.VariableNames)
            ref = d_table.reference;
            onset_idx = find(ref > 0.5);
            if length(onset_idx) > 1
                gaps = diff(onset_idx);
                keep = [true; gaps > 1];
                onset_idx = onset_idx(keep);
            end
            onset_times = ttl_time(onset_idx);
        else
            onset_times = [];
        end

        ax = nexttile(tl);
        hold(ax, 'on');

        % define colors for each light
        clear lines;
        colors = lines(4);

        for light = 1:n_lights
            plot(ax, ttl_time, ttl_traces(:, light), 'Color', colors(light, :), 'LineWidth', 0.5);
        end

        % add vertical red lines at TTL onsets
        if ~isempty(onset_times)
            xline(ax, onset_times, 'r-', 'LineWidth', 2.5, 'Alpha', 0.5);
        end

        hold(ax, 'off');
        ylabel(ax, 'Intensity');
        title(ax, sprintf('Animal %d, Day %d (%d lights, %d TTLs)', animal, day, n_lights, length(onset_times)));

        if r == n_recs
            xlabel(ax, 'Time (s)');
        end
    end
end

fprintf('\nDone. Created %d figures.\n', length(unique_dates));
