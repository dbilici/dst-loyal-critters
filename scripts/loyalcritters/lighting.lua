-- Light settings are shared by server and clients; never overwrite vanilla helper lifetime.
local M = {}
local LIGHT_SETTINGS = {
    critter_dragonling = {
        colour = { 1.00, 0.35, 0.12 }, -- warm orange-red
        radius = 1.75,
        intensity = 0.55,
        falloff = 0.75,
    },

    critter_lunarmothling = {
        colour = { 1.00, 1.00, 1.00 }, -- clean white moth glow
        radius = 1.65,
        intensity = 0.50,
        falloff = 0.80,
    },

    -- Mothling may use this helper light/buff internally, so keep it white too.
    critterbuff_lunarmoth = {
        colour = { 1.00, 1.00, 1.00 },
        radius = 1.65,
        intensity = 0.50,
        falloff = 0.80,
    },

    critter_eyeofterror = {
        colour = { 0.10, 0.35, 1.00 }, -- creepy cold blue
        radius = 1.60,
        intensity = 0.50,
        falloff = 0.95,
    },
}


function M.Configure(inst, ismaster)
    local settings = LIGHT_SETTINGS[inst.prefab]
    if settings == nil then return end
    local helper = inst.prefab == "critterbuff_lunarmoth"
    if not helper and inst.Light == nil then
        inst.entity:AddLight()
    end
    local function apply(pet)
        local light = pet.Light
        if light == nil then return end
        light:SetColour(settings.colour[1], settings.colour[2], settings.colour[3])
        light:SetRadius(settings.radius)
        light:SetIntensity(settings.intensity)
        light:SetFalloff(settings.falloff)
        -- Vanilla owns the helper's enable/disable lifecycle.
        if ismaster and not helper then light:Enable(true) end
    end
    apply(inst)
    if not helper then
        inst:DoTaskInTime(0, apply)
        inst:ListenForEvent("perishchange", function(pet)
            pet:DoTaskInTime(0, apply)
        end)
    end
end

function M.Install(addprefabpostinit, ismaster)
    for prefab in pairs(LIGHT_SETTINGS) do
        addprefabpostinit(prefab, function(inst) M.Configure(inst, ismaster()) end)
    end
end

return M
