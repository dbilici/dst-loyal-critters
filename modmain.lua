PrefabFiles = {
    "critters",
}

local GLOBAL = GLOBAL
local Vector3 = GLOBAL.Vector3
local TUNING = GLOBAL.TUNING
local TheSim = GLOBAL.TheSim
local GetTime = GLOBAL.GetTime
local require = GLOBAL.require
local pcall = GLOBAL.pcall
local ipairs = GLOBAL.ipairs
local pairs = GLOBAL.pairs
local math = GLOBAL.math
local tostring = GLOBAL.tostring
local string = GLOBAL.string
local print = GLOBAL.print
local net_bool = GLOBAL.net_bool
local TheNet = GLOBAL.TheNet

local containers = require("containers")
local WalterCritter = require("loyalcritters/walter")

local GetModConfigData = GetModConfigData

local VERSION = "1.7.3"
local ALLOW_WALTER_CRITTER = GetModConfigData ~= nil and GetModConfigData("allow_walter_critter") == true
local DEBUG_MODE = GetModConfigData ~= nil and GetModConfigData("betterpet_debug") or "off"
local DEBUG_LOG = DEBUG_MODE == true or DEBUG_MODE == "log" or DEBUG_MODE == "announce"
local DEBUG_ANNOUNCE = DEBUG_MODE == "announce"

local function BetterPetDebugLog(message)
    if DEBUG_LOG then
        print("[Loyal Critters Debug] " .. tostring(message))
    end
end

local function BetterPetDebugSay(player, message)
    if DEBUG_ANNOUNCE
        and player ~= nil
        and player:IsValid()
        and player.components ~= nil
        and player.components.talker ~= nil then
        player.components.talker:Say("[Loyal Critters] " .. tostring(message))
    end
end

local function BetterPetDebugLeader(pet, message)
    local leader = pet ~= nil
        and pet.components ~= nil
        and pet.components.follower ~= nil
        and pet.components.follower.leader
        or nil

    local pet_name = pet ~= nil and pet.prefab or "unknown_pet"
    BetterPetDebugLog(pet_name .. ": " .. tostring(message))
    BetterPetDebugSay(leader, message)
end

BetterPetDebugLog("Loaded version=" .. VERSION
    .. ", walter_critter=" .. tostring(ALLOW_WALTER_CRITTER)
    .. ", debug_mode=" .. tostring(DEBUG_MODE))

local BALANCE = {
    -- A pet only helps its owner, and only while it is fed/satiated.
    -- Satiation is read from the critter's perishable hunger meter.
    pet_satiated_min_perish = 0.5,

    glomling_sanity_aura = TUNING.SANITYAURA_TINY or (100 / (30 * 32)),
    -- Owner always follows within ~8 tiles, so this only needs to cover that
    -- range. Full strength is applied regardless of distance (see fallofffn).
    glomling_sanity_max_distsq = 400,

    -- Friendly Peeper rework: it increases the player's maximum camera zoom-out
    -- while the owner is supported. This is a fixed, standard value (12); there
    -- is no longer a mod-config option for it.
    peeper_vision_zoom_bonus = 12,
}

local CRITTER_PREFABS = {
    "critter_lamb",
    "critter_puppy",
    "critter_kitten",
    "critter_perdling",
    "critter_dragonling",
    "critter_glomling",
    "critter_lunarmothling",
    "critter_eyeofterror",
}

local LIGHT_PREFABS = {
    "critter_dragonling",
    "critter_lunarmothling",
    "critterbuff_lunarmoth",
    "critter_eyeofterror",
}

local function IsMasterSim()
    return GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim
end

-------------------------------------------------------------------------------
-- Optional Walter critter access
--
-- Vanilla explicitly sets Walter's petleash maximum to 0 so Woby is his only
-- companion. Woby is managed separately, so allowing one regular pet here lets
-- Walter adopt a critter without replacing or counting Woby. The setting is
-- disabled by default and never lowers a capacity raised by another mod.

local function ApplyWalterCritterAccess(inst)
    if not ALLOW_WALTER_CRITTER
        or not IsMasterSim()
        or inst == nil
        or inst.components == nil
        or inst.components.petleash == nil then
        return
    end

    local changed, current_max = WalterCritter.EnableCritterAccess(inst.components.petleash)

    if changed then
        BetterPetDebugLog("Walter critter access enabled; pet capacity raised from "
            .. tostring(current_max) .. " to 1")
    end
end

local function ConfigureWalterCritterAccess(inst)
    if ALLOW_WALTER_CRITTER and IsMasterSim() then
        inst:DoTaskInTime(0, ApplyWalterCritterAccess)
    end
end

AddPrefabPostInit("walter", ConfigureWalterCritterAccess)

-------------------------------------------------------------------------------
-- Lamb storage

local function ConfigureLambContainer()
    containers.params.critter_lamb = {
        widget = {
            slotpos = {
                Vector3(-37.5,  37.5, 0), Vector3(37.5,  37.5, 0),
                Vector3(-37.5, -37.5, 0), Vector3(37.5, -37.5, 0),
            },
            animbank = "ui_chest_2x2",
            animbuild = "ui_chest_2x2",
            pos = Vector3(0, 200, 0),
            side_align_tip = 160,
        },
        type = "chest",
    }

    containers.params.critter_lamb.itemtestfn = function(container, item, slot)
        return true
    end
end

ConfigureLambContainer()

-------------------------------------------------------------------------------
-- Critter follow distance

local balanced_critter_brain = nil
local brain_load_attempted = false

local function GetBalancedCritterBrain()
    if not brain_load_attempted then
        brain_load_attempted = true

        if pcall ~= nil then
            local ok, brain = pcall(require, "brains/loyalcritters_crittersbrain")
            if ok then
                balanced_critter_brain = brain
            else
                print("[Loyal Critters] Could not load balanced critter brain: " .. tostring(brain))
            end
        else
            -- DST normally exposes pcall through GLOBAL, but keep this fallback so the
            -- failure mode is a clear require error instead of a nil global call.
            balanced_critter_brain = require("brains/loyalcritters_crittersbrain")
        end
    end

    return balanced_critter_brain
end

local function ConfigureCritterBrain(inst)
    if not IsMasterSim() then
        return
    end

    local brain = GetBalancedCritterBrain()
    if brain ~= nil then
        inst:SetBrain(brain)
    end
end

for _, prefab in ipairs(CRITTER_PREFABS) do
    AddPrefabPostInit(prefab, ConfigureCritterBrain)
end

-------------------------------------------------------------------------------
-- Ownership + satiation helpers
--
-- Design: a pet only benefits its own owner, and only while the pet is
-- fed/satiated. Distance/radius no longer matter. Satiation is read from
-- the critter's perishable hunger meter (fed = full, then slowly empties).

local function GetPetOwner(pet)
    return pet ~= nil
        and pet.components ~= nil
        and pet.components.follower ~= nil
        and pet.components.follower.leader
        or nil
end

local function IsPetSatiated(pet)
    return pet ~= nil
        and pet.components ~= nil
        and pet.components.perishable ~= nil
        and pet.components.perishable:GetPercent() > BALANCE.pet_satiated_min_perish
end

-- A pet supports a player only if that player is its owner and the pet is
-- currently satiated. Every owner-only benefit below is gated through this.
local function HasBetterPetSupportForPlayer(pet, player)
    return player ~= nil
        and GetPetOwner(pet) == player
        and IsPetSatiated(pet)
end

-------------------------------------------------------------------------------
-- Glomling sanity support
--
-- Owner-only: the sanity component asks each nearby sanity-aura entity for its
-- aura, passing the recalculating player as the observer. We return the aura
-- only when that observer is the Glomling's owner and the Glomling is satiated,
-- so teammates never receive it. Full strength is applied regardless of
-- distance (fallofffn returns 1).

local function GetGlomlingSanityAura(inst, observer)
    if HasBetterPetSupportForPlayer(inst, observer) then
        return BALANCE.glomling_sanity_aura
    end

    return 0
end

local function GlomlingSanityFalloff()
    return 1
end

local function ConfigureGlomlingSanityAura(inst)
    if not IsMasterSim() then
        return
    end

    inst:DoTaskInTime(0, function()
        if inst.components.sanityaura == nil then
            inst:AddComponent("sanityaura")
        end

        inst.components.sanityaura.aura = 0
        inst.components.sanityaura.aurafn = GetGlomlingSanityAura
        inst.components.sanityaura.fallofffn = GlomlingSanityFalloff
        inst.components.sanityaura.max_distsq = BALANCE.glomling_sanity_max_distsq
    end)
end

AddPrefabPostInit("critter_glomling", ConfigureGlomlingSanityAura)

-------------------------------------------------------------------------------
-- Light balance

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

local function ApplyLightSettings(inst, settings)
    settings = settings or (inst ~= nil and LIGHT_SETTINGS[inst.prefab] or nil)

    if inst == nil or settings == nil then
        return
    end

    if inst.Light == nil and inst.entity ~= nil then
        inst.entity:AddLight()
    end

    if inst.Light == nil then
        return
    end

    local light = inst.Light
    local colour = settings.colour

    if colour ~= nil and light.SetColour ~= nil then
        light:SetColour(colour[1], colour[2], colour[3])
    end

    if settings.radius ~= nil and light.SetRadius ~= nil then
        light:SetRadius(settings.radius)
    end

    if settings.intensity ~= nil and light.SetIntensity ~= nil then
        light:SetIntensity(settings.intensity)
    end

    if settings.falloff ~= nil and light.SetFalloff ~= nil then
        light:SetFalloff(settings.falloff)
    end

    if light.Enable ~= nil then
        light:Enable(true)
    end
end

local function ApplyOwnedLightSettings(inst)
    local settings = inst ~= nil and LIGHT_SETTINGS[inst.prefab] or nil

    ApplyLightSettings(inst, settings)

    if inst ~= nil and inst.wormlight ~= nil then
        ApplyLightSettings(inst.wormlight, settings)
    end

    if inst ~= nil and inst._special_powers ~= nil and inst._special_powers.buff ~= nil then
        ApplyLightSettings(inst._special_powers.buff, settings)
    end
end

local function ConfigureLightPrefab(inst)
    inst:DoTaskInTime(0, ApplyOwnedLightSettings)

    inst:ListenForEvent("perishchange", function()
        inst:DoTaskInTime(0, ApplyOwnedLightSettings)
    end)

    if inst.EnableLight ~= nil and inst._betterpet_enablelight == nil then
        local original_enable_light = inst.EnableLight
        inst._betterpet_enablelight = original_enable_light

        inst.EnableLight = function(light_inst, enabled, ...)
            original_enable_light(light_inst, enabled, ...)

            if enabled ~= false then
                light_inst:DoTaskInTime(0, ApplyOwnedLightSettings)
            end
        end
    end
end

for _, prefab in ipairs(LIGHT_PREFABS) do
    AddPrefabPostInit(prefab, ConfigureLightPrefab)
end

-------------------------------------------------------------------------------
-- Friendly Peeper vision support
--
-- Horizon Expandinator-style utility: the Peeper does not touch sanity,
-- enlightenment, clothing, darkness, or other rate systems. Instead, it raises
-- the local player's maximum camera zoom-out while the player is supported.
--
-- Owner-only: a player is supported when they own a satiated Friendly Peeper.
-- The server decides support state; each client applies the camera locally.

local PEEPER_VISION_CHECK_PERIOD = 1
local PEEPER_VISION_DIRTY_EVENT = "betterpet_peeper_visiondirty"
-- On activation we ease the camera out toward this fraction of the newly
-- unlocked zoom range, mirroring the Horizon Expandinator's MaximizeDistance.
local PEEPER_VISION_ZOOM_FACTOR = 0.7

local function PlayerHasSatiatedPeeper(player)
    if player == nil
        or player.components == nil
        or player.components.petleash == nil then
        return false
    end

    for pet in pairs(player.components.petleash:GetPets()) do
        if pet ~= nil
            and pet.prefab == "critter_eyeofterror"
            and IsPetSatiated(pet) then
            return true
        end
    end

    return false
end

local function SetPeeperVisionNet(player, enabled)
    if player ~= nil and player._betterpet_peeper_vision_enabled ~= nil then
        player._betterpet_peeper_vision_enabled:set(enabled == true)
    end
end

local function GetPeeperVisionNet(player)
    return player ~= nil
        and player._betterpet_peeper_vision_enabled ~= nil
        and player._betterpet_peeper_vision_enabled:value()
        or false
end

local function UpdatePeeperVisionState(player)
    if player == nil then
        return
    end

    local was_enabled = GetPeeperVisionNet(player)
    local enabled = PlayerHasSatiatedPeeper(player)

    if enabled ~= was_enabled then
        SetPeeperVisionNet(player, enabled)

        local player_name = player.name or (player.GetDisplayName ~= nil and player:GetDisplayName()) or "player"
        BetterPetDebugLog(player_name .. ": Peeper vision " .. (enabled and "ON" or "OFF"))
        BetterPetDebugSay(player, "Peeper vision " .. (enabled and "ON" or "OFF"))
    end
end

local function IsDedicatedServer()
    return TheNet ~= nil and TheNet:IsDedicated()
end

local function IsLocalPlayer(player)
    return GLOBAL.ThePlayer ~= nil and player == GLOBAL.ThePlayer
end

local function SetBetterPetCameraMaxDistance(camera, max_distance)
    if camera == nil or max_distance == nil then
        return
    end

    camera.maxdist = max_distance

    -- Only nudge the zoom *target* back into range. We intentionally do NOT
    -- touch camera.distance directly: the FollowCamera eases distance toward
    -- its target every frame, and snapping distance here caused the visible
    -- camera "jump" (pitch/height are derived from the current distance).
    if camera.distancetarget ~= nil and camera.distancetarget > max_distance then
        camera.distancetarget = max_distance
    end
end

local function ApplyBetterPetPeeperVisionCamera(active)
    local camera = GLOBAL.TheCamera
    if camera == nil or camera.maxdist == nil then
        return
    end

    if camera._betterpet_peeper_base_maxdist == nil then
        camera._betterpet_peeper_base_maxdist = camera.maxdist
    end

    local base_maxdist = camera._betterpet_peeper_base_maxdist
    local target_maxdist = base_maxdist + BALANCE.peeper_vision_zoom_bonus

    if active then
        local was_active = camera._betterpet_peeper_vision_active == true
        camera._betterpet_peeper_vision_active = true

        -- Do not fight dedicated camera/zoom mods. Only raise the limit when our
        -- target is higher than the current limit.
        if camera.maxdist < target_maxdist then
            SetBetterPetCameraMaxDistance(camera, target_maxdist)
            camera._betterpet_peeper_applied_maxdist = target_maxdist
        else
            camera._betterpet_peeper_applied_maxdist = nil
        end

        -- On the moment vision turns on (and only when we actually raised the
        -- limit), automatically zoom the camera out toward the new range. We set
        -- distancetarget (not distance) so the game eases the camera smoothly,
        -- and we only ever push the view out -- never pull the player back in if
        -- they had already zoomed out further themselves.
        if not was_active
            and camera._betterpet_peeper_applied_maxdist ~= nil
            and camera.mindist ~= nil
            and camera.distancetarget ~= nil then
            local zoom_target = (camera.maxdist - camera.mindist) * PEEPER_VISION_ZOOM_FACTOR + camera.mindist
            if zoom_target > camera.distancetarget then
                camera.distancetarget = zoom_target
            end
        end
    elseif camera._betterpet_peeper_vision_active then
        camera._betterpet_peeper_vision_active = false

        -- Restore only if the current value still looks like the value we applied.
        -- This avoids lowering another zoom mod's larger limit.
        if camera._betterpet_peeper_applied_maxdist ~= nil
            and camera.maxdist <= camera._betterpet_peeper_applied_maxdist
            and camera.maxdist > base_maxdist then
            SetBetterPetCameraMaxDistance(camera, base_maxdist)
        end

        camera._betterpet_peeper_applied_maxdist = nil
    end
end

local function UpdateLocalPeeperVisionCamera(player)
    if IsDedicatedServer() or not IsLocalPlayer(player) then
        return
    end

    ApplyBetterPetPeeperVisionCamera(GetPeeperVisionNet(player))
end

local function ConfigurePeeperVision(player)
    if net_bool ~= nil and player._betterpet_peeper_vision_enabled == nil then
        player._betterpet_peeper_vision_enabled = net_bool(player.GUID, "betterpet.peepervision", PEEPER_VISION_DIRTY_EVENT)
    end

    if IsMasterSim() then
        player:DoTaskInTime(0, UpdatePeeperVisionState)
        player._betterpet_peeper_vision_task = player:DoPeriodicTask(PEEPER_VISION_CHECK_PERIOD, UpdatePeeperVisionState, PEEPER_VISION_CHECK_PERIOD)

        player:ListenForEvent("onremove", function(inst)
            SetPeeperVisionNet(inst, false)
        end)
    end

    if not IsDedicatedServer() then
        player:ListenForEvent(PEEPER_VISION_DIRTY_EVENT, UpdateLocalPeeperVisionCamera)
        player:DoTaskInTime(0, UpdateLocalPeeperVisionCamera)

        player:ListenForEvent("onremove", function(inst)
            if IsLocalPlayer(inst) then
                ApplyBetterPetPeeperVisionCamera(false)
            end
        end)
    end
end

-- Maps each pet prefab to the benefit it provides, and whether that benefit is
-- gated on the pet being fed/satiated. Light/storage are always-on.
local PET_BENEFITS = {
    critter_glomling      = { label = "sanity aura",      gated = true },
    critter_puppy         = { label = "+damage",          gated = true },
    critter_kitten        = { label = "+speed",           gated = true },
    critter_eyeofterror   = { label = "camera vision",    gated = true },
    critter_dragonling    = { label = "light",            gated = false },
    critter_lunarmothling = { label = "light",            gated = false },
    critter_lamb          = { label = "storage",          gated = false },
    critter_perdling      = { label = "-hunger drain",    gated = true },
}

local function BetterPetDebugStatus(player)
    if not DEBUG_LOG and not DEBUG_ANNOUNCE then
        print("[Loyal Critters Debug] Debug Mode is off. Enable it in mod configuration for live test messages.")
    end

    player = player or (GLOBAL.AllPlayers ~= nil and GLOBAL.AllPlayers[1] or nil)
    if player == nil then
        print("[Loyal Critters Debug] No player found for status check.")
        return
    end

    local satiated_min = (BALANCE ~= nil and BALANCE.pet_satiated_min_perish) or 0.5

    -- Header line: player-level vision state + current camera zoom limit.
    local header = "version=" .. VERSION
        .. ", walter_critter=" .. tostring(ALLOW_WALTER_CRITTER)
        .. ", debug_mode=" .. tostring(DEBUG_MODE)
        .. ", player=" .. tostring(player.name or player.prefab or player.userid or "unknown")
        .. ", Peeper vision net=" .. tostring(GetPeeperVisionNet(player))
    local player_petleash = player.components ~= nil and player.components.petleash or nil
    if player_petleash ~= nil and player_petleash.GetMaxPets ~= nil then
        header = header .. ", pet_capacity=" .. tostring(player_petleash:GetMaxPets())
    end
    local camera = GLOBAL.TheCamera
    if camera ~= nil and camera.maxdist ~= nil and string ~= nil and string.format ~= nil then
        header = header .. ", camera maxdist=" .. string.format("%.2f", camera.maxdist)
    end
    print("[Loyal Critters Debug] " .. header)

    -- Per-pet detail. Benefits are owner-only now, so we look at THIS player's
    -- own pets via petleash rather than scanning nearby critters.
    local petleash = player_petleash
    local summary_parts = {}

    if petleash == nil then
        print("[Loyal Critters Debug]   (no petleash on this player)")
    else
        local owns_any = false
        for pet in pairs(petleash:GetPets()) do
            if pet ~= nil and pet.prefab ~= nil then
                owns_any = true

                local perish = (pet.components ~= nil and pet.components.perishable ~= nil)
                    and pet.components.perishable:GetPercent() or nil
                local fed = perish ~= nil and perish > satiated_min
                local perish_txt = perish ~= nil and string.format("%.0f%%", perish * 100) or "n/a"

                local info = PET_BENEFITS[pet.prefab]
                local label = info ~= nil and info.label or "?"
                local gated = info ~= nil and info.gated or false

                local state
                if gated then
                    state = fed and (label .. " ACTIVE") or (label .. " off (needs feeding)")
                else
                    state = label .. " (always on)"
                end

                print("[Loyal Critters Debug]   " .. pet.prefab
                    .. ": hunger=" .. perish_txt
                    .. " fed=" .. tostring(fed)
                    .. " -> " .. state)

                local short = string.gsub(pet.prefab, "^critter_", "")
                table.insert(summary_parts, short .. "(" .. (fed and "fed" or "hungry") .. ")")
            end
        end

        if not owns_any then
            print("[Loyal Critters Debug]   (this player owns no pets)")
            table.insert(summary_parts, "no pets")
        end
    end

    -- Compact single-bubble version for in-game announce mode.
    local say_msg = header
    if #summary_parts > 0 then
        say_msg = say_msg .. " | " .. table.concat(summary_parts, " ")
    end
    BetterPetDebugSay(player, say_msg)
end

GLOBAL.BetterPetDebugStatus = BetterPetDebugStatus
GLOBAL.c_betterpet_status = BetterPetDebugStatus
GLOBAL.c_loyalcritters_status = BetterPetDebugStatus

AddPlayerPostInit(ConfigurePeeperVision)
