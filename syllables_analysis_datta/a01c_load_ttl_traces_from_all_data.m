

if exist('loading_split_video', 'var') && loading_split_video
    % Load pre-extracted TTL data for split video
    all_data_real = all_data;
    load('/Users/stefan/UCDrive/A SR/matlab/data_0406_split_video.mat');
    all_data_split = all_data;
    all_data = all_data_real;

    for day = 1:length(all_data(1).data)
        all_data(1).data(day).ttl_data2 = all_data_split(1).data(day).ttl_data2;
        all_data(1).data(day).ttl_roi2 = all_data_split(1).data(day).ttl_roi2;
        all_data(1).data(day).ttl_data = all_data_split(1).data(day).ttl_data;
        all_data(1).data(day).ttl_roi = all_data_split(1).data(day).ttl_roi;
    end
    return;  % skip normal loading
end

all_data_real = all_data;

load('/Users/stefan/UCDrive/A SR/matlab/data_0331_3_oldMac.mat');
all_data_oldMac = all_data;
all_data = all_data_real;

%

% compare all_data_real and all_data_oldMac
for animal = 1:length(all_data_real)
    for day = 1:5
        all_data(animal).data(day).ttl_data = all_data_oldMac(animal).data(day).ttl_data;
        all_data(animal).data(day).ttl_roi = all_data_oldMac(animal).data(day).ttl_roi;
    end
end


all_data_real = all_data;
load('/Users/stefan/UCDrive/A SR/matlab/data_0404_extracted4lights.mat');
all_data_extracted4lights = all_data;
all_data = all_data_real;

%

% compare all_data_real and all_data_oldMac
for animal = 1:length(all_data_real)
    for day = 1:5
        all_data(animal).data(day).ttl_data2 = all_data_extracted4lights(animal).data(day).ttl_data2;
        all_data(animal).data(day).ttl_roi2 = all_data_extracted4lights(animal).data(day).ttl_roi2;
    end
end



all_data_real = all_data;
load('/Users/stefan/UCDrive/A SR/matlab/data_0409_hab.mat');
all_data_extracted4lights = all_data;
all_data = all_data_real;

for animal = 1:length(all_data_real)
    for day = 6
        all_data(animal).data(day).ttl_data = all_data_extracted4lights(animal).data(day).ttl_data;
        all_data(animal).data(day).ttl_roi = all_data_extracted4lights(animal).data(day).ttl_roi;

        ttl_data2 = struct();
        ttl_data2.ttl_traces = all_data(animal).data(day).ttl_data.ttl_trace;
        ttl_data2.ttl_time = all_data(animal).data(day).ttl_data.ttl_time;

        all_data(animal).data(day).ttl_data2 = ttl_data2;
    end
end