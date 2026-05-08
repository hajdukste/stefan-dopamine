function length_str = a01x_new_plotting_trials_long(day, animal, all_data, normalised_speed, sign_sero, start_seconds, seconds_per_row, moving_window_size, show_predicted, no_images, ser_ylim)


fake_all_data = all_data(animal).data(day).d;

trial_posit = fake_all_data.trial_posit;
trial_number_arr = fake_all_data.trial;
max_trial = max(trial_number_arr);
if no_images == 0
    corri = fake_all_data.corri;
end
ttl = fake_all_data.ttl;
% reward = fake_all_data.reward;
time = seconds(fake_all_data.time);
if show_predicted
    predSero = fake_all_data.predSeroDay;
end

ser = fake_all_data.zsc_exp;
ser_norm = ser;
facemotion = movmean(normalize(fake_all_data.facemotion2), 20);
speed = fake_all_data.speed;
if ismember('speed_nose_tip', all_data(animal).data(day).d.Properties.VariableNames); facemotion = movmean(all_data(animal).data(day).d.speed_nose_tip/2,5); end

if moving_window_size(2) > 0
    speed = movmean(speed, 3);
    speed_norm = normalize(speed);
    speed = movmean(speed, moving_window_size(2));
    speed_norm = movmean(speed_norm, moving_window_size(2));
end
if moving_window_size(1) > 0
    ser_norm = movmean(ser_norm, moving_window_size(1));
end
if moving_window_size(3) > 0
    facemotion = movmean(facemotion, moving_window_size(3));
    pupil = normalize(fake_all_data.pupil);
end


thresholds = [80, 150, 220, 290, 360, 350, 370]; % Define the thresholds
flags = zeros(1, length(thresholds)); % Initialize flags for each threshold
reached = zeros(length(trial_posit), length(thresholds)); % Initialize output arrays

for i = 1:length(trial_posit)
    for j = 1:length(thresholds)
        if trial_posit(i) >= thresholds(j) && flags(j) == 0
            reached(i, j) = 1; % Mark as reached for the corresponding threshold
            flags(j) = 1;
        elseif trial_posit(i) < 10
            flags(j) = 0; % Reset flag if position drops below 10
        end
    end
end

% is_still_after_im = a19z_get_is_still_after_image(animal, day, fake_all_data);
% plot(is_still_after_im(start_idx:end_idx))

hold on
yyaxis left
ax = gca;
ax.LineStyleOrder = {'-'};
if sign_sero == -1
    ylabel("MINUS dF/F0");
else
    ylabel("dF/F0");
end
ylim(ser_ylim)

if moving_window_size(1) ~= -1
    plot(time, sign_sero * ser_norm, 'Color', 'b');
end

if show_predicted == 1
    plot(time, sign_sero*predSero, 'Color', 'm', 'LineStyle', '-')
end

if moving_window_size(3) ~= -1
    plot(time, facemotion, 'Color', 'g')
end

yyaxis right
ax = gca;
ax.LineStyleOrder = {'-'};
ylabel("Speed [cm/s]")
ylim([-5, 60])

if moving_window_size(2) ~= -1
    if normalised_speed == 0
        plot(time, speed);
    else
        plot(time, speed_norm);
    end
end



% smooth_speed_max_min = movmean(speed, 50);
% localMinIdx = find(islocalmin(smooth_speed_max_min));
% localMaxIdx = find(islocalmax(smooth_speed_max_min));
% plot(time, smooth_speed_max_min(localMaxIdx), 'r.', 'MarkerSize', 20);
% plot(time, smooth_speed_max_min(localMinIdx), 'b.', 'MarkerSize', 20);
%
% yyaxis right
% ax = gca;
% ax.LineStyleOrder = {'-'};
% ax.YColor = 'g';
% ylabel("Face motion (z-scored)")
% ylim([-3.5, 3.5])
% plot(time, facemotion, 'Color', 'g')


% yyaxis left
% ax1 = gca; % Current axes
% ax2 = axes('Position', ax1.Position, ...
%     'XAxisLocation', 'bottom', ...
%     'YAxisLocation', 'left', ...
%     'Color', 'none', ...
%     'XColor', 'k', 'YColor', 'g', ...
%     'YTick', [-3, 0, 3], ... % Hide y-ticks on the third axis
%     'XTick', []); % Hide x-ticks on the third axis
%
% % Explicitly match the x-axis type and limits of ax2 to ax1
% hold(ax2, 'on');
% plot(ax2, time, zeros(size(time)), 'Color', 'none'); % Dummy plot to set x-axis type
% ax2.XLim = ax1.XLim; % Match limits
% linkaxes([ax1, ax2], 'x');
% ylabel(ax2, 'Facemotion (std)');
% plot(time, facemotion, 'Color', 'g', 'Parent', ax2)
%
% ylim([-2, 2])


xlim([seconds(start_seconds), seconds(start_seconds + seconds_per_row)])

% line([start_seconds, start_seconds + seconds_per_row], [30, 30], 'Color', 'k', 'LineStyle', '--');
ylima = get(gca, 'YLim');



idxs = arrayfun(@(x) find(reached(:, x) == 1), [1:7], 'UniformOutput', false);

for idx = 1:length(idxs{1})-1
    [idx80, idx150, idx220, idx290, idx360, idx_before, idx_after] = deal(idxs{1}(idx), idxs{2}(idx), idxs{3}(idx), idxs{4}(idx), idxs{5}(idx), idxs{6}(idx), idxs{7}(idx));
    if no_images == 0
        if mod(corri(idx80), 2) == 1
            color_rew = 'blue';
            color_im = 'cyan';
        else
            color_rew = [0.3137 0.7804 0];
            color_im = [0.5804 1 0.5804];
        end
    end

    if day ~= 11 && no_images == 0
        patch([time(idx80), time(idx80), time(idx150), time(idx150)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        patch([time(idx220), time(idx220), time(idx290), time(idx290)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    if no_images == 0
        patch([time(idx_before), time(idx_before), time(idx_after), time(idx_after)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_rew, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
end


fake_indices = find(ttl == 1);
indices = [];
for idx = 1:length(fake_indices)
    if idx == 1 || fake_indices(idx) > fake_indices(idx-1) + 1 %not directly after the previous index
        indices = [indices fake_indices(idx)];
    end
end

[~, closestIndexStart] = min(abs(time - seconds(start_seconds)));
[~, closestIndexStop] = min(abs(time - seconds(start_seconds + seconds_per_row)));
start_idx = trial_number_arr(closestIndexStart);
stop_idx = trial_number_arr(closestIndexStop);

% for idx = 1:length(indices)-1
for idx = start_idx:stop_idx
    line([time(indices(idx)), time(indices(idx))], ylima, 'Color', 'black', 'LineStyle', '--');
    if idx <= length(trial_number_arr) - 5
        text(time(indices(idx)+5), ylima(2) * 0.75, num2str(trial_number_arr(indices(idx) + 5)), 'HorizontalAlignment', 'left');
    end
end

length_str = time(end);

% ylabelHandle.Position(1) = ylabelHandle.Position(1) - 0.33;

end