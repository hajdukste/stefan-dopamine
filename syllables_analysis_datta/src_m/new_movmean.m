function smoothed_x = new_movmean(x, movmean_size, lengths_of_periods)
    if lengths_of_periods == 0
        smoothed_x = movmean(x, movmean_size, 'omitnan');
    else
        current_start = 1;
        smoothed_x = zeros(size(x));
        for p = 1:length(lengths_of_periods)
            period_length = lengths_of_periods(p);
            current_end = current_start + period_length - 1;
            smoothed_x(current_start:current_end) = movmean(x(current_start:current_end), movmean_size, 'omitnan');
            current_start = current_end + 1;
        end
    end
end