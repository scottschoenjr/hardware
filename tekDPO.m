%**************************************************************************
%
%  Tektronix Oscilloscope Class
%
%   Class definition for basic operation of Tektronix DPO 2022B Scope
%   System.
%
%
%              Scott Schoen Jr | Georgia Tech | 20170301
%
%**************************************************************************

classdef tekDPO < handle
    
    % Set scope properties
    properties
        Manufacturer
        ManufacturerID
        Model
        ResourceName
        DeviceObject
        Verbose
        ImmediateMeasurement
    end
    
    % Set constants
    properties ( SetAccess = private )
        
        % The voltage value is scaled by this amount before it is returned.
        % May be due to an impedance mismatch? Not sure.
        VOLTAGE_SCALING = 1E-2;
        
        % Set default number of acquisitions to average over in average
        % mode
        DEFAULT_NUMAVG = 64; % Must be power of 2 [2--256]
               
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
            obj.Verbose = 0; % Turn off by default
            obj.ImmediateMeasurement.type = '';
            obj.ImmediateMeasurement.channel = 0; % Flag to store the type of immediate measurement set
            
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
                    
                    % --- Verbose Mode ---
                    if obj.Verbose
                        disp( 'TEK: Treating as Agilent device.' );
                    end
                    % --------------------
                    
                catch
                    
                    % If that didn't work, just give up
                    result = 'Couldn''t create device object.';
                    return;
                    
                end
                
                result = [ 'Warning: Treating as an Agilent object. ', ...
                    '(Not sure if this will cause problems or not).' ];
                
            end
            
            % Update object properties
            obj.DeviceObject = scopeDeviceObject;
            
            % Create a large enough buffer to hold all data
            horizontalRecordLength = 1E6;
            bufferSize = 2.*8.*horizontalRecordLength;
            
            % Try and set default parameters
            try
                
                obj.DeviceObject.InputBufferSize = bufferSize;
                obj.DeviceObject.OutputBufferSize = bufferSize;
                
                % --- Verbose Mode ---
                if obj.Verbose
                    disp( [ 'TEK: I/O Buffer sizes set to ', ...
                        num2str(bufferSize), '.' ] );
                end
                % --------------------
                
            catch
                result = 'Couldn''t size buffers.';
            end
            
            scope.DeviceObject.RecordName = ...
                [datestr(clock, 'yyyymmddTHH:MM:SS'), '.txt'];
            
            % Try and connect to scope
            try
                fopen( obj.DeviceObject );
            catch
                result = 'Couldn''t connect to scope (fopen failed).';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                
                % --- Verbose Mode ---
                if obj.Verbose
                    disp( 'TEK: Connected to scope.' );
                end
                % --------------------
                
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
        
        % Function to set scope mode --------------------------------------
        function [ result ] = setAcquisitionMode( obj, mode, numAvg )
            
            % NOTE: DATA:COMPOSITION settings were troublesome. See here
            % https://forum.tek.com/viewtopic.php?t=136577
            
            % TODO: Add all modes.
            % DATA:COMPOSITION COMPOSITE_ENV is for envelope mode
                        
            % Check if valid mode specified
            if ~isa( mode, 'char' )
                result = [ 'WARNING: Acquisition mode not changed. ', ...
                    'Valid modes are: "Average" and "Sample".' ];
                return;
            end
            mode = lower( mode );
            
            switch mode
                case {'average', 'ave', 'avg', 'av', 'a'}
                    
                    % If we're in averaging mode, check for valid number of
                    % acquisitions to average over (must be power of 2
                    if nargin < 3
                        
                        numAvg = obj.DEFAULT_NUMAVG; % Default
                        
                        % --- Verbose Mode ----
                        if obj.Verbose
                            disp( [ ...
                                'TEK: Setting number of aquisitions', ...
                                ' to average over to ', ...
                                num2str( numAvg ), '.' ] ...
                                );
                        end
                        % --------------------
                        
                    elseif ~isa( numAvg, 'double' )
                        
                        numAvg = obj.DEFAULT_NUMAVG; % Default
                        
                        % --- Verbose Mode ----
                        if obj.Verbose
                            disp( [ ...
                                'TEK: Number of aquisitions must be a', ...
                                ' double. Setting to ', ...
                                num2str( numAvg ), '.' ] ...
                                );
                        end
                        % --------------------
                        
                    else
                        
                        % Make sure specified number of points is a power
                        % of 2
                        powerOf2 = 2.^( nextpow2( floor( abs(numAvg) ) ) );
                        % Make sure in valid range
                        numAvg = max( 2, min( powerOf2, 256 ) );
                        
                    end
                    
                    % Set to averaging mode
                    fprintf( obj.DeviceObject, 'ACQuire:MODe AVErage' ); 
                    
                    % Set number of acquisitions
                    numAcqCommand = ...
                        [ 'ACQuire:NUMAVg ', num2str( numAvg ) ];
                    fprintf( obj.DeviceObject, numAcqCommand );
                    
                    % Do this stupid thing. SaveData will fail (VISA
                    % timeout) if this setting isn't set when changing to
                    % averaging mode.
                    fprintf( obj.DeviceObject, ...
                        'DATA:COMPOSITION SINGULAR_YT' );
                    
                    % TODO: Add check to verify setting
                    
                    % --- Verbose Mode ----
                    if obj.Verbose
                        disp( [ ...
                            'TEK: Set to averaging mode with ', ...
                            num2str( numAvg ), ' acquisitions.' ] ...
                            );
                    end
                    % --------------------
                    
                    % Return success
                    result = 0;
                    return;
                    
                case {'sample', 'sampling', 'samp', 'sam', 's'}
                    
                    % Set to averaging mode
                    fprintf( obj.DeviceObject, 'ACQuire:MODe SAMple' ); 
                    
                    % Set composition mode to composite
                    fprintf( obj.DeviceObject, ...
                        'DATA:COMPOSITION COMPOSITE_YT' );
                    
                    % --- Verbose Mode ----
                    if obj.Verbose
                        disp( ...
                            'TEK: Set to sampling (continuous) mode.' ...
                            );
                    end
                    % --------------------
                    
                    % Return success
                    result = 0;
                    return;
                    
                    
                otherwise
                    
                    % --- Verbose Mode ----
                    if obj.Verbose
                        disp( ...
                            'TEK: Unknown mode, keeping current mode.' ...
                            );
                    end
                    % --------------------
                    
                    
                    % Warn user, and exit without changing anything
                    result = [ 'WARNING: Unknown acquisition mode ' ...
                        ' specified; mode was not changed. ', ...
                        'Valid modes are: "Average" and "Sample".' ];
                    
                    return;
                    
            end
                    
            
            % Get status from device object
            scopeStatus = obj.DeviceObject;
            
        end
        % -----------------------------------------------------------------
        
        
        % Function to get entire data record from scope -------------------
        %   Can also specify a subset of the data to get by specifying a
        %   number of points.
        function [ timeVector, signalVector, result ] = ...
                saveData( obj, channelNumber, numPoints, startPoint )
            
            
            % Clear previous buffers
            clrdevice( obj.DeviceObject );
            
            % Initialize
            timeVector = [];
            signalVector = [];
            result = NaN;
            
            % If not specified, use default inputs
            if nargin < 4 || startPoint == 0
                startPoint = 1; % Start at beginning of record
            end
            if nargin < 3
                numPoints = 0; % Use all points
            end
            if nargin < 2 || channelNumber == 0
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
            endPoint = numPoints + startPoint - 1;
            tooManyPoints = numPoints > endPoint;
            if tooManyPoints
                result = [ 'Must specify no more than ', ...
                    num2str(totalPoints), ...
                    ' points (or increase HOR:RECO).' ];
                return;
            end
            
            % Set start and stop points if necessary
            fprintf( obj.DeviceObject, ...
                [ 'DATA:START ', num2str( floor(startPoint) ) ] );
            fprintf( obj.DeviceObject, ...
                [ 'DATA:STOP ', num2str( floor(endPoint) ) ] );
            % --- Verbose Mode ---
            if obj.Verbose
                disp( ['TEK: Saving points ', ...
                    num2str( startPoint ), ' through ', ...
                    num2str( endPoint ), '.'] );
            end
            % --------------------
            
            
            %%%%%%%% Downsampling here may be most efficient %%%%%%%%%
            if 0
                sampleAt = 0.5E6;
                % If specified, set the sampling interval
                if ~isequal( sampleAt, 0 )
                    
                    % Get time interval from sampling frequency
                    dt = 1./sampleAt;
                    
                    % Convert to NR3 string format
                    exponent = floor( log10( dt ) );
                    multiplier = dt./10.^(exponent);
                    NR3String = [ num2str(multiplier), 'E', num2str(exponent) ];
                    
                    % Set sampling rate
                    obj.sendCommand( ['WFMInpre:XINcr ', NR3String], 0, 0 );
                    
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        
            % Turn off data header
            fprintf( obj.DeviceObject, ...
                'HEAD 0');
            % Set source channel
            fprintf( obj.DeviceObject, ...
                ['DATA:SOURCE CH', num2str(channelNumber)] );
            
            % ASCII encoding for now
            fprintf( obj.DeviceObject, ...
                'DATA:ENCDG ASCII' );
                       
            % --- Verbose Mode ---
            if obj.Verbose
                disp( 'TEK: Set data transfer format successfully.' );
            end
            % --------------------
            
            %             % Now set the receive parameters
            %             fprintf( obj.DeviceObject, ...
            %                 'WFMInpre:ENCDG RPB' );
            %             fprintf( obj.DeviceObject, ...
            %                 'WFMInpre:BYT_Nr 2' );
            %             fprintf( obj.DeviceObject, ...
            %                 'WFMInpre:BIT_Nr 2' );
            %
            %             % Set the number of points
            %             fprintf( obj.DeviceObject, ...
            %                 ['DATA:START ', num2str(startPoint)] );
            %             fprintf( obj.DeviceObject, ...
            %                 ['DATA:STOP ', num2str(numPoints)] );
            
            %             % Transfer waveform preamble
            %             fprintf( obj.DeviceObject, ...
            %                 'WFMOutpre?' );
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
            
            % --- Verbose Mode ---
            % Time tranfer if we're in verbose mode
            if obj.Verbose
                tic;
            end
            % --------------------
            
            % Get the data from the scope
            clrdevice( obj.DeviceObject ); % Clear buffers to be safe
            fprintf(obj.DeviceObject, 'CURVE?');
            rawSignalString = fscanf( obj.DeviceObject );
            rawSignal = str2num( rawSignalString );
            
            % --- Verbose Mode ---
            if obj.Verbose
                disp( ['TEK: Data transfer complete. Elapsed Time: ', ...
                    num2str( toc ), ' s.' ] );
            end
            % --------------------
            
            % Get the vertical scale of the scope. There are 8 divisions,
            % so get division and multiply
            clrdevice( obj.DeviceObject );
            fprintf( obj.DeviceObject, ...
                ['CH', num2str(channelNumber), ':VOLTS?'] );
            divisionHeight = str2double( fscanf(obj.DeviceObject) );
            verticalSpan = 8*divisionHeight;
            
            % Get offset
            clrdevice( obj.DeviceObject );
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
            
            % --- Verbose Mode ---
            % Time if we're in verbose mode
            if obj.Verbose
                disp( 'TEK: Obtained voltage scaling (vertical).' );
            end
            % --------------------
            
            % Now get time vector
            
            % Determine if we're in delay mode
            clrdevice( obj.DeviceObject );
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:MODE?');
            horizontalMode = fscanf( obj.DeviceObject );
            inDelayMode = strcmp(horizontalMode(1),'D');
            
            % Get the time scaling
            clrdevice( obj.DeviceObject );
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:MAIN:SCALE?');
            tspan_main = 10*( ...
                str2num( fscanf(obj.DeviceObject) ) ); % TDS380 saves tow screens/returns 0.5*scale
            
            % Get time delay
            clrdevice( obj.DeviceObject );
            fprintf( obj.DeviceObject, ...
                'HORIZONTAL:DELAY:SCALE?'); % Get horizontal scale
            tspan_delay = 10*( ...
                str2num( fscanf(obj.DeviceObject) ) ); % TDS380 saves tow screens/returns 0.5*scale
            
            clrdevice( obj.DeviceObject );
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
            
            % --- Verbose Mode ---
            % Time if we're in verbose mode
            if obj.Verbose
                disp( 'TEK: Obtained time scaling (horizontal).' );
            end
            % --------------------
            
            
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
            
%             % Get number of data points in the record
%             totalPointsString = ...
%                 obj.sendCommand( 'HORIZONTAL:RECORDLENGTH?' );
%             totalPoints = str2double( totalPointsString );
            
            % First, check the horizontal scale. The scope can sample up to
            % 1 GHz, so once we go below a certain time resolution, the
            % scope simply zooms in on the recorded data (rather than just
            % acquiring the same number of data points over less time).
            % However, the scope does not count this as "zooming", so we'll
            % have to check this condition separately from the ZOOM? query.
            sampleRateString = obj.sendCommand( 'HORIZONTAL:SAMPLERATE?' );
            sampleRate = str2double( sampleRateString );
            sampleRateMaxed = ( sampleRate == 1E9 );
            
            % If the sample rate is not maxed, the displayed data is treated
            % as the entire record, so we can just call saveData
            if ~sampleRateMaxed
                [ timeVector, signalVector, result ] = obj.saveData();
                return;
            end
            
            
            % Get screen width
            divisionString = obj.sendCommand('HORIZONTAL:SCALE?');
            displayedDataWidth = ...
                10.*str2double( divisionString ); % [s]
            
            % Get the width of the data record in seconds
            recordLengthPoints = str2double( ...
                obj.sendCommand( 'HORIZONTAL:RECORDLENGTH?' ) );
            recordSamplingRate = str2double( ...
                obj.sendCommand( 'HORIZONTAL:SAMPLERATE?' ) );
            recordDataWidth = ...
                recordLengthPoints./recordSamplingRate; % [s]
            
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
            samplesToSave = endingSample - startingSample;
            
            % Get the data
            [ rawTimeVector, signalVector, result ] = obj.saveData( ...
                channelNumber, samplesToSave, startingSample );
            
            % Now account for time scaling and offset from zoom
            dt = 1./sampleRate;
            scaledTimeVector = dt : dt : (samplesToSave.*dt);
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
        
        % Function to get current scope sampling frequency ----------------
        function [ samplingFrequency, result ] = ...
                getSamplingFrequency( obj )
            
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
                return;
            end
            
            % Compute and return the sampling frequency in hertz
            samplingFrequency = screenWidthSamples./screenWidthSeconds;
            
            % Return success
            result = 0;
            
            
        end
        % -----------------------------------------------------------------
        
        % Function to get the peak-to-peak value of the waveform ----------
        function [ pk2pkVoltage, result ] = getPeak2Peak( obj, channel )
            
            % Initialize
            pk2pkVoltage = NaN;
            result = NaN;
            
            % Default to channel 1
            if nargin < 2 || ~isa( channel, 'double' )
                channel = 1;
            elseif channel > 2 || channel < 1
                channel = 1;
            end
            channel = abs(round(channel)); % Just to be sure
            
            % Check if we need to make any changes to the measurement type,
            % channel, etc. If they're the same as ones we've already set,
            % we don't need to reset them each time.
            imChannelSet = obj.ImmediateMeasurement.channel == channel;
            imTypeSet = strcmp( obj.ImmediateMeasurement.type, 'PK2Pk' );
            
            % Add an "immediate measurement" which will not display on the
            % scope screen and will allow us to get the peak-to-peak
            % voltage.
            if ~imChannelSet
                try
                    
                    commandString = sprintf( ...
                        'MEASUrement:IMMed:SOUrce1 CH%1d.', ...
                        channel );
                    obj.sendCommand(commandString, 0, 0);
                    
                catch
                    
                    result = 'Couldn''t set immediate measurement type.';
                    return;
                    
                end
                obj.ImmediateMeasurement.channel = channel;
            end
            % --- Verbose Mode ---
            if obj.Verbose
                verboseString = sprintf( ...
                    'TEK: Added immediate measurement of CH%1d.', ...
                    channel );
                disp( verboseString );
            end
            % --------------------
            
            % Make it a peak-to-peak measurement
            if ~imTypeSet
                try
                    
                    obj.sendCommand('MEASUrement:IMMed:TYPe PK2Pk', 0, 0);
                    
                catch
                    
                    result = 'Couldn''t set immedaite measurement type.';
                    return;
                    
                end
                obj.ImmediateMeasurement.type = 'PK2Pk';
            end
            % Make sure measurement type was set properly
            measurementType = obj.sendCommand( 'MEASUrement:IMMed:TYPe?' );
            commandSent = strcmpi( measurementType(1:4), 'pk2p'  );
            if ~commandSent
                result = [ ...
                    'Unable to set immediate measurement type to ', ...
                    'peak-to-peak. Current type is "', ...
                    measurementType, '".' ...
                    ];
                return;
            end
            % --- Verbose Mode ---
            if obj.Verbose
                verboseString = sprintf( ...
                    'TEK: Set (immediate) PK2PK measurement of CH%1d.', ...
                    channel );
                disp( verboseString );
            end
            % --------------------
            
            % Now get the peak to peak voltage
            % --- Verbose Mode ---
            if obj.Verbose
                verboseString = sprintf( ...
                    'TEK: Getting PK2PK value of CH%1d.', ...
                    channel );
                disp( verboseString );
            end
            % --------------------
            try
                
                pk2pkVoltage = str2double( ...
                    obj.sendCommand('MEASUrement:IMMed:VALue?'));
                
            catch
                result = [ ...
                    'Unknown error while getting peak-to-peak value' ];
            end

            
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
            
            % Clear buffer and send command to scope
            clrdevice( obj.DeviceObject );
            fprintf( obj.DeviceObject, command );
            
            % Get reply
            pause( delay );
            if waitForResponse
                scopeReply = fscanf( obj.DeviceObject );
            else
                scopeReply = 0;
            end
            
        end
        
        
        
        % Class destructor
        function delete(obj)
            obj.disconnectScope();
        end
        
    end
end