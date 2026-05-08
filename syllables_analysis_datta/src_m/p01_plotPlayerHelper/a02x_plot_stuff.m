
function a02x_plot_stuff(layoutHandle, fake_all_data, tile, columnNames, moving_window_size, keep_plots, plot_speed_sero_fm)

show_predicted = -1;

time = seconds(fake_all_data.time - fake_all_data.time(1));

if tile == 1
    nexttile(layoutHandle, 1);
    speed = fake_all_data.speed;
    ser_norm = fake_all_data.zsc_exp;

    if ismember('facemotion0', fake_all_data.Properties.VariableNames); facemotion = fake_all_data.facemotion0; else; facemotion = zeros(size(speed)); end
    if ismember('pupil', fake_all_data.Properties.VariableNames); pupil = normalize(fake_all_data.pupil); else; pupil = zeros(size(speed)); end

    speed = movmean(speed, 3/3.33);

    if moving_window_size(2) > 0
        speed = movmean(speed, moving_window_size(2));%/3.33);
    end
    if moving_window_size(1) > 0
        ser_norm = movmean(ser_norm, moving_window_size(1));%/3.33);
    end
    if moving_window_size(3) > 0
        facemotion = movmean(facemotion, moving_window_size(3));%/3.33);
    end


    yyaxis left
    ax = gca;
    ax.LineStyleOrder = {'-'};
    ylabel("dF/F0");


    hold off
    plot(seconds(1), NaN);
    hold on

    if plot_speed_sero_fm(1) == 1
        plot(time,  ser_norm, 'Color', 'b');
    end
    if plot_speed_sero_fm(3) == 1
        plot(time, facemotion, 'Color', 'g')
    end

    ylim([-4, 4])

    yyaxis right
    ax = gca;
    ax.LineStyleOrder = {'-'};
    ylabel("Speed [cm/s]")


    hold off
    if plot_speed_sero_fm(2) == 1
        plot(time, speed);
    else
        plot(seconds(1), NaN);
    end
    hold on
    ylim([-5, 100])
    ylabel("Speed [cm/s]")

    yyaxis left
else
    if ~strcmp(columnNames, "none") && ismember(columnNames, fake_all_data.Properties.VariableNames)
        nexttile(layoutHandle, tile)
        if keep_plots == 1
            hold on
        else
            hold off
        end
        if strcmp(columnNames, 'speed_nose_tip')
            variable = fake_all_data.(columnNames) / 2;
        elseif strcmp(columnNames, 'movcorr')
            variable = fake_all_data.(columnNames) * 2;
        elseif strcmp(columnNames, 'motion')
            variable = fake_all_data.(columnNames);
        else
            variable = normalize(fake_all_data.(columnNames));
        end
        if moving_window_size(tile+2) ~= 0
            variable = movmean(variable, moving_window_size(tile+2)/3.33);
        end
        p = plot(time, variable);
        plotColor = p.Color;
        escapedColumnName = columnNames;
        if keep_plots == 1
            % Find all existing text labels
            existingTexts = findobj(gca, 'Tag', 'ColumnLabel');
            numExistingLabels = length(existingTexts);

            % Calculate the new y-position for the label to stack below existing labels
            % Start from top (0.99) and move down by 0.05 for each existing label
            newY = 0.99 - 0.05 * numExistingLabels;

            % Create a new text label with the plot's color
            text(0.01, newY, escapedColumnName, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'Color', plotColor, ...
                'Interpreter', 'none', ...  % Interpret text literally
                'Tag', 'ColumnLabel');       % Tag for identification
        else
            % If not keeping plots, remove all existing text labels
            existingTexts = findobj(gca, 'Tag', 'ColumnLabel');
            delete(existingTexts);

            % Add a single text label at the top
            text(0.01, 0.99, escapedColumnName, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'Color', plotColor, ...
                'Interpreter', 'none', ...  % Interpret text literally
                'Tag', 'ColumnLabel');       % Tag for identification
        end
        ylim([-4, 4])
    end

    % axesHandles = findobj(layoutHandle, 'Type', 'axes');
    % for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
    %     ylima = get(ax, 'YLim');
    %     variable = 'option12bool';
    %     indices = find(fake_all_data.(variable) == 1);
    %     for idx = indices
    %         line(ax, [time(idx), time(idx)], ylima, 'Color', 'black', 'LineStyle', '--');
    %     end
    %     ylim([-3.5, 3.5])
    % end
end







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