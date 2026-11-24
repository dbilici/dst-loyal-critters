package.path = "./scripts/?.lua;" .. package.path
local Light = require("loyalcritters/lighting")
local function make(prefab, existing)
    local inst = {prefab = prefab, added = 0, tasks = {}, events = {}}
    local function create()
        local l = {enabled = false, enable_calls = 0}
        function l:SetColour(r,g,b) self.colour = {r,g,b} end
        function l:SetRadius(v) self.radius = v end
        function l:SetIntensity(v) self.intensity = v end
        function l:SetFalloff(v) self.falloff = v end
        function l:Enable(v) self.enabled = v; self.enable_calls = self.enable_calls + 1 end
        return l
    end
    inst.entity = {AddLight = function() inst.added = inst.added + 1; inst.Light = create() end}
    if existing then inst.Light = create() end
    function inst:DoTaskInTime(t, fn) table.insert(self.tasks, fn) end
    function inst:ListenForEvent(e, fn) self.events[e] = fn end
    return inst
end
for _, spec in ipairs({
    {"critter_dragonling", 1.75, .55, .75, 1, .35, .12},
    {"critter_lunarmothling", 1.65, .50, .80, 1, 1, 1},
    {"critter_eyeofterror", 1.60, .50, .95, .10, .35, 1},
}) do
    local pet = make(spec[1], false)
    Light.Configure(pet, true)
    assert(pet.added == 1 and pet.Light.enabled)
    assert(pet.Light.radius == spec[2] and pet.Light.intensity == spec[3] and pet.Light.falloff == spec[4])
    for i=1,3 do assert(pet.Light.colour[i] == spec[i+4]) end
    for _, fn in ipairs(pet.tasks) do fn(pet) end
    assert(pet.added == 1)
    local client = make(spec[1], true)
    Light.Configure(client, false)
    assert(client.added == 0 and client.Light.enable_calls == 0)
end
local helper = make("critterbuff_lunarmoth", true)
Light.Configure(helper, true)
assert(helper.Light.radius == 1.65 and helper.Light.enable_calls == 0)
local absent = make("critterbuff_lunarmoth", false)
Light.Configure(absent, true)
assert(absent.added == 0)
local eets = make("critter_eets", false)
Light.Configure(eets, true)
assert(eets.added == 0)
print("lighting_spec: OK")
