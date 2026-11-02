prologues := 0;
def val(expr whole, hi, lo) = whole + hi/256 + (lo/256)/256 enddef;
def fx(expr n) = decimal(floor(n)) & ":"
  & decimal(floor((n-floor(n))*256)) & ":"
  & decimal(floor(((n-floor(n))*256-floor((n-floor(n))*256))*256)) enddef;
input fiziko.mp;
path qpath, raypath;
numeric hval, xmax, xmin, xmid, hitone, hittwo;
numeric delta, unit;
pair rawdir, rawrev;
hval := val(0,40,97);
qpath := (val(238,78,10), val(0,41,114))
  .. controls (val(242,7,112), val(0,41,23))
  and (val(245,192,214), val(0,40,188))
  .. (val(249,122,60), val(0,40,97));
xmax := xpart(urcorner qpath);
xmin := val(157,77,214);
xmid := val(203,100,9);
raypath := (xmid,hval)--(xmax,hval);
message "RAYX " & fx(xpart(point 0 of raypath)) & " "
  & fx(xpart(postcontrol 0 of raypath)) & " "
  & fx(xpart(precontrol 1 of raypath)) & " "
  & fx(xpart(point 1 of raypath));
message "RAYY " & fx(ypart(point 0 of raypath)) & " "
  & fx(ypart(postcontrol 0 of raypath)) & " "
  & fx(ypart(precontrol 1 of raypath)) & " "
  & fx(ypart(point 1 of raypath));
rawdir := raypath intersectiontimes qpath;
rawrev := raypath intersectiontimes reverse(qpath);
message "RAW " & decimal(xpart(rawdir)) & " " & decimal(ypart(rawdir))
  & " " & decimal(xpart(rawrev)) & " " & decimal(ypart(rawrev));
hitone := ypart(((xmid,hval)--(xmax,hval)) firstIntersectionTimes qpath);
hittwo := ypart(((xmid,hval)--(xmin,hval)) firstIntersectionTimes qpath);
message "EXACT " & decimal(hitone) & " " & decimal(xpart(point hitone of qpath)) & " " & decimal(hittwo);
hval := hval + (1/256)/256;
hitone := ypart(((xmid,hval)--(xmax,hval)) firstIntersectionTimes qpath);
hittwo := ypart(((xmid,hval)--(xmin,hval)) firstIntersectionTimes qpath);
message "ABOVE " & decimal(hitone) & " " & decimal(xpart(point hitone of qpath)) & " " & decimal(hittwo);
hval := hval - 2*(1/256)/256;
hitone := ypart(((xmid,hval)--(xmax,hval)) firstIntersectionTimes qpath);
hittwo := ypart(((xmid,hval)--(xmin,hval)) firstIntersectionTimes qpath);
message "BELOW " & decimal(hitone) & " " & decimal(xpart(point hitone of qpath)) & " " & decimal(hittwo);
% Sweep exact fixed-point levels around the endpoint. This exposes whether
% the early hit is a one-unit quantization boundary or a broad tolerance.
unit := (1/256)/256;
hval := hval + unit;
for delta = -8 upto 8:
  hitone := ypart(((xmid,hval+delta*unit)--(xmax,hval+delta*unit))
    firstIntersectionTimes qpath);
  message "SWEEP " & decimal(delta) & " " & decimal(hitone) & " "
    & decimal(xpart(point hitone of qpath));
endfor;
end
