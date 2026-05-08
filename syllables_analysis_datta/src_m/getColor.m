function [color, label] = getColor(variable, idx)

    if exist('idx', 'var')
        switch idx
            case 3
                variable = 'wp_motion';
            case 7
                variable = 'pc1nose';
            case 2
                variable = 'zsc_exp';
            case 1
                variable = 'speed';
            otherwise
                variable = 'black';
        end
    end

    if strcmp(variable, 'speed') || strcmp(variable, 's')
        color = [1, 47/255, 0];
    elseif strcmp(variable, 'wp_motion')
        color = [64/255 1 0];
    elseif strcmp(variable, 'facemotion0') || strcmp(variable, 'fm')
        color = [22/255 184/255 11/255];
    elseif strcmp(variable, 'pc1nose')
        color = [1 0 1];
    elseif strcmp(variable, 'zsc_exp') || strcmp(variable, '5ht')
        color = [31/255, 59/255, 1];
    else
        color = [0 0 0];
    end

    if strcmp(variable, 'speed') || strcmp(variable, 's')
        label = 'Speed (cm/s)';
    elseif strcmp(variable, 'wp_motion')
        label = 'WP motion (z-score)';
    elseif strcmp(variable, 'facemotion0')
        label = 'Face motion (z-score)';
    elseif strcmp(variable, 'pc1nose')
        label = 'PC1 Nose (z-score)';
    elseif strcmp(variable, 'zsc_exp') || strcmp(variable, '5ht')
        label = 'DRN 5-HT (z-score)';
    else
        label = strrep(variable, '_', '\_');
    end


end