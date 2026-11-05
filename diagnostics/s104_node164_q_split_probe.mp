% Replay the source q-template split from row -6.37912, node 164 -> 165.
% All controls are the source trace's 16.16 base-256 coordinates.
beginfig(1);
path q, l;
q := (29+160/256+78/256/256, 51/256+2/256/256)
  .. controls (31+113/256+30/256/256, 47/256+119/256/256)
     and (33+65/256+238/256/256, 43/256+236/256/256)
  .. (35+18/256+190/256/256, 40/256+97/256/256)
  .. controls (46+195/256+167/256/256, 40/256+97/256/256)
     and (58+116/256+144/256/256, 40/256+96/256/256)
  .. (70+37/256+121/256/256, 40/256+96/256/256)
  .. controls (71+249/256+217/256/256, 43/256+235/256/256)
     and (73+206/256+57/256/256, 47/256+118/256/256)
  .. (75+162/256+153/256/256, 51/256+1/256/256);
l := subpath (0, 2.40022) of q;

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

for i = 0 upto floor(length(l))-1:
  showFixed(point i of l);
  showFixed(postcontrol i of l);
  showFixed(precontrol (i+1) of l);
  showFixed(point (i+1) of l);
endfor;
endfig;
end
