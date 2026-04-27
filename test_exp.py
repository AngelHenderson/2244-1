import math

def get_exponent(value):
    v0 = max(1, value)
    v = v0
    floorExp = 0
    while v > 1:
        v >>= 1
        floorExp += 1
    if v0 >= 1000000000 and (v0 & (v0 - 1)) != 0:
        return floorExp + 1
    return floorExp

print("Exponent for 1al (approx 1e123):")
# Let's see what TileStepLabelFormatter.stepForValue does!
