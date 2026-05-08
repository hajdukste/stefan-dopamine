
% load keypoint-moseq motif data and add to all_data
% assumes all_data is already loaded from a00_load_data.m

kpms_results_path = '/Users/stefan/Downloads/berkeley_collab/kpms/model/2026_01_21-15_28_19/results';

for a = 1:length(all_data)
for d = 1:length(all_data(a).data)

    [~, fname, ext] = fileparts(all_data(a).data(d).csv_path);
    kpms_file = fullfile(kpms_results_path, [fname ext]);

    if ~isfile(kpms_file)
        fprintf('Skipping %s - %s (no kpms file)\n', all_data(a).name, all_data(a).data(d).day_label);
        all_data(a).data(d).motifs = [];
        continue;
    end

    fprintf('Loading %s - %s\n', all_data(a).name, all_data(a).data(d).day_label);
    all_data(a).data(d).motifs = readtable(kpms_file);

end
end


for ia = 1:length(all_data)
    flds = fieldnames(all_data(ia).data);
    if ismember('motifs', flds)
        new_order = [{'motifs'}; flds(~strcmp(flds, 'motifs'))];
        all_data(ia).data = orderfields(all_data(ia).data, new_order);
    end
end