% Isolated core subjects, using the unmodified, pinned upstream library.
input fiziko.mp;
if unknown selected: selected := 0; fi;

if (selected = 0) or (selected = 201):
beginfig(201);
  randomseed := 1;
  draw sphere.c(26mm) shifted (55mm,28mm);
  setbounds currentpicture to (0,0)--(110mm,0)--(110mm,56mm)--(0,56mm)--cycle;
endfig;
fi;

end.
