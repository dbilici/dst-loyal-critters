-- Apply only to positive final food sanity, after character-specific modifiers.
local M = {}
function M.HasFedEets(player, ownerof)
    local leash = player and player.components and player.components.petleash
    if leash == nil then return false end
    for pet in pairs(leash:GetPets()) do
        if pet.prefab == "critter_eets" and ownerof(pet) == player
            and pet.components.perishable ~= nil
            and pet.components.perishable:GetPercent() > .5 then
            return true
        end
    end
    return false
end
function M.InstallPlayer(player, ownerof)
    local eater = player.components and player.components.eater
    if eater == nil or eater._loyalcritters_nutrition then return end
    eater._loyalcritters_nutrition = true
    local previous = eater.custom_stats_mod_fn
    eater.custom_stats_mod_fn = function(inst, health, hunger, sanity, food, feeder)
        if previous ~= nil then
            health, hunger, sanity = previous(inst, health, hunger, sanity, food, feeder)
        end
        if sanity > 0 and M.HasFedEets(inst, ownerof) then sanity = sanity * 1.2 end
        return health, hunger, sanity
    end
end
return M
