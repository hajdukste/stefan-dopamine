% a12_final_check_traces.m
% Final check of traces - one figure per recording date
% Each row = one session from that date

plot_mode = 'ttls';  % 'ttls', 'fip', or 'ttls_errors'

% Collect all recordings and group by date
recordings = struct('animal', {}, 'day', {}, 'date', {});
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if isfield(all_data(animal).data(day), 'date') && ...
           isfield(all_data(animal).data(day), 'd') && ...
           isfield(all_data(animal).data(day), 'd_old')
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
for d = 5
    this_date = unique_dates{d};

    % find all recordings on this date
    date_mask = strcmp({recordings.date}, this_date);
    date_recs = recordings(date_mask);
    n_recs = length(date_recs);

    fprintf('\nDate %s: %d recordings\n', this_date, n_recs);

    % create figure with one row per recording
    [fig, tl] = myFigure(n_recs, 1, 3200, 300, true);
    title(tl, sprintf('Date: %s', this_date));

    for r = 1:n_recs
        animal = date_recs(r).animal;
        day = date_recs(r).day;

        d = all_data(animal).data(day).d;
        d_old = all_data(animal).data(day).d_old;

        % get start_of_trial times from d_old
        start_mask = strcmp(d_old.type, 'start_of_trial');
        start_times = d_old.time(start_mask);

        ax = nexttile(tl);
        hold(ax, 'on');

        if strcmp(plot_mode, 'fip')
            % plot fip_signal_corr (black)
            plot(ax, d.time, d.fip_signal_corr, 'k', 'LineWidth', 0.5);

            % start_of_trial vertical lines (magenta, full height)
            y_lim = ylim(ax);
            for t = start_times'
                plot(ax, [t t], y_lim, 'm-', 'LineWidth', 1);
            end

            hold(ax, 'off');
            ylabel(ax, sprintf('A%d D%d', animal, day));
            title(ax, sprintf('A%d D%d: %d trials', animal, day, length(start_times)));

        elseif strcmp(plot_mode, 'ttls')
            % get ref_onsets (fip_ttl_onset) and ttl_meta times from d
            ref_onset_times = d.time(d.fip_ttl_onset);
            ttl_meta_times = d.time(d.ttl_meta);

            % find ref_onsets_not_found (fip_ttl_onset that don't match ttl_meta)
            match_tolerance = 0.5;
            ref_onsets_not_found = [];
            for t = ref_onset_times'
                if isempty(ttl_meta_times) || min(abs(ttl_meta_times - t)) > match_tolerance
                    ref_onsets_not_found(end+1) = t;
                end
            end

            % plot reference signal (black)
            plot(ax, d.time, d.fip_reference, 'k', 'LineWidth', 0.5);

            % red triangles at ref_onsets (y=0.5)
            plot(ax, ref_onset_times, 0.5*ones(size(ref_onset_times)), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 6);

            y_lim = [0 1];
            y_mid = 0.5;

            % TOP HALF: start_of_trial vertical lines (magenta)
            for t = start_times'
                plot(ax, [t t], [y_mid y_lim(2)], 'm-', 'LineWidth', 1);
            end

            % BOTTOM HALF: ttl_meta vertical lines (green)
            for t = ttl_meta_times'
                plot(ax, [t t], [y_lim(1) y_mid], 'g-', 'LineWidth', 1);
            end

            % BOTTOM HALF: ref_onsets_not_found (red dashed)
            for t = ref_onsets_not_found
                plot(ax, [t t], [y_lim(1) y_mid], 'r--', 'LineWidth', 1.5);
            end

            hold(ax, 'off');
            ylim(ax, [-0.1 1.1]);
            ylabel(ax, sprintf('A%d D%d', animal, day));
            n_not_found = length(ref_onsets_not_found);
            n_fip = length(ref_onset_times);
            n_meta = length(ttl_meta_times);
            n_trials = length(start_times);
            counts = [n_fip, n_meta, n_trials];
            diff_count = max(counts) - min(counts);
            title(ax, sprintf('(%d) A%d D%d: fip ttl=%d (red tri), ttl meta=%d (grn), trials=%d (mag), not found=%d (red dash)', ...
                diff_count, animal, day, n_fip, n_meta, n_trials, n_not_found), ...
                'Interpreter', 'none');

        elseif strcmp(plot_mode, 'ttls_errors')
            % scatter error between fip_ttl_onset and ttl_meta
            ref_onset_times = d.time(d.fip_ttl_onset);
            ttl_meta_times = d.time(d.ttl_meta);

            % for each ref_onset, find closest ttl_meta and compute error
            ttl_error_ms = zeros(length(ref_onset_times), 1);
            for i = 1:length(ref_onset_times)
                if isempty(ttl_meta_times)
                    ttl_error_ms(i) = NaN;
                else
                    diffs = ttl_meta_times - ref_onset_times(i);
                    [~, idx] = min(abs(diffs));
                    ttl_error_ms(i) = diffs(idx) * 1000;  % in ms
                end
            end

            % filter out large errors for plotting
            good_mask = abs(ttl_error_ms) < 500;
            x_data = ref_onset_times(good_mask);
            y_data = ttl_error_ms(good_mask);

            scatter(ax, x_data, y_data, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
            hold(ax, 'on');

            % fit and plot trend line
            if sum(good_mask) >= 2
                p = polyfit(x_data, y_data, 1);
                t_fit = linspace(min(x_data), max(x_data), 200);
                plot(ax, t_fit, polyval(p, t_fit), 'r-', 'LineWidth', 2);
            end

            yline(ax, 0, 'k--');
            hold(ax, 'off');

            ylabel(ax, sprintf('A%d D%d', animal, day));
            xlabel(ax, 'Time (s)');

            median_err = median(abs(y_data));
            max_err = max(abs(y_data));
            n_fip = length(ref_onset_times);
            n_meta = length(ttl_meta_times);
            title(ax, sprintf('A%d D%d: median=%.1fms, max=%.1fms, fip=%d, meta=%d', ...
                animal, day, median_err, max_err, n_fip, n_meta));
        end
    end
end
