local addonName, addon = ...

local SendChatMessage = SendChatMessage
local IsInGroup, IsInRaid, IsInGuild, IsInInstance =
    IsInGroup, IsInRaid, IsInGuild, IsInInstance
local UnitGUID = UnitGUID
local GetNormalizedRealmName = GetNormalizedRealmName
local HOME_CATEGORY = LE_PARTY_CATEGORY_HOME or 1

local function CanSendTo(channel)
    if channel == "SAY" or channel == "YELL" then return true end
    if channel == "PARTY" then return IsInGroup(HOME_CATEGORY) end
    if channel == "RAID" then return IsInRaid() end
    if channel == "INSTANCE_CHAT" then
        local _, instanceType = IsInInstance()
        return instanceType ~= "none" and instanceType ~= nil
    end
    if channel == "GUILD" then return IsInGuild() end
    return false
end
addon.CanSendToChannel = CanSendTo

-- Plain-text name + class tag. Color tokens in messages broadcast to PARTY/RAID
-- are sometimes silently rejected by the chat server, so we include class as a
-- plain-text suffix like "Shootcia (Shaman)" instead of |cff...|r.
local function PlainName(data)
    local name = data.name or "?"
    local class = data.class and data.class:sub(1, 1):upper() .. data.class:sub(2):lower() or ""
    if class ~= "" then
        return name .. " (" .. class .. ")"
    end
    return name
end

local function CollectIssues(data, craftThreshold)
    local missingEnch, missingGem = {}, {}
    local craftedCount = 0

    for slot, item in pairs(data.items or {}) do
        if item.missingEnchant then
            missingEnch[#missingEnch + 1] = addon.SLOT_NAMES[slot] or tostring(slot)
        end
        if item.missingGem then
            missingGem[#missingGem + 1] = addon.SLOT_NAMES[slot] or tostring(slot)
        end
        if item.isCrafted then craftedCount = craftedCount + 1 end
    end

    local parts = {}
    if #missingEnch > 0 then
        parts[#parts + 1] = "no ench (" .. table.concat(missingEnch, ", ") .. ")"
    end
    if #missingGem > 0 then
        parts[#parts + 1] = "no gem (" .. table.concat(missingGem, ", ") .. ")"
    end
    if craftThreshold and craftThreshold > 0 and craftedCount < craftThreshold then
        parts[#parts + 1] = "crafts " .. craftedCount .. "/" .. craftThreshold
    end

    if #parts == 0 then return nil end
    return table.concat(parts, "; ")
end
addon.CollectIssues = CollectIssues

-- Plain-text line for chat channels. No color tokens to avoid server-side rejection.
local function BuildPlainLine(data, craftThreshold)
    local issues = CollectIssues(data, craftThreshold)
    if not issues then return nil end
    return PlainName(data) .. ": " .. issues
end

function addon:SendReport()
    local channel   = BarbarianInspectDB.reportChannel or "PARTY"
    local threshold = BarbarianInspectDB.reportCraftThreshold or 0

    if not CanSendTo(channel) then
        self:Print("Cannot send to " .. channel .. " - not available right now.")
        return
    end

    local list = {}
    for _, d in pairs(self.inspectData) do list[#list + 1] = d end
    table.sort(list, function(a, b)
        return (self.rosterOrder[a.guid] or 9999) < (self.rosterOrder[b.guid] or 9999)
    end)

    local plainLines = {}
    for _, data in ipairs(list) do
        local plain = BuildPlainLine(data, threshold)
        if plain then plainLines[#plainLines + 1] = plain end
    end

    self:Print(("Report: checked %d player(s), %d with issues, sending to %s.")
        :format(#list, #plainLines, addon.CHANNEL_LABELS[channel] or channel))

    if #plainLines == 0 then
        return
    end

    -- Stagger via C_Timer to avoid WoW's client-side chat throttle, which
    -- silently drops messages fired in rapid succession.
    SendChatMessage("[BarbarianInspect] gear check:", channel)
    for i, line in ipairs(plainLines) do
        C_Timer.After(i * 0.3, function()
            SendChatMessage(line, channel)
        end)
    end
end

local function WhisperTarget(data)
    if data.realm and data.realm ~= "" and data.realm ~= GetNormalizedRealmName() then
        return (data.name or "?") .. "-" .. data.realm
    end
    return data.name or "?"
end

function addon:SendZiemniak()
    local threshold = BarbarianInspectDB.reportCraftThreshold or 0
    local myGUID = UnitGUID("player")
    local count = 0

    for _, data in pairs(self.inspectData) do
        if data.guid ~= myGUID and CollectIssues(data, threshold) then
            SendChatMessage("Jestes Ziemniakiem!!!", "WHISPER", nil, WhisperTarget(data))
            count = count + 1
        end
    end

    self:Print("Ziemniak whispered to " .. count .. " player(s).")
end
