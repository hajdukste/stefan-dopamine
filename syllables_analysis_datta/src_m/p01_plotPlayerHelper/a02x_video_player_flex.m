function a02x_video_player(session_table, keypoints, videoFile, scale, useSecondVideo, seconds_per_row, no_images, time_start, plot_speed_sero_fm, column_2, column_3, roi)


left_lim = 0;
right_lim = seconds_per_row;

% Setup the time series plot

overlayAxes = axes('Position', layoutHandle.InnerPosition, 'Color', 'none', ...
                   'XColor', 'none', 'YColor', 'none', 'HitTest', 'off');
hold(overlayAxes, 'on');
hLine = line(overlayAxes, [0 0], [0 1], ...
             'LineStyle', ':', 'Color', 'r', 'LineWidth', 2);
overlayAxes.XLim = [0 1];
overlayAxes.YLim = [0 1];
uistack(overlayAxes, 'top');



counter_for_line = 0;
keep_plots = 0;


screenSize = get(0, 'ScreenSize'); screenWidth = screenSize(3);
if screenWidth == 3008
    timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 600 2840 20]); %2132, 1760 before
else
    timeSlider2 = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [82 600 2132 20]); %1760 before
end
set(timeSlider2, 'SliderStep', [0.001 0.001]);
addlistener(timeSlider2, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 2));

closeButton = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Position', [380 50 100 30], 'Callback', @closeVideoPlayer);


keep_plots_checkbox = uicontrol('Style', 'checkbox', 'String', 'Keep', 'BackgroundColor', [1 1 1], 'Position', [300 87 50 20], 'Callback', @(src, evt) checkboxCallback(src));

timeSlider = uicontrol('Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'Position', [70 20 400 20]);
set(timeSlider, 'SliderStep', [0.001 0.01]);
addlistener(timeSlider, 'ContinuousValueChange', @(src, evt) sliderMoved(src, evt, 1));
%when timeslider changes, calls the function


function checkboxCallback(src)
    if src.Value == 1
        keep_plots = 1;  % Set to 1 when checked
    else
        keep_plots = 0;  % Set to 0 when unchecked
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
    counter_for_line = 0;
    timerfcn(0, 0, 0);
    time_start = currentTimeReal;
    save(saved_settings, 'seconds_per_row', 'time_start', 'no_images',  'column_2', 'column_3', 'seconds_per_row', 'plot_speed_sero_fm')
end

function timerfcn(~, ~, slider_id_using)

    if hasFrame(reader) && isOpen(player)
        if right_lim < currentTimeReal || left_lim > currentTimeReal
            left_lim = floor(currentTimeReal / seconds_per_row) * seconds_per_row;
            right_lim = left_lim + seconds_per_row;
            axesHandles = findobj(layoutHandle, 'Type', 'axes');
            for ax = transpose(axesHandles)  % Ensure it's a column vector for looping
                xlim(ax, seconds([left_lim, right_lim]));
            end
        end
    end
end

function sliderMoved(src, ~)
    counter_for_line = 0;
    if isvalid(t) && strcmp(t.Running, 'on')
        stop(t);  % Stop the timer only if it is running and valid
    end
    reader.CurrentTime = left_lim + time_before_first_tcam + src.Value*seconds_per_row;  % Set the reader's current time to the new time
    playButton.Value = 0;  % Reset play button to show it's paused

    timerfcn(0, 0, slider_id);
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