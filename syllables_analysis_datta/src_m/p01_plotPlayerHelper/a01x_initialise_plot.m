function [layoutHandle, last_time, reached] = a01x_initialise_plot(session_table, num_rows, variable_per_row, variables_tile_1)

time = seconds(session_table.time - session_table.time(1));
last_time = time(end);

if ismember('corri', session_table.Properties.VariableNames)
    thresholds = [80, 150, 220, 290, 360, 350, 370]; % Define the thresholds
    flags = zeros(1, length(thresholds)); % Initialize flags for each threshold
    trial_posit = session_table.trial_posit;
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
elseif ismember('gain', session_table.Properties.VariableNames)
    gain = session_table.gain;
    gain(isnan(gain)) = 0;
    reached = diff(gain) ~= 0;
elseif ismember('screen_on', session_table.Properties.VariableNames)
    reached = 0;
else
    reached = 0;
end

layoutHandle = tiledlayout(num_rows, 1, 'TileSpacing', 'None');
if variable_per_row == 0
    for i_row = 1:num_rows
        fake_i_row = num_rows + 1 - i_row;
        nexttile(layoutHandle, fake_i_row);
    end
else
    for i_row = 1:min(num_rows, -2*(variable_per_row-1) + find(variables_tile_1 == "none", 1))
        nexttile(layoutHandle, i_row);
    end
end

end