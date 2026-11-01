input "/tmp/fiziko-s101-stipple-trace.mp";

numeric figw, figh, sc;
vardef Q(expr x, y) =
  ((60 + (x - 26.5) * sc) * mm,
   (figh - (22 + (y - 24) * sc)) * mm)
enddef;
def frame(expr w, h) = figw := w; figh := h; enddef;

beginfig(501);
  frame(120, 44); sc := 0.5; randomseed := 1;
  message "OBJECT BRUSH-SCALE-05";
  draw thinBrush.stipples(Q(5,35)..Q(26,13)..Q(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;

beginfig(502);
  frame(120, 44); sc := 1.0; randomseed := 1;
  message "OBJECT BRUSH-SCALE-10";
  draw thinBrush.stipples(Q(5,35)..Q(26,13)..Q(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;

beginfig(503);
  frame(120, 44); sc := 2.0; randomseed := 1;
  message "OBJECT BRUSH-SCALE-20";
  draw thinBrush.stipples(Q(5,35)..Q(26,13)..Q(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  setbounds currentpicture to (0,0)--(120mm,0)--(120mm,44mm)--(0,44mm)--cycle;
endfig;

end.
