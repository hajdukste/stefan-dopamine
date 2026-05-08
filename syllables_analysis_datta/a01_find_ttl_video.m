


% build animal/day label lists
animal_items = cell(1, length(all_data));
for i = 1:length(all_data)
    animal_items{i} = sprintf('%d: %s', i, all_data(i).name);
end

animal = 1;
day = 1;
video_path = all_data(animal).data(day).mp4_path;

vid = VideoReader(video_path);
info.n_frames = floor(vid.Duration * vid.FrameRate);
info.fps = vid.FrameRate;
info.vid_h = vid.Height;
info.vid_w = vid.Width;

% read first frame
vid.CurrentTime = 0;
first_frame = readFrame(vid);

% build UI
fig = uifigure('Name', 'Light Detector', 'WindowState', 'maximized');
gl = uigridlayout(fig, [6 8]);
gl.RowHeight = {30, '3x', 30, 30, 30, 30, '1.5x'};
gl.ColumnWidth = {'1x','1x','1x','1x','1x','1x','1x','1x'};

% animal/day selectors (row 1)
lbl_animal = uilabel(gl, 'Text', 'Animal:');
lbl_animal.Layout.Row = 1; lbl_animal.Layout.Column = 1;
lbl_animal.HorizontalAlignment = 'right';

dd_animal = uidropdown(gl, 'Items', animal_items, 'Value', animal_items{animal});
dd_animal.Layout.Row = 1; dd_animal.Layout.Column = 2;

lbl_day = uilabel(gl, 'Text', 'Day:');
lbl_day.Layout.Row = 1; lbl_day.Layout.Column = 3;
lbl_day.HorizontalAlignment = 'right';

day_items = get_day_items(all_data, animal);
dd_day = uidropdown(gl, 'Items', day_items, 'Value', day_items{day});
dd_day.Layout.Row = 1; dd_day.Layout.Column = 4;

lbl_vid_info = uilabel(gl, 'Text', sprintf('%s - %s', all_data(animal).name, all_data(animal).data(day).day_label));
lbl_vid_info.Layout.Row = 1; lbl_vid_info.Layout.Column = [5 8];

% video axes
ax_vid = uiaxes(gl);
ax_vid.Layout.Row = 1;
ax_vid.Layout.Row = 2;
ax_vid.Layout.Column = [1 8];
% show zoomed bottom-left corner by default
crop_h = min(200, info.vid_h);
crop_w = min(200, info.vid_w);
y1 = max(1, info.vid_h - crop_h + 1);
first_crop = first_frame(y1:info.vid_h, 1:crop_w, :);
im_handle = imshow(first_crop, 'Parent', ax_vid);
ax_vid.Title.String = sprintf('Frame 1 / %d', info.n_frames);

% frame slider
sld = uislider(gl, 'Limits', [1 info.n_frames], 'Value', 1);
sld.Layout.Row = 3;
sld.Layout.Column = [1 8];
sld.MajorTicks = [];
sld.MinorTicks = [];

% controls row
btn_play = uibutton(gl, 'Text', 'Play');
btn_play.Layout.Row = 4; btn_play.Layout.Column = 1;

btn_zoom = uibutton(gl, 'Text', 'Full View');
btn_zoom.Layout.Row = 4; btn_zoom.Layout.Column = 2;

btn_pick = uibutton(gl, 'Text', 'Pick Pixel');
btn_pick.Layout.Row = 4; btn_pick.Layout.Column = 3;

lbl_roi = uilabel(gl, 'Text', 'ROI radius:');
lbl_roi.Layout.Row = 4; lbl_roi.Layout.Column = 4;
lbl_roi.HorizontalAlignment = 'right';

spn_roi = uispinner(gl, 'Value', 3, 'Limits', [1 15], 'Step', 1);
spn_roi.Layout.Row = 4; spn_roi.Layout.Column = 5;

btn_save = uibutton(gl, 'Text', 'Save ROI');
btn_save.Layout.Row = 4; btn_save.Layout.Column = 6;

dd_speed = uidropdown(gl, 'Items', {'1x','3x','5x','10x'}, 'Value', '1x');
dd_speed.Layout.Row = 4; dd_speed.Layout.Column = 7;

btn_load = uibutton(gl, 'Text', 'Load');
btn_load.Layout.Row = 4; btn_load.Layout.Column = 8;

% row 5: extra controls
btn_rand = uibutton(gl, 'Text', 'Random');
btn_rand.Layout.Row = 5; btn_rand.Layout.Column = 1;

% status label
lbl_status = uilabel(gl, 'Text', 'Click "Pick Pixel" then click on the light in the image');
lbl_status.Layout.Row = 6; lbl_status.Layout.Column = [1 8];

% timeseries axes
ax_ts = uiaxes(gl);
ax_ts.Layout.Row = 7;
ax_ts.Layout.Column = [1 8];
xlabel(ax_ts, 'Time (s)');
ylabel(ax_ts, 'Intensity');
title(ax_ts, 'Light timeseries');

% store all handles and state in appdata
s = struct();
s.pixel = [];
s.roi_radius = 3;
s.zoomed = true;
s.current_frame_idx = 1;
s.play_timer = [];
s.video_path = video_path;
s.animal = animal;
s.day = day;
s.info = info;
s.vid = vid;
s.handles.ax_vid = ax_vid;
s.handles.ax_ts = ax_ts;
s.handles.im = im_handle;
s.handles.sld = sld;
s.handles.btn_play = btn_play;
s.handles.btn_zoom = btn_zoom;
s.handles.lbl_status = lbl_status;
s.handles.btn_save = btn_save;
s.handles.dd_speed = dd_speed;
s.handles.btn_load = btn_load;
s.handles.dd_animal = dd_animal;
s.handles.dd_day = dd_day;
s.handles.btn_rand = btn_rand;
s.handles.lbl_vid_info = lbl_vid_info;
s.ttl_trace = [];
s.ttl_time = [];
s.handles.ts_cursor = [];
setappdata(fig, 's', s);

% wire callbacks
sld.ValueChangedFcn = @(src, ~) cb_slider(fig, round(src.Value));
btn_play.ButtonPushedFcn = @(~, ~) cb_play(fig);
btn_zoom.ButtonPushedFcn = @(~, ~) cb_zoom(fig);
btn_pick.ButtonPushedFcn = @(~, ~) cb_pick(fig);
spn_roi.ValueChangedFcn = @(src, ~) cb_roi(fig, round(src.Value));
btn_save.ButtonPushedFcn = @(~, ~) cb_save_roi(fig);
btn_load.ButtonPushedFcn = @(~, ~) cb_load(fig);
btn_rand.ButtonPushedFcn = @(~, ~) cb_random(fig);
dd_animal.ValueChangedFcn = @(~, ~) cb_switch_animal(fig);
dd_day.ValueChangedFcn = @(~, ~) cb_switch_day(fig);
fig.CloseRequestFcn = @(~, ~) cb_close(fig);


function cb_slider(fig, frame_idx)
    s = getappdata(fig, 's');
    frame_idx = max(1, min(s.info.n_frames, frame_idx));
    s.current_frame_idx = frame_idx;
    s.vid.CurrentTime = (frame_idx - 1) / s.info.fps;
    if hasFrame(s.vid)
        frm = readFrame(s.vid);
        show_frame(s, frm);
        s.handles.ax_vid.Title.String = sprintf('Frame %d / %d', frame_idx, s.info.n_frames);
        s.handles.sld.Value = frame_idx;
    end
    % update timeseries cursor
    update_ts_cursor(s, frame_idx);
    setappdata(fig, 's', s);
end

function update_ts_cursor(s, frame_idx)
    if isempty(s.ttl_trace); return; end
    t_now = (frame_idx - 1) / s.info.fps;
    % delete old cursor
    delete(findobj(s.handles.ax_ts, 'Tag', 'ts_cursor'));
    hold(s.handles.ax_ts, 'on');
    yl = ylim(s.handles.ax_ts);
    plot(s.handles.ax_ts, [t_now t_now], yl, 'r-', 'LineWidth', 1.5, 'Tag', 'ts_cursor');
    hold(s.handles.ax_ts, 'off');
end

function show_frame(s, frm)
    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        crop_w = min(200, s.info.vid_w);
        y1 = max(1, s.info.vid_h - crop_h + 1);
        crop = frm(y1:s.info.vid_h, 1:crop_w, :);
        s.handles.im.CData = crop;
        s.handles.ax_vid.XLim = [0.5 size(crop,2)+0.5];
        s.handles.ax_vid.YLim = [0.5 size(crop,1)+0.5];
    else
        s.handles.im.CData = frm;
        s.handles.ax_vid.XLim = [0.5 s.info.vid_w+0.5];
        s.handles.ax_vid.YLim = [0.5 s.info.vid_h+0.5];
    end
    draw_roi(s);
end

function cb_zoom(fig)
    s = getappdata(fig, 's');
    s.zoomed = ~s.zoomed;
    if s.zoomed
        s.handles.btn_zoom.Text = 'Full View';
    else
        s.handles.btn_zoom.Text = 'Zoom Corner';
    end
    setappdata(fig, 's', s);
    cb_slider(fig, s.current_frame_idx);
end

function cb_play(fig)
    s = getappdata(fig, 's');
    if ~isempty(s.play_timer) && isvalid(s.play_timer)
        stop(s.play_timer);
        delete(s.play_timer);
        s.play_timer = [];
        s.handles.btn_play.Text = 'Play';
        setappdata(fig, 's', s);
    else
        s.handles.btn_play.Text = 'Stop';
        period = max(round(1/s.info.fps, 3), 0.033);
        t = timer('ExecutionMode', 'fixedRate', 'Period', period, ...
            'TimerFcn', @(~,~) cb_advance(fig));
        s.play_timer = t;
        setappdata(fig, 's', s);
        start(t);
    end
end

function cb_advance(fig)
    s = getappdata(fig, 's');
    speed_str = s.handles.dd_speed.Value;
    speed = str2double(erase(speed_str, 'x'));
    next = s.current_frame_idx + speed;
    if next > s.info.n_frames
        cb_play(fig); % stop
        return;
    end
    cb_slider(fig, next);
end

function cb_pick(fig)
    s = getappdata(fig, 's');
    s.handles.lbl_status.Text = 'Click on the light pixel in the image...';
    s.handles.im.ButtonDownFcn = @(~, evt) cb_pixel_clicked(fig, evt);
    s.handles.ax_vid.HitTest = 'off';
    s.handles.im.HitTest = 'on';
    setappdata(fig, 's', s);
end

function cb_pixel_clicked(fig, evt)
    s = getappdata(fig, 's');
    x = round(evt.IntersectionPoint(1));
    y = round(evt.IntersectionPoint(2));
    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        s.pixel = [1 + x - 1, y1 + y - 1];
    else
        s.pixel = [x, y];
    end
    s.handles.lbl_status.Text = sprintf('Selected pixel: [%d, %d]. Click Extract.', s.pixel(1), s.pixel(2));
    s.handles.im.ButtonDownFcn = '';
    setappdata(fig, 's', s);
    draw_roi(s);
end

function draw_roi(s)
    delete(findobj(s.handles.ax_vid, 'Tag', 'roi_marker'));
    if isempty(s.pixel); return; end
    px = s.pixel;
    r = s.roi_radius;
    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        dx = px(1);
        dy = px(2) - y1 + 1;
    else
        dx = px(1);
        dy = px(2);
    end
    theta = linspace(0, 2*pi, 50);
    cx = dx + r * cos(theta);
    cy = dy + r * sin(theta);
    hold(s.handles.ax_vid, 'on');
    plot(s.handles.ax_vid, cx, cy, 'r-', 'LineWidth', 2, 'Tag', 'roi_marker');
    plot(s.handles.ax_vid, dx, dy, 'r+', 'MarkerSize', 10, 'LineWidth', 2, 'Tag', 'roi_marker');
    hold(s.handles.ax_vid, 'off');
end

function cb_roi(fig, val)
    s = getappdata(fig, 's');
    s.roi_radius = val;
    setappdata(fig, 's', s);
    draw_roi(s);
end

function cb_save_roi(fig)
    s = getappdata(fig, 's');
    if isempty(s.pixel)
        s.handles.lbl_status.Text = 'Pick a pixel first!';
        return;
    end
    px = s.pixel;
    r = s.roi_radius;

    % save ROI params into all_data
    all_data = evalin('base', 'all_data');
    all_data(s.animal).data(s.day).ttl_roi = struct('pixel', px, 'radius', r);
    assignin('base', 'all_data', all_data);

    s.handles.lbl_status.Text = sprintf('Saved ROI to all_data(%d).data(%d).ttl_roi: pixel [%d,%d], r=%d', s.animal, s.day, px(1), px(2), r);
    setappdata(fig, 's', s);
end

function cb_load(fig)
    s = getappdata(fig, 's');
    try
        all_data = evalin('base', 'all_data');
        roi = all_data(s.animal).data(s.day).ttl_roi;

        s.pixel = roi.pixel;
        s.roi_radius = roi.radius;

        draw_roi(s);

        % show ttl_trace if extraction was already done
        has_trace = isfield(all_data(s.animal).data(s.day), 'ttl_data') && ~isempty(all_data(s.animal).data(s.day).ttl_data);
        if has_trace
            td = all_data(s.animal).data(s.day).ttl_data;
            s.ttl_trace = td.ttl_trace;
            s.ttl_time = td.ttl_time;
            plot(s.handles.ax_ts, td.ttl_time, td.ttl_trace, 'k', 'LineWidth', 0.5);
            xlabel(s.handles.ax_ts, 'Time (s)');
            ylabel(s.handles.ax_ts, 'Intensity');
            title(s.handles.ax_ts, sprintf('Light trace - pixel [%d,%d] r=%d', roi.pixel(1), roi.pixel(2), roi.radius));
            update_ts_cursor(s, s.current_frame_idx);
            s.handles.lbl_status.Text = sprintf('Loaded ROI + trace (%d frames) from all_data(%d).data(%d)', length(td.ttl_trace), s.animal, s.day);
        else
            s.handles.lbl_status.Text = sprintf('Loaded ROI from all_data(%d).data(%d): pixel [%d,%d], r=%d (no trace yet)', s.animal, s.day, roi.pixel(1), roi.pixel(2), roi.radius);
        end

        draw_roi(s);
        setappdata(fig, 's', s);
    catch
        s.handles.lbl_status.Text = sprintf('No ttl_roi found in all_data(%d).data(%d).', s.animal, s.day);
    end
end

function cb_switch_animal(fig)
    s = getappdata(fig, 's');
    % stop playback
    if ~isempty(s.play_timer) && isvalid(s.play_timer)
        stop(s.play_timer); delete(s.play_timer); s.play_timer = [];
        s.handles.btn_play.Text = 'Play';
    end
    % parse animal index from dropdown
    val = s.handles.dd_animal.Value;
    s.animal = str2double(regexp(val, '^\d+', 'match', 'once'));
    s.day = 1;
    % update day dropdown
    all_data = evalin('base', 'all_data');
    day_items = get_day_items(all_data, s.animal);
    s.handles.dd_day.Items = day_items;
    s.handles.dd_day.Value = day_items{1};
    setappdata(fig, 's', s);
    cb_load_video(fig);
end

function cb_switch_day(fig)
    s = getappdata(fig, 's');
    % stop playback
    if ~isempty(s.play_timer) && isvalid(s.play_timer)
        stop(s.play_timer); delete(s.play_timer); s.play_timer = [];
        s.handles.btn_play.Text = 'Play';
    end
    val = s.handles.dd_day.Value;
    s.day = str2double(regexp(val, '^\d+', 'match', 'once'));
    setappdata(fig, 's', s);
    cb_load_video(fig);
end

function cb_load_video(fig)
    s = getappdata(fig, 's');
    all_data = evalin('base', 'all_data');
    s.video_path = all_data(s.animal).data(s.day).mp4_path;
    s.vid = VideoReader(s.video_path);
    s.info.n_frames = floor(s.vid.Duration * s.vid.FrameRate);
    s.info.fps = s.vid.FrameRate;
    s.info.vid_h = s.vid.Height;
    s.info.vid_w = s.vid.Width;
    s.current_frame_idx = 1;
    s.pixel = [];
    s.ttl_trace = [];
    s.ttl_time = [];

    % update slider
    s.handles.sld.Limits = [1 s.info.n_frames];
    s.handles.sld.Value = 1;

    % update info label
    s.handles.lbl_vid_info.Text = sprintf('%s - %s', all_data(s.animal).name, all_data(s.animal).data(s.day).day_label);

    % show first frame
    s.vid.CurrentTime = 0;
    frm = readFrame(s.vid);
    show_frame(s, frm);
    s.handles.ax_vid.Title.String = sprintf('Frame 1 / %d', s.info.n_frames);

    % clear timeseries plot
    cla(s.handles.ax_ts);
    xlabel(s.handles.ax_ts, 'Time (s)');
    ylabel(s.handles.ax_ts, 'Intensity');
    title(s.handles.ax_ts, 'Light timeseries');

    s.handles.lbl_status.Text = sprintf('Switched to animal %d, day %d. Pick pixel or Load.', s.animal, s.day);
    setappdata(fig, 's', s);

    % auto-load ROI + trace if available
    cb_load(fig);
end

function items = get_day_items(all_data, animal)
    n = length(all_data(animal).data);
    items = cell(1, n);
    for i = 1:n
        items{i} = sprintf('%d: %s', i, all_data(animal).data(i).day_label);
    end
end

function cb_random(fig)
    s = getappdata(fig, 's');
    frame_idx = randi(s.info.n_frames);
    cb_slider(fig, frame_idx);
end

function cb_close(fig)
    s = getappdata(fig, 's');
    if ~isempty(s.play_timer) && isvalid(s.play_timer)
        stop(s.play_timer);
        delete(s.play_timer);
    end
    delete(fig);
end
