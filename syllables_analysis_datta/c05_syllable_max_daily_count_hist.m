% c05_syllable_max_daily_count_hist.m
% Histogram of each syllable's maximum daily bout count.

if ~exist('all_data', 'var')
    error('c05_syllable_max_daily_count_hist requires all_data in the workspace.');
end
if ~exist('most_common_motifs_all', 'var')
    error('c05_syllable_max_daily_count_hist requires most_common_motifs_all in the workspace.');
end

syllables = most_common_motifs_all(:)';
max_daily_counts = nan(numel(syllables), 1);
second_highest_daily_counts = nan(numel(syllables), 1);
daily_counts_by_syllable = cell(numel(syllables), 1);

for i_syl = 1:numel(syllables)
    syl = syllables(i_syl);
    daily_counts = [];

    for animal = 1:numel(all_data)
        for day = 1:numel(all_data(animal).data)
            d = all_data(animal).data(day).d;
            if isempty(d) || ~ismember('syllable', d.Properties.VariableNames)
                continue;
            end

            syl_data = d.syllable(:);
            run_starts = [1; find(diff(syl_data) ~= 0) + 1];
            run_syllables = syl_data(run_starts);
            daily_counts(end + 1, 1) = sum(run_syllables == syl); %#ok<SAGROW>
        end
    end

    daily_counts_by_syllable{i_syl} = daily_counts;
    if ~isempty(daily_counts)
        daily_counts_sorted = sort(daily_counts, 'descend');
        max_daily_counts(i_syl) = daily_counts_sorted(1);
        if numel(daily_counts_sorted) >= 2
            second_highest_daily_counts(i_syl) = daily_counts_sorted(2);
        end
    end
end

valid_counts = max_daily_counts(~isnan(max_daily_counts));
valid_second_counts = second_highest_daily_counts(~isnan(second_highest_daily_counts));

[fig, tl] = myFigure(1, 2, 500, 350, true);
title(tl, 'Maximum daily syllable count');
ax = nexttile(tl);
histogram(ax, valid_counts, ...
    'FaceColor', [0.25 0.25 0.25], 'EdgeColor', 'none');
xlabel(ax, 'Max daily count');
ylabel(ax, 'Number of syllables');
title(ax, sprintf('%d syllables from most\\_common\\_motifs\\_all', numel(valid_counts)));

ax = nexttile(tl);
histogram(ax, valid_second_counts, ...
    'FaceColor', [0.45 0.45 0.45], 'EdgeColor', 'none');
xlabel(ax, 'Second-highest daily count');
ylabel(ax, 'Number of syllables');
title(ax, sprintf('%d syllables with >=2 days', numel(valid_second_counts)));

max_daily_count_table = table(syllables(:), max_daily_counts, second_highest_daily_counts, ...
    daily_counts_by_syllable, ...
    'VariableNames', {'syllable', 'max_daily_count', 'second_highest_daily_count', ...
    'daily_counts'});

min_second_highest_daily_count = 100;
motifs_second_highest_at_least_200 = syllables(second_highest_daily_counts >= ...
    min_second_highest_daily_count);
disp(size(motifs_second_highest_at_least_200));