function [layoutHandle, fake_all_data, first_tcam, last_tcam, last_time] = a02x_initialise_plot(session_table, no_images)

%
% tcam = session_table.tcam;
%
% [~, ia, ~] = unique(tcam);
%
% % session_table = session_table(1:end, :);
%
% % ser_norm = accumarray(ic, session_table.zsc_exp(:), [], @mean);
% % speed = accumarray(ic, session_table.speed, [], @mean);
%
% fake_all_data = session_table(ia, :);
fake_all_data = session_table;

first_tcam = fake_all_data.tcam(1);
last_tcam = fake_all_data.tcam(end);
time = seconds(fake_all_data.time - fake_all_data.time(1));
last_time = time(end);

thresholds = [80, 150, 220, 290, 360, 350, 370]; % Define the thresholds
flags = zeros(1, length(thresholds)); % Initialize flags for each threshold
trial_posit = fake_all_data.trial_posit;
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


layoutHandle = tiledlayout(3, 1, 'TileSpacing', 'None');




% idxs = arrayfun(@(x) find(reached(:, x) == 1), [1:7], 'UniformOutput', false);
%
% for idx = 1:length(idxs{1})-1
%     [idx80, idx150, idx220, idx290, idx360, idx_before, idx_after] = deal(idxs{1}(idx), idxs{2}(idx), idxs{3}(idx), idxs{4}(idx), idxs{5}(idx), idxs{6}(idx), idxs{7}(idx));
%     if no_images == 0
%         if mod(corri(idx80), 2) == 1
%             color_rew = 'blue';
%             color_im = 'cyan';
%         else
%             color_rew = [0.3137 0.7804 0];
%             color_im = [0.5804 1 0.5804];
%         end
%     end
%
%     if day ~= 11 && no_images == 0
%         patch([time(idx80), time(idx80), time(idx150), time(idx150)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
%         patch([time(idx220), time(idx220), time(idx290), time(idx290)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
%     end
%     if no_images == 0
%         patch([time(idx_before), time(idx_before), time(idx_after), time(idx_after)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_rew, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
%     end
% end
%
%
% fake_indices = find(ttl == 1);
% indices = [];
% for idx = 1:length(fake_indices)
%     if idx == 1 || fake_indices(idx) > fake_indices(idx-1) + 1 %not directly after the previous index
%         indices = [indices fake_indices(idx)];
%     end
% end
%
% [~, closestIndexStart] = min(abs(time - seconds(start_seconds)));
% [~, closestIndexStop] = min(abs(time - seconds(start_seconds + seconds_per_row)));
% start_idx = trial_number_arr(closestIndexStart);
% stop_idx = trial_number_arr(closestIndexStop);
%
% % for idx = 1:length(indices)-1
% for idx = start_idx:stop_idx
%     line([time(indices(idx)), time(indices(idx))], ylima, 'Color', 'black', 'LineStyle', '--');
%     if idx <= length(trial_number_arr) - 5
%         text(time(indices(idx)+5), ylima(2) * 0.75, num2str(trial_number_arr(indices(idx) + 5)), 'HorizontalAlignment', 'left');
%     end
% end
%
%



end