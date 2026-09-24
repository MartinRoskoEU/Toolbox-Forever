local AddonName, Toolbox = ...

local SoundPage = {}

Toolbox.UI.SoundPage = SoundPage

function SoundPage:Initialize(parent)
    if self.Page then
        return
    end

    self.Page = Toolbox.Classes.Page:New(
        parent,
        "Sounds"
    )

    self:CreateLayout()
    self:SetupKeyboard()
end

function SoundPage:CreateLayout()
    self:CreateBrowser()
    self:CreateSearch()
    self:LoadSoundKits()
end

function SoundPage:CreateBrowser()
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

    self:CreateSoundList()
    self:CreateDetails()

    self:UpdateBrowserLayout()

    self.BrowserFrame:SetScript("OnSizeChanged", function()
        self:UpdateBrowserLayout()
    end)
end

function SoundPage:UpdateBrowserLayout()
    local width = self.BrowserFrame:GetWidth()

    if width <= 0 then
        return
    end

    local spacing = 12

    local listWidth = math.floor(
        (width - spacing) * 0.4
    )

    self.ListFrame:SetWidth(listWidth)

    self.DetailsFrame:ClearAllPoints()

    self.DetailsFrame:SetPoint(
        "TOPLEFT",
        self.ListFrame,
        "TOPRIGHT",
        spacing,
        0
    )

    self.DetailsFrame:SetPoint(
        "BOTTOMRIGHT",
        self.BrowserFrame,
        "BOTTOMRIGHT",
        0,
        0
    )
end

function SoundPage:CreateSoundList()
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

    self.ListLabel:SetText("Sound Kits")

    self.SoundScrollBox = CreateFrame(
        "Frame",
        nil,
        self.ListFrame,
        "WowScrollBoxList"
    )

    self.SoundScrollBox:SetPoint(
        "TOPLEFT",
        self.ListFrame,
        "TOPLEFT",
        8,
        -8
    )

    self.SoundScrollBox:SetPoint(
        "BOTTOMRIGHT",
        self.ListFrame,
        "BOTTOMRIGHT",
        -26,
        8
    )

    self.SoundScrollBar = CreateFrame(
        "EventFrame",
        nil,
        self.ListFrame,
        "MinimalScrollBar"
    )

    self.SoundScrollBar:SetPoint(
        "TOPRIGHT",
        self.ListFrame,
        "TOPRIGHT",
        -10,
        -10
    )

    self.SoundScrollBar:SetPoint(
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
        function(button, soundKit)
            button:SetText(soundKit.name)

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
                self.SoundSelectionBehavior
                    and self.SoundSelectionBehavior:IsElementDataSelected(soundKit)
            )

            button:SetScript("OnClick", function()
                self.SoundSelectionBehavior:SelectElementData(
                    soundKit
                )
            end)
        end
    )

    ScrollUtil.InitScrollBoxListWithScrollBar(
        self.SoundScrollBox,
        self.SoundScrollBar,
        view
    )

    self.SoundSelectionBehavior = ScrollUtil.AddSelectionBehavior(
        self.SoundScrollBox
    )

    self.SoundSelectionBehavior:RegisterCallback(
        SelectionBehaviorMixin.Event.OnSelectionChanged,
        function(_, soundKit, selected)
            local button = self.SoundScrollBox:FindFrame(
                soundKit
            )

            if button and button.SelectionTexture then
                button.SelectionTexture:SetShown(selected)
            end

            if selected then
                self.SoundScrollBox:ScrollToElementData(
                    soundKit,
                    ScrollBoxConstants.AlignNearest,
                    0,
                    true
                )

                self:ShowSoundDetails(soundKit)
            end
        end
    )
end

function SoundPage:CreateDetails()
    self.DetailsFrame = CreateFrame(
        "Frame",
        nil,
        self.BrowserFrame,
        "TooltipBackdropTemplate"
    )

    self.DetailsLabel = self.BrowserFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.DetailsLabel:SetPoint(
        "BOTTOMLEFT",
        self.DetailsFrame,
        "TOPLEFT",
        8,
        6
    )

    self.DetailsLabel:SetText("Sound")

    self.SoundName = self.DetailsFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontHighlight"
    )

    self.SoundName:SetPoint(
        "TOPLEFT",
        self.DetailsFrame,
        "TOPLEFT",
        16,
        -16
    )

    self.SoundName:SetPoint(
        "TOPRIGHT",
        self.DetailsFrame,
        "TOPRIGHT",
        -16,
        -16
    )

    self.SoundName:SetJustifyH("LEFT")

    self.SoundID = self.DetailsFrame:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.SoundID:SetPoint(
        "TOPLEFT",
        self.SoundName,
        "BOTTOMLEFT",
        0,
        -8
    )

    self.SoundID:SetJustifyH("LEFT")

    self.PlayButton = CreateFrame(
        "Button",
        nil,
        self.DetailsFrame,
        "UIPanelButtonTemplate"
    )

    self.PlayButton:SetSize(80, 24)

    self.PlayButton:SetPoint(
        "TOPLEFT",
        self.SoundID,
        "BOTTOMLEFT",
        0,
        -16
    )

    self.PlayButton:SetText("PLAY")
    self.PlayButton:Disable()

    self.PlayButton:SetScript("OnClick", function()
        self:PlaySelectedSound()
    end)

    self.StopButton = CreateFrame(
        "Button",
        nil,
        self.DetailsFrame,
        "UIPanelButtonTemplate"
    )

    self.StopButton:SetSize(80, 24)

    self.StopButton:SetPoint(
        "LEFT",
        self.PlayButton,
        "RIGHT",
        8,
        0
    )

    self.StopButton:SetText("STOP")
    self.StopButton:Disable()

    self.StopButton:SetScript("OnClick", function()
        self:StopCurrentSound()
    end)

    self.ExportIDButton = CreateFrame(
        "Button",
        nil,
        self.DetailsFrame,
        "UIPanelButtonTemplate"
    )

    self.ExportIDButton:SetSize(110, 24)

    self.ExportIDButton:SetPoint(
        "LEFT",
        self.StopButton,
        "RIGHT",
        8,
        0
    )

    self.ExportIDButton:SetText("EXPORT ID")
    self.ExportIDButton:Disable()

    self.ExportIDButton:SetScript("OnClick", function()
        self:ExportSelectedSoundKitID()
    end)

    self.SoundEventFrame = CreateFrame(
        "Frame",
        nil,
        self.DetailsFrame
    )

    self.SoundEventFrame:RegisterEvent(
        "SOUNDKIT_FINISHED"
    )

    self.SoundEventFrame:SetScript(
        "OnEvent",
        function(_, event, soundHandle)
            if event == "SOUNDKIT_FINISHED" then
                self:OnSoundFinished(soundHandle)
            end
        end
    )
end

function SoundPage:CreateSearch()
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

function SoundPage:LoadSoundKits()
    self.SoundKits = {}

    for name, soundKitID in pairs(SOUNDKIT) do
        if type(name) == "string"
            and type(soundKitID) == "number" then

            table.insert(
                self.SoundKits,
                {
                    name = name,
                    id = soundKitID,
                    normalizedName = string.lower(name),
                }
            )
        end
    end

    table.sort(
        self.SoundKits,
        function(a, b)
            return a.name < b.name
        end
    )

    self:ApplySearchFilter("")
end

function SoundPage:ApplySearchFilter(searchText)
    local filteredSounds = {}
    local selectedSoundKit = self.SelectedSoundKit
    local selectedStillVisible = false

    searchText = string.lower(
        strtrim(searchText or "")
    )

    for _, soundKit in ipairs(self.SoundKits) do
        if searchText == ""
            or string.find(
                soundKit.normalizedName,
                searchText,
                1,
                true
            ) then

            table.insert(
                filteredSounds,
                soundKit
            )

            if soundKit == selectedSoundKit then
                selectedStillVisible = true
            end
        end
    end

    local dataProvider = CreateDataProvider(
        filteredSounds
    )

    self.SoundScrollBox:SetDataProvider(
        dataProvider,
        ScrollBoxConstants.DiscardScrollPosition
    )

    if selectedSoundKit and selectedStillVisible then
        self.SoundSelectionBehavior:SelectElementData(
            selectedSoundKit
        )
    else
        self:ClearSoundDetails()
    end
end

function SoundPage:ShowSoundDetails(soundKit)
    if self.SelectedSoundKit ~= soundKit then
        self:StopCurrentSound()
    end

    self.SelectedSoundKit = soundKit

    self.SoundName:SetText(
        soundKit.name
    )

    self.SoundID:SetText(
        string.format(
            "SoundKit ID: %d",
            soundKit.id
        )
    )

    self.PlayButton:Enable()
    self.ExportIDButton:Enable()
end

function SoundPage:PlaySelectedSound()
    if not self.SelectedSoundKit then
        return
    end

    self:StopCurrentSound()

    local success, soundHandle = C_Sound.PlaySound(
        self.SelectedSoundKit.id,
        nil,
        false,
        true
    )

    if not success or not soundHandle then
        return
    end

    self.CurrentSoundHandle = soundHandle

    self.StopButton:Enable()
end

function SoundPage:StopCurrentSound()
    if not self.CurrentSoundHandle then
        return
    end

    if C_Sound.IsPlaying(self.CurrentSoundHandle) then
        StopSound(self.CurrentSoundHandle)
    end

    self.CurrentSoundHandle = nil

    self.StopButton:Disable()
end

function SoundPage:SelectNextSound()
    if not self.SoundSelectionBehavior:HasSelection() then
        local dataProvider = self.SoundScrollBox:GetDataProvider()

        if not dataProvider or dataProvider:GetSize() == 0 then
            return
        end

        local soundKit = dataProvider:Find(1)

        self.SoundSelectionBehavior:SelectElementData(
            soundKit
        )

        return
    end

    self.SoundSelectionBehavior:SelectNextElementData()
end

function SoundPage:SelectPreviousSound()
    if not self.SoundSelectionBehavior:HasSelection() then
        local dataProvider = self.SoundScrollBox:GetDataProvider()

        if not dataProvider or dataProvider:GetSize() == 0 then
            return
        end

        local soundKit = dataProvider:Find(
            dataProvider:GetSize()
        )

        self.SoundSelectionBehavior:SelectElementData(
            soundKit
        )

        return
    end

    self.SoundSelectionBehavior:SelectPreviousElementData()
end

function SoundPage:SetupKeyboard()
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
            self:SelectNextSound()

        elseif key == "UP" then
            frame:SetPropagateKeyboardInput(false)
            self:SelectPreviousSound()

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
        self:StopCurrentSound()
    end)
end

function SoundPage:OnSoundFinished(soundHandle)
    if soundHandle ~= self.CurrentSoundHandle then
        return
    end

    self.CurrentSoundHandle = nil

    self.StopButton:Disable()
end

function SoundPage:ClearSoundDetails()
    self:StopCurrentSound()

    self.SelectedSoundKit = nil

    self.SoundName:SetText("")
    self.SoundID:SetText("")

    self.PlayButton:Disable()
    self.ExportIDButton:Disable()
end

function SoundPage:ExportSelectedSoundKitID()
    if not self.SelectedSoundKit then
        return
    end

    Toolbox.UI.ExportDialog:Show(
        "SoundKit ID",
        tostring(self.SelectedSoundKit.id),
        500,
        180
    )
end
