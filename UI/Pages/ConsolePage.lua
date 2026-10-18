local AddonName, Toolbox = ...

local ConsolePage = {}

Toolbox.UI.ConsolePage = ConsolePage

-- Keep exported output aligned with the visible message history.
local MAX_OUTPUT_LINES = 1000
local MAX_EDITOR_UNDO_STEPS = 20
local EDITOR_TYPING_INTERVAL = 1

local function IsSingleUTF8Character(text)
    local first = text:byte()
    local size = first and (first < 128 and 1 or first < 224 and 2 or first < 240 and 3 or 4)
    return #text == size and not text:find("[\r\n\t]")
end

-- Fold only ASCII case: Lua 5.1 has no Unicode case folding, and changing UTF-8
-- bytes with a locale-dependent lower() would invalidate native EditBox offsets.
local function FoldSearchCase(text)
    return (text:gsub("[A-Z]", function(character)
        return string.char(character:byte() + 32)
    end))
end

local function FindLiteralMatches(text, query, caseSensitive)
    local matches = {}
    if query == "" then
        return matches
    end

    if not caseSensitive then
        text = FoldSearchCase(text)
        query = FoldSearchCase(query)
    end

    local position = 1
    while true do
        local first, last = text:find(query, position, true)
        if not first then
            break
        end

        -- Lua strings are byte-indexed; native Get/SetCursorPosition and
        -- HighlightText also use bytes, with a zero-based, exclusive end.
        matches[#matches + 1] = { First = first - 1, Last = last }
        position = last + 1
    end
    return matches
end

local function PackResults(...)
    return {
        Count = select("#", ...),
        ...,
    }
end

local function CreateRuntimeTraceback(message)
    local stack = debugstack(2)

    if stack and stack ~= "" then
        return tostring(message) .. "\n" .. stack
    end

    return tostring(message)
end

function ConsolePage:Initialize(parent)
    if self.Page then
        return
    end

    self.Page = Toolbox.Classes.Page:New(
        parent,
        "Console"
    )

    self:CreateLayout()
    self:RefreshEditorTypography()
    self:RefreshOutputTypography()
    self:CreateEnvironment()
    self:SetupKeyboard()
end

function ConsolePage:RefreshEditorTypography()
    if not self.InputEditor then
        return
    end

    local settings = Toolbox.Typography:GetSettings("editor")
    if self.EditorFamily == settings.family and self.EditorSizeOffset == settings.sizeOffset then
        return
    end

    local scrollBox = self.InputEditor:GetScrollBox()
    local scrollPercentage = scrollBox:GetScrollPercentage()
    local font = Toolbox.Typography:GetFont("editor")
    -- EventEditBox uses this reference when applying text or clearing placeholder text.
    self.InputEditor:GetEditBox().fontName = font
    -- The template updates wrapping, padding and scroll extent without editing text,
    -- moving the caret, changing selection or taking keyboard focus.
    self.InputEditor:SetFontObject(font)
    scrollBox:SetScrollPercentage(scrollPercentage, ScrollBoxConstants.NoScrollInterpolation)
    if self.InputEditor:HasFocus() then
        self.InputEditor:ScrollCursorIntoView(false)
    end

    self.EditorFamily = settings.family
    self.EditorSizeOffset = settings.sizeOffset
end

function ConsolePage:RefreshOutputTypography()
    if not self.OutputMessages then
        return
    end

    local settings = Toolbox.Typography:GetSettings("output")
    if self.OutputFamily == settings.family and self.OutputSizeOffset == settings.sizeOffset then
        return
    end

    local scrollOffset = self.OutputMessages:GetScrollOffset()
    self.OutputMessages:SetFontObject(Toolbox.Typography:GetFont("output"))
    -- Owned font objects update in place, so SetFontObject may see the same object.
    self.OutputMessages:MarkLayoutDirty()
    -- Native layout invalidation reflows the existing message buffer without replay.
    self.OutputMessages:SetScrollOffset(scrollOffset)

    self.OutputFamily = settings.family
    self.OutputSizeOffset = settings.sizeOffset
end

function ConsolePage:CreateEnvironment()
    self.EnvironmentPrint = function(...)
        self:WriteOutput(...)
    end

    self.Environment = {
        print = self.EnvironmentPrint,
    }

    self.Environment._G = self.Environment

    self.EnvironmentMetatable = {
        __index = _G,
    }

    setmetatable(
        self.Environment,
        self.EnvironmentMetatable
    )
end

function ConsolePage:CreateLayout()
    self:CreateInput()
    self:CreateOutput()
end

function ConsolePage:CreateInput()
    local page = self.Page.Frame

    self.Input = CreateFrame(
        "Frame",
        nil,
        page,
        "TooltipBackdropTemplate"
    )

    self.Input:SetPoint(
        "TOPLEFT",
        page,
        "TOPLEFT",
        8,
        -84
    )

    self.Input:SetPoint(
        "BOTTOMRIGHT",
        page,
        "BOTTOM",
        -6,
        38
    )

    self.InputLabel = page:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.InputLabel:SetPoint(
        "BOTTOMLEFT",
        self.Input,
        "TOPLEFT",
        8,
        6
    )

    self.InputLabel:SetText("Input")

    self.SearchHint = page:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.SearchHint:SetPoint("LEFT", self.InputLabel, "RIGHT", 10, 0)
    self.SearchHint:SetJustifyH("LEFT")
    self.SearchHint:SetText("Ctrl+F: Find   Ctrl+H: Find & Replace\nCtrl+Z: Undo   Ctrl+Y: Redo")

    self.InputEditor = CreateFrame(
        "Frame",
        nil,
        self.Input,
        "ScrollingEditBoxTemplate"
    )

    self.InputEditor:SetPoint(
        "TOPLEFT",
        self.Input,
        "TOPLEFT",
        4,
        -4
    )

    self.InputEditor:SetPoint(
        "BOTTOMRIGHT",
        self.Input,
        "BOTTOMRIGHT",
        -3,
        4
    )

    self.InputEditor:SetTextInsets(4, 4, 4, 4)

    local editBox = self.InputEditor:GetEditBox()

    editBox:SetPropagateKeyboardInput(false)
    self:ResetEditorHistory()

    self.InputEditor:RegisterCallback("OnTabPressed", function(_, inputEditBox)
        self:BeginEditorHistoryOperation()
        inputEditBox:Insert("    ")
        self:EndEditorHistoryOperation()
    end)

    self.InputEditor:RegisterCallback("OnKeyDown", function(_, _, key)
        if self:HandleEditorHistoryKey(key) then
            return
        elseif self:HandleSearchShortcut(key) then
            return
        elseif key == "F5" then
            self:Run()
        elseif key ~= "LSHIFT" and key ~= "RSHIFT" and key ~= "LCTRL" and key ~= "RCTRL"
            and key ~= "LALT" and key ~= "RALT" then
            self:InvalidateSearchSelection()
        end
    end)

    self:CreateSearchBar()

    self.InputEditor:RegisterCallback("OnTextChanged", function(_, _, userChanged)
        self:RecordEditorHistory(userChanged)
        if not self.ApplyingSearchReplacement and not self.RestoringEditorHistory and self.SearchBar:IsShown() then
            -- Editing must never move the caret or select text under the typist.
            self:RefreshSearchResults()
        end
    end)

    self.InputEditor:RegisterCallback("OnCursorChanged", function()
        self:UpdateEditorHistoryCursor()
        local match = self.SearchMatches[self.SearchIndex]
        -- Layout changes can resend cursor geometry without moving the caret.
        if match and editBox:GetCursorPosition() ~= match.Last
            and not self.SelectingSearchMatch and not self.ApplyingSearchReplacement then
            self:InvalidateSearchSelection()
        end
    end)

    editBox:RegisterCallback("OnMouseDown", function()
        self:BreakEditorHistoryGroup()
        self.EditorSelection = nil
        self:InvalidateSearchSelection()
    end)

    editBox:RegisterCallback("OnMouseUp", function()
        self:CaptureEditorHistoryPosition()
    end)

    editBox:HookScript("OnKeyUp", function(_, key)
        if key == "V" or key == "INSERT" then
            self:BreakEditorHistoryGroup()
        end
    end)

    self.InputEditor:RegisterCallback("OnFocusLost", function()
        if not self.SelectingSearchMatch and not self.ApplyingSearchReplacement and not self.RestoringEditorHistory then
            self:BreakEditorHistoryGroup()
            if not self.SearchIndex then
                self.EditorSelection = nil
            end
            self:CaptureEditorHistoryPosition()
        end
        -- EventEditBox clears highlights before forwarding this callback.
        local match = self.SearchMatches and self.SearchMatches[self.SearchIndex]
        if match and self.SearchBar:IsShown() then
            editBox:HighlightText(match.First, match.Last)
        end
    end)

    self.InputEditor:RegisterCallback("OnEscapePressed", function()
        if self.SearchBar:IsShown() then
            self:CloseSearch()
        end
    end)

    self.InputScrollBar = CreateFrame(
        "EventFrame",
        nil,
        self.Input,
        "MinimalScrollBar"
    )

    self.InputScrollBar:SetPoint(
        "TOPRIGHT",
        self.InputEditor,
        "TOPRIGHT",
        -5,
        0
    )

    self.InputScrollBar:SetPoint(
        "BOTTOMRIGHT",
        self.InputEditor,
        "BOTTOMRIGHT",
        -5,
        -1
    )

    local scrollBox = self.InputEditor:GetScrollBox()

    ScrollUtil.RegisterScrollBoxWithScrollBar(
        scrollBox,
        self.InputScrollBar
    )

    local scrollBoxAnchorsWithBar = {
        CreateAnchor(
            "TOPLEFT",
            self.InputEditor,
            "TOPLEFT",
            0,
            0
        ),

        CreateAnchor(
            "BOTTOMRIGHT",
            self.InputEditor,
            "BOTTOMRIGHT",
            -18,
            -1
        ),
    }

    local scrollBoxAnchorsWithoutBar = {
        scrollBoxAnchorsWithBar[1],

        CreateAnchor(
            "BOTTOMRIGHT",
            self.InputEditor,
            "BOTTOMRIGHT",
            -2,
            -1
        ),
    }

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(
        scrollBox,
        self.InputScrollBar,
        scrollBoxAnchorsWithBar,
        scrollBoxAnchorsWithoutBar
    )

    self.RunButton = CreateFrame(
        "Button",
        nil,
        page,
        "UIPanelButtonTemplate"
    )

    self.RunButton:SetSize(80, 24)

    self.RunButton:SetPoint(
        "TOPLEFT",
        self.Input,
        "BOTTOMLEFT",
        0,
        -6
    )

    self.RunButton:SetText("RUN")

    self.RunButton:SetScript("OnClick", function()
        self:Run()
    end)

    self.ClearButton = CreateFrame(
        "Button",
        nil,
        page,
        "UIPanelButtonTemplate"
    )

    self.ClearButton:SetSize(80, 24)

    self.ClearButton:SetPoint(
        "LEFT",
        self.RunButton,
        "RIGHT",
        6,
        0
    )

    self.ClearButton:SetText("CLEAR")

    self.ClearButton:SetScript("OnClick", function()
        self:BeginEditorHistoryOperation()
        editBox:SetText("")
        self:EndEditorHistoryOperation()
        self:ClearOutput()
    end)

    self.RunHint = page:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.RunHint:SetPoint(
        "LEFT",
        self.ClearButton,
        "RIGHT",
        8,
        0
    )

    self.RunHint:SetText("* Press RUN to run the code, or press F5.")
end

function ConsolePage:GetEditorHistoryState()
    local editBox = self.InputEditor:GetEditBox()
    local selection = self.EditorSelection
    return {
        Text = editBox:GetText(),
        Cursor = editBox:GetCursorPosition(),
        First = selection and selection.First,
        Last = selection and selection.Last,
    }
end

function ConsolePage:ResetEditorHistory()
    -- Only called when the editor is created. Nothing is written to SavedVariables.
    self.EditorSelection = nil
    self.EditorHistory = { States = { self:GetEditorHistoryState() }, Index = 1 }
end

function ConsolePage:BreakEditorHistoryGroup()
    local history = self.EditorHistory
    history.Group = nil
    history.Pasting = nil
    history.Intent = nil
end

function ConsolePage:CaptureEditorHistoryPosition()
    if self.RestoringEditorHistory then
        return
    end
    local history = self.EditorHistory
    local state = history.States[history.Index]
    if state.Text == self.InputEditor:GetText() then
        local position = self:GetEditorHistoryState()
        state.Cursor, state.First, state.Last = position.Cursor, position.First, position.Last
    end
end

function ConsolePage:UpdateEditorHistoryCursor()
    if self.RestoringEditorHistory or self.SelectingSearchMatch or self.ApplyingSearchReplacement then
        return
    end
    local history = self.EditorHistory
    local state = history.States[history.Index]
    local editBox = self.InputEditor:GetEditBox()
    -- Native text edits can report cursor geometry before or after OnTextChanged.
    -- Only a caret move within the same text constitutes an editing boundary.
    if state.Text == editBox:GetText() then
        if state.Cursor ~= editBox:GetCursorPosition() then
            local selection = history.Intent == "selectAll" and self.EditorSelection or nil
            self:BreakEditorHistoryGroup()
            self.EditorSelection = selection
        end
        self:CaptureEditorHistoryPosition()
    end
end

function ConsolePage:RecordEditorHistory(userChanged)
    local history = self.EditorHistory
    if self.RestoringEditorHistory or history.OperationDepth then
        return
    end

    local before = history.States[history.Index]
    local text = self.InputEditor:GetText()
    if before.Text == text then
        return
    end

    self.EditorSelection = nil
    local state = self:GetEditorHistoryState()
    local added = #text - #before.Text
    local now = GetTime()
    local typing = userChanged and history.Intent ~= "operation" and not history.Pasting
        and not before.First and added > 0 and added <= 4
        and state.Cursor == before.Cursor + added
        and IsSingleUTF8Character(text:sub(before.Cursor + 1, state.Cursor))
        and text:sub(1, before.Cursor) == before.Text:sub(1, before.Cursor)
        and text:sub(state.Cursor + 1) == before.Text:sub(before.Cursor + 1)
    local group = history.Pasting and "paste" or typing and "typing" or nil
    local merge = group and history.Group == group and history.Index == #history.States
        and (group == "paste" or (now - history.LastEditTime <= EDITOR_TYPING_INTERVAL
            and history.GroupCursor == before.Cursor))

    -- A new edit always discards the redo branch, including after the oldest undo.
    for i = #history.States, history.Index + 1, -1 do
        history.States[i] = nil
    end
    if merge then
        history.States[history.Index] = state
    else
        history.Index = history.Index + 1
        history.States[history.Index] = state
        if #history.States > MAX_EDITOR_UNDO_STEPS + 1 then
            table.remove(history.States, 1)
            history.Index = history.Index - 1
        end
    end
    history.Group, history.GroupCursor, history.LastEditTime = group, state.Cursor, now
end

function ConsolePage:BeginEditorHistoryOperation()
    local history = self.EditorHistory
    self:BreakEditorHistoryGroup()
    self:CaptureEditorHistoryPosition()
    history.OperationDepth = (history.OperationDepth or 0) + 1
end

function ConsolePage:EndEditorHistoryOperation()
    local history = self.EditorHistory
    history.OperationDepth = history.OperationDepth - 1
    if history.OperationDepth == 0 then
        history.OperationDepth = nil
        self:RecordEditorHistory(false)
        self:CaptureEditorHistoryPosition()
        self:BreakEditorHistoryGroup()
    end
end

function ConsolePage:HandleEditorHistoryKey(key)
    local editBox = self.InputEditor:GetEditBox()
    local control = IsControlKeyDown() and not IsAltKeyDown()
    if control and editBox:HasFocus() and (key == "Z" or key == "Y") then
        if key == "Y" or IsShiftKeyDown() then
            self:RedoEditor()
        else
            self:UndoEditor()
        end
        return true
    end

    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" then
        return false
    end

    self:CaptureEditorHistoryPosition()
    local navigation = key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN"
        or key == "HOME" or key == "END" or key == "PAGEUP" or key == "PAGEDOWN"
    if control or IsAltKeyDown() or navigation or key == "BACKSPACE" or key == "DELETE"
        or key == "TAB" or key == "ENTER" or key == "ESCAPE" or key:match("^F%d+$")
        or (IsShiftKeyDown() and key == "INSERT") then
        self:BreakEditorHistoryGroup()
        self.EditorHistory.Intent = "operation"
        if (control and key == "V") or (IsShiftKeyDown() and key == "INSERT") then
            -- Some clients emit several text notifications during one paste.
            self.EditorHistory.Pasting = true
        end
    else
        self.EditorHistory.Intent = "typing"
    end

    if navigation then
        self.EditorSelection = nil
    elseif control and key == "A" then
        self.EditorHistory.Intent = "selectAll"
        self.EditorSelection = { First = 0, Last = #editBox:GetText() }
        self:CaptureEditorHistoryPosition()
    end
    return false
end

function ConsolePage:RestoreEditorHistory(index)
    local history = self.EditorHistory
    self:BreakEditorHistoryGroup()
    if index < 1 or index > #history.States then
        return
    end
    self:CaptureEditorHistoryPosition()
    history.Index = index
    local state = history.States[index]
    local editBox = self.InputEditor:GetEditBox()
    local focus = self.FindBox:HasFocus() and self.FindBox or self.ReplaceBox:HasFocus() and self.ReplaceBox
    self.RestoringEditorHistory = true
    self:InvalidateSearchSelection()
    editBox:SetFocus()
    editBox:SetText(state.Text)
    if self.SearchBar:IsShown() then
        self:RefreshSearchResults()
    end
    editBox:SetCursorPosition(state.Cursor)
    self.InputEditor:ScrollCursorIntoView(false)
    if focus then
        focus:SetFocus()
    end
    -- There is no native selection getter. Restore ranges we own (search results,
    -- Ctrl+A and prior restores); arbitrary mouse/Shift selections retain the caret.
    self.EditorSelection = state.First and { First = state.First, Last = state.Last } or nil
    if self.EditorSelection then
        editBox:HighlightText(state.First, state.Last)
    end
    self.RestoringEditorHistory = false
end

function ConsolePage:UndoEditor()
    self:RestoreEditorHistory(self.EditorHistory.Index - 1)
end

function ConsolePage:RedoEditor()
    self:RestoreEditorHistory(self.EditorHistory.Index + 1)
end

function ConsolePage:CreateSearchBar()
    local bar = CreateFrame("Frame", nil, self.Input)
    bar:SetPoint("TOPLEFT", self.Input, "TOPLEFT", 8, -4)
    bar:SetPoint("TOPRIGHT", self.Input, "TOPRIGHT", -8, -4)
    bar:SetHeight(58)
    bar:Hide()
    self.SearchBar = bar

    local function Label(parent, text, x, y)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetText(text)
        return label
    end

    local function Button(parent, text, width, x, y, onClick)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    local function Field(parent, rightInset)
        local field = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        field:SetAutoFocus(false)
        field:SetMultiLine(false)
        field:SetHeight(22)
        field:SetPoint("TOPLEFT", parent, "TOPLEFT", 60, -4)
        field:SetPoint("TOPRIGHT", parent, "TOPRIGHT", rightInset, -4)
        field:SetPropagateKeyboardInput(false)
        -- InputBoxTemplate selects all text on focus gain. Match scrolling
        -- temporarily focuses the editor, so returning here must keep the caret
        -- and leave typed text unselected. OpenSearch selects the query explicitly.
        field:SetScript("OnEditFocusGained", nil)
        field:SetScript("OnEscapePressed", function() self:CloseSearch() end)
        field:SetScript("OnEnterPressed", function()
            self:NavigateSearch(IsShiftKeyDown() and -1 or 1)
        end)
        field:SetScript("OnKeyDown", function(_, key) self:HandleSearchShortcut(key) end)
        return field
    end

    Label(bar, "Find", 0, -9)
    self.FindBox = Field(bar, -30)
    self.FindBox:SetScript("OnTextChanged", function()
        self:RefreshSearchResults()
        self:NavigateSearch(1)
    end)

    self.SearchCloseButton = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    self.SearchCloseButton:SetSize(26, 26)
    self.SearchCloseButton:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 2, -2)
    self.SearchCloseButton:SetScript("OnClick", function() self:CloseSearch() end)

    self.SearchPreviousButton = Button(bar, "Previous", 66, 0, -31, function() self:NavigateSearch(-1) end)
    self.SearchNextButton = Button(bar, "Next", 48, 70, -31, function() self:NavigateSearch(1) end)
    self.SearchCase = Toolbox.Classes.CheckBox:New(bar, "Match case")
    self.SearchCase.Frame:SetSize(22, 22)
    self.SearchCase.Frame:SetPoint("TOPLEFT", bar, "TOPLEFT", 122, -31)
    self.SearchCase.Frame.Text:SetFontObject("GameFontNormalSmall")
    self.SearchCase:SetOnClick(function()
        self:RefreshSearchResults()
        self:NavigateSearch(1)
    end)

    self.SearchStatus = Label(bar, "Enter search text", 0, 0)
    self.SearchStatus:ClearAllPoints()
    self.SearchStatus:SetPoint("LEFT", self.SearchCase.Frame.Text, "RIGHT", 10, 0)
    self.SearchStatus:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    self.SearchStatus:SetJustifyH("RIGHT")

    self.ReplaceRow = CreateFrame("Frame", nil, bar)
    self.ReplaceRow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -58)
    self.ReplaceRow:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -58)
    self.ReplaceRow:SetHeight(30)
    self.ReplaceRow:Hide()
    Label(self.ReplaceRow, "Replace", 0, -9)
    self.ReplaceBox = Field(self.ReplaceRow, -164)
    self.ReplaceButton = Button(self.ReplaceRow, "Replace", 68, 0, -4, function() self:ReplaceSearchMatch() end)
    self.ReplaceButton:ClearAllPoints()
    self.ReplaceButton:SetPoint("TOPRIGHT", self.ReplaceRow, "TOPRIGHT", -86, -4)
    self.ReplaceAllButton = Button(self.ReplaceRow, "Replace All", 82, 0, -4, function() self:ReplaceAllSearchMatches() end)
    self.ReplaceAllButton:ClearAllPoints()
    self.ReplaceAllButton:SetPoint("TOPRIGHT", self.ReplaceRow, "TOPRIGHT", 0, -4)

    self.FindBox:SetScript("OnTabPressed", function()
        if self.ReplaceRow:IsShown() then
            self.ReplaceBox:SetFocus()
        end
    end)
    self.ReplaceBox:SetScript("OnTabPressed", function() self.FindBox:SetFocus() end)
    self:RefreshSearchResults()
end

function ConsolePage:HandleSearchShortcut(key)
    if IsControlKeyDown() and not IsAltKeyDown() and (key == "F" or key == "H") then
        self:OpenSearch(key == "H")
        return true
    end
    return false
end

function ConsolePage:OpenSearch(withReplace)
    self:BreakEditorHistoryGroup()
    self:CaptureEditorHistoryPosition()
    self.ReplaceRow:SetShown(withReplace)
    self.SearchBar:SetHeight(withReplace and 88 or 58)
    self.SearchBar:Show()
    self.InputEditor:SetPoint("TOPLEFT", self.Input, "TOPLEFT", 4, withReplace and -96 or -66)
    self.FindBox:SetFocus()
    self:RefreshSearchResults()
    self:NavigateSearch(1)
    self.FindBox:HighlightText()
end

function ConsolePage:CloseSearch(restoreFocus)
    self.SearchBar:Hide()
    self.FindBox:ClearFocus()
    self.ReplaceBox:ClearFocus()
    self:InvalidateSearchSelection()
    self.InputEditor:SetPoint("TOPLEFT", self.Input, "TOPLEFT", 4, -4)
    if restoreFocus ~= false then
        self.InputEditor:SetFocus()
        self.InputEditor:ScrollCursorIntoView(false)
    end
end

function ConsolePage:UpdateSearchStatus()
    local count = #self.SearchMatches
    if self.FindBox:GetText() == "" then
        self.SearchStatus:SetText("Enter search text")
    elseif count == 0 then
        self.SearchStatus:SetText("No matches")
    else
        self.SearchStatus:SetText(string.format("%d of %d", self.SearchIndex or 0, count))
    end
    self.SearchStatus:SetTextColor(1, count == 0 and self.FindBox:GetText() ~= "" and 0.25 or 0.82, 0)
    self.SearchPreviousButton:SetEnabled(count > 0)
    self.SearchNextButton:SetEnabled(count > 0)
    self.ReplaceButton:SetEnabled(self.SearchIndex ~= nil)
    self.ReplaceAllButton:SetEnabled(count > 0)
end

function ConsolePage:InvalidateSearchSelection()
    if self.SearchIndex then
        self.SearchIndex = nil
        self:UpdateSearchStatus()
    end
end

function ConsolePage:RefreshSearchResults()
    if self.SearchIndex then
        self.InputEditor:GetEditBox():HighlightText(0, 0)
    end
    self.SearchText = self.InputEditor:GetText()
    self.SearchQuery = self.FindBox:GetText()
    self.SearchCaseSensitive = self.SearchCase:IsChecked() and true or false
    self.SearchMatches = FindLiteralMatches(self.SearchText, self.SearchQuery, self.SearchCaseSensitive)
    self.SearchIndex = nil
    self:UpdateSearchStatus()
end

function ConsolePage:EnsureSearchResults()
    if self.SearchText ~= self.InputEditor:GetText() or self.SearchQuery ~= self.FindBox:GetText()
        or self.SearchCaseSensitive ~= (self.SearchCase:IsChecked() and true or false) then
        self:RefreshSearchResults()
    end
end

function ConsolePage:SelectSearchMatch(index)
    local match = self.SearchMatches[index]
    if not match then
        return
    end

    self:BreakEditorHistoryGroup()
    self:CaptureEditorHistoryPosition()
    local focus = self.FindBox:HasFocus() and self.FindBox or self.ReplaceBox:HasFocus() and self.ReplaceBox
    local editBox = self.InputEditor:GetEditBox()
    self.SelectingSearchMatch = true
    self.SearchIndex = index
    -- EventEditBox only forwards cursor geometry changes while focused. Let the
    -- native scrolling template reveal the caret, then return to the search field.
    editBox:SetFocus()
    editBox:SetCursorPosition(match.Last)
    self.InputEditor:ScrollCursorIntoView(false)
    if focus then
        focus:SetFocus()
    end
    editBox:HighlightText(match.First, match.Last)
    self.EditorSelection = { First = match.First, Last = match.Last }
    self.SelectingSearchMatch = false
    self:CaptureEditorHistoryPosition()
    self:UpdateSearchStatus()
end

function ConsolePage:NavigateSearch(direction, position)
    self:EnsureSearchResults()
    local count = #self.SearchMatches
    if count == 0 then
        return
    end

    local index
    if self.SearchIndex and not position then
        index = ((self.SearchIndex - 1 + direction) % count) + 1
    else
        position = position or self.InputEditor:GetEditBox():GetCursorPosition()
        if direction == 1 then
            index = 1
            for i, match in ipairs(self.SearchMatches) do
                if match.First >= position then
                    index = i
                    break
                end
            end
        else
            index = count
            for i = count, 1, -1 do
                if self.SearchMatches[i].Last <= position then
                    index = i
                    break
                end
            end
        end
    end
    self:SelectSearchMatch(index)
end

function ConsolePage:ApplySearchReplacement(text, cursor)
    local editBox = self.InputEditor:GetEditBox()
    local focus = self.FindBox:HasFocus() and self.FindBox or self.ReplaceBox:HasFocus() and self.ReplaceBox
    self:BeginEditorHistoryOperation()
    self.ApplyingSearchReplacement = true
    self:InvalidateSearchSelection()
    editBox:SetFocus()
    -- Use the inner EditBox: the outer SetText scrolls back to the document start.
    editBox:SetText(text)
    editBox:SetCursorPosition(cursor)
    self.InputEditor:ScrollCursorIntoView(false)
    if focus then
        focus:SetFocus()
    end
    self.ApplyingSearchReplacement = false
    self:EndEditorHistoryOperation()
    self:RefreshSearchResults()
    if #self.SearchMatches > 0 then
        self:NavigateSearch(1, cursor)
    end
end

function ConsolePage:ReplaceSearchMatch()
    self:EnsureSearchResults()
    local match = self.SearchMatches[self.SearchIndex]
    if not match then
        return
    end
    local replacement = self.ReplaceBox:GetText()
    self:ApplySearchReplacement(
        self.SearchText:sub(1, match.First) .. replacement .. self.SearchText:sub(match.Last + 1),
        match.First + #replacement
    )
end

function ConsolePage:ReplaceAllSearchMatches()
    self:EnsureSearchResults()
    if #self.SearchMatches == 0 then
        return
    end

    local replacement = self.ReplaceBox:GetText()
    local parts, position = {}, 0
    local cursor = self.InputEditor:GetEditBox():GetCursorPosition()
    local adjustedCursor = cursor
    for _, match in ipairs(self.SearchMatches) do
        parts[#parts + 1] = self.SearchText:sub(position + 1, match.First)
        parts[#parts + 1] = replacement
        if cursor >= match.Last then
            adjustedCursor = adjustedCursor + #replacement - (match.Last - match.First)
        elseif cursor > match.First then
            adjustedCursor = adjustedCursor + #replacement - (cursor - match.First)
        end
        position = match.Last
    end
    parts[#parts + 1] = self.SearchText:sub(position + 1)
    self:ApplySearchReplacement(table.concat(parts), adjustedCursor)
end

function ConsolePage:CreateOutput()
    local page = self.Page.Frame

    self.OutputLines = {}
    self.OutputMessageHistory = {}

    self.Output = CreateFrame(
        "Frame",
        nil,
        page,
        "TooltipBackdropTemplate"
    )

    self.Output:SetPoint(
        "TOPLEFT",
        page,
        "TOP",
        6,
        -84
    )

    self.Output:SetPoint(
        "BOTTOMRIGHT",
        page,
        "BOTTOMRIGHT",
        -8,
        38
    )

    self.OutputLabel = page:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontNormal"
    )

    self.OutputLabel:SetPoint(
        "BOTTOMLEFT",
        self.Output,
        "TOPLEFT",
        8,
        6
    )

    self.OutputLabel:SetText("Output")

    self.OutputMessages = CreateFrame(
        "ScrollingMessageFrame",
        nil,
        self.Output
    )

    self.OutputMessages:SetPoint(
        "TOPLEFT",
        self.Output,
        "TOPLEFT",
        8,
        -8
    )

    self.OutputMessages:SetPoint(
        "BOTTOMRIGHT",
        self.Output,
        "BOTTOMRIGHT",
        -30,
        8
    )

    self.OutputMessages:EnableMouse(true)
    self.OutputMessages:SetFading(false)
    self.OutputMessages:SetFontObject(ChatFontNormal)

    self.OutputMessages:SetInsertMode(
        SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP
    )

    self.OutputMessages:SetJustifyH("LEFT")
    self.OutputMessages:SetTextCopyable(true)
    self.OutputMessages:SetMaxLines(MAX_OUTPUT_LINES)

    self.OutputScrollBar = CreateFrame(
        "EventFrame",
        nil,
        self.Output,
        "MinimalScrollBar"
    )

    self.OutputScrollBar:SetPoint(
        "TOPRIGHT",
        self.Output,
        "TOPRIGHT",
        -12,
        -10
    )

    self.OutputScrollBar:SetPoint(
        "BOTTOMRIGHT",
        self.Output,
        "BOTTOMRIGHT",
        -12,
        10
    )

    ScrollUtil.InitScrollingMessageFrameWithScrollBar(
        self.OutputMessages,
        self.OutputScrollBar
    )

    self.ExportOutputButton = CreateFrame(
        "Button",
        nil,
        page,
        "UIPanelButtonTemplate"
    )

    self.ExportOutputButton:SetSize(
        110,
        24
    )

    self.ExportOutputButton:SetPoint(
        "TOPRIGHT",
        self.Output,
        "BOTTOMRIGHT",
        0,
        -6
    )

    self.ExportOutputButton:SetText("EXPORT TEXT")
    self.ExportOutputButton:Disable()

    self.ExportOutputButton:SetScript("OnClick", function()
        self:ExportOutput()
    end)

    self.OutputHint = page:CreateFontString(
        nil,
        "ARTWORK",
        "GameFontDisableSmall"
    )

    self.OutputHint:SetPoint(
        "LEFT",
        self.Output,
        "BOTTOMLEFT",
        8,
        -18
    )

    self.OutputHint:SetPoint(
        "RIGHT",
        self.ExportOutputButton,
        "LEFT",
        -8,
        0
    )

    self.OutputHint:SetJustifyH("RIGHT")
    self.OutputHint:SetText(
        "* Select text to copy, or export the full output."
    )
end

function ConsolePage:SetupKeyboard()
    local page = self.Page.Frame

    page:EnableKeyboard(false)
    page:SetPropagateKeyboardInput(true)

    page:SetScript("OnKeyDown", function(frame, key)
        if self:HandleSearchShortcut(key) then
            frame:SetPropagateKeyboardInput(false)
        elseif key == "ESCAPE" and self.SearchBar:IsShown() then
            frame:SetPropagateKeyboardInput(false)
            self:CloseSearch()
        elseif key == "F5" then
            frame:SetPropagateKeyboardInput(false)
            self:Run()
        else
            frame:SetPropagateKeyboardInput(true)
        end
    end)

    page:HookScript("OnShow", function(frame)
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(true)
    end)

    page:HookScript("OnHide", function(frame)
        self:BreakEditorHistoryGroup()
        self:CaptureEditorHistoryPosition()
        self:CloseSearch(false)
        frame:SetPropagateKeyboardInput(true)
        frame:EnableKeyboard(false)
    end)
end

function ConsolePage:ClearOutput()
    self.OutputMessages:ResetSelectingText()
    self.OutputMessages:Clear()

    -- WoW: Forever can otherwise leave cleared text selectable and copyable.
    if self.OutputMessages.visibleLines then
        for _, line in ipairs(self.OutputMessages.visibleLines) do
            line:SetText("")
            line:Hide()
        end
    end

    wipe(self.OutputLines)
    wipe(self.OutputMessageHistory)

    self.ExportOutputButton:Disable()
end

function ConsolePage:StoreOutputLine(text, red, green, blue)
    table.insert(
        self.OutputLines,
        text
    )

    table.insert(
        self.OutputMessageHistory,
        {
            Text = text,
            Red = red,
            Green = green,
            Blue = blue,
        }
    )

    if #self.OutputLines > MAX_OUTPUT_LINES then
        table.remove(self.OutputLines, 1)
        table.remove(self.OutputMessageHistory, 1)
        return true
    end

    return false
end

function ConsolePage:RefreshOutputMessages()
    self.OutputMessages:ResetSelectingText()
    self.OutputMessages:Clear()

    for _, message in ipairs(self.OutputMessageHistory) do
        self.OutputMessages:BackFillMessage(
            message.Text,
            message.Red,
            message.Green,
            message.Blue
        )
    end
end

function ConsolePage:AddOutputMessage(text, red, green, blue)
    local didRollOver = self:StoreOutputLine(
        text,
        red,
        green,
        blue
    )

    if didRollOver then
        self:RefreshOutputMessages()
    else
        self.OutputMessages:BackFillMessage(
            text,
            red,
            green,
            blue
        )
    end
end

function ConsolePage:WriteOutput(...)
    local text = strjoin(" ", tostringall(...))

    self:AddOutputMessage(text)

    self.ExportOutputButton:Enable()
end

function ConsolePage:Run()
    self:ClearOutput()

    local code = self.InputEditor:GetText()

    if not code or code == "" then
        return
    end

    local chunk, compileError = loadstring(
        code,
        "ToolboxConsole"
    )

    if not chunk then
        self:WriteError(
            compileError
        )

        return
    end

    self.Environment.print = self.EnvironmentPrint
    self.Environment._G = self.Environment

    setmetatable(
        self.Environment,
        self.EnvironmentMetatable
    )

    setfenv(chunk, self.Environment)

    local results = PackResults(
        xpcall(chunk, CreateRuntimeTraceback)
    )

    local success = results[1]

    if not success then
        self:WriteError(
            results[2]
        )

        return
    end

    for i = 2, results.Count do
        self:WriteOutput(
            results[i]
        )
    end
end

function ConsolePage:WriteError(message)
    local text = tostring(message)

    self:AddOutputMessage(
        text,
        1,
        0.2,
        0.2
    )

    self.ExportOutputButton:Enable()
end

function ConsolePage:ExportOutput()
    if #self.OutputLines == 0 then
        return
    end

    Toolbox.UI.ExportDialog:Show(
        "Console Output",
        table.concat(self.OutputLines, "\n"),
        700,
        500
    )
end
