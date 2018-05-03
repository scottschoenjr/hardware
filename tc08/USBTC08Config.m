%% USBTC08Config Configure path information
% Configures paths according to platforms and loads information from
% prototype files for USB TC-08 data loggers. The folder 
% that this file is located in must be added to the MATLAB path.
%
% Platform Specific Information:-
%
% Microsoft Windows: Download the Software Development Kit installer from
% the <a href="matlab: web('https://www.picotech.com/downloads')">Pico Technology Download software and manuals for oscilloscopes and data loggers</a> page.
% 
% Linux: Follow the instructions to install the libusbtc08 package from the <a href="matlab:
% web('https://www.picotech.com/downloads/linux')">Pico Technology Linux Software & Drivers for Oscilloscopes and Data Loggers</a> page.
%
% Apple Mac OS X: Follow the instructions to install the PicoScope 6
% application from the <a href="matlab: web('https://www.picotech.com/downloads')">Pico Technology Download software and manuals for oscilloscopes and data loggers</a> page.
% Optionally, create a 'maci64' folder in the same directory as this file
% and copy the following files into it:
%
% * libusbtc08.dylib and any other libusbtc08 library files
%
% Contact our Technical Support team via the <a href="matlab: web('https://www.picotech.com/tech-support/')">Technical Enquiries form</a> for further assistance.
%
% Run this script in the MATLAB environment prior to connecting to the 
% device.
%
% This file can be edited to suit application requirements.
%
% *Copyright:* © 2016-2017 Pico Technology Ltd. See LICENSE file for terms.

%% Set Path to Shared Libraries
% Set paths to shared library files according to the operating system and
% architecture.

% Identify working directory
usbtc08ConfigInfo.workingDir = pwd;

% Find file name
usbtc08ConfigInfo.configFileName = mfilename('fullpath');

% Only require the path to the config file
[usbtc08ConfigInfo.pathStr] = fileparts(usbtc08ConfigInfo.configFileName);

% Identify architecture e.g. 'win64'
usbtc08ConfigInfo.archStr = computer('arch');

try

    addpath(fullfile(usbtc08ConfigInfo.pathStr, usbtc08ConfigInfo.archStr));
    
catch err
    
    error('USBTC08Config:OperatingSystemNotSupported', 'Operating system not supported - please contact support@picotech.com');
    
end

% Set the path according to operating system.

if (ismac())
    
    % Libraries (including wrapper libraries) are stored in the PicoScope
    % 6 App folder. Add locations of library files to environment variable.
    
    setenv('DYLD_LIBRARY_PATH', '/Applications/PicoScope6.app/Contents/Resources/lib');
    
    if(contains(getenv('DYLD_LIBRARY_PATH'), '/Applications/PicoScope6.app/Contents/Resources/lib'))
       
        addpath('/Applications/PicoScope6.app/Contents/Resources/lib');
        
    else
        
        warning('USBTC08Config:LibraryPathNotFound','Locations of libraries not found in DYLD_LIBRARY_PATH');
        
    end
    
elseif (isunix())
	    
    % Edit to specify location of .so files or place .so files in same directory
    addpath('/opt/picoscope/lib/'); 
		
elseif (ispc())
    
    % Microsoft Windows operating systems
    
    % Set path to dll files if the Pico Technology SDK Installer has been
    % used or place dll files in the folder corresponding to the
    % architecture. Detect if 32-bit version of MATLAB on 64-bit Microsoft
    % Windows.
    
    usbtc08ConfigInfo.winSDKInstallPath = '';
    
    if(strcmp(usbtc08ConfigInfo.archStr, 'win32') && exist('C:\Program Files (x86)\', 'dir') == 7)
       
        try 
            
            addpath('C:\Program Files (x86)\Pico Technology\SDK\lib\');
            usbtc08ConfigInfo.winSDKInstallPath = 'C:\Program Files (x86)\Pico Technology\SDK';
            
        catch err
           
            warning('USBTC08Config:DirectoryNotFound', ['Folder C:\Program Files (x86)\Pico Technology\SDK\lib\ not found. '...
                'Please ensure that the location of the library files are on the MATLAB path.']);
            
        end
        
    else
        
        % 32-bit MATLAB on 32-bit Windows or 64-bit MATLAB on 64-bit
        % Windows operating systems
        try 
        
            addpath('C:\Program Files\Pico Technology\SDK\lib\');
            usbtc08ConfigInfo.winSDKInstallPath = 'C:\Program Files\Pico Technology\SDK';
            
        catch err
           
            warning('USBTC08Config:DirectoryNotFound', ['Folder C:\Program Files\Pico Technology\SDK\lib\ not found. '...
                'Please ensure that the location of the library files are on the MATLAB path.']);
            
        end
        
    end
    
else
    
    error('USBTC08Config:OperatingSystemNotSupported', 'Operating system not supported - please contact support@picotech.com');
    
end

%% Load Enumerations and Structure Information
% Enumerations and structures are used by certain shared library functions.

[usbtc08Methodinfo, usbtc08Structs, usbtc08Enuminfo, usbtc08ThunkLibName] = usbtc08MFile; 
