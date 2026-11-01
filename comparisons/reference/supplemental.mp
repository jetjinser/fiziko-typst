% Supplemental source fixtures for the graphical families absent from the
% eleven-figure main-original.mp specimen. Uses the pinned upstream source.
input fiziko.mp;
% Set selected in a wrapper to render only that plate; 0 renders the gallery.
if unknown selected: selected := 0; fi;
randomseed := 1;

numeric figw, figh;
vardef P(expr x, y) = (x*mm, (figh-y)*mm) enddef;
def frame(expr w, h) = figw := w; figh := h; enddef;
def finishframe =
  setbounds currentpicture to (0,0)--(figw*mm,0)--(figw*mm,figh*mm)--(0,figh*mm)--cycle;
enddef;

% 101: stippled brush, sphere, and tube.
if (selected = 0) or (selected = 101):
beginfig(101);
  randomseed := 1;
  frame(120,44);
  draw thinBrush.stipples(P(5,35)..P(26,13)..P(48,32))
    (stippleSize*sin(offsetPathLength*pi));
  draw sphere.s(22mm) shifted P(70,22);
  draw tube.s(P(89,33)..P(103,10)..P(115,28))(3mm);
  finishframe;
endfig;
fi;

% 102: the outline-only tube and a sphere with a cast shadow.
if (selected = 0) or (selected = 102):
beginfig(102);
  randomseed := 1;
  frame(120,44);
  draw tube.e(P(7,32)..P(35,10)..P(56,31))(3mm) withpen thinpen;
  shadowsEnabled := true;
  numberOfShadows := 0;
  shadowPath0 := (-4mm,-18mm)--(-4mm,18mm)--(-2mm,18mm)--(-2mm,-18mm)--cycle;
  shadowDepth0 := 12mm;
  draw sphere.c(26mm) shifted P(90,22);
  shadowsEnabled := false;
  finishframe;
endfig;
fi;

% 103: solid surface, opaque and glass fills, and a gradient fill.
if (selected = 0) or (selected = 103):
beginfig(103);
  randomseed := 1;
  frame(120,45);
  draw solidSurface(P(4,20)..P(30,17)..P(53,21));
  path shape;
  shape := P(62,9)--P(82,9)--P(82,32)--P(62,32)--cycle;
  draw solid(shape,45,0);
  shape := P(87,9)--P(105,9)--P(105,32)--P(87,32)--cycle;
  draw solid(shape,-45,1);
  shape := P(108,9)--P(117,9)--P(117,32)--P(108,32)--cycle;
  draw gradientShade(shape,90);
  finishframe;
endfig;
fi;

% 104: both 3-D flat-surface styles.
if (selected = 0) or (selected = 104):
beginfig(104);
  randomseed := 1;
  frame(120,44);
  path panel;
  panel := P(8,8)--P(56,13)--P(50,36)--P(5,31)--cycle;
  draw flatSurface.hatches(panel,(0,0,-1),30);
  draw panel withpen thinpen;
  panel := P(65,8)--P(114,13)--P(108,36)--P(62,31)--cycle;
  draw flatSurface.stipples(panel,(1,0,1),-30);
  draw panel withpen thinpen;
  finishframe;
endfig;
fi;

% 105: the separate block and edge wood textures. The explicit 1 mm grid
% keeps the reference plate tractable without modifying upstream code.
if (selected = 0) or (selected = 105):
beginfig(105);
  randomseed := 1;
  frame(120,44);
  woodBlockRes := 1mm;
  draw woodBlock(39mm,12mm) shifted P(5,29);
  draw woodenSurface(P(60,18)..P(84,12)..P(112,18));
  finishframe;
endfig;
fi;

% 106: the source's standing and hanging weight variants.
if (selected = 0) or (selected = 106):
beginfig(106);
  randomseed := 1;
  frame(120,44);
  draw weight.s(18mm) shifted P(36,31);
  draw weight.h(18mm) shifted P(84,13);
  draw P(10,31)--P(62,31) withpen thinpen;
  draw P(64,13)--P(112,13) withpen thinpen;
  finishframe;
endfig;
fi;

% 107: pulley wheel, complete wheel, and a center-of-mass calculation.
if (selected = 0) or (selected = 107):
beginfig(107);
  randomseed := 1;
  frame(120,44);
  draw pulleyWheel(23mm) shifted P(22,22);
  draw wheel(23mm,0) shifted P(61,22);
  path plate;
  pair masscentre;
  plate := P(83,8)--P(113,11)--P(108,36)--P(87,31)--cycle;
  masscentre := shapeCenterOfMass(plate);
  draw plate withpen thinpen;
  fill fullcircle scaled 1.5mm shifted masscentre;
  finishframe;
endfig;
fi;

% 108: convex, concave, and plano-convex lens paths, plus the two annotation
% helpers absent from the main specimen's upstream drawing calls.
if (selected = 0) or (selected = 108):
beginfig(108);
  randomseed := 1;
  frame(120,44);
  draw lens((25,25),3,24,mm) shifted P(15,21) withpen thinpen;
  draw lens((-25,-25),3,24,mm) shifted P(34,21) withpen thinpen;
  draw lens((infinity,25),3,24,mm) shifted P(53,21) withpen thinpen;
  drawmidarrow (P(70,30)..P(87,11)..P(105,30)) withpen thinpen;
  picture anglelabel;
  anglelabel := "a" infont "cmr10" scaled .8;
  draw P(104,32)--P(111,20)--P(119,32) withpen thinpen;
  markAngle(P(104,32),P(111,20),P(119,32))(anglelabel);
  finishframe;
endfig;
fi;

end.
