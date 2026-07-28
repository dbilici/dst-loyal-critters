package.path = "./scripts/?.lua;" .. package.path

local WalterCritter = require("loyalcritters/walter")

local function MakePetLeash(maxpets)
    return {
        maxpets = maxpets,
        set_calls = 0,
        GetMaxPets = function(self)
            return self.maxpets
        end,
        SetMaxPets = function(self, value)
            self.maxpets = value
            self.set_calls = self.set_calls + 1
        end,
    }
end

local disabled_option = nil
dofile("modinfo.lua")

for _, option in ipairs(configuration_options) do
    if option.name == "allow_walter_critter" then
        disabled_option = option
        break
    end
end

assert(disabled_option ~= nil, "Walter configuration option is missing")
assert(disabled_option.default == false, "Walter configuration must default to disabled")

local vanilla = MakePetLeash(0)
local changed, previous = WalterCritter.EnableCritterAccess(vanilla)
assert(changed == true, "vanilla Walter capacity should be raised")
assert(previous == 0, "previous vanilla capacity should be reported")
assert(vanilla.maxpets == 1, "Walter should receive one regular critter slot")
assert(vanilla.set_calls == 1, "Walter capacity should be changed exactly once")

local already_enabled = MakePetLeash(1)
changed, previous = WalterCritter.EnableCritterAccess(already_enabled)
assert(changed == false, "capacity one should remain unchanged")
assert(previous == 1, "existing capacity should be reported")
assert(already_enabled.maxpets == 1, "capacity one should be preserved")
assert(already_enabled.set_calls == 0, "capacity one should not be rewritten")

local expanded_by_other_mod = MakePetLeash(3)
changed, previous = WalterCritter.EnableCritterAccess(expanded_by_other_mod)
assert(changed == false, "larger third-party capacity should remain unchanged")
assert(previous == 3, "larger capacity should be reported")
assert(expanded_by_other_mod.maxpets == 3, "larger third-party capacity should be preserved")
assert(expanded_by_other_mod.set_calls == 0, "larger capacity should not be rewritten")

changed, previous = WalterCritter.EnableCritterAccess(nil)
assert(changed == false and previous == nil, "missing petleash should be ignored safely")

print("walter_critter_spec: OK")
