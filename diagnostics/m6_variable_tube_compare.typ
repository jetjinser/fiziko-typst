#import "../fiziko.typ": canvas, circle-pts, tube

#set page(width: 110mm, height: 62mm, margin: 0pt)

#canvas(110, 62,
  tube(circle-pts(24, 96, center: (32, 31)),
    t => 3.5 - 1.8 * calc.sin(360 * 5 * t * 1deg),
    closed: true, per: 2, seed: 12)
  + tube(((85, 10), (85, 52)), t => (1 - t) * 9,
    per: 8, seed: 12),
)
