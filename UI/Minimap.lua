local addonName, addon = ...

local btn = CreateFrame("Button", "BarbarianInspectMinimapButton", Minimap)
btn:SetSize(32, 32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("AnyUp")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(20, 20)
bg:SetPoint("CENTER", 0, 1)

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\BarbarianInspect\\Media\\icon")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
btn.icon = icon

local border = btn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

do
    local angle = math.rad(225)
    local r = 80
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

btn:SetScript("OnClick", function()
    if addon.ToggleMainFrame then addon:ToggleMainFrame() end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BarbarianInspect")
    GameTooltip:AddLine("Click to open Raid Inspect", 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

addon.minimapButton = btn
