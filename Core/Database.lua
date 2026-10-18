local _, Toolbox = ...

local Database = {}

Toolbox.Database = Database

local DEFAULT_MINIMAP_ANGLE = 225

-- Offsets preserve each group's existing mix of native text sizes.
local TYPOGRAPHY_GROUPS = {
    editor = "friz",
    output = "arial",
    documentation = "friz",
    apiBrowser = "friz",
    atlasBrowser = "friz",
    soundBrowser = "friz",
}

local function NormalizeFontFamily(family, defaultFamily)
    if family == "ui" then
        return "friz"
    elseif family == "chat" then
        return "arial"
    elseif family == "friz" or family == "arial" or family == "morpheus" or family == "skurri" then
        return family
    end

    return defaultFamily
end

local function NormalizeSizeOffset(value, minimum, maximum)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then

        return 0
    end

    return math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
end

local function NormalizeAngle(angle)
    if type(angle) ~= "number"
        or angle ~= angle
        or angle == math.huge
        or angle == -math.huge then

        return DEFAULT_MINIMAP_ANGLE
    end

    return angle % 360
end

function Database:Initialize()
    if type(_G.ToolboxDB) ~= "table" then
        _G.ToolboxDB = {}
    end

    local database = _G.ToolboxDB

    if type(database.minimap) ~= "table" then
        database.minimap = {}
    end

    local minimap = database.minimap

    if type(minimap.show) ~= "boolean" then
        minimap.show = true
    end

    minimap.angle = NormalizeAngle(minimap.angle)

    if type(database.typography) ~= "table" then
        database.typography = {}
    end

    local typography = database.typography
    if typography.schemaVersion ~= 2 then
        local legacy = typography.browsers
        if type(legacy) == "table" then
            local baseSize = Toolbox.Typography:GetDefaultSize("apiBrowser", "body")
            local offset = NormalizeSizeOffset(legacy.sizeOffset, 10 - baseSize, 24 - baseSize)
            local family = NormalizeFontFamily(legacy.family, "friz")
            -- An untouched legacy preset maps to each browser's original defaults.
            local customized = offset ~= 0 or legacy.family == "ui" or legacy.family == "chat"
                or legacy.family == family
            for _, group in ipairs({ "apiBrowser", "atlasBrowser", "soundBrowser" }) do
                if typography[group] == nil then
                    local settings = {}
                    for key, value in pairs(legacy) do
                        settings[key] = value
                    end
                    settings.family = family
                    local primary = Toolbox.Typography:GetPrimaryRole(group)
                    settings.sizeOffset = customized
                        and (baseSize + offset - Toolbox.Typography:GetDefaultSize(group, primary)) or 0
                    typography[group] = settings
                end
            end
        end
    end

    for group, defaultFamily in pairs(TYPOGRAPHY_GROUPS) do
        if type(database.typography[group]) ~= "table" then
            database.typography[group] = {}
        end

        local settings = database.typography[group]
        local minimum, maximum = self:GetTypographySizeOffsetRange(group)
        settings.family = NormalizeFontFamily(settings.family, defaultFamily)
        settings.sizeOffset = NormalizeSizeOffset(settings.sizeOffset, minimum, maximum)
    end
    typography.schemaVersion = 2

    self.Settings = database
end

function Database:GetMinimapSettings()
    return self.Settings.minimap
end

function Database:SetMinimapShown(shown)
    self.Settings.minimap.show = shown == true
end

function Database:SetMinimapAngle(angle)
    self.Settings.minimap.angle = NormalizeAngle(angle)
end

function Database:GetTypographySettings(group)
    if not TYPOGRAPHY_GROUPS[group] then
        return nil
    end

    return self.Settings.typography[group]
end

function Database:GetTypographyDefaultFamily(group)
    return TYPOGRAPHY_GROUPS[group]
end

function Database:GetTypographySizeOffsetRange(group)
    if TYPOGRAPHY_GROUPS[group] then
        -- Native baselines need no saved data or initialized font cache.
        local typography = Toolbox.Typography
        local baseSize = typography:GetDefaultSize(group, typography:GetPrimaryRole(group))
        local minimum, maximum = typography:GetSizeRange()
        return minimum - baseSize, maximum - baseSize
    end
end

function Database:SetTypographyFamily(group, family)
    local settings = self:GetTypographySettings(group)

    if not settings then
        return false
    end

    family = NormalizeFontFamily(family, TYPOGRAPHY_GROUPS[group])

    if settings.family == family then
        return false
    end

    settings.family = family
    return true
end

function Database:SetTypographySizeOffset(group, sizeOffset)
    local settings = self:GetTypographySettings(group)

    if not settings then
        return false
    end

    local minimum, maximum = self:GetTypographySizeOffsetRange(group)
    sizeOffset = NormalizeSizeOffset(sizeOffset, minimum, maximum)

    if settings.sizeOffset == sizeOffset then
        return false
    end

    settings.sizeOffset = sizeOffset
    return true
end

function Database:RestoreTypographyDefaults(group)
    if group ~= nil and not TYPOGRAPHY_GROUPS[group] then
        return false
    end

    local changed = false

    for name, defaultFamily in pairs(TYPOGRAPHY_GROUPS) do
        if group == nil or group == name then
            local settings = self.Settings.typography[name]

            if settings.family ~= defaultFamily or settings.sizeOffset ~= 0 then
                settings.family = defaultFamily
                settings.sizeOffset = 0
                changed = true
            end
        end
    end

    return changed
end
