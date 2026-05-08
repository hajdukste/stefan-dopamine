function a02x_video_player(all_data, counter_num, keypoints_bool, scatter_bool, scale, useSecondVideo, default_variables, num_rows, time_start, seconds_per_row, plot_sero_speed, options_for_plot, roi, make_still_videos, animal, day, videoFile2, glitch, runFirstTime)



saved_settings = fullfile('a02x_video_player_saved_settings.mat');
if exist(saved_settings, 'file')
    load(saved_settings,  'counter_num', 'keypoints_bool', 'scatter_bool', 'seconds_per_row', 'time_start', 'num_rows', 'default_variables', 'plot_sero_speed', 'options_for_plot')
end

[videoFile, keypoints_data, rectangleXY] = a02x_get_video_path(animal, day);

% initialise video reader
reader = VideoReader(videoFile);
player = vision.VideoPlayer;
player.Position = [1186 906 830 580];
% player.Position = [1119 1100 930 730];
framerate = reader.FrameRate;

if useSecondVideo
    % Setup the second video player if a second video file is provided
    reader2 = VideoReader(videoFile2);
    player2 = vision.VideoPlayer;
    player2.Position = [1300 500 830 580];  % Adjust position to not overlap with the first player
end

t = timer('ExecutionMode', 'fixedRate', ...
          'Period', round(1 / framerate, 3), ...
          'TimerFcn', @(tmr, evnt) timerfcn(tmr, evnt, 0), ...% timerfcn called every tick
          'ErrorFcn', @(tmr, evnt) cleanup(tmr, player)); %when error encountered

show(player);
frame = readFrame(reader);
if scale ~= 1
    if scale ~= 1.1
        frame = imresize(frame, scale);
    else
        frame = imresize(frame, 0.5);
        frame = imresize(frame, 2);
    end
end
if roi ~= 0
    frame = imcrop(frame, roi);
end
player(frame)

function sendValuesToVideoPlayer(option_now, value)
    switch option_now
        case 1
            reader.CurrentTime = value + 10;
            timerfcn();
        case 2
            reader.CurrentTime = reader.CurrentTime + value;
            timerfcn();
        case 3
            default_variables = value;
        case 4
            options_for_plot = value;
    end

end
video_bool = struct('value', 1, 'f', @sendValuesToVideoPlayer);

% Setup the time series plot
if make_still_videos == 1
    timeSeriesFig = figure('Visible', 'on', ...               % Hide figure to speed up
                       'Position', [100, 100, 1500, 980], ...  % Set desired size to avoid resizing
                       'Color', 'w', ...
                       'Renderer', 'opengl');
else
    [timeSeriesFig, videoStruct] = a01x_plot_player(all_data, time_start, seconds_per_row, 0, num_rows, default_variables, 1, plot_sero_speed, animal, day, [0, 0, 0, 0, 0, 0, 0], options_for_plot, video_bool, glitch);
end

% time alignments
layoutHandle = videoStruct.layoutHandle;
first_tcam = videoStruct.first_tcam;
last_tcam= videoStruct.last_tcam;
last_time_harp = videoStruct.last_time_harp;
left_lim = videoStruct.left_lim;
left_lim = 2400;
right_lim = left_lim + getappdata(0, 'shared_seconds_per_row');
[time_before_first_tcam, time_last_tcam, time_after_last_tcam] = a02x_align_video_harp(videoFile, first_tcam, last_tcam);


% hline and stuff
overlayAxes = axes('Position', layoutHandle.InnerPosition, 'Color', 'none', ...
                   'XColor', 'none', 'YColor', 'none', 'HitTest', 'off');
hold(overlayAxes, 'on');
hLine = line(overlayAxes, [0 0], [0 1], ...
             'Color', 'r');
overlayAxes.XLim = [0 1];
overlayAxes.YLim = [0 1];
uistack(overlayAxes, 'top');
counter = 0;

if animal > 8
    keypoints_x = keypoints_data(:, 1);
    keypoints_y = keypoints_data(:, 2);
    mean_x = mean(keypoints_x);
    mean_y = mean(keypoints_y);
end

disp(['misali / csv length / video length / harp length (sec):'])
disp([num2str(time_before_first_tcam) '/' num2str(time_last_tcam-time_before_first_tcam) '/' num2str(reader.Duration - time_after_last_tcam - time_before_first_tcam) '/' char(last_time_harp)])
Duration2 = reader.Duration - time_after_last_tcam - time_before_first_tcam;
reader.CurrentTime = time_start + time_before_first_tcam;



screenSize = get(0, 'ScreenSize'); screenWidth = screenSize(3);
figWidth = timeSeriesFig.Position(3);
new_version_offset = 35;
if make_still_videos == 1
    big_timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 600 1 1]); %2132, 1760 before
elseif screenWidth == 3008
    big_timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82+new_version_offset 560  figWidth-100 20]); %2132, 1760 before
else
    big_timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82+new_version_offset 560 figWidth-160-2*new_version_offset 20]); %2840 before
end
set(big_timeSlider2, 'SliderStep', [0.001 0.001]);
addlistener(big_timeSlider2, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 2));

% controlFig = figure('Name', 'Playback Controls', 'NumberTitle', 'off', 'Color', 'w', 'Position', [618   1110   501   202]);
controlFig = timeSeriesFig; figure(controlFig);
playButton = uicontrol('Style', 'togglebutton', 'String', 'Play/Pause', 'Value', 1, 'Position', [50 50 100 30], 'Callback', @togglePlayPause);
currentTimeText = uicontrol('Style', 'text', 'BackgroundColor', [1 1 1], 'String', sprintf('Time: 00:00 / %02d:%02d', floor(Duration2 / 60), round(mod(Duration2, 60))), 'Position', [159 46 130 30]);
closeButton = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Position', [380 50 100 30], 'Callback', @closeVideoPlayer);
uicontrol('Style', 'pushbutton', 'String', 'Update', 'Position', [320 50 50 30], 'Callback', @updateSizeSlider);
textField = uicontrol('Style', 'edit', 'Value', counter_num, 'Position', [285, 85, 70, 30], ...
    'Callback', @(src, event) toggle_checkbox(src, 1));

% Define checkboxes and link them to a unified function
button1 = uicontrol('Style', 'checkbox', 'Value', scatter_bool, 'String', 'Scatter', 'Position', [50, 85, 50, 30], ...
    'Callback', @(src, evt) toggle_checkbox(src, 0));
button2 = uicontrol('Style', 'checkbox', 'Value', keypoints_bool, 'String', 'Keypoints', 'Position', [50 + 1*55, 85, 50, 30], ...
    'Callback', @(src, evt) toggle_checkbox(src, 0));
button3 = uicontrol('Style', 'checkbox', 'String', 'Slow', 'Position', [50 + 2*55, 85, 50, 30], ...
    'Callback', @(src, evt) toggle_checkbox(src, 0));
button4 = uicontrol('Style', 'checkbox', 'String', 'New2', 'Position', [50 + 3*55, 85, 50, 30], ...
    'Callback', @(src, evt) toggle_checkbox(src, 0));


small_timeSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [70 20 figWidth-160 20]);
set(small_timeSlider, 'SliderStep', [0.001 0.01]);
addlistener(small_timeSlider, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 1));
%when timeslider changes, calls the function

axesHandles = 0;

fig_scatter = figure('Color', 'w', 'Visible', 'off');
fig_scatter.Position(1) = fig_scatter.Position(1) + fig_scatter.Position(3);
if scatter_bool == 1; fig_scatter.Visible = 'on'; end

if scatter_bool == 1
    quiescence_bool = 0;
    time = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'time', [0,0], 6);
    x = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'latent1', [0,0], 6);
    y = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'latent2', [0,0], 6);
    h_moving = plot(NaN, NaN, 'ro', 'MarkerSize', 8, 'LineWidth', 2);  % red dot
    xline(0)
    yline(0)
    hold on
    xlim([-3, 3]); ylim([-3, 3])
end

% quiescence_bool = 0;
% time = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'time', [0,0], 6);
% x = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'nose_tip_xn', [0,0], 6);
% y = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'nose_tip_yn', [0,0], 6);
% z = a23z_new_get_core_values(all_data, animal, day, quiescence_bool, 'zsc_exp', [0,0], 6);
% a26a_plot_tile_scatter(x, y, z, 0.5, 0, 0, 0, 0, 'pc1nose');
% xline(0)
% yline(0)
% hold on
% h_moving = plot(NaN, NaN, 'ro', 'MarkerSize', 8, 'LineWidth', 2);  % red dot
% xlim([-4, 2]); ylim([-3, 3])

line1 = 0;
line2 = 0;
rectangle_lines = 0;
pupilData = [];
if (animal == 11 && day == 4) || (animal == 2 && day == 1)
    if animal == 11
        pupilData = load('/Users/stefek/CF Drive/Python/npy files/4_Jumpcamera2023-07-17T12_52_14_proc.mat');
        xrange_min = double(pupilData.data{1, 1}.rois{1, 1}.xrange(1)) + 1; %+1 for python indexing
        yrange_min = double(pupilData.data{1, 1}.rois{1, 1}.yrange(1)) + 1;
        pupilData = pupilData.data{1,1}.pupil{1,1};
    else
        pupilData = load('/Users/stefek/CF Drive/Python/npy files/1_neocameraTwo2024-05-09T15_32_45_proc.mat');
        xrange_min = double(pupilData.rois{1, 1}.xrange(1));
        yrange_min = double(pupilData.rois{1, 1}.yrange(1));
        pupilData = pupilData.pupil{1,1};
    end
    pupilData.com = pupilData.com(:, [2 1]);

    % Fix axlen and axdir so that major ≥ minor
    nFrames = size(pupilData.axlen, 1);
    for iii = 1:nFrames
        orig_axes = pupilData.axlen(iii, :);
        [sorted_axes, idx] = sort(orig_axes, 'descend');
        pupilData.axlen(iii, :) = sorted_axes;

        if idx(1) == 2  % axes were swapped
            dir = squeeze(pupilData.axdir(iii, :, 1));
            pupilData.axdir(iii, :, 1) = [-dir(2), dir(1)];  % rotate 90°
        end
        pupilData.com(iii, :) = pupilData.com(iii, :) + [xrange_min, yrange_min];
        pupilData.axlen(iii, :) = sqrt(pupilData.axlen(iii, :)) * 2; %based on gpt analysis of pupil.py, 2 is pupil_sigma
    end
end
if keypoints_bool == 1 && animal > 8 %%duplicated from below, fix for clarity to have it only once
    line1 = [mean_x - 50, mean_y, mean_x + 50, mean_y];
    line2 = [mean_x, mean_y - 50, mean_x, mean_y + 50];
    x1 = rectangleXY.x1; x2 = rectangleXY.x2; y1 = rectangleXY.y1; y2 = rectangleXY.y2;
    rectangle_lines = [
        x1, y1, x2, y1;  % top
        x2, y1, x2, y2;  % right
        x2, y2, x1, y2;  % bottom
        x1, y2, x1, y1   % left
    ];
end
start(t)
updateSizeSlider()

function timerfcn(~, ~, ~)
    % While we have more to read, read and display it.
    currentTime = reader.currentTime;
    currentTimeReal = currentTime - time_before_first_tcam;


    if hasFrame(reader) && isOpen(player)
        frame = readFrame(reader);
        if ~isempty(keypoints_bool)
            if keypoints_bool == 1
                frameIndex = round(currentTime * framerate) + 1;  % Convert time to frame index
                if ~isempty(pupilData)
                    center = pupilData.com(frameIndex, :);           % [x y]
                    axes_len = pupilData.axlen(frameIndex, :);       % [major minor]
                    dir = pupilData.axdir(frameIndex, :, 1);         % [dx dy]
                    yaw_deg = -rad2deg(atan2(dir(2), dir(1)));

                    frame = insertShape(frame, 'Ellipse', [center, axes_len, yaw_deg+90], 'Color', 'red', 'LineWidth', 1);
                end

                if animal > 8
                    frame = insertShape(frame, 'Line', [line1; line2; rectangle_lines], 'Color', 'r', 'LineWidth', 1);

                    % [~, frameIndex] = min(abs(time_all - currentTimeReal));
                    x_coords = keypoints_x(frameIndex);
                    y_coords = keypoints_y(frameIndex);
                    % disp([frameIndex, currentTime, currentTimeReal])%, x_coords, y_coords])
                    for i = 1:length(x_coords)
                        frame = insertMarker(frame, [x_coords(i), y_coords(i)], 'Color', 'green', 'Size', 10);
                    end
                end


            end
        end
        if scale ~= 1
            if scale ~= 1.1
                frame = imresize(frame, scale);
            else
                frame = imresize(frame, 0.5);
                frame = imresize(frame, 2);
            end
        end
        if roi ~= 0
            frame = imcrop(frame, roi);
        end
        player(frame)
        if runFirstTime == 0
            closeVideoPlayer();
        end
        if useSecondVideo
            frame2 = readFrame(reader2);
            frame2 = imresize(frame2, scale);
            player2(frame2)
        end
        set(currentTimeText, 'String', sprintf('Time: %02d:%02d / %02d:%02d', floor(currentTimeReal / 60), round(mod(currentTimeReal, 60)), floor(Duration2 / 60), round(mod(Duration2, 60))));
        % if slider_id_using ~= 1
        %     if fraction_time >= 0 && fraction_time <= 1
        %         set(big_timeSlider2, 'Value', fraction_time);
        %     end
        % end


        set(small_timeSlider, 'Value', currentTimeReal / Duration2);
        fraction_time = (currentTimeReal - left_lim)/getappdata(0, 'shared_seconds_per_row');
        if mod(counter, counter_num) == 0
            set(hLine, 'XData', [fraction_time, fraction_time]);
        end
        counter = counter + 1;
        if right_lim < currentTimeReal || left_lim > currentTimeReal
            left_lim = floor(currentTimeReal / getappdata(0, 'shared_seconds_per_row')) * getappdata(0, 'shared_seconds_per_row');
            videoStruct.videoUpdate(left_lim);
        end

        set(big_timeSlider2, 'Value', fraction_time);
        %
        if scatter_bool == 1 && counter_num > 0 && mod(counter, counter_num) == 0
            [~, idx] = min(abs(time - currentTimeReal));
            if idx > 0 && idx <= length(x)  % safety check
            set(h_moving, 'XData', x(idx), 'YData', y(idx));
            end
        end
    % else
    %     cleanup(tmr, player);
    end
end

function sliderMoved(src, ~, slider_id)
    counter = 0;
    if isvalid(t) && strcmp(t.Running, 'on')
        stop(t);  % Stop the timer only if it is running and valid
    end
    if slider_id == 1
        reader.CurrentTime = src.Value * Duration2 + time_before_first_tcam;  % Set the reader's current time to the new time
    else
        reader.CurrentTime = left_lim + time_before_first_tcam + src.Value*getappdata(0, 'shared_seconds_per_row');  % Set the reader's current time to the new time
    end
    if useSecondVideo
        reader2.CurrentTime = src.Value * Duration2;  % Synchronize second video with first
    end
    playButton.Value = 0;  % Reset play button to show it's paused

    timerfcn(0, 0, slider_id);
end

function toggle_checkbox(src, counter)
    if counter == 0
        label = src.String;
    else
        label = 'Counter';
    end

    switch label
        case 'Scatter'
            scatter_bool = src.Value;
            if src.Value == 1
                fig_scatter.Visible = 'on';
            else
                fig_scatter.Visible = 'off';
            end
        case 'Keypoints'
            keypoints_bool = src.Value;
            if keypoints_bool == 1 && animal > 8
                line1 = [mean_x - 50, mean_y, mean_x + 50, mean_y];
                line2 = [mean_x, mean_y - 50, mean_x, mean_y + 50];
                x1 = rectangleXY.x1; x2 = rectangleXY.x2; y1 = rectangleXY.y1; y2 = rectangleXY.y2;
                rectangle_lines = [
                    x1, y1, x2, y1;  % top
                    x2, y1, x2, y2;  % right
                    x2, y2, x1, y2;  % bottom
                    x1, y2, x1, y1   % left
                ];
            end
        case 'Slow'
            if src.Value
                set(t, 'Period', round(1 / framerate, 3)*3);
            else
                set(t, 'Period', round(1 / framerate, 3));
            end
        case 'Counter'
            new_val = str2double(src.String);
            if ~isnan(new_val)
                counter_num = new_val;
            end
        case 'New2'
            if src.Value
            else
            end
    end
end





function togglePlayPause(src, ~)
    if src.Value  % If the button is pressed, play or pause the video
        start(t);  % Start the timer
    else
        stop(t);  % Stop the timer
    end

    if useSecondVideo
        if isOpen(player2)
            show(player2);
        end
    end
end

function cleanup(tmr, player)
    % Stop and delete the timer if it is running
    if isvalid(tmr)
        stop(tmr);
        delete(tmr);
    end
    if isOpen(player)
        release(player);
        if useSecondVideo
            release(player2);
        end
    end
end

function updateSizeSlider(~, ~)
    big_timeSlider2.Position(3) = timeSeriesFig.Position(3) - 160 - 2*new_version_offset;
end

function closeVideoPlayer(~, ~)
    time_start = floor((reader.currentTime - time_before_first_tcam) / getappdata(0, 'shared_seconds_per_row')) * getappdata(0, 'shared_seconds_per_row');
    seconds_per_row = getappdata(0, 'shared_seconds_per_row');

    save(saved_settings,  'counter_num', 'keypoints_bool', 'scatter_bool', 'seconds_per_row', 'time_start', 'num_rows', 'default_variables', 'plot_sero_speed', 'options_for_plot')
    try
        if exist('timeSlider2', 'var') && ishandle(big_timeSlider2)
            delete(big_timeSlider2);
        end
        cleanup(t, player);
        disp('Player closed')
        % if ishandle(controlFig)
        %     close(controlFig);
        % end
        % disp('controlFig closed')
        if ishandle(timeSeriesFig)
            close(timeSeriesFig);
        end
        disp('timeSeriesFig closed')
        close(fig_scatter)
    catch ME
        disp(['Error in closeVideoPlayer: ', ME.message]);
    end
end
end

%
% if make_still_videos == 1
%     [startIndices, endIndices]  = start_end_indices_of_bool(fake_all12_data.still');
%     time = fake_all_data.time;
%     if animal > 8
%         set(dropdownMenu, 'Value', find(contains(columnNames, 'nose_motion'), 1));
%         dropdownCallback(dropdownMenu, [], 2);
%         set(dropdownMenu, 'Value', find(contains(columnNames, 'wp_motion'), 1));
%         dropdownCallback(dropdownMenu, [], 2);
%
%         set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_nose'), 1));
%         dropdownCallback(dropdownMenu2, [], 3);
%         set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_wp'), 1));
%         dropdownCallback(dropdownMenu2, [], 3);
%     else
%         set(dropdownMenu, 'Value', find(contains(columnNames, 'nose_top_dist'), 1));
%         dropdownCallback(dropdownMenu, [], 2);
%         set(dropdownMenu, 'Value', find(contains(columnNames, 'wp_motion'), 1));
%         dropdownCallback(dropdownMenu, [], 2);
%
%         set(dropdownMenu2, 'Value', find(contains(columnNames, 'nose_top_speed'), 1));
%         dropdownCallback(dropdownMenu2, [], 3);
%         set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_wp'), 1));
%         dropdownCallback(dropdownMenu2, [], 3);
%     end
%
%     total_frames = 0;
%     num_frames_per_segment = zeros(length(startIndices), 1);  % Preallocate for efficiency
%
%     for i_quiescence = 1:length(startIndices)
%         startIdx = startIndices(i_quiescence);
%         endIdx = endIndices(i_quiescence);
%
%         start_time = time(startIdx) - 2;
%         end_time = time(endIdx) + 2;
%
%         duration = end_time - start_time;
%         num_frames_per_segment(i_quiescence) = duration * framerate;
%
%         total_frames = total_frames + duration * framerate;
%     end
%
%     frames_processed = 0;
%     for i_quiescence = 1:length(startIndices)
%         startIdx = startIndices(i_quiescence);
%         endIdx = endIndices(i_quiescence);
%
%         start_time = time(startIdx) - 2;
%         end_time = time(endIdx) + 2;
%
%         name_of_video = "quiescence_videos/" + string(animal) + string(name) + "_" + string(day) + "_" + string(round(start_time, 0)) + "_" + string(round(end_time - start_time - 4, 0)) + ".avi";
%         output_video = VideoWriter(name_of_video, 'Motion JPEG AVI');
%         output_video.FrameRate = framerate;
%         open(output_video);
%
%         canvasHeight = reader.Height + 980;
%         canvasWidth = 1500;
%         canvas = uint8(255 * ones(canvasHeight, canvasWidth, 3, 'uint8'));
%
%         for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
%             xlim(ax, seconds([start_time-5, start_time+45]));
%         end
%
%         reader.currentTime = start_time + time_before_first_tcam;
%
%         num_frames = (end_time - start_time)*30;
%
%         for j = 1:num_frames
%             vidFrame = readFrame(reader);
%
%             currentTimeReal = reader.currentTime - time_before_first_tcam;
%             fraction_time = (currentTimeReal - (start_time - 5))/seconds_per_row;
%             if mod(j, 10) == 1
%                 timeSeriesFrame = getframe(timeSeriesFig);
%                 timeSeriesImg = frame2im(timeSeriesFrame);
%                 timeSeriesImg = imresize(timeSeriesImg, [980 1500]);
%                 set(hLine, 'XData', [fraction_time, fraction_time]);
%                 disp([num2str(j) '/' num2str(num_frames) ', ' num2str(frames_processed), '/', num2str(total_frames)]);
%             end
%
%             canvas(1:reader.Height, 1:reader.Width, :) = vidFrame;
%             canvas(reader.Height+1:reader.Height+980, 1:1500, :) = timeSeriesImg;
%
%             writeVideo(output_video, canvas);
%             frames_processed = frames_processed + 1;
%
%             if fraction_time > 0.95
%                 start_time = start_time + 50;
%                 for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
%                     xlim(ax, seconds([start_time-5, start_time+45]));
%                 end
%             end
%         end
%
%         close(output_video);
%     end
% else
%     set(playButton, 'Value', 1);
%     togglePlayPause(playButton, []);
% end