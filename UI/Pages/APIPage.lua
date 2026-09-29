local AddonName, Toolbox = ...

local APIPage = {}

local TABLE_TYPE_LABELS = {
    Structure = "Structure",
    Enumeration = "Enumeration",
    Constants = "Constants",
    CallbackType = "Callback Type",
}

local FUNCTION_METADATA_EXCLUSIONS = {
    Name = true,
    Type = true,
    Namespace = true,
    loweredName = true,
    loweredParentName = true,
    loweredNamespaceName = true,
    Documentation = true,
    Arguments = true,
    Returns = true,
    System = true,
}

local EVENT_METADATA_EXCLUSIONS = {
    Name = true,
    LiteralName = true,
    Type = true,
    Namespace = true,
    loweredName = true,
    loweredParentName = true,
    loweredNamespaceName = true,
    Documentation = true,
    Payload = true,
    System = true,
}

local TABLE_METADATA_EXCLUSIONS = {
    Name = true,
    Type = true,
    Namespace = true,
    FullName = true,
    loweredName = true,
    loweredParentName = true,
    loweredNamespaceName = true,
    System = true,
    Documentation = true,
    Fields = true,
    Values = true,
    Arguments = true,
    Returns = true,
    Payload = true,
}

local ENUMERATION_FIELD_METADATA_KEYS = {
    "Nilable",
    "Default",
    "InnerType",
    "KeyType",
    "StrideIndex",
    "Value",
}

local function FormatDetailScalar(value)
    return value == "" and '""' or tostring(value)
end

Toolbox.UI.APIPage = APIPage

function APIPage:Initialize(parent)
    if self.Initialized then
        return
    end

    if not self.Page then
        self.Page = Toolbox.Classes.Page:New(
            parent,
            "API"
        )

        self.ErrorText = self.Page.Frame:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontHighlight"
        )

        self.ErrorText:SetPoint("TOPLEFT", self.Page.Frame, "TOPLEFT", 16, -84)
        self.ErrorText:SetPoint("TOPRIGHT", self.Page.Frame, "TOPRIGHT", -16, -84)
        self.ErrorText:SetJustifyH("LEFT")
        self.ErrorText:SetTextColor(1, 0.3, 0.3)
    end

    local documentation, errorText = self:LoadDocumentation()

    if not documentation then
        self.ErrorText:SetText(errorText)
        self.ErrorText:Show()
        return
    end

    local rows, systemCount, functionCount, eventCount, tableCount = self:BuildCatalog(documentation)

    if functionCount + eventCount + tableCount == 0 then
        self.ErrorText:SetText("No documented API entries are available.")
        self.ErrorText:Show()
        return
    end

    self.ErrorText:Hide()
    self.CatalogRows = rows
    self.CatalogSystemCount = systemCount
    self.CatalogFunctionCount = functionCount
    self.CatalogEventCount = eventCount
    self.CatalogTableCount = tableCount
    self.View = "catalog"
    self:CreateDocument()
    self:CreateSearchBox()
    self.Initialized = true
end

function APIPage:LoadDocumentation()
    local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_APIDocumentation")

    if not loaded then
        local success, reason = C_AddOns.LoadAddOn("Blizzard_APIDocumentation")

        if not success then
            return nil, "Could not load Blizzard_APIDocumentation: " .. tostring(reason)
        end
    end

    local documentation = rawget(_G, "APIDocumentation")

    if type(documentation) ~= "table" then
        return nil, "Blizzard_APIDocumentation did not provide APIDocumentation."
    end

    local _, generatedLoaded = C_AddOns.IsAddOnLoaded("Blizzard_APIDocumentationGenerated")

    if not generatedLoaded then
        local loadGenerated = rawget(_G, "APIDocumentation_LoadUI")

        if type(loadGenerated) ~= "function" or not loadGenerated() then
            return nil, "Could not load Blizzard_APIDocumentationGenerated."
        end
    end

    if type(documentation.systems) ~= "table"
        or #documentation.systems == 0 then
        return nil, "Blizzard API documentation data is unavailable."
    end

    return documentation
end

function APIPage:BuildCatalog(documentation)
    local systems = {}

    for systemIndex, system in ipairs(documentation.systems) do
        if type(system) == "table"
            and type(system.Name) == "string"
            and system.Name ~= "" then
            local functions = {}

            if type(system.Functions) == "table" then
                for functionIndex, api in ipairs(system.Functions) do
                    if type(api) == "table" and type(api.GetFullName) == "function" then
                        local ok, signature = pcall(api.GetFullName, api, false, false)

                        if ok and type(signature) == "string" and signature ~= "" then
                            local returns = {}

                            if type(api.Returns) == "table" then
                                for _, result in ipairs(api.Returns) do
                                    if type(result) == "table" then
                                        table.insert(returns,
                                            type(result.Name) == "string" and result.Name or "?"
                                        )
                                    end
                                end
                            end

                            local primaryText = signature
                            local secondaryText

                            if #returns > 0 then
                                local returnNames = table.concat(returns, ", ")
                                signature = signature .. " : " .. returnNames
                                secondaryText = returnNames
                            end

                            local name = type(api.Name) == "string" and api.Name or signature

                            table.insert(functions, {
                                kind = "function",
                                text = signature,
                                primaryText = primaryText,
                                secondaryText = secondaryText,
                                api = api,
                                searchText = string.lower(signature),
                                sortName = string.lower(name),
                                index = functionIndex,
                            })
                        end
                    end
                end
            end

            local events = {}

            if type(system.Events) == "table" then
                for eventIndex, api in ipairs(system.Events) do
                    if type(api) == "table" then
                        local name = type(api.LiteralName) == "string"
                            and api.LiteralName ~= "" and api.LiteralName
                            or api.Name

                        if type(name) == "string" and name ~= "" then
                            local payload = {}

                            if type(api.Payload) == "table" then
                                for _, field in ipairs(api.Payload) do
                                    if type(field) == "table" then
                                        local fieldName = type(field.Name) == "string" and field.Name or "?"
                                        local fieldType = type(field.Type) == "string" and field.Type or nil

                                        table.insert(payload, fieldType and fieldType ~= ""
                                            and (fieldName .. ": " .. fieldType) or fieldName)
                                    end
                                end
                            end

                            local signature = name
                            local secondaryText

                            if #payload > 0 then
                                local payloadNames = table.concat(payload, ", ")
                                signature = signature .. " : " .. payloadNames
                                secondaryText = payloadNames
                            end

                            table.insert(events, {
                                kind = "event",
                                text = signature,
                                primaryText = name,
                                secondaryText = secondaryText,
                                api = api,
                                searchText = string.lower(signature),
                                searchInternalName = type(api.Name) == "string"
                                    and string.lower(api.Name) or "",
                                sortName = string.lower(name),
                                index = eventIndex,
                            })
                        end
                    end
                end
            end

            local tables = {}

            if type(system.Tables) == "table" then
                for tableIndex, api in ipairs(system.Tables) do
                    if type(api) == "table"
                        and type(api.Name) == "string"
                        and api.Name ~= "" then
                        local rawType = api.Type

                        if rawType == nil or rawType == "" then
                            rawType = "Unknown"
                        elseif type(rawType) ~= "string" then
                            rawType = tostring(rawType)
                        end

                        local typeLabel = TABLE_TYPE_LABELS[rawType] or rawType

                        table.insert(tables, {
                            kind = "table",
                            text = api.Name,
                            tableType = typeLabel,
                            api = api,
                            searchText = string.lower(api.Name),
                            searchType = string.lower(typeLabel),
                            searchRawType = string.lower(rawType),
                            sortName = string.lower(api.Name),
                            index = tableIndex,
                        })
                    end
                end
            end

            if #functions > 0 or #events > 0 or #tables > 0 then
                table.sort(functions, function(a, b)
                    if a.sortName ~= b.sortName then
                        return a.sortName < b.sortName
                    end

                    if a.text ~= b.text then
                        return a.text < b.text
                    end

                    return a.index < b.index
                end)

                table.sort(events, function(a, b)
                    if a.sortName ~= b.sortName then
                        return a.sortName < b.sortName
                    end

                    if a.text ~= b.text then
                        return a.text < b.text
                    end

                    return a.index < b.index
                end)

                table.sort(tables, function(a, b)
                    if a.sortName ~= b.sortName then
                        return a.sortName < b.sortName
                    end

                    if a.text ~= b.text then
                        return a.text < b.text
                    end

                    if a.tableType ~= b.tableType then
                        return a.tableType < b.tableType
                    end

                    return a.index < b.index
                end)

                table.insert(systems, {
                    name = system.Name,
                    sortName = string.lower(system.Name),
                    searchNamespace = type(system.Namespace) == "string"
                        and string.lower(system.Namespace) or "",
                    index = systemIndex,
                    functions = functions,
                    events = events,
                    tables = tables,
                })
            end
        end
    end

    table.sort(systems, function(a, b)
        if a.sortName ~= b.sortName then
            return a.sortName < b.sortName
        end

        if a.name ~= b.name then
            return a.name < b.name
        end

        return a.index < b.index
    end)

    local rows = {}
    local functionCount = 0
    local eventCount = 0
    local tableCount = 0

    for index, system in ipairs(systems) do
        table.insert(rows, {
            kind = "heading",
            text = system.name,
            searchName = system.sortName,
            searchNamespace = system.searchNamespace,
            topGap = index == 1 and 0 or 22,
        })

        if #system.functions > 0 then
            table.insert(rows, {
                kind = "category",
                text = "Functions",
                topGap = 8,
            })

            for _, record in ipairs(system.functions) do
                table.insert(rows, record)
                functionCount = functionCount + 1
            end
        end

        if #system.events > 0 then
            table.insert(rows, {
                kind = "category",
                text = "Events",
                topGap = #system.functions > 0 and 14 or 8,
            })

            for _, record in ipairs(system.events) do
                table.insert(rows, record)
                eventCount = eventCount + 1
            end
        end

        if #system.tables > 0 then
            table.insert(rows, {
                kind = "category",
                text = "Tables",
                topGap = (#system.functions > 0 or #system.events > 0) and 14 or 8,
            })

            for _, record in ipairs(system.tables) do
                table.insert(rows, record)
                tableCount = tableCount + 1
            end
        end
    end

    return rows, #systems, functionCount, eventCount, tableCount
end

function APIPage:CreateDocument()
    local page = self.Page.Frame

    self.DocumentFrame = CreateFrame("Frame", nil, page, "TooltipBackdropTemplate")
    self.DocumentFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -96)
    self.DocumentFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 8)

    self.NoResultsText = self.DocumentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.NoResultsText:SetPoint("TOPLEFT", self.DocumentFrame, "TOPLEFT", 24, -24)
    self.NoResultsText:SetText("No matching API entries.")
    self.NoResultsText:Hide()

    self.DocumentScrollBox = CreateFrame("Frame", nil, self.DocumentFrame, "WowScrollBoxList")
    self.DocumentScrollBox:SetPoint("TOPLEFT", self.DocumentFrame, "TOPLEFT", 12, -12)
    self.DocumentScrollBox:SetPoint("BOTTOMRIGHT", self.DocumentFrame, "BOTTOMRIGHT", -36, 12)

    self.DocumentScrollBar = CreateFrame("EventFrame", nil, self.DocumentFrame, "MinimalScrollBar")
    self.DocumentScrollBar:SetPoint("TOPRIGHT", self.DocumentFrame, "TOPRIGHT", -10, -10)
    self.DocumentScrollBar:SetPoint("BOTTOMRIGHT", self.DocumentFrame, "BOTTOMRIGHT", -10, 10)

    self.FunctionMeasure = self.DocumentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.FunctionMeasure:SetPoint("TOPLEFT", self.DocumentFrame, "TOPLEFT")
    self.FunctionMeasure:SetAlpha(0)
    self.HeadingMeasure = self.DocumentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self.HeadingMeasure:SetPoint("TOPLEFT", self.DocumentFrame, "TOPLEFT")
    self.HeadingMeasure:SetAlpha(0)
    self.CategoryMeasure = self.DocumentFrame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    self.CategoryMeasure:SetPoint("TOPLEFT", self.DocumentFrame, "TOPLEFT")
    self.CategoryMeasure:SetAlpha(0)
    self.ListRowHeight = math.ceil(self.FunctionMeasure:GetFontHeight()) + 10
    self.HeadingRowHeight = math.ceil(self.HeadingMeasure:GetFontHeight()) + 8
    self.CategoryRowHeight = math.ceil(self.CategoryMeasure:GetFontHeight()) + 2

    local view = CreateScrollBoxListLinearView(12, 12, 12, 12, 0)
    view:SetElementExtentCalculator(function(_, record)
        return self:GetRowExtent(record)
    end)
    view:SetElementInitializer("Button", function(frame, record)
        self:InitializeRow(frame, record)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(
        self.DocumentScrollBox,
        self.DocumentScrollBar,
        view
    )

    self.DocumentView = view

    self.DocumentScrollBox:HookScript("OnSizeChanged", function()
        self:RefreshDocumentLayout()
    end)

    page:HookScript("OnShow", function()
        if self.View ~= "catalog" then
            return
        end

        self:RefreshDocumentLayout()

        if self.DocumentDataProvider then
            self.DocumentScrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
        end
    end)
end

function APIPage:CreateSearchBox()
    self.SearchBox = CreateFrame("EditBox", nil, self.Page.Frame, "SearchBoxTemplate")
    self.SearchBox:SetPoint("BOTTOMLEFT", self.DocumentFrame, "TOPLEFT", 5, 12)
    self.SearchBox:SetPoint("BOTTOMRIGHT", self.DocumentFrame, "TOPRIGHT", 0, 12)
    self.SearchBox:SetHeight(20)

    self.SearchBox:SetScript("OnTextChanged", function(editBox)
        SearchBoxTemplate_OnTextChanged(editBox)
        self:ApplySearchFilter(editBox:GetText())
    end)
end

function APIPage:ApplySearchFilter(text)
    local query = string.lower(text or "")
    local rows = self.CatalogRows

    if query ~= "" then
        local pattern = query:gsub("(%W)", "%%%1")
        rows = {}
        local heading
        local category
        local hasSystemMatch = false
        local hasCategoryMatch = false
        local categoryCount = 0
        local systemMatches = false

        for _, record in ipairs(self.CatalogRows) do
            if record.kind == "heading" then
                heading = record
                hasSystemMatch = false
                categoryCount = 0
                systemMatches = string.find(record.searchName, query, 1, true) ~= nil
                    or string.find(record.searchNamespace, query, 1, true) ~= nil
            elseif record.kind == "category" then
                category = record
                hasCategoryMatch = false
            else
                local matches = systemMatches

                if not matches then
                    if type(record.api.MatchesSearchString) == "function" then
                        local ok, nativeMatches = pcall(record.api.MatchesSearchString, record.api, pattern)
                        matches = ok and nativeMatches
                    end

                    if not matches then
                        matches = string.find(record.searchText, query, 1, true) ~= nil
                            or (record.kind == "event"
                                and string.find(record.searchInternalName, query, 1, true) ~= nil)
                            or (record.kind == "table"
                                and (string.find(record.searchType, query, 1, true) ~= nil
                                    or string.find(record.searchRawType, query, 1, true) ~= nil))
                    end
                end

                if matches then
                    if not hasSystemMatch then
                        table.insert(rows, {
                            kind = "heading",
                            text = heading.text,
                            topGap = #rows == 0 and 0 or 22,
                        })
                        hasSystemMatch = true
                    end

                    if not hasCategoryMatch then
                        table.insert(rows, {
                            kind = "category",
                            text = category.text,
                            topGap = categoryCount == 0 and 8 or 14,
                        })
                        hasCategoryMatch = true
                        categoryCount = categoryCount + 1
                    end

                    table.insert(rows, record)
                end
            end
        end
    end

    local hasResults = #rows > 0
    self.DocumentScrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
    self.DocumentDataProvider = CreateDataProvider(rows)
    self.DocumentScrollBox:SetDataProvider(
        self.DocumentDataProvider,
        ScrollBoxConstants.DiscardScrollPosition
    )

    self.NoResultsText:SetShown(not hasResults)
    self.DocumentScrollBox:SetShown(hasResults)
    self.DocumentScrollBar:SetShown(hasResults)

    if hasResults then
        self.DocumentScrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
    end
end

function APIPage:GetRowExtent(record)
    if record.kind == "heading" then
        return record.topGap + self.HeadingRowHeight
    elseif record.kind == "category" then
        return record.topGap + self.CategoryRowHeight
    end

    return self.ListRowHeight
end

function APIPage:InitializeRow(frame, record)
    if not frame.Text then
        frame.Text = frame:CreateFontString(nil, "ARTWORK")
        frame.Text:SetJustifyH("LEFT")
        frame.Text:SetWordWrap(true)
        frame.Text:SetNonSpaceWrap(true)
        frame.Text:SetMaxLines(1)

        frame.Divider = frame:CreateTexture(nil, "ARTWORK")
        frame.Divider:SetAtlas("Options_HorizontalDivider")
        frame.Divider:SetHeight(2)
    end

    local heading = record.kind == "heading"
    local category = record.kind == "category"
    local tableEntry = record.kind == "table"
    local topGap = (heading or category) and record.topGap or 6
    local leftInset = (heading or category) and 0 or 12

    if tableEntry and not frame.TypeText then
        frame.TypeText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        frame.TypeText:SetJustifyH("RIGHT")
        frame.TypeText:SetWordWrap(true)
        frame.TypeText:SetNonSpaceWrap(true)
        frame.TypeText:SetMaxLines(1)
    end

    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -topGap)

    if tableEntry then
        frame.TypeText:ClearAllPoints()
        frame.TypeText:SetWidth(self.TableTypeWidth)
        frame.TypeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -topGap)
        frame.TypeText:SetText(record.tableType)
        frame.TypeText:Show()
        frame.Text:SetPoint("TOPRIGHT", frame.TypeText, "TOPLEFT", -12, 0)
    else
        if frame.TypeText then
            frame.TypeText:Hide()
        end

        if record.kind == "function" or record.kind == "event"
            or (category and (record.text == "Functions" or record.text == "Events")) then
            frame.Text:SetWidth(self.ListPrimaryWidth)
        else
            frame.Text:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -topGap)
        end
    end

    frame.Text:SetFontObject(heading and "GameFontNormalLarge"
        or category and "GameFontDisable"
        or "GameFontHighlight")
    frame.Text:SetText(record.primaryText or record.text)

    local secondaryText = record.secondaryText

    if category and record.text == "Functions" then
        secondaryText = "Returns"
    elseif category and record.text == "Events" then
        secondaryText = "Payload"
    end

    if secondaryText then
        if not frame.SecondaryText then
            frame.SecondaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
            frame.SecondaryText:SetJustifyH("LEFT")
            frame.SecondaryText:SetWordWrap(true)
            frame.SecondaryText:SetNonSpaceWrap(true)
            frame.SecondaryText:SetMaxLines(1)
        end

        frame.SecondaryText:ClearAllPoints()
        frame.SecondaryText:SetPoint("TOPLEFT", frame, "TOPLEFT", self.ListSecondaryOffset, -topGap)
        frame.SecondaryText:SetWidth(self.ListSecondaryWidth)
        frame.SecondaryText:SetText(secondaryText)
        frame.SecondaryText:Show()
    elseif frame.SecondaryText then
        frame.SecondaryText:SetText("")
        frame.SecondaryText:Hide()
    end

    frame.Divider:ClearAllPoints()
    frame.Divider:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -4)
    frame.Divider:SetPoint("TOPRIGHT", frame.Text, "BOTTOMRIGHT", 0, -4)
    frame.Divider:SetShown(heading)

    if record.kind == "function" or record.kind == "event" or record.kind == "table" then
        if not frame.HoverTexture then
            frame.HoverTexture = frame:CreateTexture(nil, "HIGHLIGHT")
            frame.HoverTexture:SetAllPoints()
            frame.HoverTexture:SetColorTexture(1, 1, 1, 0.08)
            frame:SetHighlightTexture(frame.HoverTexture)
        end

        frame:EnableMouse(true)
        frame:SetScript("OnClick", function()
            self:ShowDetail(record.kind, record.api)
        end)
    else
        frame:SetScript("OnClick", nil)
        frame:EnableMouse(false)
    end
end

function APIPage:CreateDetail()
    local page = self.Page.Frame

    self.BackButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.BackButton:SetSize(136, 24)
    self.BackButton:SetPoint("BOTTOMLEFT", self.DocumentFrame, "TOPLEFT", 0, 10)
    self.BackButton:SetText("BACK TO LIST")
    self.BackButton:SetScript("OnClick", function()
        self:ShowCatalog()
    end)
    self.BackButton:Hide()

    self.DetailFrame = CreateFrame("Frame", nil, page, "TooltipBackdropTemplate")
    self.DetailFrame:SetAllPoints(self.DocumentFrame)

    self.DetailScrollFrame = CreateFrame("ScrollFrame", nil, self.DetailFrame, "ScrollFrameTemplate")
    self.DetailScrollFrame:SetPoint("TOPLEFT", self.DetailFrame, "TOPLEFT", 12, -12)
    self.DetailScrollFrame:SetPoint("BOTTOMRIGHT", self.DetailFrame, "BOTTOMRIGHT", -36, 12)

    self.DetailContent = CreateFrame("Frame", nil, self.DetailScrollFrame)
    self.DetailContent:SetSize(1, 1)
    self.DetailScrollFrame:SetScrollChild(self.DetailContent)

    self.DetailTexts = {}
    self.DetailDividers = {}
    self.DetailRows = {}
    self.DetailFrame:Hide()

    self.DetailScrollFrame:HookScript("OnSizeChanged", function()
        if self.SelectedAPI then
            self:RenderSelectedDetail()
        end
    end)
end

function APIPage:ShowDetail(kind, api)
    if type(api) ~= "table" or (kind ~= "function" and kind ~= "event" and kind ~= "table") then
        return
    end

    if not self.DetailFrame then
        self:CreateDetail()
    end

    if self.TableGridFrame then
        self.TableGridFrame:Hide()
    end

    self.CatalogScrollPercentage = self.DocumentScrollBox:GetScrollPercentage()
    self.SelectedAPI = api
    self.View = kind

    self.SearchBox:ClearFocus()
    self.SearchBox:Hide()
    self.DocumentFrame:Hide()
    self.BackButton:Show()
    self.DetailFrame:Show()

    self:RenderSelectedDetail()
    self.DetailScrollFrame:SetVerticalScroll(0)
end

function APIPage:RenderSelectedDetail()
    if self.View == "function" then
        self:RenderFunctionDetail()
    elseif self.View == "event" then
        self:RenderEventDetail()
    elseif self.View == "table" then
        self:RenderTableDetail()
    end
end

function APIPage:ShowCatalog()
    if self.View ~= "function" and self.View ~= "event" and self.View ~= "table" then
        return
    end

    self.View = "catalog"
    self.SelectedAPI = nil
    self.DetailFrame:Hide()
    self.BackButton:Hide()
    self.DocumentFrame:Show()
    self.SearchBox:Show()

    self.DocumentScrollBox:SetScrollPercentage(
        self.CatalogScrollPercentage or 0,
        ScrollBoxConstants.NoScrollInterpolation
    )
    self.CatalogScrollPercentage = nil
end

function APIPage:AddDetailText(text, font, gap, indent)
    self.DetailCursor = self.DetailCursor + (gap or 0)
    self.DetailTextCount = self.DetailTextCount + 1

    local label = self.DetailTexts[self.DetailTextCount]

    if not label then
        label = self.DetailContent:CreateFontString(nil, "ARTWORK")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetNonSpaceWrap(true)
        self.DetailTexts[self.DetailTextCount] = label
    end

    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", self.DetailContent, "TOPLEFT", indent, -self.DetailCursor)
    label:SetWidth(math.max(self.DetailContentWidth - indent - 12, 1))
    label:SetFontObject(font)
    label:SetText(text)
    label:Show()

    self.DetailCursor = self.DetailCursor + math.ceil(label:GetStringHeight())
end

function APIPage:AddDetailSection(title)
    self:AddDetailText(title, "GameFontNormal", 16, 12)
    self.DetailCursor = self.DetailCursor + 4
    self.DetailDividerCount = self.DetailDividerCount + 1

    local divider = self.DetailDividers[self.DetailDividerCount]

    if not divider then
        divider = self.DetailContent:CreateTexture(nil, "ARTWORK")
        divider:SetAtlas("Options_HorizontalDivider")
        divider:SetHeight(2)
        self.DetailDividers[self.DetailDividerCount] = divider
    end

    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", self.DetailContent, "TOPLEFT", 12, -self.DetailCursor)
    divider:SetPoint("TOPRIGHT", self.DetailContent, "TOPRIGHT", -12, -self.DetailCursor)
    divider:Show()
    self.DetailCursor = self.DetailCursor + 8
end

function APIPage:AddDetailColumns(name, value, secondaryLines, eventPayload)
    self.DetailCursor = self.DetailCursor + (eventPayload and 6 or 8)
    self.DetailRowCount = self.DetailRowCount + 1

    local row = self.DetailRows[self.DetailRowCount]

    if not row then
        row = {
            Name = self.DetailContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight"),
            Value = self.DetailContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight"),
            Secondary = self.DetailContent:CreateFontString(nil, "ARTWORK", "GameFontDisable"),
        }

        row.Name:SetJustifyH("LEFT")
        row.Name:SetWordWrap(true)
        row.Name:SetNonSpaceWrap(true)
        row.Value:SetJustifyH("LEFT")
        row.Value:SetWordWrap(true)
        row.Value:SetNonSpaceWrap(true)
        row.Value:SetTextColor(0.8, 0.8, 0.8)
        row.Secondary:SetJustifyH("LEFT")
        row.Secondary:SetWordWrap(true)
        row.Secondary:SetNonSpaceWrap(true)
        self.DetailRows[self.DetailRowCount] = row
    end

    local leftWidth = math.min(260, math.max(math.floor((self.DetailContentWidth - 24) * 0.34), 1))
    local rightX = 12 + leftWidth + 12
    local rightWidth = math.max(self.DetailContentWidth - rightX - 12, 1)

    row.Name:ClearAllPoints()
    row.Name:SetPoint("TOPLEFT", self.DetailContent, "TOPLEFT", 12, -self.DetailCursor)
    row.Name:SetWidth(leftWidth)
    row.Name:SetText(name)
    row.Name:Show()

    row.Value:ClearAllPoints()
    row.Value:SetPoint("TOPLEFT", self.DetailContent, "TOPLEFT", rightX, -self.DetailCursor)
    row.Value:SetWidth(rightWidth)
    row.Value:SetText(value)
    row.Value:Show()

    local nameHeight = math.ceil(row.Name:GetStringHeight())
    local valueHeight = math.ceil(row.Value:GetStringHeight())

    if secondaryLines and #secondaryLines > 0 then
        row.Secondary:ClearAllPoints()
        if eventPayload then
            row.Secondary:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 8, -2)
            row.Secondary:SetWidth(math.max(leftWidth - 8, 1))
        else
            row.Secondary:SetPoint("TOPLEFT", self.DetailContent, "TOPLEFT",
                rightX, -(self.DetailCursor + math.max(nameHeight, valueHeight) + 3))
            row.Secondary:SetWidth(rightWidth)
        end

        row.Secondary:SetText(table.concat(secondaryLines, "\n"))
        row.Secondary:Show()

        local secondaryHeight = math.ceil(row.Secondary:GetStringHeight())

        if eventPayload then
            self.DetailCursor = self.DetailCursor + math.max(
                nameHeight + 2 + secondaryHeight,
                valueHeight
            )
        else
            self.DetailCursor = self.DetailCursor + math.max(nameHeight, valueHeight) + 3 + secondaryHeight
        end
    else
        row.Secondary:Hide()
        self.DetailCursor = self.DetailCursor + math.max(nameHeight, valueHeight)
    end
end

function APIPage:GetTableGridColumns(nameFraction, typeFraction, documentationX)
    local contentWidth = math.max(self.DetailContentWidth - 24, 1)
    local gap = 12
    local columnWidth = math.max(contentWidth - 2 * gap, 3)
    local nameWidth = math.max(math.floor(columnWidth * nameFraction), 1)
    local typeWidth = math.max(math.floor(columnWidth * typeFraction), 1)

    return {
        nameWidth = nameWidth,
        typeX = 12 + nameWidth + gap,
        typeWidth = typeWidth,
        thirdX = 12 + nameWidth + gap + typeWidth + gap,
        thirdWidth = math.max(columnWidth - nameWidth - typeWidth, 1),
        documentationX = documentationX,
        documentationWidth = math.max(self.DetailContentWidth - documentationX - 12, 1),
    }
end

function APIPage:AddTableGridRow(name, typeText, thirdText, documentation, isHeader, columns)
    if not self.TableGridFrame then
        self.TableGridFrame = CreateFrame("Frame", nil, self.DetailContent)
        self.TableGridFrame:SetAllPoints(self.DetailContent)
        self.TableGridRows = {}
    end

    self.TableGridRowCount = self.TableGridRowCount + 1
    local row = self.TableGridRows[self.TableGridRowCount]

    if not row then
        row = {
            Name = self.TableGridFrame:CreateFontString(nil, "ARTWORK"),
            Type = self.TableGridFrame:CreateFontString(nil, "ARTWORK"),
            Third = self.TableGridFrame:CreateFontString(nil, "ARTWORK"),
            Documentation = self.TableGridFrame:CreateFontString(nil, "ARTWORK", "GameFontDisable"),
        }

        for _, label in ipairs({ row.Name, row.Type, row.Third, row.Documentation }) do
            label:SetJustifyH("LEFT")
            label:SetWordWrap(true)
            label:SetNonSpaceWrap(true)
        end

        self.TableGridRows[self.TableGridRowCount] = row
    end

    local font = isHeader and "GameFontDisable" or "GameFontHighlight"
    self.DetailCursor = self.DetailCursor + (isHeader and 2 or 8)

    row.Name:SetFontObject(font)
    row.Name:ClearAllPoints()
    row.Name:SetPoint("TOPLEFT", self.TableGridFrame, "TOPLEFT", 12, -self.DetailCursor)
    row.Name:SetWidth(columns.nameWidth)
    row.Name:SetText(name)
    row.Name:Show()

    row.Type:SetFontObject(font)
    row.Type:ClearAllPoints()
    row.Type:SetPoint("TOPLEFT", self.TableGridFrame, "TOPLEFT", columns.typeX, -self.DetailCursor)
    row.Type:SetWidth(columns.typeWidth)
    row.Type:SetText(typeText)
    row.Type:Show()

    row.Third:SetFontObject(font)
    row.Third:ClearAllPoints()
    row.Third:SetPoint("TOPLEFT", self.TableGridFrame, "TOPLEFT", columns.thirdX, -self.DetailCursor)
    row.Third:SetWidth(columns.thirdWidth)
    row.Third:SetText(thirdText)
    row.Third:Show()

    local nameHeight = math.ceil(row.Name:GetStringHeight())
    local typeHeight = math.ceil(row.Type:GetStringHeight())
    local thirdHeight = math.ceil(row.Third:GetStringHeight())
    local mainHeight = math.max(nameHeight, typeHeight, thirdHeight)

    if documentation and #documentation > 0 then
        row.Documentation:ClearAllPoints()

        if columns.documentationUnderName then
            row.Documentation:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", columns.documentationX - 12, -3)
        else
            row.Documentation:SetPoint("TOPLEFT", self.TableGridFrame, "TOPLEFT",
                columns.documentationX, -(self.DetailCursor + mainHeight + 3))
        end

        row.Documentation:SetWidth(columns.documentationWidth)
        row.Documentation:SetText(table.concat(documentation, "\n"))
        row.Documentation:Show()

        local documentationHeight = math.ceil(row.Documentation:GetStringHeight())

        if columns.documentationUnderName then
            self.DetailCursor = self.DetailCursor + math.max(
                nameHeight + 3 + documentationHeight,
                typeHeight,
                thirdHeight
            )
        else
            self.DetailCursor = self.DetailCursor + mainHeight + 3 + documentationHeight
        end
    else
        row.Documentation:Hide()
        self.DetailCursor = self.DetailCursor + mainHeight
    end
end

function APIPage:AddDetailField(field, detailedField)
    if type(field) ~= "table" then
        return
    end

    local formatValue = detailedField and FormatDetailScalar or tostring
    local name = type(field.Name) == "string" and field.Name or "?"
    local fieldType = field.Type ~= nil and formatValue(field.Type) or ""
    local lines = {}

    if field.Nilable == true then
        table.insert(lines, "Optional")
    elseif detailedField and field.Nilable == false then
        table.insert(lines, "Nilable: false")
    end

    if field.Default ~= nil then
        local default = field.Default

        if default == "" then
            default = '""'
        end

        table.insert(lines, "Default: " .. tostring(default))
    end

    if field.InnerType ~= nil then
        table.insert(lines, "Inner type: " .. formatValue(field.InnerType))
    end

    if field.KeyType ~= nil then
        table.insert(lines, "Key type: " .. formatValue(field.KeyType))
    end

    if field.StrideIndex ~= nil then
        table.insert(lines, "Stride index: " .. formatValue(field.StrideIndex))
    end

    if detailedField and field.EnumValue ~= nil then
        table.insert(lines, "Enum value: " .. formatValue(field.EnumValue))
    end

    if type(field.Documentation) == "table" then
        for _, line in ipairs(field.Documentation) do
            if type(line) == "string" and line ~= "" then
                table.insert(lines, "Documentation: " .. line)
            end
        end
    elseif type(field.Documentation) == "string" and field.Documentation ~= "" then
        table.insert(lines, "Documentation: " .. field.Documentation)
    end

    self:AddDetailColumns(name, fieldType, lines)
end

function APIPage:RenderFunctionDetail()
    if self.DetailRendering or not self.SelectedAPI then
        return
    end

    local width = self.DetailScrollFrame:GetWidth()

    if width <= 0 then
        return
    end

    self.DetailRendering = true
    self.DetailContentWidth = width
    self.DetailContent:SetWidth(width)
    self.DetailCursor = 0
    self.DetailTextCount = 0
    self.DetailDividerCount = 0
    self.DetailRowCount = 0

    local api = self.SelectedAPI
    local system = type(api.System) == "table" and api.System or nil
    local name = type(api.Name) == "string" and api.Name ~= "" and api.Name or "Unknown Function"
    local namespace = system and type(system.Namespace) == "string" and system.Namespace or nil
    local title = namespace and namespace ~= "" and (namespace .. "." .. name) or name

    local context = { "Function" }

    if system and type(system.Name) == "string" and system.Name ~= "" then
        table.insert(context, system.Name)
    end

    if namespace and namespace ~= "" then
        table.insert(context, namespace)
    end

    self:AddDetailText(title, "GameFontNormalLarge", 14, 12)
    self:AddDetailText(table.concat(context, " · "), "GameFontDisable", 5, 12)

    local signature = title

    if type(api.GetFullName) == "function" then
        local ok, fullName = pcall(api.GetFullName, api, false, false)

        if ok and type(fullName) == "string" and fullName ~= "" then
            signature = fullName
        end
    end

    self:AddDetailText(signature, "GameFontHighlightLarge", 12, 12)

    if type(api.Documentation) == "table" then
        local hasDocumentation = false

        for _, line in ipairs(api.Documentation) do
            if type(line) == "string" and line ~= "" then
                if not hasDocumentation then
                    self:AddDetailSection("Documentation")
                    hasDocumentation = true
                end

                self:AddDetailText(line, "GameFontHighlight", 6, 12)
            end
        end
    end

    if type(api.Arguments) == "table" and #api.Arguments > 0 then
        self:AddDetailSection("Arguments")

        for _, field in ipairs(api.Arguments) do
            self:AddDetailField(field)
        end
    end

    if type(api.Returns) == "table" and #api.Returns > 0 then
        self:AddDetailSection("Returns")

        for _, field in ipairs(api.Returns) do
            self:AddDetailField(field)
        end
    end

    local metadataKeys = {}

    for key, value in pairs(api) do
        local valueType = type(value)

        if type(key) == "string"
            and not FUNCTION_METADATA_EXCLUSIONS[key]
            and (valueType == "boolean" or valueType == "number" or valueType == "string") then
            table.insert(metadataKeys, key)
        end
    end

    if #metadataKeys > 0 then
        table.sort(metadataKeys)
        self:AddDetailSection("Metadata")

        for _, key in ipairs(metadataKeys) do
            self:AddDetailColumns(key, tostring(api[key]))
        end
    end

    for index = self.DetailTextCount + 1, #self.DetailTexts do
        self.DetailTexts[index]:Hide()
    end

    for index = self.DetailDividerCount + 1, #self.DetailDividers do
        self.DetailDividers[index]:Hide()
    end

    for index = self.DetailRowCount + 1, #self.DetailRows do
        local row = self.DetailRows[index]
        row.Name:Hide()
        row.Value:Hide()
        row.Secondary:Hide()
    end

    self.DetailContent:SetHeight(math.max(self.DetailCursor + 24, self.DetailScrollFrame:GetHeight()))
    self.DetailRendering = false
end

function APIPage:RenderEventDetail()
    if self.DetailRendering or not self.SelectedAPI then
        return
    end

    local width = self.DetailScrollFrame:GetWidth()

    if width <= 0 then
        return
    end

    self.DetailRendering = true
    self.DetailContentWidth = width
    self.DetailContent:SetWidth(width)
    self.DetailCursor = 0
    self.DetailTextCount = 0
    self.DetailDividerCount = 0
    self.DetailRowCount = 0

    local api = self.SelectedAPI
    local system = type(api.System) == "table" and api.System or nil
    local name = type(api.Name) == "string" and api.Name ~= "" and api.Name or "Unknown Event"
    local literalName = type(api.LiteralName) == "string" and api.LiteralName ~= ""
        and api.LiteralName or name
    local namespace = system and type(system.Namespace) == "string" and system.Namespace or nil
    local context = { "Event" }

    if system and type(system.Name) == "string" and system.Name ~= "" then
        table.insert(context, system.Name)
    end

    if namespace and namespace ~= "" then
        table.insert(context, namespace)
    end

    self:AddDetailText(literalName, "GameFontNormalLarge", 14, 12)
    self:AddDetailText(table.concat(context, " · "), "GameFontDisable", 5, 12)
    self:AddDetailSection("API Name")
    self:AddDetailText(name, "GameFontHighlight", 6, 12)

    if type(api.Payload) == "table" then
        local hasPayload = false

        for _, field in ipairs(api.Payload) do
            if type(field) == "table" then
                if not hasPayload then
                    self:AddDetailSection("Payload")
                    hasPayload = true
                end

                local fieldName = type(field.Name) == "string" and field.Name or "?"
                local fieldType = field.Type ~= nil and FormatDetailScalar(field.Type) or ""
                local secondaryLines = {}

                if type(field.Documentation) == "table" then
                    for _, line in ipairs(field.Documentation) do
                        if type(line) == "string" and line ~= "" then
                            table.insert(secondaryLines, line)
                        end
                    end
                elseif type(field.Documentation) == "string" and field.Documentation ~= "" then
                    table.insert(secondaryLines, field.Documentation)
                end

                if field.Nilable == true then
                    table.insert(secondaryLines, "Nilable: true")
                end

                if field.Default ~= nil then
                    table.insert(secondaryLines, "Default: " .. FormatDetailScalar(field.Default))
                end

                if field.InnerType ~= nil then
                    table.insert(secondaryLines, "Inner type: " .. FormatDetailScalar(field.InnerType))
                end

                if field.KeyType ~= nil then
                    table.insert(secondaryLines, "Key type: " .. FormatDetailScalar(field.KeyType))
                end

                if field.StrideIndex ~= nil then
                    table.insert(secondaryLines, "Stride index: " .. FormatDetailScalar(field.StrideIndex))
                end

                if field.EnumValue ~= nil then
                    table.insert(secondaryLines, "Enum value: " .. FormatDetailScalar(field.EnumValue))
                end

                self:AddDetailColumns(fieldName, fieldType, secondaryLines, true)
            end
        end
    end

    if type(api.Documentation) == "table" then
        local hasDocumentation = false

        for _, line in ipairs(api.Documentation) do
            if type(line) == "string" and line ~= "" then
                if not hasDocumentation then
                    self:AddDetailSection("Documentation")
                    hasDocumentation = true
                end

                self:AddDetailText(line, "GameFontHighlight", 6, 12)
            end
        end
    elseif type(api.Documentation) == "string" and api.Documentation ~= "" then
        self:AddDetailSection("Documentation")
        self:AddDetailText(api.Documentation, "GameFontHighlight", 6, 12)
    end

    local metadataKeys = {}

    for key, value in pairs(api) do
        local valueType = type(value)

        if type(key) == "string"
            and not EVENT_METADATA_EXCLUSIONS[key]
            and (valueType == "boolean" or valueType == "number" or valueType == "string") then
            table.insert(metadataKeys, key)
        end
    end

    if #metadataKeys > 0 then
        table.sort(metadataKeys)
        self:AddDetailSection("Metadata")

        for _, key in ipairs(metadataKeys) do
            local value = api[key]
            self:AddDetailColumns(key, FormatDetailScalar(value))
        end
    end

    for index = self.DetailTextCount + 1, #self.DetailTexts do
        self.DetailTexts[index]:Hide()
    end

    for index = self.DetailDividerCount + 1, #self.DetailDividers do
        self.DetailDividers[index]:Hide()
    end

    for index = self.DetailRowCount + 1, #self.DetailRows do
        local row = self.DetailRows[index]
        row.Name:Hide()
        row.Value:Hide()
        row.Secondary:Hide()
    end

    self.DetailContent:SetHeight(math.max(self.DetailCursor + 24, self.DetailScrollFrame:GetHeight()))
    self.DetailRendering = false
end

function APIPage:RenderTableDetail()
    if self.DetailRendering or not self.SelectedAPI then
        return
    end

    local width = self.DetailScrollFrame:GetWidth()

    if width <= 0 then
        return
    end

    self.DetailRendering = true
    self.DetailContentWidth = width
    self.DetailContent:SetWidth(width)
    self.DetailCursor = 0
    self.DetailTextCount = 0
    self.DetailDividerCount = 0
    self.DetailRowCount = 0
    self.TableGridRowCount = 0

    if self.TableGridFrame then
        self.TableGridFrame:Hide()

        for _, row in ipairs(self.TableGridRows) do
            row.Name:Hide()
            row.Type:Hide()
            row.Third:Hide()
            row.Documentation:Hide()
        end
    end

    local api = self.SelectedAPI
    local name = type(api.Name) == "string" and api.Name ~= "" and api.Name or "Unknown Table"
    local rawType = type(api.Type) == "string" and api.Type ~= "" and api.Type or "Unknown"
    local typeLabel = TABLE_TYPE_LABELS[rawType] or rawType
    local system = type(api.System) == "table" and api.System or nil
    local namespace = system and type(system.Namespace) == "string" and system.Namespace or nil
    local context = { typeLabel }

    if system and type(system.Name) == "string" and system.Name ~= "" then
        table.insert(context, system.Name)
    end

    if namespace and namespace ~= "" then
        table.insert(context, namespace)
    end

    self:AddDetailText(name, "GameFontNormalLarge", 14, 12)
    self:AddDetailText(table.concat(context, " · "), "GameFontDisable", 5, 12)

    if type(api.GetFullName) == "function" then
        local ok, fullName = pcall(api.GetFullName, api)

        if ok and type(fullName) == "string" and fullName ~= "" and fullName ~= name then
            self:AddDetailSection("Full Name")
            self:AddDetailText(fullName, "GameFontHighlight", 6, 12)
        end
    end

    if type(api.Documentation) == "table" then
        local hasDocumentation = false

        for _, line in ipairs(api.Documentation) do
            if type(line) == "string" and line ~= "" then
                if not hasDocumentation then
                    self:AddDetailSection("Documentation")
                    hasDocumentation = true
                end

                self:AddDetailText(line, "GameFontHighlight", 6, 12)
            end
        end
    elseif type(api.Documentation) == "string" and api.Documentation ~= "" then
        self:AddDetailSection("Documentation")
        self:AddDetailText(api.Documentation, "GameFontHighlight", 6, 12)
    end

    if rawType == "Structure" and type(api.Fields) == "table" then
        local hasFields = false
        local columns = self:GetTableGridColumns(0.31, 0.27, 20)
        columns.documentationWidth = math.max(columns.typeX - columns.documentationX - 12, 1)
        columns.documentationUnderName = true

        if self.TableGridFrame then
            self.TableGridFrame:Show()
        end

        for _, field in ipairs(api.Fields) do
            if type(field) == "table" then
                if not hasFields then
                    self:AddDetailSection("Fields")
                    self:AddTableGridRow("Name", "Type", "Properties", nil, true, columns)
                    hasFields = true
                end

                local fieldName = type(field.Name) == "string"
                    and FormatDetailScalar(field.Name) or "?"
                local fieldType = field.Type ~= nil and FormatDetailScalar(field.Type) or ""
                local properties = {}
                local documentation = {}

                if field.Nilable == true then
                    table.insert(properties, "Optional")
                elseif field.Nilable == false then
                    table.insert(properties, "Nilable: false")
                end

                if field.Default ~= nil then
                    table.insert(properties, "Default: " .. FormatDetailScalar(field.Default))
                end

                if field.InnerType ~= nil then
                    table.insert(properties, "Inner type: " .. FormatDetailScalar(field.InnerType))
                end

                if field.KeyType ~= nil then
                    table.insert(properties, "Key type: " .. FormatDetailScalar(field.KeyType))
                end

                if field.StrideIndex ~= nil then
                    table.insert(properties, "Stride index: " .. FormatDetailScalar(field.StrideIndex))
                end

                if field.EnumValue ~= nil then
                    table.insert(properties, "Enum value: " .. FormatDetailScalar(field.EnumValue))
                end

                if type(field.Documentation) == "table" then
                    for _, line in ipairs(field.Documentation) do
                        if type(line) == "string" and line ~= "" then
                            table.insert(documentation, line)
                        end
                    end
                elseif type(field.Documentation) == "string" and field.Documentation ~= "" then
                    table.insert(documentation, field.Documentation)
                end

                self:AddTableGridRow(
                    fieldName,
                    fieldType,
                    table.concat(properties, "\n"),
                    documentation,
                    false,
                    columns
                )
            end
        end
    elseif rawType == "Enumeration" and type(api.Fields) == "table" then
        local hasValues = false

        for _, field in ipairs(api.Fields) do
            if type(field) == "table" then
                if not hasValues then
                    self:AddDetailSection("Values")
                    hasValues = true
                end

                local fieldName = type(field.Name) == "string"
                    and FormatDetailScalar(field.Name) or "?"
                local enumValueType = type(field.EnumValue)
                local enumValue = (enumValueType == "string" or enumValueType == "number"
                    or enumValueType == "boolean") and FormatDetailScalar(field.EnumValue) or ""
                local secondary = {}

                if field.Type ~= nil and field.Type ~= name then
                    local fieldType = type(field.Type)

                    if fieldType == "string" or fieldType == "number" or fieldType == "boolean" then
                        table.insert(secondary, "Type: " .. FormatDetailScalar(field.Type))
                    end
                end

                for _, key in ipairs(ENUMERATION_FIELD_METADATA_KEYS) do
                    local value = field[key]
                    local valueType = type(value)

                    if valueType == "string" or valueType == "number" or valueType == "boolean" then
                        table.insert(secondary, key .. ": " .. FormatDetailScalar(value))
                    end
                end

                if type(field.Documentation) == "table" then
                    for _, line in ipairs(field.Documentation) do
                        if type(line) == "string" and line ~= "" then
                            table.insert(secondary, "Documentation: " .. line)
                        end
                    end
                elseif type(field.Documentation) == "string" and field.Documentation ~= "" then
                    table.insert(secondary, "Documentation: " .. field.Documentation)
                end

                self:AddDetailColumns(fieldName, enumValue, secondary)
            end
        end
    elseif rawType == "Constants" and type(api.Values) == "table" then
        local hasValues = false

        if self.TableGridFrame then
            self.TableGridFrame:Show()
        end

        local columns = self:GetTableGridColumns(0.68, 0.14, 12)

        for _, constant in ipairs(api.Values) do
            if type(constant) == "table" then
                if not hasValues then
                    self:AddDetailSection("Values")
                    self:AddTableGridRow("Name", "Type", "Value", nil, true, columns)
                    hasValues = true
                end

                local constantName = type(constant.Name) == "string"
                    and FormatDetailScalar(constant.Name) or "?"
                local constantType = type(constant.Type)
                local typeText = (constantType == "string" or constantType == "number"
                    or constantType == "boolean") and FormatDetailScalar(constant.Type) or ""
                local valueType = type(constant.Value)
                local valueText = (valueType == "string" or valueType == "number"
                    or valueType == "boolean") and FormatDetailScalar(constant.Value) or ""
                local documentation = {}

                if type(constant.Documentation) == "table" then
                    for _, line in ipairs(constant.Documentation) do
                        if type(line) == "string" and line ~= "" then
                            table.insert(documentation, line)
                        end
                    end
                elseif type(constant.Documentation) == "string" and constant.Documentation ~= "" then
                    table.insert(documentation, constant.Documentation)
                end

                self:AddTableGridRow(constantName, typeText, valueText, documentation, false, columns)
            end
        end
    elseif rawType == "CallbackType" and type(api.Arguments) == "table" then
        local hasArguments = false

        for _, field in ipairs(api.Arguments) do
            if type(field) == "table" then
                if not hasArguments then
                    self:AddDetailSection("Arguments")
                    hasArguments = true
                end

                self:AddDetailField(field, true)
            end
        end
    end

    local metadataKeys = {}

    for key, value in pairs(api) do
        local valueType = type(value)

        if type(key) == "string"
            and not TABLE_METADATA_EXCLUSIONS[key]
            and (valueType == "boolean" or valueType == "number" or valueType == "string") then
            table.insert(metadataKeys, key)
        end
    end

    if #metadataKeys > 0 then
        table.sort(metadataKeys)
        self:AddDetailSection("Metadata")

        for _, key in ipairs(metadataKeys) do
            self:AddDetailColumns(key, FormatDetailScalar(api[key]))
        end
    end

    for index = self.DetailTextCount + 1, #self.DetailTexts do
        self.DetailTexts[index]:Hide()
    end

    for index = self.DetailDividerCount + 1, #self.DetailDividers do
        self.DetailDividers[index]:Hide()
    end

    for index = self.DetailRowCount + 1, #self.DetailRows do
        local row = self.DetailRows[index]
        row.Name:Hide()
        row.Value:Hide()
        row.Secondary:Hide()
    end

    self.DetailContent:SetHeight(math.max(self.DetailCursor + 24, self.DetailScrollFrame:GetHeight()))
    self.DetailRendering = false
end

function APIPage:RefreshDocumentLayout()
    if self.LayoutRefreshing or not self.Page.Frame:IsVisible() then
        return
    end

    local width = self.DocumentScrollBox:GetWidth()

    if width <= 0 then
        return
    end

    local textWidth = math.max(width - 24, 1)

    if textWidth == self.MeasurementWidth and self.DocumentDataProvider then
        return
    end

    self.LayoutRefreshing = true
    self.MeasurementWidth = textWidth
    local listEntryWidth = math.max(textWidth - 12, 1)
    self.ListPrimaryWidth = math.max(math.floor((listEntryWidth - 12) * 0.62), 1)
    self.ListSecondaryOffset = 24 + self.ListPrimaryWidth
    self.ListSecondaryWidth = math.max(listEntryWidth - self.ListPrimaryWidth - 12, 1)
    local tableEntryWidth = math.max(textWidth - 12, 1)
    self.TableTypeWidth = math.min(140, math.max(math.floor(tableEntryWidth / 3), 1))

    if not self.DocumentDataProvider then
        self.DocumentDataProvider = CreateDataProvider(self.CatalogRows)
        self.DocumentScrollBox:SetDataProvider(
            self.DocumentDataProvider,
            ScrollBoxConstants.DiscardScrollPosition
        )
    else
        self.DocumentScrollBox:ForEachFrame(function(frame, record)
            self:InitializeRow(frame, record)
        end)

        self.DocumentView:ClearElementExtentData()
        self.DocumentScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end

    self.LayoutRefreshing = false
end
