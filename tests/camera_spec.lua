package.path = "./scripts/?.lua;" .. package.path
local Camera = require("loyalcritters/camera")
local c = {maxdist = 40, mindist = 10, distance = 25, distancetarget = 25}
Camera.Apply(c, true, 12, .7)
assert(c.maxdist == 52 and c.distance == 25 and c.distancetarget > 25)
Camera.Apply(c, true, 12, .7)
Camera.Apply(c, false, 12, .7)
assert(c.maxdist == 40 and c.distance == 25 and c.distancetarget <= 40)
c.maxdist = 60
Camera.Apply(c, true, 12, .7)
assert(c.maxdist == 72)
c.maxdist = 90
Camera.Apply(c, true, 12, .7)
Camera.Apply(c, false, 12, .7)
assert(c.maxdist == 90, "external zoom changes must survive")
Camera.Apply(c, true, 12, .7)
assert(c.maxdist == 102)
Camera.Apply(c, false, 12, .7)
assert(c.maxdist == 90)
Camera.Apply(nil, true, 12, .7)
print("camera_spec: OK")
