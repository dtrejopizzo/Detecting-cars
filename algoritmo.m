filename = 'autos.mp4';
hvfr = vision.VideoFileReader(filename, 'ImageColorSpace', 'RGB');

hcsc = vision.ColorSpaceConverter('Conversion', 'RGB to intensity');

hfdet = vision.ForegroundDetector(...
        'NumTrainingFrames', 5, ...     % only 5 because of short video
        'InitialVariance', (30/255)^2); % initial standard deviation of 30/255
    
hblob = vision.BlobAnalysis( ...
                    'CentroidOutputPort', false, ...
                    'AreaOutputPort', true, ...
                    'BoundingBoxOutputPort', true, ...
                    'OutputDataType', 'single', ...
                    'MinimumBlobArea', 250, ...
                    'MaximumBlobArea', 3600, ...
                    'MaximumCount', 80);
                
hshapeins = vision.ShapeInserter( ...
            'BorderColor', 'Custom', ...
            'CustomBorderColor', [0 255 0]);

htextins = vision.TextInserter( ...
        'Text', '%4d', ...
        'Location',  [1 1], ...
        'Color', [255 255 255], ...
        'FontSize', 12);

sz = get(0,'ScreenSize');
pos = [20 sz(4)-300 200 200];
hVideoOrig = vision.VideoPlayer('Name', 'Original', 'Position', pos);
pos(1) = pos(1)+220; % move the next viewer to the right
hVideoFg = vision.VideoPlayer('Name', 'Foreground', 'Position', pos);
pos(1) = pos(1)+220;
hVideoRes = vision.VideoPlayer('Name', 'Results', 'Position', pos);

line_row = 23; % Define region of interest (ROI)


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