% Velmex debugger

clear;
clc;

% Instantiate and connect
x = velmex;
x.connectVelmex;

% % Move a bit
% x.move( 'up', 3, 1, 1.2 );
% x.move( 'down', 3, 1, 1.2);
% 
% % Set 0 position
% x.setZeroPosition();
% 
% % Move away from zero position in all directions
% x.move( 'up', 5, 1, 1.2 );
% x.move( 'left', 6, 1, 1.2);
% x.move( 'forward', -8, 2, 1.2);
% 
% % Return to zero position
% x.goToZeroPosition();