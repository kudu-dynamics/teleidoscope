## Implement a color gradient algorithm as described in
## https://krazydad.com/tutorials/makecolors.php
import colors, math

proc wave(freq: float, i, phase, width, center: int): int =
  (sin(freq + i.float + phase.float) * width.float + center.float).int mod 256

iterator makeColorGradient*(frequency1, frequency2, frequency3: float,
                            phase1, phase2, phase3, center, width: int,
                            start = 0, length = 1): int =
  for i in start ..< length:
    let
      red = wave(frequency1, i, phase1, width, center)
      green = wave(frequency2, i, phase2, width, center)
      blue = wave(frequency3, i, phase3, width, center)
    yield colors.rgb(red, green, blue).int

iterator defaultGradient*(start = 0, length = 1): int =
  for color in makeColorGradient(1.666, 2.666, 3.666,
                                 0, 0, 0, 128, 127,
                                 start, length):
    yield color
