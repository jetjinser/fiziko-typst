% Seeded MetaPost random stream oracle.
% Generate with the repository devshell: mpost metapost-rng-vectors.mp
beginfig(1);
randomseed := 1;
for i := 1 upto 16:
  show uniformdeviate(1);
endfor;
endfig;
end.
