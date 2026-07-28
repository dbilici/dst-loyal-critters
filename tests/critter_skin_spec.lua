local function ReadFile(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents
end

for _, path in ipairs({
    "critters.lua",
    "scripts/prefabs/critters.lua",
}) do
    local contents = ReadFile(path)

    assert(
        contents:find("inst.linked_skinname", 1, true) ~= nil,
        path .. " must forward DST's linked critter skin"
    )
    assert(
        contents:find("inst.skin_name", 1, true) == nil,
        path .. " still uses the obsolete critter skin field"
    )
end

print("critter_skin_spec: OK")
