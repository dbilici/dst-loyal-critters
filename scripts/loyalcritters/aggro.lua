-- Restrict only vanilla idle retarget searches, not retaliation or existing targets.
local M = { MULTIPLIER = .8 }
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
    if not candidate:HasTag("player") then return true end
    local active = M.HasFedBulbin(candidate, ownerof)
    local effective = radius * (active and M.MULTIPLIER or 1)
    local distance = math.sqrt(inst:GetDistanceSqToInst(candidate))
    local allowed = not active or distance <= effective
    -- Last real search decision, recorded only for explicitly watched players.
    if candidate._lc_aggro_watch then
        local stats = candidate._lc_aggro_watch
        stats.count = stats.count + 1
        stats.last = { enemy = inst.prefab, guid = inst.GUID, base = radius,
            effective = effective, distance = distance, active = active, allowed = allowed,
            time = GetTime() }
    end
    return allowed
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
                return (predicate == nil or predicate(candidate, ...))
                    and M.AllowCandidate(inst, candidate, radius, ownerof)
            end, ...)
        end
        local ok, target, force = pcall(previous, inst, ...)
        env.FindEntity = find
        if not ok then error(target, 0) end
        return target, force
    end
end

-- Preserve vanilla targeting for monsters, Wonkey and pirates.
-- For other players the verified vanilla retarget predicate only targets meat.
function M.MaskMeat(candidate, ownerof)
    return candidate:HasTag("player") and not candidate:HasTag("monster")
        and not candidate:HasTag("wonkey") and not candidate:HasTag("pirate")
        and M.HasFedBulbin(candidate, ownerof)
end

function M.WrapBunnyman(combat, ownerof, env)
    if combat == nil or combat._loyalcritters_odor then return end
    local previous = combat.targetfn
    if type(previous) ~= "function" then return end
    combat._loyalcritters_odor = true
    combat.targetfn = function(inst, ...)
        if combat.target ~= nil then return previous(inst, ...) end
        local find = env.FindEntity
        if type(find) ~= "function" then return previous(inst, ...) end
        env.FindEntity = function(center, radius, predicate, ...)
            if center ~= inst then return find(center, radius, predicate, ...) end
            return find(center, radius, function(candidate, ...)
                if predicate ~= nil and not predicate(candidate, ...) then return false end
                local masked = M.MaskMeat(candidate, ownerof)
                if candidate._lc_aggro_watch and candidate:HasTag("player") then
                    local stats = candidate._lc_aggro_watch
                    stats.odor = { masked = masked, time = GetTime() }
                end
                return not masked
            end, ...)
        end
        local ok, target, force = pcall(previous, inst, ...)
        env.FindEntity = find
        if not ok then error(target, 0) end
        return target, force
    end
end

function M.Install(addprefab, ownerof, ismaster, env)
    addprefab("bunnyman", function(inst)
        if ismaster() and inst.components ~= nil then
            M.WrapBunnyman(inst.components.combat, ownerof, env)
        end
    end)
    for _, prefab in ipairs(PREFABS) do
        addprefab(prefab, function(inst)
            if ismaster() and inst.components ~= nil then
                M.Wrap(inst.components.combat, ownerof, env)
            end
        end)
    end
end
return M
