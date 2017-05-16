% Class definition to make basic operations with Tektroniz DPO 2022B
% oscilloscope a bit easier.

classdef tekDPO < handle
    
    % Set scope properties
    properties
        Manufacturer
        ManufacturerID
        Model
        ResourceName
        DeviceObject
    end
    
    % Set constants
    properties (SetAccess = private, Constant = true )
        
        % The voltage value is scaled by this amount before it is returned.
        % May be due to an impedance mismatch? Not sure.
        VOLTAGE_SCALING = 1E-3;;
        
    end
    
    % Define class methods
    methods
        
        % Class constructor -----------------------------------------------
        function obj = tekDPO()
            
            % Initialize values
            obj.Manufacturer = 'Tektronix';
            obj.ManufacturerID = 'tek'; % Per MATLAB
            obj.Model = 'DPO 2022B';
            obj.ResourceName = 'USB0::0x0699::0x03A1::C030405::0';
            obj.DeviceObject = 'Not Initialized';
            
            % Delete any instances of objects using that resource name
            allObjects = instrfind;
            numObjects = length( allObjects );
            for objCount = 1:numObjects
                
                currentObj = allObjects( objCount );
                
                try
                    nameMatches = ~isempty( strfind(  ...
                        currentObj.Alias, obj.ResourceName(7:25) ) );
                catch
                    % If there's no alias field, it's not a VISA object
                    continue;
                end
                
                if nameMatches 
                    delete( allObjects(objCount) );
                end
            end
            
        end
        % -----------------------------------------------------------------

        
        % Function to connect to scope ------------------------------------
        function [obj, result] = connectScope( obj )
            
            % Initialize
            result = '';
            
            % Try to create object
            try
                scopeDeviceObject = ...
                    visa( obj.ManufacturerID, obj.ResourceName );
            catch
                
                % If it didn't work, try treating it as an Agilent object.
                % This seems to work for now
                try
                    scopeDeviceObject = ...
                        visa( 'agilent', obj.ResourceName );
                catch
                    
                    % If that didn't work, just give up
                    result = 'Couldn''t create device object.';
                    return;
                    
                end
                
                result = [ 'Warning: Treating as an Agilent object.\n', ...
                    '(Not sure if this will cause problems or not).' ];
                
            end
            
            % Update object properties
            obj.DeviceObject = scopeDeviceObject;
            
            % Create a large enough buffer to hold all data
            horizontalRecordLength = 1E6;
            inputBufferSize = 10.*horizontalRecordLength;
            
            % Try and set default parameters
            try
                obj.DeviceObject.InputBufferSize = inputBufferSize;
            catch
                result = 'Couldn''t create input buffer.';
            end
            
            % Try and connect to scope
            try
                fopen( obj.DeviceObject );
            catch
                result = 'Couldn''t connect to scope (fopen failed).';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Function to disconnect scope ------------------------------------
        function [obj, result] = disconnectScope( obj )
            
            % Initialize
            result = '';
            
            % Try to close
            try
                fclose( obj.DeviceObject );
            catch
                result = 'Something went wrong disconnecting scope!';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Function to display scope status --------------------------------
        function [scopeStatus] = status( obj )
            
            % Get status from device object
            scopeStatus = obj.DeviceObject;
            
        end
        % -----------------------------------------------------------------
        
        % Function to get entire data record from scope -------------------
        %   Can also specify a subset of the data to get by specifying a
        %   number of points.
        function [ timeVector, signalVector, result ] = ...
                saveData( obj, channelNumber, numPoints, startPoint )
            
            % Initialize
            timeVector = [];
            signalVector = [];
            result = NaN;
            
            % If not specified, use default inputs
            if nargin < 4
                startPoint = 1; % Start at beginning of record
            end
            if nargin < 3 
                numPoints = 0; % Use all points
            end
            if nargin < 2
                channelNumber = 1;
            end
            
            % Check inputs
            if ~isa( channelNumber, 'double' ) || ...
                    ~isa( numPoints, 'double' )
                result = ['Channel number and number of points must ', ...
                    'be positive integers.'];
                return;
            else
                numPoints = abs( round( numPoints ) );
                channelNumber = abs( round( channelNumber ) );
            end
            
            % Get width of screen
            totalPointsString = ...
                obj.sendCommand( 'HORIZONTAL:RECORDLENGTH?' ); 
            totalPoints = str2double( totalPointsString );
            
            % If default or 0 was entered, set to total width
            if numPoints == 0
                numPoints = totalPoints;
            end
            
            % Check if too many points were specified
            tooManyPoints = numPoints > (totalPoints + startPoint);
            if tooManyPoints
                result = [ 'Must specify no more than ', ...
                    num2str(totalPoints), ...
                    ' points (or increase HOR:RECORDLENGTH).' ];
                return;
            end
            
            % Clear previous buffer
            flushinput( obj.DeviceObject );
            
            % Turn off data header
            fprintf( obj.DeviceObject, ...
                'HEAD 0'); 
            % Set source channel
            fprintf( obj.DeviceObject, ...
                ['DATA:SOURCE CH', num2str(channelNumber)] );

%             % ASCII encoding for now
%             fprintf( obj.DeviceObject, ...
%                 'DATA:ENCDG ASCII' );
% 
            % Now set the receive parameters
            fprintf( obj.DeviceObject, ...
                'WFMInpre:ENCDG RPB' );
            fprintf( obj.DeviceObject, ...
                'WFMInpre:BYT_Nr 2' );
            fprintf( obj.DeviceObject, ...
                'WFMInpre:BIT_Nr 2' );
            
            % Set the number of points
            fprintf( obj.DeviceObject, ...
                ['DATA:START ', num2str(startPoint)] ); 
            fprintf( obj.DeviceObject, ...
                ['DATA:STOP ', num2str(numPoints)] ); 
            
            % Transfer waveform preamble
            fprintf( obj.DeviceObject, ...
                'WFMOutpre?' );
%             
%             % Use binary encoding (2 Byte samples, MSB first)
%             fprintf( obj.DeviceObject, ...
%                 'WFMOutre:ENCDG RPB' );
%             fprintf( obj.DeviceObject, ...
%                 'WFMOutre:BYT_Nr 2' );
%             fprintf( obj.DeviceObject, ...
%                 'DATA:ENCDG RPB; WIDTH 2' );
%             fprintf( obj.DeviceObject, ...
%                 'DATA:WIDTH 2' );
            
            
            % Get the data from the scope
            fprintf(obj.DeviceObject, 'CURVE?');
            rawSignalString = fscanf( obj.DeviceObject );
            rawSignal = str2num( rawSignalString );
            
            % Get the vertical scale of the scope. There are 8 divisions,
            % so get division and multiply
            fprintf( obj.DeviceObject, ...
                ['CH', num2str(channelNumber), ':VOLTS?'] ); 
            divisionHeight = str2double( fscanf(obj.DeviceObject) );
            verticalSpan = 8*divisionHeight;
            
            % Get offset
            fprintf( obj.DeviceObject, ...
                [ 'CH', num2str(channelNumber), ':POS?'] );
            verticalOffset = (1./8)*(  ...
                str2double( fscanf(obj.DeviceObject) )*(verticalSpan./8) ...
                );
            
            % Assemble voltage trace
            signalVoltage = ...
                rawSignal.*(verticalSpan./2) - verticalOffset;
            
            % Scale by appropriate amount
            signalVoltage = signalVoltage.*obj.VOLTAGE_SCALING; 
            
            % Now get time vector
            
            % Determine if we're in delay mode
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:MODE?');
            horizontalMode = fscanf( obj.DeviceObject );
            inDelayMode = strcmp(horizontalMode(1),'D');
            
            % Get the time scaling
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:MAIN:SCALE?');
            tspan_main = 10*( ...
                str2num( fscanf(obj.DeviceObject) ) ); % TDS380 saves tow screens/returns 0.5*scale
            
            % Get time delay
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:DELAY:SCALE?'); % Get horizontal scale
            tspan_delay = 10*( ...
                str2num( fscanf(obj.DeviceObject) ) ); % TDS380 saves tow screens/returns 0.5*scale
            
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:DELAY:TIME?'); %Get delay
            tdel = str2num( fscanf(obj.DeviceObject) );
            
            % Assemble time vector
            if inDelayMode
                tmax = tdel + tspan_delay;
                t = linspace( tmax - tspan_delay, tmax, ...
                    length(signalVoltage) );
            else
                tmax = tspan_main;
                t = linspace( tmax - tspan_main, tmax, ...
                    length(signalVoltage));
            end
            
            % Return variables
            timeVector = t;
            signalVector = signalVoltage;
            result = 0;

            
        end
        % -----------------------------------------------------------------
        
        % Function to get data displayed on screen -------------------
        function [ timeVector, signalVector, result ] = ...
                getScreenData( obj, channelNumber )
            
            % Initialize
            timeVector = [];
            signalVector = [];
            result = NaN;
            
            % If not specified, use default inputs
            if nargin < 2
                channelNumber = 1;
            end
            
            % Check inputs
            if ~isa( channelNumber, 'double' ) || ...
                    ( channelNumber > 2 ) || ( channelNumber < 1 )
                result = ['Channel number must be 1 or 2.'];
                return;
            else
                channelNumber = abs( round( channelNumber ) );
            end
            
            % Get number of data points in the record
            totalPointsString = ...
                obj.sendCommand( 'HORIZONTAL:RECORDLENGTH?' );
            totalPoints = str2double( totalPointsString );
            
            % First, check the horizontal scale. The scope can sample up to
            % 1 GHz, so once we go below a certain time resolution, the
            % scope simply zooms in on the recorded data (rather than just
            % acquiring the same number of data points over less time).
            % However, the scope does not count this as "zooming", so we'll
            % have to check this condition separately from the ZOOM? query.
            sampleRateString = obj.sendCommand( 'HORIZONTAL:SAMPLERATE?' );
            sampleRate = str2double( sampleRateString );
            sampleRateMaxed = ( sampleRate == 1E9 );
            
            % If the sample rate is maxed, the displayed data is treated
            % as the entire record, so we can just call saveData
            if sampleRateMaxed
                [ timeVector, signalVector, result ] = ...
                    obj.saveData( channelNumber, 0, 1 );
                return;
            end
                
            
            % Check the zoom state. If we're zoomed, we'll need to account
            % for this
            zoomedIn = str2double( obj.sendCommand('ZOOM:ZOOM:STATE?') );
            
            % If we are zoomed in...
            if zoomedIn
                
                % Get width of displayed data in seconds
                divisionString = obj.sendCommand('ZOOM:ZOOM:HORIZONTAL:SCALE?');
                displayedDataWidth = ...
                    10.*str2double( divisionString ); % [s]
                
                % Get the width of the data record in seconds
                recordLengthPoints = str2double( ...
                    obj.sendCommand( 'HORIZONTAL:RECORDLENGTH?' ) );
                recordSamplingRate = str2double( ...
                    obj.sendCommand( 'HORIZONTAL:SAMPLERATE?' ) );
                recordDataWidth = recordLengthPoints./recordSamplingRate;
                
                % Get the fraction of the total data displayed
                fractionOfRecordDisplayed = ...
                    displayedDataWidth./recordDataWidth;
                
                % Get position of the center of the window
                percentOfRecordDisplayed = 100.*fractionOfRecordDisplayed;
                % Returns the percentage of the record to the left of the
                % window center
                percentOffset = str2double( ...
                    obj.sendCommand( 'ZOOM:ZOOM:HORIZONTAL:POSITION?' ) );
                % This is then the offset of the left of the window...
                firstPointFraction = ...
                    ( percentOffset - percentOfRecordDisplayed./2 )./100;
                % And the right of the window
                lastPointFraction = ...
                    ( percentOffset + percentOfRecordDisplayed./2 )./100;
                
                
                % Now compute the first and last samples to keep
                startingSample = max( ...
                    floor( firstPointFraction.*recordLengthPoints ), ...
                    1 );
                endingSample = min( ...
                    ceil( lastPointFraction.*recordLengthPoints ), ...
                    recordLengthPoints );
                
                % Get the data
                [ rawTimeVector, signalVector, result ] = ...
                    obj.saveData( channelNumber, ...
                    startingSample, endingSample );
                
                % Now account for time scaling and offset from zoom
                scaledTimeVector = rawTimeVector.*fractionOfRecordDisplayed;
                timeOffset = firstPointFraction.*max( rawTimeVector );
                timeVector = timeOffset + scaledTimeVector;
                
                %%% TODO %%%
                % Add "zoomInfo" struct to be returned which includes
                % information about the offset, zoom level, etc. Not sure
                % it's necessary right now, but might be useful at some
                % point.
                %%%%%%%%%%%%
                
                return;
                
            end
            
            
            % If the screen isn't zoomed at all, just get all the data
            [ timeVector, signalVector, result ] = ...
                obj.saveData( channelNumber, 0, 1 );
            
            
        end
        % -----------------------------------------------------------------
        
        % Function to set scope width -------------------------------------
        function [ result ] = setScreenWidth( obj, screenWidth )
            
            % Initialize
            result = NaN;
            
            % Check inputs
            if ~isa( screenWidth, 'double' )
                result = 'Screen width must be a positive number.';
                return;
            elseif screenWidth < 1E-9 || screenWidth > 1000
                result = 'Screen width must be between 1 ns and 1000 s.';
                return;
            end
            
            % Compute number of seconds per division
            secondsPerDivision = screenWidth./10;
            
            % Convert to NR3 format (decimal exponent)
            exponent = floor( log10( secondsPerDivision ) );
            multiplier = secondsPerDivision./10.^(exponent);
            NR3String = [ num2str(multiplier), 'E', num2str(exponent) ];
            
            % Assemble and pass scale command
            scaleCommand = [ 'HORIZONTAL:SCALE ', NR3String ];
            fprintf( obj.DeviceObject, scaleCommand ); 
            
            % Return success
            result = 0;

            
        end
        % -----------------------------------------------------------------
        
        % Function to get current scope screen width ---------------------
        function [ screenWidth, result ] = getScreenWidth( obj )
            
            % Initialize
            screenWidth = NaN;
            result = NaN;
            
            try
                
                % Get the number of seconds per division
                secondsPerDivisionString = ...
                    obj.sendCommand( 'HORIZONTAL:SCALE?' );
                secondsPerDivision = ...
                    str2double( secondsPerDivisionString );
                
                % Get total screen width
                screenWidth = secondsPerDivision.*10; % 10 div. per screen
                
                
                % Return success
                result = 0;
                
            catch
                result = ...
                    'Something went wrong trying to get the screen width';
            end

            
        end
        % -----------------------------------------------------------------
        
        % Function to get current scope sampling frequency ---------------------
        function [ samplingFrequency, result ] = getSamplingFrequency( obj )
            
            % Initialize
            samplingFrequency = NaN;
            result = NaN;
            
            % Get screen width
            [ screenWidthSeconds, result ] = getScreenWidth( obj );
            if ~isequal( result, 0 )
                return;
            end
            
            % Get the width of the screen in samples
            try
                
                % Get the number of seconds per division
                horizontalResolutionString = ...
                    obj.sendCommand( 'HORIZONTAL:RESOLUTION?' );
                screenWidthSamples = ...
                    str2double( horizontalResolutionString );
                
            catch
                result = [ ...
                    'Something went wrong trying to get ', ...
                    'the screen resolution.' ];
            end
            
            % Compute and return the sampling frequency in hertz
            samplingFrequency = screenWidthSamples./screenWidthSeconds;
            
            % Return success
            result = 0;

            
        end
        % -----------------------------------------------------------------
        
        % Function to handle arbitrary scope commands and return the
        % scope's output
        function [scopeReply] = ...
                sendCommand( obj, command, delay, waitForResponse )
            
           % If the delay isn't specified, don't use one
           if nargin < 3 || ~isa( delay, 'double' )
              delay = 0; 
           end
           
           % Some commands do not elicit a response from the scope. 
           % For these cases, we don't to wait for a timeout, so set the
           % flag here. If not specified, wait for response
           if nargin < 4 || ~isa( waitForResponse, 'double' )
              waitForResponse = 1; 
           end
            
           % Make sure scope is connected
           if isa( obj.DeviceObject, 'string' )
               scopeReply = ...
                   'Not connected to scope. Run .connectScope first';
               return;
           end
              
           % Make sure we're sending a string
           if ~isa( command, 'char' )
               scopeReply = 'Make sure command is a string.';
               return;
           end
           
           % Send command to scope
           fprintf( obj.DeviceObject, command );
           
           % Get reply
           pause( delay );
           if waitForResponse
               scopeReply = fscanf( obj.DeviceObject );
           else
               scopeReply = 0;
           end
            
        end
    end
end