% Run with a pinned fiziko.mp in the current directory.
input fiziko.mp;
beginfig(1);
for t := 0 step 1/32 until 8:
  message "WFC " & decimal(t) & " "
    & decimal(xpart(point t of fullcircle)) & " "
    & decimal(ypart(point t of fullcircle)) & " "
    & decimal(minStrokeWidth * (1/2 + abs(sin(woodKnotAngle))
      * abs(sin(angleRad(point t of fullcircle)))));
endfor;
endfig;
end
