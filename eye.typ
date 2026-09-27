#import "fiziko.typ": *

#set page(paper: "a5", margin: 18mm)
#set text(font: ("New Computer Modern", "DejaVu Serif"), size: 10pt)

= Eye drawing edge cases

The examples vary aspect ratio, rotation, gaze extremes, and lash count. Lash
placement remains deterministic for a fixed seed.

#figure(
  canvas(118, 40,
    eye(at: (20, 20), size: (16, 7), look: (-1, 1), lashes: 3, seed: 1)
    + eye(at: (59, 20), size: (30, 17), look: (1, -1), rotation: 28,
        lashes: 13, seed: 7)
    + eye(at: (99, 20), size: (18, 12), look: (0, 0), lashes: 0),
  ),
  caption: [Narrow and wide eyes with extreme gaze, rotation, and no lashes],
)
