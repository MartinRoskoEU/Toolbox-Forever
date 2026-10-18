local AddonName, Toolbox = ...

Toolbox.Loaded = false

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= AddonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")

    Toolbox:Load()
end)

function Toolbox_OnAddonCompartmentClick(addonName, buttonName)    
    Toolbox:OnAddonCompartmentClick(buttonName)
end

function Toolbox:Load()
    if self.Loaded then
        return
    end

    self.Database:Initialize()
    self.Typography:Initialize()
    self.UI.MinimapButton:Initialize()
    self.Loaded = true
end

function Toolbox:OnAddonCompartmentClick(buttonName)
    if not self.Loaded then return end
    Toolbox.UI.MainWindow:Toggle()
end
