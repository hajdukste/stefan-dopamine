
% p02_trial_metrics - Plot trial-specific metrics for a given animal, day, trial
%
% Shows: distance_to_reward, speed_to_reward, time_to_go, final_approach
% Can plot a grid of consecutive trials (grid_rows x grid_cols units)

animal = 3;
day = 5;
start_trial = 10;      % first trial to plot
grid_rows = 2;         % number of unit rows
grid_cols = 3;         % number of unit columns

%--------------------------------------------------------------------------
% Get data
d = all_data(animal).data(day).d;
d_old = all_data(animal).data(day).d_old;

% Get trial boundaries
start_mask = strcmp(d_old.type, 'start_of_trial');
end_mask = strcmp(d_old.type, 'end_of_trial');
start_times = d_old.time(start_mask);
end_times = d_old.time(end_mask);

n_units = grid_rows * grid_cols;
end_trial = start_trial + n_units - 1;

if end_trial > length(start_times)
    error('Not enough trials. Requested %d-%d but max trial is %d', start_trial, end_trial, length(start_times));
end

%--------------------------------------------------------------------------
% Find max trial duration for shared x-axis
max_duration = 0;
for trial_num = start_trial:end_trial
    t_start = start_times(trial_num);
    t_end_idx = find(end_times > t_start, 1);
    if ~isempty(t_end_idx)
        max_duration = max(max_duration, end_times(t_end_idx) - t_start);
    end
end

%--------------------------------------------------------------------------
% Plot grid
% Each unit is 5 plots tall. Layout: 5*grid_rows rows, grid_cols columns
[fig, tl] = myFigure(5 * grid_rows, grid_cols, 700, 320, true);
tl.TileSpacing = 'compact';
tl.Padding = 'compact';

all_axes = cell(n_units, 5);  % store axes for linking

for unit_idx = 1:n_units
    trial_num = start_trial + unit_idx - 1;

    % Get unit position in grid (1-indexed, row-major order)
    unit_row = ceil(unit_idx / grid_cols);  % which row of units (1 to grid_rows)
    unit_col = mod(unit_idx - 1, grid_cols) + 1;  % which column (1 to grid_cols)

    % Get trial data
    t_start = start_times(trial_num);
    t_end_idx = find(end_times > t_start, 1);
    if isempty(t_end_idx); continue; end
    t_end = end_times(t_end_idx);

    trial_mask = d.time >= t_start & d.time <= t_end;
    t = d.time(trial_mask) - t_start;

    dist = d.distance_to_reward(trial_mask);
    speed = d.speed_to_reward(trial_mask);
    ttg = d.time_to_go(trial_mask);
    fa = d.final_approach(trial_mask);
    fip = d.fip_signal_corr(trial_mask);

    if isempty(t); continue; end

    % Calculate tile indices for this unit's 5 plots
    % Tile numbering is row-major: tile 1 is top-left, increases left-to-right then top-to-bottom
    base_row = (unit_row - 1) * 5;  % starting row (0-indexed) for this unit

    % Plot 1: Distance to reward
    tile_idx = base_row * grid_cols + unit_col;
    ax1 = nexttile(tl, tile_idx);
    plot(ax1, t, dist, 'k', 'LineWidth', 0.8);
    if unit_col == 1; ylabel(ax1, 'Dist'); end
    title(ax1, sprintf('T%d', trial_num), 'FontSize', 8);
    set(ax1, 'XTickLabel', [], 'FontSize', 7);

    % Plot 2: Speed to reward
    tile_idx = (base_row + 1) * grid_cols + unit_col;
    ax2 = nexttile(tl, tile_idx);
    plot(ax2, t, speed, 'b', 'LineWidth', 0.8);
    hold(ax2, 'on');
    yline(ax2, 0, '--', 'Color', [0.5 0.5 0.5]);
    hold(ax2, 'off');
    if unit_col == 1; ylabel(ax2, 'Spd'); end
    set(ax2, 'XTickLabel', [], 'FontSize', 7);

    % Plot 3: Time to go
    tile_idx = (base_row + 2) * grid_cols + unit_col;
    ax3 = nexttile(tl, tile_idx);
    plot(ax3, t, ttg, 'Color', [0.8 0.4 0], 'LineWidth', 0.8);
    if unit_col == 1; ylabel(ax3, 'TTG'); end
    ylim(ax3, [0 min(20, max(ttg))]);
    set(ax3, 'XTickLabel', [], 'FontSize', 7);

    % Plot 4: Final approach
    tile_idx = (base_row + 3) * grid_cols + unit_col;
    ax4 = nexttile(tl, tile_idx);
    area(ax4, t, double(fa), 'FaceColor', [0.3 0.7 0.3], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    if unit_col == 1; ylabel(ax4, 'FA'); end
    ylim(ax4, [-0.1 1.1]);
    set(ax4, 'XTickLabel', [], 'FontSize', 7);

    % Plot 5: FIP signal
    tile_idx = (base_row + 4) * grid_cols + unit_col;
    ax5 = nexttile(tl, tile_idx);
    plot(ax5, t, fip, 'Color', [0.2 0.6 0.8], 'LineWidth', 0.8);
    if unit_col == 1; ylabel(ax5, 'FIP'); end
    if unit_row == grid_rows
        xlabel(ax5, 't (s)', 'FontSize', 7);
    else
        set(ax5, 'XTickLabel', []);
    end
    set(ax5, 'FontSize', 7);

    all_axes{unit_idx, 1} = ax1;
    all_axes{unit_idx, 2} = ax2;
    all_axes{unit_idx, 3} = ax3;
    all_axes{unit_idx, 4} = ax4;
    all_axes{unit_idx, 5} = ax5;
end

% Link all x-axes across all units and set shared xlim
all_axes_flat = all_axes(~cellfun('isempty', all_axes));
linkaxes([all_axes_flat{:}], 'x');
xlim(all_axes_flat{1}, [0 max_duration]);

% Add overall title
title(tl, sprintf('Animal %d, Day %d, Trials %d-%d', animal, day, start_trial, end_trial));
