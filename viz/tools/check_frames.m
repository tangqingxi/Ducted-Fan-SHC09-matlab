"""Numeric checks to run in MATLAB (§6.2) and compare with test_frames.py."""

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'lib', 'math'));
R = ca_euler_rotation([0 0 0]);
fprintf('R(0,0,0)  * [0;1;0]  = %s   (expect [0 1 0] -> NED +y = east)\n', mat2str((R * [0; 1; 0])', 6));
R = ca_euler_rotation([0 0 pi/2]);
fprintf('R(0,0,90) * [0;1;0]  = %s   (expect [-1 0 0])\n', mat2str((R * [0; 1; 0])', 6));
R = ca_euler_rotation([pi/2 0 0]);
fprintf('R(90,0,0) * [0;0;-1] = %s   (test_frames.py freezes this as [0 1 0])\n', mat2str((R * [0; 0; -1])', 6));
fprintf('det(R) = %.15f\n', det(R));
