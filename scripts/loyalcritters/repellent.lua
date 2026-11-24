-- Temporary, targeted avoidance; no damage or permanent combat/AI changes.
local M = {}
local TARGETS = { fruitfly = true, mosquito = true, killerbee = true, frog = true, perd = true }
local BRAINS = {"fruitflybrain", "mosquitobrain", "killerbeebrain", "frogbrain", "perdbrain"}
local RADIUS, PERIOD, DURATION = 8, 15, 3

local function ActiveBulbin(pet, ownerof)
    return pet ~= nil and pet:IsValid() and ownerof(pet) ~= nil
        and pet.components.perishable ~= nil
        and pet.components.perishable:GetPercent() > .5
end

function M.Pulse(pet, ownerof, find, now)
    if not ActiveBulbin(pet, ownerof) or pet:HasTag("INLIMBO") or pet:HasTag("asleep") then return end
    local x,y,z = pet.Transform:GetWorldPosition()
    for _, target in ipairs(find(x,y,z,RADIUS)) do
        if TARGETS[target.prefab] and target:IsValid() and not target:HasTag("INLIMBO")
            and not target:HasTag("playerghost") and target.components.locomotor ~= nil
            and (target.components.health == nil or not target.components.health:IsDead()) then
            target._loyalcritters_repellent = {source = pet, expires = now + DURATION}
        end
    end
end

function M.GetSource(target, ownerof, now)
    local mark = target._loyalcritters_repellent
    if mark ~= nil and now < mark.expires and ActiveBulbin(mark.source, ownerof) then
        return mark.source
    end
    target._loyalcritters_repellent = nil
    return nil
end

function M.Install(addprefab, addbrain, ownerof, ismaster)
    local RunAway = require("behaviours/runaway")
    for _, name in ipairs(BRAINS) do
        addbrain(name, function(brain)
            local inst = brain.inst
            if not TARGETS[inst.prefab] or brain.bt == nil or brain.bt.root == nil then return end
            local function source() return M.GetSource(inst, ownerof, GetTime()) end
            local root = brain.bt.root
            if root._loyalcritters_repellent then return end
            local flee = WhileNode(function() return source() ~= nil end, "Bulbin foul breath",
                RunAway(inst, {getfn = source}, RADIUS + 2, RADIUS + 2))
            brain.bt.root = PriorityNode({flee, root}, .1)
            brain.bt.root._loyalcritters_repellent = true
        end)
    end
    addprefab("critter_bulbin", function(pet)
        if not ismaster() then return end
        pet:DoPeriodicTask(PERIOD, function(inst)
            M.Pulse(inst, ownerof, function(x,y,z,r)
                return TheSim:FindEntities(x,y,z,r,nil,{"INLIMBO","FX","DECOR"})
            end, GetTime())
        end, PERIOD)
    end)
end
return M
