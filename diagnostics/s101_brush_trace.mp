input "/tmp/fiziko-s101-brush-trace.mp";
randomseed := 1;

numeric figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
def frame(expr w, h) = figw := w; figh := h; enddef;

beginfig(1);
  randomseed := 1;
  frame(120,44);
  draw thinBrush.stipples(P(5,35)..P(26,13)..P(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;
end.
