package.path = "./scripts/?.lua;" .. package.path
local Nutrition = require("loyalcritters/nutrition")
local Repellent = require("loyalcritters/repellent")
local player = {components = {}}
local eets = {prefab = "critter_eets", components = {}}
local percent, owner = 1, player
eets.components.perishable = {GetPercent = function() return percent end}
player.components.petleash = {GetPets = function() return {[eets] = true} end}
player.components.eater = {custom_stats_mod_fn = function(_, h, f, s) return h+1, f+2, s*2 end}
local function ownerof(p) return owner end
Nutrition.InstallPlayer(player, ownerof)
Nutrition.InstallPlayer(player, ownerof)
local function check(s, expected)
    local h,f,n = player.components.eater.custom_stats_mod_fn(player, 5, 6, s)
    assert(h == 6 and f == 8 and math.abs(n-expected) < .00001)
end
check(5,12)
check(-5,-10)
check(0,0)
percent=.5
check(5,10)
percent=1
owner=nil
check(5,10)

local bulbin = {prefab="critter_bulbin", components=eets.components, Transform={GetWorldPosition=function() return 0,0,0 end}}
function bulbin:IsValid() return true end
function bulbin:HasTag() return false end
local function target(prefab)
    return {prefab=prefab, components={locomotor={}}, IsValid=function() return true end, HasTag=function() return false end}
end
local pests = {}
for _, prefab in ipairs({"fruitfly","mosquito","killerbee","frog","perd","bee","friendlyfruitfly","spider","lordfruitfly"}) do
    table.insert(pests,target(prefab))
end
local function find(x,y,z,r) assert(r==8); return pests end
owner=player
Repellent.Pulse(bulbin, ownerof, find, 15)
for i,p in ipairs(pests) do
    assert(Repellent.GetSource(p,ownerof,15) == (i<=5 and bulbin or nil))
    assert(Repellent.GetSource(p,ownerof,18)==nil)
end
Repellent.Pulse(bulbin,ownerof,find,30)
owner=nil
assert(Repellent.GetSource(pests[1],ownerof,31)==nil)
Repellent.Pulse(bulbin,ownerof,find,45)
assert(Repellent.GetSource(pests[1],ownerof,45)==nil)
owner=player
percent=.5
Repellent.Pulse(bulbin,ownerof,find,60)
assert(Repellent.GetSource(pests[1],ownerof,60)==nil)
print("new_critter_spec: OK")
