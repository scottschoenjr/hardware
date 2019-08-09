% Function to read temerpature from Pico TC-08 Data Logger

clear all;
close all;
clc;

verbose = 0;

% Load Configuration Information
USBTC08Config;

% Make sure library isn't already loaded.
try
    unloadlibrary( 'usbtc08' )
catch
    % Do nothing if not found
end

% Load Library
loadlibrary('usbtc08.dll', @usbtc08MFile);
% Check if the library is loaded
if ~libisloaded('usbtc08')
    
    error('Library usbtc08.dll or usbtc08MFile not found');
    
end

% Define Buffers
numSamples = 512;

pBufferCJ       = libpointer('singlePtr',zeros(numSamples, 1, 'single'));
pBufferCh1      = libpointer('singlePtr',zeros(numSamples, 1, 'single'));
pBufferCh2      = libpointer('singlePtr',zeros(numSamples, 1, 'single'));
pBufferCh1Last  = libpointer('singlePtr',zeros(1, 1, 'single'));
pBufferTimes    = libpointer('int32Ptr',zeros(numSamples, 1, 'int32'));
overflow        = libpointer('int16Ptr',zeros(1, 1, 'int16'));

% Open Unit and Display Information
unithandle = calllib('usbtc08', 'usb_tc08_open_unit');
if ~( unithandle >= 0 )
    
    unloadlibrary('usbtc08');
    error('USBTC08Example:UnitFailedToOpen', 'Unit failed to open.');
    return;
    
end

% Get unit information

infoString = blanks(512);

[status.unitinfo, infostring] = calllib('usbtc08', 'usb_tc08_get_formatted_info', ...
    unithandle, infoString, length(infoString));

if verbose == 1
    disp(infostring);
end

error = calllib('usbtc08', 'usb_tc08_get_last_error', unithandle);

% Configure Device

% Set up channels

usbtc08MaxChannels = usbtc08Enuminfo.enUSBTC08Channels.USBTC08_MAX_CHANNELS;
typek = 'K';

% Enable Cold Junction and Channels 1 and 2
for n = 1:3
    
    status.setChannel = calllib('usbtc08', 'usb_tc08_set_channel', unithandle, ...
        (n - 1), int8(typek));
    
end

% Set mains filter to 50Hz

status.mainsFilter = calllib('usbtc08', 'usb_tc08_set_mains', unithandle, 0);

% Find minimum sampling interval
min_interval_ms = calllib('usbtc08', 'usb_tc08_get_minimum_interval_ms', unithandle);

% Capture Data

% Call the run function. This will continuously collect data (at the rate
% specified by "interval")
interval = calllib('usbtc08', 'usb_tc08_run', unithandle, ...
    min_interval_ms);

% Get the most recent value and
maxTime = 180;
figureCreated = 0;
tic; % Start timer
while toc < maxTime
    
    % [numValuesCJ, pBufferCJ, pBufferTimes, overflow] = calllib('usbtc08', ...
    %     'usb_tc08_get_temp', unithandle, pBufferCJ, pBufferTimes, numSamples, ...
    %     overflow, 0, 0, 0);
    
    % This will continually write the measured temperatures into the specified
    % buffers
    [numValuesCh1, pBufferCh1, pBufferTimes, overflow] = calllib('usbtc08', ...
        'usb_tc08_get_temp', unithandle, pBufferCh1, pBufferTimes, numSamples, ...
        overflow, 1, 0, 0);
    
    [numValuesCh2, pBufferCh2, pBufferTimes, overflow] = calllib('usbtc08', ...
        'usb_tc08_get_temp', unithandle, pBufferCh2, pBufferTimes, numSamples, ...
        overflow, 2, 0, 0);
    
    if ~figureCreated
        figure(1)
        set( gcf, 'Position', [1000, 300, 800, 550], 'Color', 'w' );
        set( gca, 'FontSize', 18, 'position', [0.12, 0.14, 0.8, 0.75] );
        hold all;
        grid on;
        title('Temperature vs. Time');
        xlabel('Time [s]')
        ylabel('Temperature [°C]')
        xlim([0, maxTime]);
        ylim([20, 40]);
        
        % Initialize plot vectors
        a1 = [];
        b1 = [];
        a2 = [];
        b2 = [];
        figureCreated = 1;
    end
    
    % Get updated plot vectors
    tVec = double(pBufferTimes(1:numValuesCh1))./1E3;
    tempVec1 = double( pBufferCh1(1:numValuesCh1) );
    tempVec2 = double( pBufferCh2(1:numValuesCh2) );
    
    if ~isempty( tempVec1 )
        
        % Delete old lines
        delete( findobj( 'Tag', 'TempLine' ) );
        
        % Store
        a1 = [a1, tVec'];
        b1 = [b1, tempVec1'];
                
        % Plot, display, and wait
        plot( a1, b1, 'k', 'LineWidth', 2.2 );
        plot( a2, b2, 'k', 'LineWidth', 2.2 );
        
        plot( tVec(end), tempVec1(end), 'ro', 'LineWidth', 2.2, ...
            'Tag', 'TempLine');
        
        if ~isempty( tempVec2 )
            a2 = [a2, tVec'];
            b2 = [b2, tempVec2'];
            plot( tVec(end), tempVec2(end), 'bo', 'LineWidth', 2.2, ...
                'Tag', 'TempLine');            
        end
        drawnow();
    else
        toc
    end
    
    pause( interval./1E3 );
    
end

%% Stop the Device

stop = calllib('usbtc08', 'usb_tc08_stop', unithandle);

error = calllib('usbtc08', 'usb_tc08_get_last_error', unithandle);


%% Close Connection to Unit and Unload Library

exit = calllib('usbtc08', 'usb_tc08_close_unit', unithandle);

unloadlibrary('usbtc08');



