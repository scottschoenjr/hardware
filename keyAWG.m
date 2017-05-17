% *************************************************************************
%
% Class for operation of the Keysight 33600A Arbitrary Waveform Generator
%
%       Arpit Patel & Scott Schoen Jr | Georgia Tech | 20170516
%
% *************************************************************************

classdef keyAWG < handle
    
    % Set AWG properties
    properties
        Manufacturer
        ManufacturerID
        ModelCode
        ResourceName
        DeviceObject
    end
    
    
    methods
        
        % Class constructor -----------------------------------------------
        function obj = keyAWG()
            
            % Initialize values
            obj.Manufacturer = 'Agilent Technologies';
            obj.ManufacturerID = 'agilent'; % Per MATLAB
            obj.ModelCode = '0x4807';
            obj.ResourceName = 'USB0::0x0957::0x4807::MY53300703::0::INSTR';
            obj.DeviceObject = 'Not Initialized';
            
            % % Delete any instances of objects using that resource name
            allObjects = instrfind;
            numObjects = length( allObjects );
            for objCount = 1:numObjects
                currentObj = allObjects( objCount );
                try
                    nameMatches = ~isempty( strfind(  ...
                        currentObj.ResourceName, obj.ResourceName ) );
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
        function [obj, result] = connectWaveGen( obj )
            
            % Initialize
            result = '';
            
            % Try to create object
            try
                deviceObject = ...
                    visa( obj.ManufacturerID, obj.ResourceName );
            catch
                result = 'Couldnt create device object.';
                return;
            end
            
            % Update object properties
            obj.DeviceObject = deviceObject;
            
            % Specify buffer sizes
            inputBufferSize = 2^10; % Shouldn't need any, but still.
            outputBufferSize = 2^16; 
            
            % Try and set default parameters
            try
                obj.DeviceObject.InputBufferSize = inputBufferSize;
                obj.DeviceObject.OutputBufferSize = outputBufferSize;
            catch
                result = 'Couldn''t allocate buffers.';
            end
            
            % Try and connect to wavegen
            try
                fopen( obj.DeviceObject );
            catch
                result = 'Couldn''t connect to AWG (fopen failed).';
                return;
            end
            
            % Try and clear wavegen
            try
                fprintf (obj.DeviceObject, '*RST');
                fprintf (obj.DeviceObject, '*CLS');
            catch
                result = 'Couldn''t clear the wavegen';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                result = 0;
            end
        end
        
        % -----------------------------------------------------------------
        
        % Function to disconnect wavegen-----------------------------------
        function [obj, result] = disconnectWaveGen( obj )
            
            % Initialize
            result = '';
            
            % Try to close
            try
                fclose( obj.DeviceObject );
            catch
                result = 'Something went wrong disconnecting AWG!';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Function to generate a sine wave --------------------------------
        function [ result ]  = ...
                generateSineWave( obj, frequency, amplitude, offset)
            
            
            % Format as decimals
            fmtSpec = '%08.3f';
            
            % Assemble command
            command = ['APPLY:SIN ', ...
                sprintf( fmtSpec, frequency ), ',', ...
                sprintf( fmtSpec, amplitude ), ',', ...
                sprintf( fmtSpec, offset ) ...
                ];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        
        % Function to generate a pulsed waveform --------------------------
        function [ result ]  = ...
                generatePulseWave( obj, frequency, amplitude, offset)
            
            
            % Format as decimals
            fmtSpec = '%08.3f';
            
            % Assemble command
            command = ['APPLY:PULS ', ...
                sprintf( fmtSpec, frequency ), ',', ...
                sprintf( fmtSpec, amplitude ), ',', ...
                sprintf( fmtSpec, offset ) ...
                ];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to set burst parameters --------------------------------
        function [ result ] = setBurstParameters( obj, ...
                numCycles, period, phase, mode)
            
            % Parse user inputs
            mode   = lower(mode);
            
            % If not (or wrongly) specified, set mode to trigger mode
            invalidMode = ismember( mode, ...
                {'trigger','trig','t', 'gated','gate','g'} );
            if nargin < 5 || invalidMode
                mode = 'trigger';
            end
            
            % Use trigger mode unless gated mode is specified. If
            % specifcation is unrecognized, trigger mode is used.
            switch mode
                case {'trigger','trig','t'}
                    modeCommand = 'BURS:MODE TRIG';
                case {'gated','gate','g'}
                    modeCommand = 'BURS:MODE GAT';
            end
            modeResult = sendCommand( obj, modeCommand );
            
            % If we got an error, return here
            if ~isequal( modeResult, 0 )
                result = [ 'Couldn''t set mode to ', mode, '. ', ...
                    'AWG said: "', modeResult, '".'];
                return;
            end
            
            % Format number inputs as decimals
            fmtSpec = '%08.3f';
            
            % Set number of cycles per burst
            numCycles  = sprintf( fmtSpec, numCycles);
            burstCommand = ['BURS:NCYC ' numCycles];
            cycleResult = sendCommand( obj, burstCommand );
            
            % If we got an error, return here
            if ~isequal( cycleResult, 0 )
                result = [ 'Couldn''t set number of cycles to ', ...
                    num2str(numCycles), '. ', ...
                    'AWG said: "', cycleResult, '".'];
                return;
            end
            
            % Set period
            period  = sprintf( fmtSpec, period);
            periodCommand = ['BURSt:INTernal:PERiod ' period];
            periodResult = sendCommand( obj, periodCommand );
            
            % If we got an error, return here
            if ~isequal( periodResult, 0 )
                result = [ 'Couldn''t set period to ', ...
                    num2str(period), '. ', ...
                    'AWG said: "', periodResult, '".'];
                return;
            end
            
            % Set phase
            phase  = sprintf( fmtSpec, phase );
            phaseCommand = ['BURSt:PHASe ' phase];
            phaseResult = sendCommand( obj, phaseCommand );
            
            % If we got an error, return here
            if ~isequal( periodResult, 0 )
                result = [ 'Couldn''t set phase to ', ...
                    num2str(phase), '. ', ...
                    'AWG said: "', phaseResult, '".'];
                return;
            end

            % Set trigger source and enable bust mode
            sendCommand( obj,'TRIGger:SOURce IMMediate');
            sendCommand( obj,'BURSt:STATe ON');
            
            % Return success
            result = 0;
            
        end
        
        % Function to set voltage -----------------------------------------
        function [result] = setVoltage( obj, voltage )
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % TODO: Set voltage specification 
            % (e.g., peak-to-peak, RMS, etc.)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Format as decimal
            fmtSpec = '%08.3f';
            
            % Assemble command
            command = ['VOLT ', ...
                sprintf( fmtSpec, voltage ) ...
                ];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to set frequency ---------------------------------------
        function [result] = setFrequency( obj, frequency )
            
            % Format as decimal
            fmtSpec = '%08.3f';
            
            % Assemble command
            command = ['FREQ ', ...
                sprintf( fmtSpec, frequency ) ...
                ];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to set output load -------------------------------------
        function [result] = setOutputLoad( obj, outputLoad )
                        
            % Format as decimal
            fmtSpec = '%08.3f';
            
            % Assemble command
            command = ['OUTPUT:LOAD ', ...
                sprintf( fmtSpec, outputLoad ) ...
                ];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to turn on output --------------------------------------
        function [result] = outputOn( obj )
            
            % Assemble command
            command = ['OUTP 1'];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to turn off output -------------------------------------
        function [result] = outputOff( obj )
            
            % Assemble command
            command = ['OUTP 0'];
            
            % Send to AWG
            result = sendCommand( obj, command );
            
        end
        % -----------------------------------------------------------------
        
        % Function to check currently programmed waveform -----------------
        function [result, signal] = checkSignal(obj)
            
            % Pass query (wait 1 ms for response)
            awgReply = sendCommand( obj, 'APPLy?', 1E-3, 1 );
            
            try
                % Parse out reply parameters
                reply = strsplit( awgReply, ' ' );
                
                signalType = reply{1}(2:end);
                
                parameters = strsplit(reply{2},',');
                frequency = str2double(parameters{1});
                amplitude = str2double(parameters{2});
                
                % Looks like return is truncated with ", so don't read this
                % character to avoid errors
                quotesIndex = strfind( parameters{3}, '"' );
                if ~isempty( quotesIndex )
                    offset = str2double( ...
                        parameters{3}(1:quotesIndex - 1) );
                else
                    offset = str2double( parameters{3} );
                end
                
                % Return struct
                signal.type = signalType;
                signal.frequency = frequency;
                signal.amplitude = amplitude;
                signal.offset = offset;
                signal.awgReply = reply;
                
                % Return success
                result = 0;
                
            catch
                
                % If we couldn't parse, just return what we got
                signal = NaN;
                result = ['Couldn''t parse output. The AWG said: "', ...
                    awgReply ];
                
            end
            
        end
        % ----------------------------------------------------------------
        
        % Function to send command to AWG and wait for a reply -----------
        function [ awgReply ] = ...
                sendCommand( obj, command, delay, waitForResponse )
            
            % If the delay isn't specified, don't use one
            if nargin < 3 || ~isa( delay, 'double' )
                delay = 0;
            end
            
            % Some commands do not elicit a response from the AWG.
            % For these cases, we don't to wait for a timeout, so set the
            % flag here. If not specified, wait for response
            if nargin < 4 || ~isa( waitForResponse, 'double' )
                waitForResponse = 0;
            end
            
            % Make sure scope is connected
            if isa( obj.DeviceObject, 'string' )
                awgReply = ...
                    'Not connected to AWG. Run .connectWaveGen first';
                return;
            end
            
            % Make sure we're sending a string
            if ~isa( command, 'char' )
                awgReply = 'Command must be a string.';
                return;
            end
            
            % Send command to scope
            fprintf( obj.DeviceObject, command );
            
            % Get reply
            pause( delay );
            if waitForResponse
                awgReply = fscanf( obj.DeviceObject );
            else
                awgReply = 0;
            end
            
        end
        % ----------------------------------------------------------------
        
    end
    
end