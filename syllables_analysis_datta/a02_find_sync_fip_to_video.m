
% sync video ttl_trace with fip reference column
plot_mode = 1; % 0 = full plots per animal/day, 1 = scatter-only into shared figure
animals = 1:6;
days = 1:5;

if plot_mode == 1
    [fig_scatter, tl_scatter] = myFigure(-length(animals)*length(days), [], 400, 300, true);
end

for animal = animals
for day = days

% skip bad recordings
if (animal == 1 && day == 3); continue; end

if (animal == 2 && day == 2) || (animal == 6 && day == 1)
    std_factor = 0.1;
elseif (animal == 5 && day == 3)
    std_factor = 2;
elseif (animal == 2 && day == 1)
    std_factor = 0.001;
elseif (animal == 3 && day == 1) || (animal == 4 && day == 1) || (animal == 2 && day == 1)
    std_factor = 0.0001;
elseif (animal == 5 && day == 1)
    std_factor = 0.5;
else
    std_factor = 1.5;
end

if (animal == 6 && day == 1)
    skip_last_video_ttl = 1;
else
    skip_last_video_ttl = 0;
end

fip = all_data(animal).data(day).fip;
fip_time = fip.time;
fip_ref = fip.reference;

ttl_trace = all_data(animal).data(day).ttl_data.ttl_trace;
ttl_time = all_data(animal).data(day).ttl_data.ttl_time;

% --- detect TTL events in fip reference (ground truth) ---
fip_onsets_idx = find(fip_ref > 0.5);
if length(fip_onsets_idx) > 1
    gaps = diff(fip_onsets_idx);
    keep = [true; gaps > 1];
    fip_onsets_idx = fip_onsets_idx(keep);
end
fip_onset_times = fip_time(fip_onsets_idx);
fip_first = fip_onset_times(1);
fip_last = fip_onset_times(end);

% --- detect first and last TTL in video trace ---
% smooth heavily to get clean ON/OFF blocks
% if ~(animal == 2 && day == 4)
% video_smooth = movmean(ttl_trace, 50);

% else
video_smooth = ttl_trace;
% end

thr_video = median(ttl_trace) + std_factor * std(ttl_trace);
video_binary = video_smooth > thr_video;
% find all rising edges
rising_edges = find(diff(video_binary) == 1) + 1;
if skip_last_video_ttl
    rising_edges = rising_edges(1:end-1);
end
video_first = ttl_time(rising_edges(1));
video_last = ttl_time(rising_edges(end));

fprintf('FIP:   first TTL = %.2f s, last TTL = %.2f s (%d pulses)\n', fip_first, fip_last, length(fip_onset_times));
fprintf('Video: first TTL = %.2f s, last TTL = %.2f s (%d edges)\n', video_first, video_last, length(rising_edges));

% --- linear time mapping: fip_time = a * video_time + b ---
a = (fip_last - fip_first) / (video_last - video_first);
b = fip_first - a * video_first;
fprintf('Mapping: fip_time = %.6f * video_time + %.4f\n', a, b);
fprintf('Time scale ratio: %.6f (should be ~1)\n', a);

% map all video times to fip clock
video_time_mapped = a * ttl_time + b;

% --- compute sync quality ---
video_edges_mapped = a * ttl_time(rising_edges) + b;
closest_dt_signed = zeros(length(fip_onset_times), 1);
for i = 1:length(fip_onset_times)
    diffs = video_edges_mapped - fip_onset_times(i);
    [~, idx] = min(abs(diffs));
    closest_dt_signed(i) = diffs(idx); % positive = video after fip
end
closest_dt = abs(closest_dt_signed);
good = closest_dt * 1000 < 500;
p = polyfit(fip_onset_times(good), closest_dt_signed(good) * 1000, 1);
drift_rate = p(1) * 1000; % ms per 1000s

if plot_mode == 1
    % scatter-only into shared figure
    ax2b = nexttile(tl_scatter);
    scatter(ax2b, fip_onset_times(good), closest_dt_signed(good) * 1000, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax2b, 'on');
    t_fit = linspace(min(fip_onset_times(good)), max(fip_onset_times(good)), 200);
    plot(ax2b, t_fit, polyval(p, t_fit), 'r-', 'LineWidth', 2);
    yline(ax2b, 0, 'k--');
    hold(ax2b, 'off');
    xlabel(ax2b, 'FIP time (s)');
    ylabel(ax2b, 'Video - FIP (ms)');
    title(ax2b, sprintf('A%d D%d drift: %.2f ms/1000s (n=%d/%d)', animal, day, drift_rate, sum(good), length(good)));
else
    % full plots
    % --- plot verification ---
    [fig, tl] = myFigure(4, 1, 2200, 300, true);

    ax1 = nexttile(tl);
    plot(ax1, ttl_time, ttl_trace, 'k', 'LineWidth', 0.5);
    hold(ax1, 'on');
    plot(ax1, ttl_time, video_smooth, 'b', 'LineWidth', 1.5);
    yline(ax1, thr_video, 'r--');
    plot(ax1, ttl_time(rising_edges), ttl_trace(rising_edges), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    xline(ax1, video_first, 'g-', 'LineWidth', 2);
    xline(ax1, video_last, 'g-', 'LineWidth', 2);
    hold(ax1, 'off');
    ylabel(ax1, 'Pixel intensity');
    title(ax1, 'Video TTL (green = first/last edge, blue = smoothed)');

    ax2 = nexttile(tl);
    plot(ax2, fip_time, fip_ref, 'k', 'LineWidth', 0.5);
    hold(ax2, 'on');
    plot(ax2, fip_onset_times, fip_ref(fip_onsets_idx), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    xline(ax2, fip_first, 'g-', 'LineWidth', 2);
    xline(ax2, fip_last, 'g-', 'LineWidth', 2);
    hold(ax2, 'off');
    ylabel(ax2, 'FIP reference');
    title(ax2, sprintf('FIP TTL reference (%d pulses, green = first/last)', length(fip_onset_times)));

    ax3 = nexttile(tl);
    yyaxis(ax3, 'left');
    plot(ax3, video_time_mapped, ttl_trace, 'b', 'LineWidth', 0.5);
    ylabel(ax3, 'Video pixel intensity');
    yyaxis(ax3, 'right');
    plot(ax3, fip_time, fip_ref, 'r', 'LineWidth', 0.5);
    ylabel(ax3, 'FIP reference');
    xlabel(ax3, 'FIP time (s)');
    title(ax3, 'Mapped video (blue) vs FIP reference (red)');

    ax4 = nexttile(tl);
    yyaxis(ax4, 'left');
    plot(ax4, video_time_mapped, ttl_trace, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
    hold(ax4, 'on');
    plot(ax4, video_edges_mapped, ttl_trace(rising_edges), 'v', 'Color', [0 0.5 1], 'MarkerFaceColor', [0 0.5 1], 'MarkerSize', 6);
    hold(ax4, 'off');
    ylabel(ax4, 'Video pixel intensity');
    ax4.YColor = [0 0.5 1];
    yyaxis(ax4, 'right');
    plot(ax4, fip_time, fip_ref, 'Color', [1 0.7 0.7], 'LineWidth', 0.5);
    hold(ax4, 'on');
    plot(ax4, fip_onset_times, fip_ref(fip_onsets_idx), '^', 'Color', [0.8 0 0], 'MarkerFaceColor', [0.8 0 0], 'MarkerSize', 6);
    hold(ax4, 'off');
    ylabel(ax4, 'FIP reference');
    ax4.YColor = [0.8 0 0];
    xlabel(ax4, 'FIP time (s)');
    title(ax4, 'Mapped video onsets (blue v) vs FIP onsets (red ^)');

    % --- sync quality figure ---
    [fig2, tl2] = myFigure(1, 2, 500, 350, true);
    ax = nexttile(tl2);
    binedges = linspace(0, 500, 30);
    histogram(ax, closest_dt * 1000, binedges);
    xlabel(ax, 'Closest video-FIP TTL distance (ms)');
    ylabel(ax, 'Count');
    title(ax, sprintf('Sync quality: median = %.1f ms, max = %.1f ms', median(closest_dt)*1000, max(closest_dt)*1000));

    ax2b = nexttile(tl2);
    scatter(ax2b, fip_onset_times(good), closest_dt_signed(good) * 1000, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax2b, 'on');
    t_fit = linspace(min(fip_onset_times(good)), max(fip_onset_times(good)), 200);
    plot(ax2b, t_fit, polyval(p, t_fit), 'r-', 'LineWidth', 2);
    yline(ax2b, 0, 'k--');
    hold(ax2b, 'off');
    xlabel(ax2b, 'FIP time (s)');
    ylabel(ax2b, 'Video - FIP (ms)');
    title(ax2b, sprintf('Clock drift: %.2f ms/1000s (n=%d/%d)', drift_rate, sum(good), length(good)));
end

% save sync mapping to all_data
sync = struct('a', a, 'b', b, 'video_time_mapped', video_time_mapped);
all_data(animal).data(day).sync = sync;
fprintf('Saved sync mapping to all_data(%d).data(%d).sync\n', animal, day);

end
end
