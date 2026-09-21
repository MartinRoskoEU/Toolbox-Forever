local AddonName, Toolbox = ...

local ExportDialog = {}

Toolbox.UI.ExportDialog = ExportDialog

local DEFAULT_WIDTH = 650
local DEFAULT_HEIGHT = 420
local SCREEN_MARGIN = 32

function ExportDialog:Initialize()
    if self.Window then
        return
    end

    self.Window = Toolbox.Classes.Window:New(
        DEFAULT_WIDTH,
        DEFAULT_HEIGHT
    )

    self.Window:SetTitle("Export Text")
    self.Window:SetMovable(true)
    self.Window:SetFrameStrata("FULLSCREEN_DIALOG")

    self:CreateLayout()

    self.Window.Frame:HookScript("OnHide", function()
        self.EditBox:ClearFocus()
    end)
end

function ExportDialog:CreateLayout()
    local frame = self.Window.Frame
    local background = frame.Bg

    self.Content = CreateFrame(
        "Frame",
        nil,
        frame,
        "TooltipBackdropTemplate"
    )

    self.Content:SetPoint(
        "TOPLEFT",
        background,
        "TOPLEFT",
        12,
        -12
    )

    self.Content:SetPoint(
        "BOTTOMRIGHT",
        background,
        "BOTTOMRIGHT",
        -12,
        46
    )

    self.Editor = CreateFrame(
        "Frame",
        nil,
        self.Content,
        "ScrollingEditBoxTemplate"
    )

    self.Editor:SetPoint(
        "TOPLEFT",
        self.Content,
        "TOPLEFT",
        4,
        -4
    )

    self.Editor:SetPoint(
        "BOTTOMRIGHT",
        self.Content,
        "BOTTOMRIGHT",
        -3,
        4
    )

    self.Editor:SetTextInsets(
        4,
        4,
        4,
        4
    )

    self.EditBox = self.Editor:GetEditBox()

    self.EditBox:SetPropagateKeyboardInput(false)

    self.Editor:RegisterCallback(
        "OnEscapePressed",
        function()
            self:Hide()
        end
    )

    self.ScrollBar = CreateFrame(
        "EventFrame",
        nil,
        self.Content,
        "MinimalScrollBar"
    )

    self.ScrollBar:SetPoint(
        "TOPRIGHT",
        self.Editor,
        "TOPRIGHT",
        -5,
        0
    )

    self.ScrollBar:SetPoint(
        "BOTTOMRIGHT",
        self.Editor,
        "BOTTOMRIGHT",
        -5,
        -1
    )

    local scrollBox = self.Editor:GetScrollBox()

    ScrollUtil.RegisterScrollBoxWithScrollBar(
        scrollBox,
        self.ScrollBar
    )

    local scrollBoxAnchorsWithBar = {
        CreateAnchor(
            "TOPLEFT",
            self.Editor,
            "TOPLEFT",
            0,
            0
        ),

        CreateAnchor(
            "BOTTOMRIGHT",
            self.Editor,
            "BOTTOMRIGHT",
            -18,
            -1
        ),
    }

    local scrollBoxAnchorsWithoutBar = {
        scrollBoxAnchorsWithBar[1],

        CreateAnchor(
            "BOTTOMRIGHT",
            self.Editor,
            "BOTTOMRIGHT",
            -2,
            -1
        ),
    }

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(
        scrollBox,
        self.ScrollBar,
        scrollBoxAnchorsWithBar,
        scrollBoxAnchorsWithoutBar
    )

    self.Hint = frame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.Hint:SetPoint(
        "TOPLEFT",
        self.Content,
        "BOTTOMLEFT",
        8,
        -10
    )

    self.Hint:SetText(
        "* Press Ctrl+C to copy the selected text."
    )

    self.SelectAllButton = CreateFrame(
        "Button",
        nil,
        frame,
        "UIPanelButtonTemplate"
    )

    self.SelectAllButton:SetSize(
        100,
        24
    )

    self.SelectAllButton:SetPoint(
        "TOPRIGHT",
        self.Content,
        "BOTTOMRIGHT",
        -86,
        -6
    )

    self.SelectAllButton:SetText("SELECT ALL")

    self.SelectAllButton:SetScript("OnClick", function()
        self:SelectAll()
    end)

    self.CloseButton = CreateFrame(
        "Button",
        nil,
        frame,
        "UIPanelButtonTemplate"
    )

    self.CloseButton:SetSize(
        80,
        24
    )

    self.CloseButton:SetPoint(
        "LEFT",
        self.SelectAllButton,
        "RIGHT",
        6,
        0
    )

    self.CloseButton:SetText("CLOSE")

    self.CloseButton:SetScript("OnClick", function()
        self:Hide()
    end)
end

function ExportDialog:Show(title, text, width, height)
    self:Initialize()

    local maximumWidth = math.max(
        UIParent:GetWidth() - SCREEN_MARGIN,
        1
    )

    local maximumHeight = math.max(
        UIParent:GetHeight() - SCREEN_MARGIN,
        1
    )

    self.Window:SetSize(
        math.max(1, math.min(width or DEFAULT_WIDTH, maximumWidth)),
        math.max(1, math.min(height or DEFAULT_HEIGHT, maximumHeight))
    )

    self.Window:SetTitle(
        title or "Export Text"
    )

    self.Editor:SetText(
        text or ""
    )

    self.Window:Show()

    self.Editor:GetScrollBox():ScrollToBegin(
        ScrollBoxConstants.NoScrollInterpolation
    )

    self:SelectAll()
end

function ExportDialog:SelectAll()
    self.EditBox:SetFocus()
    self.EditBox:HighlightText()
end

function ExportDialog:Hide()
    if not self.Window then
        return
    end

    self.EditBox:ClearFocus()
    self.Window:Hide()
end
