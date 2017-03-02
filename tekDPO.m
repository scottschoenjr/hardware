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
                result = 'Couldn''t create device object.';
                return;
            end
            
            % Update object properties
            obj.DeviceObject = scopeDeviceObject;
            
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
        
        % Function to handle arbitrary scope commands and return the
        % scope's output
        function [scopeReply] = sendCommand( obj, command, delay )
            
           % If the delay isn't specified, don't use one
           if nargin < 3 || ~isa( delay, 'double' )
              delay = 0; 
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
           scopeReply = fscanf( obj.DeviceObject );
            
        end
    end
end