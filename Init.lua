local addonName, addon = ...

BarbarianInspectDB = BarbarianInspectDB or {}

addon.name = addonName
addon.version = "1.0.0"

addon.events = {}
addon.inspectQueue = {}
addon.inspectData = {}
addon.rosterOrder = {}

addon.SLOTS = {
    INVSLOT_HEAD,
    INVSLOT_NECK,
    INVSLOT_SHOULDER,
    INVSLOT_BACK,
    INVSLOT_CHEST,
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_TRINKET1,
    INVSLOT_TRINKET2,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
}

-- Midnight Season 1 enchantable slots.
-- Source: user-confirmed in-game (back/wrist/hands have NO live enchants this season).
-- Update when new enchants are added (new raid tier / season patch).
addon.CAN_HAVE_ENCHANT = {
    [INVSLOT_HEAD]     = true,
    [INVSLOT_SHOULDER] = true,
    [INVSLOT_CHEST]    = true,
    [INVSLOT_LEGS]     = true,
    [INVSLOT_FEET]     = true,
    [INVSLOT_FINGER1]  = true,
    [INVSLOT_FINGER2]  = true,
    [INVSLOT_MAINHAND] = true,
}

addon.SORT_MODES = { "group", "name", "class", "ilvl" }
addon.SORT_LABELS = { group = "Group", name = "Name", class = "Class", ilvl = "iLvl" }

addon.CHANNEL_OPTIONS = { "SAY", "PARTY", "RAID", "INSTANCE_CHAT" }
addon.CHANNEL_LABELS = {
    SAY           = "Say",
    PARTY         = "Party",
    RAID          = "Raid",
    INSTANCE_CHAT = "Instance",
}

addon.CRAFT_THRESHOLD_OPTIONS = { 0, 1, 2 }
addon.CRAFT_THRESHOLD_LABELS  = {
    [0] = "Ignore crafts",
    [1] = "< 1 craft",
    [2] = "< 2 crafts",
}

addon.SLOT_NAMES = {
    [INVSLOT_HEAD]     = "Head",
    [INVSLOT_NECK]     = "Neck",
    [INVSLOT_SHOULDER] = "Shoulders",
    [INVSLOT_BACK]     = "Back",
    [INVSLOT_CHEST]    = "Chest",
    [INVSLOT_WRIST]    = "Wrists",
    [INVSLOT_HAND]     = "Hands",
    [INVSLOT_WAIST]    = "Waist",
    [INVSLOT_LEGS]     = "Legs",
    [INVSLOT_FEET]     = "Feet",
    [INVSLOT_FINGER1]  = "Ring1",
    [INVSLOT_FINGER2]  = "Ring2",
    [INVSLOT_TRINKET1] = "Trinket1",
    [INVSLOT_TRINKET2] = "Trinket2",
    [INVSLOT_MAINHAND] = "MH",
    [INVSLOT_OFFHAND]  = "OH",
}

addon.DB_DEFAULTS = {
    sortMode             = "group",
    sortAsc              = true,
    reportChannel        = "PARTY",
    reportCraftThreshold = 2,
    frameHeight          = 440,
}

addon.PREFIX = "|cffffd100[BarbarianInspect]|r "

function addon:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. tostring(msg))
end

function addon:ApplyDBDefaults()
    for k, v in pairs(self.DB_DEFAULTS) do
        if BarbarianInspectDB[k] == nil then
            BarbarianInspectDB[k] = v
        end
    end

    -- Reset persisted values that no longer exist in current option sets
    -- (e.g. user had "GUILD" saved before we removed it).
    if not self.CHANNEL_LABELS[BarbarianInspectDB.reportChannel or ""] then
        BarbarianInspectDB.reportChannel = self.DB_DEFAULTS.reportChannel
    end
    if not self.CRAFT_THRESHOLD_LABELS[BarbarianInspectDB.reportCraftThreshold or -1] then
        BarbarianInspectDB.reportCraftThreshold = self.DB_DEFAULTS.reportCraftThreshold
    end
end
