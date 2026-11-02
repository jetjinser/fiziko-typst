prologues := 0;
def val(expr whole, hi, lo) = whole + hi/256 + (lo/256)/256 enddef;
input fiziko.mp;
path qpath;
numeric hval, xmax, xmin, xmid, hitone, hittwo;
hval := val(0,40,97);
qpath := (val(238,78,10), val(0,41,114))
  .. controls (val(242,7,112), val(0,41,23))
  and (val(245,192,214), val(0,40,188))
  .. (val(249,122,60), val(0,40,97));
xmax := xpart(urcorner qpath);
xmin := val(157,77,214);
xmid := val(203,100,9);
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
end
