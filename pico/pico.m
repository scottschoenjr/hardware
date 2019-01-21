%**************************************************************************
%
%  PicoScope 5242B Class
%
%   Requires API in './api/' directory and installation of the PicoScope
%   SDK in the default folder C:\Program Files\Pic
%
%
%             Scott Schoen Jr | Georgia Tech | 20190116
%
%**************************************************************************

classdef pico < handle
    
    
    properties
                
        % Harware properties
        Manufacturer
        ManufacturerID
        Model
        DeviceObject
        
        % Plotting options
        PlotOptions
        
                
    end
    
    % Properties used by the class. They can only be set by the user
    % through class functions.
    properties (SetAccess = 'protected')
        
      SampleRate
      Resolution
      VoltageRange
      Trigger
      Window
      
      % PicoScope-specific
      ConfigInfo
      EnumInfo
      MethodInfo
      Structs
      ThunkLibName
      BlockObject
      
    end
    
    % Set default properties
    properties (Constant, Hidden)
        
        % Sample rate
        DEFAULT_SAMPLE_RATE = 10E6; % [Hz] 
        
        % Resolution
        DEFAULT_DATA_RESOLUTION = 12; % [bit]  
        
        % Voltage range
        DEFAULT_VOLTAGE_RANGE = 2; % [V]
        
        % Trigger options
        DEFAULT_TRIGGER_CH = 2; % Channel to trigger on
        DEFAULT_TRIGGER_THRESHOLD = 1; % [V]
        DEFAULT_TRIGGER_CUTOFF = 5E-3; % [s]
        
        % Timing Options
        DEFAULT_PRETRIGGER_TIME = 20E-6;
        DEFAULT_POSTTRIGGER_TIME = 200E-6;
        
    end
    
    % Define user-accessible methods
    methods
        
        % Class constructor -----------------------------------------------
        function obj = pico()
            
            % Initialize values
            obj.Manufacturer = 'PicoScope';
            obj.ManufacturerID = ''; % No MATLAB designation
            obj.Model = '5242B';
            obj.DeviceObject = 'Not Initialized';
            
            % Plotting options
            obj.PlotOptions.ylim = [-1, 1]; % [V]
            
            % PicoScope properties
            obj.ConfigInfo = '';
            obj.EnumInfo = '';
            obj.MethodInfo = '';
            obj.Structs = '';
            obj.ThunkLibName = '';
            obj.BlockObject = ''; % Buffer to hold samples
            
            % PicoScope properties
            obj.SampleRate = 'Not Set';
            obj.Resolution = 'Not Set';
            obj.VoltageRange = 'Not Set';
            
            % Trigger properties
            obj.Trigger.channel = 'Not Set';
            obj.Trigger.threshold = 'Not Set';
            
            % Window Options
            obj.Window.preTrigger = 'Not Set';
            obj.Window.postTrigger = 'Not Set';
            
        end
        % -----------------------------------------------------------------
        
        
        % Function to connect to PicoScope.
        function [obj, result] = connectPico( obj )
            
            % Initialize
            result = '';
            
            % Try to create object
            try
                % Run setup
                addpath( genpath( './api' ) );
                run( 'PS5000aConfig.m' );
                
            catch
                result = 'Couldn''t create device object.';
                return;
            end
            
            % Try to connect to scope            
            try
                % Create a device object.
                ps5000aDeviceObj = icdevice('picotech_ps5000a_generic', '');
                
                % Connect device object to hardware.
                connect(ps5000aDeviceObj);
                
                % There may be a way suppress verbose output of the connect
                % command, but for now just "clc" it away.
                clc;
                
            catch
                
                result = 'Couldn''t connect to device.';
                return;
                
            end
            
            % Store device object
            obj.DeviceObject = ps5000aDeviceObj;
            
            % Store properties
            obj.ConfigInfo = ps5000aConfigInfo;
            obj.EnumInfo = ps5000aEnuminfo; % Lowercase for some reason...
            obj.MethodInfo = ps5000aMethodinfo;
            obj.Structs = ps5000aStructs;
            obj.ThunkLibName = ps5000aThunkLibName;
            
            % Set sample rate to default
            [~, rslt] = obj.setSampleRate( ...
                obj.DEFAULT_SAMPLE_RATE, obj.DEFAULT_DATA_RESOLUTION );
            if ~isequal( rslt, 0 )
                result = 'Couldn''t set default sampling rate.';
                return;
            else
                obj.SampleRate = obj.DEFAULT_SAMPLE_RATE;
            end
            
            % Set time window
            [~, rslt] = obj.setWindow( obj.DEFAULT_PRETRIGGER_TIME, ...
                obj.DEFAULT_POSTTRIGGER_TIME );
            if ~isequal( rslt, 0 )
                result = ['Couldn''t set time window. Scope said: ', rslt ];
                return;
            end
            
            % Set trigger options
            [~, rslt] = obj.setTrigger( obj.DEFAULT_TRIGGER_CH, ...
                obj.DEFAULT_TRIGGER_THRESHOLD );
            if ~isequal( rslt, 0 )
                result = ['Couldn''t set trigger. Scope said: ', rslt ];
                return;
            end
                        
            % If we make it here, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to set sampling rate
        function [obj, result] = ...
                setSampleRate( obj, sampleRate, resolution )
            
            % Initialize
            result = '';
            
            % If resolution not specified, set to 15 bit (max resolution
            % for highest sampling for two channels)
            if nargin < 3
                resolution = obj.DEFAULT_DATA_RESOLUTION;
            else
                
                % Make sure valid
                validResolution = ...
                    ismember( resolution, [8, 12, 14, 15, 16] );
                if ~validResolution
                    warning( 'Invalid resolution specified, using default' );
                    resolution = obj.DEFAULT_DATA_RESOLUTION;
                end
                
            end
            
            % Try to set device resolution
            try
                invoke( ...
                    obj.DeviceObject, 'ps5000aSetDeviceResolution', ...
                    resolution );
                clc; % Don't neet output here
            catch
                result = sprintf( ...
                    'Couldn''t set resolution to %2.2f-bit. Make sure it''s an integer.', ...
                    resolution );
                return;
            end
            
            % Find time base that allows minimum sample rate
            timebase = 128;
            minSampleRateFound = 0;
            
            while ~minSampleRateFound
            
                % Try newtime base
                try
                    [~, dt_ns, ~] = invoke( obj.DeviceObject, ...
                        'ps5000aGetTimebase2', timebase, 0);
                catch
                    result = 'Couldn''t set sampling rate. :( ';
                    return;
                end
                
                % Compute sample rate and see if it's high enough
                Fs = 1./( dt_ns./1E9 );
                if Fs >= sampleRate
                    minSampleRateFound = 1;
                    continue;
                end
                
                timebase = timebase - 1;
                
                if timebase < 2
                    result = 'No valid timebase found for this sampling rate. ';
                    return;
                end
               
            end
            
            
            % Update timebase
            obj.DeviceObject.timebase = timebase;

            % Update resolution and sample rate in class poperties
            obj.SampleRate = Fs;
            obj.Resolution = resolution;
            
%             % Re-establish the start and end times, since the scope does
%             % this by sample number, and the number of samples has changed.
%             [~, rslt] = obj.setWindow( ...
%                 obj.Window.preTrigger, obj.Window.preTrigger );
            
            % If we make it here, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to set trigger parameters
        function [obj, result] = setTrigger( obj, channel, threshold )
            
            % Initialize
            result = '';
                        
            % Set trigger channel
            if nargin < 3
                
                % Set to defaults
               threshold = obj.DEFAULT_TRIGGER_CUTOFF;
               
            elseif ~isa( threshold, 'double' ) || threshold < 0 || threshold > 5;
                
                 result = 'Invalid trigger cutoff specified.';
                 return;
                 
            end
            
            % Set trigger channel
            if nargin < 2
                
                % Set to defaults
               channel = obj.DEFAULT_TRIGGER_CH; 
               
            elseif ~isequal( channel, 1 ) && ~isequal( channel, 2 )
                
                 result = 'Invalid trigger channel specified.';
                 return;
                 
            end
            
            % For now, only make a rising trigger.
            direction = 2;
            
            % 0 is A, so 1 is B? Check this.
            channel = channel - 1; 
            
            % Create trigger group object
            triggerGroupObj = obj.DeviceObject.Trigger(1);
            
            % Automatically collect data after 1 s if no trigger. Set 0 to
            % wait indefinitely.
            triggerCutoff_s = obj.DEFAULT_TRIGGER_CUTOFF;
            triggerGroupObj.autoTriggerMs = 1E3.*triggerCutoff_s;
            
            % Set trigger settings 
            try
                [status.setSimpleTrigger] = invoke(triggerGroupObj, ...
                    'setSimpleTrigger', channel, threshold.*1E3, direction);
            catch
                result = [ 'Error setting trigger parameters. ', ...
                    'Scope said: ', status.setSimpleTrigger ];
                return;
            end
            
            obj.Trigger.channel = channel;
            obj.Trigger.threshodld = threshold;
            obj.Trigger.cutoff = triggerCutoff_s;    
            
            % Return success
            result = 0;
                        
        end
        % -----------------------------------------------------------------
        
        % Function to set trigger parameters
        function [obj, result] = setWindow( obj, startTime, endTime )
            
            % Initialize
            result = '';
                        
            % Set time to record after trigger
            if nargin < 3
                
                % Set to defaults
               endTime = obj.DEFAULT_POSTTRIGGER_TIME;
               
            elseif ~isa( endTime, 'double' )
                result = 'Invalid window length';
                return;
            end
            
            % Set time to record before trigger
            if nargin < 2
                
                % Set to defaults
               startTime = obj.DEFAULT_PRETRIGGER_TIME;
               
            elseif ~isa( startTime, 'double' )
                result = 'Invalid window length';
                return;
            end
                            
            % Capture a block of data and retrieve data values for 
            % channels A and B.
            blockGroupObj = obj.DeviceObject.Block(1);
            
            % Determine number of samples before and after trigger
            Fs = obj.SampleRate;
            nPre = round( startTime.*Fs );
            nPost = round( endTime.*Fs );
 
            obj.DeviceObject.numPreTriggerSamples = nPre;
            obj.DeviceObject.numPostTriggerSamples = nPost;
            
            % Store it to be accessed for collection later
            obj.BlockObject = blockGroupObj;    
            
            % Store updated values
            obj.Window.preTrigger = startTime;
            obj.Window.postTrigger = endTime;
                        
            % Return success
            result = 0;
                        
        end
        % -----------------------------------------------------------------
        
                
        
        % Function to display data.
        function [obj, result] = displayData( obj, channels, plotSpectrum )
            
            % Initialize
            result = '';
            
            % Don't plot spectrum by default
            if nargin < 3
                plotSpectrum = 0;
            end
            
            % Plot channel A by default
            if nargin < 2
               channels = 1; 
            elseif ~isequal( channels, 1 ) && ...
                    ~isequal( channels, 2 )&& ...
                    ~( ...
                       isequal( channels, [1,2] ) || ...
                       isequal( channels, [2,1] ) ...
                     );
                 result = 'Invalid channel(s) specified.';
                 return;
            end
            
            
            % Set data retreival values            
            startIndex = 0;
            segmentIndex = 0;
            
            % No downsampling
            downsamplingRatio = 1;
            downsamplingRatioMode = 0;            
            
            % Capture a block of data           
            [status.runBlock] = invoke(obj.BlockObject, 'runBlock', 0);
            [numSamples, overflow, chA, chB] = invoke( obj.BlockObject, ...
                'getBlockData', startIndex, segmentIndex, ...
                downsamplingRatio, downsamplingRatioMode);
            clc;
                        
            % Plot data values, calculate and plot FFT.
            tsFigure = figure(555);
            
            % Get time vector
            dt = 1./( double(obj.SampleRate) );
            N = double( numSamples );
            tVec = ( 0 : N-1 ).*dt;
            
            fVec = linspace(0, 1./dt, length(tVec) );
            
            % Channel A
            clf;
            chAAxes = axes();
            hold all;
            
            % Plot each channel specified
            if isequal( channels, 1 )
                plot(chAAxes, tVec.*1E6, chA);
            elseif isequal( channels, 2 )                
                plot(chAAxes, tVec.*1E6, chB);
            elseif isequal( channels, [1,2] ) || isequal( channels, [2,1] )
                plot(chAAxes, tVec.*1E6, chA);
                plot(chAAxes, tVec.*1E6, chB);
                legend( ' Ch. A', ' Ch. B' );
            end
                
            ylim(chAAxes, 1E3.*obj.PlotOptions.ylim ); 
            
            xlabel(chAAxes, 'Time [\mus]');
            ylabel(chAAxes, 'Voltage [mV]');
            grid(chAAxes, 'on');            
            
            % Plot FFT if desired
            if plotSpectrum
                
                spFig = figure(556);
                
                clf;
                spAxes = axes();
                hold all;
                
                if isequal( channels, 1 )
                    plot(spAxes, fVec./1E6, 20.*log10(abs(fft(chA))) );
                elseif isequal( channels, 2 )
                    plot(spAxes, fVec./1E6, 20.*log10(abs(fft(chB))) );
                elseif isequal( channels, [1,2] ) || isequal( channels, [2,1] )
                    plot(spAxes, fVec./1E6, 20.*log10(abs(fft(chA))) );
                    plot(spAxes, fVec./1E6, 20.*log10(abs(fft(chB))) );
                    legend( ' Ch. A', ' Ch. B' );
                end
                
                xlim([0, 5]);
                ylim([0, 120]);
                
                ylabel(spAxes, 'Level [Arb. dB]');
                xlabel(spAxes, 'Frequency [MHz]');
                grid(chAAxes, 'on');
            
            end
            
            % If we make it here, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        
        % Function to pass other API commands manually
        function [obj, output, result] = ...
                sendCommand( obj, cmdString )
            
            % Initialize
            output = '';
            result = '';
            
            % Call function
            try
                output = invoke( obj.DeviceObject, cmdString );
            catch
                result = 'Something went wrong passing command.';
                return;
            end
            
            % If we make it here, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        
        
    end
    
end