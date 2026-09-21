local AddonName, Toolbox = ...

local Page = {}
Page.__index = Page

Toolbox.Classes.Page = Page

function Page:New(parent, title)
    local instance = setmetatable({}, self)

    instance:CreateFrame(parent)
    instance:SetTitle(title)

    return instance
end

function Page:CreateFrame(parent)
    self.Frame = CreateFrame("Frame", nil, parent)
    self.Frame:SetAllPoints(parent)

    self.Header = CreateFrame("Frame", nil, self.Frame)
    self.Header:SetPoint("TOPLEFT")
    self.Header:SetPoint("TOPRIGHT")
    self.Header:SetHeight(50)

    self.Title = self.Header:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlightHuge"
    )

    self.Title:SetPoint("TOPLEFT", self.Header, "TOPLEFT", 7, -22)
    self.Title:SetJustifyH("LEFT")

    self.Divider = self.Header:CreateTexture(nil, "ARTWORK")
    self.Divider:SetAtlas("Options_HorizontalDivider")
    self.Divider:SetPoint("LEFT", self.Header, "LEFT", 7, 0)
    self.Divider:SetPoint("RIGHT", self.Header, "RIGHT", -7, 0)
    self.Divider:SetPoint("BOTTOM", self.Header, "BOTTOM", 0, 0)
    self.Divider:SetHeight(1)

    self.Frame:Hide()
end

function Page:SetTitle(title)
    self.Title:SetText(title)
end

function Page:Show()
    self.Frame:Show()
end

function Page:Hide()
    self.Frame:Hide()
end