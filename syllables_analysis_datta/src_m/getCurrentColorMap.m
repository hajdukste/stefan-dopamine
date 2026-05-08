function [map, color1, legenda] = getCurrentColorMap(idx)
    values = {[0.8500    0.3250    0.0980], [0 0.4470 0.7410], getColor('wp_motion'), 'm', 'k', 'c', getColor('pc1nose'), 'k', 'g', 'g'};
    % [speed, ser_norm, facemotion, predSeroDay, pupil, speed_nose_tip];
    map = containers.Map({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, values);
    color1 = 0;
    if nargin == 1
        color1 = map(idx);
        switch idx
            case 4; legenda = 'Prediction dF/F0 by speed model';
            case 5; legenda = 'Pupil';
            case 3; legenda = 'Whisker pad motion';
            case 1; legenda = 'Locomotion';
            otherwise; legenda = '';
        end
    end
end