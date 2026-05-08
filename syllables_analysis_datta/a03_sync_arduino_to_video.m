
% sync start_of_trial events (d_old) with fip reference column (d.reference)
plot_mode = 1; % 0 = full plots per animal/day, 1 = scatter-only into shared figure
interpolate_arduino = 1; % if 1, add interpolated time column to d_old
animals = 1:6;
days = 1:5;

if plot_mode == 1
    [fig_scatter, tl_scatter] = myFigure(-length(animals)*length(days), [], 400, 300, true);
end

for animal = animals
for day = days

% skip bad recordings
if ismember([animal, day], skip_animals_days, 'rows'); continue; end

d = all_data(animal).data(day).d;
d_old = all_data(animal).data(day).d_old;

if isempty(d) || isempty(d_old); continue; end
if ~ismember('type', d_old.Properties.VariableNames); continue; end
if ~ismember('reference', d.Properties.VariableNames); continue; end

d_time = d.time;
d_ref = d.reference;

% --- detect start_of_trial events from d_old (ground truth) ---
trial_mask = strcmp(d_old.type, 'start_of_trial');
trial_times = d_old.arduino_time(trial_mask);

if isempty(trial_times)
    fprintf('A%d D%d: No start_of_trial events found\n', animal, day);
    continue;
end

trial_first = trial_times(1);
trial_last = trial_times(end);

% --- detect TTL events in d.reference ---
ref_onsets_idx = find(d_ref > 0.5);
if length(ref_onsets_idx) > 1
    gaps = diff(ref_onsets_idx);
    keep = [true; gaps > 1];
    ref_onsets_idx = ref_onsets_idx(keep);
end
ref_onset_times = d_time(ref_onsets_idx);
ref_first = ref_onset_times(1);
ref_last = ref_onset_times(end);

fprintf('Trial: first = %.2f s, last = %.2f s (%d events)\n', trial_first, trial_last, length(trial_times));
fprintf('Ref:   first = %.2f s, last = %.2f s (%d pulses)\n', ref_first, ref_last, length(ref_onset_times));

% --- linear time mapping: ref_time = a * trial_time + b ---
a = (ref_last - ref_first) / (trial_last - trial_first);
b = ref_first - a * trial_first;
fprintf('Mapping: ref_time = %.6f * trial_time + %.4f\n', a, b);
fprintf('Time scale ratio: %.6f (should be ~1)\n', a);

% map all trial times to ref clock
trial_time_mapped = a * trial_times + b;

% --- compute sync quality ---
closest_dt_signed = zeros(length(ref_onset_times), 1);
for i = 1:length(ref_onset_times)
    diffs = trial_time_mapped - ref_onset_times(i);
    [~, idx] = min(abs(diffs));
    closest_dt_signed(i) = diffs(idx); % positive = trial after ref
end
closest_dt = abs(closest_dt_signed);
good = closest_dt * 1000 < 500;
if sum(good) < 2
    fprintf('A%d D%d: Not enough good matches for drift fit\n', animal, day);
    continue;
end
p = polyfit(ref_onset_times(good), closest_dt_signed(good) * 1000, 1);
drift_rate = p(1) * 1000; % ms per 1000s

if plot_mode == 1
    % scatter-only into shared figure
    ax2b = nexttile(tl_scatter);
    scatter(ax2b, ref_onset_times(good), closest_dt_signed(good) * 1000, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax2b, 'on');
    t_fit = linspace(min(ref_onset_times(good)), max(ref_onset_times(good)), 200);
    plot(ax2b, t_fit, polyval(p, t_fit), 'r-', 'LineWidth', 2);
    yline(ax2b, 0, 'k--');
    hold(ax2b, 'off');
    xlabel(ax2b, 'Ref time (s)');
    ylabel(ax2b, 'Trial - Ref (ms)');
    title(ax2b, sprintf('A%d D%d drift: %.2f ms/1000s (n=%d/%d)', animal, day, drift_rate, sum(good), length(good)));
else
    % full plots
    [fig, tl] = myFigure(4, 1, 2200, 300, true);

    % row 1: arduino_time (raw trial events in arduino time)
    ax1 = nexttile(tl);
    hold(ax1, 'on');
    for tt = trial_times'
        xline(ax1, tt, 'b-', 'LineWidth', 1);
    end
    xline(ax1, trial_first, 'g-', 'LineWidth', 2);
    xline(ax1, trial_last, 'g-', 'LineWidth', 2);
    hold(ax1, 'off');
    ylabel(ax1, 'Arduino time');
    title(ax1, sprintf('start_of_trial in arduino_time (%d events, green = first/last)', length(trial_times)));
    xlim(ax1, [trial_first - 10, trial_last + 10]);

    % row 2: d.reference with detected pulses
    ax2 = nexttile(tl);
    plot(ax2, d_time, d_ref, 'k', 'LineWidth', 0.5);
    hold(ax2, 'on');
    plot(ax2, ref_onset_times, d_ref(ref_onsets_idx), 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 4);
    xline(ax2, ref_first, 'g-', 'LineWidth', 2);
    xline(ax2, ref_last, 'g-', 'LineWidth', 2);
    hold(ax2, 'off');
    ylabel(ax2, 'Reference');
    title(ax2, sprintf('d.reference (%d pulses, green = first/last)', length(ref_onset_times)));

    % row 3: aligned trial events (arduino_time mapped to ref time)
    ax3 = nexttile(tl);
    plot(ax3, d_time, d_ref, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    hold(ax3, 'on');
    for tt = trial_time_mapped'
        xline(ax3, tt, 'b-', 'LineWidth', 1);
    end
    hold(ax3, 'off');
    ylabel(ax3, 'Reference + aligned trials');
    title(ax3, sprintf('start_of_trial mapped to ref time (blue lines)'));
    linkaxes([ax2, ax3], 'x');

    ax4 = nexttile(tl);
    scatter(ax4, ref_onset_times(good), closest_dt_signed(good) * 1000, 15, 'k', 'filled', 'MarkerFaceAlpha', 0.5);
    hold(ax4, 'on');
    t_fit = linspace(min(ref_onset_times(good)), max(ref_onset_times(good)), 200);
    plot(ax4, t_fit, polyval(p, t_fit), 'r-', 'LineWidth', 2);
    yline(ax4, 0, 'k--');
    hold(ax4, 'off');
    xlabel(ax4, 'Ref time (s)');
    ylabel(ax4, 'Trial - Ref (ms)');
    title(ax4, sprintf('Clock drift: %.2f ms/1000s (n=%d/%d)', drift_rate, sum(good), length(good)));
end

% save sync mapping to all_data
sync_arduino = struct('a', a, 'b', b, 'trial_times', trial_times, 'trial_time_mapped', trial_time_mapped);
all_data(animal).data(day).sync_arduino = sync_arduino;
fprintf('Saved sync mapping to all_data(%d).data(%d).sync_arduino\n', animal, day);

% add interpolated time column to d_old
if interpolate_arduino
    d_old.time = a * d_old.arduino_time + b;
    all_data(animal).data(day).d_old = d_old;
    fprintf('Added d_old.time (arduino_time mapped to ref time)\n');
end

end
end
