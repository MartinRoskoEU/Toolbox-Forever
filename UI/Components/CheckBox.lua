local AddonName, Toolbox = ...

local CheckBox = {}
CheckBox.__index = CheckBox

Toolbox.Classes.CheckBox = CheckBox

function CheckBox:New(parent, text)
    local instance = setmetatable({}, self)

    instance:CreateFrame(parent)
    instance:SetText(text)

    return instance
end

function CheckBox:CreateFrame(parent)
    self.Frame = CreateFrame(
        "CheckButton",
        nil,
        parent,
        "UICheckButtonTemplate"
    )

    self.Frame.Text:ClearAllPoints()

    self.Frame.Text:SetPoint(
        "LEFT",
        self.Frame,
        "RIGHT",
        6,
        0
    )

    self.Frame.Text:SetFontObject("GameFontNormal")
end

function CheckBox:SetText(text)
    self.Frame.Text:SetText(text)
end

function CheckBox:SetChecked(checked)
    self.Frame:SetChecked(checked)
end

function CheckBox:IsChecked()
    return self.Frame:GetChecked()
end

function CheckBox:SetOnClick(callback)
    self.Frame:SetScript("OnClick", function()
        callback(self)
    end)
end