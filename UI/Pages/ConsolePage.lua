local AddonName, Toolbox = ...

local ConsolePage = {}

Toolbox.UI.ConsolePage = ConsolePage

-- Keep exported output aligned with the visible message history.
local MAX_OUTPUT_LINES = 1000

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
    self:CreateEnvironment()
    self:SetupKeyboard()
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

    self.InputEditor:RegisterCallback("OnKeyDown", function(_, _, key)
        if key == "F5" then
            self:Run()
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
        editBox:SetText("")
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
        if key == "F5" then
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
