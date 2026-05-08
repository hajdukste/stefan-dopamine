# Syllables Analysis Datta

MATLAB workspace scripts for preprocessing, analyzing, and plotting fiber photometry, behavior, video tracking, TTL sync, and keypoint-MoSeq syllable data from the Datta collaboration workflow.

These files are working analysis scripts, not a packaged MATLAB toolbox. They are normally run from an interactive MATLAB session after the relevant raw data paths and workspace variables have been configured.

## Main Entry Points

- `a00___run_whole_pipeline.m` is the main preprocessing entrypoint. It loads FIP data, checks artifacts, preprocesses photometry with lowpass filtering and bleaching correction, loads TTL traces, syncs FIP/video/Arduino timing, loads MoSeq syllables, and handles the split-video session by merging split video data back into `all_data`.
- `a00___extract_data_to_python.m` exports processed `all_data` session tables into a Python-readable folder structure with CSV, NPZ, schema JSON, metadata JSON, and a manifest.

## File Groups

- Files starting with `a` are preprocessing, loading, syncing, filtering, and export scripts.
- Files starting with `b` are behavioral analysis scripts.
- Files starting with `c` are syllable/motif analysis scripts.
- Files starting with `f` are figure and plotting scripts.
- Files starting with `p` are interactive plot-player scripts.
- Files starting with `v` are video or GUI scripts.
- `src_m/` contains helper functions used by the interactive plot player.

## Main Scripts

- `b01_beh_analysis.m` plots behavioral performance of mice, including trial counts per day and mean trial duration summaries.
- `c01b_advanced_motif_coverage.m` plots common syllable/motif summaries, including a most-common syllables histogram and related speed/FIP motif summaries.
- `f01_run_psth_figures.m` runs PSTH figure workflows: trial start/end PSTHs, day-by-day region plots, day-5 animal summaries, hybrid time-to-go plots, syllable onset PSTH grids, split syllable summaries, and heatmap summaries.
- `f11_plot_trial_trajectories.m` plots full trial XY trajectories by animal, day, or valve, with gray, phase, cluster, or syllable coloring.
- `f12_plot_syllable_spatial_trajectories.m` plots selected syllable trajectory segments and ratemap-style spatial summaries.
- `p01_plot_main.m` opens an interactive long-timescale trace and behavior plot player.
- `v01_video_gui.m` opens a synchronized video GUI with syllable overlays, tracking trail, dopamine trace, and trial event markers.

## Data Notes

The main loaded container is `all_data(animal).data(day)`. Frame-aligned continuous data is usually in `.d`, discrete event records are usually in `.d_old`, corrected photometry is usually `d.zsc_exp`, and syllable IDs are in `d.syllable`.

The source data are saved on Synology at `abstract_cue_project/Datta collaboration`.

Large `.mat` data files are intentionally excluded from this repository.
