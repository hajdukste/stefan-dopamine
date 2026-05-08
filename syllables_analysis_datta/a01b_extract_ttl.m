



for animal = 1:length(all_data)
    for day = 5

        % check if ROI params exist
        if ~isfield(all_data(animal).data(day), 'ttl_roi') || isempty(all_data(animal).data(day).ttl_roi)
            error('No ttl_roi saved for animal %d, day %d. Run a01_find_ttl_video first.', animal, day);
        end

        roi = all_data(animal).data(day).ttl_roi;
        px = roi.pixel;
        r = roi.radius;
        video_path = all_data(animal).data(day).mp4_path;

        % replace in video_path: /Users/stefan/Downloads/ by /Volumes/Stefan SSD/
        % video_path = strrep(video_path, '/Users/stefan/Downloads/', '/Volumes/Stefan SSD/');

        fprintf('Extracting TTL from %s\n', video_path);
        fprintf('Pixel: [%d, %d], radius: %d\n', px(1), px(2), r);

        % circular mask
        [xx, yy] = meshgrid(-r:r, -r:r);
        mask = (xx.^2 + yy.^2) <= r^2;

        vid = VideoReader(video_path);
        n_frames = floor(vid.Duration * vid.FrameRate);
        fps = vid.FrameRate;

        y_range = (px(2)-r):(px(2)+r);
        x_range = (px(1)-r):(px(1)+r);
        valid_y = y_range >= 1 & y_range <= vid.Height;
        valid_x = x_range >= 1 & x_range <= vid.Width;
        mask = mask(valid_y, valid_x);
        y_range = y_range(valid_y);
        x_range = x_range(valid_x);

        % check if grayscale
        frm = readFrame(vid);
        is_gray = isequal(frm(:,:,1), frm(:,:,2)) && isequal(frm(:,:,1), frm(:,:,3));
        fprintf('Grayscale: %d\n', is_gray);
        vid.CurrentTime = 0;

        % extract
        ttl_trace = zeros(n_frames, 1);
        tic;
        for f = 1:n_frames
            frm = readFrame(vid);
            if is_gray
                patch = double(frm(y_range, x_range, 1));
            else
                patch = double(rgb2gray(frm(y_range, x_range, :)));
            end
            ttl_trace(f) = mean(patch(mask));
            if mod(f, 5000) == 0
                elapsed = toc;
                eta = elapsed / f * (n_frames - f);
                fprintf('  %d / %d (%.0f%s) - ETA: %.0fs\n', f, n_frames, 100*f/n_frames, char(37), eta);
            end
        end
        elapsed = toc;
        fprintf('Done in %.1fs\n', elapsed);

        ttl_time = ((1:n_frames)' - 1) / fps;

        % save into all_data
        ttl_data = struct('ttl_trace', ttl_trace, 'ttl_time', ttl_time, 'ttl_pixel', px, 'ttl_roi_radius', r);
        all_data(animal).data(day).ttl_data = ttl_data;

        % also save to workspace for convenience
        assignin('base', 'ttl_trace', ttl_trace);
        assignin('base', 'ttl_time', ttl_time);

        fprintf('Saved to all_data(%d).data(%d).ttl_data\n', animal, day);

    end
end