input "/tmp/fiziko-s101-stipple-trace.mp";
randomseed := 1;

numeric figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
def frame(expr w, h) = figw := w; figh := h; enddef;

beginfig(101);
  frame(120,44);
  randomseed := 1;
  message "OBJECT BRUSH";
  draw thinBrush.stipples(P(5,35)..P(26,13)..P(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  message "OBJECT SPHERE";
  draw sphere.s(22mm) shifted P(70,22);
  message "OBJECT TUBE";
  draw tube.s(P(89,33)..P(103,10)..P(115,28))(3mm);
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
end.
