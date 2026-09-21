local AddonName, Toolbox = ...

local NavigationButton = {}
NavigationButton.__index = NavigationButton

Toolbox.Classes.NavigationButton = NavigationButton

function NavigationButton:New(parent, text)
    local instance = setmetatable({}, self)

    instance.Selected = false

    instance.Frame = CreateFrame("Button", nil, parent)
    instance.Frame:SetSize(175, 20)

    Mixin(instance.Frame, ButtonStateBehaviorMixin)

    instance.Frame.Texture = instance.Frame:CreateTexture(nil, "BACKGROUND")
    instance.Frame.Texture:SetPoint("CENTER")
    instance.Frame.Texture:Hide()

    instance.Frame.Label = instance.Frame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    instance.Frame.Label:SetPoint("TOPLEFT", 12, 1)
    instance.Frame.Label:SetPoint("BOTTOMRIGHT", -4, 1)
    instance.Frame.Label:SetJustifyH("LEFT")
    instance.Frame.Label:SetText(text)

    instance.Frame.OnButtonStateChanged = function()
        instance:UpdateState()
    end

    instance.Frame:SetScript("OnEnter", function(frame)
        frame:OnEnter()
    end)

    instance.Frame:SetScript("OnLeave", function(frame)
        frame:OnLeave()
    end)

    instance.Frame:SetScript("OnMouseDown", function(frame)
        frame:OnMouseDown()
    end)

    instance.Frame:SetScript("OnMouseUp", function(frame)
        frame:OnMouseUp()
    end)

    instance.Frame:OnLoad()

    return instance
end

function NavigationButton:SetSelected(selected)
    self.Selected = selected
    self:UpdateState()
end

function NavigationButton:IsSelected()
    return self.Selected
end

function NavigationButton:UpdateState()
    if self.Selected then
        self.Frame.Label:SetFontObject("GameFontHighlight")
        self.Frame.Texture:SetAtlas(
            "Options_List_Active",
            TextureKitConstants.UseAtlasSize
        )
        self.Frame.Texture:Show()
        return
    end

    self.Frame.Label:SetFontObject("GameFontNormal")

    if self.Frame:IsOver() then
        self.Frame.Texture:SetAtlas(
            "Options_List_Hover",
            TextureKitConstants.UseAtlasSize
        )
        self.Frame.Texture:Show()
    else
        self.Frame.Texture:Hide()
    end
end