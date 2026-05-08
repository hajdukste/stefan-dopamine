%---------------------- b01_beh_analysis - Trial count and duration summary

n_animals = numel(all_data);
n_days = max(arrayfun(@(x) numel(x.data), all_data));

trial_counts = nan(n_animals, n_days);
mean_trial_lengths = nan(n_animals, n_days);

for animal = 1:n_animals
    n_days_this_animal = numel(all_data(animal).data);

    for day = 1:n_days_this_animal
        if ~isfield(all_data(animal).data(day), 'd_old') || ...
                ~istable(all_data(animal).data(day).d_old)
            continue;
        end

        d_old = all_data(animal).data(day).d_old;
        if ~all(ismember({'type', 'time'}, d_old.Properties.VariableNames))
            continue;
        end

        [trial_start_times, trial_end_times] = getTrialStartEndPairs(d_old);
        trial_durations = trial_end_times - trial_start_times;

        trial_counts(animal, day) = numel(trial_durations);
        if ~isempty(trial_durations)
            mean_trial_lengths(animal, day) = mean(trial_durations, 'omitnan');
        end
    end
end

animal_names = cell(n_animals, 1);
for animal = 1:n_animals
    if isfield(all_data(animal), 'name') && ~isempty(all_data(animal).name)
        animal_names{animal} = strrep(all_data(animal).name, '_', '\_');
    else
        animal_names{animal} = sprintf('Animal %d', animal);
    end
end

animal_colors = getAnimalColors(n_animals);
day_labels = arrayfun(@(x) sprintf('D%d', x), 1:n_days, 'UniformOutput', false);

[fig, tl] = myFigure(1, 2, 420, 320, true);
title(tl, 'Behavior Summary');

ax_counts = nexttile(tl);
hold(ax_counts, 'on');
for animal = 1:n_animals
    valid_mask = isfinite(trial_counts(animal, :));
    if ~any(valid_mask)
        continue;
    end

    plot(ax_counts, find(valid_mask), trial_counts(animal, valid_mask), '-o', ...
        'Color', animal_colors(animal, :), ...
        'MarkerFaceColor', animal_colors(animal, :), ...
        'MarkerEdgeColor', animal_colors(animal, :), ...
        'LineWidth', 1.5, ...
        'MarkerSize', 5, ...
        'DisplayName', animal_names{animal});
end
title(ax_counts, 'Trials per Day');
xlabel(ax_counts, 'Day');
ylabel(ax_counts, 'Number of trials');
xlim(ax_counts, [0.5, n_days + 0.5]);
xticks(ax_counts, 1:n_days);
xticklabels(ax_counts, day_labels);
box(ax_counts, 'off');

ax_duration = nexttile(tl);
hold(ax_duration, 'on');
for animal = 1:n_animals
    valid_mask = isfinite(mean_trial_lengths(animal, :));
    if ~any(valid_mask)
        continue;
    end

    plot(ax_duration, find(valid_mask), mean_trial_lengths(animal, valid_mask), '-o', ...
        'Color', animal_colors(animal, :), ...
        'MarkerFaceColor', animal_colors(animal, :), ...
        'MarkerEdgeColor', animal_colors(animal, :), ...
        'LineWidth', 1.5, ...
        'MarkerSize', 5, ...
        'DisplayName', animal_names{animal});
end
title(ax_duration, 'Mean Trial Duration');
xlabel(ax_duration, 'Day');
ylabel(ax_duration, 'Duration (s)');
xlim(ax_duration, [0.5, n_days + 0.5]);
ylim(ax_duration, [0, 40]);
ref_line = yline(ax_duration, 5, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1);
ref_line.Annotation.LegendInformation.IconDisplayStyle = 'off';
xticks(ax_duration, 1:n_days);
xticklabels(ax_duration, day_labels);
box(ax_duration, 'off');

legend(ax_duration, 'Location', 'eastoutside');

%--------------------------------------------------------------------------
function [trial_start_times, trial_end_times] = getTrialStartEndPairs(d_old)
    event_types = d_old.type;
    event_times = d_old.time;

    if iscategorical(event_types) || isstring(event_types)
        event_types = cellstr(event_types);
    elseif ischar(event_types)
        event_types = cellstr(event_types);
    end

    valid_events = isfinite(event_times) & ~cellfun(@isempty, event_types);
    event_types = event_types(valid_events);
    event_times = event_times(valid_events);

    [event_times, sort_idx] = sort(event_times);
    event_types = event_types(sort_idx);

    is_start = strcmp(event_types, 'start_of_trial');
    is_end = strcmp(event_types, 'end_of_trial');

    start_times = event_times(is_start);
    end_times = event_times(is_end);

    trial_start_times = [];
    trial_end_times = [];
    next_end_idx = 1;

    for i_start = 1:numel(start_times)
        while next_end_idx <= numel(end_times) && end_times(next_end_idx) <= start_times(i_start)
            next_end_idx = next_end_idx + 1;
        end

        if next_end_idx > numel(end_times)
            break;
        end

        trial_start_times(end+1, 1) = start_times(i_start); %#ok<AGROW>
        trial_end_times(end+1, 1) = end_times(next_end_idx); %#ok<AGROW>
        next_end_idx = next_end_idx + 1;
    end
end

%--------------------------------------------------------------------------
function animal_colors = getAnimalColors(n_animals)
    base_colors = [
        0.18 0.18 0.18;
        0.34 0.34 0.34;
        0.50 0.50 0.50;
        0.66 0.66 0.66;
        0.82 0.82 0.82;
        0.20 0.48 0.52;
    ];

    if n_animals <= size(base_colors, 1)
        animal_colors = base_colors(1:n_animals, :);
        return;
    end

    animal_colors = zeros(n_animals, 3);
    animal_colors(1:size(base_colors, 1), :) = base_colors;

    gray_values = linspace(0.15, 0.85, n_animals - size(base_colors, 1) + 2);
    gray_values = gray_values(2:end-1);
    for i_extra = 1:numel(gray_values)
        animal_colors(size(base_colors, 1) + i_extra, :) = repmat(gray_values(i_extra), 1, 3);
    end
end
