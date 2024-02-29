% Copyright 2018 - 2024, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% Path
% Add utilities, such as msl2agl
addpath(genpath([getenv('AEM_DIR_CORE') filesep 'matlab']));
addpath(genpath('dividepolygon'));

% Plotting defaults
% https://www.mathworks.com/help/matlab/creating_plots/default-property-values.html
myColorOrder = [0 114 178; ... % Blue
                230 159 0; ... % Orange
                204 121 167; ... % Reddish purple
                86 180 233; ... % Sky Blue
                0 158 155; ... % Bluish green
                213 94 0; .... % Vermillion
                240 228 66 ... % Yellow
               ] / 255;

set(groot, 'defaultFigureColor', 'white'); % Figure defaults
set(groot, 'defaultAxesColorOrder', myColorOrder, ...
    'defaultAxesFontsize', 12, ...
    'defaultAxesFontweight', 'bold', ...
    'defaultAxesFontName', 'Arial'); % Axes defaults
set(0, 'DefaultAxesColorOrder', myColorOrder);
set(groot, 'defaultLineLineWidth', 1.5); % Line defaults
set(groot, 'defaultStairLineWidth', 1.5); % Stair defaults (used in ecdf)
