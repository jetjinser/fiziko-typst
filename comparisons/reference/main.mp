% Companion graphics for main.typ, rendered by upstream jemmybutton/fiziko.
% Source snapshot: https://github.com/jemmybutton/fiziko/tree/54a63dba8e6700a5e70d3508838edebcbf0f45fe
input fiziko.mp;
% Set selected in a wrapper to render only that plate; 0 renders the gallery.
if unknown selected: selected := 0; fi;

numeric figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
def frame(expr w, h) =
  figw := w; figh := h;
enddef;
def finishframe =
  setbounds currentpicture to (0,0)--(figw*mm,0)--(figw*mm,figh*mm)--(0,figh*mm)--cycle;
enddef;

if (selected = 0) or (selected = 1):
beginfig(1);
  randomseed := 1;
  frame(110,52);
  path p, q;
  p := P(6,36)..P(38,16)..P(72,34)..P(104,14);
  q := offsetPath(p)(7mm*sin(offsetPathLength*pi));
  draw p withpen pencircle scaled .6pt;
  draw q dashed evenly withpen pencircle scaled .5pt;
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 2):
beginfig(2);
  randomseed := 1;
  frame(110,52);
  path p;
  p := P(6,36)..P(38,16)..P(72,34)..P(104,14);
  draw p dashed withdots withpen pencircle scaled .35pt;
  draw brush(p)(3pt*sin(offsetPathLength*pi)**2);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 3):
beginfig(3);
  randomseed := 1;
  frame(110,56);
  draw sphereLat(20mm,-60) shifted P(36,28);
  draw sphereLat(30mm,45) shifted P(70,28);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 4):
beginfig(4);
  randomseed := 1;
  frame(110,56);
  path p;
  p := P(55+42*cosd(205),68+42*sind(205));
  for i=1 upto 40:
    p := p..P(55+42*cosd(205+130*i/40),68+42*sind(205+130*i/40));
  endfor;
  draw tube.l(p)(6mm);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 5):
beginfig(5);
  randomseed := 1;
  frame(110,82);
  draw P(14,6)--P(78,6) withpen thickpen;
  for i=0 upto 8:
    draw P(20+6.5*i,6)--P(16.5+6.5*i,1.5) withpen thinpen;
  endfor;
  draw tube.l(P(35,6)--P(59.4,51.9))(1mm);
  draw sphere.c(26mm) shifted P(59.4,51.9);
  drawarrow P(59.4,66.5)--P(59.4,78) withpen thinpen;
  draw subpath (0,1) of fullcircle scaled 15mm shifted P(35,6) withpen thinpen;
  label("A",P(31,3.5));
  label("theta",P(37.6,16.3));
  label("l",P(51.2,26.9));
  label("m",P(76.4,49.9));
  label("mg",P(65,76));
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 6):
beginfig(6);
  randomseed := 1;
  frame(110,62);
  path ring;
  ring := fullcircle scaled 48mm shifted P(32,31);
  draw tube.l(ring)(3.5mm+1.8mm*sin(10*pi*offsetPathLength));
  draw tube.l(P(85,10)--P(85,52))((1-offsetPathLength)*9mm);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 7):
beginfig(7);
  randomseed := 1;
  frame(110,42);
  draw tube.t(P(6,32)..P(40,14)..P(74,32)..P(104,16))(5mm);
  finishframe;
endfig;
fi;

def drawLH(expr ab, ll, rope, ox, oy) =
  begingroup
    save x, y, a, d, pa, pb, pc, pd, pe, offa, offb;
    numeric x, y, a, d;
    pair pa, pb, pc, pd, pe, offa, offb;
    x := (ll**2 + abs(ll)*((sqrt(8)*ab)++ll))/(4*ab);
    y := ll+-+x;
    pa := P(ox,oy);
    pb := P(ox+6*ab,oy);
    pd := P(ox+6*x,oy+6*y);
    pc := pd shifted (0,-6*(rope-((ab-x)++y))*mm);
    d := 4mm;
    offa := unitvector(pc-pd) rotated 90 scaled (5d/12);
    offb := unitvector(pd-pb) rotated 90 scaled (5d/12);
    pe := whatever[pd shifted offa,pc shifted offa]
        = whatever[pd shifted offb,pb shifted offb];
    a := angle(pa-pd);
    draw solidSurface(P(ox-4,oy)--P(ox+6*ab+4,oy));
    draw pulley(d,a-90) shifted pe;
    draw image(
      draw pa--pd--pb withpen thickpen;
      draw pd--pc withpen thickpen;
    ) maskedWith (pulleyOutline shifted pe);
    draw sphere.c(6mm) shifted pc shifted (0,-3mm);
    label("A",pa shifted (-2mm,-3mm));
    label("B",pb shifted (2mm,-3mm));
    label("C",pc shifted (-3mm,2mm));
  endgroup;
enddef;

if (selected = 0) or (selected = 8):
beginfig(8);
  randomseed := 1;
  frame(110,40);
  drawLH(6,2,5.5,8,6);
  drawLH(3,2.5,3,58,6);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 9):
beginfig(9);
  randomseed := 1;
  frame(110,66);
  % The native 1/3 mm wood grid is expensive across four large planks.
  % This is an explicit source-library resolution setting for this plate.
  woodBlockRes := 1mm;
  path plank;
  plank := P(0,0)--P(55,0)--P(55,33)--P(0,33)--cycle;
  draw woodenThing(plank,0);
  plank := P(55,0)--P(110,0)--P(110,33)--P(55,33)--cycle;
  draw woodenThing(plank,90);
  plank := P(0,33)--P(55,33)--P(55,66)--P(0,66)--cycle;
  draw woodenThing(plank,90);
  plank := P(55,33)--P(110,33)--P(110,66)--P(55,66)--cycle;
  draw woodenThing(plank,0);
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 10):
beginfig(10);
  randomseed := 1;
  frame(110,58);
  draw P(8,6)--P(30,6) withpen thickpen;
  for i=0 upto 4:
    draw P(11+4.5*i,6)--P(9.5+4.5*i,3.5) withpen thinpen;
  endfor;
  springwidth := 2.4mm;
  draw spring(P(19,6),P(19,30),7);
  draw weight.h(14mm) shifted P(19,30);
  drawarrow P(19,45.5)--P(19,54) withpen thinpen;
  label("k",P(25,17));
  label("mg",P(23.5,52));
  path glass;
  glass := lens((25mm,25mm),3.2mm,20mm,1) shifted P(72,30);
  draw glass withpen thinpen;
  draw P(51,30)--P(94,30) dashed evenly withpen thinpen;
  drawarrow P(52,24)--P(68.5,24) withpen thinpen;
  drawarrow P(74.5,24)--P(86,33.6) withpen thinpen;
  draw fullcircle scaled .8mm shifted P(82,30) withpen thinpen;
  label("F",P(84.5,36));
  label("f",P(78.6,32.8));
  label("i",P(75.6,27.7));
  finishframe;
endfig;
fi;

if (selected = 0) or (selected = 11):
beginfig(11);
  randomseed := 1;
  frame(155,44);
  draw globe(15mm,0,0) shifted P(19,22);
  eyescale := 18mm;
  draw eye(0) shifted P(62,22);
  path wa, wb, refractor;
  wa := P(86,22);
  wb := P(86,22);
  for i=1 upto 24:
    wa := wa..P(86+32*i/24,22+6*sind(720*i/24));
    wb := wb..P(86+32*i/24,22-6*sind(720*i/24));
  endfor;
  addStrandToKnot(weave)(wa,.8mm,"l","-1,1,-1,1");
  addStrandToKnot(weave)(wb,.8mm,"l","1,-1,1,-1");
  draw knotFromStrands(weave);
  refractor := fullcircle scaled 20mm shifted P(136,22);
  draw refractor withpen thinpen;
  draw refractionPath(P(122,17)--P(128,17),refractor,1.5) withpen thinpen;
  finishframe;
endfig;
fi;

end.
