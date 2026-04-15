local addonName, addon = ...

local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetNormalizedRealmName = GetNormalizedRealmName

local ROW_H      = 40
local ICON_SIZE  = 32
local ICON_GAP   = 2
local BADGE_SIZE = 14
local NAME_W     = 160
local ILVL_W     = 50
local SLOTS_X    = 20 + 28 + 28 + NAME_W + 8 + ILVL_W + 8
local SORTBAR_H  = 24
local SORT_BTN_W = 72
local SORT_BTN_G = 4

-- Sort bar sits just below the gold title strip; start it past the portrait
-- (portrait covers x=0..~60) so buttons aren't hidden behind it.
local SORTBAR_Y     = -28
local SORTBAR_X     = 75
local SORTBAR_X_END = -30

-- Report bar sits at the top of the Inset content area (y=-60 relative to frame).
local REPORTBAR_Y   = -62
local REPORTBAR_H   = 24

-- Scroll goes below the report bar.
local SCROLL_Y      = REPORTBAR_Y - REPORTBAR_H - 4

-- Frame width: left/right insets + slots column + inspect column + scrollbar + padding buffer.
local LEFT_INSET       = 12
local RIGHT_INSET      = 30
local SCROLLBAR_W      = 24
local INSPECT_BTN_W    = ICON_SIZE
local INSPECT_BTN_GAP  = 8
local INSPECT_COL_W    = INSPECT_BTN_GAP + INSPECT_BTN_W
local FRAME_WIDTH      = SLOTS_X + #addon.SLOTS * (ICON_SIZE + ICON_GAP)
                       + INSPECT_COL_W
                       + LEFT_INSET + RIGHT_INSET + SCROLLBAR_W + 10

local MIN_FRAME_HEIGHT = 260
local MAX_FRAME_HEIGHT = 1000

local frame = CreateFrame("Frame", "BarbarianInspectMainFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(FRAME_WIDTH, 470)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)

-- Height-resizable. Width locked so the gear-slot columns stay aligned.
frame:SetResizable(true)
if frame.SetResizeBounds then
    frame:SetResizeBounds(FRAME_WIDTH, MIN_FRAME_HEIGHT, FRAME_WIDTH, MAX_FRAME_HEIGHT)
elseif frame.SetMinResize then
    frame:SetMinResize(FRAME_WIDTH, MIN_FRAME_HEIGHT)
    frame:SetMaxResize(FRAME_WIDTH, MAX_FRAME_HEIGHT)
end

-- Resize grip in bottom-right corner.
local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 10)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
resizeGrip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    BarbarianInspectDB.frameHeight = math.floor(frame:GetHeight() + 0.5)
end)

frame:Hide()

frame.TitleText:SetText("BarbarianInspect - Raid Inspect")

local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
refreshBtn:SetSize(80, 22)
refreshBtn:SetPoint("BOTTOMRIGHT", -10, 6)
refreshBtn:SetText("Refresh")
refreshBtn:SetScript("OnClick", function() addon:RefreshAll() end)

------------------------------------------------------------------------------
-- Sort bar
------------------------------------------------------------------------------

local sortBar = CreateFrame("Frame", nil, frame)
sortBar:SetPoint("TOPLEFT", frame, "TOPLEFT", SORTBAR_X, SORTBAR_Y)
sortBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", SORTBAR_X_END, SORTBAR_Y)
sortBar:SetHeight(SORTBAR_H)
sortBar:SetFrameLevel(frame:GetFrameLevel() + 5)

local sortBtns = {}

local function GetSortState()
    return BarbarianInspectDB.sortMode or "group",
           BarbarianInspectDB.sortAsc ~= false
end

local function UpdateSortButtons()
    local mode, asc = GetSortState()
    for _, b in pairs(sortBtns) do
        local label = addon.SORT_LABELS[b.mode] or b.mode
        if b.mode == mode then
            label = label .. (asc and "  ^" or "  v")
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
        b:SetText(label)
    end
end

local function SetSort(mode)
    local current, asc = GetSortState()
    if mode == current then
        BarbarianInspectDB.sortAsc = not asc
    else
        BarbarianInspectDB.sortMode = mode
        BarbarianInspectDB.sortAsc = true
    end
    UpdateSortButtons()
    if frame:IsShown() and addon.RefreshMainFrame then addon.RefreshMainFrame() end
end

local sortLabel = sortBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sortLabel:SetText("Sort by:")
sortLabel:SetPoint("LEFT", 2, 0)

local prevSortBtn
for i, mode in ipairs(addon.SORT_MODES) do
    local b = CreateFrame("Button", nil, sortBar, "UIPanelButtonTemplate")
    b:SetSize(SORT_BTN_W, 22)
    if i == 1 then
        b:SetPoint("LEFT", sortLabel, "RIGHT", 6, 0)
    else
        b:SetPoint("LEFT", prevSortBtn, "RIGHT", SORT_BTN_G, 0)
    end
    b:SetText(addon.SORT_LABELS[mode] or mode)
    b.mode = mode
    b:SetScript("OnClick", function(self) SetSort(self.mode) end)
    sortBtns[mode] = b
    prevSortBtn = b
end

------------------------------------------------------------------------------
-- Report bar
------------------------------------------------------------------------------

local reportBar = CreateFrame("Frame", nil, frame)
reportBar:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_INSET + 4, REPORTBAR_Y)
reportBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(RIGHT_INSET + 4), REPORTBAR_Y)
reportBar:SetHeight(REPORTBAR_H)
reportBar:SetFrameLevel(frame:GetFrameLevel() + 5)

local reportLabel = reportBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reportLabel:SetText("Report:")
reportLabel:SetPoint("LEFT", 2, 0)

-- Channel dropdown (Blizzard modern dropdown template)
local channelDropdown = CreateFrame("DropdownButton", nil, reportBar, "WowStyle1DropdownTemplate")
channelDropdown:SetSize(120, 22)
channelDropdown:SetPoint("LEFT", reportLabel, "RIGHT", 6, 0)

local function UpdateChannelText()
    local ch = BarbarianInspectDB.reportChannel or "PARTY"
    channelDropdown:SetText(addon.CHANNEL_LABELS[ch] or ch)
end

channelDropdown:SetupMenu(function(_, root)
    for _, ch in ipairs(addon.CHANNEL_OPTIONS) do
        local label = addon.CHANNEL_LABELS[ch] or ch
        root:CreateRadio(label,
            function() return BarbarianInspectDB.reportChannel == ch end,
            function()
                BarbarianInspectDB.reportChannel = ch
                UpdateChannelText()
            end)
    end
end)

-- Crafts threshold dropdown
local craftDropdown = CreateFrame("DropdownButton", nil, reportBar, "WowStyle1DropdownTemplate")
craftDropdown:SetSize(130, 22)
craftDropdown:SetPoint("LEFT", channelDropdown, "RIGHT", 4, 0)

local function UpdateCraftText()
    local th = BarbarianInspectDB.reportCraftThreshold or 0
    craftDropdown:SetText(addon.CRAFT_THRESHOLD_LABELS[th] or ("Crafts: " .. th))
end

craftDropdown:SetupMenu(function(_, root)
    for _, th in ipairs(addon.CRAFT_THRESHOLD_OPTIONS) do
        local label = addon.CRAFT_THRESHOLD_LABELS[th] or tostring(th)
        root:CreateRadio(label,
            function() return BarbarianInspectDB.reportCraftThreshold == th end,
            function()
                BarbarianInspectDB.reportCraftThreshold = th
                UpdateCraftText()
            end)
    end
end)

-- Report button
local reportBtn = CreateFrame("Button", nil, reportBar, "UIPanelButtonTemplate")
reportBtn:SetSize(80, 22)
reportBtn:SetPoint("LEFT", craftDropdown, "RIGHT", 8, 0)
reportBtn:SetText("Report")
reportBtn:SetScript("OnClick", function() addon:SendReport() end)

-- Ziemniak button — anchored to the far right of the report bar.
local ziemniakBtn = CreateFrame("Button", nil, reportBar, "UIPanelButtonTemplate")
ziemniakBtn:SetSize(90, 22)
ziemniakBtn:SetPoint("RIGHT", reportBar, "RIGHT", 0, 0)
ziemniakBtn:SetText("Ziemniak")
ziemniakBtn:SetScript("OnClick", function() addon:SendZiemniak() end)

local function UpdateReportButtons()
    UpdateChannelText()
    UpdateCraftText()
end
addon.UpdateReportButtons = UpdateReportButtons

------------------------------------------------------------------------------
-- Scroll area
------------------------------------------------------------------------------

local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_INSET, SCROLL_Y)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(RIGHT_INSET + SCROLLBAR_W - 4), 34)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(frame:GetWidth() - 40, 2000)
scroll:SetScrollChild(content)

frame.rows = {}

------------------------------------------------------------------------------
-- Row rendering
------------------------------------------------------------------------------

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(content:GetWidth(), ROW_H - 2)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)

    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(24, 24)
    row.classIcon:SetPoint("LEFT", 6, 0)

    row.specIcon = row:CreateTexture(nil, "ARTWORK")
    row.specIcon:SetSize(24, 24)
    row.specIcon:SetPoint("LEFT", row.classIcon, "RIGHT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")

    row.ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.ilvl:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.ilvl:SetWidth(ILVL_W)
    row.ilvl:SetJustifyH("RIGHT")

    row.slots = {}
    for i, slot in ipairs(addon.SLOTS) do
        local s = CreateFrame("Frame", nil, row)
        s:SetSize(ICON_SIZE, ICON_SIZE)
        s:SetPoint("LEFT", row, "LEFT", SLOTS_X + (i - 1) * (ICON_SIZE + ICON_GAP), 0)
        s.slot = slot

        s.missBorder = s:CreateTexture(nil, "BACKGROUND")
        s.missBorder:SetPoint("TOPLEFT", -2, 2)
        s.missBorder:SetPoint("BOTTOMRIGHT", 2, -2)
        s.missBorder:SetColorTexture(1, 0.1, 0.1, 1)
        s.missBorder:Hide()

        s.texture = s:CreateTexture(nil, "ARTWORK")
        s.texture:SetAllPoints()
        s.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- top-right: enchant quality badge (silver/gold pentagon)
        s.qualityBadge = s:CreateTexture(nil, "OVERLAY")
        s.qualityBadge:SetSize(BADGE_SIZE, BADGE_SIZE)
        s.qualityBadge:SetPoint("TOPRIGHT", 3, 3)
        s.qualityBadge:Hide()

        -- top-left: crafted hammer badge. Circular mask removes the standard
        -- square border on icon textures so the hammer sits cleanly on the item.
        s.craftedBadge = s:CreateTexture(nil, "OVERLAY")
        s.craftedBadge:SetSize(BADGE_SIZE, BADGE_SIZE)
        s.craftedBadge:SetPoint("TOPLEFT", -3, 3)
        s.craftedBadge:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        s.craftedBadge:Hide()

        s.ilvlText = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        s.ilvlText:SetPoint("BOTTOM", 0, 1)

        s:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.slots[i] = s
    end

    -- Inspect magnifying-glass button in the last column
    local inspectX = SLOTS_X + #addon.SLOTS * (ICON_SIZE + ICON_GAP) + INSPECT_BTN_GAP
    local inspectBtn = CreateFrame("Button", nil, row)
    inspectBtn:SetSize(INSPECT_BTN_W, INSPECT_BTN_W)
    inspectBtn:SetPoint("LEFT", row, "LEFT", inspectX, 0)

    local tex = inspectBtn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\inv_12_profession_jewelcrafting_inscription_magnifyingglass_yellow")

    inspectBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    inspectBtn:GetHighlightTexture():SetBlendMode("ADD")

    inspectBtn:SetScript("OnClick", function(self)
        local data = self.data
        if not data or not data.unit then return end
        if UnitIsUnit(data.unit, "player") then
            ToggleCharacter("PaperDollFrame")
        elseif CanInspect(data.unit) then
            InspectUnit(data.unit)
        end
    end)

    inspectBtn:SetScript("OnEnter", function(self)
        local data = self.data
        if not data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.unit and UnitIsUnit(data.unit, "player") then
            GameTooltip:AddLine("Open character sheet")
        else
            GameTooltip:AddLine("Inspect " .. (data.name or "?"))
        end
        GameTooltip:Show()
    end)
    inspectBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.inspectBtn = inspectBtn

    return row
end

local function UpdateRow(row, data)
    if not data then row:Hide() return end
    row:Show()

    if row.inspectBtn then row.inspectBtn.data = data end

    local color = RAID_CLASS_COLORS[data.class or ""]
    if color then
        row.bg:SetColorTexture(color.r, color.g, color.b, 0.35)
    else
        row.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    end

    if data.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.class] then
        row.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[data.class]))
    else
        row.classIcon:SetTexture(nil)
    end

    if data.spec and data.spec > 0 then
        local _, _, _, specIcon = GetSpecializationInfoByID(data.spec)
        row.specIcon:SetTexture(specIcon)
        row.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        row.specIcon:SetTexture(nil)
    end

    local label = data.name or "?"
    if data.realm and data.realm ~= GetNormalizedRealmName() then
        label = label .. " - " .. data.realm
    end
    if color then
        row.name:SetText(("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, label))
    else
        row.name:SetText(label)
    end

    if data.ilvl and data.ilvl > 0 then
        row.ilvl:SetText(("%.1f"):format(data.ilvl))
    else
        row.ilvl:SetText("...")
    end

    for i, s in ipairs(row.slots) do
        local item = data.items and data.items[s.slot]
        if item and item.texture then
            s.texture:SetTexture(item.texture)
            s.link = item.link

            local _, _, _, hex = GetItemQualityColor(item.quality or 1)
            s.ilvlText:SetText("|c" .. (hex or "ffffffff") .. (item.ilvl or "") .. "|r")

            if item.missingEnchant or item.missingGem then
                s.missBorder:Show()
            else
                s.missBorder:Hide()
            end

            if item.enchantQualityAtlas then
                s.qualityBadge:SetAtlas(item.enchantQualityAtlas, false)
                s.qualityBadge:Show()
            else
                s.qualityBadge:Hide()
            end

            if item.isCrafted then
                s.craftedBadge:SetTexture("Interface\\Icons\\inv_misc_1h_orcclansblacksmithhammer_a_01")
                s.craftedBadge:Show()
            else
                s.craftedBadge:Hide()
            end

            s:Show()
        else
            s.texture:SetTexture(nil)
            s.ilvlText:SetText("")
            s.missBorder:Hide()
            s.qualityBadge:Hide()
            s.craftedBadge:Hide()
            s.link = nil
            s:Show()
        end
    end
end

------------------------------------------------------------------------------
-- Sorting
------------------------------------------------------------------------------

local function MakeComparator()
    local mode, asc = GetSortState()
    local order = addon.rosterOrder

    if mode == "group" then
        return function(a, b)
            local pa = order[a.guid] or 9999
            local pb = order[b.guid] or 9999
            if pa == pb then return (a.name or "") < (b.name or "") end
            if asc then return pa < pb else return pa > pb end
        end
    elseif mode == "name" then
        return function(a, b)
            local na = (a.name or ""):lower()
            local nb = (b.name or ""):lower()
            if asc then return na < nb else return na > nb end
        end
    elseif mode == "class" then
        return function(a, b)
            local ca, cb = a.class or "", b.class or ""
            if ca == cb then return (a.name or "") < (b.name or "") end
            if asc then return ca < cb else return ca > cb end
        end
    elseif mode == "ilvl" then
        return function(a, b)
            local ia, ib = a.ilvl or 0, b.ilvl or 0
            if ia == ib then return (a.name or "") < (b.name or "") end
            if asc then return ia < ib else return ia > ib end
        end
    end

    return function(a, b) return (a.name or "") < (b.name or "") end
end

local function Refresh()
    local list = {}
    for _, d in pairs(addon.inspectData) do list[#list + 1] = d end
    table.sort(list, MakeComparator())

    for i, data in ipairs(list) do
        if not frame.rows[i] then frame.rows[i] = CreateRow(i) end
        UpdateRow(frame.rows[i], data)
    end
    for i = #list + 1, #frame.rows do
        frame.rows[i]:Hide()
    end

    content:SetHeight(math.max(#list * ROW_H + 10, 100))
end
addon.RefreshMainFrame = Refresh
addon.UpdateSortButtons = UpdateSortButtons

function addon:ToggleMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        if BarbarianInspectDB.frameHeight then
            frame:SetHeight(BarbarianInspectDB.frameHeight)
        end
        UpdateSortButtons()
        frame:Show()
        self:RefreshAll()
    end
end

function addon:OnInspectComplete(_)
    if frame:IsShown() then Refresh() end
end

addon.mainFrame = frame
