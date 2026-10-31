function results = make_fixture(tag, duration_s, mode, reference_stages)
%MAKE_FIXTURE  Run one short SHC09 simulation that saves a replayable log.
%
%   Usage:
%     addpath('viz/tools'); make_fixture('viz_fixture_2s_DCA', 2, 'ideal')
%     make_fixture('viz_20s_ideal_DCA', 20, 'ideal', ...
%         [0 0 0 -10; 5 1 0.5 -10; 10 0.5 0 -10; 15 0 0 -10])
%     make_fixture('viz_15s_lite_DCA', 15, 'lite')
%
%   The optional 4th argument moves the position reference so the replay shows
%   a real trajectory and its deviation; without it the vehicle hovers in place.
%   Writes results/<tag>/DCA/log.mat plus control.csv/pwm.csv.  This is the only
%   MATLAB action needed for the v0.1 replay deliverables; it changes no model code.

if nargin < 1 || strlength(string(tag)) == 0, tag = 'viz_fixture_2s_DCA'; end
if nargin < 2, duration_s = 2; end
if nargin < 3, mode = 'ideal'; end
if nargin < 4, reference_stages = []; end

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
cd(root);
ca_setup();
o = shc09_airframe(mode);
o.duration_s = duration_s;
o.save_results = true;
o.overwrite_results = true;
o.output_tag = string(tag);
if ~isempty(reference_stages)
    o.position_reference_stages = reference_stages;
end
results = main(3, o); %#ok<NASGU> % 3 = DCA
log = load(fullfile(root, 'results', char(tag), 'DCA', 'log.mat'), 'log');
n = size(log.log.position_ned_m, 1);
fprintf('fixture %s: mode=%s duration=%gs n=%d (expected %d at 800 Hz)\n', ...
    char(tag), char(mode), duration_s, n, 800 * duration_s + 1);
end
