local AddonName, Toolbox = ...

local MainWindow = {}

Toolbox.UI.MainWindow = MainWindow

function MainWindow:Initialize()
    if self.Window then
        return
    end

    self.Window = Toolbox.Classes.Window:New(1200, 724)
    self.Window:SetTitle("Toolbox v" .. C_AddOns.GetAddOnMetadata(AddonName, "Version"))
    self.Window:SetMovable(true)

    self:CreateLayout()
    self:CreatePages()
    self:SetNavigation()

    self:SelectPage(self.ConsolePage, self.ConsoleButton)
end

function MainWindow:CreateLayout()
    local frame = self.Window.Frame
    local background = frame.Bg

    self.Navigation = CreateFrame("Frame", nil, frame)
    self.Navigation:SetPoint("TOPLEFT", background, "TOPLEFT", 5, -5)
    self.Navigation:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 5, 5)
    self.Navigation:SetWidth(200)

    self.Divider = frame:CreateTexture(nil, "ARTWORK")
    self.Divider:SetAtlas("Options_HorizontalDivider")
    self.Divider:SetPoint("TOPLEFT", self.Navigation, "TOPRIGHT", 0, 0)
    self.Divider:SetPoint("BOTTOMLEFT", self.Navigation, "BOTTOMRIGHT", 0, 0)
    self.Divider:SetWidth(2)

    self.Content = CreateFrame("Frame", nil, frame)
    self.Content:SetPoint("TOPLEFT", self.Divider, "TOPRIGHT", 8, 0)
    self.Content:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -5, 5)
end

function MainWindow:CreatePages()
    self.ConsolePage = Toolbox.UI.ConsolePage
    self.ToolsPage = Toolbox.UI.ToolsPage
    self.AtlasPage = Toolbox.UI.AtlasPage
end

function MainWindow:SetNavigation()
    self.ConsoleButton = Toolbox.Classes.NavigationButton:New(
        self.Navigation,
        "Console"
    )

    self.ConsoleButton.Frame:SetPoint(
        "TOPLEFT",
        self.Navigation,
        "TOPLEFT",
        8,
        -8
    )

    self.ConsoleButton.Frame:SetScript("OnClick", function()
        self:SelectPage(
            self.ConsolePage,
            self.ConsoleButton
        )
    end)

    self.ToolsButton = Toolbox.Classes.NavigationButton:New(
        self.Navigation,
        "Tools"
    )

    self.ToolsButton.Frame:SetPoint(
        "TOPLEFT",
        self.ConsoleButton.Frame,
        "BOTTOMLEFT",
        0,
        -4
    )

    self.ToolsButton.Frame:SetScript("OnClick", function()
        self:SelectPage(
            self.ToolsPage,
            self.ToolsButton
        )
    end)

    self.AtlasButton = Toolbox.Classes.NavigationButton:New(
        self.Navigation,
        "Atlas"
    )

    self.AtlasButton.Frame:SetPoint(
        "TOPLEFT",
        self.ToolsButton.Frame,
        "BOTTOMLEFT",
        0,
        -4
    )

    self.AtlasButton.Frame:SetScript("OnClick", function()
        self:SelectPage(
            self.AtlasPage,
            self.AtlasButton
        )
    end)
end

function MainWindow:SelectPage(page, button)
    page:Initialize(self.Content)

    if self.ActivePage then
        self.ActivePage:Hide()
    end

    if self.ActiveButton then
        self.ActiveButton:SetSelected(false)
    end

    self.ActivePage = page.Page
    self.ActiveButton = button

    self.ActivePage:Show()
    self.ActiveButton:SetSelected(true)
end

function MainWindow:Toggle()
    self:Initialize()
    self.Window:Toggle()
end
