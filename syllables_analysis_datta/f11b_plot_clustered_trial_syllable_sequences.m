
% plot syllables for filtered trajectories
% assumes trajectories table and most_common_motifs exist in workspace

animal_filter = 1;
trial_height = 2;  % fixed height for each trial rectangle
trial_gap = 0.3;   % gap between rectangles

% filter trajectories: this animal, valid clusters only
traj_filt = trajectories(trajectories.animal == animal_filter & trajectories.cluster > 0, :);
fprintf('%d trajectories for A%d (all clusters)\n', height(traj_filt), animal_filter);

if height(traj_filt) == 0
    error('No trajectories match filter');
end

% sort clusters by frequency (most common first)
cluster_ids = unique(traj_filt.cluster);
cluster_counts = arrayfun(@(c) sum(traj_filt.cluster == c), cluster_ids);
[~, sort_idx] = sort(cluster_counts, 'descend');
cluster_ids = cluster_ids(sort_idx);

% cluster colors (same as f11)
clear lines;
cluster_colors = lines(10);

% build syllable to color index map (only top 20 get colors)
syl_to_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:length(most_common_motifs)
    syl_to_idx(most_common_motifs(i)) = i;
end
other_color = [0.15 0.15 0.15];  % dark grey/black for non-top-20

% find max length for x-axis
max_len = max(cellfun(@length, traj_filt.syllable));
n_trials = height(traj_filt);

trial_step = trial_height + trial_gap;  % total space per trial
[fig, tl] = myFigure(1, 1, 600, max(400, trial_step * n_trials * 15), true);
ax = nexttile(tl);
hold(ax, 'on');

y_pos = n_trials * trial_step;  % start from top
separator_y = [];  % track separator positions
cluster_labels = {};  % for y-axis labels
cluster_label_y = [];  % y positions for labels
cluster_label_ids = [];  % cluster IDs for coloring

for i_c = 1:length(cluster_ids)
    c = cluster_ids(i_c);
    c_traj = traj_filt(traj_filt.cluster == c, :);
    n_c = height(c_traj);

    % store cluster label
    cluster_labels{end+1} = sprintf('C%d (n=%d)', c, n_c);
    y_start = y_pos;

    for i_t = 1:n_c
        y_pos = y_pos - trial_step;
        syl = c_traj.syllable{i_t};
        len = length(syl);
        x_offset = max_len - len;

        % find runs of consecutive same syllables
        run_starts = [1; find(diff(syl) ~= 0) + 1];
        run_ends = [run_starts(2:end) - 1; len];
        run_lengths = run_ends - run_starts + 1;

        for i_run = 1:length(run_starts)
            rs = run_starts(i_run);
            re = run_ends(i_run);
            rl = run_lengths(i_run);
            s = syl(rs);

            % get color
            if isnan(s) || s < 0
                col = [0.9 0.9 0.9];
            elseif syl_to_idx.isKey(s)
                col = cmap20(syl_to_idx(s), :);
            else
                col = other_color;
            end

            % draw rectangle for entire run
            x = x_offset + rs - 1;
            rectangle(ax, 'Position', [x, y_pos, rl, trial_height], ...
                'FaceColor', col, 'EdgeColor', 'none');

            % add syllable number if run >= 20 frames
            if rl >= 20 && ~isnan(s) && s >= 0
                text(ax, x + 2, y_pos + trial_height/2, num2str(s), ...
                    'Color', 'w', 'FontSize', 7, 'FontWeight', 'bold', ...
                    'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
            end
        end
    end

    % store label y position (center of cluster) and cluster ID
    cluster_label_y(end+1) = (y_start + y_pos) / 2;
    cluster_label_ids(end+1) = c;

    % add separator line after each cluster (except last)
    if i_c < length(cluster_ids)
        separator_y(end+1) = y_pos;
        plot(ax, [0 max_len], [y_pos y_pos], 'k-', 'LineWidth', 1.5);
    end
end

xlim(ax, [0 max_len]);
ylim(ax, [0 n_trials * trial_step]);
set(ax, 'YDir', 'normal');
set(ax, 'YTick', []);  % remove default ticks
xlabel(ax, 'Time (frames from end)');
ylabel(ax, 'Cluster');

% add colored cluster labels on y-axis
for i_c = 1:length(cluster_labels)
    c = cluster_label_ids(i_c);
    col = cluster_colors(mod(c-1, size(cluster_colors,1)) + 1, :);
    text(ax, 5, cluster_label_y(i_c), cluster_labels{i_c}, ...
        'Color', col, 'FontSize', 16, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end
title(ax, sprintf('Syllables A%d (n=%d, %d clusters, aligned to end)', animal_filter, n_trials, length(cluster_ids)));

% add colorbar legend for top 20 motifs
colormap(ax, cmap20);
cb = colorbar(ax);
cb.Ticks = linspace(0.025, 0.975, n_colors);  % center ticks in each color band
cb.TickLabels = arrayfun(@num2str, most_common_motifs, 'UniformOutput', false);
cb.Label.String = 'Syllable (top 20)';
