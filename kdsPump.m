%**************************************************************************
%
%  KDScientific Pump Class
%
%   Class definition for basic operation of the kdScientific Syringe Pump
%   model 110.
%
%
%              Scott Schoen Jr | Georgia Tech | 20170407
%
%**************************************************************************

classdef kdsPump < handle
    
    % Set slider properties
    properties
        Manufacturer
        ManufacturerID
        Model
        ResourceName
        DeviceObject
        ComSettings
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
            obj.ResourceName = 'COM5';
            obj.DeviceObject = 'Not Initialized';
            
            % COM Port default settings
            obj.ComSettings.ComPort = 5;
            obj.ComSettings.BaudRate = 9600;
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
                result = 'Couldn''t open serial connection with the pump.';
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
            
            % Otherwise, return success
            result = 0;
            
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
            
            % Make sure device responed as expected
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
            
            % Keep trying to check that we get the expected response
            elapsedTime = 0;
            tic;
            
            % Initialize break flags
            validResponse = 0;
            timedOut = 0;
            
            % If we don't expect a reply, just pass command and return
            if ~replyExpected
                fprintf( obj.DeviceObject, command);
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
                
                % Check the new response
                % Parse reply
                % \d+     - Any number of numeric digits
                % :       - Colon
                % (\w*\s) - Any alphanumeric character followed by a space
                %           or a period (any number of times)
                expression = '\d+:(\w*(\s|.))+';
                [startIndex, endIndex] = regexp( pumpReply, expression);
                
                if isempty( startIndex ) || isempty( endIndex )
                    response = [...
                        'Unexpected reply format. Pump replied: ', ...
                        pumpReply ];
                    return;
                else
                    response = pumpReply( startIndex + 3 : endIndex );
                    validResponse = 1;
                end
                
                % Check if timed out
                timedOut = ( elapsedTime > waitFor );
                
            end
            
            % If we've timed out, the response is returned as read
            
        end
        
    end
end