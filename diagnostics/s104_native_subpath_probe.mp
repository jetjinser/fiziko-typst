% Reproduce the S104 row -11.76086 q split from its traced source controls.
% Source node 32 is split at t=0.5; its left child is source node 33.
% Coordinates below encode (floor(value*256), remaining 16.16 units).
beginfig(1);
path p, l;
p := (27 + 159/256 + 145/256/256, 51/256 + 2/256/256)
  .. controls (30 + 187/256 + 84/256/256, 49/256 + 151/256/256)
  and (33 + 215/256 + 22/256/256, 48/256 + 45/256/256)
  .. (36 + 242/256 + 217/256/256, 46/256 + 194/256/256);
l := subpath (0, 0.5) of p;

vardef showFixed expr z =
  save ix, hx, lx, iy, hy, ly;
  numeric ix, hx, lx, iy, hy, ly;
  ix := floor(xpart z); hx := floor((xpart z - ix)*256);
  lx := round(((xpart z - ix)*256 - hx)*256);
  iy := floor(ypart z); hy := floor((ypart z - iy)*256);
  ly := round(((ypart z - iy)*256 - hy)*256);
  message "FIX " & decimal(ix) & " " & decimal(hx) & " " & decimal(lx)
    & " " & decimal(iy) & " " & decimal(hy) & " " & decimal(ly);
enddef;

% Ordered as point 0, postcontrol 0, precontrol 1, point 1.
showFixed(point 0 of l);
showFixed(postcontrol 0 of l);
showFixed(precontrol 1 of l);
showFixed(point 1 of l);
endfig;
end
