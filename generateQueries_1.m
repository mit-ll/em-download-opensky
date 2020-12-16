function [queries,groups,boxLat_deg,boxLon_deg,minAlt_m_msl,maxAlt_m_msl] = generateQueries(fileAirspace,varargin)
% Copyright 2018 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

%% Input parser
p = inputParser;

% Required
addRequired(p,'fileAirspace'); % Input airspace from em-core

% Optional - Output File
addOptional(p,'outFile',[getenv('AEM_DIR_OPENSKY') filesep 'output' filesep 'queries.txt']); % Output filename
addOptional(p,'isWrite',true,@islogical); % If true, write to file
addOptional(p,'queriesPerGroup',1000,@isnumeric); % Maximum number of queries per group (groups will be used for load balencing / directory structure)

% Optional - Boundary / Bounding Box parameters
addOptional(p,'rad_nm', 8,@isnumeric); % Radius of small circles away from aerodromes
addOptional(p,'areaThres_nm', 600,@isnumeric); % Maximum bounding box size (will divide boxes larger than this)
addOptional(p,'classInclude',{'B','C','D'},@iscell); % Airspace classes to include
addOptional(p,'maxConvgInit', 20,@isnumeric); % Maximum iterations to attempt when unioning bound box

% Optional - Altitude Limits
addOptional(p,'minAGL_ft', 0,@isnumeric); % Minimum barometric altitude (feet AGL)
addOptional(p,'maxAGL_ft', 5100,@isnumeric); % Maximum barometric altitude (feet AGL)
addOptional(p,'maxMSL_ft', 12500,@isnumeric); % Maximum barometric altitude (feet MSL)

% Optional - Timezones
addOptional(p,'timeStart', datetime('2019-01-01 05:00:00'),@isdatetime); % Start time (no time zone)
addOptional(p,'timeEnd', datetime('2019-01-01 23:00:00'),@isdatetime); % End time
addOptional(p,'timeStep', hours(1),@isduration); % Time step

% Optional - Random Seed
addOptional(p,'rngSeed',42,@isnumeric); % Random seed
addOptional(p,'isRandomize',true,@islogical); % If true, random order of queries (this often helps with load balancing)

% Optional - Plot and Display
addOptional(p,'isPlotBoundary',false,@islogical);
addOptional(p,'isPlotFinal',true,@islogical);

% Optional - Reuse bounding boxes
addOptional(p,'boxLat_deg',{},@iscell);
addOptional(p,'boxLon_deg',{},@iscell);
addOptional(p,'minAlt_m_msl',[],@isnumeric);
addOptional(p,'maxAlt_m_msl',[],@isnumeric);

% Parse
parse(p,fileAirspace,varargin{:});

%% Warnings and Input Handling
if p.Results.queriesPerGroup > 1000;
    warning('queriesPerGroup:max','queriesPerGroup = %i, Strongly recommended for HPC storage to set queriesPerGroup around 1000\n',p.Results.queriesPerGroup);
end

% Check lat / lon are the same
assert(size(p.Results.boxLat_deg,1) == size(p.Results.boxLon_deg,1) & size(p.Results.boxLat_deg,2) == size(p.Results.boxLon_deg,2),'generateQueries:bboxsize','bounding boxes are not the same size\n');

% Check altitude is the same
assert(size(p.Results.minAlt_m_msl,1) == size(p.Results.maxAlt_m_msl,1) & size(p.Results.minAlt_m_msl,2) == size(p.Results.maxAlt_m_msl,2),'generateQueries:altsize','altitudes are not the same size\n');

% Check lat / lon and altitude are the same
assert(size(p.Results.minAlt_m_msl,1) == size(p.Results.boxLon_deg,1) & size(p.Results.minAlt_m_msl,2) == size(p.Results.boxLon_deg,2),'generateQueries:bboxaltsize','bounding box and altitudes are not the same size\n');

%% Preallocate output
queries = strings(0,0);
groups = ones(0,0);
boxLat_deg = p.Results.boxLat_deg;
boxLon_deg = p.Results.boxLon_deg;
minAlt_m_msl = p.Results.minAlt_m_msl;
maxAlt_m_msl = p.Results.maxAlt_m_msl;

%% Set random seed
rng(p.Results.rngSeed,'twister');

%% Load and parse airports and airspace
if any(strcmpi(p.UsingDefaults,'boxLat_deg'))
    % Load Airports
    S_airports = m_shaperead([getenv('AEM_DIR_CORE') filesep 'data' filesep 'FAA-Airports' filesep 'Airports']);
    
    % Load Airspace
    load(fileAirspace,'airspace');
    
    % Parse airports
    % Find column index
    idxName = find(strcmpi(S_airports.fieldnames,'name'));
    idxLat = find(strcmpi(S_airports.fieldnames,'latitude'));
    idxLon = find(strcmpi(S_airports.fieldnames,'longitude'));
    
    % Parse
    names = lower(string(S_airports.dbfdata(:,idxName)));
    latAirports_dms = S_airports.dbfdata(:,idxLat);
    lonAirports_dms = S_airports.dbfdata(:,idxLon);
    
    % String split to break out each individual word
    namesSplit = cellfun(@strsplit,names,'uni',false);
    namesSplit = cellfun(@string,namesSplit,'UniformOutput',false);
    
    % Parse hemisphere
    lat_sense = cellfun(@(x)(x(end)),latAirports_dms,'uni',false);
    lon_sense = cellfun(@(x)(x(end)),lonAirports_dms,'uni',false);
    
    % String split degrees, minutes, seconds
    latAirports_dms = cellfun(@(x)(str2double(strsplit(x(1:end-1),'-'))),latAirports_dms,'uni',false);
    lonAirports_dms = cellfun(@(x)(str2double(strsplit(x(1:end-1),'-'))),lonAirports_dms,'uni',false);
    
    % Filter out bad lat / lon
    lbad = (cellfun(@numel,latAirports_dms) ~= 3) | (cellfun(@numel,lonAirports_dms) ~= 3);
    names = names(~lbad);
    latAirports_dms = latAirports_dms(~lbad);
    lonAirports_dms = lonAirports_dms(~lbad);
    lat_sense = lat_sense(~lbad);
    lon_sense = lon_sense(~lbad);
    
    % Convert to decimal degrees
    latAirports_dms = cell2mat(latAirports_dms);
    lonAirports_dms = cell2mat(lonAirports_dms);
    if any(strcmpi(lat_sense,'S'));latAirports_dms(strcmpi(lat_sense,'S'),1) = -1* latAirports_dms(strcmpi(lat_sense,'S'),1); end
    if any(strcmpi(lon_sense,'W'));lonAirports_dms(strcmpi(lon_sense,'W'),1) = -1* lonAirports_dms(strcmpi(lon_sense,'W'),1); end;
    latAirports_deg = dms2degrees(latAirports_dms);
    lonAirports_deg = dms2degrees(lonAirports_dms);
    
    % Filter Airspace
    % Create filters for individual airspace classes
    isF = airspace.CLASS == 'F';
    isE = airspace.CLASS == 'E';
    isD = airspace.CLASS == 'D';
    isC = airspace.CLASS == 'C';
    isB = airspace.CLASS == 'B';
    
    % Create aggregate logical filter
    isClass = false(size(airspace,1),1);
    if any(strcmpi('B',p.Results.classInclude)); isClass = isClass | isB; end;
    if any(strcmpi('C',p.Results.classInclude)); isClass = isClass | isC; end;
    if any(strcmpi('D',p.Results.classInclude)); isClass = isClass | isD; end;
    if any(strcmpi('E',p.Results.classInclude)); isClass = isClass | isE; end;
    if any(strcmpi('F',p.Results.classInclude)); isClass = isClass | isF; end;
    
    % Filter airspace table
    airspace = airspace(isClass,:);
    
    % Calculate altitude AGL extremes
    airspace.minAGL_ft = cellfun(@min,airspace.LOWALT_ft_agl);
    airspace.maxAGL_ft = cellfun(@min,airspace.HIGHALT_ft_agl);
end

%% Create polygons based on aerodromes within an airspace
if any(strcmpi(p.UsingDefaults,'boxLat_deg'))
    % Preallocate
    pgons(size(airspace,1),1) = polyshape();
    
    for i=1:1:size(airspace,1)
        % Get airspace points and remove nan
        [lat_deg,lon_deg] = polyjoin(airspace.LAT_deg(i),airspace.LON_deg(i));
        lat_deg = lat_deg(~isnan(lat_deg)); lon_deg = lon_deg(~isnan(lon_deg));
        
        % Convex hull of airspace points
        kair = convhull(lat_deg,lon_deg);
        
        % Identify airports within convex hull of airspace
        lport = InPolygon(latAirports_deg, lonAirports_deg, lat_deg(kair),lon_deg(kair));
        
        if any(lport)
            % Circle small circles around airports
            [clat_deg,clon_deg] = scircle1(latAirports_deg(lport),lonAirports_deg(lport),repmat(p.Results.rad_nm,sum(lport),1),[],wgs84Ellipsoid('nm'));
            
            % Rearrange to column array
            clat_deg = clat_deg(:); clon_deg = clon_deg(:);
            
            % Convex hull of airport small circles points
            kport = convhull(clat_deg,clon_deg);
            
            % Find min / max
            minLat_deg = min(clat_deg(kport));
            maxLat_deg = max(clat_deg(kport));
            minLon_deg = min(clon_deg(kport));
            maxLon_deg = max(clon_deg(kport));
            
            % Create ith polyshape as the bounding box
            pgons(i) = polyshape([minLon_deg, maxLon_deg,maxLon_deg,minLon_deg],[minLat_deg, minLat_deg, maxLat_deg, maxLat_deg]);
            
            % Plot
            if p.Results.isPlotBoundary
                % Create figure
                figure(i); set(gcf,'Name', airspace.NAME{i});
                gx = geoaxes('Basemap','streets',...
                    'FontSize',14,...
                    'FontWeight','bold');
                bmap = geobasemap(gx);
                hold on;
                
                % Populate map
                geoscatter(latAirports_deg(lport),lonAirports_deg(lport),20,'k','d','filled');
                geoplot(lat_deg(kair),lon_deg(kair),'Color',[0 114 178]/255,'LineStyle','--','LineWidth',2.5);
                geoplot(clat_deg(kport),clon_deg(kport),'Color',[0 158 155]/255,'LineStyle','-','LineWidth',5);
                hold off;
                
                % Legend, labels, Adjust map size
                legend({'Aerodrome','Airspace','Boundary'},'Location','southoutside','NumColumns',3);
                gx.LatitudeLabel.String = '';
                gx.LongitudeLabel.String = '';
                set(gcf,'Units','inches','Position',[1 1 5.82 5.28]);
            end
        end
    end
    
    % Union of polyshape objects of small circles
    polyunion = union(pgons);
    
    % Remove holes
    polyunion = rmholes(polyunion);
end

%% Iteratively union bounding boxes
if any(strcmpi(p.UsingDefaults,'boxLat_deg'))
    % Record the current number of regions
    nRegions = polyunion.NumRegions;
    
    % Extract out each region
    [latcells,loncells] = polysplit(polyunion.Vertices(:,2),polyunion.Vertices(:,1));
    
    % Preallocate
    polybox(nRegions,1) = polyshape();
    
    % Counters
    isConvg = false;
    c = 0;
    
    % Iterate
    while ~isConvg
        % Find min / max
        minLat_deg = cellfun(@min,latcells);
        maxLat_deg = cellfun(@max,latcells);
        minLon_deg = cellfun(@min,loncells);
        maxLon_deg = cellfun(@max,loncells);
        
        % Create ith polyshape as the bounding box
        for i=1:1:nRegions
            polybox(i) = polyshape([minLon_deg(i), maxLon_deg(i), maxLon_deg(i), minLon_deg(i)],[minLat_deg(i), minLat_deg(i), maxLat_deg(i), maxLat_deg(i)]);
        end
        
        % Union of polyshape objects of small circles
        polybox = union(polybox);
        
        % Remove holes
        polybox = rmholes(polybox);
        
        % Check if we reached convergence
        if polybox.NumRegions < nRegions
            isConvg = false;
            % Extract out each region
            [latcells,loncells] = polysplit(polybox.Vertices(:,2),polybox.Vertices(:,1));
            
            % Preallocate
            polybox(nRegions,1) = polyshape();
        else
            isConvg = true;
        end
        
        % Update counters
        nRegions = polybox.NumRegions;
        c = c+1;
        
        % Make sure we don't get stuck in a while loop
        if c == p.Results.maxConvgInit; isConvg = true; warning('Convergence not reached'); end;
    end
end

%% Split bounding boxes if they are too large
if any(strcmpi(p.UsingDefaults,'boxLat_deg'))
    % Extract out each bounding box
    [latcells,loncells] = polysplit(polybox.Vertices(:,2),polybox.Vertices(:,1));
    
    % Preallocate
    boxLat_deg = cell(nRegions,1);
    boxLon_deg = cell(nRegions,1);
    
    % Calculate area
    area_nm = cellfun(@(lat,lon)(areaint(lat,lon,wgs84Ellipsoid('nm'))),latcells,loncells,'uni',true);
    
    % Iterate over bounding boxes
    for i=1:1:nRegions
        % Do something if area is greater than threshold
        if area_nm(i) > p.Results.areaThres_nm
            % Determine number of splits
            nDivid = ceil((area_nm(i) / p.Results.areaThres_nm) );
            
            % Round to nearest multiple of two
            nDivid = 2*ceil(nDivid/2);
            
            % If the bounding box is really big, divide some more
            % 14 was heuristically picked
            if nDivid > 14; nDivid = nDivid * 2; end;
            
            % Divide along X & Y
            switch nDivid
                case 2
                    NX = 2;
                    NY = 1;
                case 4
                    NX = 2;
                    NY = 2;
                case 6
                    NX = 3;
                    NY = 2;
                case 8
                    NX = 4;
                    NY = 2;
                otherwise
                    NX = ceil(sqrt(nDivid));
                    NY = ceil(sqrt(nDivid));
                    if NY<=0; NY==1;end;
            end
            
            % Parse and divide
            poly.x = loncells{i};
            poly.y = latcells{i};
            PXY = DIVIDEXY(poly,NX,NY);
            PXY = PXY(~cellfun(@isempty,PXY));
            
            % Convert to column
            PXY = PXY(:);
            
            % Convert to polyshapes
            px = cellfun(@(p)(p.x),PXY,'uni',false);
            py = cellfun(@(p)(p.y),PXY,'uni',false);
            
            % Assign
            [boxLat_deg{i},boxLon_deg{i}] = polyjoin(py,px);
        else
            boxLat_deg{i} = latcells{i};
            boxLon_deg{i} = loncells{i};
        end
    end
    
    % Join and split
    [lat,lon] = polyjoin(boxLat_deg,boxLon_deg);
    [boxLat_deg,boxLon_deg] = polysplit(lat,lon);
    
    % Find min / max
    minLat_deg = cellfun(@min,boxLat_deg);
    maxLat_deg = cellfun(@max,boxLat_deg);
    minLon_deg = cellfun(@min,boxLon_deg);
    maxLon_deg = cellfun(@max,boxLon_deg);
end

%% Now that we have nice grids, remove airspaces not of interest
if any(strcmpi(p.UsingDefaults,'boxLat_deg'))
    % Preallocate
    isKeep = false(size(boxLat_deg));
    
    % Split into cells so we can easily iterate over them using parfor
    [latUnion,lonUnion] = polysplit(polyunion.Vertices(:,2),polyunion.Vertices(:,1));
    
    % Iterate over bounding boxes
    parfor i=1:1:numel(boxLat_deg)
        % Create grid
        [X,Y] = meshgrid(minLon_deg(i):nm2deg(0.1):maxLon_deg(i),minLat_deg(i):nm2deg(0.1):maxLat_deg(i));
        
        % Determine if a point within the grid is within the original unioned polygon
        li = cellfun(@(lat,lon)(any(InPolygon(Y(:),X(:),lat,lon))),latUnion,lonUnion,'uni',true);
        
        % Assign
        isKeep(i) = any(li);
    end
    
    % Filter
    boxLat_deg = boxLat_deg(isKeep);
    boxLon_deg = boxLon_deg(isKeep);
end

%% Find min / max
minLat_deg = cellfun(@min,boxLat_deg);
maxLat_deg = cellfun(@max,boxLat_deg);
minLon_deg = cellfun(@min,boxLon_deg);
maxLon_deg = cellfun(@max,boxLon_deg);

%% Determine local time zone
% You may not set the 'TimeZone' property of individual elements of a datetime array.
% Time zone based on longitude
[zd,~,~] = timezone(minLon_deg,'degrees');

tz = strings(size(zd));
for i=1:1:numel(tz)
    if zd(i) >= 0
        tz(i) = sprintf('+%02.0f:00',zd(i));
    else
        tz(i) = sprintf('-%02.0f:00',zd(i));
    end
end

%% Plot
if p.Results.isPlotFinal
    figure(100000);
    gx = geoaxes('Basemap','streets',...
        'FontSize',14,...
        'FontWeight','bold');
    bmap = geobasemap(gx); hold on;
    
    % Create a closed polygon
    [latunion,lonunion] = polysplit(polyunion.Vertices(:,2),polyunion.Vertices(:,1));
    latunion = cellfun(@(x)([x; x(1)]),latunion,'uni',false);
    lonunion = cellfun(@(x)([x; x(1)]),lonunion,'uni',false);
    [latunion,lonunion] = polyjoin(latunion,lonunion);
    
    % Plot closed polygon
    geoplot(latunion,lonunion,'Color','k','LineStyle','-','LineWidth',1);
    %geolimits([24 50], [-125,-65]); % Only show conus
    geolimits([40 44], [-75,-70]); % NYC + BOS
    gx.LatitudeLabel.String = '';
    gx.LongitudeLabel.String = '';
    hold off;
    
    figure(100001);
    gx = geoaxes('Basemap','streets',...
        'FontSize',14,...
        'FontWeight','bold');
    bmap = geobasemap(gx); hold on;
    
    lat = cellfun(@(x)([x; x(1)]),boxLat_deg,'uni',false);
    lon = cellfun(@(x)([x; x(1)]),boxLon_deg,'uni',false);
    [lat,lon] = polyjoin(lat,lon);
    
    % Plot closed polygon
    geoplot(lat,lon,'Color','k','LineStyle','-','LineWidth',1);
    %geolimits([24 50], [-125,-65]); % Only show conus
    geolimits([40 44], [-75,-70]); % NYC + BOS
    gx.LatitudeLabel.String = '';
    gx.LongitudeLabel.String = '';
    hold off;
    
    figure(100002);
    gx = geoaxes('Basemap','streets-dark',...
        'FontSize',14,...
        'FontWeight','bold');
    bmap = geobasemap(gx); hold on;
    geoplot(lat,lon,'Color','y','LineStyle','-','LineWidth',0.5);
    geolimits([24 50], [-125,-65]); % Only show conus
    gx.LatitudeLabel.String = '';
    gx.LongitudeLabel.String = '';
    hold off;
end

%% Get altitude MSL feet extremes
if any(strcmpi(p.UsingDefaults,'minAlt_m_msl'))
    % Preallocate
    minAlt_m_msl = zeros(size(boxLat_deg));
    maxAlt_m_msl = zeros(size(boxLat_deg));
    
    % Iterate over bounding boxes
    parfor i=1:1:numel(boxLat_deg)
        % NOAA GLOBE is 30 arc seconds = 1 km = 0.5 nautical miles
        [X,Y] = meshgrid(minLon_deg(i):nm2deg(0.5):maxLon_deg(i),minLat_deg(i):nm2deg(0.5):maxLat_deg(i));
        
        % Get elevation
        [el_ft_msl,~,~,~] = msl2agl(Y(:), X(:), 'globe');
        
        % Convert units
        el_m_msl = el_ft_msl * unitsratio('m','ft');
        
        % Calculate floor and ceiling
        minAlt_m_msl(i) = floor(min(el_m_msl) + (p.Results.minAGL_ft* unitsratio('m','ft')));
        maxAlt_m_msl(i) = ceil(max(el_m_msl) + (p.Results.maxAGL_ft* unitsratio('m','ft')));
    end
    
    % Adjust altitude to max altitude MSL if needed
    maxMSL_m = p.Results.maxMSL_ft * unitsratio('m','ft');
    isHigh = maxAlt_m_msl > maxMSL_m;
    maxAlt_m_msl(isHigh) = floor(maxMSL_m);
end

%% Plot
if p.Results.isPlotFinal
    figure(100003);
    histogram((maxAlt_m_msl - minAlt_m_msl) * unitsratio('ft','m'),'Normalization','cdf')
    xlabel('Maximum Altitude AGL (ft) Within Bounding Box');
    grid on;
end

%% Create queries and write to file
% Preallocate
queries = strings((numel(p.Results.timeStart:p.Results.timeStep:p.Results.timeEnd)-1) * numel(boxLat_deg),1);
cq = 1; % queries counter

% Iterate over bounding boxes
for i=1:1:numel(boxLat_deg)
    % Local time
    timeStart_local = datetime(p.Results.timeStart.Year,p.Results.timeStart.Month,p.Results.timeStart.Day,p.Results.timeStart.Hour,p.Results.timeStart.Minute,p.Results.timeStart.Second,'TimeZone',tz(i));
    timeEnd_local = datetime(p.Results.timeEnd.Year,p.Results.timeEnd.Month,p.Results.timeEnd.Day,p.Results.timeEnd.Hour,p.Results.timeEnd.Minute,p.Results.timeEnd.Second,'TimeZone',tz(i));
    
    % UTC time
    timeStart_utc = timeStart_local; timeStart_utc.TimeZone = 'UTC';
    timeEnd_utc = datetime(timeEnd_local,'TimeZone','UTC');
    
    % Get all timesteps
    time_utc = timeStart_utc:p.Results.timeStep:timeEnd_utc;
    
    % Iterate over time
    for j=1:1:numel(time_utc)-1
        
        % POSIX Time
        timeStart_posix = posixtime(time_utc(j));
        timeEnd_posix = posixtime(time_utc(j+1));
        
        % Create query
        query = sprintf('SELECT * FROM state_vectors_data4 WHERE baroaltitude>=%i AND baroaltitude<=%i AND lon>=%f AND lon<=%f AND lat>=%f AND lat<=%f AND time>=%i AND hour>=%i AND time<=%i AND hour<=%i;quit;',...
            minAlt_m_msl(i),maxAlt_m_msl(i),minLon_deg(i),maxLon_deg(i),minLat_deg(i),maxLat_deg(i),timeStart_posix,timeStart_posix,timeEnd_posix,timeEnd_posix);
        
        % Write to workspace variable
        queries(cq) = query;
        cq = cq + 1;
    end
end

%% Assign groups
% Determine total number of queries
nQueries = numel(queries);

% Preallocate output
groups = ones(nQueries,1);

% Only do something if needed
if nQueries > p.Results.queriesPerGroup
    % Calculate number of directories required
    nDir = ceil(nQueries / p.Results.queriesPerGroup);
    
    % Create group edges
    groupEdges = floor(linspace(1,nQueries,nDir+1))';
    
    % Assign groups
    for i=1:1:numel(groupEdges)-1
        groups(groupEdges(i):groupEdges(i+1)) = i;
    end
end

%% Randomize order
% We do this to help with load balancing when using queries
if p.Results.isRandomize
    pidx = randperm(numel(queries));
    queries = queries(pidx);
    groups = groups(pidx);
    boxLat_deg = boxLat_deg(pidx);
    boxLon_deg = boxLon_deg(pidx);
    minAlt_m_msl = minAlt_m_msl(pidx);
    maxAlt_m_msl = maxAlt_m_msl(pidx);
end

%% Write to file
if p.Results.isWrite
    % Open File
    fid = fopen(p.Results.outFile,'w+');
    
    % Write to file
    fprintf(fid,'%s\n',queries);
    
    % Close file
    fclose(fid);
    
    % Repeat process but for groups
    fid = fopen([p.Results.outFile(1:end-4) '_groups.txt'],'w+');
    fprintf(fid,'%i\n',groups);
    fclose(fid);
end
