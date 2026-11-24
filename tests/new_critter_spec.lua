package.path = "./scripts/?.lua;" .. package.path
local Nutrition = require("loyalcritters/nutrition")
local Aggro = require("loyalcritters/aggro")
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

local bulbin = {prefab="critter_bulbin", components=eets.components}
local other = {components={}}
function player:HasTag(tag) return tag=="player" end
function other:HasTag(tag) return tag=="player" end
player.components.petleash.GetPets = function() return {[bulbin]=true} end
local inst = {HasTag=function() return false end}
local distance=9
function inst:GetDistanceSqToInst() return distance^2 end
local env={}
local original=function(center,radius,predicate)
    if predicate(player) then return player end
    if predicate(other) then return other end
end
env.FindEntity=original
local combat={targetfn=function(i) return env.FindEntity(i,10,function() return true end),true end}
owner=player
percent=1
Aggro.Wrap(combat,ownerof,env)
Aggro.Wrap(combat,ownerof,env)
assert(combat.targetfn(inst)==other)
distance=8
assert(combat.targetfn(inst)==player)
distance=9
percent=.5
assert(combat.targetfn(inst)==player)
percent=1
owner=nil
assert(combat.targetfn(inst)==player)
owner=player
combat.target=player
assert(combat.targetfn(inst)==player)
combat.target=nil
inst.HasTag=function(_,tag) return tag=="epic" end
assert(combat.targetfn(inst)==player)
assert(env.FindEntity==original)
inst.HasTag=function() return false end
local broken={targetfn=function() error("test") end}
Aggro.Wrap(broken,ownerof,env)
assert(not pcall(broken.targetfn,inst))
assert(env.FindEntity==original)
print("new_critter_spec: OK")
