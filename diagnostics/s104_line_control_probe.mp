% Emit exact 16.16 chunks for MetaPost's `--` line-cubic controls.
% The Typst port computes these as round(delta/3) and round(2*delta/3).
beginfig(1);
pair a, b;
path p;
for dx=1 upto 12:
  a := (0, 0);
  b := (dx, 0);
  p := a -- b;
  message decimal(dx) & " "
    & decimal(floor(xpart(postcontrol 0 of p) * 256)) & " "
    & decimal(floor((xpart(postcontrol 0 of p) * 256
      - floor(xpart(postcontrol 0 of p) * 256)) * 256)) & " "
    & decimal(floor(xpart(precontrol 1 of p) * 256)) & " "
    & decimal(floor((xpart(precontrol 1 of p) * 256
      - floor(xpart(precontrol 1 of p) * 256)) * 256));
endfor;
endfig;
end
