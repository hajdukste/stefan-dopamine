
if exist('loading_split_video', 'var') && loading_split_video
    base_path = '/Users/stefan/Downloads/Datta_colab/split_video';
else
    base_path = '/Users/stefan/Downloads/Datta_colab/';
end

% find all csv files across all date folders
csv_files = dir(fullfile(base_path, '**', '*.csv'));

% Exclude split_video folder when not in split video mode
if ~exist('loading_split_video', 'var') || ~loading_split_video
    exclude_mask = contains({csv_files.folder}, 'split_video');
    csv_files(exclude_mask) = [];
end

% parse animal name, day label, and date from each filename
% pattern: {animal}_{dayLabel}_{date}.csv
% dayLabel is 'habituation' or 'dayN', date is 8 digits
animal_names = {};
day_labels = {};
dates = {};
file_paths = {};

for i = 1:length(csv_files)
    fname = csv_files(i).name;
    fname_no_ext = erase(fname, '.csv');

    % extract date (last 8 digits) and day label (habituation or dayN)
    tokens = regexp(fname_no_ext, '^(.+)_(habituation|day\d+)_(\d{8})$', 'tokens');
    if isempty(tokens); continue; end

    animal_names{end+1} = tokens{1}{1};
    day_labels{end+1} = tokens{1}{2};
    dates{end+1} = tokens{1}{3};
    file_paths{end+1} = fullfile(csv_files(i).folder, fname);
end

% build struct: all_data(animal).name, all_data(animal).data(day).d, .day_label, .date
unique_animals = unique(animal_names);
all_data = struct();

for a = 1:length(unique_animals)
    all_data(a).name = unique_animals{a};
    idx = strcmp(animal_names, unique_animals{a});
    a_day_labels = day_labels(idx);
    a_dates = dates(idx);
    a_paths = file_paths(idx);

    for i = 1:length(a_paths)
        % determine array index: habituation=6, dayN=N
        if strcmp(a_day_labels{i}, 'habituation')
            d = 6;
        else
            if ~exist('loading_split_video', 'var') || ~loading_split_video
                d = sscanf(a_day_labels{i}, 'day%d');
            else
                d = i;
            end
        end

        fprintf('Loading %s - %s (%s) -> data(%d)\n', unique_animals{a}, a_day_labels{i}, a_dates{i}, d);
        all_data(a).data(d).day_label = a_day_labels{i};
        all_data(a).data(d).date = a_dates{i};
        % skip loading csv for habituation
        if d == 6
            all_data(a).data(d).d = [];
        else
            all_data(a).data(d).d = readtable(a_paths{i});
        end
        % save file paths (csv, txt, mp4)
        all_data(a).data(d).csv_path = a_paths{i};
        txt_path = strrep(a_paths{i}, '.csv', '.txt');
        mp4_path = strrep(a_paths{i}, '.csv', '_video.mp4');
        all_data(a).data(d).txt_path = txt_path;
        all_data(a).data(d).mp4_path = mp4_path;
        % load matching txt file (fiber photometry)
        if isfile(txt_path)
            all_data(a).data(d).fip = readtable(txt_path, 'FileType', 'text', 'Delimiter', '\t', 'ReadVariableNames', false);
            all_data(a).data(d).fip.Properties.VariableNames = {'time', 'signal', 'reference'};
        else
            all_data(a).data(d).fip = [];
        end
    end
end


if exist('loading_split_video', 'var') && loading_split_video
    % For split video: restructure 2 animals into 1 animal with 2 days
    % C57_51_9_2 = part 1 (first part of recording)
    % C57_51_9 = part 2 (second part of recording)

    % Find which animal is which
    idx_part1 = find(strcmp({all_data.name}, 'C57_51_9_2'));
    idx_part2 = find(strcmp({all_data.name}, 'C57_51_9'));

    % Combine into single data array
    data_combined = [all_data(idx_part1).data(1), all_data(idx_part2).data(1)];
    data_combined(1).part_label = 'part1';
    data_combined(2).part_label = 'part2';

    all_data_temp = struct();
    all_data_temp(1).name = 'split_video';
    all_data_temp(1).region = 'NAcMed';
    all_data_temp(1).data = data_combined;

    all_data = all_data_temp;
else
    % remove animal 'C57_51_9_2' (duplicate recording, not a separate animal)
    remove_idx = strcmp({all_data.name}, 'C57_51_9_2');
    all_data(remove_idx) = [];

    % assign recording region
    region_map = { ...
        'K413_5', 'NAcLat'; ...
        'K413_3', 'NAcMed'; ...
        'K413_1', 'NAcMed'; ...
        'C57_51_9', 'NAcMed'; ...
        'K411_0', 'NAcLat'; ...
        'K411_2', 'NAcLat'};

    for a = 1:length(all_data)
        match = strcmp(region_map(:,1), all_data(a).name);
        all_data(a).region = region_map{match, 2};
    end
end

fprintf('Loaded %d animals\n', length(all_data));
for a = 1:length(all_data)
    fprintf('  %s: %d sessions\n', all_data(a).name, length(all_data(a).data));
end
