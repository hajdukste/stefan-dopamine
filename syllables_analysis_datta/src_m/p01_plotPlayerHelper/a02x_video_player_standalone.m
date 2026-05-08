function a02x_video_player(session_table, keypoints, videoFile, scale, useSecondVideo, seconds_per_row, no_images, time_start, plot_speed_sero_fm, column_2, column_3, roi, name, make_still_videos, animal, day, videoFile2)

saved_settings = fullfile('a02x_video_player_saved_settings.mat');
if exist(saved_settings, 'file')
    load(saved_settings, 'seconds_per_row', 'time_start', 'no_images',  'column_2', 'column_3', 'seconds_per_row', 'plot_speed_sero_fm')
end

values = {[0, 0, 0, 0, 0], [10, 10, 10, 10, 10], [50, 50, 50, 50, 50], [150, 150, 150, 150, 150]};
mapMovMean = containers.Map({50, 100, 400, 1000}, values);

seconds_per_row_var = seconds_per_row;
left_lim = 0;
right_lim = seconds_per_row;
current_movmean = mapMovMean(seconds_per_row);

% Setup the time series plot
if make_still_videos == 1
    timeSeriesFig = figure('Visible', 'on', ...               % Hide figure to speed up
                       'Position', [100, 100, 1500, 980], ...  % Set desired size to avoid resizing
                       'Color', 'w', ...
                       'Renderer', 'opengl');
else
    timeSeriesFig = figure;
    timeSeriesFig.Position = [1 1 3000 980];
end
set(timeSeriesFig, 'Color', 'w');

[layoutHandle, fake_all_data, first_tcam, last_tcam, last_time_harp] = a02x_initialise_plot(session_table, no_images);
[time_before_first_tcam, time_last_tcam, time_after_last_tcam] = a02x_align_video_harp(videoFile, first_tcam, last_tcam);
a02x_plot_stuff(layoutHandle, fake_all_data, 1, '0', current_movmean, 0, plot_speed_sero_fm);

overlayAxes = axes('Position', layoutHandle.InnerPosition, 'Color', 'none', ...
                   'XColor', 'none', 'YColor', 'none', 'HitTest', 'off');
hold(overlayAxes, 'on');
hLine = line(overlayAxes, [0 0], [0 1], ...
             'Color', 'r');
overlayAxes.XLim = [0 1];
overlayAxes.YLim = [0 1];
uistack(overlayAxes, 'top');

if ~strcmp(column_2, 'none')
    a02x_plot_stuff(layoutHandle, fake_all_data, 2, column_2, current_movmean, 0, plot_speed_sero_fm)
end
if ~strcmp(column_3, 'none')
    a02x_plot_stuff(layoutHandle, fake_all_data, 2, column_3, current_movmean, 0, plot_speed_sero_fm)
end

if ~isempty(keypoints)
    if keypoints == 1
        keypoint1 = 'nose_tip'; keypoint2 = 'nose_top'; keypoint3 = 'nose_bottom';
        keypoints_x = [fake_all_data.(keypoint1+"_x") fake_all_data.(keypoint2+"_x") fake_all_data.(keypoint3+"_x")];
        keypoints_y = [fake_all_data.(keypoint1+"_y") fake_all_data.(keypoint2+"_y") fake_all_data.(keypoint3+"_y")];

        mean_x = mean(fake_all_data.(keypoint1+"_x"));
        mean_y = mean(fake_all_data.(keypoint1+"_y"));

        % keypoints_x = [keypoints.(keypoint1)(:, 1) keypoints.(keypoint2)(:, 1) keypoints.(keypoint3)(:, 1)];
        % keypoints_y = [keypoints.(keypoint1)(:, 2) keypoints.(keypoint2)(:, 2) keypoints.(keypoint3)(:, 2)];
        %
        % mean_x = mean(keypoints.(keypoint1)(:, 1));
        % mean_y = mean(keypoints.(keypoint1)(:, 2));
    end
end

axesHandles = findobj(layoutHandle, 'Type', 'axes');
for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
    xlim(ax, seconds([left_lim, right_lim]));
end

counter = 0;
keep_plots = 0;

reader = VideoReader(videoFile);
player = vision.VideoPlayer;
player.Position = [1119 1100 730 530];
% player.Position = [1119 1100 930 730];
framerate = reader.FrameRate;

disp(['misali / csv length / video length / harp length (sec):'])
disp([num2str(time_before_first_tcam) '/' num2str(time_last_tcam-time_before_first_tcam) '/' num2str(reader.Duration - time_after_last_tcam - time_before_first_tcam) '/' char(last_time_harp)])
Duration2 = reader.Duration - time_after_last_tcam - time_before_first_tcam;

if useSecondVideo
    % Setup the second video player if a second video file is provided
    reader2 = VideoReader(videoFile2);
    player2 = vision.VideoPlayer;
    player2.Position = [1300 500 750 500];  % Adjust position to not overlap with the first player
end

screenSize = get(0, 'ScreenSize'); screenWidth = screenSize(3);
if make_still_videos == 1
    timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 600 1 1]); %2132, 1760 before
elseif screenWidth == 3008
    timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 600 2840 20]); %2132, 1760 before
else
    timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 630 1760 20]); %2840 before
end
set(timeSlider2, 'SliderStep', [0.001 0.001]);
addlistener(timeSlider2, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 2));

controlFig = figure('Name', 'Playback Controls', 'NumberTitle', 'off', 'Color', 'w', 'Position', [618   1110   501   202]);
playButton = uicontrol('Style', 'togglebutton', 'String', 'Play/Pause', 'Position', [50 50 100 30], 'Callback', @togglePlayPause);
currentTimeText = uicontrol('Style', 'text', 'BackgroundColor', [1 1 1], 'String', sprintf('Time: 00:00 / %02d:%02d', floor(Duration2 / 60), round(mod(Duration2, 60))), 'Position', [159 46 130 30]);
textField = uicontrol('Style', 'edit', 'Position', [285, 50, 70, 30], 'Callback', @(src, event) updateValueCallback(src));
closeButton = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Position', [380 50 100 30], 'Callback', @closeVideoPlayer);

% Create the buttons
button1 = uicontrol('Style', 'pushbutton', 'String', '50', 'Position', [50, 85, 50, 30], 'Callback', @(src, evt) xlim_change(50));
button2 = uicontrol('Style', 'pushbutton', 'String', '100', 'Position', [50 + 1*55, 85, 50, 30], 'Callback', @(src, evt) xlim_change(100));
button3 = uicontrol('Style', 'pushbutton', 'String', '400', 'Position', [50 + 2*55, 85, 50, 30], 'Callback', @(src, evt) xlim_change(400));
button4 = uicontrol('Style', 'pushbutton', 'String', '1000', 'Position', [50 + 3*55, 85, 50, 30], 'Callback', @(src, evt) xlim_change(1000));


% Dropdown Menu
columnNames = session_table.Properties.VariableNames;
columnNames = [{'none'}, flip(columnNames)];


if(isempty(find(strcmp(columnNames, column_2), 1)))
    value_now = 1; else; value_now = find(strcmp(columnNames, column_2), 1); end
if(isempty(find(strcmp(columnNames, column_3), 1)))
    value_now2 = 1; else; value_now2 = find(strcmp(columnNames, column_3), 1); end


dropdownMenu = uicontrol('Style', 'popupmenu', 'String', columnNames, 'Value', value_now, 'Position', [270 100 110 30], 'Callback', @(src, evt) dropdownCallback(src, evt, 2));
dropdownMenu2 = uicontrol('Style', 'popupmenu', 'String', columnNames, 'Value', value_now2, 'Position', [380 100 110 30], 'Callback', @(src, evt) dropdownCallback(src, evt, 3));
names_check = {"sero", "speed", "fm"};
for i_text = 1:5
    editHandles(i_text) = uicontrol('Style', 'edit', 'Position', [-60+i_text*2*45, 150, 70, 25], 'String', current_movmean(i_text), 'Callback', @(src, evt) movmean_checkboxCallback(src, evt, i_text));
    if i_text < 4
        checkbox1 = uicontrol('Style', 'checkbox', 'Value', plot_speed_sero_fm(i_text), 'String', names_check(i_text), 'BackgroundColor', [1 1 1], 'Position', [-60+i_text*2*45, 125, 70, 20], 'Callback', @(src, evt) checkboxCallback2(src, evt, i_text));
    end
end


checkbox1 = uicontrol('Style', 'checkbox', 'String', 'Keep', 'BackgroundColor', [1 1 1], 'Position', [300 87 50 20], 'Callback', @(src, evt) checkboxCallback(src));

timeSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [70 20 400 20]);
set(timeSlider, 'SliderStep', [0.001 0.01]);
addlistener(timeSlider, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 1));
%when timeslider changes, calls the function

t = timer('ExecutionMode', 'fixedRate', ...
          'Period', round(1 / framerate, 3), ...
          'TimerFcn', @(tmr, evnt) timerfcn(tmr, evnt, 0), ...% timerfcn called every tick
          'ErrorFcn', @(tmr, evnt) cleanup(tmr, player)); %when error encountered

show(player);
reader.CurrentTime = time_start + time_before_first_tcam;

if make_still_videos == 1
    [startIndices, endIndices]  = start_end_indices_of_bool(fake_all12_data.still');
    time = fake_all_data.time;
    if animal > 8
        keep_plots = 0;
        set(dropdownMenu, 'Value', find(contains(columnNames, 'nose_motion'), 1));
        dropdownCallback(dropdownMenu, [], 2);
        keep_plots = 1;
        set(dropdownMenu, 'Value', find(contains(columnNames, 'wp_motion'), 1));
        dropdownCallback(dropdownMenu, [], 2);

        set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_nose'), 1));
        dropdownCallback(dropdownMenu2, [], 3);
        keep_plots = 1;
        set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_wp'), 1));
        dropdownCallback(dropdownMenu2, [], 3);
    else
        keep_plots = 0;
        set(dropdownMenu, 'Value', find(contains(columnNames, 'nose_top_dist'), 1));
        dropdownCallback(dropdownMenu, [], 2);
        keep_plots = 1;
        set(dropdownMenu, 'Value', find(contains(columnNames, 'wp_motion'), 1));
        dropdownCallback(dropdownMenu, [], 2);

        set(dropdownMenu2, 'Value', find(contains(columnNames, 'nose_top_speed'), 1));
        dropdownCallback(dropdownMenu2, [], 3);
        keep_plots = 1;
        set(dropdownMenu2, 'Value', find(contains(columnNames, 'd_wp'), 1));
        dropdownCallback(dropdownMenu2, [], 3);
    end

    total_frames = 0;
    num_frames_per_segment = zeros(length(startIndices), 1);  % Preallocate for efficiency

    for i_quiescence = 1:length(startIndices)
        startIdx = startIndices(i_quiescence);
        endIdx = endIndices(i_quiescence);

        start_time = time(startIdx) - 2;
        end_time = time(endIdx) + 2;

        duration = end_time - start_time;
        num_frames_per_segment(i_quiescence) = duration * framerate;

        total_frames = total_frames + duration * framerate;
    end

    frames_processed = 0;
    for i_quiescence = 1:length(startIndices)
        startIdx = startIndices(i_quiescence);
        endIdx = endIndices(i_quiescence);

        start_time = time(startIdx) - 2;
        end_time = time(endIdx) + 2;

        name_of_video = "quiescence_videos/" + string(animal) + string(name) + "_" + string(day) + "_" + string(round(start_time, 0)) + "_" + string(round(end_time - start_time - 4, 0)) + ".avi";
        output_video = VideoWriter(name_of_video, 'Motion JPEG AVI');
        output_video.FrameRate = framerate;
        open(output_video);

        canvasHeight = reader.Height + 980;
        canvasWidth = 1500;
        canvas = uint8(255 * ones(canvasHeight, canvasWidth, 3, 'uint8'));

        for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
            xlim(ax, seconds([start_time-5, start_time+45]));
        end

        reader.currentTime = start_time + time_before_first_tcam;

        num_frames = (end_time - start_time)*30;

        for j = 1:num_frames
            vidFrame = readFrame(reader);

            currentTimeReal = reader.currentTime - time_before_first_tcam;
            fraction_time = (currentTimeReal - (start_time - 5))/seconds_per_row;
            if mod(j, 10) == 1
                timeSeriesFrame = getframe(timeSeriesFig);
                timeSeriesImg = frame2im(timeSeriesFrame);
                timeSeriesImg = imresize(timeSeriesImg, [980 1500]);
                set(hLine, 'XData', [fraction_time, fraction_time]);
                disp([num2str(j) '/' num2str(num_frames) ', ' num2str(frames_processed), '/', num2str(total_frames)]);
            end

            canvas(1:reader.Height, 1:reader.Width, :) = vidFrame;
            canvas(reader.Height+1:reader.Height+980, 1:1500, :) = timeSeriesImg;

            writeVideo(output_video, canvas);
            frames_processed = frames_processed + 1;

            if fraction_time > 0.95
                start_time = start_time + 50;
                for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
                    xlim(ax, seconds([start_time-5, start_time+45]));
                end
            end
        end

        close(output_video);
    end
else
    set(playButton, 'Value', 1);
    togglePlayPause(playButton, []);
end


function updateValueCallback(src)
    newValue = str2double(src.String);
    if isnan(newValue)
        disp('Please enter a valid number.');
        return;
    end
    reader.currentTime = newValue - time_before_first_tcam;
    xlim_change(seconds_per_row);
end

function movmean_checkboxCallback(src, ~, i_dropdown)
    current_movmean(i_dropdown) = str2double(src.String);
    plot_all();
    xlim_change(seconds_per_row);
end

function updateEditBoxes()
    for i = 1:length(editHandles)
        set(editHandles(i), 'String', num2str(current_movmean(i)));
    end
end

function checkboxCallback(src)
    if src.Value == 1
        keep_plots = 1;  % Set to 1 when checked
    else
        keep_plots = 0;  % Set to 0 when unchecked
    end
end

function checkboxCallback2(src, ~, which_one)
    plot_speed_sero_fm(which_one) = src.Value;
    a02x_plot_stuff(layoutHandle, fake_all_data, 1, '0', current_movmean, 0, plot_speed_sero_fm);
end

function dropdownCallback(src, ~, tile)
    selectedColumn = src.String{src.Value};
    a02x_plot_stuff(layoutHandle, fake_all_data, tile, selectedColumn, current_movmean, keep_plots, plot_speed_sero_fm)
    xlim_change(seconds_per_row)
    if tile == 2
        column_2 = selectedColumn;
    elseif tile == 3
        column_3 = selectedColumn;
    end
end

function plot_all()
    a02x_plot_stuff(layoutHandle, fake_all_data, 1, '0', current_movmean, 0, plot_speed_sero_fm);
    a02x_plot_stuff(layoutHandle, fake_all_data, 2, column_2, current_movmean, 0, plot_speed_sero_fm)
    if ~strcmp(column_3, 'none')
        a02x_plot_stuff(layoutHandle, fake_all_data, 3, column_3, current_movmean, 0, plot_speed_sero_fm)
    end
end

function xlim_change(seconds_per_row_var)
    currentTimeReal = reader.currentTime  - time_before_first_tcam;
    if seconds_per_row_var ~= seconds_per_row
        current_movmean = mapMovMean(seconds_per_row_var);
        updateEditBoxes()
        plot_all();
    end
    seconds_per_row = seconds_per_row_var;
    right_lim = left_lim + seconds_per_row;

    if right_lim < currentTimeReal || left_lim > currentTimeReal
        left_lim = floor(currentTimeReal / seconds_per_row) * seconds_per_row;
        right_lim = left_lim + seconds_per_row;
    end
    axesHandles = findobj(layoutHandle, 'Type', 'axes');
    for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
        xlim(ax, seconds([left_lim, right_lim]));
    end
    counter = 0;
    timerfcn(0, 0, 0);
    time_start = currentTimeReal;
    save(saved_settings, 'seconds_per_row', 'time_start', 'no_images',  'column_2', 'column_3', 'seconds_per_row', 'plot_speed_sero_fm')
end

function timerfcn(~, ~, slider_id_using)
    % While we have more to read, read and display it.
    currentTime = reader.currentTime;
    currentTimeReal = currentTime - time_before_first_tcam;

    if hasFrame(reader) && isOpen(player)
        frame = readFrame(reader);
        if ~isempty(keypoints)
            if keypoints == 1
                frameIndex = round(currentTimeReal * framerate) + 1;  % Convert time to frame index
                x_coords = keypoints_x(frameIndex, :);

                y_coords = keypoints_y(frameIndex, :);
                % disp([frameIndex, currentTime, currentTimeReal])%, x_coords, y_coords])
                for i = 1:length(x_coords)
                    frame = insertMarker(frame, [x_coords(i), y_coords(i)], 'Color', 'green', 'Size', 10);
                end

                % line1 = [mean_x - 100, mean_y, mean_x + 100, mean_y];
                % line2 = [mean_x, mean_y - 100, mean_x, mean_y + 100];
                % frame = insertShape(frame, 'Line', [line1; line2], 'Color', 'g', 'LineWidth', 1);
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
        step(player, frame);
        if useSecondVideo
            frame2 = readFrame(reader2);
            frame2 = imresize(frame2, scale);
            step(player2, frame2);
        end
        set(currentTimeText, 'String', sprintf('Time: %02d:%02d / %02d:%02d', floor(currentTimeReal / 60), round(mod(currentTimeReal, 60)), floor(Duration2 / 60), round(mod(Duration2, 60))));
        fraction_time = (currentTimeReal - left_lim)/seconds_per_row;
        if slider_id_using ~= 1
            if fraction_time >= 0 && fraction_time <= 1
                set(timeSlider2, 'Value', fraction_time);
            end
        end
        set(timeSlider, 'Value', currentTimeReal / Duration2);
        % if mod(counter, 10) == 0
        %     set(hLine, 'XData', [fraction_time, fraction_time]);
        % end
        counter = counter + 1;
        if right_lim < currentTimeReal || left_lim > currentTimeReal
            left_lim = floor(currentTimeReal / seconds_per_row) * seconds_per_row + 35;
            right_lim = left_lim + seconds_per_row;
            axesHandles = findobj(layoutHandle, 'Type', 'axes');
            for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
                xlim(ax, seconds([left_lim, right_lim]));
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
        reader.CurrentTime = left_lim + time_before_first_tcam + src.Value*seconds_per_row;  % Set the reader's current time to the new time
    end
    if useSecondVideo
        reader2.CurrentTime = src.Value * Duration2;  % Synchronize second video with first
    end
    playButton.Value = 0;  % Reset play button to show it's paused

    timerfcn(0, 0, slider_id);
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

function closeVideoPlayer(~, ~)
    try
        if exist('timeSlider2', 'var') && ishandle(timeSlider2)
            delete(timeSlider2);
        end
        cleanup(t, player);
        disp('Player closed')
        if ishandle(controlFig)
            close(controlFig);
        end
        disp('controlFig closed')
        % if ishandle(timeSeriesFig)
        %     close(timeSeriesFig);
        % end
        % disp('timeSeriesFig closed')
    catch ME
        disp(['Error in closeVideoPlayer: ', ME.message]);
    end
end
end