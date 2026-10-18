local AddonName, Toolbox = ...

local Typography = {}

Toolbox.Typography = Typography

local FAMILY_FONTS = {
    friz = "GameFontHighlight",
    arial = "ChatFontNormal",
    morpheus = "QuestFont_Large",
    skurri = "NumberFont_Outline_Huge",
}

local PRIMARY_ROLES = {
    editor = "body",
    output = "body",
    documentation = "signature",
    apiBrowser = "body",
    atlasBrowser = "entry",
    soundBrowser = "entry",
}

-- Roles describe current content fonts, not the surrounding UI controls.
local ROLE_FONTS = {
    editor = {
        body = "GameFontHighlight",
    },
    output = {
        body = "ChatFontNormal",
        export = "GameFontHighlight",
    },
    documentation = {
        body = "GameFontHighlight",
        heading = "GameFontNormalLarge",
        signature = "GameFontHighlightLarge",
        section = "GameFontNormal",
        metadata = "GameFontDisable",
    },
    apiBrowser = {
        body = "GameFontHighlight",
        heading = "GameFontNormalLarge",
        metadata = "GameFontDisable",
    },
    atlasBrowser = {
        entry = "GameFontHighlightSmall",
        body = "GameFontHighlight",
        metadata = "GameFontDisableSmall",
    },
    soundBrowser = {
        entry = "GameFontHighlightSmall",
        body = "GameFontHighlight",
        metadata = "GameFontDisableSmall",
    },
}

---@type FontAlphabet[]
local ALPHABETS = {
    "roman",
    "korean",
    "simplifiedchinese",
    "traditionalchinese",
    "russian",
}

local function GetNativeFont(group, role)
    local roles = assert(ROLE_FONTS[group], "Unknown Toolbox typography group")
    local fontName = assert(roles[role], "Unknown Toolbox typography role")
    return _G[fontName]
end

function Typography:Initialize()
    if self.Fonts then
        return
    end

    self.Fonts = {}
end

function Typography:GetSettings(group)
    return Toolbox.Database:GetTypographySettings(group)
end

function Typography:GetDefaultFamily(group)
    return Toolbox.Database:GetTypographyDefaultFamily(group)
end

function Typography:GetSizeOffsetRange(group)
    return Toolbox.Database:GetTypographySizeOffsetRange(group)
end

function Typography:GetPrimaryRole(group)
    local role = assert(PRIMARY_ROLES[group], "Unknown Toolbox typography group")
    return role
end

function Typography:GetSizeRange()
    return 10, 24
end

function Typography:ResolveFamily(group, role)
    GetNativeFont(group, role or "body")
    local settings = self:GetSettings(group)
    local fontName = assert(FAMILY_FONTS[settings.family], "Unknown Toolbox font family")

    return _G[fontName]
end

-- GetFont can report measurements such as 13.999 instead of the nominal 14.
-- Use integer baselines for preferences, never measured values from applied fonts.
function Typography:GetDefaultSize(group, role, alphabet)
    local nativeFont = GetNativeFont(group, role or "body")

    if alphabet then
        nativeFont = nativeFont:GetFontObjectForAlphabet(alphabet)
    end

    local _, height = nativeFont:GetFont()
    return math.floor(height + 0.5)
end

-- Every alphabet's primary role gets the selected integer size. Secondary roles
-- keep their native difference from that alphabet's primary role.
function Typography:GetSize(group, role, alphabet)
    role = role or "body"
    local primaryRole = self:GetPrimaryRole(group)
    local primarySize = self:GetDefaultSize(group, primaryRole) + self:GetSettings(group).sizeOffset
    return primarySize + self:GetDefaultSize(group, role, alphabet)
        - self:GetDefaultSize(group, primaryRole, alphabet)
end

function Typography:UpdateFont(group, role, entry)
    local nativeFont = GetNativeFont(group, role)
    local familyFont = self:ResolveFamily(group, role)
    local settings = self:GetSettings(group)
    local members = {}

    -- Keep all native alphabet members instead of flattening the family to Roman.
    for _, alphabet in ipairs(ALPHABETS) do
        local nativeMember = nativeFont:GetFontObjectForAlphabet(alphabet)
        local familyMember = familyFont:GetFontObjectForAlphabet(alphabet)
        local file = familyMember:GetFont()
        local _, _, flags = nativeMember:GetFont()

        members[#members + 1] = {
            alphabet = alphabet,
            file = file,
            height = self:GetSize(group, role, alphabet),
            flags = flags,
        }
    end

    if not entry.font then
        entry.font = CreateFontFamily(
            AddonName .. "_Typography_" .. group .. "_" .. role,
            members
        )
    else
        for _, member in ipairs(members) do
            local font = entry.font:GetFontObjectForAlphabet(member.alphabet)
            font:SetFont(member.file, member.height, member.flags)
        end
    end

    -- Family overrides change the face only; keep the native role's other styling.
    entry.font:SetTextColor(nativeFont:GetTextColor())
    entry.font:SetShadowColor(nativeFont:GetShadowColor())
    entry.font:SetShadowOffset(nativeFont:GetShadowOffset())
    entry.font:SetSpacing(nativeFont:GetSpacing())
    entry.font:SetAlpha(nativeFont:GetAlpha())
    entry.font:SetJustifyH("LEFT")
    entry.font:SetJustifyV(nativeFont:GetJustifyV())
    entry.font:SetIndentedWordWrap(nativeFont:GetIndentedWordWrap())

    entry.family = settings.family
    entry.sizeOffset = settings.sizeOffset
end

function Typography:GetFont(group, role)
    role = role or "body"
    GetNativeFont(group, role)
    local settings = self:GetSettings(group)

    self.Fonts[group] = self.Fonts[group] or {}
    local entry = self.Fonts[group][role]

    if not entry then
        entry = {}
        self.Fonts[group][role] = entry
    end

    if entry.family ~= settings.family or entry.sizeOffset ~= settings.sizeOffset then
        self:UpdateFont(group, role, entry)
    end

    return entry.font
end

-- Refresh existing owned objects in place; never allocate fonts on every update.
function Typography:Refresh(group)
    for name, fonts in pairs(self.Fonts) do
        if group == nil or group == name then
            for role, entry in pairs(fonts) do
                self:UpdateFont(name, role, entry)
            end
        end
    end

    -- Refresh only existing consumers; keep unvisited pages and dialogs lazy.
    local console = Toolbox.UI.ConsolePage
    if console then
        if group == nil or group == "editor" then
            console:RefreshEditorTypography()
        end
        if group == nil or group == "output" then
            console:RefreshOutputTypography()
        end
    end

    if (group == nil or group == "output") and Toolbox.UI.ExportDialog then
        Toolbox.UI.ExportDialog:RefreshTypography()
    end

    local api = Toolbox.UI.APIPage
    if api then
        if group == nil or group == "apiBrowser" then
            api:RefreshCatalogTypography()
        end
        if group == nil or group == "documentation" then
            api:RefreshDocumentationTypography()
        end
    end
    if (group == nil or group == "atlasBrowser") and Toolbox.UI.AtlasPage then
        Toolbox.UI.AtlasPage:RefreshTypography()
    end
    if (group == nil or group == "soundBrowser") and Toolbox.UI.SoundPage then
        Toolbox.UI.SoundPage:RefreshTypography()
    end
end

function Typography:SetFamily(group, family)
    local changed = Toolbox.Database:SetTypographyFamily(group, family)

    if changed then
        self:Refresh(group)
    end

    return changed
end

function Typography:SetSizeOffset(group, sizeOffset)
    local changed = Toolbox.Database:SetTypographySizeOffset(group, sizeOffset)

    if changed then
        self:Refresh(group)
    end

    return changed
end

function Typography:RestoreDefaults(group)
    local changedGroups = {}
    for name in pairs(PRIMARY_ROLES) do
        if group == nil or group == name then
            local settings = self:GetSettings(name)
            if settings.family ~= self:GetDefaultFamily(name) or settings.sizeOffset ~= 0 then
                changedGroups[#changedGroups + 1] = name
            end
        end
    end
    local changed = Toolbox.Database:RestoreTypographyDefaults(group)

    if changed then
        for _, name in ipairs(changedGroups) do
            self:Refresh(name)
        end
    end

    return changed
end
