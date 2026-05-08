
loading_split_video = false;
show_figures = true;
% MAIN PREPROCESSING PIPELINE FOR THE FULL ANALYSIS WORKSPACE.
% THIS IS THE TOP-LEVEL SCRIPT TO RUN THE LOADING, FIP PREPROCESSING,
% TTL/VIDEO/ARDUINO SYNCING, AND MOTIF/SYLLABLE LOADING STEPS IN ORDER.
% IT BUILDS THE MAIN ALL_DATA STRUCTURE USED BY THE DOWNSTREAM ANALYSIS
% AND FIGURE SCRIPTS.

if show_figures == false
    set(0, 'DefaultFigureVisible', 'off');
end
% FIP DATA PROCESSING
run('a00_load_data.m'); % LOADS FIP DATA INTO ALL_DATA STRUCTURE
run('a10_artifacts_check.m') % CHECKS FOR ARTIFACTS IN FIP DATA (BASED ON VIDEO_FIP_SYNC_DATTA_COLAB.IPYNB FROM YILAN GITHUB)
run('a11_preproc_fip.m') % LOWPASS FILTER AND EXPONENTIAL BLEACHING CORRECTION

% FIRST, I RAN A01_FIND_TTL_VIDEO AND A01_FIND_TTL_VIDEO_4LIGHTS, AND THEN A01B_EXTRACT_TTL AND A01B_EXTRACT_TTL_4LIGHTS.
% THESE SCRIPTS SAVE THE TTL TIMESERIES INTO ALL_DATA STRUCTURE.
run('a01c_load_ttl_traces_from_all_data.m'); % LOADS THE TTL TIMESERIES INTO ALL_DATA STRUCTURE.

run('a07a_find_sync.m'); % SYNCING TTL FIP TO VIDEO
run('a07b_arduino_sync.m'); % SYNCING ARDUINO (BEHAVIOR) TO VIDEO
run('a04_load_motif_data.m'); % LOADS SYLLABLES DATA (CSV) INTO ALL_DATA STRUCTURE.

all_data_backup = all_data;



% SPLIT VIDEO PROCESSING FOR A1 D3.
% THIS STEP IS ONLY FOR THE SESSION WHERE THE VIDEO WAS SAVED IN SPLIT PARTS.
% IT RERUNS THE SAME LOADING AND SYNCING STEPS WITH LOADING_SPLIT_VIDEO ON,
% THEN A07E_SYNC_SPLIT_VIDEO MERGES THE SPLIT VIDEO DATA BACK INTO
% ALL_DATA_BACKUP(1).DATA(3). SPLIT_VIDEO_MODE CONTROLS WHETHER THE GAP
% BETWEEN VIDEO PARTS IS REMOVED OR KEPT AS NAN VALUES.
loading_split_video = true;
split_video_mode = 'remove_gap';  % 'remove_gap' or 'nan_gap'

if loading_split_video
    run('a00_load_data.m');
    run('a10_artifacts_check.m')
    run('a11_preproc_fip.m')
    run('a01c_load_ttl_traces_from_all_data.m');
    run('a07a_find_sync.m');
    run('a07b_arduino_sync.m');
    run('a04_load_motif_data.m');
    run('a07e_sync_split_video.m');  % MERGES INTO ALL_DATA_BACKUP(1).DATA(3)
    all_data = all_data_backup;
end

loading_split_video = false;  % RESET FLAG

set(0, 'DefaultFigureVisible', 'on');

% save('data_0408.mat', 'all_data', '-v7.3');
