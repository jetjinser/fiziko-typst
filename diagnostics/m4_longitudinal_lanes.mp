input "/tmp/fiziko-m4-lanes.mp";
randomseed := 1;

numeric figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
def frame(expr w, h) = figw := w; figh := h; enddef;
def finishframe =
  setbounds currentpicture to (0,0)--(figw*mm,0)--(figw*mm,figh*mm)--(0,figh*mm)--cycle;
enddef;

beginfig(4);
  frame(110,56);
  path p;
  p := P(55+42*cosd(205),68+42*sind(205));
  for i=1 upto 40:
    p := p..P(55+42*cosd(205+130*i/40),68+42*sind(205+130*i/40));
  endfor;
  draw tube.l(p)(6mm);
  finishframe;
endfig;
end
