% Plot x/y trajectory segments where selected syllable(s) are active
% Requires: all_data from a00_load_data.m pipeline
%           sorted_syllables, cmap25 from a00_process_data.m

if ~exist('all_data', 'var')
    error('f12_plot_syllable_spatial_trajectories requires all_data in the workspace.');
end
if ~exist('sorted_syllables', 'var')
    error('f12_plot_syllable_spatial_trajectories requires sorted_syllables in the workspace.');
end
if ~exist('cmap25', 'var')
    error('f12_plot_syllable_spatial_trajectories requires cmap25 in the workspace.');
end

plot_mode = 'pooled';      % 'per_animal' means per_iterate_over. or 'pooled'
iterate_over = 'animals';      % 'animals' or 'days'
day_filter = 1:5;                % scalar/vector day(s), or NaN for all days
animals = 1:length(all_data);  % animal(s) to include
valve_id = [];                % [] = all valves, otherwise scalar/vector Valve_ID filter
epoch_filter = 'outside_trial'; % 'within_trial', 'outside_trial', 'all_data', or 'final_approach'
reference_angle = false;    % false keeps raw coordinates; true aligns active valve to image-bottom
% syllable_selector = [0 1 2 3 4];         % syllable ID(s), e.g. 2 or [2 14 29]
syllable_selector = [29 22 14 16 20 18];
syllable_selector = [18, 20, 29, 22, 14, 16];
display_mode = 'ratemap';   % 'trajectory' or 'ratemap'
pooled_layout = 'column';   % when plot_mode = 'pooled': 'column' or 'row'
trajectory_line_width = 0.25;   % line width for display_mode = 'trajectory'
trajectory_alpha = 0.25;       % transparency for display_mode = 'trajectory'
trajectory_color_mode = 'syllable'; % 'syllable' or 'progress'
trajectory_progress_cmap = parula(256); % used when trajectory_color_mode = 'progress'
n_spatial_bins = 25;           % number of bins per axis for ratemap mode
ratemap_clim = [0 0.2];       % [] = shared auto clim [0 max], or e.g. [0 1]
ratemap_smooth_sigma_bins = 0.75; % 0 = no smoothing, otherwise Gaussian sigma in bins
skip_animals_days = [0 0];

epoch_filter = f12_normalize_epoch_filter(epoch_filter);
reference_angle = f12_normalize_reference_angle(reference_angle);
pooled_layout = f12_normalize_pooled_layout(pooled_layout);
requested_days = day_filter(isfinite(day_filter));
requested_valves = valve_id(isfinite(valve_id));

if reference_angle && (strcmp(epoch_filter, 'all_data') || strcmp(epoch_filter, 'outside_trial'))
    fprintf('WARNING: reference_angle only supports trial-based epochs; using raw coordinates for epoch_filter=''%s''.\n', epoch_filter);
    reference_angle = false;
end

segments = table();
occupancy = table();

for animal = animals
    if animal < 1 || animal > length(all_data); continue; end

    for day = 1:length(all_data(animal).data)
        if ismember([animal, day], skip_animals_days, 'rows'); continue; end
        if ~isempty(requested_days) && ~ismember(day, requested_days); continue; end

        d = all_data(animal).data(day).d;
        if isempty(d); continue; end
        if ~ismember('syllable', d.Properties.VariableNames); continue; end
        if ~ismember('centroidX', d.Properties.VariableNames) || ~ismember('centroidY', d.Properties.VariableNames)
            continue;
        end
        if reference_angle
            d = f12_require_reference_fields(d, animal, day);
            arena_center = f12_get_arena_center(all_data(animal).data(day), animal, day);
            rotation_mask = isfinite(d.trial_number) & isfinite(d.trial_rotation_deg);
        else
            arena_center = [];
            rotation_mask = true(height(d), 1);
        end

        if strcmp(epoch_filter, 'all_data') && isempty(requested_valves)
            epoch_mask = true(height(d), 1);
        else
            d_old = all_data(animal).data(day).d_old;
            if isempty(d_old); continue; end
            epoch_mask = f12_build_epoch_mask(d, d_old, epoch_filter, requested_valves);
        end

        occupancy_mask = epoch_mask ...
            & rotation_mask ...
            & isfinite(d.centroidX) ...
            & isfinite(d.centroidY);

        if any(occupancy_mask)
            occ_x = d.centroidX(occupancy_mask);
            occ_y = d.centroidY(occupancy_mask);
            if reference_angle
                [occ_x, occ_y] = f12_rotate_xy(occ_x, occ_y, d.trial_rotation_deg(occupancy_mask), arena_center);
            end

            occ = table();
            occ.x = {occ_x};
            occ.y = {occ_y};
            occ.animal = animal;
            occ.day = day;
            occ.n_points = sum(occupancy_mask);
            occupancy = [occupancy; occ];
        end

        valid_mask = epoch_mask ...
            & rotation_mask ...
            & ismember(d.syllable, syllable_selector) ...
            & isfinite(d.centroidX) ...
            & isfinite(d.centroidY);

        if ~any(valid_mask); continue; end

        idx = find(valid_mask);
        run_breaks = [true; diff(idx) > 1 | diff(d.syllable(idx)) ~= 0];
        if reference_angle
            run_breaks = run_breaks | [true; diff(d.trial_number(idx)) ~= 0];
        end
        run_start_pos = find(run_breaks);
        run_end_pos = [run_start_pos(2:end) - 1; length(idx)];

        for i_run = 1:length(run_start_pos)
            this_idx = idx(run_start_pos(i_run):run_end_pos(i_run));
            if isempty(this_idx); continue; end

            seg_x = d.centroidX(this_idx);
            seg_y = d.centroidY(this_idx);
            if reference_angle
                [seg_x, seg_y] = f12_rotate_xy(seg_x, seg_y, d.trial_rotation_deg(this_idx), arena_center);
            end

            seg = table();
            seg.x = {seg_x};
            seg.y = {seg_y};
            seg.syllable = d.syllable(this_idx(1));
            seg.animal = animal;
            seg.day = day;
            seg.n_points = length(this_idx);

            segments = [segments; seg];
        end
    end
end

fprintf('%d total syllable trajectory segments found\n', height(segments));

if height(segments) == 0
    error('No syllable trajectory segments match the current filters.');
end

if strcmp(iterate_over, 'animals')
    iter_vals = animals;
    iter_title_fn = @(v) sprintf('Animal %d', v);
    filter_field = 'animal';
elseif strcmp(iterate_over, 'days')
    if isempty(requested_days)
        iter_vals = unique(segments.day)';
    else
        iter_vals = requested_days;
    end
    iter_title_fn = @(v) sprintf('Day %d', v);
    filter_field = 'day';
else
    error('iterate_over must be ''animals'' or ''days''.');
end

iter_vals = iter_vals(:)';
selected_syllables = unique(syllable_selector(:)', 'stable');
selected_syllables = selected_syllables(~isnan(selected_syllables));
if isempty(selected_syllables)
    error('syllable_selector must contain at least one valid syllable ID.');
end

if isempty(requested_days)
    days_included = unique(segments.day)';
else
    days_included = requested_days;
end

if strcmp(display_mode, 'ratemap') && height(occupancy) > 0
    x_min = min(cellfun(@(x) min(x), occupancy.x));
    x_max = max(cellfun(@(x) max(x), occupancy.x));
    y_min = min(cellfun(@(y) min(y), occupancy.y));
    y_max = max(cellfun(@(y) max(y), occupancy.y));
else
    x_min = min(cellfun(@(x) min(x), segments.x));
    x_max = max(cellfun(@(x) max(x), segments.x));
    y_min = min(cellfun(@(y) min(y), segments.y));
    y_max = max(cellfun(@(y) max(y), segments.y));
end

x_pad = max(1, 0.02 * max(x_max - x_min, 1));
y_pad = max(1, 0.02 * max(y_max - y_min, 1));
x_limits = [x_min - x_pad, x_max + x_pad];
y_limits = [y_min - y_pad, y_max + y_pad];
x_edges = linspace(x_limits(1), x_limits(2), n_spatial_bins + 1);
y_edges = linspace(y_limits(1), y_limits(2), n_spatial_bins + 1);
x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
y_centers = (y_edges(1:end-1) + y_edges(2:end)) / 2;

syllable_str = strjoin(string(selected_syllables), ', ');
epoch_title = f12_epoch_title(epoch_filter);
valve_title = f12_valve_title(requested_valves);
display_title = f12_display_title(display_mode);
alignment_title = f12_alignment_title(reference_angle);
n_rows = length(selected_syllables);
shared_ratemap_clim = [];

if strcmp(display_mode, 'ratemap')
    max_count = 0;
    for i_syl = 1:n_rows
        syl_id = selected_syllables(i_syl);

        if strcmp(plot_mode, 'per_animal')
            for i_iter = 1:length(iter_vals)
                iter_val = iter_vals(i_iter);
                this_segments = segments(segments.(filter_field) == iter_val & segments.syllable == syl_id, :);
                this_occupancy = occupancy(occupancy.(filter_field) == iter_val, :);
                map_counts = f12_make_ratemap(this_segments, this_occupancy, x_edges, y_edges, ratemap_smooth_sigma_bins);
                max_count = max(max_count, max(map_counts(:)));
            end
        else
            this_segments = segments(segments.syllable == syl_id, :);
            map_counts = f12_make_ratemap(this_segments, occupancy, x_edges, y_edges, ratemap_smooth_sigma_bins);
            max_count = max(max_count, max(map_counts(:)));
        end
    end

    if isempty(ratemap_clim)
        shared_ratemap_clim = [0 max(max_count, 1)];
    else
        shared_ratemap_clim = ratemap_clim;
    end
end

if strcmp(plot_mode, 'per_animal')
    n_iter = length(iter_vals);
    [fig, tl] = myFigure(n_rows, n_iter, 420, 420, true);
    title(tl, sprintf('Syllable %s [%s] | %s | %s\nAnimals: %s | Days: %s | Valves: %s', ...
        display_title, syllable_str, epoch_title, ...
        alignment_title, ...
        f12_num_list_str(animals), f12_num_list_str(days_included), valve_title));
    last_ax = [];

    for i_syl = 1:n_rows
        syl_id = selected_syllables(i_syl);
        syl_color = f12_get_syllable_color(syl_id, sorted_syllables, cmap25);

        for i_iter = 1:n_iter
            iter_val = iter_vals(i_iter);
            this_segments = segments(segments.(filter_field) == iter_val & segments.syllable == syl_id, :);
            this_occupancy = occupancy(occupancy.(filter_field) == iter_val, :);

            ax = nexttile(tl);
            hold(ax, 'on');
            last_ax = ax;

            if strcmp(display_mode, 'trajectory')
                for i_seg = 1:height(this_segments)
                    x = this_segments.x{i_seg};
                    y = this_segments.y{i_seg};
                    f12_plot_trajectory(ax, x, y, syl_color, trajectory_line_width, ...
                        trajectory_alpha, trajectory_color_mode, trajectory_progress_cmap);
                end
            elseif strcmp(display_mode, 'ratemap')
                map_counts = f12_make_ratemap(this_segments, this_occupancy, x_edges, y_edges, ratemap_smooth_sigma_bins);
                imagesc(ax, x_centers, y_centers, map_counts);
                set(ax, 'YDir', 'normal');
                colormap(ax, turbo(256));
                caxis(ax, shared_ratemap_clim);
            else
                error('display_mode must be ''trajectory'' or ''ratemap''.');
            end

            xlim(ax, x_limits);
            ylim(ax, y_limits);
            axis(ax, 'square');
            xlabel(ax, 'X');
            ylabel(ax, 'Y');

            title_parts = {sprintf('%s', iter_title_fn(iter_val)), sprintf('Syl %d', syl_id), sprintf('n=%d', height(this_segments))};
            title(ax, strjoin(title_parts, ' | '));
        end
    end

    if strcmp(display_mode, 'ratemap') && ~isempty(last_ax)
        cb = colorbar(last_ax, 'eastoutside');
        ylabel(cb, 'P(syllable | position)');
    end

elseif strcmp(plot_mode, 'pooled')
    if strcmp(pooled_layout, 'row')
        pooled_n_rows = 1;
        pooled_n_cols = n_rows;
    else
        pooled_n_rows = n_rows;
        pooled_n_cols = 1;
    end

    [fig, tl] = myFigure(pooled_n_rows, pooled_n_cols, 650, 650, true);
    title(tl, sprintf('Syllable %s [%s] | %s | %s | pooled\nAnimals: %s | Days: %s | Valves: %s', ...
        display_title, syllable_str, epoch_title, ...
        alignment_title, ...
        f12_num_list_str(animals), f12_num_list_str(days_included), valve_title));
    last_ax = [];

    for i_syl = 1:n_rows
        syl_id = selected_syllables(i_syl);
        syl_color = f12_get_syllable_color(syl_id, sorted_syllables, cmap25);
        this_segments = segments(segments.syllable == syl_id, :);

        ax = nexttile(tl);
        hold(ax, 'on');
        last_ax = ax;

        if strcmp(display_mode, 'trajectory')
            for i_seg = 1:height(this_segments)
                x = this_segments.x{i_seg};
                y = this_segments.y{i_seg};
                f12_plot_trajectory(ax, x, y, syl_color, trajectory_line_width, ...
                    trajectory_alpha, trajectory_color_mode, trajectory_progress_cmap);
            end
        elseif strcmp(display_mode, 'ratemap')
            map_counts = f12_make_ratemap(this_segments, occupancy, x_edges, y_edges, ratemap_smooth_sigma_bins);
            imagesc(ax, x_centers, y_centers, map_counts);
            set(ax, 'YDir', 'normal');
            colormap(ax, turbo(256));
            caxis(ax, shared_ratemap_clim);
        else
            error('display_mode must be ''trajectory'' or ''ratemap''.');
        end

        xlim(ax, x_limits);
        ylim(ax, y_limits);
        axis(ax, 'square');
        xlabel(ax, 'X');
        ylabel(ax, 'Y');
        title(ax, sprintf('Pooled | Syl %d | n=%d', syl_id, height(this_segments)));
    end

    if strcmp(display_mode, 'ratemap') && ~isempty(last_ax)
        cb = colorbar(last_ax, 'eastoutside');
        ylabel(cb, 'P(syllable | position)');
    end

else
    error('plot_mode must be ''per_animal'' or ''pooled''.');
end

function epoch_mask = f12_build_epoch_mask(d, d_old, epoch_filter, valve_filter)
    if nargin < 4
        valve_filter = [];
    end

    start_mask = strcmp(d_old.type, 'start_of_trial');
    end_mask = strcmp(d_old.type, 'end_of_trial');
    fa_mask = strcmp(d_old.type, 'final_approach_start');

    start_times = d_old.time(start_mask);
    epoch_mask = false(height(d), 1);

    if isempty(start_times)
        if strcmp(epoch_filter, 'outside_trial')
            epoch_mask = true(height(d), 1);
        end
        return;
    end

    if ~isempty(valve_filter)
        if ~ismember('Valve_ID', d_old.Properties.VariableNames)
            error('Valve filter requested, but d_old does not contain Valve_ID.');
        end
        start_valves = d_old.Valve_ID(start_mask);
    else
        start_valves = [];
    end

    end_times = d_old.time(end_mask);
    fa_times = d_old.time(fa_mask);

    for i_start = 1:length(start_times)
        if ~isempty(valve_filter) && ~ismember(start_valves(i_start), valve_filter)
            continue;
        end

        t_trial_start = start_times(i_start);
        t_end_idx = find(end_times > t_trial_start, 1);
        if isempty(t_end_idx); continue; end
        t_end = end_times(t_end_idx);

        switch epoch_filter
            case {'all_data', 'trial', 'outside_trial'}
                t_start = t_trial_start;
            case 'final_approach'
                fa_idx = find(fa_times > t_trial_start & fa_times < t_end, 1);
                if isempty(fa_idx); continue; end
                t_start = fa_times(fa_idx);
            otherwise
                error('Unknown epoch_filter: %s', epoch_filter);
        end

        epoch_mask = epoch_mask | (d.time >= t_start & d.time <= t_end);
    end

    if strcmp(epoch_filter, 'outside_trial')
        epoch_mask = ~epoch_mask;
    end
end

function epoch_filter = f12_normalize_epoch_filter(epoch_filter)
    if strcmp(epoch_filter, 'within_trial') || strcmp(epoch_filter, 'within_tiral')
        epoch_filter = 'trial';
    end
end

function reference_angle = f12_normalize_reference_angle(reference_angle)
    if islogical(reference_angle)
        reference_angle = logical(reference_angle);
        return;
    end

    if isnumeric(reference_angle)
        reference_angle = logical(reference_angle);
        return;
    end

    if ischar(reference_angle) || (isstring(reference_angle) && isscalar(reference_angle))
        reference_angle = char(string(reference_angle));
        if strcmpi(reference_angle, 'true')
            reference_angle = true;
            return;
        end
        if strcmpi(reference_angle, 'false')
            reference_angle = false;
            return;
        end
    end

    error('reference_angle must be true/false or ''true''/''false''.');
end

function pooled_layout = f12_normalize_pooled_layout(pooled_layout)
    if ~strcmp(pooled_layout, 'column') && ~strcmp(pooled_layout, 'row')
        error('pooled_layout must be ''column'' or ''row''.');
    end
end

function title_str = f12_epoch_title(epoch_filter)
    switch epoch_filter
        case 'all_data'
            title_str = 'All Data';
        case 'trial'
            title_str = 'Within-Trial';
        case 'outside_trial'
            title_str = 'Outside-Trial';
        case 'final_approach'
            title_str = 'Final Approach';
        otherwise
            title_str = epoch_filter;
    end
end

function title_str = f12_valve_title(valve_filter)
    if isempty(valve_filter)
        title_str = 'all';
    else
        title_str = strjoin(string(valve_filter(:)'), ', ');
    end
end

function title_str = f12_display_title(display_mode)
    switch display_mode
        case 'trajectory'
            title_str = 'trajectories';
        case 'ratemap'
            title_str = 'occupancy-normalized ratemaps';
        otherwise
            title_str = display_mode;
    end
end

function title_str = f12_alignment_title(reference_angle)
    if reference_angle
        title_str = 'valve-aligned';
    else
        title_str = 'raw arena';
    end
end

function d = f12_require_reference_fields(d, animal, day)
    required_fields = {'trial_number', 'trial_valve_id', 'trial_light_idx', ...
        'trial_nearest_end_light_idx', 'trial_valve_match_ok', 'trial_rotation_deg'};
    missing_fields = required_fields(~ismember(required_fields, d.Properties.VariableNames));
    if ~isempty(missing_fields)
        error('A%d D%d is missing reference-angle fields in d: %s. Re-run a00_process_data.m.', ...
            animal, day, strjoin(missing_fields, ', '));
    end
end

function arena_center = f12_get_arena_center(day_data, animal, day)
    if ~isfield(day_data, 'ttl_roi2') || isempty(day_data.ttl_roi2) || ~isfield(day_data.ttl_roi2, 'light_pixels')
        error('A%d D%d is missing ttl_roi2.light_pixels required for reference_angle.', animal, day);
    end

    light_pixels = day_data.ttl_roi2.light_pixels;
    valid_light_mask = cellfun(@(px) isnumeric(px) && numel(px) >= 2, light_pixels);
    if ~any(valid_light_mask)
        error('A%d D%d has no valid ttl_roi2.light_pixels for reference_angle.', animal, day);
    end

    light_pos_mat = cell2mat(cellfun(@(px) double(px(1:2)), light_pixels(valid_light_mask), 'UniformOutput', false)');
    arena_center = mean(light_pos_mat, 1);
end

function [x_rot, y_rot] = f12_rotate_xy(x, y, theta_deg, arena_center)
    x_shift = x(:) - arena_center(1);
    y_shift = y(:) - arena_center(2);
    theta_deg = theta_deg(:);

    x_rot = arena_center(1) + x_shift .* cosd(theta_deg) - y_shift .* sind(theta_deg);
    y_rot = arena_center(2) + x_shift .* sind(theta_deg) + y_shift .* cosd(theta_deg);
end

function color = f12_get_syllable_color(syllable_id, sorted_syllables, cmap25)
    idx = find(sorted_syllables == syllable_id, 1);
    if ~isempty(idx) && idx <= size(cmap25, 1)
        color = cmap25(idx, :);
    else
        color = [0.5 0.5 0.5];
    end
end

function f12_plot_trajectory(ax, x, y, syl_color, line_width, alpha_value, color_mode, progress_cmap)
    if isempty(x) || isempty(y) || length(x) ~= length(y)
        return;
    end

    if strcmp(color_mode, 'syllable')
        if length(x) > 1
            h = plot(ax, x, y, 'Color', syl_color, 'LineWidth', line_width);
            h.Color(4) = alpha_value;
        else
            h = plot(ax, x, y, '.', 'Color', syl_color, 'MarkerSize', 10);
            h.Color(4) = alpha_value;
        end
        return;
    end

    if ~strcmp(color_mode, 'progress')
        error('trajectory_color_mode must be ''syllable'' or ''progress''.');
    end

    colormap(ax, progress_cmap);
    caxis(ax, [0 1]);

    if length(x) == 1
        point_color = progress_cmap(end, :);
        h = plot(ax, x, y, '.', 'Color', point_color, 'MarkerSize', 10);
        h.Color(4) = alpha_value;
        return;
    end

    progress_vals = linspace(0, 1, length(x));
    surface(ax, [x(:)'; x(:)'], [y(:)'; y(:)'], zeros(2, length(x)), ...
        [progress_vals; progress_vals], ...
        'FaceColor', 'none', ...
        'EdgeColor', 'interp', ...
        'LineWidth', line_width, ...
        'EdgeAlpha', alpha_value);
end

function map_counts = f12_make_ratemap(this_segments, this_occupancy, x_edges, y_edges, smooth_sigma_bins)
    map_counts = zeros(length(y_edges) - 1, length(x_edges) - 1);

    if height(this_occupancy) == 0
        return;
    end

    occ_x = vertcat(this_occupancy.x{:});
    occ_y = vertcat(this_occupancy.y{:});
    occupancy_counts = histcounts2(occ_y, occ_x, y_edges, x_edges);

    if height(this_segments) == 0
        return;
    end

    all_x = vertcat(this_segments.x{:});
    all_y = vertcat(this_segments.y{:});
    syllable_counts = histcounts2(all_y, all_x, y_edges, x_edges);

    if smooth_sigma_bins > 0
        kernel = f12_gaussian_kernel(smooth_sigma_bins);
        occupancy_counts = conv2(occupancy_counts, kernel, 'same');
        syllable_counts = conv2(syllable_counts, kernel, 'same');
    end

    valid_bins = occupancy_counts > 0;
    map_counts(valid_bins) = syllable_counts(valid_bins) ./ occupancy_counts(valid_bins);
end

function kernel = f12_gaussian_kernel(sigma)
    kernel_radius = max(1, ceil(3 * sigma));
    x = -kernel_radius:kernel_radius;
    g = exp(-(x .^ 2) / (2 * sigma ^ 2));
    g = g / sum(g);
    kernel = g' * g;
    kernel = kernel / sum(kernel(:));
end

function str = f12_num_list_str(vals)
    vals = vals(:)';
    if isempty(vals)
        str = 'all';
        return;
    end
    str = strjoin(string(vals), ', ');
end
