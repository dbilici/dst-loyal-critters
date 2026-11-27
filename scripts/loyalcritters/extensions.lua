-- Vanilla critter extensions. Dependencies are supplied by modmain.
local M = {}

function M.Install(AddPrefabPostInit, AddBrainPostInit, GetPetOwner, IsMasterSim)
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
        -- container_replica initializes its widget from containers.params
        -- on the client when the entity's replicated tags arrive.
        if not IsMasterSim() then return end
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

        local function RefreshStorage(pet)
            local owner = GetPetOwner(pet)
            local leader = pet.components.follower:GetLeader()
            local canopen = owner ~= nil
            if container.canbeopened ~= canopen then
                container.canbeopened = canopen
                if not canopen then container:Close() end
            end
            if owner == nil then
                -- Do not drop items during a temporary detach or save/load.
                -- Only a confirmed non-player adoption empties storage.
                local leash = leader and leader.components and leader.components.petleash
                if leader ~= nil and not leader:HasTag("player")
                    and leash ~= nil and leash:IsPet(pet) and not container:IsEmpty() then
                    container:DropEverything()
                end
            end
        end

        container.canbeopened = false
        inst:ListenForEvent("leaderchanged", function(pet)
            container:Close()
            pet:DoTaskInTime(0, RefreshStorage)
        end)
        inst:DoTaskInTime(0, RefreshStorage)
        inst:DoPeriodicTask(1, RefreshStorage)
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
end

return M
