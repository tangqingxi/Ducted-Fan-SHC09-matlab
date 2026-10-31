function out_path = export_geometry(out_path)
%EXPORT_GEOMETRY  Write viz/geometry/shc09_geometry.json from the MATLAB parameters.
%
%   This is the single source of the SHC09 geometry constants used by the
%   Python replay (plan §7, decision D1).  Python never copies l1/l2/P_cs.
%   The JSON carries a SHA-256 over a canonical ASCII payload so a stale copy
%   is detected by viz/tests/test_geometry.py.
%
%   Usage:  cd E:\Ducted-Fan-SHC09-viz; addpath('viz/geometry'); export_geometry

if nargin < 1
    here = fileparts(mfilename('fullpath'));
    out_path = fullfile(here, 'shc09_geometry.json');
end
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
addpath(fullfile(root, 'models', 'shc09'));
p = ca_shc09_parameters();

% Visual choices only (§6.6).  Not real airframe dimensions.
duct_outer_m = 0.30;
duct_inner_m = 0.28;
body_box_m = [0.18, 0.18, 0.35];
disc_radius_m = sqrt(p.S / pi);

g = struct();
g.schema = 'shc09-geometry-v1';
g.source = 'ca_shc09_parameters';
g.generated_by = 'viz/geometry/export_geometry.m';
g.generated_at = char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
g.vehicle = struct();
g.vehicle.l1_m = p.l1;
g.vehicle.l2_m = p.l2;
g.vehicle.vane_limit_rad = p.cm;
g.vehicle.vane_vertices = p.P_cs;
g.vehicle.disc_area_m2 = p.S;
g.vehicle.disc_area_radius_m = disc_radius_m;
g.vehicle.duct_outer_m = duct_outer_m;
g.vehicle.duct_inner_m = duct_inner_m;
g.vehicle.body_box_m = body_box_m;
g.vehicle.mass_kg = p.m;
g.vehicle.inertia_kg_m2 = diag(p.J)';
g.assumed = { ...
    'duct_outer_m and duct_inner_m are visual choices, not airframe dimensions', ...
    'disc_area_radius_m is the area-equivalent radius sqrt(S/pi), not the duct radius', ...
    'body_box_m is a schematic box because the repository has no airframe geometry', ...
    'vanes rotate about the tangential axis (-P2, P1, 0); this is a display choice, not the numerical effectiveness matrix', ...
    'vane_vertices are the six unit hexagon vertices P_cs from ca_shc09_parameters'};
g.sha256 = sha256_hex(build_payload(g));

txt = jsonencode(g, 'PrettyPrint', true);
fid = fopen(out_path, 'w', 'n', 'UTF-8');
assert(fid > 0, 'cannot open %s for writing', out_path);
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('geometry written: %s (sha256=%s)\n', out_path, g.sha256);
end

function payload = build_payload(g)
% Canonical ASCII payload shared with viz/shc09_viz/geometry.py.
lines = {
    'shc09-geometry-v1'
    sprintf('l1_m %s', fmt(g.vehicle.l1_m))
    sprintf('l2_m %s', fmt(g.vehicle.l2_m))
    sprintf('vane_limit_rad %s', fmt(g.vehicle.vane_limit_rad))
    sprintf('disc_area_m2 %s', fmt(g.vehicle.disc_area_m2))
    sprintf('disc_area_radius_m %s', fmt(g.vehicle.disc_area_radius_m))
    sprintf('duct_outer_m %s', fmt(g.vehicle.duct_outer_m))
    sprintf('duct_inner_m %s', fmt(g.vehicle.duct_inner_m))
    sprintf('body_x_m %s', fmt(g.vehicle.body_box_m(1)))
    sprintf('body_y_m %s', fmt(g.vehicle.body_box_m(2)))
    sprintf('body_z_m %s', fmt(g.vehicle.body_box_m(3)))
    sprintf('mass_kg %s', fmt(g.vehicle.mass_kg))
    sprintf('inertia_xx %s', fmt(g.vehicle.inertia_kg_m2(1)))
    sprintf('inertia_yy %s', fmt(g.vehicle.inertia_kg_m2(2)))
    sprintf('inertia_zz %s', fmt(g.vehicle.inertia_kg_m2(3)))};
for i = 1:3
    for j = 1:6
        lines{end + 1} = sprintf('vane_vertex_%d_%d %s', i, j, fmt(g.vehicle.vane_vertices(i, j))); %#ok<AGROW>
    end
end
payload = strjoin(lines, char(10));
end

function s = fmt(x)
s = sprintf('%.17g', double(x));
end

function hex = sha256_hex(text)
md = java.security.MessageDigest.getInstance('SHA-256');
digest = md.digest(int8(text));
hex = lower(reshape(dec2hex(typecast(digest, 'uint8'), 2)', 1, []));
end
