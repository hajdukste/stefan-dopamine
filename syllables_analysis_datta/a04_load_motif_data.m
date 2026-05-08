
% load keypoint-moseq motif data and add to d_new
animals = 1:6;
days = 1:6;

if exist('loading_split_video', 'var') && loading_split_video
    animals = 1;
    days = 1:2;
end

for animal = animals
for day = days
disp(sprintf('Processing A%d D%d', animal, day));

if (animal == 1 && day == 3); continue; end

kpms_results_path = '/Users/stefan/Downloads/berkeley_collab-1/kpms/model/2026_01_21-15_28_19/results';

% get filename from csv_path
[~, fname, ext] = fileparts(all_data(animal).data(day).csv_path);
kpms_file = fullfile(kpms_results_path, [fname ext]);

if ~isfile(kpms_file)
    error('KPMS result file not found: %s', kpms_file);
end

fprintf('Loading %s\n', kpms_file);
kpms = readtable(kpms_file);

% Get d_new and check frame alignment
d_new = all_data(animal).data(day).d_new;
first_frame = d_new.frame_idx(1);
last_frame = d_new.frame_idx(end);
n_d_new = height(d_new);

fprintf('d_new: %d rows, frame_idx %d to %d\n', n_d_new, first_frame, last_frame);
fprintf('kpms:  %d rows (should match original video length)\n', height(kpms));

% Check kpms length matches expected video length
if height(kpms) ~= last_frame
    error('kpms has %d rows, but last frame_idx is %d', height(kpms), last_frame);
end

% Extract kpms rows corresponding to d_new frame indices
kpms_aligned = kpms(d_new.frame_idx, :);
fprintf('Extracted kpms rows %d to %d (matching d_new frame_idx)\n', first_frame, last_frame);

% Verify alignment
if height(kpms_aligned) ~= height(d_new)
    error('Row mismatch after alignment: kpms has %d rows, d_new has %d rows', height(kpms_aligned), height(d_new));
end

% remove any kpms columns already in d_new (from previous runs)
overlap = intersect(d_new.Properties.VariableNames, kpms_aligned.Properties.VariableNames);
if ~isempty(overlap)
    d_new(:, overlap) = [];
end

% add kpms columns to d_new
d_new = [d_new, kpms_aligned];
all_data(animal).data(day).d_new = d_new;

fprintf('Added %d columns from kpms to d_new (%d total columns)\n', width(kpms_aligned), width(d_new));

end
end
