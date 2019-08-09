%**************************************************************************
%
%  Velmex Class
%
%   Class definition for basic operation of Velmex BiSlide 3D Positioning
%   System (3DPS).
%
%
%              Scott Schoen Jr | Georgia Tech | 20170301
%
%*************************************************************************

classdef velmex < handle
    
    % Set slider properties
    properties
        Manufacturer
        ManufacturerID
        Model
        ResourceName
        DeviceObject
        ComSettings
        StopButton
    end
    
    % Set static properties
    properties (Constant, Hidden)
        
        % Set slider conversion
        stepsPerMillimeter = 160; % 1 step = 1/160th of a millimeter
        % Set max travel distance (per command)
        maxTravelDistance = 100; % [mm]
        
    end
    
    % Define user-accessible methods
    methods
        
        % Class constructor -----------------------------------------------
        function obj = velmex()
            
            % Initialize vapolues
            obj.Manufacturer = 'Velmex';
            obj.ManufacturerID = ''; % No MATLAB designation
            obj.Model = 'BiSlide';
            obj.ResourceName = 'COM3';
            obj.DeviceObject = 'Not Initialized';
            
            % COM Port default settings
            obj.ComSettings.ComPort = 3;
            obj.ComSettings.BaudRate = 9600;
            obj.ComSettings.DataBits = 8;
            obj.ComSettings.Parity = 'none';
            obj.ComSettings.StopBits = 1;
            obj.ComSettings.Terminator = 'CR';
            obj.ComSettings.InputBufferSize = 2048;
            obj.ComSettings.Timeout = 0.1;
            
            % Set the button to off initially. It can be enabled by setting
            % this to 1 before connecting the object
            obj.StopButton = 0;
            
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
        
        
        % Function to connect to Velmex BiSlide with a (virtualized) serial
        % connection. It's actually over USB.
        function [obj, result] = connectVelmex( obj )
            
            % Initialize
            result = '';
            
            % Try to create object
            try
                comPort = obj.ResourceName;
                velmexObject = serial( comPort, ...
                    'Baudrate', obj.ComSettings.BaudRate, ...
                    'Databits', obj.ComSettings.DataBits, ...
                    'Parity', obj.ComSettings.Parity, ...
                    'StopBits', obj.ComSettings.StopBits, ...
                    'Terminator', obj.ComSettings.Terminator, ... 
                    'InputBufferSize', obj.ComSettings.InputBufferSize, ...
                    'Timeout', obj.ComSettings.Timeout ...
                    );
            catch
                result = 'Couldn''t create device object.';
                return;
            end
            
            % Buffer size?
            % obj.ComSettings.InputBufferSize = 2048;
            % 'InputBufferSize', obj.ComSettings.InputBufferSize, ...
            
            % Update object properties
            obj.DeviceObject = velmexObject;
            
            % Open port
            try
                fopen( obj.DeviceObject );
            catch
                result = [ 'Port ', obj.ResourceName, ' seems to be '...
                    'unavailable. Is USB cable disconnected?' ];
                return;
            end
            
            % Make sure port was opened
            portOpenedSuccessfully = isequal( ...
                obj.DeviceObject.status, 'open' );
            if ~portOpenedSuccessfully
                % Otherwise, something went wrong...
                result = [ 'Couldn''t open port ', obj.ResourceName, '.' ];
                return;
            end
            
%             % Clear any existing commands or programs
%             % K - Kill any running programs
%             % C - Clear
%             [response, timedOut] = ...
%                 sendCommandAndWait( obj, 'KC', '^', 1 );
%             if timedOut
%                 result = [ ...
%                     'Something went wrong clearing 3DPS memory. ', ...
%                     'When I tried, the Velmex didn''t respond as ', ...
%                     'expected. It said: ', response...
%                     ];
%                 return;
%             end
            
            
            % Verify that VMX is connected and responding
            % V - Verify status
            % F - Echo off [E = on]
            [response, timedOut] = ...
                sendCommandAndWait( obj, 'VF', 'R', 2 );
            if timedOut
                result = [ 'Comm check timed out. ', ...
                    'Velmex didn''t report ready, though ', ...
                    'it may still work. ', ...
                    'It said: ', response...
                    ];
                return;
            end
                        
            % Create a kill button to stop motors if desired
            if obj.StopButton
                kbf = figure();
                set( kbf, ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none', ...
                    'NumberTitle', 'off', ...
                    'Name', 'Stop Motors', ...
                    'Resize', 'off', ...
                    'Position', [100, 100, 400, 200], ...
                    'Color', [1, 1, 1], ...
                    'Tag', 'KillButtonFigure', ...
                    'CloseRequestFcn', @obj.preventFigureClose ...
                    );
                
                killButton = uicontrol( ...
                    'Units', 'Normalized', ...
                    'Style', 'pushbutton', ...
                    'BackgroundColor', 0.8.*[1, 0, 0], ...
                    'ForegroundColor', [1, 1, 1], ...
                    'Position', [0.1, 0.25, 0.8, 0.6], ...
                    'String', 'STOP MOTORS', ...
                    'FontSize', 28, ...
                    'FontWeight', 'Bold', ...
                    'Callback', @obj.killCallback ...
                    );
            end
            
            
            % Otherwise, return success
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to disconnect Velmex -----------------------------------
        function [obj, result] = disconnectVelmex( obj )
            
            % Initialize
            result = '';
            
            % Try to close
            try
                fclose( obj.DeviceObject );
            catch
                result = 'Something went wrong disconnecting Velmex.';
                return;
            end
            
            % If we're successful, return 0
            if isempty( result )
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Function to display properties of the serial object (the 3DPS) --
        function [velmexStatus] = status( obj )
            
            % Get status from device object
            velmexStatus = obj.DeviceObject;
            
        end
        % -----------------------------------------------------------------
        
        % Function to move motor a specified amount -----------------------
        function [result, response ] = ...
                move( obj, direction, distance_mm, speed_mmps, wait )
            
            % Initialize
            result = '';
            response = '';
            
            % If no wait time is specified, don't pause after execution
            if nargin < 5
                wait = 0;
            elseif ~isa( wait, 'double' )
                result = [ ...
                    'Wait time is a fraction of the computed time. ', ...
                    '(Something like 1.1 for 10% extra time.)' ...
                    ];
                return;
            else
                wait = abs(wait); % Make sure positive
            end
            
            % First, determine which motor and direction. Note that
            % positive direction is away from motor.
            direction = lower( direction );
            if isa( direction, 'char' )
                switch direction
                    case 'left'
                        motorNumber = 1;
                    case 'right'
                        motorNumber = 1;
                        distance_mm = -1.*distance_mm;
                    case 'forward'
                        motorNumber = 2;
                    case 'back'
                        motorNumber = 2;
                        distance_mm = -1.*distance_mm;
                    case 'down'
                        motorNumber = 3;
                    case 'up'
                        motorNumber = 3;
                        distance_mm = -1.*distance_mm;
                    otherwise
                        result = 'Unknown motor direction.';
                        return;
                end
            elseif ~isempty( intersect( direction, [1, 2, 3] ) )
                motorNumber = direction;
            else
                result = 'Unknown motor direction.';
                return;
            end
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Assemble set speed command
            stepsPerSecond = round( speed_mmps.*obj.stepsPerMillimeter );
            if ~isa( stepsPerSecond, 'double' )
                result = 'Motor speed must be a postitive number [mm/s]';
                return;
            elseif stepsPerSecond > 4000
                stepsPerSecond = 4000;
            elseif stepsPerSecond < 1
                stepsPerSecond = 1;
            end
            speedCommand = ['F,C,G,'...
                'S', num2str(motorNumber), ... % Has form, e.g., S1M2000
                'M', num2str(stepsPerSecond), ...
                ',R'];
            
            % Send speed command
            [response, timedOut] = sendCommandAndWait( ...
                obj, speedCommand, '', 2 );
            if timedOut
                result = 'Set speed command timed out.';
                return;
            end
            
            % Check if specified distance is 0 (passing 0 will cause the
            % motor to run away, so just return here instead).
            if distance_mm == 0
                result = 0;
                return;
            end
            
            % Assemble movement command
            numSteps = round( distance_mm.*obj.stepsPerMillimeter );
            maxSteps = obj.maxTravelDistance.*obj.stepsPerMillimeter;
            if ~isa( distance_mm, 'double' )
                result = 'Motor distance must be a number [mm].';
                return;
            elseif abs(numSteps) > maxSteps
                numSteps = sign(numSteps).*maxSteps;
            end
            movementCommand = ['K,F,C,G,'...
                'I', num2str(motorNumber), ...  % Has form, e.g., I1M500
                'M', num2str(numSteps), ...
                ',R'];
            
            % Send movement command
            [response, timedOut] = sendCommandAndWait( ...
                obj, movementCommand, '', 2 );
            if timedOut
                result = 'Movement command timed out.';
                return;
            end
            
            % Pause (if required) to make sure motion completes
            if wait > 0
                % Compute wait time and then pause
                waitFor = wait.*abs( numSteps./stepsPerSecond );
                pause( waitFor );
            end
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to set the zero position of the 3DPS -------------------
        function [result, response] = setZeroPosition( obj )
            
            % Initialize
            result = '';
            response = '';
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Assemble command. It's most efficient to pass as several
            % commands, rather than calling sendCommandAndWait three times
            setZeroPositionCommand = 'K,F,C,G';
            for motorCount = 1:3
                
                % Append current motor and setting
                setZeroPositionCommand = [ setZeroPositionCommand, ...
                    ',IA', num2str(motorCount), 'M-0' ];
                expectedResponse = '';
                
            end
            % The "N" command sets the motor absolute position registers to
            % 0. Without this, the motor stores, e.g., (400, 100, -200) as
            % the "zero", and returns to this position whenever the return
            % to 0 command ("IA[motor #]M0") is issued. Making this
            % position Null will allow us to get its position too.
            setZeroPositionCommand = [ setZeroPositionCommand, ',N,R' ];
            
            % Send command
            [response, timedOut] = sendCommandAndWait( ...
                obj, setZeroPositionCommand, expectedResponse, 2 );
            
            % Make sure device responed as expected
            if timedOut
                result = [ ...
                    'Command timed out trying to zero motors. ', ...
                    'Was waiting for response: ', expectedResponse,  ...
                    '. Velmex said: ' response ];
                return;
            end
            
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to return to the zero position of the 3DPS -------------
        function [result, response] = goToZeroPosition( obj )
            
            % Initialize
            result = '';
            response = '';
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Assemble command. It's most efficient to pass as several
            % commands, rather than calling sendCommandAndWait three times
%             goToZeroPositionCommand = 'K,F,C,G';
            goToZeroPositionCommand = 'K,F,C';
            for motorCount = 1:3
                
                % Append current motor and setting
                goToZeroPositionCommand = [ goToZeroPositionCommand, ...
                    ',IA', num2str(motorCount), 'M0' ];
                expectedResponse = '';
                
            end
            goToZeroPositionCommand = [ goToZeroPositionCommand, ',R' ];
            
            % Send command
            [response, timedOut] = sendCommandAndWait( ...
                obj, goToZeroPositionCommand, expectedResponse, 2 );
            
            % Make sure device responed as expected
            if timedOut
                result = [ ...
                    'Command timed out trying to return motors to origin. ', ...
                    'Was waiting for response: ', expectedResponse,  ...
                    '. Velmex said: ' response ];
                return;
            end
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to get the current position of the 3DPS ----------------
        function [result, response, axisPositions] = ...
                getCurrentPosition( obj )
            
            % Initialize
            result = '';
            response = '';
            axisPositions = NaN.*ones(1, 3);
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Vector to hold motor positions
            axisNames = {'X', 'Y', 'Z'};
            axisPositions = zeros(1, 3);
            expectedResponse = '';
            
            % Query each motor for its position
            for motorCount = 1:3
                
                % Append current motor and setting
                getPositionCommand = [ 'C,', axisNames{motorCount}, 'R' ];
                
                % Send command
                [response, timedOut] = sendCommandAndWait( ...
                    obj, getPositionCommand, expectedResponse, 2 );
                
                % Make sure device responed as expected
                if timedOut
                    result = [ ...
                        'Command timed out trying to get position ', ...
                        'of motor #', num2str(motorCount), ...
                        'Was waiting for response: ', expectedResponse,  ...
                        '. Velmex said: ' response ];
                    return;
                end
                
                % Parse value from VXM response
                
                % Get response from serial object
                vxmResponse = fscanf( obj.DeviceObject );
                
                % Find the sign of the position
                plusSignIndex = strfind( vxmResponse, '+' );
                minusSignIndex = strfind( vxmResponse, '-' );
                
                if isempty( plusSignIndex ) && isempty( minusSignIndex )
                    
                    % If we find neither, return an error
                    result = [ 'Couldn''t parse position. ' ...
                        'The buffer was: ', vxmResponse ];
                    return;
                    
                elseif ~isempty( plusSignIndex ) && ...
                        ~isempty( minusSignIndex )
                    
                    % If we find both, return an error
                    result = [ 'Couldn''t parse position. ' ...
                        'The buffer was: ', vxmResponse ];
                    return;
                    
                elseif ~isempty( plusSignIndex )
                    
                    % Make sure sign is correct
                    motorPosition_steps = str2double( ...
                        vxmResponse( plusSignIndex + 1 : end ) );
                    
                elseif ~isempty( minusSignIndex )
                    
                    motorPosition_steps = -1.*str2double( ...
                        vxmResponse( minusSignIndex + 1 : end ) );
                    
                else
                    % Unknown read problem
                    result = [ 'Couldn''t parse position. ' ...
                        'The buffer was: ', vxmResponse ];
                    return;
                end
                
                % Store received position
                axisPositions( motorCount ) = ...
                    motorPosition_steps./obj.stepsPerMillimeter;
                
            end
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
        
        % Function to move 3DPS to a desired location ---------------------
        function [ result, response ] = ...
                goToPosition( obj, axis1, axis2, axis3 )
            
            % Initialize
            result = '';
            response = '';
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Get current position of motors
            [~, ~, currentPositions] = getCurrentPosition( obj );
            
            % Determine how far we have to go, in each direction, to get to
            % that position
            axisDistances = [ ...
                axis1 - currentPositions(1), ...
                axis2 - currentPositions(2), ...
                axis3 - currentPositions(3) ];
            
            % Query each motor for its position
            for motorCount = 1:3
                
                % Compute number of steps
                motorDistance = axisDistances(motorCount); % [mm/s]
                motorSpeed = 3; % [mm/s]
                
                % Compute the wait time. Shorter moves should have longer
                % wait times.
                expectedTime = abs(motorDistance)./motorSpeed;
                waitTime = 3 - 0.6.*expectedTime;
                waitTime = max( waitTime, 1.3 ); % Make at least 1.3
                
                % Use move command (1.3 safety factor should be enough)
                % If this is causing problems, consider assembling commands
                % and then sending comma-separated to VXM
                [result, response] = obj.move( ...
                    motorCount, motorDistance, motorSpeed, waitTime );
                
                % Make sure device responed as expected
                if ~isequal( result, 0 )
                    result = [ ...
                        'Command to move motor #', num2str(motorCount), ...
                        ' failed. Velmex said: ' response ];
                    return;
                end
                
            end
            
            % Return 0 to indicate no errors
            result = 0;
            
        end
        % -----------------------------------------------------------------
                
        % Function to display kill button if it's been closed -------------
        function [ result ] = showKillButton( obj )
            
            % Initialize
            result = NaN;
            
            % Check if the kill button figure already exists
            buttonExists = ~isempty( ...
                findobj( 'Tag', 'KillButtonFigure' ) );
            if buttonExists
                result = 1;
                return;
            end
            
            % Create a kill button to stop motors
            kbf = figure();
            set( kbf, ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', 'Stop Motors', ...
                'Resize', 'off', ...
                'Position', [100, 100, 400, 200], ...
                'Color', [1, 1, 1], ...
                'Tag', 'KillButtonFigure', ...
                'CloseRequestFcn', @obj.preventFigureClose ...
                );
            
            killButton = uicontrol( ...
                'Units', 'Normalized', ...
                'Style', 'pushbutton', ...
                'BackgroundColor', 0.8.*[1, 0, 0], ...
                'ForegroundColor', [1, 1, 1], ...
                'Position', [0.1, 0.25, 0.8, 0.6], ...
                'String', 'STOP MOTORS', ...
                'FontSize', 28, ...
                'FontWeight', 'Bold', ...
                'Callback', @obj.killCallback ...
                );
            
            
            % Otherwise, return success
            result = 0;
            
            
        end
        % -----------------------------------------------------------------
        
        % Function to kill all motor operation ----------------------------
        function [result, response] = kill( obj )
            
            % Initialize
            result = '';
            response = '';
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Assemble kill command
            killCommand = ['F,C,G,K'];
            expectedResponse = '';
            
            % Send kill command
            [response, timedOut] = sendCommandAndWait( ...
                obj, killCommand, expectedResponse, 2 );
            
            % Make sure device responed as expected
            if timedOut
                result = [ ...
                    'Command timed out trying to kill operation. ', ...
                    'Velmex said: ' response ];
            else
                % Return 0 to indicate no errors
                result = 0;
            end
            
            
        end
        % -----------------------------------------------------------------
        
        % Function to pass  an arbitrary command to the 3DPS --------------
        function [result, response] = ...
                sendVelmexCommand( obj, command, expectedResponse )
            
            % Use default expected response if unknown
            if nargin < 2
                expectedResponse = '^';
            end
            
            % Initialize
            result = '';
            response = '';
            
            % Ensure device is open
            portIsClosed = isequal( obj.DeviceObject.status, 'closed' );
            if portIsClosed
                result = 'Must connect device (.connectVelmex) first.';
                return;
            end
            
            % Send command
            [response, timedOut] = sendCommandAndWait( ...
                obj, command, expectedResponse, 2 );
            
            % Make sure device responed as expected
            if timedOut
                result = ['Command timed out, waiting for response: ', ...
                    expectedResponse, '. Velmex said: ' response ];
            else
                % Return 0 to indicate no errors
                result = 0;
            end
            
        end
        % -----------------------------------------------------------------
        
        % ============== Callback Functions for UI Button ================
        
        % Function to kill all motor operation ----------------------------
        function killCallback( obj, src, evnt )
            
            % Assemble kill command
            killCommand = ['F,C,G,K'];
            expectedResponse = '';
            
            % Send kill command
            [response, timedOut] = sendCommandAndWait( ...
                obj, killCommand, expectedResponse, 2 );
            
            % Make sure device responed as expected
            if timedOut
                result = [ ...
                    'Command timed out trying to kill operation. ', ...
                    'Velmex said: ' response ];
            else
                % Return 0 to indicate no errors
                result = 0;
            end
            
            
        end
        % -----------------------------------------------------------------
        
        % Function to make kill button persistent -------------------------
        function preventFigureClose( obj, src, evnt )
            
            % Make sure user really wants to kill
            [ userChoice ] = questdlg( ...
                [ 'It''s a good idea to have this button visible. ', ...
                'Are you sure you want to close? ', ...
                '[Motors can be stopped with the .kill command]' ], ...
                'Are you sure?', ...
                'Stay Visible', 'Close Anyway', 'Stay Visible' ...
                );
            
            % Warn user
            switch userChoice
                case 'Stay Visible'
                    % Do nothing
                case 'Close Anyway'
                    % Close window
                    figureObject = findobj( 'Tag', 'KillButtonFigure' );
                    figureObject.delete;
            end
            
        end
        % -----------------------------------------------------------------
        
        % Class destructor -----------------------------------------------
        function delete( obj )
            
            % Close the connection
            fclose( obj.DeviceObject );
            
            % Close the kill button
            figureObject = findobj( 'Tag', 'KillButtonFigure' );
            if ~isempty( figureObject )
                close( figure( figureObject.Number ) );
                figureObject.delete;
            end
            
        end
        % -----------------------------------------------------------------
        
    end
    
    % Methods to be used only by other methods in this class
    methods (Access = private, Hidden)
        
        % Function to wait for response from controller
        function [response, timedOut] = sendCommandAndWait( ...
                obj, command, expectedResponse, waitFor )
            
            % Initialize
            timedOut = 0;
            response = '';
            
            % Send command
            fprintf( obj.DeviceObject, command );
            
            % Keep trying to check that we get the expected response
            elapsedTime = 0;
            tic;
            while ( ~strcmp( response, expectedResponse ) ) ...
                    && ( elapsedTime < waitFor )
                
                % Send command
                fprintf( obj.DeviceObject, command);
                pause( obj.ComSettings.Timeout ); % Pause for 0.1 seconds
                
                % Now as soon as data is sent back, keep checking it until
                % we get the response we expected, or we time out.
                dataSent = obj.DeviceObject.BytesAvailable;
                if dataSent > 0
                    response = ...
                        fscanf(obj.DeviceObject, '%s)', dataSent);
                end
                
                % Update time
                elapsedTime = toc;
                
            end
            
            % If we've timed out return 1
            if elapsedTime >= waitFor
                timedOut = 1;
            end
            
        end
        
    end
end