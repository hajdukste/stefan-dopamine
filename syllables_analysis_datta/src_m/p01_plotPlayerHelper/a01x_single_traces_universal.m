% TODO
% Do similar as moving_window from the main code?

function fig = a01x_single_traces_universal(events, start_idx, end_idx, index_of_touple, i_start, t_line, plotPredSero, num_rows, num_col, facemotion_bool)

fig = figure;
% fig.Position = [192          96        2129        1061];
fig.Position = [192          96        1120        1061];
set(gcf,'color','w');

max_events = min(num_rows*num_col, length(events) - (i_start - 1));

ci_sero = [];

for i_event = 1:max_events
    thisStruct = events{i_event + i_start - 1};
    subset_name = 'subset';
    subset = thisStruct.(subset_name);
    ci_sero = [ci_sero subset(:, 2)];
end
[~, mean_sero] = ci95_photoM(ci_sero);


minYRight = Inf;
maxYRight = -Inf;
for i_event = 1:max_events
    thisStruct = events{i_event + i_start - 1};
    subset_name = 'subset';
    subset = thisStruct.(subset_name);

    subplot(num_rows, num_col, i_event)
    hold on;

    % title(['An: ' num2str(thisStruct.animal) ', d: ' num2str(thisStruct.day) ', time: ' char(thisStruct.time), ', tcam: ' num2str(thisStruct.tcam)])

    yyaxis left
    p = plot(subset(:, 2));
    plot(mean_sero, 'LineStyle', ':', 'Color', p.Color)

    ylabelHandle = ylabel("dF/F0");

    if t_line < 0
        line([length(subset(:, 1))+t_line, length(subset(:, 1))+t_line], [-20, 20], 'Color', 'k', 'LineStyle', '--');
    end

    yyaxis right
    if index_of_touple ~= 0
        plot(subset(:, index_of_touple));
        % plot(movmean(subset(:, index_of_touple),150));
    end

    if plotPredSero == 1
        plot(subset(t_before:t_after, 4), 'Color', 'm', 'LineStyle', '-')
    end


    yyaxis right
    currentYLim = get(gca, 'YLim');
    minYRight = min(minYRight, currentYLim(1));
    maxYRight = max(maxYRight, currentYLim(2));

    xlim([start_idx end_idx])

end

for i_event = 1:max_events
    subplot(num_rows, num_col, i_event)
    xlabel('Time [s]')
    xticks(linspace(1 + start_idx,   + start_idx + end_idx + 1, end_idx / 100 + 1))
    xticklabels(arrayfun(@(x) [num2str(x) ' '], 1: - start_idx / 100 + end_idx / 100 + 1, 'UniformOutput', false))
    yyaxis left;
    ylim([-6 14])
    ylim([-0.08, 0.14])
    yyaxis right;
    ylim([minYRight maxYRight]);
    ylima = [minYRight maxYRight];
    if(t_line > 0)
        line([t_line+1, t_line+1], ylima, 'Color', 'k', 'LineStyle', '--');
    end
    if index_of_touple ~= 0
        ylabel('Speed [cm/s]')
    end
    if facemotion_bool == 1
        yyaxis left
        ax1 = gca; % Current axes
        ax2 = axes('Position', ax1.Position, ...
            'XAxisLocation', 'bottom', ...
            'YAxisLocation', 'left', ...
            'Color', 'none', ...
            'XColor', 'k', 'YColor', 'g', ...
            'YTick', [-6, 0, 6], ... % Hide y-ticks on the third axis
            'XTick', []); % Hide x-ticks on the third axis

        % Explicitly match the x-axis type and limits of ax2 to ax1
        hold(ax2, 'on');
        % plot(ax2, time, zeros(size(time)), 'Color', 'none'); % Dummy plot to set x-axis type
        ax2.XLim = ax1.XLim; % Match limits
        linkaxes([ax1, ax2], 'x');
        ylabel(ax2, 'Facemotion (std)');
        plot(subset(:, 4), 'Color', 'g', 'Parent', ax2)

        ylim([-6.5, 6.5])
        ylabelHandle.Position(1) = ylabelHandle.Position(1) - 0.33;
    end
end