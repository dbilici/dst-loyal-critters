package.path = "./scripts/?.lua;" .. package.path
local ownerof = require("loyalcritters/ownership").GetPetOwner
local hooks, brainhook = {}, nil
local master = true
require("loyalcritters/extensions").Install(function(prefab, fn)
    hooks[prefab] = hooks[prefab] or {}
    table.insert(hooks[prefab], fn)
end, function(name, fn)
    assert(name == "crittersbrain")
    brainhook = fn
end, ownerof, function() return master end)

local function owner(player)
    local tags = {}
    local modifiers = {}
    local o = {components = {}, valid = true, tags = tags, modifiers = modifiers}
    function o:IsValid() return self.valid end
    function o:HasTag(t) return (t == "player" and player) or tags[t] == true end
    function o:AddTag(t) tags[t] = true end
    function o:RemoveTag(t) tags[t] = nil end
    o.components.petleash = {pets = {}, IsPet = function(self, p) return self.pets[p] ~= nil end}
    local mods = {
        SetModifier = function(self, source, value, key) modifiers[key] = value end,
        RemoveModifier = function(self, source, key) modifiers[key] = nil end,
    }
    o.components.combat = {externaldamagemultipliers = mods}
    o.components.hunger = {burnratemodifiers = mods}
    o.components.locomotor = {
        SetExternalSpeedMultiplier = function(self, source, key, value) modifiers[key] = value end,
        RemoveExternalSpeedMultiplier = function(self, source, key) modifiers[key] = nil end,
    }
    return o
end

local function pet(prefab, leader)
    local p = {prefab = prefab, components = {}, callbacks = {}, pending = {}, percent = 1}
    p.components.follower = {leader = leader, GetLeader = function(self) return self.leader end}
    p.components.perishable = {GetPercent = function() return p.percent end}
    function p:ListenForEvent(e, fn) self.callbacks[e] = fn end
    function p:DoTaskInTime(delay, fn) table.insert(self.pending, fn) end
    function p:DoPeriodicTask(delay, fn) self.tick = fn end
    function p:flush()
        local tasks = self.pending
        self.pending = {}
        for _, fn in ipairs(tasks) do fn(self) end
    end
    function p:event(e) if self.callbacks[e] then self.callbacks[e](self) end end
    function p:transfer(new)
        local old = self.components.follower.leader
        if old then old.components.petleash.pets[self] = nil end
        if new then new.components.petleash.pets[self] = true end
        self.components.follower.leader = new
        self:event("leaderchanged")
        self:flush()
    end
    if leader then leader.components.petleash.pets[p] = true end
    return p
end

for _, spec in ipairs({
    {"critter_puppy", "betterpet_puppy_damage", 1.2},
    {"critter_kitten", "betterpet_kitten_speed", 1.2},
    {"critter_perdling", "betterpet_perdling_hunger", 0.8},
}) do
    local player, pearl, other = owner(true), owner(false), owner(true)
    local p = pet(spec[1], player)
    local key, value = spec[2], spec[3]
    assert(ownerof(p) == player)
    for _, fn in ipairs(hooks[p.prefab]) do fn(p) end
    p:flush()
    assert(player.modifiers[key] == value, "fed owner receives buff")
    p.percent = .5
    p:event("perishchange")
    assert(player.modifiers[key] == nil, "threshold clears buff")
    p.percent = 1
    p:event("perishchange")
    assert(player.modifiers[key] == value, "feeding restores buff")
    p:transfer(pearl)
    assert(ownerof(p) == nil and player.modifiers[key] == nil and pearl.modifiers[key] == nil, "NPC transfer clears buff")
    p:transfer(other)
    assert(other.modifiers[key] == value, "new player receives buff")
    other.components.petleash.pets[p] = nil
    p:tick()
    assert(other.modifiers[key] == nil, "detached pet clears buff")
    other.components.petleash.pets[p] = true
    p:tick()
    p:event("onremove")
    assert(other.modifiers[key] == nil, "removal clears buff")
end
local player, pearl = owner(true), owner(false)
local p = pet("critter_bulbin", player)
local follow = {name = "Follow", target_dist = 4, max_dist = 4.5}
local minigame = {name = "Follow", target_dist = 9, max_dist = 10}
brainhook({bt = {root = {children = {follow, minigame}}}})
assert(follow.target_dist_fn(p) == 6 and follow.max_dist_fn(p) == 8)
p:transfer(pearl)
assert(follow.target_dist_fn(p) == 4 and follow.max_dist_fn(p) == 4.5)
assert(minigame.target_dist_fn == nil, "minigame distances untouched")
print("critter_compatibility_spec: OK")
