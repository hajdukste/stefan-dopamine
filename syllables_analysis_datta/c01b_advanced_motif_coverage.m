skip_animals_days = [0 0];
top_n = 25;
top25 = sorted_syllables(1:top_n);
n_animals = length(all_data);

% symbols for individual animal scatter points
animal_symbols = {'o', 's', 'd', '^', 'v', '>'};
animal_marker_size = 20;

% per-animal means for each motif
speed_per_animal = NaN(n_animals, top_n);
fip_naclat_per_animal = NaN(n_animals, top_n);
fip_nacmed_per_animal = NaN(n_animals, top_n);

% collect data
for animal = 1:n_animals
    region = all_data(animal).region;
    is_naclat = strcmp(region, 'NAcLat');

    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end

        d = all_data(animal).data(day).d;
        if isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end

        for i = 1:top_n
            syl = top25(i);
            mask = d.syllable == syl;
            if sum(mask) == 0; continue; end

            % speed
            if ismember('speed', d.Properties.VariableNames)
                speed_per_animal(animal, i) = mean(d.speed(mask));
            end

            % FIP activity by region
            if ismember('fip_signal_corr', d.Properties.VariableNames)
                fip_vals = d.fip_signal_corr(mask);
                fip_vals = fip_vals(~isnan(fip_vals));
                if ~isempty(fip_vals)
                    if is_naclat
                        fip_naclat_per_animal(animal, i) = mean(fip_vals);
                    else
                        fip_nacmed_per_animal(animal, i) = mean(fip_vals);
                    end
                end
            end
        end
    end
end

% compute means and SEM across animals
mean_speed = nanmean(speed_per_animal, 1)';
sem_speed = nanstd(speed_per_animal, 0, 1)' / sqrt(sum(~isnan(speed_per_animal(:,1))));

n_naclat = sum(~isnan(fip_naclat_per_animal(:,1)));
n_nacmed = sum(~isnan(fip_nacmed_per_animal(:,1)));
mean_naclat = nanmean(fip_naclat_per_animal, 1)';
mean_nacmed = nanmean(fip_nacmed_per_animal, 1)';
sem_naclat = nanstd(fip_naclat_per_animal, 0, 1)' / sqrt(n_naclat);
sem_nacmed = nanstd(fip_nacmed_per_animal, 0, 1)' / sqrt(n_nacmed);

% layout parameters
bar_width = 0.35;
color_naclat = [17 113 190] / 255;   % #1171BE
color_nacmed = [221 84 0] / 255;      % #DD5400

% create figure: 2 rows, 1 column
[fig, tl] = myFigure(2, 1, 1200, 300, true);
title(tl, 'Motif characteristics (Top 25 sorted syllables)');

% row 1: speed
ax1 = nexttile(tl);
hold(ax1, 'on');
for i = 1:top_n
    bar(ax1, i, mean_speed(i), bar_width*2, 'FaceColor', cmap25(i, :), 'EdgeColor', 'k', 'LineWidth', 0.5);
    % error bar
    plot(ax1, [i i], [mean_speed(i) - sem_speed(i), mean_speed(i) + sem_speed(i)], 'k-', 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(speed_per_animal(a, i))
            scatter(ax1, i, speed_per_animal(a, i), animal_marker_size, 'k', animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax1, 'off');
xlim(ax1, [0 top_n + 1]);
set(ax1, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax1, 'Speed');
title(ax1, 'Average speed during motif');

% row 2: NAcLat + NAcMed clustered
ax2 = nexttile(tl);
hold(ax2, 'on');
for i = 1:top_n
    % NAcLat bar (left)
    bar(ax2, i - bar_width/2, mean_naclat(i), bar_width, 'FaceColor', cmap25(i, :), 'EdgeColor', color_naclat, 'LineWidth', 2);
    % NAcLat error bar
    plot(ax2, [i - bar_width/2, i - bar_width/2], [mean_naclat(i) - sem_naclat(i), mean_naclat(i) + sem_naclat(i)], '-', 'Color', color_naclat, 'LineWidth', 1);
    % NAcMed bar (right)
    bar(ax2, i + bar_width/2, mean_nacmed(i), bar_width, 'FaceColor', cmap25(i, :), 'EdgeColor', color_nacmed, 'LineWidth', 2);
    % NAcMed error bar
    plot(ax2, [i + bar_width/2, i + bar_width/2], [mean_nacmed(i) - sem_nacmed(i), mean_nacmed(i) + sem_nacmed(i)], '-', 'Color', color_nacmed, 'LineWidth', 1);
    % individual animal points
    for a = 1:n_animals
        if ~isnan(fip_naclat_per_animal(a, i))
            scatter(ax2, i - bar_width/2, fip_naclat_per_animal(a, i), animal_marker_size, color_naclat, animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
        if ~isnan(fip_nacmed_per_animal(a, i))
            scatter(ax2, i + bar_width/2, fip_nacmed_per_animal(a, i), animal_marker_size, color_nacmed, animal_symbols{a}, 'filled', 'MarkerFaceAlpha', 0.6);
        end
    end
end
hold(ax2, 'off');
xlim(ax2, [0 top_n + 1]);
set(ax2, 'XTick', 1:top_n, 'XTickLabel', string(top25));
ylabel(ax2, 'dF/F (z)');
title(ax2, 'Average activity during motif (NAcLat=blue edge, NAcMed=orange edge)');
