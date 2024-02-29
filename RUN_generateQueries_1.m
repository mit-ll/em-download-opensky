% Copyright 2018 - 2024, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%% Inputs
% Airspace file created in em-core
fileAirspace = [getenv('AEM_DIR_CORE') filesep 'output' filesep 'airspace-B-C-D-E-03-Aug-2020' '.mat'];

% Boundaries / bounding boxes
rad_nm = 8;
areaThres_nm = 1000; % 30 square miles
classInclude = {'B', 'C', 'D'};

% Altitude
minAGL_ft = 0;
maxAGL_ft = 5100;
maxMSL_ft = 12500;

% Misc
rngSeed = 42;
isPlotBoundary = false;
isPlotFinal = true;

% Start Time
sY = 2019; % Start Year
sM = 11; % Start Month
sD = 1; % Start Day
sH = 5; % Start Hour
sMI = 0; % Start Minutecd
sS = 0; % Start Second

% End Time
timeEnd = 2019;
eY = sY; % End Year
eM = sM; % End Month
eD = sD; % End Day
eH = 23; % End Hour
eMI = 0; % End Minute
eS = 0; % End Second

% Number of days to iterate over
nDays = 14;

% Time step for queries
timeStep = hours(eH - sH);

% Set this to false if you don't want parfor to automatically run
ps = parallel.Settings;
ps.Pool.AutoCreate = false;

%% Iterate over time range and create queries
for i = 0:1:nDays - 1
    % Create ith start and end times
    % Time zones will be set locally
    timeStart = datetime(sY, sM, sD, sH, sMI, sS) + days(i);
    timeEnd = datetime(eY, eM, eD, eH, eMI, eS) + days(i);

    % Create string with relevant information
    outInfo = [[classInclude{:}] '_area' num2str(areaThres_nm) '_r' num2str(rad_nm) '_minAGL' num2str(minAGL_ft) '_maxAGL' num2str(maxAGL_ft) '_maxMSL' num2str(maxMSL_ft)];

    % Create output directories
    outDirQuery = ['output'];
    outDirParent = [getenv('AEM_DIR_OPENSKY') filesep 'data'  filesep outInfo filesep datestr(timeStart, 'yyyy-mm-dd')];

    % Create output file based on inputs
    outName = ['queries_' outInfo '_' datestr(timeStart, 'yyyy-mm-dd') '_' '.txt'];
    outFile = [outDirQuery filesep outName];

    % Create queries and write to file
    % Because this for loop only iterates over time, we don't need to
    % calculate the bounding boxes everytime
    if i == 0
        [queries, groups, boxLat_deg, boxLon_deg, minAlt_m_msl, maxAlt_m_msl] = generateQueries_1(fileAirspace, ...
                                                                                                  'outFile', outFile, 'isWrite', true, ...
                                                                                                  'rad_nm', rad_nm, 'areaThres_nm', areaThres_nm, 'classInclude', classInclude, ...
                                                                                                  'minAGL_ft', minAGL_ft, 'maxAGL_ft', maxAGL_ft, 'maxMSL_ft', maxMSL_ft, ...
                                                                                                  'timeStart', timeStart, 'timeEnd', timeEnd, 'timeStep', timeStep, ...
                                                                                                  'rngSeed', rngSeed, 'isRandomize', true, ...
                                                                                                  'isPlotBoundary', isPlotBoundary, 'isPlotFinal', isPlotFinal);
    else
        [queries, groups, ~, ~, ~, ~] = generateQueries_1(fileAirspace, ...
                                                          'boxLat_deg', boxLat_deg, 'boxLon_deg', boxLon_deg, ...
                                                          'minAlt_m_msl', minAlt_m_msl, 'maxAlt_m_msl', maxAlt_m_msl, ...
                                                          'outFile', outFile, 'isWrite', true, ...
                                                          'rad_nm', rad_nm, 'areaThres_nm', areaThres_nm, 'classInclude', classInclude, ...
                                                          'minAGL_ft', minAGL_ft, 'maxAGL_ft', maxAGL_ft, 'maxMSL_ft', maxMSL_ft, ...
                                                          'timeStart', timeStart, 'timeEnd', timeEnd, 'timeStep', timeStep, ...
                                                          'isRandomize', false, ...
                                                          'isPlotBoundary', false, 'isPlotFinal', false);
    end

    % Create parent directory
    mkdir(outDirParent);

    % Create subdirectories for each group
    arrayfun(@(x)(mkdir([outDirParent filesep num2str(x)])), unique(groups));
end
