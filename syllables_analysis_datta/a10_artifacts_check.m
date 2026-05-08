% a10_artifacts_check.m - detect signal drop artifacts in fiber photometry

threshold = 100;
flat_frames = 15; % ~0.5s at typical sampling rates

animals = 1:6;
days = 1:6;

all_artifacts = {};
session_labels = {};
sess_idx = 0;

if exist('loading_split_video', 'var') && loading_split_video
    animals = 1;
    days = 1:2;
    skip_list = [];
end

for animal = animals
    for day = days

        time = all_data(animal).data(day).fip.time;
        sig = all_data(animal).data(day).fip.signal;
        dt = median(diff(time));
        sig_diff = abs(diff(sig));

        starts = find(sig_diff > threshold);
        n = length(sig);
        artifacts = [];
        count = 0;

        for k = 1:length(starts)
            s = starts(k);
            % check if next flat_frames have ~zero diff (signal stuck)
            if s + flat_frames >= n; continue; end
            if sum(abs(diff(sig(s+1:s+flat_frames)))) == 0
                count = count + 1;
                a_start = time(s);
                % find where signal resumes (non-zero diff after artifact)
                resume = find(abs(diff(sig(s+1:end))) > 0, 1, 'first');
                if isempty(resume)
                    a_end = time(end);
                else
                    a_end = time(s + resume);
                end
                artifacts(count).start_idx = s;
                artifacts(count).start_time = a_start;
                artifacts(count).end_time = a_end;
                artifacts(count).duration = a_end - a_start;
                artifacts(count).before = sig(max(s-1, 1));
                artifacts(count).after = sig(min(s + resume + 1, n));
            end
        end

        % linear interpolation across artifacts
        sig_clean = sig;
        for ja = 1:length(artifacts)
            si_idx = artifacts(ja).start_idx;
            % find end index
            resume = find(abs(diff(sig(si_idx+1:end))) > 0, 1, 'first');
            if isempty(resume); ei_idx = n; else; ei_idx = si_idx + resume; end
            % interpolate from sample before to sample after
            i0 = max(si_idx, 1);
            i1 = min(ei_idx + 1, n);
            sig_clean(i0:i1) = linspace(sig(i0), sig(i1), i1 - i0 + 1);
        end
        all_data(animal).data(day).fip.signal_artcorr = sig_clean;

        sess_idx = sess_idx + 1;
        label = sprintf('%s d%d', all_data(animal).name, day);
        session_labels{sess_idx} = label;
        all_artifacts{sess_idx} = artifacts;

        if isempty(artifacts)
            fprintf('%s: no artifacts\n', label);
        else
            durations = [artifacts.duration];
            total_dur = sum(durations);
            rec_dur = time(end) - time(1);
            base_unit = median(durations);
            replications = round(durations / base_unit);
            remainders = abs(mod(durations + 0.15, base_unit) - 0.2);

            fprintf('%s: %d artifacts (%.2f%s of recording, base unit %.2fs, max error %.2fs)\n', ...
                label, count, 100 * total_dur / rec_dur, char(37), base_unit, max(remainders));
        end
    end
end

% plot sessions that have artifacts
has_artifacts = find(~cellfun(@isempty, all_artifacts));
if isempty(has_artifacts)
    fprintf('\nNo artifacts found in any session.\n');
else
    % figure 1: full traces with artifact regions marked
    [fig1, tl1] = myFigure(-length(has_artifacts), [], 500, 200, true);
    title(tl1, 'Signal with artifact regions');
    for ii = 1:length(has_artifacts)
        si = has_artifacts(ii);
        arts = all_artifacts{si};

        % find which animal/day this corresponds to
        idx2 = 0;
        for animal = animals
            for day = 1:length(all_data(animal).data)
                if isempty(all_data(animal).data(day).fip); continue; end
                idx2 = idx2 + 1;
                if idx2 == si
                    time = all_data(animal).data(day).fip.time;
                    sig = all_data(animal).data(day).fip.signal;
                end
            end
        end

        nexttile(tl1);
        hold on;
        plot(time, sig, 'k', 'LineWidth', 0.5);
        yl = [min(sig) max(sig)];
        art_times = arrayfun(@(x) x.start_time, arts);
        plot(art_times, repmat(yl(2), size(art_times)), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        title(sprintf('%s (%d artifacts)', session_labels{si}, length(arts)));
        xlabel('time (s)');
    end

    % figure 2: zoom into each artifact (up to 20)
    all_art_list = [];
    all_art_labels = {};
    for ii = 1:length(has_artifacts)
        si = has_artifacts(ii);
        arts = all_artifacts{si};
        for a = 1:length(arts)
            all_art_list(end+1).si = si;
            all_art_list(end).art = arts(a);
            all_art_labels{end+1} = sprintf('%s #%d', session_labels{si}, a);
        end
    end

    n_zoom = length(all_art_list);
    [fig2, tl2] = myFigure(-n_zoom, [], 300, 150, true);
    title(tl2, 'Artifact zoom');
    for ii = 1:n_zoom
        si = all_art_list(ii).si;
        art = all_art_list(ii).art;

        idx2 = 0;
        for animal = animals
            for day = 1:length(all_data(animal).data)
                if isempty(all_data(animal).data(day).fip); continue; end
                idx2 = idx2 + 1;
                if idx2 == si
                    time = all_data(animal).data(day).fip.time;
                    sig = all_data(animal).data(day).fip.signal;
                    sig_corr = all_data(animal).data(day).fip.signal_artcorr;
                end
            end
        end

        margin = max(art.duration * 2, 1);
        t0 = art.start_time - margin;
        t1 = art.end_time + margin;
        mask = time >= t0 & time <= t1;

        nexttile(tl2);
        hold on;
        plot(time(mask), sig(mask), 'k', 'LineWidth', 0.5);
        plot(time(mask), sig_corr(mask), 'b', 'LineWidth', 1);
        xline(art.start_time, 'r', 'LineWidth', 1);
        xline(art.end_time, 'r', 'LineWidth', 1);
        title(sprintf('%s (%.2fs)', all_art_labels{ii}, art.duration));
        xlabel('time (s)');
    end
end
