local brain = require("brains/crittersbrain")

local WAKE_TO_FOLLOW_DISTANCE = 6
local SLEEP_NEAR_LEADER_DISTANCE = 5

-- Light pets need to stay closer so their light benefits the player.
local LIGHT_WAKE_TO_FOLLOW_DISTANCE = 3.5
local LIGHT_SLEEP_NEAR_LEADER_DISTANCE = 2.5

local function IsLightCritter(inst)
    return inst ~= nil and (inst.prefab == "critter_dragonling" or inst.prefab == "critter_lunarmothling" or inst.prefab == "critter_eyeofterror")
end

local function GetWakeToFollowDistance(inst)
    return IsLightCritter(inst) and LIGHT_WAKE_TO_FOLLOW_DISTANCE or WAKE_TO_FOLLOW_DISTANCE
end

local function GetSleepNearLeaderDistance(inst)
    return IsLightCritter(inst) and LIGHT_SLEEP_NEAR_LEADER_DISTANCE or SLEEP_NEAR_LEADER_DISTANCE
end

local HUNGRY_PERISH_PERCENT = 0.5 -- matches stale tag
local STARVING_PERISH_PERCENT = 0.2 -- matches spoiked tag

local BUFFTIME = TUNING.TOTAL_DAY_TIME
local BUFFMULT = 1.2

local ApplyPuppyDamageBuff
local ApplyKittenSpeedBuff

local function IsLeaderSleeping(inst)
    return inst.components.follower.leader and inst.components.follower.leader:HasTag("sleeping")
end

local function ShouldWakeUp(inst)
    return (DefaultWakeTest(inst) and not IsLeaderSleeping(inst)) or not inst.components.follower:IsNearLeader(GetWakeToFollowDistance(inst))
end

local function ShouldSleep(inst)
    return (DefaultSleepTest(inst) 
            or IsLeaderSleeping(inst))
            and inst.components.follower:IsNearLeader(GetSleepNearLeaderDistance(inst))
end

local function oneat(inst, food)
    local owner = inst.components.follower.leader
    if owner == nil then
        return
    end
    if inst.prefab == "critter_puppy" then -- Puppy: modern damage modifier
        ApplyPuppyDamageBuff(owner)
    end
    if inst.prefab == "critter_kitten" then -- Kitten: modern speed modifier
        ApplyKittenSpeedBuff(owner)
    end
    if inst.prefab == "critter_perdling" then --小鸡
        SpawnPrefab("redpouch").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
	-- minigame around feeding, if fed at the right time, its max hunger goes up, if left too long, its max hunger goes down
	local perish = inst.components.perishable:GetPercent()
	local is_wellfed = inst.components.crittertraits:IsDominantTrait("wellfed")
	if perish <= STARVING_PERISH_PERCENT then
		inst.components.perishable.perishtime = math.max(inst.components.perishable.perishtime - TUNING.CRITTER_HUNGERTIME_DELTA, is_wellfed and TUNING.CRITTER_DOMINANTTRAIT_HUNGERTIME_MIN or TUNING.CRITTER_HUNGERTIME_MIN)
	elseif perish <= HUNGRY_PERISH_PERCENT then
		inst.components.perishable.perishtime = math.min(inst.components.perishable.perishtime + TUNING.CRITTER_HUNGERTIME_DELTA, is_wellfed and TUNING.CRITTER_DOMINANTTRAIT_HUNGERTIME_MAX or TUNING.CRITTER_HUNGERTIME_MAX)
	else
		if is_wellfed and inst.components.perishable.perishtime < TUNING.CRITTER_DOMINANTTRAIT_HUNGERTIME_MIN then
			inst.components.perishable.perishtime = TUNING.CRITTER_DOMINANTTRAIT_HUNGERTIME_MIN
		end
	end
	
    inst.components.perishable:SetPercent(1)
    inst.components.perishable:StartPerishing()
end

-------------------------------------------------------------------------------
local function GetPeepChance(inst)
    local hunger_percent = inst.components.perishable:GetPercent()
    if hunger_percent <= 0 then
        return 0.8
    elseif hunger_percent < STARVING_PERISH_PERCENT then -- matches spoiled tag
        return (0.2 - inst.components.perishable:GetPercent()) * 2
    elseif hunger_percent < HUNGRY_PERISH_PERCENT then
        return 0.025
    end

    return 0
end

local function IsAffectionate(inst)
    return (inst.components.perishable == nil or inst.components.perishable:GetPercent() > STARVING_PERISH_PERCENT)
            or false
end

local function IsPlayful(inst)
	return IsAffectionate(inst)
end

local function IsSuperCute(inst)
	return true
end


-------------------------------------------------------------------------------
-- Modern modifier helpers.

local PUPPY_DAMAGE_KEY = "betterpet_puppy_damage"
local KITTEN_SPEED_KEY = "betterpet_kitten_speed"

local function ClearPuppyDamageBuff(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner._betterpet_puppy_task ~= nil then
        owner._betterpet_puppy_task:Cancel()
        owner._betterpet_puppy_task = nil
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

    owner._betterpet_puppy_task = owner:DoTaskInTime(BUFFTIME, ClearPuppyDamageBuff)
end

local function ClearKittenSpeedBuff(owner)
    if owner == nil or not owner:IsValid() then
        return
    end

    if owner._betterpet_kitten_task ~= nil then
        owner._betterpet_kitten_task:Cancel()
        owner._betterpet_kitten_task = nil
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

    owner._betterpet_kitten_task = owner:DoTaskInTime(BUFFTIME, ClearKittenSpeedBuff)
end

-------------------------------------------------------------------------------

local function OnSave(inst, data)
    if inst.wormlight ~= nil then
        data.wormlight = inst.wormlight:GetSaveRecord()
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.wormlight ~= nil and inst.wormlight == nil then
        local wormlight = SpawnSaveRecord(data.wormlight)
        if wormlight ~= nil and wormlight.components.spell ~= nil then
            wormlight.components.spell:SetTarget(inst)
            if wormlight:IsValid() then
                if wormlight.components.spell.target == nil then
                    wormlight:Remove()
                else
                    wormlight.components.spell:ResumeSpell()
                end
            end
        end
    end
end

local function OnLoadPostPass(inst)
    if inst._special_powers ~= nil then
        inst:PushEvent("perishchange", {percent = inst.components.perishable:GetPercent()})
    end
end

-------------------------------------------------------------------------------

local function MakeCritter(name, animname, face, diet, flying, data, prefabs)
    local buildname = (data ~= nil and data.buildname) or animname.."_build"
    local assets =
    {
	    Asset("ANIM", "anim/"..buildname..".zip"),
	    Asset("ANIM", "anim/"..animname.."_basic.zip"),
	    Asset("ANIM", "anim/"..animname.."_emotes.zip"),
	    Asset("ANIM", "anim/"..animname.."_traits.zip"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddDynamicShadow()
        inst.entity:AddNetwork()

        inst.DynamicShadow:SetSize(2, .75)

        if face == 2 then
            inst.Transform:SetTwoFaced()
        elseif face == 4 then
            inst.Transform:SetFourFaced()
        elseif face == 6 then
            inst.Transform:SetSixFaced()
        elseif face == 8 then
            inst.Transform:SetEightFaced()
        end

        if name == "critter_dragonling" then -- Dragonling: stronger warm light
            inst.entity:AddLight()
            inst.Light:SetRadius(4.5)
            inst.Light:SetFalloff(0.4)
            inst.Light:SetIntensity(0.9)
            inst.Light:SetColour(235/255, 121/255, 12/255)
            inst.Light:Enable(true)
        elseif name == "critter_lunarmothling" then -- Mothling: soft lunar light
            inst.entity:AddLight()
            inst.Light:SetRadius(4)
            inst.Light:SetFalloff(0.45)
            inst.Light:SetIntensity(0.8)
            inst.Light:SetColour(160/255, 210/255, 255/255)
            inst.Light:Enable(true)
        elseif name == "critter_eyeofterror" then -- Friendly Peeper: tiny thematic eye glow
            inst.entity:AddLight()
            inst.Light:SetRadius(1.5)
            inst.Light:SetFalloff(0.7)
            inst.Light:SetIntensity(0.45)
            inst.Light:SetColour(180/255, 220/255, 255/255)
            inst.Light:Enable(true)
        end

        inst.AnimState:SetBank(animname)
        inst.AnimState:SetBuild(buildname)
        inst.AnimState:PlayAnimation("idle_loop")

        if flying then
            --We want to collide with players
            --MakeFlyingCharacterPhysics(inst, 1, .5)
            inst.entity:AddPhysics()
            inst.Physics:SetMass(1)
            inst.Physics:SetCapsule(.5, 1)
            inst.Physics:SetFriction(0)
            inst.Physics:SetDamping(5)
            inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
            inst.Physics:ClearCollisionMask()
            inst.Physics:CollidesWith(COLLISION.WORLD)
            inst.Physics:CollidesWith(COLLISION.FLYERS)
            inst.Physics:CollidesWith(COLLISION.CHARACTERS)

            inst:AddTag("flying")
        else
            MakeCharacterPhysics(inst, 1, .5)
        end

        inst:AddTag("critter")
        inst:AddTag("companion")
        inst:AddTag("notraptrigger")
        inst:AddTag("noauradamage")
        inst:AddTag("small_livestock")
        inst:AddTag("NOBLOCK")

        if data ~= nil and data.flyingsoundloop ~= nil then
            inst.SoundEmitter:PlaySound(data.flyingsoundloop, "flying")
        end

        inst:AddComponent("spawnfader")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            if name == "critter_lamb" then
                inst:DoTaskInTime(0, function()
                    if inst.replica.container ~= nil then
                        inst.replica.container:WidgetSetup("critter_lamb")
                    end
                end)
            end
            return inst
        end

        if name == "critter_lamb" then --小绵羊
            inst:AddComponent("container")
            inst.components.container:WidgetSetup("critter_lamb")
        end
        if name == "critter_glomling" then -- Glomling: base aura; modmain applies owner/team support rules.
            inst:AddComponent("sanityaura")
            inst.components.sanityaura.aura = TUNING.SANITYAURA_TINY
            inst.components.sanityaura.max_distsq = 100 -- 10 tile radius
        end
		inst.favoritefood = data.favoritefood

        inst.GetPeepChance = GetPeepChance
        inst.IsAffectionate = IsAffectionate
        inst.IsSuperCute = IsSuperCute
        inst.IsPlayful = IsPlayful
        
		inst.playmatetags = {"critter"}
		if data ~= nil and data.playmatetags ~= nil then
			inst.playmatetags = JoinArrays(inst.playmatetags, data.playmatetags)
		end
	
        inst:AddComponent("inspectable")

        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()
        inst.components.follower.keepdeadleader = true
        -- Some DST builds expose follow distance setters on follower/brain helpers.
        -- Guarded so older builds will simply ignore it instead of crashing.
        if (name == "critter_dragonling" or name == "critter_lunarmothling" or name == "critter_eyeofterror") and inst.components.follower.SetFollowDistance ~= nil then
            inst.components.follower:SetFollowDistance(1.5, 2.5, 3.5)
        end

        inst:AddComponent("knownlocations")

        inst:AddComponent("sleeper")
        inst.components.sleeper:SetResistance(3)
        inst.components.sleeper.testperiod = GetRandomWithVariance(6, 2)
        inst.components.sleeper:SetSleepTest(ShouldSleep)
        inst.components.sleeper:SetWakeTest(ShouldWakeUp)

        inst:AddComponent("eater")
        inst.components.eater:SetDiet(diet, diet)
        inst.components.eater:SetOnEatFn(oneat)

        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.CRITTER_HUNGERTIME)
        inst.components.perishable:StartPerishing()

        inst:AddComponent("locomotor")
        inst.components.locomotor:EnableGroundSpeedMultiplier(not flying)
        inst.components.locomotor:SetTriggersCreep(false)
        inst.components.locomotor.softstop = true
        inst.components.locomotor.walkspeed = TUNING.CRITTER_WALK_SPEED

        inst:AddComponent("crittertraits")
        inst:AddComponent("timer")

        inst:SetBrain(brain)
        inst:SetStateGraph("SG"..name)

        --MakeMediumFreezableCharacter(inst, "critters_body")
        --MakeHauntablePanic(inst)

        if data ~= nil and data.special_powers_fn ~= nil then
            inst._special_powers = {}
            inst:ListenForEvent("perishchange", data.special_powers_fn)
            if not POPULATING then
                inst:PushEvent("perishchange", {percent = inst.components.perishable:GetPercent()})
            end
        end

        inst.OnSave = OnSave
        inst.OnLoad = OnLoad
        inst.OnLoadPostPass = OnLoadPostPass

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

-------------------------------------------------------------------------------
local function builder_onbuilt(inst, builder)
    local theta = math.random() * 2 * PI
    local pt = builder:GetPosition()
    local radius = 1
    local offset = FindWalkableOffset(pt, theta, radius, 6, true)
    if offset ~= nil then
        pt.x = pt.x + offset.x
        pt.z = pt.z + offset.z
    end
    builder.components.petleash:SpawnPetAt(pt.x, 0, pt.z, inst.pettype, inst.linked_skinname)
    inst:Remove()
end

local function MakeBuilder(prefab)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()

        inst:AddTag("CLASSIFIED")

        --[[Non-networked entity]]
        inst.persists = false

        --Auto-remove if not spawned by builder
        inst:DoTaskInTime(0, inst.Remove)

        if not TheWorld.ismastersim then
            return inst
        end

        inst.pettype = prefab
        inst.OnBuiltFn = builder_onbuilt

        return inst
    end

    return Prefab(prefab.."_builder", fn, nil, { prefab })
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
local function lunarmoth_special_powers_fn(inst, data)
    if inst._special_powers.buff ~= nil then
        -- Keep the official lunar moth buff in sync with hunger.
        inst._special_powers.buff:EnableLight(data.percent >= HUNGRY_PERISH_PERCENT)
    else
        if data.percent > HUNGRY_PERISH_PERCENT then
            local light = SpawnPrefab("critterbuff_lunarmoth")
            light.entity:SetParent(inst.entity)
            inst._special_powers.buff = light
            inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
            inst:ListenForEvent("onremove", function(buff)
                if inst._special_powers.buff == buff then
                    inst._special_powers.buff = nil
                    inst.AnimState:SetLightOverride(0)
                    inst.DynamicShadow:Enable(true)
                    inst.AnimState:ClearBloomEffectHandle()
                end
            end, inst._special_powers.buff)
            inst.AnimState:SetLightOverride(0.4)
            inst.DynamicShadow:Enable(false)
        end
    end
end

local standard_diet = { FOODGROUP.OMNI }

return MakeCritter("critter_lamb", "sheepington", 6, standard_diet, false, {favoritefood="guacamole"}),
       MakeBuilder("critter_lamb"),
       MakeCritter("critter_puppy", "pupington", 4, standard_diet, false, {favoritefood="monsterlasagna"}),
       MakeBuilder("critter_puppy"),
       MakeCritter("critter_kitten", "kittington", 6, standard_diet, false, {favoritefood="fishsticks"}),
       MakeBuilder("critter_kitten"),
       MakeCritter("critter_perdling", "perdling", 4, standard_diet, false, {favoritefood="trailmix"}),
       MakeBuilder("critter_perdling"),
       MakeCritter("critter_dragonling", "dragonling", 6, standard_diet, true, {favoritefood="hotchili", flyingsoundloop="dontstarve_DLC001/creatures/together/dragonling/fly_LP"}),
       MakeBuilder("critter_dragonling"),
       MakeCritter("critter_glomling", "glomling", 6, standard_diet, true, {favoritefood="taffy", playmatetags={"glommer"}, flyingsoundloop="dontstarve_DLC001/creatures/together/glomling/flap_LP"}),
       MakeBuilder("critter_glomling"),
       MakeCritter("critter_lunarmothling", "lunarmoth", 4, standard_diet, true, {favoritefood="flowersalad", flyingsoundloop="dontstarve_DLC001/creatures/together/dragonling/flap_LP", special_powers_fn=lunarmoth_special_powers_fn}, {"critterbuff_lunarmoth"}),
       MakeBuilder("critter_lunarmothling"),
       MakeCritter("critter_eyeofterror", "eyeofterror_mini", 6, standard_diet, true, {buildname="eyeofterror_mini_basic", favoritefood="baconeggs"}),
       MakeBuilder("critter_eyeofterror")
