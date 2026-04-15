local addonName, addon = ...

local frame = CreateFrame("Frame", "BarbarianInspectEventFrame")
addon.eventFrame = frame

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = addon.events[event]
    if handler then handler(addon, ...) end
end)

function addon:RegisterEvent(event)
    frame:RegisterEvent(event)
end

function addon:UnregisterEvent(event)
    frame:UnregisterEvent(event)
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("GROUP_ROSTER_UPDATE")
addon:RegisterEvent("INSPECT_READY")
addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
