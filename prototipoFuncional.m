%% Tracking Cars Using Gaussian Mixture Models
% This demo illustrates how to detect cars in a video sequence 
% using foreground detection based on gaussian mixture models (GMMs). 

%   Copyright 2004-2010 The MathWorks, Inc.
%   $Revision: 1.1.6.6 $  $Date: 2011/10/02 00:47:16 $

%% Introduction
% This demo illustrates the use of gaussian mixture models to detect 
% foreground in a video. After foreground detection, the demo process
% the binary foreground images using blob analysis. Finally,  
% bounding boxes are drawn around the detected cars.

%% Initialization
% Use these next sections of code to initialize the required variables and
% System objects.

%% 
% Create a System object to read video from avi file.
filename = 'autos.avi';
hvfr = vision.VideoFileReader(filename, 'ImageColorSpace', 'RGB');

%%
% Create color space converter System object to convert the image from RGB
% to intensity format.
hcsc = vision.ColorSpaceConverter('Conversion', 'RGB to intensity');


%%
% Create a System object to detect foreground using gaussian mixture models.
hfdet = vision.ForegroundDetector(...
        'NumTrainingFrames', 5, ...     % only 5 because of short video
        'InitialVariance', (30/255)^2); % initial standard deviation of 30/255
   
%%
% Create a blob analysis System object to segment cars in the video.
hblob = vision.BlobAnalysis( ...
                    'CentroidOutputPort', false, ...
                    'AreaOutputPort', true, ...
                    'BoundingBoxOutputPort', true, ...
                    'OutputDataType', 'single', ...
                    'MinimumBlobArea', 250, ...
                    'MaximumBlobArea', 3600, ...
                    'MaximumCount', 80);

%%
% Create System object for drawing the bounding boxes around detected cars.
hshapeins = vision.ShapeInserter( ...
            'BorderColor', 'Custom', ...
            'CustomBorderColor', [0 255 0]);

%%
% Create and configure a System object to write the number of cars being
% tracked.
htextins = vision.TextInserter( ...
        'Text', '%4d', ...
        'Location',  [1 1], ...
        'Color', [255 255 255], ...
        'FontSize', 12);

%%
% Create System objects to display the results.
sz = get(0,'ScreenSize');
pos = [20 sz(4)-300 200 200];
hVideoOrig = vision.VideoPlayer('Name', 'Original', 'Position', pos);
pos(1) = pos(1)+220; % move the next viewer to the right
hVideoFg = vision.VideoPlayer('Name', 'Foreground', 'Position', pos);
pos(1) = pos(1)+220;
hVideoRes = vision.VideoPlayer('Name', 'Results', 'Position', pos);

line_row = 23; % Define region of interest (ROI)

%% Stream Processing Loop
% Create a processing loop to track the cars in the input video. This
% loop uses the previously instantiated System objects.
%
% When the VideoFileReader object detects the end of the input file, the loop
% stops.
while ~isDone(hvfr)
    image = step(hvfr);      % Read input video frame
    y = step(hcsc, image);   % Convert color image to intensity
    
    % Remove the effect of sudden intensity changes due to camera's 
    % auto white balancing algorithm.
    y = y-mean(y(:)); 
        
    fg_image = step(hfdet, y); % Detect foreground

    % Estimate the area and bounding box of the blobs in the foreground
    % image.
    [area, bbox] = step(hblob, fg_image);
    
    image_out = image;
    image_out(22:23,:,:) = 255;  % Count cars only below this white line
    image_out(1:15,1:30,:) = 0;  % Black background for displaying count
    
    Idx = bbox(:,2) > line_row; % Select boxes which are in the ROI.

    % Based on dimensions, exclude objects which are not cars. When the
    % ratio between the area of the blob and the area of the bounding box
    % is above 0.4 (40%) classify it as a car.
    ratio = zeros(length(Idx),1);
    ratio(Idx) = single(area(Idx,1))./single(bbox(Idx,3).*bbox(Idx,4));
    ratiob = ratio > 0.4;
    count = int32(sum(ratiob));    % Number of cars
    bbox(~ratiob,:) = int32(-1);

    % Draw bounding rectangles around the detected cars.
    image_out = step(hshapeins, image_out, bbox);

    % Display the number of cars tracked and a white line showing the ROI.
    image_out = step(htextins, image_out, count);

    step(hVideoOrig, image);          % Original video
    step(hVideoFg,   fg_image);       % Foreground 
    step(hVideoRes,  image_out);      % Bounding boxes around cars
end

% Close the video file
release(hvfr);

%% Summary
% The output video displays the bounding boxes around the cars. It also 
% displays the number of cars in the upper left corner of the video.

displayEndOfDemoMessage(mfilename)
