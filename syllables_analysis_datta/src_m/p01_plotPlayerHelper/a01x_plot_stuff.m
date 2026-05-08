function [result, max_time] = a01x_plot_stuff(layoutHandle, session_table, moving_window_size, active_rows, plot_sero_speed, variables_tile_1, reached, colorMap, colorNameMap, variable_per_row, images, seconds_per_row, paper_figure, options, all_data, animal, day);

result = 1;
lengths_of_periods = 0;
if options.only_quiescence == 1
    og_time = session_table.time;
    [lengths_of_periods, session_table, lenght_of_tables] = get_quiescence_periods(all_data, animal);
end

if isempty(session_table.time)
    result = 0;
    max_time = 0;
    return
end

time = seconds(session_table.time - session_table.time(1));
if options.only_quiescence == 1
    time = seconds((0:(height(session_table) - 1))/30);
    og_time = session_table.time;
end
max_time = max(time);

for i_row = active_rows
    nexttile(layoutHandle, i_row);
    if variable_per_row == 0 || i_row == 1

        ser_norm = session_table.zsc_exp;
        if ismember('speed', session_table.Properties.VariableNames)
            speed = session_table.speed;
        else
            speed = zeros(size(ser_norm));
        end

        if moving_window_size(2) > 0
            speed = new_movmean(speed, moving_window_size(2), lengths_of_periods);
        end
        if moving_window_size(1) > 0
            ser_norm = new_movmean(ser_norm, moving_window_size(1), lengths_of_periods);
        end

        yyaxis left
        ax = gca;
        ax.LineStyleOrder = {'-'};
        ylabel("dF/F0");
        ylim([-3.5, 3.5])
        hold off
        if plot_sero_speed(1) == 1
            if moving_window_size(1) ~= -1
                plot(time,  ser_norm, 'Color', 'b');
            end
        else
            plot(seconds(1), NaN);
        end
        hold on

        yyaxis right
        ax = gca;
        ax.LineStyleOrder = {'-'};
        ylabel("Speed [cm/s]")
        ylim([-5, 100])

        hold off
        if plot_sero_speed(2) == 1
            if moving_window_size(2) ~= -1
                plot(time, speed);
            end
        else
            plot(seconds(1), NaN);
        end
        hold on


    end

    if variable_per_row == 0 || i_row ~= 1
        if variable_per_row == 0
            yyaxis left
            variables_tile_1_var = variables_tile_1;
        else
            variables_tile_1_var = variables_tile_1(i_row-1);
        end
        for name = variables_tile_1_var
            if ~strcmp(name, "none") && ismember(name, session_table.Properties.VariableNames)
                variable = session_table.(name);
                if strcmp(name, "nose_tip") || strcmp(name, "valve_motion") || strcmp(name, "mouse_motion") || strcmp(name, "speed_to_reward")
                    variable = normalize(variable);
                end
                if strcmp(name, "valve_motion")
                    variable = variable / 8;
                end
                if strcmp(name, "d_nose") || strcmp(name, "d_wp")
                    variable = variable / 2;
                    yline(0.25);
                    yline(-0.25);
                end
                if contains(name, "mcorr")
                    variable = variable * 3;
                    yline(0);
                    yline(-1);
                    yline(1);
                end
                if moving_window_size(find(strcmp(name, variables_tile_1), 1)+2) > 0
                    % if length(unique(variable(1:1000))) < 500
                        % movmean_size = 3.33*moving_window_size(find(strcmp(name, variables_tile_1), 1)+2);
                    % else
                        movmean_size = moving_window_size(find(strcmp(name, variables_tile_1), 1)+2);
                    % end
                    variable = new_movmean(variable, movmean_size, lengths_of_periods);
                end
                if ~strcmp(getColor(name), 'k')
                    color = getColor(name);
                    plot(time, variable, 'Color', color)
                else
                    colors_jet = hsv(7);
                    plot(time, variable, 'Color', colors_jet(mod(1+3*find(strcmp(name, variables_tile_1), 1),7)+1, :))
                end
            end
        end
    end

    if variable_per_row == 0 || i_row == 1
        yyaxis right
        ylim([-10, 100])

        yyaxis left
        if variable_per_row == 1 % 5-ht row
            ylim([-2.5, 6.5])
        else
            ylim([-5.5, 6.5])
        end
    elseif paper_figure == 1 && strcmp(variables_tile_1(i_row-1), "speed")
        ylim([-10, 100])
    else
        if strcmp(variables_tile_1_var, 'pc1nose')
            ylim([-3, 5])
        elseif strcmp(variables_tile_1_var, 'wp_motion') || strcmp(variables_tile_1_var, 'facemotion0')
            ylim([-5, 3])
        else
            ylim([-4, 4])
        end
        % ylim([-5,2])
    end
end

ylima = get(gca, 'YLim');

if seconds_per_row ~= 1001
    for i_row = active_rows
        nexttile(layoutHandle, i_row);
        % disp(i_row)

        % fake_indices = find(session_table.ttl == 1);
        % indices = [];
        % for idx = 1:length(fake_indices)
        %     if idx == 1 || fake_indices(idx) > fake_indices(idx-1) + 1 %not directly after the previous index
        %         indices = [indices fake_indices(idx)];
        %     end
        % end

        % if options.show_trials && ismember('trial', session_table.Properties.VariableNames)
        %     for idx = 1:length(indices)-1
        %         line([time(indices(idx)), time(indices(idx))], ylima, 'Color', 'black', 'LineStyle', '--');
        %         if idx <= length(session_table.trial) - 5
        %             text(time(indices(idx)+5), ylima(2) * 0.75, num2str(session_table.trial(indices(idx) + 5)), 'HorizontalAlignment', 'left');
        %         end
        %     end
        % end

        if isfield(all_data(animal).data(day), 'd_old') && ~isempty(all_data(animal).data(day).d_old)
            d_old = all_data(animal).data(day).d_old;
            if ismember('type', d_old.Properties.VariableNames)
                t0 = session_table.time(1);
                if options.show_start_trial
                    start_idx = strcmp(d_old.type, 'start_of_trial');
                    start_times = d_old.time(start_idx) - t0;
                    yl = get(gca, 'YLim');
                    for i_st = 1:length(start_times)
                        line([start_times(i_st), start_times(i_st)], yl, 'Color', [0 0.6 0], 'LineWidth', 1);
                    end
                end
                if options.show_end_trial
                    end_idx = strcmp(d_old.type, 'end_of_trial');
                    end_times = d_old.time(end_idx) - t0;
                    yl = ylim;
                    for i_et = 1:length(end_times)
                        line([end_times(i_et), end_times(i_et)], yl, 'Color', [0.8 0 0], 'LineWidth', 1);
                    end
                end
            end
        end

        %% image plot
        if options.show_images && ismember('corri', session_table.Properties.VariableNames)
            if variable_per_row == 0 || i_row == 1
                idxs = arrayfun(@(x) find(reached(:, x) == 1), [1:7], 'UniformOutput', false);

                for idx = 1:length(idxs{1})-1
                    [idx80, idx150, idx220, idx290, idx360, idx_before, idx_after] = deal(idxs{1}(idx), idxs{2}(idx), idxs{3}(idx), idxs{4}(idx), idxs{5}(idx), idxs{6}(idx), idxs{7}(idx));


                    if mod(session_table.corri(idx80), 2) == 1 || paper_figure == 1
                        color_rew = 'blue';
                        color_im = 'cyan';
                    else
                        color_rew = [0.3137 0.7804 0];
                        color_im = [0.5804 1 0.5804];
                    end
                    color_rew = 'blue'; color_im = 'blue';

                    patch([time(idx80), time(idx80), time(idx150), time(idx150)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
                    patch([time(idx220), time(idx220), time(idx290), time(idx290)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_im, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
                    % patch([time(idx_before), time(idx_before), time(idx_after), time(idx_after)], [ylima(1), ylima(2), ylima(2), ylima(1)], color_rew, 'FaceAlpha', 0.1, 'EdgeColor', 'none');

                end
            end
        end

        % %% rewards bool line which is kinda bar as well if done differently.
        % if options.yline_rewards && i_row == 2
        %     start_idx = 1;
        %     sequence = session_table.rew_bool;

        %     for i = 2:length(sequence)
        %         if sequence(i) ~= sequence(i-1)
        %             if sequence(start_idx) == 0
        %                 % plot(time(start_idx:i-1), sequence(start_idx:i-1), 'k', 'LineWidth', 5); % Black for 0s
        %             else
        %                 % plot(time(start_idx:i-1), sequence(start_idx:i-1)-1, 'k', 'LineWidth', 25); % Red for 1s
        %                 x = [time(start_idx), time(i-1), time(i-1), time(start_idx)];
        %                 y = [0, 0, 1, 1] + (sequence(start_idx)-1);  % Shift vertically as in original code
        %                 patch(x, y, 'k', 'EdgeColor', 'none');  % 'k' is black; no border
        %             end
        %             hold on;

        %             start_idx = i;
        %         end
        %     end
        % end

        %% quiescence
        if  options.show_quiescence && (variable_per_row == 0 || i_row == active_rows(end))
            columnsToProcess = {'still'};
            colors = {[0.3 0.3 0.3]}; % Default color for 'still'
            if paper_figure == 1
                y_list = {[10, -1, -1, 10]};
            else
                y_list = {[1, -1, -1, 1]};
            end

            for col = 1:length(columnsToProcess)
                columnName = columnsToProcess{col};
                currentColor = colors{col};
                y = y_list{col};
                dataColumn = session_table.(columnName);
                start_idx = 0;

                for i = 2:length(dataColumn)
                    if dataColumn(i) == 1 && start_idx == 0
                        start_idx = i;
                    elseif dataColumn(i) == 0 && start_idx > 0
                        end_idx = i;
                        patch([time(start_idx), time(start_idx), time(end_idx), time(end_idx)], ...
                              y, ...
                              currentColor, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
                        start_idx = 0;
                    end
                end
            end
        end

        %% hmm
        if  options.show_hmm && (variable_per_row == 0 || i_row == active_rows(end))
            columnName = 'hmm_4';
            if paper_figure == 1
                y = [10, -1, -1, 10];
            else
                y = [1, -1, -1, 1];
            end

            dataColumn = session_table.(columnName);
            unique_states = unique(dataColumn(~isnan(dataColumn)));
            n_states = numel(unique_states);

            if n_states <= 2
                % Binary: shade state 0 only
                currentColor = [0.3 0.3 0.3];
                start_idx = 0;
                for i = 2:length(dataColumn)
                    if dataColumn(i) == 0 && start_idx == 0
                        start_idx = i;
                    elseif dataColumn(i) ~= 0 && start_idx > 0
                        end_idx = i;
                        patch([time(start_idx), time(start_idx), time(end_idx), time(end_idx)], ...
                              y, currentColor, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
                        start_idx = 0;
                    end
                end
            else
                % Multi-state: color each state, skip the one with lowest avg pc1nose
                pc1_col = session_table.pc1nose;
                avg_pc1_per_state = zeros(n_states, 1);
                for s_idx = 1:n_states
                    mask = dataColumn == unique_states(s_idx) & ~isnan(pc1_col);
                    avg_pc1_per_state(s_idx) = mean(pc1_col(mask));
                end
                [~, sorted_idx] = sort(avg_pc1_per_state, 'descend');
                skip_idx = sorted_idx(end);

                state_colors = lines(n_states);
                % Assign colors by pc1nose rank (highest=blue, 2nd=orange, 3rd=yellow, lowest=skipped)
                color_map = zeros(n_states, 3);
                for rank = 1:n_states
                    if sorted_idx(rank) == skip_idx; continue; end
                    color_map(sorted_idx(rank), :) = state_colors(rank, :);
                end

                for s_idx = 1:n_states
                    if s_idx == skip_idx; continue; end
                    s = unique_states(s_idx);
                    start_idx = 0;
                    for i = 2:length(dataColumn)
                        if dataColumn(i) == s && start_idx == 0
                            start_idx = i;
                        elseif dataColumn(i) ~= s && start_idx > 0
                            end_idx = i;
                            patch([time(start_idx), time(start_idx), time(end_idx), time(end_idx)], ...
                                  y, color_map(s_idx, :), 'FaceAlpha', 0.1, 'EdgeColor', 'none');
                            start_idx = 0;
                        end
                    end
                end
            end
        end


        true_options = fieldnames(options);
        columnsToProcess = true_options(contains(true_options, 'option') & cellfun(@(f) options.(f), true_options));
        if ~isempty(columnsToProcess) && (variable_per_row == 0 || i_row == active_rows(end))
            for col = 1:length(columnsToProcess)
                columnName = columnsToProcess{col};
                indices = find(session_table.(columnName) == 1)';
                for idx = 1:length(indices)
                    line([time(indices(idx)), time(indices(idx))], ylima, 'Color', 'r', 'LineStyle', '--');
                    if idx <= length(session_table.trial) - 10
                        text(time(indices(idx)+10), ylima(2) * 0.75 + 0.1, regexprep(columnName, '\D', ''), 'Color', 'r', 'HorizontalAlignment', 'left');
                    end
                end
            end
        end

        if options.show_speedBelow5 && (variable_per_row == 0 || i_row == active_rows(end))
            columnsToProcess = {'speedBelow5'};
            colors = {[0.3 0.3 0.3]}; % Default color for 'still'
            if paper_figure == 1
                y_list = {[15, 25, 25, 15]};
            else
                y_list = {[1, 2, 2, 1]};
            end

            for col = 1:length(columnsToProcess)
                columnName = columnsToProcess{col};
                currentColor = colors{col};
                y = y_list{col};
                dataColumn = session_table.(columnName);
                start_idx = 0;

                for i = 2:length(dataColumn)
                    if dataColumn(i) == 1 && start_idx == 0
                        start_idx = i;
                    elseif dataColumn(i) == 0 && start_idx > 0
                        end_idx = i;
                        patch([time(start_idx), time(start_idx), time(end_idx), time(end_idx)], ...
                              y, ...
                              currentColor, 'FaceAlpha', 0.1, 'EdgeColor', 'none');
                        start_idx = 0;
                    end
                end
            end
        end

        if options.show_gain && ismember('gain', session_table.Properties.VariableNames)
            indices = find(reached == 1)';
            for idx = 1:length(indices)
                line([time(indices(idx)), time(indices(idx))], ylima, 'Color', 'r', 'LineStyle', '--');
                if idx <= length(session_table.trial) - 10
                    text(time(indices(idx)+10), ylima(2) * 0.75 + 0.1, num2str(session_table.gain(indices(idx) + 5)), 'Color', 'r', 'HorizontalAlignment', 'left');
                    text(time(indices(idx)-10), ylima(2) * 0.75 - 0.1, num2str(session_table.gain(indices(idx) - 5)), 'Color', 'r', 'HorizontalAlignment', 'right');
                end
            end
        end

        if options.only_quiescence
            current_start = 1;
            for p = 1:length(lengths_of_periods)
                period_length = lengths_of_periods(p);
                current_end = current_start + period_length - 1;
                line([time(current_start), time(current_start)], ylima, 'Color', 'black', 'LineStyle', '--');
                % text_str = sprintf('%.1fs: %.1fs-%.1fs', period_length/30, seconds(time(current_start)), seconds(time(current_end)));
                % text_str = sprintf('%.1fs', period_length/30);
                corr_value = corr(session_table.wp_motion(current_start:current_end), session_table.zsc_exp(current_start:current_end), 'rows', 'complete');
                if ismember('pc1nose', all_data(animal).data(1).d.Properties.VariableNames)
                    corr_value2 = corr(session_table.pc1nose(current_start:current_end), session_table.zsc_exp(current_start:current_end), 'rows', 'complete');
                else
                    corr_value2 = 0;
                end
                % text_str = sprintf('%.1fs, r: %.2f', period_length / 30, corr_value);
                if seconds_per_row < 201
                    % text_str = sprintf('|%.1fs: %.0fs-%.0fs, r: %.2f|', period_length / 30, og_time(current_start), og_time(current_end), corr_value);
                    % text_str = sprintf('|%.1fs: %.0fs, r: %.2f|', period_length / 30, og_time(current_start), corr_value);
                    text_str = sprintf('|%.1fs: %.0fs, r: %.2f, %.2f|', period_length / 30, og_time(current_start), corr_value, corr_value2);
                else
                    text_str = sprintf('|%.1fs, r: %.2f|', period_length / 30, corr_value);
                end
                if seconds_per_row < 1001
                    text(time(current_start+5), ylima(2) * (0.65 + mod(p-1, 3)*0.1), text_str, 'HorizontalAlignment', 'left');
                end
                current_start = current_end + 1;
            end

            current_start = 1;
            for p = 1:length(lenght_of_tables)
                period_length = lenght_of_tables(p);
                current_end = current_start + period_length;
                % text_str = sprintf('%.1fs: %.1fs-%.1fs', period_length/30, seconds(time(current_start)), seconds(time(current_end)));
                % text_str = sprintf('%.1fs', period_length/30);
                % corr_value = corr(session_table.wp_motion(current_start:current_end), session_table.zsc_exp(current_start:current_end), 'rows', 'complete');
                % text_str = sprintf('%.1fs, r: %.2f', period_length / 30, corr_value);
                % text_str = sprintf('%.1fs: %.1fs-%.1fs, r: %.2f', period_length / 30, og_time(current_start), og_time(current_end), corr_value);
                text_str = ['Day ' num2str(p) ' (' num2str(round(period_length/30, 1)) 's)'];
                % if mod(p, 2) == 1
                    % text(time(current_start+5), ylima(2) * 0.75, text_str, 'HorizontalAlignment', 'left');
                % else
                if period_length ~= 0 && current_start < height(session_table) && seconds_per_row < 201
                    line([time(current_start), time(current_start)], ylima, 'Color', 'r');
                    text(time(current_start+5), ylima(2) * 0.92, text_str, 'HorizontalAlignment', 'left');
                end
                % end
                current_start = current_end;
            end
        end
    end
end


if paper_figure

end


end