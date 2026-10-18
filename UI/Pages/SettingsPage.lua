local _, Toolbox = ...

local SettingsPage = {}

Toolbox.UI.SettingsPage = SettingsPage

local CONTENT_INDENT = 12
local GROUP_WIDTH = 520
local FAMILY_WIDTH = 220
local SIZE_WIDTH = 100
local COLUMN_GAP = 20

local FONT_FAMILIES = {
    { value = "friz", label = "Friz Quadrata" },
    { value = "arial", label = "Arial Narrow" },
    { value = "morpheus", label = "Morpheus" },
    { value = "skurri", label = "Skurri" },
}

-- Each group's preview role is also the primary size shown in its dropdown.
local TYPOGRAPHY_GROUPS = {
    {
        key = "editor",
        label = "Console Editor",
        sample = "if value then\n    print(value)\nend",
    },
    {
        key = "output",
        label = "Console Output & Export",
        sample = "Toolbox: Loaded 42 entries in 0.03 seconds.",
    },
    {
        key = "documentation",
        label = "API Documentation",
        sample = "C_AddOns.GetAddOnMetadata(addonName, field)",
    },
    {
        key = "apiBrowser",
        label = "API Browser",
        sample = "C_Spell.GetSpellInfo(spellIdentifier)",
    },
    {
        key = "atlasBrowser",
        label = "Atlas Browser",
        sample = "UI-HUD-Minimap-Zoom-In",
    },
    {
        key = "soundBrowser",
        label = "Sound Browser",
        sample = "IG_MAINMENU_OPEN",
    },
}

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(text)
    return button
end

function SettingsPage:Initialize(parent)
    if self.Page then
        return
    end

    self.Page = Toolbox.Classes.Page:New(
        parent,
        "Settings"
    )

    self:CreateLayout()
    self:Refresh()

    self.Page.Frame:HookScript("OnShow", function()
        self:Refresh()
    end)
end

function SettingsPage:CreateLayout()
    local page = self.Page.Frame

    self.ScrollFrame = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    self.ScrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -70)
    self.ScrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -36, 8)

    self.Content = CreateFrame("Frame", nil, self.ScrollFrame)
    self.Content:SetSize(1, 1)
    self.ScrollFrame:SetScrollChild(self.Content)

    self:CreateMinimap()
    self:CreateTypography()

    self.ScrollFrame:HookScript("OnSizeChanged", function()
        self:UpdateLayout()
    end)
end

function SettingsPage:CreateMinimap()
    self.MinimapLabel = self.Content:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormalLarge"
    )

    self.MinimapLabel:SetText("Minimap")

    self.MinimapCheckBox = Toolbox.Classes.CheckBox:New(
        self.Content,
        "Show Minimap Icon"
    )

    self.MinimapCheckBox:SetOnClick(function(checkBox)
        Toolbox.UI.MinimapButton:SetShown(checkBox:IsChecked() and true or false)
        self:Refresh()
    end)
end

function SettingsPage:CreateTypography()
    self.TypographyLabel = self.Content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self.TypographyLabel:SetText("Typography")

    self.TypographyHint = self.Content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    self.TypographyHint:SetJustifyH("LEFT")
    self.TypographyHint:SetWordWrap(true)
    self.TypographyHint:SetText(
        "Font sizes match the previews; other text keeps its relative size."
    )

    self.TypographyGroups = {}

    for _, definition in ipairs(TYPOGRAPHY_GROUPS) do
        self.TypographyGroups[#self.TypographyGroups + 1] = self:CreateTypographyGroup(definition)
    end

    self.RestoreFontsButton = CreateButton(self.Content, "Restore Font Defaults", 180)
    self.RestoreFontsButton:SetScript("OnClick", function()
        Toolbox.Typography:RestoreDefaults()
        self:Refresh()
    end)
end

function SettingsPage:CreateTypographyGroup(definition)
    local item = {
        Group = definition.key,
        Role = Toolbox.Typography:GetPrimaryRole(definition.key),
    }

    item.Frame = CreateFrame("Frame", nil, self.Content)
    item.Title = item.Frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    item.Title:SetPoint("TOPLEFT")
    item.Title:SetJustifyH("LEFT")
    item.Title:SetWordWrap(true)
    item.Title:SetText(definition.label)

    item.Controls = CreateFrame("Frame", nil, item.Frame)

    item.FamilyLabel = item.Controls:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    item.FamilyLabel:SetPoint("TOPLEFT")
    item.FamilyLabel:SetJustifyH("LEFT")
    item.FamilyLabel:SetText("Font Family")

    item.FamilyDropdown = CreateFrame(
        "DropdownButton", nil, item.Controls, "WowStyle1DropdownTemplate"
    )
    item.FamilyDropdown:SetSize(FAMILY_WIDTH, 25)
    item.FamilyDropdown:SetupMenu(function(_, rootDescription)
        for _, family in ipairs(FONT_FAMILIES) do
            rootDescription:CreateRadio(family.label, function(value)
                return Toolbox.Typography:GetSettings(item.Group).family == value
            end, function(value)
                Toolbox.Typography:SetFamily(item.Group, value)
                -- DropdownButton updates its own selection after a menu choice.
                item.CurrentFamily = value
                self:Refresh()
            end, family.value)
        end
    end)
    item.CurrentFamily = Toolbox.Typography:GetSettings(item.Group).family

    item.SizeLabel = item.Controls:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    item.SizeLabel:SetJustifyH("LEFT")
    item.SizeLabel:SetText("Font Size")

    item.SizeDropdown = CreateFrame(
        "DropdownButton", nil, item.Controls, "WowStyle1DropdownTemplate"
    )
    item.SizeDropdown:SetSize(SIZE_WIDTH, 25)
    item.SizeDropdown:SetupMenu(function(_, rootDescription)
        local typography = Toolbox.Typography
        local baseSize = typography:GetDefaultSize(item.Group, item.Role)
        local minimum, maximum = typography:GetSizeRange()

        for size = minimum, maximum do
            rootDescription:CreateRadio(tostring(size), function(value)
                return typography:GetSize(item.Group, item.Role) == value
            end, function(value)
                typography:SetSizeOffset(item.Group, value - baseSize)
                item.CurrentSize = value
                self:Refresh()
            end, size)
        end
    end)
    item.CurrentSize = Toolbox.Typography:GetSize(item.Group, item.Role)

    item.ResetButton = CreateButton(item.Frame, "Reset to Default", 136)
    item.ResetButton:SetPoint("TOPRIGHT", item.Frame, "TOPRIGHT")
    item.ResetButton:SetScript("OnClick", function()
        Toolbox.Typography:RestoreDefaults(item.Group)
        self:Refresh()
    end)

    item.Preview = item.Frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    item.Preview:SetPoint("TOPLEFT", item.Controls, "BOTTOMLEFT", 0, -10)
    item.Preview:SetPoint("TOPRIGHT", item.Controls, "BOTTOMRIGHT", 0, -10)
    item.Preview:SetWordWrap(true)
    item.Preview:SetNonSpaceWrap(true)
    item.Preview:SetText(definition.sample)

    return item
end

function SettingsPage:RefreshTypographyGroup(item)
    local typography = Toolbox.Typography
    local settings = typography:GetSettings(item.Group)

    if item.CurrentFamily ~= settings.family then
        item.FamilyDropdown:GenerateMenu()
        item.CurrentFamily = settings.family
    end

    local size = typography:GetSize(item.Group, item.Role)
    if item.CurrentSize ~= size then
        item.SizeDropdown:GenerateMenu()
        item.CurrentSize = size
    end
    item.ResetButton:SetEnabled(
        settings.family ~= typography:GetDefaultFamily(item.Group) or settings.sizeOffset ~= 0
    )

    item.Preview:SetFontObject(typography:GetFont(item.Group, item.Role))
    item.Preview:SetJustifyH("LEFT")
    item.Preview:SetJustifyV("TOP")
end

function SettingsPage:UpdateLayout()
    local width = self.ScrollFrame:GetWidth()

    if width <= 0 then
        return
    end

    self.Content:SetWidth(width)
    local groupWidth = math.min(GROUP_WIDTH, math.max(width - CONTENT_INDENT, 1))
    local familyWidth = math.min(FAMILY_WIDTH, math.max(groupWidth - COLUMN_GAP - SIZE_WIDTH, 1))
    local cursor = 0

    self.MinimapLabel:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -cursor)
    cursor = cursor + math.ceil(self.MinimapLabel:GetStringHeight()) + 4
    self.MinimapCheckBox.Frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", CONTENT_INDENT, -cursor)
    cursor = cursor + self.MinimapCheckBox.Frame:GetHeight() + 24

    self.TypographyLabel:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 0, -cursor)
    cursor = cursor + math.ceil(self.TypographyLabel:GetStringHeight()) + 6
    self.TypographyHint:SetWidth(groupWidth)
    self.TypographyHint:SetPoint("TOPLEFT", self.Content, "TOPLEFT", CONTENT_INDENT, -cursor)
    cursor = cursor + math.ceil(self.TypographyHint:GetStringHeight()) + 16

    for _, item in ipairs(self.TypographyGroups) do
        item.Frame:SetWidth(groupWidth)
        item.Frame:SetPoint("TOPLEFT", self.Content, "TOPLEFT", CONTENT_INDENT, -cursor)
        item.Title:SetWidth(math.max(groupWidth - item.ResetButton:GetWidth() - 12, 1))
        local titleHeight = math.ceil(item.Title:GetStringHeight())
        local headingHeight = math.max(titleHeight, item.ResetButton:GetHeight())
        item.Title:SetPoint(
            "TOPLEFT", item.Frame, "TOPLEFT", 0, -math.floor((headingHeight - titleHeight) / 2)
        )
        item.ResetButton:SetPoint(
            "TOPRIGHT", item.Frame, "TOPRIGHT", 0,
            -math.floor((headingHeight - item.ResetButton:GetHeight()) / 2)
        )

        item.Controls:SetWidth(groupWidth)
        item.Controls:SetPoint("TOPLEFT", item.Frame, "TOPLEFT", 0, -headingHeight - 8)
        item.FamilyLabel:SetWidth(familyWidth)
        item.SizeLabel:SetWidth(SIZE_WIDTH)
        item.SizeLabel:SetPoint("TOPLEFT", item.Controls, "TOPLEFT", familyWidth + COLUMN_GAP, 0)
        local labelHeight = math.ceil(math.max(
            item.FamilyLabel:GetStringHeight(), item.SizeLabel:GetStringHeight()
        ))
        item.FamilyDropdown:SetWidth(familyWidth)
        item.FamilyDropdown:SetPoint("TOPLEFT", item.Controls, "TOPLEFT", 0, -labelHeight - 4)
        item.SizeDropdown:SetPoint("TOPLEFT", item.Controls, "TOPLEFT", familyWidth + COLUMN_GAP, -labelHeight - 4)
        item.Controls:SetHeight(labelHeight + 4 + item.FamilyDropdown:GetHeight())

        -- Set the wrapping width before measuring; every group follows its preview.
        item.Preview:SetWidth(groupWidth)
        local height = headingHeight + 8 + item.Controls:GetHeight() + 10
            + math.ceil(item.Preview:GetStringHeight())
        item.Frame:SetHeight(height)
        cursor = cursor + height + 20
    end

    self.RestoreFontsButton:SetPoint("TOPLEFT", self.Content, "TOPLEFT", CONTENT_INDENT, -cursor)
    self.Content:SetHeight(cursor + self.RestoreFontsButton:GetHeight() + 12)
    self.ScrollFrame:UpdateScrollChildRect()

    -- A smaller preview or restored defaults can reduce the available scroll range.
    local maximumScroll = math.max(self.Content:GetHeight() - self.ScrollFrame:GetHeight(), 0)
    self.ScrollFrame:SetVerticalScroll(math.min(self.ScrollFrame:GetVerticalScroll(), maximumScroll))
end

function SettingsPage:Refresh()
    self.MinimapCheckBox:SetChecked(
        Toolbox.Database:GetMinimapSettings().show
    )

    local changed = false

    for _, item in ipairs(self.TypographyGroups) do
        self:RefreshTypographyGroup(item)
        local settings = Toolbox.Typography:GetSettings(item.Group)
        changed = changed or settings.family ~= Toolbox.Typography:GetDefaultFamily(item.Group)
            or settings.sizeOffset ~= 0
    end

    self.RestoreFontsButton:SetEnabled(changed)
    self:UpdateLayout()
end
