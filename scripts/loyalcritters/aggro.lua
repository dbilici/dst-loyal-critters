-- Restrict only vanilla idle retarget searches, not retaliation or existing targets.
local M = {}
local PREFABS = {"hound","firehound","icehound","spider","spider_warrior","spider_hider",
    "spider_spitter","spider_dropper","spider_moon","spider_healer","spider_water",
    "bee","killerbee","frog","mosquito"}

function M.HasFedBulbin(player, ownerof)
    local leash = player and player.components and player.components.petleash
    if leash == nil then return false end
    for pet in pairs(leash:GetPets()) do
        if pet.prefab == "critter_bulbin" and ownerof(pet) == player
            and pet.components.perishable ~= nil and pet.components.perishable:GetPercent() > .5 then
            return true
        end
    end
    return false
end

function M.AllowCandidate(inst, candidate, radius, ownerof)
    if not candidate:HasTag("player") or not M.HasFedBulbin(candidate, ownerof) then return true end
    return inst:GetDistanceSqToInst(candidate) <= (radius * .8)^2
end

-- Vanilla retarget callbacks are synchronous. Temporarily decorate FindEntity
-- only during an idle retarget callback, preserving the original search order,
-- tags, predicate and other candidates. Always restore even on error.
function M.Wrap(combat, ownerof, env)
    if combat == nil or combat._loyalcritters_aggro then return end
    local previous = combat.targetfn
    if type(previous) ~= "function" then return end
    combat._loyalcritters_aggro = true
    combat.targetfn = function(inst, ...)
        if combat.target ~= nil or inst:HasTag("epic") or inst:HasTag("boss") then
            return previous(inst, ...)
        end
        local find = env.FindEntity
        if type(find) ~= "function" then return previous(inst, ...) end
        env.FindEntity = function(center, radius, predicate, ...)
            if center ~= inst or type(radius) ~= "number" then
                return find(center, radius, predicate, ...)
            end
            return find(center, radius, function(candidate, ...)
                return M.AllowCandidate(inst, candidate, radius, ownerof)
                    and (predicate == nil or predicate(candidate, ...))
            end, ...)
        end
        local ok, target, force = pcall(previous, inst, ...)
        env.FindEntity = find
        if not ok then error(target, 0) end
        return target, force
    end
end

function M.Install(addprefab, ownerof, ismaster, env)
    for _, prefab in ipairs(PREFABS) do
        addprefab(prefab, function(inst)
            if ismaster() and inst.components ~= nil then
                M.Wrap(inst.components.combat, ownerof, env)
            end
        end)
    end
end
return M
