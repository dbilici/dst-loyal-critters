-- Extend vanilla critters instead of replacing their prefab definitions.
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

local VERSION = "1.7.4"
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
    "critter_bulbin",
    "critter_eets",
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

-- Ownership + satiation helpers
--
-- Design: a pet only benefits its own owner, and only while the pet is
-- fed/satiated. Distance/radius no longer matter. Satiation is read from
-- the critter's perishable hunger meter (fed = full, then slowly empties).

local function GetPetOwner(pet)
    local follower = pet and pet.components and pet.components.follower
    local owner = follower and follower:GetLeader()
    if owner == nil or not owner:IsValid() or not owner:HasTag("player") then
        return nil
    end
    local leash = owner.components and owner.components.petleash
    return leash ~= nil and leash:IsPet(pet) and owner or nil
end

-- Preserve vanilla behavior trees, including jumping and minigames.
local function PatchOwnerFollow(node)
    if node == nil then return end
    if node.name == "Follow" and node.target_dist == 4 and node.max_dist == 4.5 then
        node.target_dist_fn = function(pet)
            return GetPetOwner(pet) ~= nil and 6 or 4
        end
        node.max_dist_fn = function(pet)
            return GetPetOwner(pet) ~= nil and 8 or 4.5
        end
    end
    for _, child in ipairs(node.children or {}) do
        PatchOwnerFollow(child)
    end
end

AddBrainPostInit("crittersbrain", function(brain)
    if brain.bt ~= nil then PatchOwnerFollow(brain.bt.root) end
end)

-- Original player modifiers, now independent of the vanilla prefab factory.
local BUFFMULT = 1.2
local PERDLING_HUNGER_RATE = 0.8
local HUNGRY_PERISH_PERCENT = 0.5
local ApplyPuppyDamageBuff, ApplyKittenSpeedBuff

local PUPPY_DAMAGE_KEY = "betterpet_puppy_damage"
local KITTEN_SPEED_KEY = "betterpet_kitten_speed"
local PERDLING_HUNGER_KEY = "betterpet_perdling_hunger"

local function ClearPuppyDamageBuff(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner.components ~= nil and owner.components.combat ~= nil then
        local combat = owner.components.combat
        if combat.externaldamagemultipliers ~= nil then
            combat.externaldamagemultipliers:RemoveModifier(owner, PUPPY_DAMAGE_KEY)
        elseif owner._betterpet_puppy_old_damagemultiplier ~= nil then
            combat.damagemultiplier = owner._betterpet_puppy_old_damagemultiplier
            owner._betterpet_puppy_old_damagemultiplier = nil
        end
    end

    owner:RemoveTag("puppypower")
end

ApplyPuppyDamageBuff = function(owner)
    if owner == nil or owner.components == nil or owner.components.combat == nil or owner:HasTag("puppypower") then
        return
    end

    owner:AddTag("puppypower")

    local combat = owner.components.combat
    if combat.externaldamagemultipliers ~= nil then
        combat.externaldamagemultipliers:SetModifier(owner, BUFFMULT, PUPPY_DAMAGE_KEY)
    else
        owner._betterpet_puppy_old_damagemultiplier = combat.damagemultiplier or 1
        combat.damagemultiplier = owner._betterpet_puppy_old_damagemultiplier * BUFFMULT
    end
end

local function ClearKittenSpeedBuff(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner.components ~= nil and owner.components.locomotor ~= nil then
        local locomotor = owner.components.locomotor
        if locomotor.RemoveExternalSpeedMultiplier ~= nil then
            locomotor:RemoveExternalSpeedMultiplier(owner, KITTEN_SPEED_KEY)
        elseif owner._betterpet_kitten_old_walkspeed ~= nil then
            locomotor.walkspeed = owner._betterpet_kitten_old_walkspeed
            locomotor.runspeed = owner._betterpet_kitten_old_runspeed
            owner._betterpet_kitten_old_walkspeed = nil
            owner._betterpet_kitten_old_runspeed = nil
        end
    end

    owner:RemoveTag("kittenspeed")
end

ApplyKittenSpeedBuff = function(owner)
    if owner == nil or owner.components == nil or owner.components.locomotor == nil or owner:HasTag("kittenspeed") then
        return
    end

    owner:AddTag("kittenspeed")

    local locomotor = owner.components.locomotor
    if locomotor.SetExternalSpeedMultiplier ~= nil then
        locomotor:SetExternalSpeedMultiplier(owner, KITTEN_SPEED_KEY, BUFFMULT)
    else
        owner._betterpet_kitten_old_walkspeed = locomotor.walkspeed
        owner._betterpet_kitten_old_runspeed = locomotor.runspeed
        locomotor.walkspeed = locomotor.walkspeed * BUFFMULT
        locomotor.runspeed = locomotor.runspeed * BUFFMULT
    end
end

local function ClearPerdlingHungerBuff(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner.components ~= nil and owner.components.hunger ~= nil then
        local hunger = owner.components.hunger
        if hunger.burnratemodifiers ~= nil then
            hunger.burnratemodifiers:RemoveModifier(owner, PERDLING_HUNGER_KEY)
        elseif owner._betterpet_perdling_old_burnrate ~= nil then
            hunger.burnrate = owner._betterpet_perdling_old_burnrate
            owner._betterpet_perdling_old_burnrate = nil
        end
    end

    owner:RemoveTag("perdlinghunger")
end

local function ApplyPerdlingHungerBuff(owner)
    if owner == nil or owner.components == nil or owner.components.hunger == nil or owner:HasTag("perdlinghunger") then
        return
    end

    owner:AddTag("perdlinghunger")

    local hunger = owner.components.hunger
    if hunger.burnratemodifiers ~= nil then
        -- Preferred modern path: a named multiplicative modifier on the hunger
        -- burn rate. A value below 1 means hunger drains more slowly.
        hunger.burnratemodifiers:SetModifier(owner, PERDLING_HUNGER_RATE, PERDLING_HUNGER_KEY)
    else
        -- Fallback for older builds that only expose the deprecated burnrate.
        owner._betterpet_perdling_old_burnrate = hunger.burnrate or 1
        hunger.burnrate = (hunger.burnrate or 1) * PERDLING_HUNGER_RATE
    end
end

-------------------------------------------------------------------------------
-- Feed buff manager: the puppy damage, kitten speed and perdling hunger buffs
-- apply only to the owner, and only while the pet is fed/satiated. This runs
-- periodically instead of using a fixed timer, and is cleaned up immediately
-- when the pet is abandoned/removed (see the onremove listener in fn).

local SATIATED_MIN_PERISH = HUNGRY_PERISH_PERCENT -- perishable percent > 0.5 = fed/satiated

-- Owner-only feed buffs keyed by pet prefab. Add new "while fed" pets here.
local FEED_BUFFS = {
    critter_puppy    = { apply = ApplyPuppyDamageBuff,    clear = ClearPuppyDamageBuff },
    critter_kitten   = { apply = ApplyKittenSpeedBuff,    clear = ClearKittenSpeedBuff },
    critter_perdling = { apply = ApplyPerdlingHungerBuff, clear = ClearPerdlingHungerBuff },
}

local function ManageFeedBuff(inst)
    local buff = FEED_BUFFS[inst.prefab]
    if buff == nil then
        return
    end

    local owner = GetPetOwner(inst)
    local satiated = inst.components.perishable ~= nil
        and inst.components.perishable:GetPercent() > SATIATED_MIN_PERISH

    if owner ~= nil and satiated then
        -- If ownership somehow changed while buffed, release the old owner first.
        if inst._betterpet_buff_owner ~= nil and inst._betterpet_buff_owner ~= owner then
            buff.clear(inst._betterpet_buff_owner)
        end
        inst._betterpet_buff_owner = owner
        buff.apply(owner)
    elseif inst._betterpet_buff_owner ~= nil then
        buff.clear(inst._betterpet_buff_owner)
        inst._betterpet_buff_owner = nil
    end
end

-------------------------------------------------------------------------------


local function ClearFeedBuff(pet)
    local buff = FEED_BUFFS[pet.prefab]
    if buff ~= nil and pet._betterpet_buff_owner ~= nil then
        buff.clear(pet._betterpet_buff_owner)
        pet._betterpet_buff_owner = nil
    end
end

local function ConfigureFeedBuff(pet)
    if not IsMasterSim() then return end
    pet:ListenForEvent("leaderchanged", function(inst)
        ClearFeedBuff(inst)
        inst:DoTaskInTime(0, ManageFeedBuff)
    end)
    pet:ListenForEvent("perishchange", ManageFeedBuff)
    pet:ListenForEvent("onremove", ClearFeedBuff)
    pet:DoTaskInTime(0, ManageFeedBuff)
    pet:DoPeriodicTask(1, ManageFeedBuff)
end
for prefab in pairs(FEED_BUFFS) do
    AddPrefabPostInit(prefab, ConfigureFeedBuff)
end

AddPrefabPostInit("critter_lamb", function(inst)
    if not IsMasterSim() then
        inst:DoTaskInTime(0, function()
            if inst.replica.container ~= nil then
                inst.replica.container:WidgetSetup("critter_lamb")
            end
        end)
        return
    end
    if inst.components.container == nil then inst:AddComponent("container") end
    local container = inst.components.container
    container:WidgetSetup("critter_lamb")
    if inst.components.preserver == nil then inst:AddComponent("preserver") end
    inst.components.preserver:SetPerishRateMultiplier(1.5)
    local open = container.Open
    container.Open = function(self, doer, ...)
        if doer ~= nil and GetPetOwner(inst) == doer then
            return open(self, doer, ...)
        end
    end
    inst:ListenForEvent("leaderchanged", function(pet)
        container:Close()
        pet:DoTaskInTime(0, function()
            local leader = pet.components.follower:GetLeader()
            if leader ~= nil and not leader:HasTag("player") then
                container:DropEverything()
            end
        end)
    end)
end)

-- Keep light pets close while sleeping; NPC owners keep vanilla distances.
for _, prefab in ipairs({"critter_dragonling", "critter_lunarmothling", "critter_eyeofterror"}) do
    AddPrefabPostInit(prefab, function(inst)
        if not IsMasterSim() then return end
        local sleeper = inst.components.sleeper
        if sleeper == nil then return end
        local sleep, wake = sleeper.sleeptestfn, sleeper.waketestfn
        if sleep ~= nil then
            sleeper:SetSleepTest(function(pet)
                return sleep(pet) and (GetPetOwner(pet) == nil or pet.components.follower:IsNearLeader(2.5))
            end)
        end
        if wake ~= nil then
            sleeper:SetWakeTest(function(pet)
                return wake(pet) or (GetPetOwner(pet) ~= nil and not pet.components.follower:IsNearLeader(3.5))
            end)
        end
    end)
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
    critter_bulbin        = { label = "vanilla behavior", gated = false },
    critter_eets          = { label = "vanilla behavior", gated = false },
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
