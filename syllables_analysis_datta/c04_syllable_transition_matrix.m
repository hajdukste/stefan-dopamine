% c04_syllable_transition_matrix.m
% Compute and visualize transition probabilities between top 20 syllables
% P(A -> B) = #transitions from A to B / #all transitions from A

skip_animals_days = [0 0];
epoch_filter = 'final_approach';  % 'all_data', 'trial', or 'final_approach'
days = 5;

% use most_common_motifs from a00_process_data.m (top 20 syllables)
top25 = sorted_syllables;
n_top = length(top25);

% map syllable ID to index (1-20)
syl_to_idx_local = containers.Map('KeyType', 'double', 'ValueType', 'double');
for i = 1:n_top
    syl_to_idx_local(top25(i)) = i;
end

% count transitions: trans_counts(i,j) = # transitions from bout of syllable i to bout of syllable j
trans_counts = zeros(n_top, n_top);

n_animals = length(all_data);
for a = 1:n_animals
    for day = days
        if ismember([a, day], skip_animals_days, 'rows'); continue; end

        d = all_data(a).data(day).d;
        if isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end

        syllables = d.syllable;
        n_frames = length(syllables);

        % filter by epoch
        if ~strcmp(epoch_filter, 'all_data')
            d_old = all_data(a).data(day).d_old;
            if isempty(d_old); continue; end

            end_mask = strcmp(d_old.type, 'end_of_trial');
            end_times = d_old.time(end_mask);

            if strcmp(epoch_filter, 'trial')
                start_mask = strcmp(d_old.type, 'start_of_trial');
            else  % 'final_approach'
                start_mask = strcmp(d_old.type, 'final_approach_start');
            end
            start_times = d_old.time(start_mask);

            in_epoch = false(n_frames, 1);
            for i_start = 1:length(start_times)
                t_start = start_times(i_start);
                t_end_idx = find(end_times > t_start, 1);
                if isempty(t_end_idx); continue; end
                t_end = end_times(t_end_idx);
                in_epoch = in_epoch | (d.time >= t_start & d.time <= t_end);
            end

            syllables = syllables(in_epoch);
            if isempty(syllables); continue; end
        end

        % find bout boundaries (where syllable changes)
        bout_starts = [1; find(diff(syllables) ~= 0) + 1];
        bout_syllables = syllables(bout_starts);
        n_bouts = length(bout_syllables);

        % count transitions between consecutive bouts
        for b = 1:(n_bouts - 1)
            syl_from = bout_syllables(b);
            syl_to = bout_syllables(b + 1);

            % only count if both are in top 20
            if isKey(syl_to_idx_local, syl_from) && isKey(syl_to_idx_local, syl_to)
                i_from = syl_to_idx_local(syl_from);
                i_to = syl_to_idx_local(syl_to);
                trans_counts(i_from, i_to) = trans_counts(i_from, i_to) + 1;
            end
        end
    end
end

% compute transition probabilities
% P(A -> B) = trans_counts(A, B) / sum(trans_counts(A, :))
row_sums = sum(trans_counts, 2);
row_sums(row_sums == 0) = 1;  % avoid division by zero
trans_prob = trans_counts ./ row_sums;

% create figure with heatmap
[fig, tl] = myFigure(1, 2, 1000, 1050, true);
epoch_titles = struct('all_data', 'All Data', 'trial', 'Within-Trial', 'final_approach', 'Final Approach');
title(tl, sprintf('Syllable Transition Matrix (Top 25, %s)', epoch_titles.(epoch_filter)));

% build colored tick labels using TeX
colored_labels = cell(n_top, 1);
for i = 1:n_top
    colored_labels{i} = sprintf('\\color[rgb]{%.3f,%.3f,%.3f}%d', ...
        cmap25(i,1), cmap25(i,2), cmap25(i,3), top25(i));
end

% transition counts heatmap
ax1 = nexttile(tl);
imagesc(ax1, trans_counts);
colorbar(ax1);
axis(ax1, 'square');
xticks(ax1, 1:n_top);
yticks(ax1, 1:n_top);
ax1.XAxis.TickLabelInterpreter = 'tex';
ax1.YAxis.TickLabelInterpreter = 'tex';
xticklabels(ax1, colored_labels);
yticklabels(ax1, colored_labels);
xlabel(ax1, 'To syllable');
ylabel(ax1, 'From syllable');
title(ax1, 'Transition counts');
colormap(ax1, 'hot');

% transition probabilities heatmap
ax2 = nexttile(tl);
imagesc(ax2, trans_prob);
colorbar(ax2);
axis(ax2, 'square');
xticks(ax2, 1:n_top);
yticks(ax2, 1:n_top);
ax2.XAxis.TickLabelInterpreter = 'tex';
ax2.YAxis.TickLabelInterpreter = 'tex';
xticklabels(ax2, colored_labels);
yticklabels(ax2, colored_labels);
xlabel(ax2, 'To syllable');
ylabel(ax2, 'From syllable');
title(ax2, 'Transition probability P(from -> to)');
colormap(ax2, 'hot');

% print summary stats
fprintf('\n--- Transition Matrix Summary (%s) ---\n', epoch_titles.(epoch_filter));
fprintf('Total transitions counted: %d\n', sum(trans_counts(:)));
fprintf('Most common transitions:\n');

% find top 10 transitions
[sorted_counts, sort_idx] = sort(trans_counts(:), 'descend');
for k = 1:min(10, length(sorted_counts))
    [i, j] = ind2sub(size(trans_counts), sort_idx(k));
    fprintf('  %d -> %d: %d (%.2f%%)\n', top25(i), top25(j), ...
        sorted_counts(k), 100 * trans_prob(i, j));
end
