local AddonName, Toolbox = ...

local AtlasPage = {}

Toolbox.UI.AtlasPage = AtlasPage

function AtlasPage:Initialize(parent)
    if self.Page then
        return
    end

    self.Page = Toolbox.Classes.Page:New(
        parent,
        "Atlas"
    )

    self:CreateLayout()
    self:SetupKeyboard()
end

function AtlasPage:CreateLayout()
    self:CreateBrowser()
    self:CreateSearch()
    self:LoadAtlases()
end

function AtlasPage:CreateBrowser()
    local page = self.Page.Frame

    self.BrowserFrame = CreateFrame(
        "Frame",
        nil,
        page
    )

    self.BrowserFrame:SetPoint(
        "TOPLEFT",
        page,
        "TOPLEFT",
        8,
        -128
    )

    self.BrowserFrame:SetPoint(
        "BOTTOMRIGHT",
        page,
        "BOTTOMRIGHT",
        -8,
        8
    )

    self:CreateAtlasList()
    self:CreatePreview()
    self:UpdateBrowserLayout()

    self.BrowserFrame:SetScript("OnSizeChanged", function()
        self:UpdateBrowserLayout()
    end)
end

function AtlasPage:UpdateBrowserLayout()
    local width = self.BrowserFrame:GetWidth()

    if width <= 0 then
        return
    end

    local spacing = 12
    local listWidth = math.floor(
        (width - spacing) * 0.4
    )

    self.ListFrame:SetWidth(listWidth)

    self.PreviewFrame:ClearAllPoints()

    self.PreviewFrame:SetPoint(
        "TOPLEFT",
        self.ListFrame,
        "TOPRIGHT",
        spacing,
        0
    )

    self.PreviewFrame:SetPoint(
        "BOTTOMRIGHT",
        self.BrowserFrame,
        "BOTTOMRIGHT",
        0,
        0
    )
end

function AtlasPage:CreateAtlasList()
    self.ListFrame = CreateFrame(
        "Frame",
        nil,
        self.BrowserFrame,
        "TooltipBackdropTemplate"
    )

    self.ListFrame:SetPoint(
        "TOPLEFT",
        self.BrowserFrame,
        "TOPLEFT",
        0,
        0
    )

    self.ListFrame:SetPoint(
        "BOTTOMLEFT",
        self.BrowserFrame,
        "BOTTOMLEFT",
        0,
        0
    )

    self.ListLabel = self.BrowserFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.ListLabel:SetPoint(
        "BOTTOMLEFT",
        self.ListFrame,
        "TOPLEFT",
        8,
        6
    )

    self.ListLabel:SetText("Atlases")

    self.AtlasScrollBox = CreateFrame(
        "Frame",
        nil,
        self.ListFrame,
        "WowScrollBoxList"
    )

    self.AtlasScrollBox:SetPoint(
        "TOPLEFT",
        self.ListFrame,
        "TOPLEFT",
        8,
        -8
    )

    self.AtlasScrollBox:SetPoint(
        "BOTTOMRIGHT",
        self.ListFrame,
        "BOTTOMRIGHT",
        -26,
        8
    )

    self.AtlasScrollBar = CreateFrame(
        "EventFrame",
        nil,
        self.ListFrame,
        "MinimalScrollBar"
    )

    self.AtlasScrollBar:SetPoint(
        "TOPRIGHT",
        self.ListFrame,
        "TOPRIGHT",
        -10,
        -10
    )

    self.AtlasScrollBar:SetPoint(
        "BOTTOMRIGHT",
        self.ListFrame,
        "BOTTOMRIGHT",
        -10,
        10
    )

    local view = CreateScrollBoxListLinearView()

    view:SetElementExtent(22)

    view:SetElementInitializer(
        "TruncatedButtonTemplate",
        function(button, atlasName)
            button:SetText(atlasName)

            button.Text:ClearAllPoints()

            button.Text:SetPoint(
                "LEFT",
                button,
                "LEFT",
                6,
                0
            )

            button.Text:SetPoint(
                "RIGHT",
                button,
                "RIGHT",
                -6,
                0
            )

            button.Text:SetJustifyH("LEFT")
            button.Text:SetFontObject("GameFontHighlightSmall")

            if not button.SelectionTexture then
                button.SelectionTexture = button:CreateTexture(
                    nil,
                    "BACKGROUND"
                )

                button.SelectionTexture:SetAllPoints()
                button.SelectionTexture:SetAtlas(
                    "Options_List_Active"
                )
            end

            button.SelectionTexture:SetShown(
                self.AtlasSelectionBehavior
                    and self.AtlasSelectionBehavior:IsElementDataSelected(atlasName)
            )

            button:SetScript("OnClick", function()
                self.AtlasSelectionBehavior:SelectElementData(
                    atlasName
                )
            end)
        end
    )

    ScrollUtil.InitScrollBoxListWithScrollBar(
        self.AtlasScrollBox,
        self.AtlasScrollBar,
        view
    )

    self.AtlasSelectionBehavior = ScrollUtil.AddSelectionBehavior(
        self.AtlasScrollBox
    )

    self.AtlasSelectionBehavior:RegisterCallback(
        SelectionBehaviorMixin.Event.OnSelectionChanged,
        function(_, atlasName, selected)
            local button = self.AtlasScrollBox:FindFrame(
                atlasName
            )

            if button and button.SelectionTexture then
                button.SelectionTexture:SetShown(selected)
            end

            if selected then
                self.AtlasScrollBox:ScrollToElementData(
                    atlasName,
                    ScrollBoxConstants.AlignNearest,
                    0,
                    true
                )

                self:ShowAtlasPreview(atlasName)
            end
        end
    )

end

function AtlasPage:CreatePreview()
    self.PreviewFrame = CreateFrame(
        "Frame",
        nil,
        self.BrowserFrame,
        "TooltipBackdropTemplate"
    )

    self.PreviewLabel = self.BrowserFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.PreviewLabel:SetPoint(
        "BOTTOMLEFT",
        self.PreviewFrame,
        "TOPLEFT",
        8,
        6
    )

    self.PreviewLabel:SetText("Preview")

    self.PreviewCanvas = CreateFrame(
        "Frame",
        nil,
        self.PreviewFrame
    )

    self.PreviewCanvas:SetPoint(
        "TOPLEFT",
        self.PreviewFrame,
        "TOPLEFT",
        16,
        -16
    )

    self.PreviewCanvas:SetPoint(
        "BOTTOMRIGHT",
        self.PreviewFrame,
        "BOTTOMRIGHT",
        -16,
        76
    )

    self.PreviewTexture = self.PreviewCanvas:CreateTexture(
        nil,
        "ARTWORK"
    )

    self.PreviewTexture:SetPoint(
        "CENTER",
        self.PreviewCanvas,
        "CENTER"
    )

    self.PreviewName = self.PreviewFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlight"
    )

    self.PreviewName:SetPoint(
        "BOTTOMLEFT",
        self.PreviewFrame,
        "BOTTOMLEFT",
        16,
        38
    )

    self.PreviewName:SetPoint(
        "BOTTOMRIGHT",
        self.PreviewFrame,
        "BOTTOMRIGHT",
        -140,
        38
    )

    self.PreviewName:SetJustifyH("LEFT")

    self.PreviewSize = self.PreviewFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.PreviewSize:SetPoint(
        "TOPLEFT",
        self.PreviewName,
        "BOTTOMLEFT",
        0,
        -6
    )

    self.PreviewSize:SetJustifyH("LEFT")

    self.ExportButton = CreateFrame(
        "Button",
        nil,
        self.PreviewFrame,
        "UIPanelButtonTemplate"
    )

    self.ExportButton:SetSize(
        130,
        24
    )

    self.ExportButton:SetPoint(
        "BOTTOMRIGHT",
        self.PreviewFrame,
        "BOTTOMRIGHT",
        -16,
        16
    )

    self.ExportButton:SetText("EXPORT NAME")
    self.ExportButton:Disable()

    self.ExportButton:SetScript("OnClick", function()
        self:ExportSelectedAtlas()
    end)

    self.PreviewCanvas:SetScript("OnSizeChanged", function()
        self:UpdatePreviewTextureSize()
    end)
end

function AtlasPage:CreateSearch()
    local page = self.Page.Frame

    self.SearchFrame = CreateFrame(
        "Frame",
        nil,
        page
    )

    self.SearchFrame:SetPoint(
        "BOTTOMLEFT",
        self.ListFrame,
        "TOPLEFT",
        5,
        42
    )

    self.SearchFrame:SetPoint(
        "BOTTOMRIGHT",
        self.ListFrame,
        "TOPRIGHT",
        0,
        42
    )

    self.SearchFrame:SetHeight(20)

    self.SearchBox = CreateFrame(
        "EditBox",
        nil,
        self.SearchFrame,
        "SearchBoxTemplate"
    )

    self.SearchBox:SetAllPoints(
        self.SearchFrame
    )

    self.SearchBox:SetScript("OnTextChanged", function(editBox)
        SearchBoxTemplate_OnTextChanged(editBox)

        self:ApplySearchFilter(
            editBox:GetText()
        )
    end)
end

function AtlasPage:LoadAtlases()
    local atlases = C_Texture.GetAtlasElements()

    table.sort(atlases)

    self.Atlases = atlases
    self.NormalizedAtlases = {}

    for index, atlasName in ipairs(self.Atlases) do
        self.NormalizedAtlases[index] = string.lower(atlasName)
    end

    self:ApplySearchFilter("")
end

function AtlasPage:ClearAtlasPreview()
    self.SelectedAtlas = nil
    self.SelectedAtlasWidth = nil
    self.SelectedAtlasHeight = nil

    self.PreviewTexture:SetTexture(nil)
    self.PreviewName:SetText("")
    self.PreviewSize:SetText("")
    self.ExportButton:Disable()
end

function AtlasPage:ShowAtlasPreview(atlasName)
    self.SelectedAtlas = atlasName

    self.PreviewTexture:SetAtlas(
        atlasName,
        true
    )

    self.SelectedAtlasWidth = self.PreviewTexture:GetWidth()
    self.SelectedAtlasHeight = self.PreviewTexture:GetHeight()

    self.PreviewName:SetText(atlasName)

    self.PreviewSize:SetText(
        string.format(
            "Size: %d x %d",
            math.floor(self.SelectedAtlasWidth + 0.5),
            math.floor(self.SelectedAtlasHeight + 0.5)
        )
    )

    self.ExportButton:Enable()

    self:UpdatePreviewTextureSize()
end

function AtlasPage:UpdatePreviewTextureSize()
    if not self.SelectedAtlas then
        return
    end

    local atlasWidth = self.SelectedAtlasWidth
    local atlasHeight = self.SelectedAtlasHeight

    if not atlasWidth
        or not atlasHeight
        or atlasWidth <= 0
        or atlasHeight <= 0 then
        return
    end

    local availableWidth = self.PreviewCanvas:GetWidth()
    local availableHeight = self.PreviewCanvas:GetHeight()

    if availableWidth <= 0 or availableHeight <= 0 then
        return
    end

    local scale = math.min(
        availableWidth / atlasWidth,
        availableHeight / atlasHeight
    )

    self.PreviewTexture:SetSize(
        atlasWidth * scale,
        atlasHeight * scale
    )
end

function AtlasPage:SelectNextAtlas()
    if not self.AtlasSelectionBehavior:HasSelection() then
        local dataProvider = self.AtlasScrollBox:GetDataProvider()

        if not dataProvider or dataProvider:GetSize() == 0 then
            return
        end

        local atlasName = dataProvider:Find(1)

        self.AtlasSelectionBehavior:SelectElementData(
            atlasName
        )

        return
    end

    self.AtlasSelectionBehavior:SelectNextElementData()
end

function AtlasPage:SelectPreviousAtlas()
    if not self.AtlasSelectionBehavior:HasSelection() then
        local dataProvider = self.AtlasScrollBox:GetDataProvider()

        if not dataProvider or dataProvider:GetSize() == 0 then
            return
        end

        local atlasName = dataProvider:Find(
            dataProvider:GetSize()
        )

        self.AtlasSelectionBehavior:SelectElementData(
            atlasName
        )

        return
    end

    self.AtlasSelectionBehavior:SelectPreviousElementData()
end

function AtlasPage:SetupKeyboard()
    local page = self.Page.Frame

    page:EnableKeyboard(false)
    page:SetPropagateKeyboardInput(true)

    page:SetScript("OnKeyDown", function(frame, key)
        if self.SearchBox:HasFocus() then
            frame:SetPropagateKeyboardInput(true)
            return
        end

        if key == "DOWN" then
            frame:SetPropagateKeyboardInput(false)
            self:SelectNextAtlas()

        elseif key == "UP" then
            frame:SetPropagateKeyboardInput(false)
            self:SelectPreviousAtlas()

        else
            frame:SetPropagateKeyboardInput(true)
        end
    end)

    page:HookScript("OnShow", function(frame)
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(true)
    end)

    page:HookScript("OnHide", function(frame)
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(false)
    end)
end

function AtlasPage:ApplySearchFilter(searchText)
    local filteredAtlases = {}
    local selectedAtlas = self.SelectedAtlas
    local selectedAtlasFound = false

    searchText = string.lower(
        strtrim(searchText or "")
    )

    for index, atlasName in ipairs(self.Atlases) do
        if searchText == ""
            or string.find(
                self.NormalizedAtlases[index],
                searchText,
                1,
                true
            ) then

            table.insert(filteredAtlases, atlasName)

            if atlasName == selectedAtlas then
                selectedAtlasFound = true
            end
        end
    end

    local dataProvider = CreateDataProvider(filteredAtlases)

    self.AtlasScrollBox:SetDataProvider(
        dataProvider,
        ScrollBoxConstants.DiscardScrollPosition
    )

    if selectedAtlasFound then
        self.AtlasSelectionBehavior:SelectElementData(
            selectedAtlas
        )
    else
        self:ClearAtlasPreview()
    end
end

function AtlasPage:ExportSelectedAtlas()
    if not self.SelectedAtlas then
        return
    end

    Toolbox.UI.ExportDialog:Show(
        "Atlas Name",
        self.SelectedAtlas,
        500,
        180
    )
end
