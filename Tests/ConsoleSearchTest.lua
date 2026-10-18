-- Run from the addon root with Lua 5.1: lua Tests/ConsoleSearchTest.lua
-- No game client or third-party test framework is required.
local focused, controlDown, shiftDown, altDown
local elapsed = 0
local Widget = {}
Widget.__index = Widget

local function NewWidget()
    return setmetatable({ text = "", cursor = 0, shown = true, scripts = {}, callbacks = {}, points = {} }, Widget)
end

function Widget:SetScript(event, callback) self.scripts[event] = callback end
function Widget:HookScript(event, callback)
    local previous = self.scripts[event]
    self.scripts[event] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function Widget:RegisterCallback(event, callback)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], callback)
end
function Widget:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, callback in ipairs(self.callbacks[event] or {}) do callback(nil, self, ...) end
end
function Widget:SetPoint(point, ...) self.points[point] = { ... } end
function Widget:ClearAllPoints() self.points = {} end
function Widget:SetSize() end
function Widget:SetHeight(height) self.height = height end
function Widget:SetTextInsets() end
function Widget:SetFontObject() end
function Widget:SetTextColor() end
function Widget:SetJustifyH() end
function Widget:SetAutoFocus() end
function Widget:SetMultiLine() end
function Widget:SetPropagateKeyboardInput(value) self.propagate = value end
function Widget:EnableKeyboard(value) self.keyboard = value end
function Widget:SetEnabled(value) self.enabled = value end
function Widget:Disable() self.enabled = false end
function Widget:SetChecked(value) self.checked = value end
function Widget:GetChecked() return self.checked end
function Widget:IsShown() return self.shown end
function Widget:SetShown(value) if value then self:Show() else self:Hide() end end
function Widget:Show() self.shown = true; self:Fire("OnShow") end
function Widget:Hide() self.shown = false; self:Fire("OnHide") end
function Widget:GetText() return self.text end
function Widget:SetText(text)
    self.text = text
    self.cursor = #text
    self.highlight = nil
    self:Fire("OnTextChanged", false)
end
function Widget:SetCursorPosition(position)
    assert(position >= 0 and position <= #self.text, "cursor outside document")
    local nextByte = self.text:byte(position + 1)
    assert(not nextByte or nextByte < 128 or nextByte >= 192, "cursor splits UTF-8")
    self.cursor = position
    self.highlight = nil
    if self:HasFocus() then self:Fire("OnCursorChanged") end
end
function Widget:GetCursorPosition() return self.cursor end
function Widget:HighlightText(first, last)
    first, last = first or 0, last or #self.text
    assert(first <= last and last <= #self.text, "highlight outside document")
    self.highlight = { first, last }
end
function Widget:HasFocus() return focused == self end
function Widget:ClearFocus()
    if focused == self then
        focused = nil
        self.highlight = nil
        self:Fire("OnEditFocusLost")
        self:Fire("OnFocusLost")
    end
end
function Widget:SetFocus()
    if focused ~= self then
        if focused then focused:ClearFocus() end
        focused = self
        self:Fire("OnEditFocusGained")
    end
end
function Widget:Insert(text)
    local first, last = self.cursor, self.cursor
    if self.highlight then first, last = unpack(self.highlight) end
    self.text = self.text:sub(1, first) .. text .. self.text:sub(last + 1)
    self.cursor = first + #text
    self.highlight = nil
    self:Fire("OnTextChanged", true)
    if self:HasFocus() then self:Fire("OnCursorChanged") end
end
function Widget:CreateFontString() return NewWidget() end
function Widget:GetEditBox() return self.editBox end
function Widget:GetScrollBox() return self.scrollBox end
function Widget:ScrollCursorIntoView() self.scrolledCursor = self.editBox.cursor end
function Widget:GetInputText() return self.editBox:GetText() end

function CreateFrame(_, _, _, template)
    local widget = NewWidget()
    if template == "ScrollingEditBoxTemplate" then
        widget.editBox, widget.scrollBox = NewWidget(), NewWidget()
        for _, event in ipairs({ "OnKeyDown", "OnTextChanged", "OnCursorChanged", "OnEscapePressed", "OnFocusLost", "OnTabPressed" }) do
            widget.editBox:RegisterCallback(event, function(_, _, ...)
                for _, callback in ipairs(widget.callbacks[event] or {}) do
                    callback(nil, widget.editBox, ...)
                end
            end)
        end
        -- The real template inserts newlines and clears focus by default.
        widget.editBox:SetScript("OnEnterPressed", function(editBox) editBox:Insert("\n") end)
        widget.editBox:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
        widget.GetText = function(self) return self.editBox:GetText() end
        widget.SetFocus = function(self) self.editBox:SetFocus() end
    elseif template == "UICheckButtonTemplate" then
        widget.Text = NewWidget()
    elseif template == "InputBoxTemplate" then
        -- InputBoxScriptTemplate selects all text whenever focus returns.
        widget:SetScript("OnEditFocusGained", function(editBox) editBox:HighlightText() end)
        widget:SetScript("OnEditFocusLost", function(editBox) editBox.highlight = nil end)
    end
    return widget
end
function CreateAnchor() return {} end
ScrollUtil = {
    RegisterScrollBoxWithScrollBar = function() end,
    AddManagedScrollBarVisibilityBehavior = function() end,
}
function IsControlKeyDown() return controlDown end
function IsShiftKeyDown() return shiftDown end
function IsAltKeyDown() return altDown end
function GetTime() return elapsed end

local Toolbox = { UI = {}, Classes = {} }
assert(loadfile("UI/Components/CheckBox.lua"))("Toolbox", Toolbox)
assert(loadfile("UI/Pages/ConsolePage.lua"))("Toolbox", Toolbox)
local ConsolePage = Toolbox.UI.ConsolePage
local tests = 0
local function Equal(actual, expected)
    assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end
local function Test(name, callback)
    focused, controlDown, shiftDown, altDown = nil, false, false, false
    elapsed = 0
    callback()
    tests = tests + 1
    print("PASS " .. name)
end
local function Editor(text, query, sensitive)
    local page = setmetatable({ Page = { Frame = NewWidget() } }, { __index = ConsolePage })
    page:CreateInput()
    page:SetupKeyboard()
    page.runs = 0
    page.Run = function(self) self.runs = self.runs + 1 end
    page.InputEditor:GetEditBox():SetText(text)
    page.InputEditor:GetEditBox():SetCursorPosition(0)
    page:OpenSearch(true)
    page.SearchCase:SetChecked(sensitive)
    page.FindBox:SetText(query or "")
    return page, page.InputEditor:GetEditBox()
end

Test("next, previous, and wrapping", function()
    local page = Editor("one one one", "one")
    Equal(page.SearchStatus:GetText(), "1 of 3")
    page:NavigateSearch(1); Equal(page.SearchIndex, 2)
    page:NavigateSearch(1); Equal(page.SearchIndex, 3)
    page:NavigateSearch(1); Equal(page.SearchIndex, 1)
    page:NavigateSearch(-1); Equal(page.SearchIndex, 3)
end)
Test("navigation starts at the editor caret", function()
    local page, editBox = Editor("one one one", "one")
    editBox:SetFocus(); editBox:SetCursorPosition(4)
    page:NavigateSearch(1); Equal(page.SearchIndex, 2)
    editBox:SetCursorPosition(4)
    page:NavigateSearch(-1); Equal(page.SearchIndex, 1)
end)
Test("single occurrence wraps to itself", function()
    local page = Editor("one", "one")
    page:NavigateSearch(1); page:NavigateSearch(-1)
    Equal(page.SearchIndex, 1)
end)
Test("case-insensitive and case-sensitive searches", function()
    local page = Editor("Lua lua LUA", "lua")
    Equal(#page.SearchMatches, 3)
    page.SearchCase:SetChecked(true); page.SearchCase.Frame:Fire("OnClick")
    Equal(#page.SearchMatches, 1)
    Equal(page.SearchMatches[1].First, 4)
end)
Test("special characters are literal", function()
    local literal = ".^$%[]()*+-?"
    local page = Editor(literal .. "\n" .. literal, literal)
    Equal(#page.SearchMatches, 2)
    page.ReplaceBox:SetText("%1%0\\literal")
    page:ReplaceAllSearchMatches()
    Equal(page.InputEditor:GetText(), "%1%0\\literal\n%1%0\\literal")
end)
Test("multiline queries and replacements", function()
    local page = Editor("a\nb\na\nb", "a\nb")
    Equal(#page.SearchMatches, 2)
    page.ReplaceBox:SetText("x\ny")
    page:ReplaceSearchMatch()
    Equal(page.InputEditor:GetText(), "x\ny\na\nb")
    Equal(#page.SearchMatches, 1)
end)
Test("typing queries and replacements never edits Lua", function()
    local page, editBox = Editor("one two one", "one")
    page.FindBox:SetText("two")
    page.ReplaceBox:SetText("changed")
    Equal(editBox:GetText(), "one two one")
    Equal(page.runs, 0)
end)
Test("typing a full query does not replace earlier letters after a match", function()
    local page, editBox = Editor("print('hello')", "")
    for _, character in ipairs({ "p", "r", "i", "n", "t" }) do
        local expected = page.FindBox:GetText() .. character
        page.FindBox:Insert(character)
        Equal(page.FindBox:GetText(), expected)
        Equal(page.FindBox:GetCursorPosition(), #expected)
        Equal(page.FindBox.highlight, nil)
        Equal(page.FindBox:HasFocus(), true)
    end
    Equal(page.FindBox:GetText(), "print")
    Equal(page.SearchStatus:GetText(), "1 of 1")
    Equal(editBox:GetText(), "print('hello')")
end)
Test("query editing in the middle preserves its caret across match updates", function()
    local page = Editor("print print", "pnt")
    page.FindBox:SetCursorPosition(1)
    page.FindBox:Insert("r")
    page.FindBox:Insert("i")
    Equal(page.FindBox:GetText(), "print")
    Equal(page.FindBox:GetCursorPosition(), 3)
    page:NavigateSearch(1)
    Equal(page.FindBox:GetCursorPosition(), 3)
    Equal(page.FindBox.highlight, nil)
    page.FindBox:Insert("X")
    Equal(page.FindBox:GetText(), "priXnt")
end)
Test("typing UTF-8 query characters preserves prior input", function()
    local page = Editor("café😀", "")
    for _, character in ipairs({ "c", "a", "f", "é", "😀" }) do
        page.FindBox:Insert(character)
    end
    Equal(page.FindBox:GetText(), "café😀")
    Equal(page.SearchStatus:GetText(), "1 of 1")
end)
Test("reopening Find still explicitly selects the existing query", function()
    local page = Editor("print", "print")
    page:CloseSearch()
    page:OpenSearch(false)
    Equal(page.FindBox.highlight[1], 0)
    Equal(page.FindBox.highlight[2], #"print")
    page.FindBox:Insert("p")
    Equal(page.FindBox:GetText(), "p")
    page.FindBox:Insert("r")
    Equal(page.FindBox:GetText(), "pr")
end)
Test("replacement text remains editable after match scrolling", function()
    local page = Editor("one one", "one")
    page.ReplaceBox:SetFocus()
    page.ReplaceBox:SetText("two")
    page:NavigateSearch(1)
    page.ReplaceBox:Insert("!")
    Equal(page.ReplaceBox:GetText(), "two!")
    page:ReplaceSearchMatch()
    page.ReplaceBox:Insert("?")
    Equal(page.ReplaceBox:GetText(), "two!?")
    Equal(page.InputEditor:GetText(), "one two!")
end)
Test("replace only the selected occurrence, then advance", function()
    local page, editBox = Editor("one one one", "one")
    page:NavigateSearch(1)
    page.ReplaceBox:SetText("two")
    page:ReplaceSearchMatch()
    Equal(editBox:GetText(), "one two one")
    Equal(page.SearchMatches[page.SearchIndex].First, 8)
end)
Test("empty replacement deletes one or all matches", function()
    local page, editBox = Editor("one-one-one", "one")
    page:ReplaceSearchMatch(); Equal(editBox:GetText(), "-one-one")
    page:ReplaceAllSearchMatches(); Equal(editBox:GetText(), "--")
    Equal(page.SearchStatus:GetText(), "No matches")
end)
Test("adjacent repeated matches use non-overlapping occurrences", function()
    local page, editBox = Editor("aaaaa", "aa")
    Equal(#page.SearchMatches, 2)
    page.ReplaceBox:SetText("b"); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), "bba")
end)
Test("replace all does not search newly inserted text", function()
    local page, editBox = Editor("a a", "a")
    page.ReplaceBox:SetText("aa"); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), "aa aa")
    Equal(#page.SearchMatches, 4)
end)
Test("empty query safely disables every action", function()
    local page, editBox = Editor("keep me", "")
    page:NavigateSearch(1); page:NavigateSearch(-1)
    page:ReplaceSearchMatch(); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), "keep me")
    Equal(page.SearchStatus:GetText(), "Enter search text")
    Equal(page.ReplaceButton.enabled, false)
    Equal(page.ReplaceAllButton.enabled, false)
end)
Test("no results and empty document", function()
    local page = Editor("", "missing")
    Equal(page.SearchStatus:GetText(), "No matches")
    page:NavigateSearch(-1); page:ReplaceAllSearchMatches()
    Equal(page.SearchNextButton.enabled, false)
end)
Test("changing to a missing or empty query clears the old highlight", function()
    local page, editBox = Editor("one", "one")
    page.FindBox:SetText("missing")
    Equal(editBox.highlight[1], editBox.highlight[2])
    page.FindBox:SetText("")
    Equal(page.SearchIndex, nil)
end)
Test("UTF-8 byte offsets select complete characters", function()
    local page, editBox = Editor("ž 😀 café\nž 😀", "😀")
    Equal(page.SearchMatches[1].First, #"ž ")
    Equal(editBox.highlight[2] - editBox.highlight[1], #"😀")
    Equal(editBox:GetText():sub(editBox.highlight[1] + 1, editBox.highlight[2]), "😀")
    page:NavigateSearch(1)
    Equal(page.SearchMatches[2].First, #"ž 😀 café\nž ")
    page.ReplaceBox:SetText("漢字"); page:ReplaceSearchMatch()
    Equal(editBox:GetText(), "ž 😀 café\nž 漢字")
end)
Test("UTF-8 survives case folding and replace all", function()
    local page, editBox = Editor("éLUA😀 élua😀", "élua😀")
    Equal(#page.SearchMatches, 2)
    page.ReplaceBox:SetText("ž"); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), "ž ž")
end)
Test("editing refreshes results without moving or selecting the caret", function()
    local page, editBox = Editor("one one", "one")
    editBox:SetFocus(); editBox:SetCursorPosition(0)
    editBox:Insert("one ")
    Equal(#page.SearchMatches, 3)
    Equal(page.SearchIndex, nil)
    Equal(editBox:GetCursorPosition(), 4)
    Equal(editBox.highlight, nil)
    Equal(page.ReplaceButton.enabled, false)
end)
Test("layout cursor notifications retain a selected result", function()
    local page, editBox = Editor("one one", "one")
    editBox:Fire("OnCursorChanged")
    Equal(page.SearchIndex, 1)
    Equal(page.ReplaceButton.enabled, true)
end)
Test("navigation reuses matches until the document or query changes", function()
    local page = Editor("one one", "one")
    local matches = page.SearchMatches
    page:NavigateSearch(1); page:NavigateSearch(-1)
    Equal(page.SearchMatches, matches)
end)
Test("reopening search refreshes edits made while closed", function()
    local page, editBox = Editor("one one", "one")
    page:CloseSearch()
    editBox:SetText("one one one")
    page:OpenSearch(false)
    Equal(#page.SearchMatches, 3)
    Equal(editBox:GetText(), "one one one")
end)
Test("manual mouse selection cannot replace a stale search result", function()
    local page, editBox = Editor("one one", "one")
    editBox:Fire("OnMouseDown")
    page.ReplaceBox:SetText("two"); page:ReplaceSearchMatch()
    Equal(editBox:GetText(), "one one")
end)
Test("external text changes invalidate cached replacements", function()
    local page, editBox = Editor("one one", "one")
    editBox:SetText("different")
    page:ReplaceSearchMatch()
    Equal(editBox:GetText(), "different")
    Equal(page.SearchStatus:GetText(), "No matches")
end)
Test("search retains focus while selecting and scrolling the editor", function()
    local page, editBox = Editor("one\none", "one")
    Equal(page.FindBox:HasFocus(), true)
    Equal(editBox.highlight[1], 0)
    Equal(page.InputEditor.scrolledCursor, 3)
    page.ReplaceBox:SetFocus(); page.ReplaceBox:SetText("two")
    page:ReplaceSearchMatch()
    Equal(page.ReplaceBox:HasFocus(), true)
    Equal(page.InputEditor.scrolledCursor, 7)
    Equal(editBox.highlight[1], 4)
end)
Test("replace all preserves a UTF-8-safe adjusted caret", function()
    local page, editBox = Editor("ž a 😀 a end", "a")
    editBox:SetFocus(); editBox:SetCursorPosition(#"ž a 😀 a")
    page.ReplaceBox:SetText("漢"); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), "ž 漢 😀 漢 end")
    Equal(editBox:GetCursorPosition(), #"ž 漢 😀 漢")
end)
Test("Ctrl+F and Ctrl+H open compact modes while editing", function()
    local page, editBox = Editor("keep", "")
    page:CloseSearch()
    controlDown = true
    editBox:Fire("OnKeyDown", "F")
    Equal(page.SearchBar:IsShown(), true)
    Equal(page.ReplaceRow:IsShown(), false)
    editBox:Fire("OnKeyDown", "H")
    Equal(page.ReplaceRow:IsShown(), true)
    Equal(editBox:GetText(), "keep")
    Equal(page.runs, 0)
end)
Test("Enter and Shift+Enter navigate without executing or adding newlines", function()
    local page, editBox = Editor("one one", "one")
    page.FindBox:Fire("OnEnterPressed"); Equal(page.SearchIndex, 2)
    shiftDown = true
    page.ReplaceBox:Fire("OnEnterPressed"); Equal(page.SearchIndex, 1)
    Equal(editBox:GetText(), "one one")
    Equal(page.runs, 0)
end)
Test("search fields isolate F5 and Tab from editor behavior", function()
    local page, editBox = Editor("one", "one")
    page.FindBox:Fire("OnKeyDown", "F5")
    page.ReplaceBox:Fire("OnKeyDown", "F5")
    page.FindBox:Fire("OnTabPressed"); Equal(page.ReplaceBox:HasFocus(), true)
    page.ReplaceBox:Fire("OnTabPressed"); Equal(page.FindBox:HasFocus(), true)
    Equal(page.FindBox.propagate, false)
    Equal(page.ReplaceBox.propagate, false)
    Equal(editBox:GetText(), "one")
    Equal(page.runs, 0)
end)
Test("F5 and Tab still work in Lua editor", function()
    local page, editBox = Editor("one", "")
    page:CloseSearch()
    editBox:SetCursorPosition(0)
    editBox:Fire("OnTabPressed"); Equal(editBox:GetText(), "    one")
    editBox:Fire("OnKeyDown", "F5"); Equal(page.runs, 1)
    page.Page.Frame:Fire("OnKeyDown", "F5"); Equal(page.runs, 2)
end)
Test("Escape and page hide restore layout and release search focus", function()
    local page, editBox = Editor("one", "one")
    page.FindBox:Fire("OnEscapePressed")
    Equal(page.SearchBar:IsShown(), false)
    Equal(page.InputEditor.points.TOPLEFT[4], -4)
    Equal(editBox:HasFocus(), true)
    page:OpenSearch(true)
    editBox:Fire("OnEscapePressed")
    Equal(page.SearchBar:IsShown(), false)
    page:OpenSearch(true); page.Page.Frame:Hide()
    Equal(page.SearchBar:IsShown(), false)
    Equal(page.FindBox:HasFocus(), false)
    Equal(page.Page.Frame.keyboard, false)
end)
Test("long multiline scripts navigate and replace all", function()
    local page, editBox = Editor(string.rep("local café = '😀'\n", 10000), "café")
    Equal(#page.SearchMatches, 10000)
    page:NavigateSearch(-1); Equal(page.SearchIndex, 10000)
    page.ReplaceBox:SetText("name"); page:ReplaceAllSearchMatches()
    Equal(editBox:GetText(), string.rep("local name = '😀'\n", 10000))
end)

print(string.format("%d tests passed", tests))

-- Reuse the native widget mock and fixtures for the history integration suite.
return {
    Editor = Editor,
    Test = Test,
    Equal = Equal,
    GetTestCount = function() return tests end,
    SetModifiers = function(control, shift, alt)
        controlDown, shiftDown, altDown = control, shift, alt
    end,
    AdvanceTime = function(seconds) elapsed = elapsed + seconds end,
}
