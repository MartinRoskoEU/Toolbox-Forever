local AddonName, Toolbox = ...

local MinimapButton = {}

Toolbox.UI.MinimapButton = MinimapButton

local PERIMETER_OFFSET = 6

function MinimapButton:Initialize()
    if self.Frame then
        return
    end

    local settings = Toolbox.Database:GetMinimapSettings()
    self.Angle = settings.angle

    local button = CreateFrame("Button", nil, Minimap)
    self.Frame = button

    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    self.Background = button:CreateTexture(nil, "BACKGROUND")
    self.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    self.Background:SetSize(25, 25)
    self.Background:SetPoint("CENTER", 0, 1)

    self.Icon = button:CreateTexture(nil, "ARTWORK")
    self.Icon:SetTexture("Interface\\AddOns\\" .. AddonName .. "\\Assets\\toolbox_icon_128.png")
    self.Icon:SetSize(20, 20)
    self.Icon:SetPoint("CENTER", 0, 1)

    self.IconMask = button:CreateMaskTexture()
    self.IconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    self.IconMask:SetAllPoints(self.Icon)
    self.Icon:AddMaskTexture(self.IconMask)

    self.Border = button:CreateTexture(nil, "OVERLAY")
    self.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    self.Border:SetSize(54, 54)
    self.Border:SetPoint("TOPLEFT")

    button:SetScript("OnMouseDown", function()
        if not self.Dragging then
            self.SuppressClick = false
        end
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if self.SuppressClick or self.Dragging then
            return
        end

        if mouseButton == "LeftButton" then
            PlaySound(84240)
            Toolbox.UI.MainWindow:Toggle()
        elseif mouseButton == "RightButton" then
            self:OpenContextMenu()
        end
    end)

    button:SetScript("OnDragStart", function()
        self.Dragging = true
        self.SuppressClick = true
        GameTooltip:Hide()

        button:SetScript("OnUpdate", function()
            self:UpdateDragPosition()
        end)

        self:UpdateDragPosition()
    end)

    button:SetScript("OnDragStop", function()
        self:StopDragging()
    end)

    button:SetScript("OnEnter", function()
        if self.Dragging then
            return
        end

        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Toolbox", 1, 1, 1)
        GameTooltip:AddLine("Left-click to toggle Toolbox.", 1, 1, 1)
        GameTooltip:AddLine("Right-click for options.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the Minimap.", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnHide", function()
        self:StopDragging()

        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnShow", function()
        self:UpdatePosition()
    end)

    Minimap:HookScript("OnSizeChanged", function()
        self:UpdatePosition()
    end)

    self:UpdatePosition()
    button:SetShown(settings.show)
end

function MinimapButton:OpenContextMenu()
    GameTooltip:Hide()

    -- The native context menu supplies its own opening sound and dismissal.
    MenuUtil.CreateContextMenu(self.Frame, function(_, rootDescription)
        local reloadButton = rootDescription:CreateButton("Reload UI", function()
            ReloadUI()
        end)

        reloadButton:AddInitializer(function(button)
            ---@cast button { fontString: FontString, AttachTexture: fun(self: table): Texture }
            local icon = button:AttachTexture()
            icon:SetAtlas("uitools-icon-refresh")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT")

            button.fontString:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        end)
    end)
end

function MinimapButton:UpdatePosition()
    local angle = math.rad(self.Angle)
    local radiusX = Minimap:GetWidth() / 2 + PERIMETER_OFFSET
    local radiusY = Minimap:GetHeight() / 2 + PERIMETER_OFFSET

    self.Frame:ClearAllPoints()
    self.Frame:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * radiusX,
        math.sin(angle) * radiusY
    )
end

function MinimapButton:UpdateDragPosition()
    local centerX, centerY = Minimap:GetCenter()

    if not centerX or not centerY then
        return
    end

    -- Cursor pixels must be converted into the Minimap's scaled coordinates.
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local radiusX = Minimap:GetWidth() / 2 + PERIMETER_OFFSET
    local radiusY = Minimap:GetHeight() / 2 + PERIMETER_OFFSET
    local x = (cursorX / scale - centerX) / radiusX
    local y = (cursorY / scale - centerY) / radiusY

    if x == 0 and y == 0 then
        return
    end

    self.Angle = math.deg(math.atan2(y, x)) % 360
    self:UpdatePosition()
end

function MinimapButton:StopDragging()
    if not self.Dragging then
        return
    end

    self:UpdateDragPosition()
    self.Dragging = false
    self.Frame:SetScript("OnUpdate", nil)

    -- Keep movement in memory; persist only the final angle on release or hide.
    Toolbox.Database:SetMinimapAngle(self.Angle)
end

function MinimapButton:SetShown(shown)
    Toolbox.Database:SetMinimapShown(shown)
    self.Frame:SetShown(Toolbox.Database:GetMinimapSettings().show)
end
