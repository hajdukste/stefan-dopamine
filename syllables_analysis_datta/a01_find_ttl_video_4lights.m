
% a01_find_ttl_video_4lights.m
% Extended version with 4 light ROIs and reference frame corners
%
% Keyboard shortcuts:
%   P - toggle pixel chooser mode for lights (top/left/right/bottom)
%   R - toggle reference frame mode (set 4 corners of box)
%   A - next day (or next animal's first day if on last day)
%   S - save ROI locations (ttl_roi2, ttl_traces2)
%   1/2/3/4 - select which light to pick (1=top, 2=left, 3=right, 4=bottom)

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
fig = uifigure('Name', '4-Light Detector', 'WindowState', 'maximized');
gl = uigridlayout(fig, [6 8]);
gl.RowHeight = {30, '5x', 30, 30, 30, '1x'};
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

% main video axes (left half)
ax_vid = uiaxes(gl);
ax_vid.Layout.Row = 2;
ax_vid.Layout.Column = [1 4];
im_handle = imshow(first_frame, 'Parent', ax_vid);
ax_vid.Title.String = sprintf('Frame 1 / %d', info.n_frames);

% zoom quadrants panel (right half)
zoom_panel = uipanel(gl);
zoom_panel.Layout.Row = 2;
zoom_panel.Layout.Column = [5 8];
zoom_gl = uigridlayout(zoom_panel, [2 2]);
zoom_gl.RowHeight = {'1x', '1x'};
zoom_gl.ColumnWidth = {'1x', '1x'};
zoom_gl.Padding = [2 2 2 2];
zoom_gl.RowSpacing = 2;
zoom_gl.ColumnSpacing = 2;

% zoom size for each quadrant (pixels around the light)
zoom_size = 100;

% Top zoom (top-left quadrant)
ax_zoom_top = uiaxes(zoom_gl);
ax_zoom_top.Layout.Row = 1; ax_zoom_top.Layout.Column = 1;
ax_zoom_top.Title.String = 'Top';
im_zoom_top = imshow(zeros(zoom_size*2, zoom_size*2, 'uint8'), 'Parent', ax_zoom_top);

% Right zoom (top-right quadrant)
ax_zoom_right = uiaxes(zoom_gl);
ax_zoom_right.Layout.Row = 1; ax_zoom_right.Layout.Column = 2;
ax_zoom_right.Title.String = 'Right';
im_zoom_right = imshow(zeros(zoom_size*2, zoom_size*2, 'uint8'), 'Parent', ax_zoom_right);

% Left zoom (bottom-left quadrant)
ax_zoom_left = uiaxes(zoom_gl);
ax_zoom_left.Layout.Row = 2; ax_zoom_left.Layout.Column = 1;
ax_zoom_left.Title.String = 'Left';
im_zoom_left = imshow(zeros(zoom_size*2, zoom_size*2, 'uint8'), 'Parent', ax_zoom_left);

% Bottom zoom (bottom-right quadrant)
ax_zoom_bottom = uiaxes(zoom_gl);
ax_zoom_bottom.Layout.Row = 2; ax_zoom_bottom.Layout.Column = 2;
ax_zoom_bottom.Title.String = 'Bottom';
im_zoom_bottom = imshow(zeros(zoom_size*2, zoom_size*2, 'uint8'), 'Parent', ax_zoom_bottom);

% frame slider
sld = uislider(gl, 'Limits', [1 info.n_frames], 'Value', 1);
sld.Layout.Row = 3;
sld.Layout.Column = [1 8];
sld.MajorTicks = [];
sld.MinorTicks = [];

% controls row 1
btn_play = uibutton(gl, 'Text', 'Play');
btn_play.Layout.Row = 4; btn_play.Layout.Column = 1;

btn_zoom = uibutton(gl, 'Text', 'Reset Zoom');
btn_zoom.Layout.Row = 4; btn_zoom.Layout.Column = 2;

btn_pick = uibutton(gl, 'Text', '[E] Pick Light');
btn_pick.Layout.Row = 4; btn_pick.Layout.Column = 3;

lbl_roi = uilabel(gl, 'Text', 'ROI radius:');
lbl_roi.Layout.Row = 4; lbl_roi.Layout.Column = 4;
lbl_roi.HorizontalAlignment = 'right';

spn_roi = uispinner(gl, 'Value', 3, 'Limits', [1 15], 'Step', 1);
spn_roi.Layout.Row = 4; spn_roi.Layout.Column = 5;

btn_save = uibutton(gl, 'Text', '[S] Save ROI');
btn_save.Layout.Row = 4; btn_save.Layout.Column = 6;

dd_speed = uidropdown(gl, 'Items', {'1x','3x','5x','10x'}, 'Value', '1x');
dd_speed.Layout.Row = 4; dd_speed.Layout.Column = 7;

btn_load = uibutton(gl, 'Text', 'Load');
btn_load.Layout.Row = 4; btn_load.Layout.Column = 8;

% controls row 2
btn_rand = uibutton(gl, 'Text', 'Random');
btn_rand.Layout.Row = 5; btn_rand.Layout.Column = 1;

btn_refframe = uibutton(gl, 'Text', '[R] Ref Frame');
btn_refframe.Layout.Row = 5; btn_refframe.Layout.Column = 2;

% light selector dropdown
dd_light = uidropdown(gl, 'Items', {'1: Top', '2: Left', '3: Right', '4: Bottom'}, 'Value', '1: Top');
dd_light.Layout.Row = 5; dd_light.Layout.Column = 3;

btn_next_day = uibutton(gl, 'Text', '[A] Next Day');
btn_next_day.Layout.Row = 5; btn_next_day.Layout.Column = 4;

% status label
lbl_status = uilabel(gl, 'Text', 'Press P to pick light pixels, R for reference frame. A=next day, S=save.');
lbl_status.Layout.Row = 5; lbl_status.Layout.Column = [5 8];

% timeseries axes
ax_ts = uiaxes(gl);
ax_ts.Layout.Row = 6;
ax_ts.Layout.Column = [1 8];
xlabel(ax_ts, 'Time (s)');
ylabel(ax_ts, 'Intensity');
title(ax_ts, 'Light timeseries');

% store all handles and state in appdata
s = struct();
% 4 light pixels: [top, left, right, bottom] - each is [x, y] or empty
s.light_pixels = {[], [], [], []};
s.light_names = {'Top', 'Left', 'Right', 'Bottom'};
s.light_colors = {'r', 'g', 'b', 'm'}; % colors for each light
s.current_light = 1; % which light is being selected (1-4)
s.roi_radius = 3;
s.zoomed = false; % start with full view for 4 lights
s.current_frame_idx = 1;
s.play_timer = [];
s.video_path = video_path;
s.animal = animal;
s.day = day;
s.info = info;
s.vid = vid;

% modes
s.pick_mode = false;  % P toggles this
s.refframe_mode = false;  % R toggles this
s.current_corner = 1;  % which corner is being selected (1-4)
s.dragging_corner = 0;  % 0 = not dragging, 1-4 = dragging that corner

% panning state
s.panning = false;
s.pan_start = [];
s.pan_xlim_start = [];
s.pan_ylim_start = [];

% reference frame corners: [top-left, top-right, bottom-right, bottom-left]
s.ref_corners = {[], [], [], []};
s.corner_names = {'Top', 'Left', 'Right', 'Bottom'};

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
% zoom quadrant handles
s.handles.ax_zoom = {ax_zoom_top, ax_zoom_left, ax_zoom_right, ax_zoom_bottom};
s.handles.im_zoom = {im_zoom_top, im_zoom_left, im_zoom_right, im_zoom_bottom};
s.zoom_size = zoom_size;
s.handles.btn_rand = btn_rand;
s.handles.lbl_vid_info = lbl_vid_info;
s.handles.btn_pick = btn_pick;
s.handles.btn_refframe = btn_refframe;
s.handles.dd_light = dd_light;
s.handles.btn_next_day = btn_next_day;
s.ttl_traces = {[], [], [], []}; % traces for each light
s.ttl_time = [];
s.handles.ts_cursor = [];
s.handles.corner_points = []; % handles for draggable corner points
setappdata(fig, 's', s);

% wire callbacks
sld.ValueChangedFcn = @(src, ~) cb_slider(fig, round(src.Value));
btn_play.ButtonPushedFcn = @(~, ~) cb_play(fig);
btn_zoom.ButtonPushedFcn = @(~, ~) cb_zoom(fig);
btn_pick.ButtonPushedFcn = @(~, ~) cb_toggle_pick_mode(fig);
spn_roi.ValueChangedFcn = @(src, ~) cb_roi(fig, round(src.Value));
btn_save.ButtonPushedFcn = @(~, ~) cb_save_roi(fig);
btn_load.ButtonPushedFcn = @(~, ~) cb_load(fig);
btn_rand.ButtonPushedFcn = @(~, ~) cb_random(fig);
btn_refframe.ButtonPushedFcn = @(~, ~) cb_toggle_refframe_mode(fig);
btn_next_day.ButtonPushedFcn = @(~, ~) cb_next_day(fig);
dd_animal.ValueChangedFcn = @(~, ~) cb_switch_animal(fig);
dd_day.ValueChangedFcn = @(~, ~) cb_switch_day(fig);
dd_light.ValueChangedFcn = @(src, ~) cb_select_light(fig, src.Value);
fig.CloseRequestFcn = @(~, ~) cb_close(fig);
fig.WindowKeyPressFcn = @(~, evt) cb_keypress(fig, evt);
fig.WindowScrollWheelFcn = @(~, evt) cb_scroll(fig, evt);

% enable panning by default (will be overridden by pick/refframe modes)
im_handle.ButtonDownFcn = @(~, evt) cb_pan_start(fig, evt);
ax_vid.HitTest = 'off';
im_handle.HitTest = 'on';

% initialize zoom quadrants with first frame
update_zoom_quadrants(s, first_frame);

% click on timeseries to jump to that time
ax_ts.ButtonDownFcn = @(~, evt) cb_timeseries_click(fig, evt);


function cb_timeseries_click(fig, evt)
    s = getappdata(fig, 's');
    % get clicked x position (time)
    t_click = evt.IntersectionPoint(1);
    % convert time to frame index
    frame_idx = round(t_click * s.info.fps) + 1;
    frame_idx = max(1, min(s.info.n_frames, frame_idx));
    % update video to that frame
    cb_slider(fig, frame_idx);
end

function cb_keypress(fig, evt)
    s = getappdata(fig, 's');
    switch evt.Key
        case 'e'
            cb_toggle_pick_mode(fig);
        case 'r'
            cb_toggle_refframe_mode(fig);
        case 'a'
            cb_next_day(fig);
        case 's'
            cb_save_roi(fig);
        case '1'
            s.current_light = 1;
            s.handles.dd_light.Value = '1: Top';
            s.handles.lbl_status.Text = 'Selected light: Top';
            setappdata(fig, 's', s);
        case '2'
            s.current_light = 2;
            s.handles.dd_light.Value = '2: Left';
            s.handles.lbl_status.Text = 'Selected light: Left';
            setappdata(fig, 's', s);
        case '3'
            s.current_light = 3;
            s.handles.dd_light.Value = '3: Right';
            s.handles.lbl_status.Text = 'Selected light: Right';
            setappdata(fig, 's', s);
        case '4'
            s.current_light = 4;
            s.handles.dd_light.Value = '4: Bottom';
            s.handles.lbl_status.Text = 'Selected light: Bottom';
            setappdata(fig, 's', s);
    end
end

function cb_scroll(fig, evt)
    s = getappdata(fig, 's');
    % get mouse position relative to video axes
    cp = s.handles.ax_vid.CurrentPoint;
    mouse_x = cp(1,1);
    mouse_y = cp(1,2);

    % check if mouse is over the video axes
    xl = s.handles.ax_vid.XLim;
    yl = s.handles.ax_vid.YLim;
    if mouse_x < xl(1) || mouse_x > xl(2) || mouse_y < yl(1) || mouse_y > yl(2)
        return; % mouse not over video
    end

    % scroll up = zoom in, scroll down = zoom out
    scroll_count = evt.VerticalScrollCount;

    % convert mouse position to full image coordinates
    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        img_x = mouse_x;
        img_y = y1 + mouse_y - 1;
    else
        img_x = mouse_x;
        img_y = mouse_y;
    end

    % store zoom center for custom zoom
    if ~isfield(s, 'zoom_center') || isempty(s.zoom_center)
        s.zoom_center = [s.info.vid_w/2, s.info.vid_h/2];
    end
    if ~isfield(s, 'zoom_level') || isempty(s.zoom_level)
        s.zoom_level = 1;
    end

    % update zoom level
    if scroll_count < 0
        s.zoom_level = min(s.zoom_level * 1.2, 10); % zoom in
    else
        s.zoom_level = max(s.zoom_level / 1.2, 1); % zoom out
    end

    % update zoom center to mouse position when zooming in
    if scroll_count < 0
        s.zoom_center = [img_x, img_y];
    end

    % calculate view bounds
    view_w = s.info.vid_w / s.zoom_level;
    view_h = s.info.vid_h / s.zoom_level;

    x1 = s.zoom_center(1) - view_w/2;
    x2 = s.zoom_center(1) + view_w/2;
    y1 = s.zoom_center(2) - view_h/2;
    y2 = s.zoom_center(2) + view_h/2;

    % clamp to image bounds
    if x1 < 1; x2 = x2 + (1 - x1); x1 = 1; end
    if y1 < 1; y2 = y2 + (1 - y1); y1 = 1; end
    if x2 > s.info.vid_w; x1 = x1 - (x2 - s.info.vid_w); x2 = s.info.vid_w; end
    if y2 > s.info.vid_h; y1 = y1 - (y2 - s.info.vid_h); y2 = s.info.vid_h; end
    x1 = max(1, x1); y1 = max(1, y1);

    % update axes limits
    s.handles.ax_vid.XLim = [x1 x2];
    s.handles.ax_vid.YLim = [y1 y2];

    % disable the old zoomed mode since we're using custom zoom now
    s.zoomed = false;
    s.handles.btn_zoom.Text = 'Reset Zoom';

    setappdata(fig, 's', s);
end

function cb_pan_start(fig, ~)
    s = getappdata(fig, 's');

    % don't pan if in pick or refframe mode
    if s.pick_mode || s.refframe_mode
        return;
    end

    % check if zoomed in
    if ~isfield(s, 'zoom_level') || s.zoom_level <= 1
        return;
    end

    % start panning
    cp = s.handles.ax_vid.CurrentPoint;
    s.panning = true;
    s.pan_start = [cp(1,1), cp(1,2)];
    s.pan_xlim_start = s.handles.ax_vid.XLim;
    s.pan_ylim_start = s.handles.ax_vid.YLim;

    fig.WindowButtonMotionFcn = @(~, ~) cb_pan_move(fig);
    fig.WindowButtonUpFcn = @(~, ~) cb_pan_end(fig);

    setappdata(fig, 's', s);
end

function cb_pan_move(fig)
    s = getappdata(fig, 's');

    if ~s.panning
        return;
    end

    cp = s.handles.ax_vid.CurrentPoint;
    dx = cp(1,1) - s.pan_start(1);
    dy = cp(1,2) - s.pan_start(2);

    new_xlim = s.pan_xlim_start - dx;
    new_ylim = s.pan_ylim_start - dy;

    % clamp to image bounds
    view_w = diff(new_xlim);
    view_h = diff(new_ylim);

    if new_xlim(1) < 1
        new_xlim = [1, 1 + view_w];
    end
    if new_xlim(2) > s.info.vid_w
        new_xlim = [s.info.vid_w - view_w, s.info.vid_w];
    end
    if new_ylim(1) < 1
        new_ylim = [1, 1 + view_h];
    end
    if new_ylim(2) > s.info.vid_h
        new_ylim = [s.info.vid_h - view_h, s.info.vid_h];
    end

    s.handles.ax_vid.XLim = new_xlim;
    s.handles.ax_vid.YLim = new_ylim;

    % update zoom center
    s.zoom_center = [mean(new_xlim), mean(new_ylim)];
    setappdata(fig, 's', s);
end

function cb_pan_end(fig)
    s = getappdata(fig, 's');
    s.panning = false;
    fig.WindowButtonMotionFcn = '';
    fig.WindowButtonUpFcn = '';
    setappdata(fig, 's', s);
end

function cb_toggle_pick_mode(fig)
    s = getappdata(fig, 's');
    s.pick_mode = ~s.pick_mode;
    s.refframe_mode = false; % turn off refframe mode

    if s.pick_mode
        s.handles.btn_pick.Text = '[E] PICKING...';
        s.handles.btn_pick.BackgroundColor = [0.8 1 0.8];
        s.handles.btn_refframe.Text = '[R] Ref Frame';
        s.handles.btn_refframe.BackgroundColor = [0.96 0.96 0.96];
        s.handles.lbl_status.Text = 'PICK MODE: Click in zoom quadrants to set light positions';
        % set click handlers on zoom quadrant images
        for i = 1:4
            s.handles.im_zoom{i}.ButtonDownFcn = @(~, evt) cb_zoom_light_clicked(fig, evt, i);
            s.handles.im_zoom{i}.HitTest = 'on';
            s.handles.ax_zoom{i}.HitTest = 'off';
        end
    else
        s.handles.btn_pick.Text = '[E] Pick Light';
        s.handles.btn_pick.BackgroundColor = [0.96 0.96 0.96];
        s.handles.lbl_status.Text = 'Pick mode OFF';
        % clear zoom quadrant click handlers
        for i = 1:4
            s.handles.im_zoom{i}.ButtonDownFcn = '';
        end
    end
    setappdata(fig, 's', s);
end

function cb_toggle_refframe_mode(fig)
    s = getappdata(fig, 's');
    s.refframe_mode = ~s.refframe_mode;
    s.pick_mode = false; % turn off pick mode

    if s.refframe_mode
        s.handles.btn_refframe.Text = '[R] SETTING...';
        s.handles.btn_refframe.BackgroundColor = [1 0.8 0.8];
        s.handles.btn_pick.Text = '[E] Pick Light';
        s.handles.btn_pick.BackgroundColor = [0.96 0.96 0.96];
        s.handles.lbl_status.Text = 'REF FRAME MODE: Click in zoom quadrants to set ref points';
        % set click handlers on zoom quadrant images
        for i = 1:4
            s.handles.im_zoom{i}.ButtonDownFcn = @(~, evt) cb_zoom_ref_clicked(fig, evt, i);
            s.handles.im_zoom{i}.HitTest = 'on';
            s.handles.ax_zoom{i}.HitTest = 'off';
        end
        % hide light ROIs
        delete(findobj(s.handles.ax_vid, 'Tag', 'roi_marker'));
    else
        s.handles.btn_refframe.Text = '[R] Ref Frame';
        s.handles.btn_refframe.BackgroundColor = [0.96 0.96 0.96];
        s.handles.lbl_status.Text = 'Ref frame mode OFF';
        % clear zoom quadrant click handlers
        for i = 1:4
            s.handles.im_zoom{i}.ButtonDownFcn = '';
        end
        % show light ROIs again
        draw_all_rois(s);
    end
    setappdata(fig, 's', s);
end

function cb_zoom_light_clicked(fig, evt, quadrant_idx)
    % quadrant_idx: 1=Top, 2=Left, 3=Right, 4=Bottom
    s = getappdata(fig, 's');

    % get click position in the zoom quadrant
    x = round(evt.IntersectionPoint(1));
    y = round(evt.IntersectionPoint(2));

    % convert to full image coordinates
    % need to know the center of this quadrant's view
    default_centers = {
        [round(s.info.vid_w/2), s.zoom_size],                    % Top
        [s.zoom_size, round(s.info.vid_h/2)],                    % Left
        [s.info.vid_w - s.zoom_size, round(s.info.vid_h/2)],     % Right
        [round(s.info.vid_w/2), s.info.vid_h - s.zoom_size]      % Bottom
    };

    if ~isempty(s.light_pixels{quadrant_idx})
        cx = s.light_pixels{quadrant_idx}(1);
        cy = s.light_pixels{quadrant_idx}(2);
    else
        cx = default_centers{quadrant_idx}(1);
        cy = default_centers{quadrant_idx}(2);
    end

    % calculate the crop bounds used for this quadrant
    half = s.zoom_size;
    x1 = max(1, cx - half);
    y1 = max(1, cy - half);

    % convert click to full image coords
    img_x = x1 + x - 1;
    img_y = y1 + y - 1;

    % clamp to image bounds
    img_x = max(1, min(s.info.vid_w, img_x));
    img_y = max(1, min(s.info.vid_h, img_y));

    pixel = [img_x, img_y];

    % assign to this quadrant's light
    s.light_pixels{quadrant_idx} = pixel;
    s.current_light = quadrant_idx;
    s.handles.dd_light.Value = s.handles.dd_light.Items{quadrant_idx};
    s.handles.lbl_status.Text = sprintf('Set %s light at [%d, %d]', s.light_names{quadrant_idx}, pixel(1), pixel(2));

    setappdata(fig, 's', s);
    draw_all_rois(s);

    % update zoom quadrants to reflect new position
    s.vid.CurrentTime = (s.current_frame_idx - 1) / s.info.fps;
    if hasFrame(s.vid)
        frm = readFrame(s.vid);
        update_zoom_quadrants(s, frm);
    end
end

function cb_zoom_ref_clicked(fig, evt, quadrant_idx)
    % quadrant_idx: 1=Top, 2=Left, 3=Right, 4=Bottom
    s = getappdata(fig, 's');

    % get click position in the zoom quadrant
    x = round(evt.IntersectionPoint(1));
    y = round(evt.IntersectionPoint(2));

    % convert to full image coordinates
    default_centers = {
        [round(s.info.vid_w/2), s.zoom_size],                    % Top
        [s.zoom_size, round(s.info.vid_h/2)],                    % Left
        [s.info.vid_w - s.zoom_size, round(s.info.vid_h/2)],     % Right
        [round(s.info.vid_w/2), s.info.vid_h - s.zoom_size]      % Bottom
    };

    if ~isempty(s.light_pixels{quadrant_idx})
        cx = s.light_pixels{quadrant_idx}(1);
        cy = s.light_pixels{quadrant_idx}(2);
    else
        cx = default_centers{quadrant_idx}(1);
        cy = default_centers{quadrant_idx}(2);
    end

    % calculate the crop bounds used for this quadrant
    half = s.zoom_size;
    x1 = max(1, cx - half);
    y1 = max(1, cy - half);

    % convert click to full image coords
    img_x = x1 + x - 1;
    img_y = y1 + y - 1;

    % clamp to image bounds
    img_x = max(1, min(s.info.vid_w, img_x));
    img_y = max(1, min(s.info.vid_h, img_y));

    pixel = [img_x, img_y];

    % assign to this quadrant's ref point
    s.ref_corners{quadrant_idx} = pixel;
    s.current_corner = quadrant_idx;
    s.handles.lbl_status.Text = sprintf('Set %s ref point at [%d, %d]', s.corner_names{quadrant_idx}, pixel(1), pixel(2));

    setappdata(fig, 's', s);
    draw_ref_frame(s);

    % update zoom quadrants to reflect new position
    s.vid.CurrentTime = (s.current_frame_idx - 1) / s.info.fps;
    if hasFrame(s.vid)
        frm = readFrame(s.vid);
        update_zoom_quadrants(s, frm);
    end
end

function cb_light_clicked(fig, evt)
    s = getappdata(fig, 's');
    x = round(evt.IntersectionPoint(1));
    y = round(evt.IntersectionPoint(2));

    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        pixel = [1 + x - 1, y1 + y - 1];
    else
        pixel = [x, y];
    end

    % auto-detect which light based on position
    % Top: y < 100 (near top edge)
    % Bottom: y > height - 100 (near bottom edge)
    % Left: x < 100 (near left edge)
    % Right: x > width - 100 (near right edge)
    edge_threshold = 250;
    px = pixel(1);
    py = pixel(2);
    vid_w = s.info.vid_w;
    vid_h = s.info.vid_h;

    if py < edge_threshold
        light_idx = 1; % Top
    elseif py > vid_h - edge_threshold
        light_idx = 4; % Bottom
    elseif px < edge_threshold
        light_idx = 2; % Left
    elseif px > vid_w - edge_threshold
        light_idx = 3; % Right
    else
        % not near any edge, use current selection
        light_idx = s.current_light;
    end

    s.light_pixels{light_idx} = pixel;
    s.current_light = light_idx;
    s.handles.dd_light.Value = s.handles.dd_light.Items{light_idx};
    s.handles.lbl_status.Text = sprintf('Auto-assigned %s light at [%d, %d]', ...
        s.light_names{light_idx}, pixel(1), pixel(2));
    setappdata(fig, 's', s);
    draw_all_rois(s);
end

function cb_corner_clicked(fig, evt)
    s = getappdata(fig, 's');
    x = round(evt.IntersectionPoint(1));
    y = round(evt.IntersectionPoint(2));

    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        pixel = [1 + x - 1, y1 + y - 1];
    else
        pixel = [x, y];
    end

    % check if clicking near an existing corner (for dragging)
    for i = 1:4
        if ~isempty(s.ref_corners{i})
            dist = sqrt((s.ref_corners{i}(1) - pixel(1))^2 + (s.ref_corners{i}(2) - pixel(2))^2);
            if dist < 20 % within 20 pixels
                s.dragging_corner = i;
                s.handles.lbl_status.Text = sprintf('Dragging %s corner...', s.corner_names{i});
                setappdata(fig, 's', s);
                return;
            end
        end
    end

    % auto-detect which ref point based on position (same as lights)
    edge_threshold = 250;
    px = pixel(1);
    py = pixel(2);
    vid_w = s.info.vid_w;
    vid_h = s.info.vid_h;

    if py < edge_threshold
        corner_idx = 1; % Top
    elseif py > vid_h - edge_threshold
        corner_idx = 4; % Bottom
    elseif px < edge_threshold
        corner_idx = 2; % Left
    elseif px > vid_w - edge_threshold
        corner_idx = 3; % Right
    else
        % not near any edge, use current selection
        corner_idx = s.current_corner;
    end

    s.ref_corners{corner_idx} = pixel;
    s.current_corner = corner_idx;
    s.handles.lbl_status.Text = sprintf('Auto-assigned %s ref point at [%d, %d]', s.corner_names{corner_idx}, pixel(1), pixel(2));

    setappdata(fig, 's', s);
    draw_ref_frame(s);
end

function cb_corner_drag(fig)
    s = getappdata(fig, 's');
    if s.dragging_corner == 0
        return;
    end

    % get current mouse position
    cp = s.handles.ax_vid.CurrentPoint;
    x = round(cp(1,1));
    y = round(cp(1,2));

    if s.zoomed
        crop_h = min(200, s.info.vid_h);
        y1 = s.info.vid_h - crop_h + 1;
        pixel = [1 + x - 1, y1 + y - 1];
    else
        pixel = [x, y];
    end

    % clamp to image bounds
    pixel(1) = max(1, min(s.info.vid_w, pixel(1)));
    pixel(2) = max(1, min(s.info.vid_h, pixel(2)));

    s.ref_corners{s.dragging_corner} = pixel;
    setappdata(fig, 's', s);
    draw_ref_frame(s);
end

function cb_corner_release(fig)
    s = getappdata(fig, 's');
    if s.dragging_corner > 0
        s.handles.lbl_status.Text = sprintf('Released %s corner at [%d, %d]', ...
            s.corner_names{s.dragging_corner}, s.ref_corners{s.dragging_corner}(1), s.ref_corners{s.dragging_corner}(2));
    end
    s.dragging_corner = 0;
    setappdata(fig, 's', s);
end

function cb_select_light(fig, val)
    s = getappdata(fig, 's');
    s.current_light = str2double(val(1));
    s.handles.lbl_status.Text = sprintf('Selected light: %s', s.light_names{s.current_light});
    setappdata(fig, 's', s);
end

function cb_next_day(fig)
    s = getappdata(fig, 's');
    all_data = evalin('base', 'all_data');
    n_animals = length(all_data);
    n_days = length(all_data(s.animal).data);

    if s.day < n_days
        % go to next day same animal
        new_day = s.day + 1;
        day_items = s.handles.dd_day.Items;
        s.handles.dd_day.Value = day_items{new_day};
        cb_switch_day(fig);
    else
        % on last day, go to next animal first day
        new_animal = mod(s.animal, n_animals) + 1;
        animal_items = s.handles.dd_animal.Items;
        s.handles.dd_animal.Value = animal_items{new_animal};
        cb_switch_animal(fig);
    end
end

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
    has_any_trace = false;
    for i = 1:4
        if ~isempty(s.ttl_traces{i})
            has_any_trace = true;
            break;
        end
    end
    if ~has_any_trace; return; end

    t_now = (frame_idx - 1) / s.info.fps;
    % delete old cursor
    delete(findobj(s.handles.ax_ts, 'Tag', 'ts_cursor'));
    hold(s.handles.ax_ts, 'on');
    yl = ylim(s.handles.ax_ts);
    plot(s.handles.ax_ts, [t_now t_now], yl, 'k-', 'LineWidth', 1.5, 'Tag', 'ts_cursor');
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
    draw_all_rois(s);
    draw_ref_frame(s);
    update_zoom_quadrants(s, frm);
end

function update_zoom_quadrants(s, frm)
    % default center positions for each quadrant (if no light is set)
    % Top: top middle, Left: left middle, Right: right middle, Bottom: bottom middle
    default_centers = {
        [round(s.info.vid_w/2), s.zoom_size],                    % Top
        [s.zoom_size, round(s.info.vid_h/2)],                    % Left
        [s.info.vid_w - s.zoom_size, round(s.info.vid_h/2)],     % Right
        [round(s.info.vid_w/2), s.info.vid_h - s.zoom_size]      % Bottom
    };

    for i = 1:4
        % use light pixel position if set, otherwise use default
        if ~isempty(s.light_pixels{i})
            cx = s.light_pixels{i}(1);
            cy = s.light_pixels{i}(2);
        else
            cx = default_centers{i}(1);
            cy = default_centers{i}(2);
        end

        % calculate crop bounds
        half = s.zoom_size;
        x1 = max(1, cx - half);
        x2 = min(s.info.vid_w, cx + half);
        y1 = max(1, cy - half);
        y2 = min(s.info.vid_h, cy + half);

        % extract crop
        crop = frm(y1:y2, x1:x2, :);

        % update zoom image
        s.handles.im_zoom{i}.CData = crop;
        s.handles.ax_zoom{i}.XLim = [0.5 size(crop,2)+0.5];
        s.handles.ax_zoom{i}.YLim = [0.5 size(crop,1)+0.5];

        % draw crosshair at center if light is set
        delete(findobj(s.handles.ax_zoom{i}, 'Tag', 'zoom_marker'));
        if ~isempty(s.light_pixels{i})
            % position relative to crop
            rel_x = cx - x1 + 1;
            rel_y = cy - y1 + 1;
            hold(s.handles.ax_zoom{i}, 'on');
            plot(s.handles.ax_zoom{i}, rel_x, rel_y, 'r+', 'MarkerSize', 15, 'LineWidth', 2, 'Tag', 'zoom_marker');
            % draw ROI circle
            theta = linspace(0, 2*pi, 50);
            rx = rel_x + s.roi_radius * cos(theta);
            ry = rel_y + s.roi_radius * sin(theta);
            plot(s.handles.ax_zoom{i}, rx, ry, 'r-', 'LineWidth', 1, 'Tag', 'zoom_marker');
            hold(s.handles.ax_zoom{i}, 'off');
        end

        % draw ref point if set
        if ~isempty(s.ref_corners{i})
            rcx = s.ref_corners{i}(1);
            rcy = s.ref_corners{i}(2);
            % check if ref point is in this crop
            if rcx >= x1 && rcx <= x2 && rcy >= y1 && rcy <= y2
                rel_rx = rcx - x1 + 1;
                rel_ry = rcy - y1 + 1;
                hold(s.handles.ax_zoom{i}, 'on');
                plot(s.handles.ax_zoom{i}, rel_rx, rel_ry, 'c+', 'MarkerSize', 10, 'LineWidth', 1, 'Tag', 'zoom_marker');
                hold(s.handles.ax_zoom{i}, 'off');
            end
        end
    end
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

function draw_all_rois(s)
    delete(findobj(s.handles.ax_vid, 'Tag', 'roi_marker'));

    for i = 1:4
        if isempty(s.light_pixels{i}); continue; end

        px = s.light_pixels{i};
        r = s.roi_radius;
        col = s.light_colors{i};

        if s.zoomed
            crop_h = min(200, s.info.vid_h);
            y1 = s.info.vid_h - crop_h + 1;
            dx = px(1);
            dy = px(2) - y1 + 1;
            % skip if outside zoomed view
            if dy < 1 || dy > crop_h || dx < 1 || dx > 200
                continue;
            end
        else
            dx = px(1);
            dy = px(2);
        end

        theta = linspace(0, 2*pi, 50);
        cx = dx + r * cos(theta);
        cy = dy + r * sin(theta);
        hold(s.handles.ax_vid, 'on');
        plot(s.handles.ax_vid, cx, cy, [col '-'], 'LineWidth', 2, 'Tag', 'roi_marker');
        plot(s.handles.ax_vid, dx, dy, [col '+'], 'MarkerSize', 10, 'LineWidth', 2, 'Tag', 'roi_marker');
        text(s.handles.ax_vid, dx + r + 3, dy, s.light_names{i}(1), 'Color', col, 'FontWeight', 'bold', 'Tag', 'roi_marker');
        hold(s.handles.ax_vid, 'off');
    end
end

function draw_ref_frame(s)
    delete(findobj(s.handles.ax_vid, 'Tag', 'ref_frame'));

    % collect valid corners
    valid_corners = [];
    valid_idx = [];
    for i = 1:4
        if ~isempty(s.ref_corners{i})
            if s.zoomed
                crop_h = min(200, s.info.vid_h);
                y1 = s.info.vid_h - crop_h + 1;
                dx = s.ref_corners{i}(1);
                dy = s.ref_corners{i}(2) - y1 + 1;
            else
                dx = s.ref_corners{i}(1);
                dy = s.ref_corners{i}(2);
            end
            valid_corners = [valid_corners; dx, dy];
            valid_idx = [valid_idx; i];
        end
    end

    if isempty(valid_corners); return; end

    hold(s.handles.ax_vid, 'on');

    % draw corner points as small crosshairs
    for j = 1:size(valid_corners, 1)
        plot(s.handles.ax_vid, valid_corners(j,1), valid_corners(j,2), 'c+', ...
            'MarkerSize', 6, 'LineWidth', 1, 'Tag', 'ref_frame');
        text(s.handles.ax_vid, valid_corners(j,1) + 5, valid_corners(j,2), ...
            s.corner_names{valid_idx(j)}, 'Color', 'c', 'FontWeight', 'bold', 'Tag', 'ref_frame');
    end

    hold(s.handles.ax_vid, 'off');
end

function cb_roi(fig, val)
    s = getappdata(fig, 's');
    s.roi_radius = val;
    setappdata(fig, 's', s);
    draw_all_rois(s);
end

function cb_save_roi(fig)
    s = getappdata(fig, 's');

    % count how many lights are set
    n_lights = 0;
    for i = 1:4
        if ~isempty(s.light_pixels{i})
            n_lights = n_lights + 1;
        end
    end

    if n_lights == 0
        s.handles.lbl_status.Text = 'No lights selected! Use P to pick light pixels.';
        return;
    end

    % save ROI params into all_data as ttl_roi2
    all_data = evalin('base', 'all_data');

    roi2 = struct();
    roi2.light_pixels = s.light_pixels;
    roi2.light_names = s.light_names;
    roi2.radius = s.roi_radius;
    roi2.ref_corners = s.ref_corners;

    all_data(s.animal).data(s.day).ttl_roi2 = roi2;
    assignin('base', 'all_data', all_data);

    % build summary
    light_summary = '';
    for i = 1:4
        if ~isempty(s.light_pixels{i})
            light_summary = [light_summary sprintf('%s:[%d,%d] ', s.light_names{i}(1), s.light_pixels{i}(1), s.light_pixels{i}(2))];
        end
    end

    s.handles.lbl_status.Text = sprintf('Saved ttl_roi2 to all_data(%d).data(%d): %s r=%d', ...
        s.animal, s.day, light_summary, s.roi_radius);
    setappdata(fig, 's', s);
end

function cb_load(fig)
    s = getappdata(fig, 's');
    s.handles.lbl_status.Text = 'Loading...';
    drawnow;
    try
        all_data = evalin('base', 'all_data');
        loaded_roi = false;
        loaded_trace = false;

        % try to load ttl_roi2 first (new 4-light format)
        has_roi2 = isfield(all_data(s.animal).data(s.day), 'ttl_roi2') && ~isempty(all_data(s.animal).data(s.day).ttl_roi2);

        if has_roi2
            roi2 = all_data(s.animal).data(s.day).ttl_roi2;
            s.light_pixels = roi2.light_pixels;
            s.roi_radius = roi2.radius;
            if isfield(roi2, 'ref_corners')
                s.ref_corners = roi2.ref_corners;
            end
            loaded_roi = true;
        else
            % fallback to old ttl_roi (single light format)
            has_roi = isfield(all_data(s.animal).data(s.day), 'ttl_roi') && ~isempty(all_data(s.animal).data(s.day).ttl_roi);
            if has_roi
                roi = all_data(s.animal).data(s.day).ttl_roi;
                % put old single ROI in the first slot (Bottom, since old was bottom-left corner)
                s.light_pixels = {[], [], [], roi.pixel};
                s.roi_radius = roi.radius;
                loaded_roi = true;
            end
        end

        draw_all_rois(s);
        draw_ref_frame(s);

        % load traces - try ttl_data2 first (new 4-light format)
        has_trace2 = isfield(all_data(s.animal).data(s.day), 'ttl_data2') && ~isempty(all_data(s.animal).data(s.day).ttl_data2);
        has_trace = isfield(all_data(s.animal).data(s.day), 'ttl_data') && ~isempty(all_data(s.animal).data(s.day).ttl_data);

        cla(s.handles.ax_ts);
        hold(s.handles.ax_ts, 'on');

        if has_trace2
            td2 = all_data(s.animal).data(s.day).ttl_data2;
            s.ttl_traces = td2.ttl_traces;
            s.ttl_time = td2.ttl_time;

            % plot all 4 traces
            for i = 1:4
                if ~isempty(s.ttl_traces{i})
                    plot(s.handles.ax_ts, td2.ttl_time, s.ttl_traces{i}, s.light_colors{i}, 'LineWidth', 0.5);
                end
            end
            loaded_trace = true;
        elseif has_trace
            % fallback to old ttl_data (single trace)
            td = all_data(s.animal).data(s.day).ttl_data;
            s.ttl_traces = {[], [], [], td.ttl_trace}; % put in Bottom slot
            s.ttl_time = td.ttl_time;
            plot(s.handles.ax_ts, td.ttl_time, td.ttl_trace, 'k', 'LineWidth', 0.5);
            loaded_trace = true;
        end

        % plot Valve_ID markers from d_old (start_of_trial only)
        if loaded_trace
            try
                d_old = all_data(s.animal).data(s.day).d_old;
                if istable(d_old) && ismember('time', d_old.Properties.VariableNames) && ...
                   ismember('Valve_ID', d_old.Properties.VariableNames) && ismember('type', d_old.Properties.VariableNames)
                    % filter to start_of_trial only
                    start_mask = strcmp(d_old.type, 'start_of_trial');
                    start_times = d_old.time(start_mask);
                    start_valves = d_old.Valve_ID(start_mask);

                    yl = ylim(s.handles.ax_ts);
                    y_mid = mean(yl);
                    for j = 1:length(start_times)
                        t_valve = start_times(j);
                        valve_id = start_valves(j);
                        % add Valve_ID as text inside plot
                        text(s.handles.ax_ts, t_valve, y_mid+8, sprintf('%d', valve_id), ...
                            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                            'FontSize', 14, 'FontWeight', 'bold', 'Color', 'r');
                    end
                end
            catch
                % d_old not available or wrong format, skip
            end
        end

        hold(s.handles.ax_ts, 'off');
        xlabel(s.handles.ax_ts, 'Time (s)');
        ylabel(s.handles.ax_ts, 'Intensity');
        title(s.handles.ax_ts, 'Light traces');
        update_ts_cursor(s, s.current_frame_idx);

        % count lights
        n_lights = 0;
        for i = 1:4
            if ~isempty(s.light_pixels{i})
                n_lights = n_lights + 1;
            end
        end

        if loaded_roi
            s.handles.lbl_status.Text = sprintf('Loaded %d light(s) from all_data(%d).data(%d)', n_lights, s.animal, s.day);
        else
            s.handles.lbl_status.Text = sprintf('No ROI found in all_data(%d).data(%d). Use P to pick lights.', s.animal, s.day);
        end

        setappdata(fig, 's', s);
    catch ME
        s.handles.lbl_status.Text = sprintf('Error loading: %s', ME.message);
        setappdata(fig, 's', s);
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

    % reset light pixels and corners
    s.light_pixels = {[], [], [], []};
    s.ref_corners = {[], [], [], []};
    s.ttl_traces = {[], [], [], []};
    s.ttl_time = [];

    % turn off modes
    s.pick_mode = false;
    s.refframe_mode = false;
    s.handles.btn_pick.Text = '[E] Pick Light';
    s.handles.btn_pick.BackgroundColor = [0.96 0.96 0.96];
    s.handles.btn_refframe.Text = '[R] Ref Frame';
    s.handles.btn_refframe.BackgroundColor = [0.96 0.96 0.96];
    s.handles.im.ButtonDownFcn = '';

    % update slider
    s.handles.sld.Limits = [1 s.info.n_frames];
    s.handles.sld.Value = 1;

    % update info label
    s.handles.lbl_vid_info.Text = sprintf('%s - %s', all_data(s.animal).name, all_data(s.animal).data(s.day).day_label);

    % show first frame (full view by default)
    s.zoomed = false;
    s.handles.btn_zoom.Text = 'Zoom Corner';
    s.vid.CurrentTime = 0;
    frm = readFrame(s.vid);
    show_frame(s, frm);
    s.handles.ax_vid.Title.String = sprintf('Frame 1 / %d', s.info.n_frames);

    % clear timeseries plot
    cla(s.handles.ax_ts);
    xlabel(s.handles.ax_ts, 'Time (s)');
    ylabel(s.handles.ax_ts, 'Intensity');
    title(s.handles.ax_ts, '4-Light timeseries');

    s.handles.lbl_status.Text = sprintf('Switched to animal %d, day %d. Press P to pick lights or Load.', s.animal, s.day);
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
