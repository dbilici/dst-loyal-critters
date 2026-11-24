-- Local camera ownership: restore only the limit we actually installed.
local M = {}

local function SetMaxDistance(camera, distance)
    camera.maxdist = distance
    if camera.distancetarget ~= nil and camera.distancetarget > distance then
        camera.distancetarget = distance
    end
end

function M.Apply(camera, active, bonus, zoom_factor)
    if camera == nil or camera.maxdist == nil then return end
    local state = camera._loyalcritters_vision
    if not active then
        if state ~= nil then
            if state.applied ~= nil and camera.maxdist == state.applied then
                SetMaxDistance(camera, state.base)
            end
            camera._loyalcritters_vision = nil
        end
        return
    end
    if state ~= nil then
        -- Another system changed the limit. Relinquish ownership rather than
        -- repeatedly fighting its value or restoring a stale baseline.
        if state.applied ~= nil and camera.maxdist ~= state.applied then
            state.applied = nil
        end
        return
    end
    state = {base = camera.maxdist}
    camera._loyalcritters_vision = state
    local target = state.base + bonus
    if target > state.base then
        SetMaxDistance(camera, target)
        state.applied = target
        if camera.mindist ~= nil and camera.distancetarget ~= nil then
            local zoom_target = (target - camera.mindist) * zoom_factor + camera.mindist
            if zoom_target > camera.distancetarget then
                camera.distancetarget = zoom_target
            end
        end
    end
end

return M
