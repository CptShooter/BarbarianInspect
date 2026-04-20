local addonName, addon = ...

local CanInspect, NotifyInspect, ClearInspectPlayer = CanInspect, NotifyInspect, ClearInspectPlayer
local UnitGUID, UnitName, UnitClass, UnitExists, UnitIsUnit = UnitGUID, UnitName, UnitClass, UnitExists, UnitIsUnit
local GetInspectSpecialization = GetInspectSpecialization
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetAverageItemLevel = GetAverageItemLevel
local GetNormalizedRealmName = GetNormalizedRealmName
local GetRaidRosterInfo = GetRaidRosterInfo
local IsInRaid, IsInGroup, GetNumGroupMembers, GetNumSubgroupMembers =
    IsInRaid, IsInGroup, GetNumGroupMembers, GetNumSubgroupMembers
local strsplit, ipairs, pairs, tonumber, wipe = strsplit, ipairs, pairs, tonumber, wipe
local GetTime = GetTime

local GetItemInfo        = (C_Item and C_Item.GetItemInfo)        or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetDetailedItemLevelInfo =
    (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local GetInspectItemLevel = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
local GetInventoryItemTooltip = C_TooltipInfo and C_TooltipInfo.GetInventoryItem

-- Localized tooltip prefixes. ENCHANTED_TOOLTIP_LINE = "Enchanted: %s" in enUS,
-- "Zaczarowane: %s" in plPL, etc. Strip the format specifier to get the prefix.
local function StripFormat(s)
    return (s or ""):gsub("%s*%%s.*$", ""):gsub(":%s*$", ":")
end
local ENCHANTED_PREFIX = StripFormat(ENCHANTED_TOOLTIP_LINE or "Enchanted: %s")
local CRAFTED_PREFIX   = StripFormat(ITEM_CREATED_BY         or "Crafted by %s")

-- Minimum time between our NotifyInspect calls. Throttle only applies when the
-- server hasn't returned INSPECT_READY yet; on INSPECT_READY we fire the next
-- request immediately.
local INSPECT_THROTTLE      = 0.1
local INSPECT_TIMEOUT       = 5.0
-- Back off this long when a different addon triggers an inspect we don't own.
-- Kept short because we still collect data from their INSPECT_READY events
-- (piggyback), so the backoff only exists to avoid cancelling their request.
local OTHER_INSPECT_BACKOFF = 0.4

local lastInspectAt    = 0
local pendingGUID      = nil
local pendingSince     = 0
local ourInspectCall   = false  -- set true just before WE call NotifyInspect
local lastPendingCount = 0      -- stub count snapshot, used for completion detection

local function BuildUnitList()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do
                units[#units + 1] = "party" .. i
            end
        end
    end
    return units
end
addon.BuildUnitList = BuildUnitList

-- Position within roster for default sort:
--   raid: subgroup * 100 + raidIndex   → groups first, stable within group
--   party: player = 1, party1..N = 2..N+1
local function BuildRosterOrder()
    wipe(addon.rosterOrder)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            if guid then
                local _, _, subgroup = GetRaidRosterInfo(i)
                addon.rosterOrder[guid] = (subgroup or 9) * 100 + i
            end
        end
    else
        local playerGUID = UnitGUID("player")
        if playerGUID then addon.rosterOrder[playerGUID] = 1 end
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do
                local guid = UnitGUID("party" .. i)
                if guid then addon.rosterOrder[guid] = i + 1 end
            end
        end
    end
end
addon.BuildRosterOrder = BuildRosterOrder

local function ParseItemLink(link)
    local payload = link:match("item:([%-%d:]+)")
    if not payload then return 0, 0, 0, 0, 0, 0 end
    local itemID, enchantID, g1, g2, g3, g4 = strsplit(":", payload, 7)
    return tonumber(itemID) or 0,
           tonumber(enchantID) or 0,
           tonumber(g1) or 0,
           tonumber(g2) or 0,
           tonumber(g3) or 0,
           tonumber(g4) or 0
end
addon.ParseItemLink = ParseItemLink

local function ItemHasSocket(link)
    local stats = GetItemStats(link)
    if not stats then return false end
    for key in pairs(stats) do
        if type(key) == "string" and key:find("EMPTY_SOCKET_") then
            return true
        end
    end
    return false
end
addon.ItemHasSocket = ItemHasSocket

-- Scan tooltip for enchant quality atlas (Professions-ChatIcon-Quality-TierN
-- embedded in the "Enchanted:" line) and crafted marker (any "hammer" atlas
-- in any line).
local function ScanItemTooltip(unit, slotID)
    local result = { enchantQualityAtlas = nil, isCrafted = false }
    if not GetInventoryItemTooltip then return result end

    local tip = GetInventoryItemTooltip(unit, slotID)
    if not tip or not tip.lines then return result end

    for _, line in ipairs(tip.lines) do
        local text = line.leftText
        if text and text ~= "" then
            if text:find(ENCHANTED_PREFIX, 1, true) then
                local atlas = text:match("|A:([^:|]+):")
                if atlas then result.enchantQualityAtlas = atlas end
            end

            local lower = text:lower()
            if text:find(CRAFTED_PREFIX, 1, true)
               or lower:find("crafted by ", 1, true)
               or lower:find("radiance crafted", 1, true)
               or lower:find("^crafted:")
               or lower:find("|a:[^|]-hammer")
               or lower:find("|a:[^|]-anvil")
               or lower:find("|a:[^|]-smithing")
               or lower:find("|a:[^|]-crafting") then
                result.isCrafted = true
            end
        end
    end

    return result
end
addon.ScanItemTooltip = ScanItemTooltip

-- Debug helper: dump tooltip lines of player's slot to chat so we can figure
-- out which pattern matches "crafted" in a given patch.
function addon:DumpTooltip(slotID)
    slotID = tonumber(slotID) or 16
    if not GetInventoryItemTooltip then
        self:Print("C_TooltipInfo not available")
        return
    end
    local tip = GetInventoryItemTooltip("player", slotID)
    if not tip or not tip.lines then
        self:Print("No tooltip for slot " .. slotID)
        return
    end
    self:Print("Tooltip slot " .. slotID .. ":")
    for i, line in ipairs(tip.lines) do
        if line.leftText and line.leftText ~= "" then
            -- escape pipes so the chat doesn't render color/atlas tokens
            local safe = line.leftText:gsub("|", "||")
            self:Print("  " .. i .. ": " .. safe)
        end
    end
end

-- Lightweight stub: everything we can know without NotifyInspect. Used so rows
-- appear immediately for the whole raid before gear finishes loading.
local function CollectStubData(unit)
    if not UnitExists(unit) then return nil end

    local name, realm = UnitName(unit)
    local _, classFile = UnitClass(unit)
    local guid = UnitGUID(unit)

    return {
        unit  = unit,
        guid  = guid,
        name  = name,
        realm = realm and realm ~= "" and realm or GetNormalizedRealmName(),
        class = classFile,
        spec  = 0,
        ilvl  = 0,
        items = {},
        stub  = true,
    }
end
addon.CollectStubData = CollectStubData

local function CollectGearForUnit(unit)
    if not UnitExists(unit) then return nil end

    local name, realm = UnitName(unit)
    local _, classFile = UnitClass(unit)
    local guid = UnitGUID(unit)

    local data = {
        unit    = unit,
        guid    = guid,
        name    = name,
        realm   = realm and realm ~= "" and realm or GetNormalizedRealmName(),
        class   = classFile,
        spec    = 0,
        ilvl    = 0,
        items   = {},
        updated = GetTime(),
    }

    if UnitIsUnit(unit, "player") then
        data.spec = GetSpecializationInfo(GetSpecialization() or 0) or 0
    else
        data.spec = GetInspectSpecialization(unit) or 0
    end

    for _, slot in ipairs(addon.SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local itemID, enchantID, g1, g2, g3, g4 = ParseItemLink(link)
            local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
            if not texture then
                _, _, _, _, texture = GetItemInfoInstant(link)
            end
            local ilvl = GetDetailedItemLevelInfo(link) or 0
            local hasSocket = ItemHasSocket(link)
            local hasGem = (g1 ~= 0) or (g2 ~= 0) or (g3 ~= 0) or (g4 ~= 0)
            local tipInfo = ScanItemTooltip(unit, slot)

            data.items[slot] = {
                link                = link,
                itemID              = itemID,
                quality             = quality or 1,
                ilvl                = ilvl,
                texture             = texture,
                enchantID           = enchantID,
                hasSocket           = hasSocket,
                hasGem              = hasGem,
                missingEnchant      = addon.CAN_HAVE_ENCHANT[slot] and enchantID == 0 or false,
                missingGem          = hasSocket and not hasGem,
                enchantQualityAtlas = tipInfo.enchantQualityAtlas,
                isCrafted           = tipInfo.isCrafted,
            }
        end
    end

    -- Count items with a real ilvl. Partial scans (INSPECT_READY arriving
    -- before the server sent all item data) return fewer — we detect that and
    -- fall back to the API's overall ilvl instead of a wrong computed average.
    --
    -- 15 is the threshold because many players legitimately run with an empty
    -- offhand (2H weapon, staff) — flagging those as partial would be wrong.
    local itemCount, total = 0, 0
    for _, item in pairs(data.items) do
        if item.ilvl and item.ilvl > 0 then
            itemCount = itemCount + 1
            total = total + item.ilvl
        end
    end
    data.itemCount = itemCount
    data.partial   = itemCount < 15

    if not data.partial then
        -- Complete: compute our own precise average. If MH is equipped but OH
        -- is empty (2H / single-wield), MH counts twice (same as paperdoll + MRT).
        local mh = data.items[INVSLOT_MAINHAND]
        local oh = data.items[INVSLOT_OFFHAND]
        if mh and not oh then
            total = total + (mh.ilvl or 0)
        end
        data.ilvl = total / 16
    elseif UnitIsUnit(unit, "player") then
        local _, equipped = GetAverageItemLevel()
        data.ilvl = equipped or 0
    else
        data.ilvl = (GetInspectItemLevel and GetInspectItemLevel(unit)) or 0
    end

    return data
end
addon.CollectGearForUnit = CollectGearForUnit

-- Returns true if the unit was newly added to the queue (so callers like
-- RefreshAll can count without double-counting already-queued players).
function addon:QueueInspect(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player") then return false end
    if self.inspectQueue[unit] then return false end
    -- Queue even if CanInspect is currently false (out of range / zoning) —
    -- ProcessInspectQueue will retry each tick until it becomes true.
    self.inspectQueue[unit] = GetTime()
    return true
end

function addon:ProcessInspectQueue()
    -- Don't fight other addons or the user's manual inspect.
    if InspectFrame and InspectFrame:IsShown() then return end
    if InCombatLockdown() then return end

    local now = GetTime()

    if pendingGUID and (now - pendingSince) > INSPECT_TIMEOUT then
        ClearInspectPlayer()
        pendingGUID = nil
    end
    if pendingGUID then return end
    if (now - lastInspectAt) < INSPECT_THROTTLE then return end

    for unit in pairs(self.inspectQueue) do
        if not UnitExists(unit) then
            -- Player gone from the group entirely — drop.
            self.inspectQueue[unit] = nil
        elseif CanInspect(unit, false) then
            pendingGUID   = UnitGUID(unit)
            pendingSince  = now
            lastInspectAt = now
            ourInspectCall = true
            NotifyInspect(unit)
            ourInspectCall = false
            self.inspectQueue[unit] = nil
            return
        end
        -- Else: CanInspect false (out of range, zoning) — keep in queue, retry next tick.
    end
end

-- Detect when a different addon (or the user's right-click→Inspect) calls
-- NotifyInspect. Back off briefly so we don't cancel their inspect or cause
-- INSPECT_READY cross-wiring.
hooksecurefunc("NotifyInspect", function()
    if ourInspectCall then return end
    lastInspectAt = GetTime() + OTHER_INSPECT_BACKOFF - INSPECT_THROTTLE
    pendingGUID = nil
end)

function addon:RefreshAll()
    BuildRosterOrder()

    -- drop data for people no longer in group
    for guid in pairs(self.inspectData) do
        if not self.rosterOrder[guid] then
            self.inspectData[guid] = nil
        end
    end

    local units = BuildUnitList()

    -- Phase 1 (cheap): stub entries so rows appear instantly.
    for _, u in ipairs(units) do
        local guid = UnitGUID(u)
        if guid and not self.inspectData[guid] then
            local stub = CollectStubData(u)
            if stub then self.inspectData[guid] = stub end
        end
    end

    -- Phase 2 (cheap): queue inspects for others. Stubs AND partial scans
    -- both count as "needs inspect". Manual Refresh resets the retry counter
    -- on partial data so users get a fresh 3-attempt budget.
    local queuedCount = 0
    for _, u in ipairs(units) do
        if not UnitIsUnit(u, "player") then
            local guid = UnitGUID(u)
            local existing = guid and self.inspectData[guid]
            local needs = not existing or existing.stub or existing.partial
            if needs then
                if existing and existing.partial then
                    existing.scanAttempts = 0
                end
                if self:QueueInspect(u) then
                    queuedCount = queuedCount + 1
                end
            end
        end
    end

    if queuedCount > 0 then
        self:Print(("Refreshing %d player(s)..."):format(queuedCount))
        lastPendingCount = queuedCount  -- so completion detection fires for this batch
    end

    -- Paint the stubs immediately.
    if self.OnInspectComplete then self:OnInspectComplete(nil) end

    -- Phase 3 (heavy — 16× tooltip scans): defer to next frame so the rest of
    -- RefreshAll and the first UI paint don't compete for the same 200ms
    -- script budget. Without this the initial /barbi in a 25-man raid can hit
    -- "script ran too long".
    C_Timer.After(0, function()
        local selfData = CollectGearForUnit("player")
        if selfData then
            self.inspectData[selfData.guid] = selfData
            if self.OnInspectComplete then self:OnInspectComplete(selfData.guid) end
        end
    end)

    -- Kick the queue now instead of waiting up to 0.25s for the ticker.
    self:ProcessInspectQueue()
end

local MAX_SCAN_ATTEMPTS = 5
local RETRY_DELAY       = 1.5

local function FindUnitForGUID(guid)
    for _, u in ipairs(BuildUnitList()) do
        if UnitGUID(u) == guid then return u end
    end
    return nil
end

local function TriggerCompletionIfDone()
    local pending = 0
    for _, d in pairs(addon.inspectData) do
        if d.stub then pending = pending + 1 end
    end
    if pending == 0 and lastPendingCount > 0 then
        addon:Print("Refresh complete.")
    end
    lastPendingCount = pending
end

-- MRT-style: parse immediately on INSPECT_READY, don't hold the inspect session.
-- Partial scans (server fires INSPECT_READY before all items populated) retry
-- through a fresh NotifyInspect a few seconds later.
function addon.events:INSPECT_READY(guid)
    local existing = self.inspectData[guid]
    local shouldCollect = existing and (existing.stub or existing.partial)

    if shouldCollect then
        local unit = FindUnitForGUID(guid)
        if unit then
            local data = CollectGearForUnit(unit)
            if data then
                data.scanAttempts = (existing.scanAttempts or 0) + 1
                self.inspectData[guid] = data
                self.inspectQueue[unit] = nil

                if data.partial and data.scanAttempts < MAX_SCAN_ATTEMPTS then
                    local retryUnit = unit
                    local retryGUID = guid
                    C_Timer.After(RETRY_DELAY, function()
                        local d = addon.inspectData[retryGUID]
                        if d and d.partial then
                            addon:QueueInspect(retryUnit)
                        end
                    end)
                end

                if self.OnInspectComplete then self:OnInspectComplete(guid) end
            end
        end
    end

    if pendingGUID == guid then
        ClearInspectPlayer()
        pendingGUID = nil
    end

    TriggerCompletionIfDone()

    -- Fire next queued inspect immediately (don't wait for 0.25s ticker).
    self:ProcessInspectQueue()
end

C_Timer.NewTicker(0.25, function() addon:ProcessInspectQueue() end)
