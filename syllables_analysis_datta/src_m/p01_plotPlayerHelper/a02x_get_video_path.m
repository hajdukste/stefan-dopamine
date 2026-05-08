function [video_file, keypoints_data, rectangleXY] = a02x_get_video_path(animal, day)
    if ispc
        video_file = '0';
    else
        names = ["olaf", "neo", "moul", "sam", "5", "6", "7", "8", "OLAF", "Hold", "Jump", "Try", "0", "MOUL", "UGO"];
        if animal < 7
            directory = '/Users/stefek/CF Drive/Python/facemap/videos_glitch/';
        end
        if animal > 8
            directory = '/Users/stefek/CF Drive/Python/facemap/';
        end
        files = dir(fullfile(directory, '*.mp4')); %list of all mp4
        for k = 1:length(files)
            filename = files(k).name;
            if contains(filename, sprintf('%d_%s', day, names(animal)))
                video_file = fullfile(directory, filename);
            end
        end
        if strcmp(video_file, '0')
            error('No video found for %d %s, day: %d\n', animal, names(animal), day);
        end
    end

    if animal > 8
        keypoint1 = 'nose_tip';
        mat_name = 'motionvalve1213of0831.mat';

        file_path_mat = fullfile('facemap', mat_name);
        S = load(file_path_mat);
        keypoints_data = double(S.folderData(animal-9).data(day).d.(keypoint1));
        keypoints_data = keypoints_data(:, 1:2);

        mat_name = 'size_rectangles_0424of0831.mat';

        file_path_mat = fullfile('facemap', mat_name);
        S = load(file_path_mat);
        rectangleFullData = S.folderData;
        rectangleSessionData = rectangleFullData(animal-9).data(day).d;
        whichRoi = 1;
        rectangleXY = struct('x1', rectangleSessionData.MinX(whichRoi), 'x2', rectangleSessionData.MaxX(whichRoi), 'y1', rectangleSessionData.MinY(whichRoi), 'y2', rectangleSessionData.MaxY(whichRoi));
    else
        rectangleXY = [];
        keypoints_data = [];
    end


end