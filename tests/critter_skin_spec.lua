local function ReadFile(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local main = ReadFile("modmain.lua")
assert(not main:find('["\']critters["\']'), "mod must not register a replacement critter factory")
for _, path in ipairs({"critters.lua", "scripts/prefabs/critters.lua", "scripts/brains/loyalcritters_crittersbrain.lua"}) do
    local f = io.open(path, "r")
    if f then f:close(); error("obsolete override present: " .. path) end
end
print("critter_skin_spec: vanilla prefab delegation OK")
