function results = make_fixture(tag, duration_s, mode)
%MAKE_FIXTURE  Run one short SHC09 simulation that saves a replayable log.
%
%   Usage:
%     addpath('viz/tools'); make_fixture('viz_fixture_2s_DCA', 2, 'ideal')
%     make_fixture('viz_20s_ideal_DCA', 20, 'ideal')
%     make_fixture('viz_15s_lite_DCA', 15, 'lite')
%
%   Writes results/<tag>/DCA/log.mat plus control.csv/pwm.csv.  This is the only
%   MATLAB action needed for the v0.1 replay deliverables; it changes no model code.

if nargin < 1 || strlength(string(tag)) == 0, tag = 'viz_fixture_2s_DCA'; end
if nargin < 2, duration_s = 2; end
if nargin < 3, mode = 'ideal'; end

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
cd(root);
ca_setup();
o = shc09_airframe(mode);
o.duration_s = duration_s;
o.save_results = true;
o.overwrite_results = true;
o.output_tag = string(tag);
results = main(3, o); %#ok<NASGU> % 3 = DCA
log = load(fullfile(root, 'results', char(tag), 'DCA', 'log.mat'), 'log');
n = size(log.log.position_ned_m, 1);
fprintf('fixture %s: mode=%s duration=%gs n=%d (expected %d at 800 Hz)\n', ...
    char(tag), char(mode), duration_s, n, 800 * duration_s + 1);
end
