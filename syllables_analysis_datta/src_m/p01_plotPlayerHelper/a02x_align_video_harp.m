function [time_before_first_tcam, time_last_tcam, time_after_last_tcam] = video_player_gui_simple(videoFile, first_tcam, last_tcam)

filename = strrep(strrep(strrep(strrep(strrep(videoFile, '_h265', ''), 'Two', ''), 'camera', 'cameracsv'), 'mp4', 'csv'), 'avi', 'csv');

if ~isfile(fullfile(filename))
    error('Csv file does not exist.');
end

dataTable = readtable(filename);

tolerance = 1e-6;
frames_before_first_tcam = find(abs(dataTable{:, 2} - first_tcam) < tolerance);
frames_last_tcam = find(abs(dataTable{:, 2} - last_tcam) < tolerance);


time_before_first_tcam = frames_before_first_tcam/30;

time_last_tcam = frames_last_tcam/30;

time_after_last_tcam = (height(dataTable) - frames_last_tcam) / 30;
end