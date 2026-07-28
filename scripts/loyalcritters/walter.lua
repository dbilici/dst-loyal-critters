local WalterCritter = {}

function WalterCritter.EnableCritterAccess(petleash)
    if petleash == nil
        or petleash.GetMaxPets == nil
        or petleash.SetMaxPets == nil then
        return false, nil
    end

    local current_max = petleash:GetMaxPets() or 0
    if current_max < 1 then
        petleash:SetMaxPets(1)
        return true, current_max
    end

    return false, current_max
end

return WalterCritter
