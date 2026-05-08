function fig = a01x_single_traces_universal_new(events, start_idx, end_idx, idx2, idx3, ylim_sero, i_start, t_line, t_line2, num_rows, num_col, random, mov_mean_window, mean_sero, sem_per_animal)

fig = figure;
% fig.Position = [192          96        2129        1061];
fig.Position = [192          96        1120        1061];
set(gcf,'color','w');
tiledlayout(num_rows, num_col)

max_events = min(num_rows*num_col, length(events) - (i_start - 1));



minYRight = Inf;
maxYRight = -Inf;

randomNumbers = randperm(length(events), max_events);
if sem_per_animal == 1
    randomNumbers = 1:length(events);
end

for i_event = 1:max_events
    if random > 0
        thisStruct = events{randomNumbers(i_event)};
    else
        thisStruct = events{i_event + i_start - 1};
    end
    subset_name = 'subset';
    subset = thisStruct.(subset_name);
    time = (0:1/30:(length(subset(:, 2))-1)/30)';



    nexttile
    hold on;

    % title(['An: ' num2str(thisStruct.animal) ', d: ' num2str(thisStruct.day) ', time: ' char(thisStruct.time), ', tcam: ' num2str(thisStruct.tcam)])
    if sem_per_animal
        title(['An: ' num2str(thisStruct.animal) ', n = ' num2str(thisStruct.n_per_animal)])
    end

    yyaxis left
    ax = gca;
    ax.LineStyleOrder = {'-'};
    if mov_mean_window(1) > 0
        p = plot(time, movmean(subset(:, 2), mov_mean_window(1)));
    else
        p = plot(time, subset(:, 2));
    end
    ylim(ylim_sero)
    if idx3 > 0 && idx3 ~= 8
        [~, color] = getCurrentColorMap(idx3);
        if mov_mean_window(3) > 0
            plot(time, movmean(subset(:, idx3), mov_mean_window(3)), 'Color', color);
        else
            plot(time, subset(:, idx3), 'Color', color);
        end
    end


    plot(time, mean_sero, 'LineStyle', '--', 'Color', p.Color)

    % if t_line < 0
    %     line([length(subset(:, 1))+t_line, length(subset(:, 1))+t_line], [-20, 20], 'Color', 'k', 'LineStyle', '--');
    % end

    yyaxis right
    ax = gca;
    ax.LineStyleOrder = {'-'};
    if mov_mean_window(2) > 0
        p = plot(time, movmean(subset(:, idx2), mov_mean_window(2)));
    else
        p = plot(time, subset(:, idx2));
    end
    if idx3 > 0  && idx3 == 8
        [~, color] = getCurrentColorMap(idx3);
        if mov_mean_window(3) > 0
            p = plot(time, movmean(subset(:, idx3), mov_mean_window(3)), 'Color', color);
        else
            p = plot(time, subset(:, idx3), 'Color', color);
        end
    end

    currentYLim = get(gca, 'YLim');
    minYRight = min(minYRight, currentYLim(1));
    maxYRight = max(maxYRight, currentYLim(2));

    if start_idx > 0
        xlim([start_idx end_idx])
    end
end

for i_event = 1:max_events
    nexttile(i_event)
    xlabel('Time [s]')
    yyaxis right;
    ylim([minYRight maxYRight]);
    ylima = [minYRight maxYRight];
    if(t_line > 0)
        line([t_line, t_line], ylima, 'Color', 'k', 'LineStyle', '--');
    end
    if(t_line2 > 0)
        line([t_line, t_line], ylima, 'Color', 'k', 'LineStyle', '--');
    end
end