
glitch = 0;
animal = 1;
day = 1;

project_root = fileparts(mfilename('fullpath'));
addpath(fullfile(project_root, 'src_m'))
addpath(fullfile(project_root, 'src_m', 'p01_plotPlayerHelper'))

ser_ylim = [-3.5, 3.5];
variable_per_row = 0;
num_rows = 4 + variable_per_row*2;

start_seconds = 0;
seconds_per_row = 1600;
default_variables = ["none", "none", "none", "none", "none", "none"];
plot_sero_speed = [0, 1];
images = 0;

%Fig1 and Fig4
paper_figure = [0, 800, 40, 2550, 1, 4]; %newest
% paper_figure = [0, 400, 30, 1500, 14, 4]; %14_4 speed,sero plots first
% paper_figure = [0, 400, 30, 2450, 14, 4]; %14_4 speed,sero plots first
% paper_figure = [2, 1750, 80, 800, 14, 4];

%Fig2
% paper_figure = [2, 100, 0, 2950, 11, 4]; %new
% paper_figure = [2, 150, 0, 2870, 10, 7]; %10_7 for fm still figure LONG
% paper_figure = [1, 150, 0, 2010, 14, 4]; %10_7 for fm still figure SHORT

%Fig3
% paper_figure = [1, 214, 15, 3076, 14, 4]; %new
% paper_figure = [1, 150, 10, 3050, 14, 9]; %wrong? for fm short bursts figure, also 2 brief quiesc!!

% paper_figure = [2, 150, 10, 3500, 10, 6]; %short bursts n2
% paper_figure = [0, 150, 10, 3050, 10, 10]; %short bursts n3
% paper_figure = [0, 150, 10, 3968, 10, 10]; %short bursts n4

% paper_figure = [0, 400, 30, 1900, 14, 4];

%Valve
% paper_figure = [0, 3000, 0, 100, 15, 4]; %0 or 50
% paper_figure = [0, 150, 0, 1920, 15, 4]; %470 1160 1920

%New Figure
% paper_figure = [0, 1600, 70, 1600, 14, 4]; %new figure long, a lot of quiescences with diff lenghts

%Fig6
% paper_figure = [0, 200, 10, 1000, 14, 4]; %hmm
% paper_figure = [0, 200, 10, 1, 1, 2]; %hmm

%Diff baseline pc1, wp, run vs quisc
% paper_figure = [0, 100, 5, 2030, 11, 4]; %hmm

% supfig1
% paper_figure = [1, 600, 25, 1635, 14, 6]; %hmm


%Misc
% paper_figure = [0, 800, 100, 700, 10, 1]; %overlap run pc1 wp

preset_variables = 0; %0 is don't change.
plot_all_animals = 0;

options_for_plot = struct(...
    'show_start_trial', false, ...
    'show_end_trial', false, ...
    'show_quiescence', false, ...
    'show_speedBelow5', false, ...
    'show_hmm', false, ...
    'show_images', false, ...
    'show_trials', false, ...
    'only_quiescence', false, ...
    'show_gain', false, ...
    'paper_figure', false ...
);
% save('a01x_plot_player_saved_settings.mat', 'options_for_plot', '-append');


%
if plot_all_animals == 0
    fig = a01x_plot_player(all_data, start_seconds, seconds_per_row, images, num_rows, default_variables, variable_per_row, plot_sero_speed, animal, day, paper_figure, options_for_plot, 0, glitch, preset_variables);
else
    for animal = 10:15
        max_time_done = 0;
        jump = 0;
        start_time = 0;
        i = 1;
        for day = 1
            while max_time_done == 0
                options_for_plot.only_quiescence = true;
                start_time = start_time + jump;
                plot_sero_speed = [1, 1];
                variables_tile_1 = ["pc1nose", "wp_motion", "none", "none", "none", "none"];

                % save('a01x_plot_player_saved_settings.mat', 'plot_sero_speed', '-append');
                % save('a01x_plot_player_saved_settings.mat', 'variables_tile_1', '-append');

                save('a01x_plot_player_saved_settings.mat', 'animal', '-append');
                save('a01x_plot_player_saved_settings.mat', 'day', '-append');
                save('a01x_plot_player_saved_settings.mat', 'options_for_plot', '-append');
                save('a01x_plot_player_saved_settings.mat', 'start_time', '-append');
                [fig, ~, max_time_done_arr] = a01x_plot_player(all_data, start_seconds, seconds_per_row, images, num_rows, default_variables, variable_per_row, plot_sero_speed, animal, day, paper_figure, options_for_plot, 0, glitch);
                jump = max_time_done_arr(2);
                max_time_done = max_time_done_arr(1);
                % saveas(fig, ['images/quiescence_periods/' sprintf('%d_%d_quiescence_periods_2', animal, day) '.png'])
                saveas(fig, ['images/0428_long_plots/' sprintf('%d_%d_long_plots', animal, i) '.png'])
                close(fig)
                i = i + 1;
            end
        end
    end
end

% save_cropped_image(fig, mfilenameclose all
