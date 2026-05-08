
% downsample fip to video frame rate
% requires: a02_sync_video_ttl.m saved sync mapping in all_data
% produces: fip2 table with one row per video frame

animals = 1:6;
days = 1:5;
do_plot = 0;

for animal = animals
for day = days
disp(sprintf('Processing A%d D%d', animal, day));
if (animal == 1 && day == 3); continue; end

% video frame times mapped to fip clock
video_frame_times = all_data(animal).data(day).sync.video_time_mapped(:);

% fip data
fip = all_data(animal).data(day).fip;
fip_time = fip.time;
fip_signal = fip.signal;
fip_reference = fip.reference;
fip_signal_artcorr = fip.signal_artcorr;
fip_signal_corr_wo_norm = fip.signal_corr_wo_norm;
fip_signal_corr = fip.signal_corr;

% check if video starts before fip
fip_start = fip_time(1);
fip_end = fip_time(end);
n_before = sum(video_frame_times < fip_start);
n_after = sum(video_frame_times > fip_end);

if n_before > 0
    fprintf('Warning: %d video frames (%.2f s) start before fip recording\n', ...
        n_before, fip_start - video_frame_times(1));
end
if n_after > 0
    fprintf('Warning: %d video frames (%.2f s) extend past fip recording\n', ...
        n_after, video_frame_times(end) - fip_end);
end

% interpolate fip signals to video frame times
% frames outside fip range get NaN (extrapolation disabled)
fip2_signal = interp1(fip_time, fip_signal, video_frame_times, 'linear', NaN);
fip2_time = interp1(fip_time, fip_time, video_frame_times, 'linear', NaN);
fip2_reference = interp1(fip_time, fip_reference, video_frame_times, 'linear', NaN);
fip2_signal_artcorr = interp1(fip_time, fip_signal_artcorr, video_frame_times, 'linear', NaN);
fip2_signal_corr_wo_norm = interp1(fip_time, fip_signal_corr_wo_norm, video_frame_times, 'linear', NaN);
fip2_signal_corr = interp1(fip_time, fip_signal_corr, video_frame_times, 'linear', NaN);

fip2 = table(video_frame_times, fip2_time, fip2_signal, fip2_reference, ...
    fip2_signal_artcorr, fip2_signal_corr_wo_norm, fip2_signal_corr, ...
    'VariableNames', {'video_time', 'time', 'signal', 'reference', ...
    'signal_artcorr', 'signal_corr_wo_norm', 'signal_corr'});

% save fip2 as first field in all_data.data
if ~isfield(all_data(animal).data, 'fip2')
    [all_data(animal).data.fip2] = deal([]);
end
all_data(animal).data(day).fip2 = fip2;
% reorder so fip2 is first
for ia = 1:length(all_data)
    flds = fieldnames(all_data(ia).data);
    if ismember('fip2', flds)
        new_order = [{'fip2'}; flds(~strcmp(flds, 'fip2'))];
        all_data(ia).data = orderfields(all_data(ia).data, new_order);
    end
end

fprintf('fip2: %d rows (1 per video frame), %d with data, %d NaN\n', ...
    height(fip2), sum(~isnan(fip2.signal)), sum(isnan(fip2.signal)));

if do_plot
% plot downsampling verification
valid = ~isnan(fip2.signal);

[fig, tl] = myFigure(3, 1, 2200, 300, true);
title(tl, sprintf('Downsampling: FIP %.0f Hz -> video %.0f Hz', ...
    1/median(diff(fip_time)), 1/median(diff(video_frame_times))));

ax1 = nexttile(tl);
plot(ax1, fip_time, fip_signal, 'k', 'LineWidth', 0.5);
ylabel(ax1, 'signal');
title(ax1, sprintf('Original FIP (%d samples)', length(fip_signal)));

ax2 = nexttile(tl);
plot(ax2, fip2.time(valid), fip2.signal(valid), 'k', 'LineWidth', 0.5);
ylabel(ax2, 'signal');
title(ax2, sprintf('Downsampled to video frames (%d samples, %d NaN)', sum(valid), sum(~valid)));

ax3 = nexttile(tl);
resid = fip2.signal(valid) - interp1(fip_time, fip_signal, fip2.time(valid), 'nearest');
plot(ax3, fip2.time(valid), resid, 'k', 'LineWidth', 0.5);
ylabel(ax3, 'linear - nearest');
xlabel(ax3, 'time (s)');
title(ax3, sprintf('Interpolation difference (std = %.4f)', std(resid)));

linkaxes([ax1 ax2], 'x');

% plot time mapping
sync = all_data(animal).data(day).sync;
[fig2, tl2] = myFigure(2, 1, 1200, 350, true);
title(tl2, sprintf('Time mapping: fip = %.6f * video + %.4f', sync.a, sync.b));

ax4 = nexttile(tl2);
plot(ax4, video_frame_times, video_frame_times, 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
hold(ax4, 'on');
plot(ax4, video_frame_times, fip2.video_time, 'k', 'LineWidth', 1);
xlabel(ax4, 'video time (s)');
ylabel(ax4, 'mapped fip time (s)');
legend(ax4, 'identity', 'mapped', 'Location', 'best');
title(ax4, 'Video time -> FIP time');

ax5 = nexttile(tl2);
offset = video_frame_times - fip2.video_time;
plot(ax5, video_frame_times, offset * 1000, 'k', 'LineWidth', 1);
xlabel(ax5, 'video time (s)');
ylabel(ax5, 'offset (ms)');
title(ax5, sprintf('Time offset (video - mapped), range %.1f ms', range(offset)*1000));
end

end
end
