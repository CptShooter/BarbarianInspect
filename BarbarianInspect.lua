local addonName, addon = ...

SLASH_BARBARIANINSPECT1 = "/barbi"
SLASH_BARBARIANINSPECT2 = "/bi"

SlashCmdList.BARBARIANINSPECT = function(input)
    input = (input or ""):match("^%s*(.-)%s*$"):lower()

    if input == "" or input == "show" or input == "toggle" then
        if addon.ToggleMainFrame then addon:ToggleMainFrame() end
    elseif input == "refresh" then
        addon:RefreshAll()
        addon:Print("Refreshing inspect data...")
    elseif input == "report" then
        if addon.SendReport then addon:SendReport() end
    elseif input == "ziemniak" then
        if addon.SendZiemniak then addon:SendZiemniak() end
    elseif input:sub(1, 4) == "dump" then
        local _, slotStr = strsplit(" ", input, 2)
        addon:DumpTooltip(slotStr)
    elseif input == "help" then
        addon:Print("Commands:")
        addon:Print("  /barbi           - toggle inspect window")
        addon:Print("  /barbi refresh   - re-query all group members")
        addon:Print("  /barbi report    - send gear-check report to selected channel")
        addon:Print("  /barbi ziemniak  - whisper 'Jestes Ziemniakiem!!!' to everyone with gear issues")
        addon:Print("  /barbi dump N    - dump tooltip lines of your slot N (e.g. 16 = mainhand)")
        addon:Print("  /barbi help      - this message")
    else
        addon:Print("Unknown command: '" .. input .. "'. Try /barbi help")
    end
end

function addon.events:PLAYER_LOGIN()
    self:ApplyDBDefaults()
    if self.UpdateSortButtons then self.UpdateSortButtons() end
    if self.UpdateReportButtons then self.UpdateReportButtons() end
    self:Print("v" .. self.version .. " loaded. Type /barbi or click minimap icon.")
end

function addon.events:GROUP_ROSTER_UPDATE()
    if self.mainFrame and self.mainFrame:IsShown() then
        self:RefreshAll()
    end
end

function addon.events:PLAYER_EQUIPMENT_CHANGED()
    if not self.CollectGearForUnit then return end
    local data = self.CollectGearForUnit("player")
    if data then
        self.inspectData[data.guid] = data
        if self.mainFrame and self.mainFrame:IsShown() and self.RefreshMainFrame then
            self.RefreshMainFrame()
        end
    end
end
