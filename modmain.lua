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

local VERSION = "1.8.0"
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

local GetPetOwner = require("loyalcritters/ownership").GetPetOwner

require("loyalcritters/extensions").Install(AddPrefabPostInit, AddBrainPostInit,
    GetPetOwner, IsMasterSim)

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

require("loyalcritters/lighting").Install(AddPrefabPostInit, IsMasterSim)

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
            and HasBetterPetSupportForPlayer(pet, player) then
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

local PeeperCamera = require("loyalcritters/camera")

local function ApplyBetterPetPeeperVisionCamera(active)
    PeeperCamera.Apply(GLOBAL.TheCamera, active, BALANCE.peeper_vision_zoom_bonus,
        PEEPER_VISION_ZOOM_FACTOR)
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
    critter_bulbin        = { label = "-20% detection | Meat masking", gated = true },
    critter_eets          = { label = "+20% food sanity", gated = true },
}

local Aggro = require("loyalcritters/aggro")
local function DebugPlayer(player)
    if not IsMasterSim() then return nil end
    return player or (GLOBAL.ConsoleCommandPlayer ~= nil and GLOBAL.ConsoleCommandPlayer() or nil)
end

local function DebugOutput(player, message)
    print("[Loyal Critters Debug] " .. message)
    BetterPetDebugSay(player, message)
end

local function BetterPetDebugStatus(player)
    player = DebugPlayer(player)
    if player == nil then return end
    local leash = player.components and player.components.petleash
    local parts = {}
    for pet in pairs(leash ~= nil and leash:GetPets() or {}) do
        local info = PET_BENEFITS[pet.prefab]
        if info ~= nil then
            local owned = GetPetOwner(pet) == player
            local perish = pet.components and pet.components.perishable
            local fullness = perish and perish:GetPercent()
            local active = owned and (not info.gated or IsPetSatiated(pet))
            local name = string.gsub(pet.prefab, "^critter_", "")
            local state = not owned and "NOT OWNED" or (active and "ON" or "OFF")
            GLOBAL.table.insert(parts, name .. " " .. state .. " | " ..
                (fullness and string.format("%.0f%% fed", fullness*100) or "n/a") ..
                " | " .. info.label)
        end
    end
    GLOBAL.table.sort(parts)
    DebugOutput(player, #parts > 0 and GLOBAL.table.concat(parts, "\n") or "No critters owned.")
end

GLOBAL.BetterPetDebugStatus = BetterPetDebugStatus
GLOBAL.c_betterpet_status = BetterPetDebugStatus
GLOBAL.c_loyalcritters_status = BetterPetDebugStatus
GLOBAL.c_lc = BetterPetDebugStatus

AddPlayerPostInit(ConfigurePeeperVision)
local Nutrition = require("loyalcritters/nutrition")
AddPlayerPostInit(function(player)
    if IsMasterSim() then
        player:DoTaskInTime(0, function(inst) Nutrition.InstallPlayer(inst, GetPetOwner) end)
    end
end)
Aggro.Install(AddPrefabPostInit, GetPetOwner, IsMasterSim, GLOBAL)
GLOBAL.c_lc_aggro = function()
    local player = DebugPlayer()
    if player == nil then return end
    local active = Aggro.HasFedBulbin(player, GetPetOwner)
    local watch = player._lc_aggro_watch
    local status = active and string.format("ON (x%.1f)", Aggro.MULTIPLIER) or "OFF (x1.0)"
    if watch == nil then
        DebugOutput(player, "Bulbin " .. status .. " | Watch off")
        return
    end
    local last = watch.last
    if last == nil then
        DebugOutput(player, "Bulbin " .. status .. " | No eligible search observed")
        return
    end
    local line = string.format("%s: %.1f / %.1f (base %.1f) | %s",
        last.enemy or "enemy", last.distance, last.effective, last.base,
        last.allowed and "PASS" or "BLOCK")
    print(string.format("[Loyal Critters Debug] aggro samples=%d enemy=%s guid=%s sample_age=%.1fs active_at_sample=%s",
        watch.count, last.enemy or "?", tostring(last.guid), GetTime()-last.time, tostring(last.active)))
    DebugOutput(player, "Bulbin NOW " .. status .. "\nLAST: " .. line)
end
GLOBAL.c_loyalcritters_aggro = GLOBAL.c_lc_aggro
GLOBAL.c_lc_odor = function()
    local player = DebugPlayer()
    if player == nil then return end
    local active = Aggro.HasFedBulbin(player, GetPetOwner)
    local watch = player._lc_aggro_watch
    local sample = watch and watch.odor
    local result = sample and (sample.masked and "MEAT MASKED" or "VANILLA TARGET") or "No eligible Bunnyman search observed"
    DebugOutput(player, "Odor Masking NOW " .. (active and "ON" or "OFF") .. "\nLAST: " .. result)
end
GLOBAL.c_lc_watch = function(enabled)
    local player = DebugPlayer()
    if player == nil then return end
    if enabled == false then
        player._lc_aggro_watch = nil
    else
        player._lc_aggro_watch = {count=0}
    end
    DebugOutput(player, enabled == false and "Aggro watch OFF" or "Aggro watch ON (reset)")
end
GLOBAL.c_lc_help = function()
    local player = DebugPlayer()
    if player == nil then return end
    DebugOutput(player, "c_lc() status | c_lc_watch() start/reset\nc_lc_aggro() | c_lc_odor() | c_lc_watch(false) stop")
end
