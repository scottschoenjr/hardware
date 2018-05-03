%% PicoScope 5000 Series Instrument Driver Oscilloscope Block Data Capture with FFT Example
%  
%   This is a modified version of the machine generated representation of 
%   an instrument control session using a device object. The instrument 
%   control session comprises all the steps you are likely to take when 
%   communicating with your instrument. These steps are:
%       
%       1. Create a device object   
%       2. Connect to the instrument 
%       3. Configure properties 
%       4. Invoke functions 
%       5. Disconnect from the instrument 
%  
%   To run the instrument control session, type the name of the file,
%   PS5000A_ID_Block_FFT_Example, at the MATLAB command prompt.
% 
%   The file, PS5000A_ID_BLOCK_FFT_EXAMPLE.M must be on your MATLAB PATH. For additional information
%   on setting your MATLAB PATH, type 'help addpath' at the MATLAB command
%   prompt.
%
%   Example:
%       PS5000A_ID_Block_FFT_Example;
%
%   Description:
%       Demonstrates how to call functions in order to capture a block of
%       data from a PicoScope 5000 series oscilloscope and calculates FFT
%       on Channel A.
%
%   See also ICDEVICE.
%
%   Copyright: (c) 2013 - 2017 Pico Technology Ltd. See LICENSE file for terms.
%
%   Author: HSM
%
%   Device used to generated example: PicoScope 5242A

%   Creation time: 05-Jul-2013 13:00:29 

%% LOAD CONFIGURATION INFORMATION

PS5000aConfig;

%% DEVICE CONNECTION

% Create a device object. 
ps5000aDeviceObj = icdevice('picotech_ps5000a_generic.mdd');

% Connect device object to hardware.
connect(ps5000aDeviceObj);

%% SET CHANNELS

% Default driver settings used - use ps5000aSetChannel to turn channels on
% or off and set voltage ranges, coupling, as well as analogue offset.

%% SET DEVICE RESOLUTION

% Max. resolution with 2 channels enabled is 15 bits.
[status, resolution] = invoke(ps5000aDeviceObj, 'ps5000aSetDeviceResolution', 15);

%% SET TRIGGER

% Channel     : 0 (PS5000A_CHANNEL_A)
% Threshold   : 1000 (mV)
% Direction   : 2 (Rising)
% Delay       : 0
% Auto trigger: 0 (wait indefinitely)

[status] = invoke(ps5000aDeviceObj, 'setSimpleTrigger', 0, 1000, 2, 0, 0);

%% GET TIMEBASE

% Driver default timebase index used - use ps5000aGetTimebase or
% ps5000aGetTimebase2 to query the driver as to suitability of using a
% particular timebase index then set the 'timebase' property if required.

% timebase     : 65 (default)
% segment index: 0

[status, timeIntervalNanoSeconds, maxSamples] = invoke(ps5000aDeviceObj, 'ps5000aGetTimebase', 65, 0);

%% SET BLOCK PARAMETERS AND CAPTURE DATA

% Set pre-trigger samples.
set(ps5000aDeviceObj, 'numPreTriggerSamples', 1024);
% Set post-trigger samples.
set(ps5000aDeviceObj, 'numPostTriggerSamples', 10000);

% Capture a block of data:
%
% segment index: 0

[status] = invoke(ps5000aDeviceObj, 'runBlock', 0);

% Retrieve data values:
%
% start index       : 0
% segment index     : 0
% downsampling ratio: 1
% downsampling mode : 0 (PS5000A_RATIO_MODE_NONE)

[chA, chB, chC, chD, numSamples, overflow] = invoke(ps5000aDeviceObj, 'getBlockData', 0, 0, 1, 0);

% Stop the device
[status] = invoke(ps5000aDeviceObj, 'ps5000aStop');

%% PROCESS DATA

% Plot data values.

figure;

% Calculate time (nanoseconds) and convert to milliseconds
% Use timeIntervalNanoSeconds output from ps5000aGetTimebase or
% ps5000aGetTimebase2 or calculate from Programmer's Guide.

timeNs = double(timeIntervalNanoSeconds) * double([0:numSamples - 1]);
timeMs = timeNs / 1e6;

% Channel A
axisHandleChA = subplot(2,1,1); 
plot(timeMs, chA, 'b');
title('Channel A');
xlabel('Time (ms)');
ylabel(axisHandleChA, 'Voltage (mV)');

% Channel B

axisHandleChB = subplot(2,1,2); 
plot(timeMs, chB, 'r');
title('Channel B');
xlabel('Time (ms)');
ylabel(axisHandleChB, 'Voltage (mV)');

% Calculate FFT of Channel A and plot - based on fft help file.
L = length(chA);
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft(chA,NFFT)/L;

Fs = 1/504e-9;
f = Fs/2*linspace(0,1,NFFT/2+1);

figure;
plot(f,2*abs(Y(1:NFFT/2+1))); 
title('Single-Sided Amplitude Spectrum of y(t)');
xlabel('Frequency (Hz)');
ylabel('|Y(f)|');

%% DEVICE DISCONNECTION

% Disconnect device object from hardware.
disconnect(ps5000aDeviceObj);