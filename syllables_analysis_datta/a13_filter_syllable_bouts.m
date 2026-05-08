% a13_filter_syllable_bouts.m
% Replace short or long syllable bouts in all_data(...).data(...).d.syllable with -1.
%
% Run after a04_load_motif_data.m.
% If you want counts like most_common_motifs or sorted_syllables to reflect
% the filtered syllables, run this before a00_process_data.m or rerun
% a00_process_data.m after applying the filter.

%--------------------------------------------------------------------------
% Parameters
%--------------------------------------------------------------------------
mode = 'restore';              % 'apply' or 'restore'
min_or_max = 'max';          % 'min' removes shorter bouts, 'max' removes longer bouts
filter_mode = 'min_frames';  % 'min_frames' or 'percentile'
min_frames = 30;             % used when filter_mode = 'min_frames'
min_percentile = 30;         % used when filter_mode = 'percentile'
replacement_value = -1;
backup_var = 'syllables_og';
skip_animals_days = [0 0];
verbose = true;

%--------------------------------------------------------------------------
% Validate inputs
%--------------------------------------------------------------------------
if ~exist('all_data', 'var')
    error('a13_filter_syllable_bouts requires all_data in the workspace.');
end

valid_modes = {'apply', 'restore'};
if ~ismember(mode, valid_modes)
    error('mode must be one of: %s', strjoin(valid_modes, ', '));
end

valid_filter_modes = {'min_frames', 'percentile'};
if ~ismember(filter_mode, valid_filter_modes)
    error('filter_mode must be one of: %s', strjoin(valid_filter_modes, ', '));
end

valid_min_or_max = {'min', 'max'};
if ~ismember(min_or_max, valid_min_or_max)
    error('min_or_max must be one of: %s', strjoin(valid_min_or_max, ', '));
end

if strcmp(mode, 'apply')
    if strcmp(filter_mode, 'min_frames') && (isempty(min_frames) || min_frames < 1)
        error('min_frames must be >= 1 when filter_mode = ''min_frames''.');
    end
    if strcmp(filter_mode, 'percentile') && (isempty(min_percentile) || min_percentile < 0 || min_percentile > 100)
        error('min_percentile must be between 0 and 100 when filter_mode = ''percentile''.');
    end
end

%--------------------------------------------------------------------------
% Apply or restore
%--------------------------------------------------------------------------
if strcmp(mode, 'restore')
    restore_summary = struct( ...
        'sessions_restored', 0, ...
        'sessions_missing_backup', 0, ...
        'frames_restored', 0);

    for animal = 1:length(all_data)
        for day = 1:length(all_data(animal).data)
            if ismember([animal, day], skip_animals_days, 'rows'); continue; end
            if ~isfield(all_data(animal).data(day), 'd'); continue; end

            d = all_data(animal).data(day).d;
            if isempty(d); continue; end
            if ~ismember('syllable', d.Properties.VariableNames); continue; end

            if ~ismember(backup_var, d.Properties.VariableNames)
                restore_summary.sessions_missing_backup = restore_summary.sessions_missing_backup + 1;
                if verbose
                    fprintf('A%d D%d: no %s backup found, skipping restore\n', animal, day, backup_var);
                end
                continue;
            end

            source_syllables = d.(backup_var);
            if length(source_syllables) ~= height(d)
                error('A%d D%d: %s length does not match d height.', animal, day, backup_var);
            end

            changed_frames = sum(d.syllable ~= source_syllables);
            d.syllable = source_syllables;
            all_data(animal).data(day).d = d;

            restore_summary.sessions_restored = restore_summary.sessions_restored + 1;
            restore_summary.frames_restored = restore_summary.frames_restored + changed_frames;

            if verbose
                fprintf('A%d D%d: restored %d frames from %s\n', animal, day, changed_frames, backup_var);
            end
        end
    end

    a13_filter_info = struct();
    a13_filter_info.mode = mode;
    a13_filter_info.min_or_max = min_or_max;
    a13_filter_info.filter_mode = filter_mode;
    a13_filter_info.summary = restore_summary;

    fprintf('\nRestore complete: %d sessions restored, %d frames restored, %d sessions missing backup\n', ...
        restore_summary.sessions_restored, restore_summary.frames_restored, ...
        restore_summary.sessions_missing_backup);
    return;
end

%--------------------------------------------------------------------------
% First pass: make sure backup exists and gather run lengths if needed
%--------------------------------------------------------------------------
length_map = containers.Map('KeyType', 'double', 'ValueType', 'any');
apply_summary = struct( ...
    'sessions_processed', 0, ...
    'sessions_with_backup_created', 0, ...
    'runs_replaced', 0, ...
    'frames_replaced', 0);

for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ~isfield(all_data(animal).data(day), 'd'); continue; end

        d = all_data(animal).data(day).d;
        if isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end

        if ~ismember(backup_var, d.Properties.VariableNames)
            d.(backup_var) = d.syllable;
            all_data(animal).data(day).d = d;
            apply_summary.sessions_with_backup_created = apply_summary.sessions_with_backup_created + 1;
        end

        source_syllables = all_data(animal).data(day).d.(backup_var);
        [run_syllables, run_lengths, ~, ~] = a13_compute_runs(source_syllables);

        if strcmp(filter_mode, 'percentile')
            for i_run = 1:length(run_syllables)
                syl = run_syllables(i_run);
                if isnan(syl) || syl == replacement_value
                    continue;
                end
                if isKey(length_map, syl)
                    length_map(syl) = [length_map(syl); run_lengths(i_run)];
                else
                    length_map(syl) = run_lengths(i_run);
                end
            end
        end
    end
end

percentile_thresholds = containers.Map('KeyType', 'double', 'ValueType', 'double');
if strcmp(filter_mode, 'percentile')
    syl_keys = cell2mat(keys(length_map));
    for i_key = 1:length(syl_keys)
        syl = syl_keys(i_key);
        percentile_thresholds(syl) = prctile(length_map(syl), min_percentile);
    end
end

%--------------------------------------------------------------------------
% Second pass: rewrite selected bouts to replacement_value
%--------------------------------------------------------------------------
for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ~isfield(all_data(animal).data(day), 'd'); continue; end

        d = all_data(animal).data(day).d;
        if isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end
        if ~ismember(backup_var, d.Properties.VariableNames); continue; end

        source_syllables = d.(backup_var);
        [run_syllables, run_lengths, run_starts, run_ends] = a13_compute_runs(source_syllables);

        filtered_syllables = source_syllables;
        runs_replaced_this_session = 0;
        frames_replaced_this_session = 0;

        for i_run = 1:length(run_syllables)
            syl = run_syllables(i_run);
            run_length = run_lengths(i_run);
            replace_this_run = false;

            if isnan(syl) || syl == replacement_value
                continue;
            end

            switch filter_mode
                case 'min_frames'
                    replace_this_run = a13_should_replace(run_length, min_frames, min_or_max);

                case 'percentile'
                    if ~isKey(percentile_thresholds, syl)
                        continue;
                    end
                    replace_this_run = a13_should_replace(run_length, percentile_thresholds(syl), min_or_max);
            end

            if replace_this_run
                idx = run_starts(i_run):run_ends(i_run);
                filtered_syllables(idx) = replacement_value;
                runs_replaced_this_session = runs_replaced_this_session + 1;
                frames_replaced_this_session = frames_replaced_this_session + numel(idx);
            end
        end

        d.syllable = filtered_syllables;
        all_data(animal).data(day).d = d;

        apply_summary.sessions_processed = apply_summary.sessions_processed + 1;
        apply_summary.runs_replaced = apply_summary.runs_replaced + runs_replaced_this_session;
        apply_summary.frames_replaced = apply_summary.frames_replaced + frames_replaced_this_session;

        if verbose
            fprintf('A%d D%d: replaced %d bouts (%d frames)\n', ...
                animal, day, runs_replaced_this_session, frames_replaced_this_session);
        end
    end
end

a13_filter_info = struct();
a13_filter_info.mode = mode;
a13_filter_info.min_or_max = min_or_max;
a13_filter_info.filter_mode = filter_mode;
a13_filter_info.min_frames = min_frames;
a13_filter_info.min_percentile = min_percentile;
a13_filter_info.replacement_value = replacement_value;
a13_filter_info.backup_var = backup_var;
a13_filter_info.summary = apply_summary;
if strcmp(filter_mode, 'percentile')
    a13_filter_info.percentile_thresholds = percentile_thresholds;
end

fprintf('\nApply complete: %d sessions processed, %d backups created, %d bouts replaced, %d frames replaced\n', ...
    apply_summary.sessions_processed, apply_summary.sessions_with_backup_created, ...
    apply_summary.runs_replaced, apply_summary.frames_replaced);

%--------------------------------------------------------------------------
function [run_syllables, run_lengths, run_starts, run_ends] = a13_compute_runs(syllables)
    n_rows = length(syllables);
    run_starts = [1; find(diff(syllables) ~= 0) + 1];
    run_ends = [run_starts(2:end) - 1; n_rows];
    run_syllables = syllables(run_starts);
    run_lengths = run_ends - run_starts + 1;
end

function replace_this_run = a13_should_replace(run_length, threshold, min_or_max)
    switch min_or_max
        case 'min'
            replace_this_run = run_length < threshold;
        case 'max'
            replace_this_run = run_length > threshold;
        otherwise
            error('Unknown min_or_max: %s', min_or_max);
    end
end
