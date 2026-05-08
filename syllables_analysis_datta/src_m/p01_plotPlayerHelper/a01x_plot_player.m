function [fig, videoStruct, max_time_done] = a01x_plot_player(all_data, start_time, seconds_per_row, images, num_rows, variables_tile_1, variable_per_row, plot_sero_speed, animal, day, paper_figure, options_for_plot, video_bool, glitch, preset_variables)

if isstruct(video_bool)
    sendValuesToVideoPlayer = video_bool.f;
    video_bool = video_bool.value;
else
    videoStruct = 0; sendValuesToVideoPlayer = 0;
end

if glitch == 0
    saved_settings = fullfile('p01x_plot_player_saved_settings.mat');
else
    saved_settings = fullfile('p01x_plot_player_glitch_saved_settings_.mat');
end
if exist(saved_settings, 'file') && video_bool == 0
    load(saved_settings, 'start_time', 'seconds_per_row', 'images',  'num_rows', 'variables_tile_1', 'variable_per_row', 'plot_sero_speed', 'animal', 'day', 'options_for_plot')
end

if animal > size(all_data, 2)
    animal = 1;
end
if day > size(all_data(animal).data, 2)
    day = 1;
end

num_extra_var = 4;
fig = figure();
set(gcf,"color","w", 'Renderer', 'painters');
% height_of_fig = min(400*num_rows, 1588);
screenSize = get(0, 'ScreenSize'); screenWidth = screenSize(3);
if screenWidth == 3008
    height_of_fig = 1300;
else
    height_of_fig = 800;
end
if ispc
    % fig.Position = [67         160        2884         400*num_rows];
    fig.Position = [78         69        2480         300*num_rows];
else
    % fig.Position = [1        1        2884         height_of_fig];
    if paper_figure(1) == 1
        fig.Position = [250        1        2884         600];
    else
        fig.Position = [250        1        2884         778];
    end
end

values = {repmat(3, 1, 8), repmat(5, 1, 8),repmat(10, 1, 8), repmat(20, 1, 8), repmat(40, 1, 8), ...
    repmat(70, 1, 8), repmat(100, 1, 8), repmat(paper_figure(3), 1, 8)};
mapMovMean = containers.Map({100, 150, 200, 400, 800, 1600, 4000, -1}, values);
buttonMovMeanMap = containers.Map({100, 150, 200, 400, 800, 1600, 4000}, {1, 2, 3, 4, 5, 6, 7});
colorNameMap = containers.Map({'facemotion2', 'pupil', 'speed_nose_tip', 'facemotion3'}, {3, 5, 6, 7});
colorMap = getCurrentColorMap();

if isKey(mapMovMean, seconds_per_row)
    current_movmean = mapMovMean(seconds_per_row);
else
    current_movmean = mapMovMean(1600);  % fallback/default
end
height_of_elements = height_of_fig - 75;
editHandles = gobjects(1, num_extra_var + 2);
variablesMenus = gobjects(1, num_extra_var + 2);
for i_text = 1:num_extra_var+2
    editHandles(i_text) = uicontrol('Style', 'edit', 'Position', [165 + 8.5*55 + i_text*2*55, height_of_elements - 15, 80, 25], 'String', current_movmean(i_text), 'Callback', @(src, evt) movmean_checkboxCallback(src, evt, i_text));
end

uicontrol('Style', 'togglebutton', 'String', '5HT/Sp', 'Value', 0, 'Position', [150 + 35.7*55, height_of_elements+15, 60, 30], 'Callback', @(src, evt) presetVariables(src, evt, 1));
uicontrol('Style', 'togglebutton', 'String', '5HT/Sp/PC1/Wp', 'Value', 0, 'Position', [150 + 35.7*55, height_of_elements-10, 60, 30], 'Callback', @(src, evt) presetVariables(src, evt, 2));

max_time = 0;
animal_list = 1:numel(all_data);
day_list = 1:numel(all_data(1).data);

% change animal/day logic
animal_popupmenu = uicontrol('Style', 'popupmenu', 'String', animal_list, 'Position', [150 + 26.5*55, height_of_elements - 10, 110, 25], 'Value', animal, 'Callback', @(src, evt) changeAnimalDay(src, evt, 0));
day_popupmenu = uicontrol('Style', 'popupmenu', 'String', day_list, 'Position', [150 + 28.5*55, height_of_elements - 10, 110, 25], 'Value', day, 'Callback', @(src, evt) changeAnimalDay(src, evt, 1));
uicontrol('Style', 'togglebutton', 'String', '-', 'Value', 0, 'Position', [150 + 28*55, height_of_elements+15, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, 3));
uicontrol('Style', 'togglebutton', 'String', '+', 'Value', 0, 'Position', [150 + 29*55, height_of_elements+15, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, 4));

%arrows
uicontrol('Style', 'pushbutton', 'String', '<', 'Position', [150 + 4*55, height_of_elements, 40, 30], 'Callback', @(src, event) arrowButtonCallback(3));
uicontrol('Style', 'pushbutton', 'String', '<', 'Position', [150 + 4.7*55, height_of_elements+5, 15, 20], 'Callback', @(src, event) arrowButtonCallback(1));
uicontrol('Style', 'pushbutton', 'String', '>', 'Position', [150 + 5*55, height_of_elements+5, 15, 20], 'Callback', @(src, event) arrowButtonCallback(2));
uicontrol('Style', 'pushbutton', 'String', '>', 'Position', [150 + 5.3*55, height_of_elements, 40, 30], 'Callback', @(src, event) arrowButtonCallback(4));

%preset animals
uicontrol('Style', 'togglebutton', 'String', '11_4', 'Value', 0, 'Position', [150 + 33*55, height_of_elements+15, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, [2, 11, 4]));
uicontrol('Style', 'togglebutton', 'String', '14_2', 'Value', 0, 'Position', [150 + 33*55, height_of_elements-10, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, [2, 14, 2]));
uicontrol('Style', 'togglebutton', 'String', '14_4', 'Value', 0, 'Position', [150 + 33.7*55, height_of_elements+15, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, [2, 14, 4]));
uicontrol('Style', 'togglebutton', 'String', '15_2', 'Value', 0, 'Position', [150 + 33.7*55, height_of_elements-10, 40, 30], 'Callback', @(src, evt) changeAnimalDay(src, evt, [2, 15, 2]));

%misc, change time, variable per row
checkbox1 = uicontrol('Style', 'checkbox', 'String', 'Rows', 'Position', [150 + 7.5*55, height_of_elements, 50, 30], 'Value', variable_per_row, 'BackgroundColor', [1 1 1], 'Callback', @(src, evt) changeRows(src));
uicontrol('Style', 'edit', 'Position', [150 + 6.2*55, height_of_elements, 70, 30], 'Callback', @(src, event) updateValueCallback(src));

variablesMenus(7) = uicontrol('Style', 'popupmenu', 'String', {'none', 'zsc_exp'}, 'Position', [150 + 10.5*55, height_of_elements + 15, 110, 25], 'Value', plot_sero_speed(1)+1, 'Callback', @(src, evt) addVariable(src, evt, 7), 'ForegroundColor', 'b');
variablesMenus(8) = uicontrol('Style', 'popupmenu', 'String', {'none', 'speed'}, 'Position', [150 + 12.5*55, height_of_elements + 15, 110, 25], 'Value', plot_sero_speed(2)+1, 'Callback', @(src, evt) addVariable(src, evt, 8), 'ForegroundColor', colorMap(1));

% Setup the time series plot
active_rows = 0;

% if paper_figure(1) > 0
%     current_movmean = mapMovMean(-1);
%     seconds_per_row = paper_figure(2);
%     start_time = paper_figure(4);
%     animal = paper_figure(5);
%     day = paper_figure(6);
%     variable_per_row = 1;
% end


if paper_figure(1) == 1
    plot_sero_speed = [1, 0];
    if preset_variables == 1
        variables_tile_1 = ["none", "none", "none", "none", "none", "none"];
    elseif preset_variables == 2
        variables_tile_1 = ["pc1nose", "wp_motion", "none", "none", "none", "none"];
    end
    first_none = find(variables_tile_1 == "none", 1, 'first');
    if ~isempty(first_none)
        variables_tile_1(first_none) = "speed";
    end
end

% change listbox options (rewards, lines)
session_table = all_data(animal).data(day).d;
option_fields = fieldnames(session_table);
option_fields = option_fields(contains(option_fields, 'option'));
for i = 1:length(option_fields)
    fname = option_fields{i};
    if ~isfield(options_for_plot, fname)
        options_for_plot.(fname) = false;
    end
end
listbox_labels = create_listbox_labels(options_for_plot);
listbox = uicontrol('Style', 'listbox', 'String', listbox_labels, 'Position', [150 + 30.5*55, height_of_elements - 8, 110, 55], 'Value', day, 'Callback', @(src, evt) toggle_option(src, evt));

%setup plot continuation
[layoutHandle, Duration2, reached, buttonHandles] = initialise_plot(session_table);

if exist('preset_variables', 'var') && preset_variables > 0 && paper_figure(1) ~= 1
    presetVariables(0, 0, preset_variables)
end
defineVariables();
plot_stuff();



if video_bool == 1
    if video_bool == 1; setappdata(0, 'shared_seconds_per_row', seconds_per_row); end
end

if seconds(max_time) < start_time + active_rows(end)*seconds_per_row
    max_time_done = [1, 0];
else
    max_time_done = [0, active_rows(end)*seconds_per_row];
end

if paper_figure(1) == 1
    ax = nexttile(layoutHandle,1);
    xlima = get(gca, 'XLim');
    ylima = get(gca, 'YLim');
    if seconds_per_row < 200
        text_now = '30s';
        x_bar = [xlima(end) - seconds(60) , xlima(end) - seconds(90)]; % 20% width bar
    else
        text_now = '60s';
        x_bar = [xlima(end) - seconds(60) , xlima(end) - seconds(120)]; % 20% width bar
    end
    y_bar = [ylima(end)-1, ylima(end)-1]; % Bar at 10% height
    plot(x_bar, y_bar, 'k', 'LineWidth', 1); % HorizontaFl scale bar
    text(mean(x_bar), y_bar(1) + 0.25 * diff(ylima), text_now, ...
            'HorizontalAlignment', 'center', 'FontSize', 10); % Scale bar label


    x_bar = [xlima(end) - seconds(30) , xlima(end) - seconds(30)];

    for ii_row = active_rows
        nexttile(layoutHandle, ii_row);
        ylima = get(gca, 'YLim');
        hold on
        if paper_figure(2) ~= 400
            if ii_row == 1
                name="zsc_exp";
            else
                name = variables_tile_1(ii_row-1);
            end
            if strcmp("speed", name)
                % std_now = std(session_table.speed(not(isnan(session_table.speed))));
                % y_bar = [ylima(1) + 0.75*range(ylima), ylima(1) + 0.75*range(ylima)-(20/std_now)]; % Bar at 10% height
                y_bar = [ylima(1) + 0.75*range(ylima), ylima(1) + 0.75*range(ylima)-(20)]; % Bar at 10% height
                text_now = '20 cm/s';
            else
                y_bar = [ylima(end)-1, ylima(end)-2]; % Bar at 10% height
                text_now = '1 std';
            end
            plot(x_bar, y_bar, 'k', 'LineWidth', 1); % Horizontal scale bar
            % text(x_bar(1)+seconds(10.5), mean(y_bar), text_now, ...
                % 'HorizontalAlignment', 'center', 'FontSize', 10, 'Rotation', 90); % Scale bar label
        end
        lines = findall(gca, 'Type', 'Line');
        lines = lines(arrayfun(@(x) numel(x.XData) > 2, lines)); % filter lines longer than 2 points
        set(lines, 'LineWidth', 0.25);
    end

    axes = findobj(layoutHandle, 'Type', 'axes');
    for ax = axes'
        ax.XColor = 'none'; % Hide x-axis line and ticks

        yyaxis(ax, 'left');
        ax.YColor = 'none';
        yyaxis(ax, 'right');
        ax.YColor = 'none';

        ax.XColor = 'none';
        ax.XTick = [];
        ax.YTick = [];
    end

    save_cropped_image_old(fig, [num2str(animal) '_' num2str(day) '_' num2str(start_time) '_' num2str(paper_figure(2)) '_' num2str(paper_figure(3))], [4.5 1.5]);
end

if video_bool == 1
    videoStruct = struct();
    videoStruct.layoutHandle = layoutHandle;
    videoStruct.first_tcam = session_table.tcam(1);
    videoStruct.last_tcam = session_table.tcam(end);
    time = seconds(session_table.time - session_table.time(1));
    videoStruct.last_time_harp = time(end);
    videoStruct.left_lim = start_time;
end




function xlim_change(seconds_per_row_var)
    if seconds_per_row_var ~= seconds_per_row
        seconds_per_row = seconds_per_row_var;
        current_movmean = mapMovMean(seconds_per_row);
        plot_stuff();
        updateEditBoxes();
        set(buttonHandles, 'Value', 0);
        set(buttonHandles(buttonMovMeanMap(seconds_per_row_var)), 'Value', 1);
        if video_bool == 1; setappdata(0, 'shared_seconds_per_row', seconds_per_row); end
    end

    start_time_var = start_time;
    for i_row = active_rows
        if variable_per_row == 0 || (i_row == 1 || ~strcmp(variables_tile_1(i_row-1), "none"))
            nexttile(layoutHandle, i_row);
            xlim(seconds([start_time_var, start_time_var + seconds_per_row]));
            if variable_per_row == 0
                start_time_var = start_time_var + seconds_per_row;
            end
        %     if i_row == num_rows
        %         title(sprintf('%i - %i sec, total length: %s', start_times(i_row), start_times(i_row) + seconds_per_row, length_str))
        %     else
        %         title(sprintf('%i - %i sec', start_times(i_row), start_times(i_row) + seconds_per_row))
        %     end
        end
    end
    if paper_figure(1) ~= 1 && video_bool == 0; save(saved_settings, 'start_time', 'seconds_per_row', 'images',  'num_rows', 'variables_tile_1', 'variable_per_row', 'plot_sero_speed', 'animal', 'day', 'options_for_plot'); end
end

function [layoutHandle, Duration2, reached, buttonHandles] = initialise_plot(session_table)
    [layoutHandle, Duration2, reached] = a01x_initialise_plot(session_table, num_rows, variable_per_row, variables_tile_1);
    Duration2 = seconds(Duration2);
    % fig.Name = ['Animal: ' num2str(animal) ', Day: ' num2str(day) ', total length: ' num2str(Duration2) ' sec, #Trials: ' num2str(max(session_table.trial))];

    % closeButton = uicontrol('Style', 'pushbutton', 'String', 'Close', 'Position', [150 - 55, height_of_elements, 50, 30], 'Callback', @(src, event) delete(fig));
    values = [100, 150, 200, 400, 800, 1600, 4000];
    buttonHandles = gobjects(1, numel(values));
    for i = 1:numel(values)
        buttonHandles(i) = uicontrol('Style', 'togglebutton', ...
            'String', num2str(values(i)), ...
            'Position', [80 + (i-1)*40, height_of_elements, 40, 30], ...
            'Value', seconds_per_row == values(i), ...
            'Callback', @(src, evt) xlim_change(values(i)));
    end

    columnNames = session_table.Properties.VariableNames;
    columnNames = [{'none'}, flip(columnNames)];
    % index = find(strcmp(columnNames, 'tcam'));
    % columnNames = columnNames(index:end);
    % columnNames = [{'none'}, columnNames, {'pupil', 'g475', 'g405', 'speed', 'zsc_exp', 'facemotion', 'cleanrawg475', 'zsc_exp'}];
    % disp('ahoj')

    for i_dropdown = 1:num_extra_var
        if(isempty(find(strcmp(columnNames, variables_tile_1(i_dropdown)), 1)))
            value_now = 1;
        else
            value_now = find(strcmp(variables_tile_1(i_dropdown), columnNames), 1);
            if ~strcmp(getColor(columnNames(value_now)), 'k')
                color_now = getColor(columnNames(value_now));
            else
                colors_jet = hsv(7);
                color_now = colors_jet(mod(1+3*i_dropdown,7)+1, :);
            end
        end
        if value_now == 1; variables_tile_1(i_dropdown) = "none"; color_now = 'k'; end
        variablesMenus(i_dropdown) = uicontrol('Style', 'popupmenu', 'String', columnNames, 'Position', [150 + 12.5*55 + i_dropdown*2*55, height_of_elements + 15, 110, 25], 'Value', value_now, 'Callback', @(src, evt) addVariable(src, evt, i_dropdown), 'ForegroundColor', color_now);
    end
end

function plot_stuff()
    [result, max_time] = a01x_plot_stuff(layoutHandle, session_table, current_movmean, active_rows, plot_sero_speed, variables_tile_1, reached, colorMap, colorNameMap, variable_per_row, images, seconds_per_row, paper_figure(1), options_for_plot, all_data, animal, day);
    if result ~= 0
        xlim_change(seconds_per_row);
    end
end

function movmean_checkboxCallback(src, ~, i_dropdown)
    current_movmean(i_dropdown) = str2double(src.String);
    plot_stuff()
    xlim_change(seconds_per_row);
end

function toggle_option(src, ~)
    selected_idx = src.Value;

    opts = options_for_plot;
    names = fieldnames(opts);

    selected_field = names{selected_idx};
    opts.(selected_field) = ~opts.(selected_field);

    options_for_plot = opts;

    src.String = create_listbox_labels(opts);
    disp('Plotting')

    plot_stuff()
    if video_bool == 1; sendValuesToVideoPlayer(4, options_for_plot); end
end

function labels = create_listbox_labels(opts)
    field_names = fieldnames(opts);

    labels = arrayfun(@(f) ...
        sprintf('[%s] %s', ...
                ifelse(opts.(f{1}), '✓', ' '), f{1}), ...
        field_names, 'UniformOutput', false);
end

% Helper function to emulate an inline if (ternary operator)
function result = ifelse(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

function defineVariables()
    if variable_per_row == 1
        active_rows = [1, nonzeros((2:(length(variables_tile_1)+1)) .* (variables_tile_1 ~= "none"))'];
    else
        active_rows = 1:num_rows;
    end
    if video_bool == 1; sendValuesToVideoPlayer(3, variables_tile_1); end
end

function updateEditBoxes()
    for i = 1:length(editHandles)
        set(editHandles(i), 'String', num2str(current_movmean(i)));
    end
end

function updateValueCallback(src)
    newValue = str2double(src.String);
    if isnan(newValue)
        disp('Please enter a valid number.');
        return;
    end
    if video_bool == 1; sendValuesToVideoPlayer(1, newValue); end
    start_time = newValue;
    xlim_change(seconds_per_row);
end

function arrowButtonCallback(direction)
    if direction == 1
        difference = - seconds_per_row;
    elseif direction == 2
        difference = + seconds_per_row;
    elseif direction == 3
        difference = - 4 * seconds_per_row;
    elseif direction == 4
        difference = + 4 * seconds_per_row;
    end
    start_time = start_time + difference;
    xlim_change(seconds_per_row);
    if video_bool == 1; sendValuesToVideoPlayer(2, difference); end
end

function changeRows(src)
    if src.Value == 1
        variable_per_row = 1;  % Set to 1 when checked
    else
        variable_per_row = 0;  % Set to 0 when unchecked
    end
    num_rows = 4 + variable_per_row*2;
    defineVariables();
    [layoutHandle, Duration2, reached] = a01x_initialise_plot(session_table, num_rows, variable_per_row, variables_tile_1);
    Duration2 = seconds(Duration2);
    plot_stuff()
end

function changeAnimalDay(src, ~, animal_or_day)
    if options_for_plot.only_quiescence == true && (animal_or_day(1) == 3 || animal_or_day(1) == 4)
        if animal_or_day(1) == 4
            animal = animal + 1;
        else
            animal = animal - 1;
        end
    elseif animal_or_day(1) == 0
        animal = src.Value;
    elseif animal_or_day(1) == 1
        day = src.Value;
    elseif animal_or_day(1) == 2
        day = animal_or_day(3);
        animal = animal_or_day(2);
    elseif animal_or_day(1) == 4
        if day ~= 10
            day = day + 1;
        else
            day = 1;
            % if contains(animals, animal + 1)
                animal = animal + 1;
            % end
        end
    elseif animal_or_day(1) == 3
        if day ~= 1
            day = day - 1;
        else
            day = 10;
            % if contains(animals, animal - 1)
                animal = animal - 1;
            % end
        end
    end
    animal_popupmenu.Value = animal;
    day_popupmenu.Value = day;
    session_table = all_data(animal).data(day).d;
    [layoutHandle, Duration2, reached, buttonHandles] = initialise_plot(session_table);
    plot_stuff();
end

function addVariable(src, ~, tile)
    if tile < 7
        selectedColumn = src.String{src.Value};
        variables_tile_1(tile) = selectedColumn;
        defineVariables();
        if ~strcmp(getColor(selectedColumn), 'k')
            color = getColor(selectedColumn);
        else
            colors_jet = hsv(7);
            color = colors_jet(mod(1+3*tile,7)+1, :);
        end
        src.ForegroundColor = color;
    else
        plot_sero_speed(tile-6) = ~strcmp(src.String{src.Value}, 'none');
    end
    plot_stuff();
end

function presetVariables(~, ~, preset_num)
    switch preset_num
        case 1
            plot_sero_speed = [1, 1];
            variables_tile_1 = ["none", "none", "none", "none", "none", "none"];
        case 2
            plot_sero_speed = [1, 1];
            variables_tile_1 = ["pc1nose", "wp_motion", "none", "none", "none", "none"];
    end
    defineVariables();
    update_selected_columns_variables();
    plot_stuff();
end

function update_selected_columns_variables()
    for i_variable = 1:num_extra_var
        value_now = find(strcmp(variables_tile_1{i_variable}, variablesMenus(i_variable).String));
        variablesMenus(i_variable).Value = value_now;
        addVariable(variablesMenus(i_variable), 0, i_variable);
    end
end

% function sliderMoved(src, ~, slider_id)
%     counter = 0;
%     if isvalid(t) && strcmp(t.Running, 'on')
%         stop(t);  % Stop the timer only if it is running and valid
%     end
%     if slider_id == 1
%         reader.CurrentTime = src.Value * Duration2 + time_before_first_tcam;  % Set the reader's current time to the new time
%     else
%         reader.CurrentTime = left_lim + time_before_first_tcam + src.Value*seconds_per_row;  % Set the reader's current time to the new time
%     end
%     playButton.Value = 0;  % Reset play button to show it's paused
%
%     timerfcn(0, 0, slider_id);
% end

function videoUpdate(start_time_new)
    start_time = start_time_new;
    xlim_change(seconds_per_row);
end

if video_bool == 1
    videoStruct.videoUpdate = @videoUpdate;
end

end