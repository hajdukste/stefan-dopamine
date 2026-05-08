% a10_preproc_fip.m - preprocess fiber photometry: lowpass + exponential bleaching correction

lp_cutoff = 10; % Hz

animals = 1:6;
days = 1:6;

if exist('loading_split_video', 'var') && loading_split_video
    animals = 1;
    days = 1:2;
end

% count valid sessions
n_total = 0;
for animal = animals
    for day = days
        if ~isempty(all_data(animal).data(day).fip)
            n_total = n_total + 1;
        end
    end
end

% process all
results = cell(n_total, 1);
labels = cell(n_total, 1);
idx = 0;
for animal = animals
    for day = days
        if isempty(all_data(animal).data(day).fip); continue; end
        idx = idx + 1;
        fprintf('Processing %s day %d\n', all_data(animal).name, day);
        results{idx} = preproc_fip_clean(all_data(animal).data(day).fip, lp_cutoff);
        labels{idx} = sprintf('%s d%d', all_data(animal).name, day);
        all_data(animal).data(day).fip.signal_corr_wo_norm = results{idx}.corrected;

        % normalize ignoring first 0.5s
        t = results{idx}.time;
        skip_idx = find(t >= 0.5, 1, 'first');
        sig = results{idx}.corrected;
        mu = mean(sig(skip_idx:end));
        sd = std(sig(skip_idx:end));
        all_data(animal).data(day).fip.signal_corr = (sig - mu) / sd;
    end
end

% figure 1: raw signal + exponential fit
[fig1, tl1] = myFigure(length(animals), length(days), 400, 200, true);
title(tl1, 'Raw signal + exponential fit');
for i = 1:n_total
    ax = nexttile(tl1);
    hold(ax, 'on');
    plot(ax, results{i}.time, results{i}.raw, 'k', 'LineWidth', 0.5);
    plot(ax, results{i}.time, results{i}.exp_fit, 'r', 'LineWidth', 1);
    title(ax, labels{i});
    xlabel(ax, 'time (s)');
    if i == 1; legend(ax, 'raw', 'exp2 fit', 'Location', 'best'); end
end

%
% figure 2: corrected signal from all_data
[fig2, tl2] = myFigure(length(animals), length(days), 400, 200, true);
title(tl2, 'Corrected signal');
for animal = animals
    for day = days
        fip = all_data(animal).data(day).fip;
        if isempty(fip); continue; end
        ax = nexttile(tl2);
        plot(ax, fip.time, fip.signal_corr, 'k', 'LineWidth', 0.5);
        title(ax, sprintf('%s d%d', all_data(animal).name, day));
        xlabel(ax, 'time (s)');
    end
end
