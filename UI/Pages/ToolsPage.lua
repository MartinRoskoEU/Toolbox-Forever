local AddonName, Toolbox = ...

local ToolsPage = {}

Toolbox.UI.ToolsPage = ToolsPage

local TOGGLE_SPACING = 2
local SECTION_SPACING = 20
local ACTION_LABEL_SPACING = 10
local ACTION_BUTTON_SPACING = 8

function ToolsPage:Initialize(parent)
    if self.Page then
        return
    end

    self.Page = Toolbox.Classes.Page:New(
        parent,
        "Tools"
    )

    self:CreateLayout()

    self:CreateLuaErrors()
    self:CreateFrameStack()

    self:CreateActions()

    self:Refresh()

    self.Page.Frame:HookScript("OnShow", function()
        self:Refresh()
    end)
end

function ToolsPage:CreateLayout()
    local page = self.Page.Frame

    self.ToggleItems = {}
    self.ActionButtons = {}

    self.TogglesFrame = CreateFrame(
        "Frame",
        nil,
        page
    )

    self.TogglesFrame:SetPoint(
        "TOPLEFT",
        page,
        "TOPLEFT",
        8,
        -70
    )

    self.TogglesFrame:SetPoint(
        "TOPRIGHT",
        page,
        "TOPRIGHT",
        -8,
        -70
    )

    self.ActionsFrame = CreateFrame(
        "Frame",
        nil,
        page
    )

    self.ActionsFrame:SetPoint(
        "TOPLEFT",
        self.TogglesFrame,
        "BOTTOMLEFT",
        0,
        -SECTION_SPACING
    )

    self.ActionsFrame:SetPoint(
        "TOPRIGHT",
        self.TogglesFrame,
        "BOTTOMRIGHT",
        0,
        -SECTION_SPACING
    )
end

function ToolsPage:AddToggle(checkBox)
    local previous = self.ToggleItems[#self.ToggleItems]

    checkBox.Frame:ClearAllPoints()

    if previous then
        checkBox.Frame:SetPoint(
            "TOPLEFT",
            previous.Frame,
            "BOTTOMLEFT",
            0,
            -TOGGLE_SPACING
        )
    else
        checkBox.Frame:SetPoint(
            "TOPLEFT",
            self.TogglesFrame,
            "TOPLEFT",
            0,
            0
        )
    end

    table.insert(
        self.ToggleItems,
        checkBox
    )

    self:UpdateTogglesLayout()
end

function ToolsPage:UpdateTogglesLayout()
    local height = 0

    for index, checkBox in ipairs(self.ToggleItems) do
        if index > 1 then
            height = height + TOGGLE_SPACING
        end

        height = height + checkBox.Frame:GetHeight()
    end

    self.TogglesFrame:SetHeight(height)
end

function ToolsPage:CreateLuaErrors()
    self.LuaErrorsCheckBox = Toolbox.Classes.CheckBox:New(
        self.TogglesFrame,
        "Lua Errors"
    )

    self:AddToggle(
        self.LuaErrorsCheckBox
    )

    self.LuaErrorsCheckBox:SetOnClick(function(checkBox)
        C_CVar.SetCVar(
            "scriptErrors",
            checkBox:IsChecked() and "1" or "0"
        )
    end)
end

function ToolsPage:CreateFrameStack()
    self.FrameStackCheckBox = Toolbox.Classes.CheckBox:New(
        self.TogglesFrame,
        "Frame Stack"
    )

    self:AddToggle(
        self.FrameStackCheckBox
    )

    self.FrameStackCheckBox:SetOnClick(function(checkBox)
        local shouldEnable = checkBox:IsChecked() and true or false
        local isActive = self:IsFrameStackActive()

        if shouldEnable ~= isActive then
            local _, isLoaded = C_AddOns.IsAddOnLoaded(
                "Blizzard_DebugTools"
            )

            local loadError

            if shouldEnable and not isLoaded then
                local loadSucceeded
                loadSucceeded, loadError = C_AddOns.LoadAddOn(
                    "Blizzard_DebugTools"
                )
                isLoaded = loadSucceeded == true
            end

            local frameStackTooltip = _G.FrameStackTooltip
            local toggleFrameStack = _G.FrameStackTooltip_ToggleDefaults

            if not isLoaded
                or not frameStackTooltip
                or type(frameStackTooltip.IsVisible) ~= "function"
                or type(toggleFrameStack) ~= "function" then

                self:RefreshFrameStack()
                self:ReportFrameStackError(loadError)
                return
            end

            toggleFrameStack()
        end

        self:RefreshFrameStack()
    end)
end

function ToolsPage:ReportFrameStackError(loadError)
    if loadError then
        loadError = " " .. tostring(loadError)
    else
        loadError = " Required function is unavailable."
    end

    local message =
        "Unable to use Blizzard frame-stack tools."
        .. loadError

    if Toolbox.UI.ConsolePage.Page then
        Toolbox.UI.ConsolePage:WriteError(message)
    else
        print("Toolbox: " .. message)
    end
end

function ToolsPage:CreateActions()
    self.ActionsLabel = self.ActionsFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.ActionsLabel:SetPoint(
        "TOPLEFT",
        self.ActionsFrame,
        "TOPLEFT",
        0,
        0
    )

    self.ActionsLabel:SetText("Actions")

    self.ReloadButton = CreateFrame(
        "Button",
        nil,
        self.ActionsFrame,
        "UIPanelButtonTemplate"
    )

    self.ReloadButton:SetSize(120, 24)
    self.ReloadButton:SetText("Reload UI")

    self.ReloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)

    self:AddActionButton(
        self.ReloadButton
    )
end

function ToolsPage:AddActionButton(button)
    local previous = self.ActionButtons[#self.ActionButtons]

    button:ClearAllPoints()

    if previous then
        button:SetPoint(
            "LEFT",
            previous,
            "RIGHT",
            ACTION_BUTTON_SPACING,
            0
        )
    else
        button:SetPoint(
            "TOPLEFT",
            self.ActionsLabel,
            "BOTTOMLEFT",
            0,
            -ACTION_LABEL_SPACING
        )
    end

    table.insert(
        self.ActionButtons,
        button
    )

    self:UpdateActionsLayout()
end

function ToolsPage:UpdateActionsLayout()
    local buttonHeight = 0

    for _, button in ipairs(self.ActionButtons) do
        buttonHeight = math.max(
            buttonHeight,
            button:GetHeight()
        )
    end

    local height =
        self.ActionsLabel:GetStringHeight()
        + ACTION_LABEL_SPACING
        + buttonHeight

    self.ActionsFrame:SetHeight(height)
end

function ToolsPage:Refresh()
    self:RefreshLuaErrors()
    self:RefreshFrameStack()
end

function ToolsPage:RefreshLuaErrors()
    self.LuaErrorsCheckBox:SetChecked(
        C_CVar.GetCVarBool("scriptErrors")
    )
end

function ToolsPage:IsFrameStackActive()
    local frameStackTooltip = _G.FrameStackTooltip

    if not frameStackTooltip
        or type(frameStackTooltip.IsVisible) ~= "function" then

        return false
    end

    return frameStackTooltip:IsVisible() and true or false
end

function ToolsPage:RefreshFrameStack()
    self.FrameStackCheckBox:SetChecked(
        self:IsFrameStackActive()
    )
end
