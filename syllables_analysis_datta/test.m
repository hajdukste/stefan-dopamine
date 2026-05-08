



% load /Users/stefan/Downloads/Datta_colab/10142025/K411_0_habituation_10142025.txt as a table
T = readtable('/Users/stefan/Downloads/Datta_colab/10142025/K411_0_habituation_10142025.txt');


% load /Users/stefan/Downloads/Datta_colab/10152025/K411_0_day1_10152025.csv as a table
T2 = readtable('/Users/stefan/Downloads/Datta_colab/10182025/K413_5_day3_10182025.csv');

%
% make different tables for each different 'type' column in T2
% first, get the unique values of the 'type' column
unique_types = unique(T2.type);

disp(unique_types);

% plot each type as a row of vertical lines
[fig, tl] = myFigure(8, 1, 1600, 300, true);
x_max = max(T2.python_time);

for i = 1:length(unique_types)
    ax = nexttile(tl);
    idx = strcmp(T2.type, unique_types{i});
    times = T2.python_time(idx);
    xline(ax, times, 'k');
    xlim(ax, [0 x_max]);
    ylabel(ax, unique_types{i}, 'Interpreter', 'none');
    if i < length(unique_types)
        set(ax, 'XTickLabel', []);
    end
end



%

% load /Users/stefan/Downloads/berkeley_collab/kpms/model/2026_01_21-15_28_19/results/C57_51_9_2_day3_10182025.csv as a table
T3 = readtable('/Users/stefan/Downloads/berkeley_collab/kpms/model/2026_01_21-15_28_19/results/C57_51_9_day5_10202025.csv');

%


data_table = all_data(1).data(5).d;
disp(height(data_table));
disp(height(T3));

%
d_old = all_data(1).data(5).d_old;
% look at 'start_of_trial' only:
start_idx = strcmp(d_old.type, 'start_of_trial');

% and look at Valve_ID what are the values for these rows:
valve_ids = d_old.Valve_ID(start_idx);

% plot distribution of valve_ids
figure;
histogram(valve_ids);


%
% name of the fields of all_data_exp(1).data(1).d
fields = fieldnames(all_data(1).data(1).d);
disp(fields);

%
disp(length(sorted_syllables));

%compare if all from most_common_motifs are in sorted_syllables
disp(ismember(most_common_motifs, sorted_syllables));
disp(ismember(most_common_trial_motifs, sorted_syllables));

% plot cmap25
figure;
hold on;
for i = 1:25
    patch([i-1 i i i-1], [0 0 1 1], cmap25(i, :), 'EdgeColor', 'none');
end
xlim([0 25]);
set(gca, 'XTick', 0.5:1:24.5, 'XTickLabel', sorted_syllables);
xlabel('Syllable');
title('cmap25');


% plot cmap25
figure;
hold on;
for i = 1:20
    patch([i-1 i i i-1], [0 0 1 1], cmap20(i, :), 'EdgeColor', 'none');
end
xlim([0 25]);
set(gca, 'XTick', 0.5:1:19.5, 'XTickLabel', most_common_motifs);
xlabel('Syllable');
title('cmap20');