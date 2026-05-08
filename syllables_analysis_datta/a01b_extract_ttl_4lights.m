



for animal = 1:length(all_data)
    for day = 1:length(all_data(animal).data)

        % check if ROI params exist (ttl_roi2 for 4-light format)
        if ~isfield(all_data(animal).data(day), 'ttl_roi2') || isempty(all_data(animal).data(day).ttl_roi2)
            fprintf('No ttl_roi2 saved for animal %d, day %d. Skipping.\n', animal, day);
            continue;
        end

        roi2 = all_data(animal).data(day).ttl_roi2;
        light_pixels = roi2.light_pixels;
        light_names = roi2.light_names;
        r = roi2.radius;
        video_path = all_data(animal).data(day).mp4_path;

        % replace in video_path: /Users/stefan/Downloads/ by /Volumes/Stefan SSD/
        % video_path = strrep(video_path, '/Users/stefan/Downloads/', '/Volumes/Stefan SSD/');

        % count how many lights are defined
        n_lights_defined = 0;
        for i = 1:4
            if ~isempty(light_pixels{i})
                n_lights_defined = n_lights_defined + 1;
            end
        end

        if n_lights_defined == 0
            fprintf('No lights defined for animal %d, day %d. Skipping.\n', animal, day);
            continue;
        end

        fprintf('Extracting TTL (4-light) from %s\n', video_path);
        fprintf('Lights defined: %d, radius: %d\n', n_lights_defined, r);
        for i = 1:4
            if ~isempty(light_pixels{i})
                fprintf('  %s: [%d, %d]\n', light_names{i}, light_pixels{i}(1), light_pixels{i}(2));
            end
        end

        vid = VideoReader(video_path);
        n_frames = floor(vid.Duration * vid.FrameRate);
        fps = vid.FrameRate;

        % build circular mask template
        [xx, yy] = meshgrid(-r:r, -r:r);
        mask_template = (xx.^2 + yy.^2) <= r^2;

        % prepare masks and ranges for each light
        masks = cell(1, 4);
        y_ranges = cell(1, 4);
        x_ranges = cell(1, 4);

        for i = 1:4
            if isempty(light_pixels{i})
                continue;
            end
            px = light_pixels{i};
            y_range = (px(2)-r):(px(2)+r);
            x_range = (px(1)-r):(px(1)+r);
            valid_y = y_range >= 1 & y_range <= vid.Height;
            valid_x = x_range >= 1 & x_range <= vid.Width;
            masks{i} = mask_template(valid_y, valid_x);
            y_ranges{i} = y_range(valid_y);
            x_ranges{i} = x_range(valid_x);
        end

        % check if grayscale
        frm = readFrame(vid);
        is_gray = isequal(frm(:,:,1), frm(:,:,2)) && isequal(frm(:,:,1), frm(:,:,3));
        fprintf('Grayscale: %d\n', is_gray);
        vid.CurrentTime = 0;

        % extract all 4 traces
        ttl_traces = zeros(n_frames, 4);
        tic;
        for f = 1:n_frames
            frm = readFrame(vid);
            if is_gray
                gray_frm = double(frm(:,:,1));
            else
                gray_frm = double(rgb2gray(frm));
            end

            for i = 1:4
                if isempty(light_pixels{i})
                    continue;
                end
                patch = gray_frm(y_ranges{i}, x_ranges{i});
                ttl_traces(f, i) = mean(patch(masks{i}));
            end

            if mod(f, 5000) == 0
                elapsed = toc;
                eta = elapsed / f * (n_frames - f);
                fprintf('  %d / %d (%.0f%s) - ETA: %.0fs\n', f, n_frames, 100*f/n_frames, char(37), eta);
            end
        end
        elapsed = toc;
        fprintf('Done in %.1fs\n', elapsed);

        ttl_time = ((1:n_frames)' - 1) / fps;

        % save into all_data as ttl_data2
        ttl_data2 = struct();
        ttl_data2.ttl_traces = ttl_traces;
        ttl_data2.ttl_time = ttl_time;
        ttl_data2.light_pixels = light_pixels;
        ttl_data2.light_names = light_names;
        ttl_data2.ttl_roi_radius = r;

        all_data(animal).data(day).ttl_data2 = ttl_data2;

        % also save to workspace for convenience
        assignin('base', 'ttl_traces', ttl_traces);
        assignin('base', 'ttl_time', ttl_time);

        fprintf('Saved to all_data(%d).data(%d).ttl_data2\n', animal, day);

    end
end
