-- Return only a real player whose petleash still owns this critter.
local M = {}
function M.GetPetOwner(pet)
    local follower = pet and pet.components and pet.components.follower
    local owner = follower and follower:GetLeader()
    if owner == nil or not owner:IsValid() or not owner:HasTag("player") then
        return nil
    end
    local leash = owner.components and owner.components.petleash
    return leash ~= nil and leash:IsPet(pet) and owner or nil
end
return M
