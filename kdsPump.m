%**************************************************************************
%
%  KDScientific Pump Class
%
%   Class definition for basic operation of the kdScientific Syringe Pump
%   model 110.
%
%
%      Scott Schoen Jr & Lucas Salvador | Georgia Tech | 20170621
%
%**************************************************************************

classdef kdsPump < handle
    
    % Set pump properties
    properties
        Manufacturer
        ManufacturerID
        Model
        ResourceName
        DeviceObject
        ComSettings
        Address
        WaitTime
        Syringe
    end
    
    % Set static properties
    properties (Constant, Hidden)
        % Any persistent properties
        
    end
    
    % Define user-accessible methods
    methods
        
        % Class constructor -----------------------------------------------
        function obj = kdsPump()
            
            % Initialize values
            obj.Manufacturer = 'KDScientific';
            obj.ManufacturerID = ''; % No MATLAB designation
            obj.Model = '110';
            obj.ResourceName = 'COM4';
            obj.DeviceObject = 'Not Initialized';
            obj.Address = 0; % Will change response format if not 0!
            obj.WaitTime = 0.2; % How long to wait after each command
            
            % Create syringe struct to store information about syringe
            syringeStruct = struct( ...
                'Volume_ml', NaN, ...
                'InnerDiameter_mm', NaN, ...
                'Name', '' ...
                );
            obj.Syringe = syringeStruct;
            
            % COM Port default settings
            obj.ComSettings.ComPort = 4;
            obj.ComSettings.BaudRate = 115200;
            obj.ComSettings.DataBits = 8;
            obj.ComSettings.Parity = 'none';
            obj.ComSettings.StopBits = 1;
            obj.ComSettings.Terminator = 'CR';
            obj.ComSettings.Timeout = 0.1;
            
            % TODO: Add set.ComSettings function to check values when
            %       updated (e.g., that Terminator is a string).
            
            
            % Delete any instances of objects using that resource name
            allObjects = instrfind;
            numObjects = length( allObjects );
            for objCount = 1:numObjects
                
                currentObj = allObjects( objCount );
                try
                    nameMatches = ~isempty( ...
                        strfind( currentObj.Port, obj.ResourceName ) );
                catch
                    % In this case, object doesn't have a Port field. Since
                    % it's not a velmex object then, just continue
                    continue;
                end
                
                % If we do find an existing Velmex object, just delete it
                if nameMatches
                    delete( allObjects(objCount) );
                end
            end
            
        end
        % -----------------------------------------------------------------
        
        
        % Function to connect to KDS 110 with a (virtualized) serial
        % connection. It's actually over USB.
        function [obj, result] = connectPump( obj )
            
            % Initialize
            result = '';
            
            % Try to create object
            try
                comPort = obj.ResourceName;
                pumpObject = serial( comPort, ...
                    'Baudrate', obj.ComSettings.BaudRate, ...
                    'Databits', obj.ComSettings.DataBits, ...
                    'Parity', obj.ComSettings.Parity, ...
                    'StopBits', obj.ComSettings.StopBits, ...
                    'Terminator', obj.ComSettings.Terminator, ...
                    'Timeout', obj.ComSettings.Timeout ...
                    );
            catch
                result = 'Couldn''t create device object.';
                return;
            end
            
            % Update object properties
            obj.DeviceObject = pumpObject;
            
            % Open port
            try
                fopen( obj.DeviceObject );
            catch
                result = [ ...
                    'Couldn''t open serial connection with the pump. ', ...
                    'Tried on ', obj.ResourceName, '. Ensure that ', ...
                    'this is the correct port.' ...
                    ];
                return;
            end
            
            % Make sure port was opened properly
            portOpenedSuccessfully = isequal( ...
                obj.DeviceObject.status, 'open' );
            if ~portOpenedSuccessfully
                % Otherwise, something went wrong...
                result = [ 'Couldn''t open port ', obj.ResourceName, '.' ];
                return;
            end
            
            % Set address to 0
            try
                addressString = [ 'address ', num2str( obj.Address ) ];
                fprintf( obj.DeviceObject, addressString ); % Set
                fprintf( obj.DeviceObject, 'address' ); % Query
                fscanf( obj.DeviceObject );

            catch
                % If something went wrong...
                result = [ 'Couldn''t set pump address to 0.' ];
                return;
            end
            
            % If we make it here, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to stop pump -------------------------------------------
        function [result, response] = kill( obj )
            
            
            % Initialize
            result = '';
            response = '';
                       
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'SHUT OFF MANUALLY! Pump not connected!';
                return;
            end
            
            % Send command
            killCommand = 'stop';
            [response, ~] = sendCommandAndWait( obj, killCommand, 0, 0 );
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
         % Function to set the syringe diameter ---------------------------
        function [result, response] = setSyringeDiameter( obj, diameter_mm )
            
            
            % Initialize
            result = '';
            response = '';
                       
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Pump not connected. First run .connectPump.';
                return;
            end
            
            % Check inputs
            if ~isa( diameter_mm, 'double' )
                result = ...
                    'Diameter must be a double specified in millimeters';
                return;
            end
            
            % Store diameter to syringe struct
            obj.Syringe.InnerDiameter_mm = diameter_mm;
            
            % Send command
            diameterCommand = sprintf( 'diameter %06.2f', diameter_mm );
            [response, ~] = ...
                sendCommandAndWait( obj, diameterCommand, 0, 0 );
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to set the syringe parameters --------------------------
        function [result, response] = setSyringeParameters( ...
                obj, diameter_mm, svolume_ml )
            
            
            % Initialize
            result = '';
            response = '';
                       
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Pump not connected. First run .connectPump.';
                return;
            end
            
            % Check inputs
            if ~isa( diameter_mm, 'double' )
                result = ...
                    'Diameter must be a double specified in millimeters.';
                return;
            end
            if ~isa( svolume_ml, 'double' )
                result = ...
                    'Syringe volume must be a double specified in milliliters.';
                return;
            end
            
            % Store properties to syringe struct
            obj.Syringe.InnerDiameter_mm = diameter_mm;
            obj.Syringe.Volume_ml = svolume_ml;
            
            % Send command
            diameterCommand = sprintf( 'diameter %06.2f', diameter_mm );
            [response1, ~] = ...
                sendCommandAndWait( obj, diameterCommand, 0, 0 );
            svolumeCommand = sprintf( 'svolume %06.2f ml', svolume_ml );
            [response2, ~] = ...
                sendCommandAndWait( obj, svolumeCommand, 0, 0 );
            response = [{response1},{response2}];            
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        
        % -----------------------------------------------------------------
        
        % Function to set continuous mode ---------------------------------
        function [result, response] = ...
                runContinuous( obj, volume_ml, rate_mlPerMin )            
            
            % Initialize
            result = '';
            response = '';
            
            
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Must connect device (.connectPump) first.';
                return;
            end
            
            % Make sure syringe properties have been set
            syringeNotInitialized = ...
                isnan( obj.Syringe.Volume_ml ) || ...
                isnan( obj.Syringe.InnerDiameter_mm ) ;
            if syringeNotInitialized
                result = 'Must set syringe parameters first.';
                return;
            end
            
            % Set device to infuse-withdraw mode
            modeCommand = '@load qs iw';
            [rslt, rply] = obj.sendKdsCommand( modeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set mode. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Set device target volume
            targetVolumeCommand = sprintf( ....
                '@tvolume %6.2f ml', volume_ml );
            [rslt, rply] = obj.sendKdsCommand( targetVolumeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set target volume. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Set the input and output rates
            infuseRateCommand = sprintf( ....
                '@irate %6.2f ml/min', rate_mlPerMin );
            withdrawRateCommand = sprintf( ....
                '@wrate %6.2f ml/min', rate_mlPerMin );
            [rslt, rply] = obj.sendKdsCommand( infuseRateCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set infuse rate. Pump said: ', ...
                    rply ];
                return;
            end
            [rslt, rply] = obj.sendKdsCommand( withdrawRateCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set withdraw rate. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Send command
            runCommand = 'run';
            % For some reason the run command doesn't work sometimes. If
            % you take one or the other of these run commands away, it 
            % won't always work, but with both it seems to work always.
            [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
            [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
            
            % We're off and running, so return and cede command back to
            % main script
            result = 0;
            return;

            
        end
        % -----------------------------------------------------------------
        
        % Function to infuse a specified amount ---------------------------
        function [result, response] = infuse( obj, ...
                volume_ml, rate_mlPerMin, infuseOrWidthdraw )            
            
            % Initialize
            result = '';
            response = '';            
            
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Must connect device (.connectPump) first.';
                return;
            end
            
            % Make sure syringe properties have been set
            syringeNotInitialized = ...
                isnan( obj.Syringe.Volume_ml ) || ...
                isnan( obj.Syringe.InnerDiameter_mm ) ;
            if syringeNotInitialized
                result = 'Must set syringe parameters first.';
                return;
            end
            
            % Set pump to infuse mode
            modeCommand = '@load qs i';
            [rslt, rply] = obj.sendKdsCommand( modeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set to infuse mode. ', ...
                    'Pump said: ', rply ];
                return;
            end
            
            % Set device target volume
            targetVolumeCommand = sprintf( ....
                'tvolume %6.4f ml', volume_ml );
            [rslt, rply] = obj.sendKdsCommand( targetVolumeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set target volume. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Set the flow rate
            rateCommand = sprintf( ....
                'irate %6.2f ml/min', rate_mlPerMin );

            % Pass command
            [rslt, rply] = obj.sendKdsCommand( rateCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set flow rate. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Send command
            runCommand = 'run';
            % For some reason the run command doesn't work sometimes. If
            % you take one or the other of these run commands away, it 
            % won't always work, but with both it seems to work always.
            [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
%             [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
            
            % We're off and running, so return and cede command back to
            % main script
            result = 0;
            return;
            
        end
        % -----------------------------------------------------------------
        
        % Function to withdraw a specified amount ---------------------------
        function [result, response] = withdraw( obj, ...
                volume_ml, rate_mlPerMin )          
            
            % Initialize
            result = '';
            response = '';   
            
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Must connect device (.connectPump) first.';
                return;
            end
            
            % Make sure syringe properties have been set
            syringeNotInitialized = ...
                isnan( obj.Syringe.Volume_ml ) || ...
                isnan( obj.Syringe.InnerDiameter_mm ) ;
            if syringeNotInitialized
                result = 'Must set syringe parameters first.';
                return;
            end
            
            % Set pump to withdraw mode
            modeCommand = '@load qs w';
            [rslt, rply] = obj.sendKdsCommand( modeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set to withdraw mode. ', ...
                    'Pump said: ', rply ];
                return;
            end
            
            % Set device target volume
            targetVolumeCommand = sprintf( ....
                'tvolume %6.4f ml', volume_ml );
            [rslt, rply] = obj.sendKdsCommand( targetVolumeCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set target volume. Pump said: ', ...
                    rply ];
                return;
            end
            
            % Set the flow rate
            rateCommand = sprintf( ...
                'wrate %6.2f ml/min', rate_mlPerMin );                
            
            % Pass command
            [rslt, rply] = obj.sendKdsCommand( rateCommand, 0, 0 );
            if ~isequal( rslt, 0 )
                result = [ 'Couldn''t set withdraw flow rate. ', ...
                    'Pump said: ', rply ];
                return;
            end
            
            % Send command
            runCommand = 'run';
            % For some reason the run command doesn't work sometimes. If
            % you take one or the other of these run commands away, it 
            % won't always work, but with both it seems to work always.
            [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
%             [response, ~] = sendCommandAndWait( obj, runCommand, 0, 0 );
            
            % Return success
            result = 0;
            return;

            
        end
        % -----------------------------------------------------------------
        
        
        % Function to pass  an arbitrary command to the pump --------------
        function [result, response] = ...
                sendKdsCommand( obj, command, waitForReply, waitTime )
            
            
            % Initialize
            result = '';
            response = '';
            
            % Default if not specificied
            if nargin == 3
                waitTime = 0; % Don't wait
            elseif nargin == 2
                waitTime = 0;
                waitForReply = 0; % No response expected
            end
            
            % Ensure device is open
            portIsClosed = ...
                isequal( obj.DeviceObject, 'Not Initialized' ) || ...
                isequal( obj.DeviceObject.status, 'closed' );
            
            if portIsClosed
                result = 'Must connect device (.connectPump) first.';
                return;
            end
            
            % Send command
            [response, timedOut] = sendCommandAndWait( ...
                obj, command, waitForReply, waitTime );
            
            % Pause for the pump to process command
            pause( obj.WaitTime );
            
            % Make sure device responded as expected
            if timedOut
                result = ['Command timed out, waiting for response. ', ...
                    'Pump said: ' response ];
            else
                % Return 0 to indicate no errors
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Class destructor -----------------------------------------------
        function delete( obj )
            
            % Actions when device is deleted
            
        end
        % -----------------------------------------------------------------
        
    end
    
    % Methods to be used only by other methods in this class
    methods (Access = private, Hidden)
        
        % Function to wait for response from controller
        function [response, timedOut] = sendCommandAndWait( ...
                obj, command, replyExpected, waitFor )
            
            % Initialize
            timedOut = 0;
            response = '';
                       
            % Send command
            fprintf( obj.DeviceObject, command );
            
            % Pause for the pump to process command
            pause( obj.WaitTime );
            
            % Keep trying to check that we get the expected response
            tic;
            
            % Initialize break flag
            validResponse = 0;
            
            % If we don't expect a reply, just pass command and return
            if ~replyExpected
%                 fprintf( obj.DeviceObject, command);
                response = '[none expected]';
                return;
            end
            
            % Otherwise, keep checking for a response
            while ( ~validResponse ) && ( ~timedOut )
                
                % Send command
                fprintf( obj.DeviceObject, command);
                pause( obj.ComSettings.Timeout ); % Pause for 0.1 seconds
                
                % Get response
                pumpReply = fscanf( obj.DeviceObject );
                
                % Update time
                elapsedTime = toc;
                
                % If the pump address is not 0, its response will be
                % prepended with its address in brackets.
                if ~isequal( obj.Address, 0 )
                    
                    % Check the new response
                    % Parse reply
                    % \d+     - Any number of numeric digits
                    % :       - Colon
                    % (\w*\s) - Any alphanumeric character followed by a space
                    %           or a period (any number of times)
                    expression = '\d+:(\w*(\s|.))+';
                    indexOffset = 3;
                    
                else
                    
                    % Parse reply
                    % :       - Colon
                    % (\w*\s) - Any alphanumeric character followed by a space
                    %           or a period (any number of times)
                    expression = ':(\w*(\s|.))+';
                    indexOffset = 0;
                    
                end
                
                [startIndex, endIndex] = regexp( pumpReply, expression);
                
                if isempty( startIndex ) || isempty( endIndex )
                    response = [...
                        'Unexpected reply format. Pump replied: ', ...
                        pumpReply ];
                    return;
                else
                    response = pumpReply( startIndex + indexOffset : endIndex );
                    validResponse = 1;
                end
                
                % Check if timed out
                timedOut = ( elapsedTime > waitFor );
                
            end
            
            % If we've timed out, the response is returned as read
            
        end
        
    end
end