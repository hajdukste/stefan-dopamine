% Export loaded all_data tables into a Python-readable folder structure.
%
% Run this script from the MATLAB workspace after all_data has been loaded
% and processed. It exports all columns from each session's frame-aligned
% table and behavioral event table.

export_root = '/Users/stefan/Downloads/all_data_python_export';
days_to_export = 1:5;
python_exe = '/opt/anaconda3/envs/py312/bin/python';
overwrite_existing = true;

timeseries_base = 'frame_aligned_timeseries';
events_base = 'behavioral_events';

%--------------------------------------------------------------------------

if ~exist('all_data', 'var')
    error('all_data is not loaded in the current MATLAB workspace.');
end

if ~isfolder(export_root)
    mkdir(export_root);
end

python_converter = writePythonConverter(tempdir);
writeExportReadme(export_root, timeseries_base, events_base);

manifest = struct( ...
    'animal_index', {}, ...
    'animal_name', {}, ...
    'region', {}, ...
    'day_index', {}, ...
    'day_label', {}, ...
    'session_folder', {}, ...
    'timeseries_rows', {}, ...
    'timeseries_columns', {}, ...
    'event_rows', {}, ...
    'event_columns', {}, ...
    'status', {}, ...
    'note', {});

fprintf('Exporting all_data to %s\n', export_root);

for day = days_to_export
    day_name = sprintf('day%d', day);
    day_folder = fullfile(export_root, day_name);
    if ~isfolder(day_folder)
        mkdir(day_folder);
    end

    for animal = 1:numel(all_data)
        animal_name = getStructText(all_data(animal), 'name', sprintf('animal_%02d', animal));
        region = getStructText(all_data(animal), 'region', '');
        animal_folder = fullfile(day_folder, sanitizePathName(animal_name));
        if ~isfolder(animal_folder)
            mkdir(animal_folder);
        end

        row = newManifestRow(animal, animal_name, region, day, day_name, animal_folder);

        if ~isfield(all_data(animal), 'data') || day > numel(all_data(animal).data)
            row.status = 'skipped';
            row.note = 'day index not present';
            manifest(end + 1) = row; %#ok<SAGROW>
            fprintf('  skipped %s %s: %s\n', animal_name, day_name, row.note);
            continue;
        end

        session = all_data(animal).data(day);
        day_label = getStructText(session, 'day_label', day_name);
        row.day_label = day_label;

        if ~isfield(session, 'd') || ~istable(session.d) || isempty(session.d) || height(session.d) == 0
            row.status = 'skipped';
            row.note = 'frame-aligned table is missing or empty';
            manifest(end + 1) = row; %#ok<SAGROW>
            fprintf('  skipped %s %s: %s\n', animal_name, day_name, row.note);
            continue;
        end

        timeseries_table = makePythonReadableTable(session.d);
        if isfield(session, 'd_old') && istable(session.d_old)
            events_table = makePythonReadableTable(session.d_old);
        else
            events_table = table();
        end

        timeseries_csv = fullfile(animal_folder, [timeseries_base '.csv']);
        events_csv = fullfile(animal_folder, [events_base '.csv']);
        timeseries_npz = fullfile(animal_folder, [timeseries_base '.npz']);
        events_npz = fullfile(animal_folder, [events_base '.npz']);
        timeseries_schema = fullfile(animal_folder, [timeseries_base '.schema.json']);
        events_schema = fullfile(animal_folder, [events_base '.schema.json']);
        metadata_path = fullfile(animal_folder, 'session_metadata.json');

        if ~overwrite_existing
            output_paths = {timeseries_csv, events_csv, timeseries_npz, events_npz, ...
                timeseries_schema, events_schema, metadata_path};
            if any(cellfun(@isfile, output_paths))
                row.status = 'skipped';
                row.note = 'one or more output files already exist';
                manifest(end + 1) = row; %#ok<SAGROW>
                fprintf('  skipped %s %s: %s\n', animal_name, day_name, row.note);
                continue;
            end
        end

        writetable(timeseries_table, timeseries_csv);
        if width(events_table) == 0
            writeEmptyCsv(events_csv);
        else
            writetable(events_table, events_csv);
        end

        runPythonCsvConverter(python_exe, python_converter, timeseries_csv, ...
            timeseries_npz, timeseries_schema, 'time');
        if width(events_table) == 0
            writeEmptySchema(events_schema, 'time');
            writeEmptyNpz(python_exe, python_converter, events_csv, events_npz, events_schema, 'time');
        else
            runPythonCsvConverter(python_exe, python_converter, events_csv, ...
                events_npz, events_schema, 'time');
        end

        metadata = makeSessionMetadata(all_data(animal), session, animal, day, ...
            animal_name, region, day_label, animal_folder, ...
            timeseries_table, events_table, timeseries_base, events_base);
        writeJsonFile(metadata_path, metadata);

        row.timeseries_rows = height(timeseries_table);
        row.timeseries_columns = width(timeseries_table);
        row.event_rows = height(events_table);
        row.event_columns = width(events_table);
        row.status = 'exported';
        if width(events_table) == 0
            row.note = 'exported frame-aligned table; behavioral event table was missing';
        else
            row.note = 'exported';
        end
        manifest(end + 1) = row; %#ok<SAGROW>

        fprintf('  exported %s %s: %d frame rows, %d event rows\n', ...
            animal_name, day_name, height(timeseries_table), height(events_table));
    end
end

writeManifestFiles(export_root, manifest);

n_exported = sum(strcmp({manifest.status}, 'exported'));
n_skipped = sum(strcmp({manifest.status}, 'skipped'));
fprintf('Done. Exported %d sessions, skipped %d sessions.\n', n_exported, n_skipped);
fprintf('Manifest: %s\n', fullfile(export_root, 'manifest.csv'));

%--------------------------------------------------------------------------

function row = newManifestRow(animal_index, animal_name, region, day_index, day_label, session_folder)
row = struct();
row.animal_index = animal_index;
row.animal_name = char(animal_name);
row.region = char(region);
row.day_index = day_index;
row.day_label = char(day_label);
row.session_folder = char(session_folder);
row.timeseries_rows = 0;
row.timeseries_columns = 0;
row.event_rows = 0;
row.event_columns = 0;
row.status = '';
row.note = '';
end

function out_table = makePythonReadableTable(in_table)
n_rows = height(in_table);
var_names = in_table.Properties.VariableNames;
out_table = table();

for i_var = 1:numel(var_names)
    var_name = var_names{i_var};
    out_table.(var_name) = makePythonReadableColumn(in_table.(var_name), n_rows);
end
end

function col = makePythonReadableColumn(value, n_rows)
if isnumeric(value) || islogical(value)
    if isVectorWithOneValuePerRow(value, n_rows)
        col = reshape(value, n_rows, 1);
    else
        col = encodeRowsAsJson(value, n_rows);
    end
elseif isdatetime(value) || isduration(value)
    if isVectorWithOneValuePerRow(value, n_rows)
        col = reshape(value, n_rows, 1);
    else
        col = encodeRowsAsJson(value, n_rows);
    end
elseif iscategorical(value)
    if isVectorWithOneValuePerRow(value, n_rows)
        col = cellstr(reshape(value, n_rows, 1));
    else
        col = encodeRowsAsJson(value, n_rows);
    end
elseif isstring(value)
    if isVectorWithOneValuePerRow(value, n_rows)
        col = cellstr(reshape(value, n_rows, 1));
    else
        col = encodeRowsAsJson(value, n_rows);
    end
elseif ischar(value)
    if size(value, 1) == n_rows
        col = cellstr(value);
    elseif n_rows == 1
        col = {value};
    else
        col = encodeRowsAsJson(value, n_rows);
    end
elseif iscell(value)
    if isVectorWithOneValuePerRow(value, n_rows)
        col = cell(n_rows, 1);
        for i_row = 1:n_rows
            col{i_row} = encodeCellValue(value{i_row});
        end
    else
        col = encodeRowsAsJson(value, n_rows);
    end
else
    col = encodeRowsAsJson(value, n_rows);
end
end

function tf = isVectorWithOneValuePerRow(value, n_rows)
tf = isvector(value) && numel(value) == n_rows;
end

function col = encodeRowsAsJson(value, n_rows)
col = cell(n_rows, 1);

for i_row = 1:n_rows
    try
        row_value = getRowValue(value, i_row, n_rows);
        col{i_row} = encodeJsonText(row_value);
    catch err
        col{i_row} = sprintf('[unexportable row: %s]', err.message);
    end
end
end

function row_value = getRowValue(value, i_row, n_rows)
if size(value, 1) == n_rows
    row_value = value(i_row, :);
elseif numel(value) == n_rows
    row_value = value(i_row);
else
    row_value = value;
end
end

function text = encodeCellValue(value)
if isempty(value)
    text = '';
elseif ischar(value)
    text = value;
elseif isstring(value) && isscalar(value)
    text = char(value);
elseif iscategorical(value) && isscalar(value)
    text = char(value);
elseif (isnumeric(value) || islogical(value)) && isscalar(value)
    text = char(string(value));
elseif isdatetime(value) && isscalar(value)
    text = char(value);
elseif isduration(value) && isscalar(value)
    text = char(value);
else
    text = encodeJsonText(value);
end
end

function text = encodeJsonText(value)
try
    value = normalizeJsonValue(value);
    text = char(jsonencode(value));
catch
    try
        text = strtrim(evalc('disp(value)'));
    catch err
        text = sprintf('[unexportable value: %s]', err.message);
    end
end
end

function value = normalizeJsonValue(value)
if istable(value)
    value = table2struct(value);
elseif iscategorical(value)
    value = cellstr(value);
elseif isdatetime(value) || isduration(value)
    value = cellstr(char(value));
elseif isstring(value)
    value = cellstr(value);
elseif iscell(value)
    for i = 1:numel(value)
        value{i} = normalizeJsonValue(value{i});
    end
elseif isstruct(value)
    names = fieldnames(value);
    for i_struct = 1:numel(value)
        for i_name = 1:numel(names)
            value(i_struct).(names{i_name}) = normalizeJsonValue(value(i_struct).(names{i_name}));
        end
    end
end
end

function metadata = makeSessionMetadata(animal_struct, session, animal_index, day_index, ...
    animal_name, region, day_label, session_folder, timeseries_table, events_table, ...
    timeseries_base, events_base)
metadata = struct();
metadata.exported_at = datestr(now, 31);
metadata.animal_name = char(animal_name);
metadata.animal_index = animal_index;
metadata.region = char(region);
metadata.day_index = day_index;
metadata.day_label = char(day_label);
metadata.date = getStructText(session, 'date', '');
metadata.session_folder = char(session_folder);
metadata.files = struct( ...
    'frame_aligned_timeseries_csv', [timeseries_base '.csv'], ...
    'frame_aligned_timeseries_npz', [timeseries_base '.npz'], ...
    'frame_aligned_timeseries_schema', [timeseries_base '.schema.json'], ...
    'behavioral_events_csv', [events_base '.csv'], ...
    'behavioral_events_npz', [events_base '.npz'], ...
    'behavioral_events_schema', [events_base '.schema.json']);
metadata.frame_aligned_timeseries = struct( ...
    'description', 'All columns from all_data(animal).data(day).d; one row per video-frame-aligned timepoint.', ...
    'row_count', height(timeseries_table), ...
    'column_count', width(timeseries_table), ...
    'columns', {timeseries_table.Properties.VariableNames});
metadata.behavioral_events = struct( ...
    'description', 'All columns from all_data(animal).data(day).d_old; one row per discrete behavioral event.', ...
    'row_count', height(events_table), ...
    'column_count', width(events_table), ...
    'columns', {events_table.Properties.VariableNames});
metadata.source_paths = struct( ...
    'csv_path', getStructText(session, 'csv_path', ''), ...
    'txt_path', getStructText(session, 'txt_path', ''), ...
    'mp4_path', getStructText(session, 'mp4_path', ''));

if isfield(animal_struct, 'name')
    metadata.source_animal_name = getStructText(animal_struct, 'name', '');
end
end

function writeManifestFiles(export_root, manifest)
manifest_csv = fullfile(export_root, 'manifest.csv');
manifest_json = fullfile(export_root, 'manifest.json');

if isempty(manifest)
    writeEmptyCsv(manifest_csv);
    manifest_json_value = struct();
    manifest_json_value.sessions = [];
    writeJsonFile(manifest_json, manifest_json_value);
    return;
end

manifest_table = struct2table(manifest);
writetable(manifest_table, manifest_csv);
manifest_json_value = struct();
manifest_json_value.sessions = manifest;
writeJsonFile(manifest_json, manifest_json_value);
end

function writeExportReadme(export_root, timeseries_base, events_base)
readme_path = fullfile(export_root, 'README.md');
fid = fopen(readme_path, 'w');
if fid < 0
    error('Could not write README: %s', readme_path);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# all_data Python Export\n\n');
fprintf(fid, 'This folder was generated from the MATLAB `all_data` workspace.\n\n');
fprintf(fid, '## Layout\n\n');
fprintf(fid, '- `day1/` through `day5/`: training-day folders.\n');
fprintf(fid, '- `dayN/<animal_name>/`: one exported session for one animal on one day.\n');
fprintf(fid, '- `manifest.csv` and `manifest.json`: exported/skipped session summary.\n\n');
fprintf(fid, '## Session Files\n\n');
fprintf(fid, '- `%s.csv`: all columns from `all_data(animal).data(day).d`, with one row per frame-aligned timepoint.\n', timeseries_base);
fprintf(fid, '- `%s.csv`: all columns from `all_data(animal).data(day).d_old`, with one row per behavioral event.\n', events_base);
fprintf(fid, '- `%s.npz` and `%s.npz`: NumPy array versions of the CSV files.\n', timeseries_base, events_base);
fprintf(fid, '- `*.schema.json`: column names, inferred Python dtypes, and index field.\n');
fprintf(fid, '- `session_metadata.json`: animal/day metadata, row counts, column lists, and source paths.\n\n');
fprintf(fid, 'For the frame-aligned table, `time` is saved as `__index__` in the `.npz` file when available.\n');
fprintf(fid, 'For the behavioral event table, `time` is saved as `__index__` in the `.npz` file when available.\n');
end

function converter_path = writePythonConverter(folder)
converter_path = fullfile(folder, 'all_data_csv_to_npz.py');
lines = {
    'import json'
    'import sys'
    'from pathlib import Path'
    ''
    'import numpy as np'
    'import pandas as pd'
    ''
    'csv_path = Path(sys.argv[1])'
    'npz_path = Path(sys.argv[2])'
    'schema_path = Path(sys.argv[3])'
    'index_name = sys.argv[4] if len(sys.argv) > 4 else ""'
    ''
    'try:'
    '    df = pd.read_csv(csv_path)'
    'except pd.errors.EmptyDataError:'
    '    df = pd.DataFrame()'
    ''
    'def kind_for(series):'
    '    if pd.api.types.is_bool_dtype(series):'
    '        return "bool"'
    '    if pd.api.types.is_numeric_dtype(series):'
    '        return "numeric"'
    '    if pd.api.types.is_datetime64_any_dtype(series):'
    '        return "datetime"'
    '    return "string"'
    ''
    'schema = {"index_name": index_name or None, "columns": []}'
    'arrays = {}'
    ''
    'if index_name and index_name in df.columns:'
    '    arrays["__index__"] = df[index_name].to_numpy()'
    ''
    'for col in df.columns:'
    '    series = df[col]'
    '    kind = kind_for(series)'
    '    schema["columns"].append({"name": col, "kind": kind, "dtype": str(series.dtype)})'
    '    if kind in {"numeric", "bool"}:'
    '        arrays[col] = series.to_numpy()'
    '    else:'
    '        arrays[col] = series.fillna("").astype(str).to_numpy()'
    ''
    'npz_path.parent.mkdir(parents=True, exist_ok=True)'
    'schema_path.parent.mkdir(parents=True, exist_ok=True)'
    'np.savez_compressed(npz_path, **arrays)'
    'schema_path.write_text(json.dumps(schema, indent=2), encoding="utf-8")'
    };

fid = fopen(converter_path, 'w');
if fid < 0
    error('Could not write Python converter: %s', converter_path);
end
cleanup = onCleanup(@() fclose(fid));
for i_line = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i_line});
end
end

function runPythonCsvConverter(python_exe, converter_path, csv_path, npz_path, schema_path, index_name)
cmd = sprintf('%s %s %s %s %s %s', ...
    shellQuote(python_exe), shellQuote(converter_path), shellQuote(csv_path), ...
    shellQuote(npz_path), shellQuote(schema_path), shellQuote(index_name));
[status, output] = system(cmd);
if status ~= 0
    error('Python CSV conversion failed for %s:\n%s', csv_path, output);
end
end

function writeEmptyNpz(python_exe, converter_path, csv_path, npz_path, schema_path, index_name)
runPythonCsvConverter(python_exe, converter_path, csv_path, npz_path, schema_path, index_name);
end

function writeEmptySchema(schema_path, index_name)
schema = struct('index_name', index_name, 'columns', []);
writeJsonFile(schema_path, schema);
end

function writeEmptyCsv(csv_path)
fid = fopen(csv_path, 'w');
if fid < 0
    error('Could not write empty CSV: %s', csv_path);
end
fclose(fid);
end

function writeJsonFile(path, value)
try
    text = jsonencode(value, 'PrettyPrint', true);
catch
    text = jsonencode(value);
end

fid = fopen(path, 'w');
if fid < 0
    error('Could not write JSON file: %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
end

function text = getStructText(s, field_name, default_value)
text = default_value;
if isstruct(s) && isfield(s, field_name) && ~isempty(s.(field_name))
    value = s.(field_name);
    if ischar(value)
        text = value;
    elseif isstring(value) && isscalar(value)
        text = char(value);
    elseif isnumeric(value) || islogical(value)
        text = char(string(value));
    else
        text = encodeJsonText(value);
    end
end
end

function safe_name = sanitizePathName(name)
safe_name = regexprep(char(name), '[/:*?"<>|\\]', '_');
safe_name = strtrim(safe_name);
if isempty(safe_name)
    safe_name = 'unnamed';
end
end

function quoted = shellQuote(value)
value = char(value);
value = strrep(value, '\', '\\');
value = strrep(value, '"', '\"');
quoted = ['"' value '"'];
end
