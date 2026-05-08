
% motif coverage analysis
% how much of total timestamps do syllables 0-23 cover?
% how much do the top 20 most common syllables cover?

all_syl = [];
n_animals = length(all_data);
use_motifs_or_d = 'd';

for a = 1:n_animals
    for d = 1:length(all_data(a).data)
        % skip animals
        if ismember([a, d], skip_animals_days, 'rows'); continue; end
        if strcmp(use_motifs_or_d, 'motifs')
            if isempty(all_data(a).data(d).motifs); continue; end
            syl = all_data(a).data(d).motifs.syllable;
        elseif strcmp(use_motifs_or_d, 'd')
            syl = all_data(a).data(d).d.syllable;
        end
        all_syl = [all_syl; syl];
    end
end

all_syl = all_syl(all_syl >= 0);
total_timestamps = length(all_syl);
unique_syl = unique(all_syl);
n_syl = length(unique_syl);

% counts per syllable sorted by frequency
pooled_counts = histcounts(all_syl, [unique_syl; max(unique_syl)+1])';
[pooled_sorted, sort_idx] = sort(pooled_counts, 'descend');
syl_order = unique_syl(sort_idx);

fprintf('\nTotal timestamps: %d\n', total_timestamps);
fprintf('Unique syllables: %d\n', n_syl);

% coverage by syllables 0-23
mask_0_23 = all_syl >= 0 & all_syl <= 23;
count_0_23 = sum(mask_0_23);
fprintf('\n--- Syllables 0-23 coverage ---\n');
fprintf('  Timestamps in syl 0-23: %d / %d (%.1f%s)\n', count_0_23, total_timestamps, count_0_23/total_timestamps*100, char(37));
fprintf('  Timestamps outside 0-23: %d (%.1f%s)\n', total_timestamps - count_0_23, (total_timestamps - count_0_23)/total_timestamps*100, char(37));

% top 20 most common syllables coverage
top_n = min(20, n_syl);
top_syl = syl_order(1:top_n);
top_counts = pooled_sorted(1:top_n);
cumulative = cumsum(top_counts);

fprintf('\n--- Top %d most common syllables (cumulative coverage) ---\n', top_n);
for i = 1:top_n
    fprintf('  %2d. Syllable %3d: %6d timestamps (%5.1f%s) | cumulative: %6d (%5.1f%s)\n', ...
        i, top_syl(i), top_counts(i), top_counts(i)/total_timestamps*100, char(37), ...
        cumulative(i), cumulative(i)/total_timestamps*100, char(37));
end

% summary thresholds
thresholds = [5, 10, 15, 20, 30, 50];
fprintf('\n--- Coverage summary ---\n');
for t = thresholds
    if t > n_syl; break; end
    cov = sum(pooled_sorted(1:t)) / total_timestamps * 100;
    fprintf('  Top %2d syllables cover %.1f%s of all timestamps\n', t, cov, char(37));
end

% how many syllables needed for 50/75/90/95/99% coverage
cumulative_all = cumsum(pooled_sorted) / total_timestamps * 100;
pct_targets = [50, 75, 90, 95, 99];
fprintf('\n--- Syllables needed for X%s coverage ---\n', char(37));
for p = pct_targets
    n_needed = find(cumulative_all >= p, 1);
    fprintf('  %2d%s coverage: %d syllables\n', p, char(37), n_needed);
end
