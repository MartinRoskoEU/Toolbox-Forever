local AddonName, Toolbox = ...

local Window = {}
Window.__index = Window

Toolbox.Classes.Window = Window

function Window:New(width, height)
    local instance = setmetatable({}, self)

    instance:CreateFrame(width, height)

    return instance
end

function Window:CreateFrame(width, height)    
    width = width or 700
    height = height or 500

    self.Frame = CreateFrame(
        "Frame",
        nil,
        UIParent,
        "SettingsFrameTemplate"
    )

    self.Frame:SetSize(width, height)
    self.Frame:SetPoint("CENTER")

    self.Frame:SetFrameStrata("DIALOG")
    self.Frame:EnableMouse(true)
    
    self.Frame:Hide()
end

function Window:SetSize(width, height)
    self.Frame:SetSize(width, height)    
end

function Window:SetTitle(title)
    self.Frame.NineSlice.Text:SetText(title)
end

function Window:Show()
    self.Frame:Show()
end

function Window:Hide()
    self.Frame:Hide()
end

function Window:Toggle()
    if self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Window:SetMovable(enabled)
    self.Frame:SetMovable(enabled)

    if not self.DragHandle then
        self.DragHandle = CreateFrame(
            "Button",
            nil,
            self.Frame,
            "PanelDragBarTemplate"
        )

        self.DragHandle:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", 8, -2)
        self.DragHandle:SetPoint("TOPRIGHT", self.Frame, "TOPRIGHT", -40, -2)
        self.DragHandle:SetHeight(28)

        self.DragHandle.showCursorOnHover = true
    end

    self.DragHandle:SetDragSuspended(not enabled)
    self.DragHandle:SetShown(enabled)
end

function Window:SetFrameStrata(strata)
    self.Frame:SetFrameStrata(strata)
end