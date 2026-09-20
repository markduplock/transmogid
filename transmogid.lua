local addonName = ...
local TransmogID = CreateFrame("Frame")

-- Inspection state: used to match an INSPECT_READY event to the target we asked
-- the game to inspect, and to avoid sending inspect requests too frequently.
local pendingGUID
local lastInspectRequest = 0
local INSPECT_COOLDOWN_SECONDS = 2

-- Position settings for the icon relative to the standard target frame.
local DEFAULT_ICON_X_OFFSET = -24
local MIN_ICON_X_OFFSET = -200
local MAX_ICON_X_OFFSET = 0
local ICON_Y_OFFSET = -8
local iconXOffset = DEFAULT_ICON_X_OFFSET

-- The small wardrobe icon displayed over TargetFrame when transmog is found.
local icon = CreateFrame("Frame", addonName .. "TargetIcon", TargetFrame)
icon:SetSize(18, 18)
icon:SetFrameStrata("MEDIUM")
icon:Hide()

-- Re-anchor the icon after its X offset changes or saved settings are loaded.
local function positionIcon()
    icon:ClearAllPoints()
    icon:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", iconXOffset, ICON_Y_OFFSET)
end

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetAllPoints()
texture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\transmog-wardrobe")

local border = icon:CreateTexture(nil, "OVERLAY")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

-- A fixed settings panel opened by /tmid. It is separate from the target icon
-- so moving the icon does not make the slider difficult to use.
local optionsMenu = CreateFrame("Frame", addonName .. "OptionsMenu", UIParent)
optionsMenu:SetSize(250, 104)
optionsMenu:SetFrameStrata("DIALOG")
optionsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
optionsMenu:Hide()

local menuBackground = optionsMenu:CreateTexture(nil, "BACKGROUND")
menuBackground:SetAllPoints()
menuBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

local menuTitle = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
menuTitle:SetPoint("TOP", 0, -10)
menuTitle:SetText("Transmog ID position")

local positionLabel = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
positionLabel:SetPoint("BOTTOM", 0, 38)

local positionSlider = CreateFrame("Slider", nil, optionsMenu)
positionSlider:SetPoint("TOPLEFT", 18, -30)
positionSlider:SetPoint("TOPRIGHT", -18, -30)
positionSlider:SetHeight(16)
positionSlider:SetOrientation("HORIZONTAL")
positionSlider:SetMinMaxValues(MIN_ICON_X_OFFSET, MAX_ICON_X_OFFSET)
positionSlider:SetValueStep(1)
if positionSlider.SetObeyStepOnDrag then
    positionSlider:SetObeyStepOnDrag(true)
end
positionSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

local sliderTrack = positionSlider:CreateTexture(nil, "BACKGROUND")
sliderTrack:SetPoint("LEFT")
sliderTrack:SetPoint("RIGHT")
sliderTrack:SetHeight(8)
sliderTrack:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")

positionSlider:SetScript("OnValueChanged", function(_, value)
    -- Update the icon immediately so the slider acts as a live preview.
    iconXOffset = value
    positionIcon()
    positionLabel:SetText(("Horizontal position: %d"):format(value))
end)

local savePositionButton = CreateFrame("Button", nil, optionsMenu, "UIPanelButtonTemplate")
savePositionButton:SetSize(110, 22)
savePositionButton:SetPoint("BOTTOM", 0, 10)
savePositionButton:SetText("Save position")
savePositionButton:SetScript("OnClick", function()
    -- TransmogIDDB is the account-wide table declared in TransmogID.toc.
    -- WoW writes it to disk on reload, logout, or client exit.
    if type(TransmogIDDB) ~= "table" then
        TransmogIDDB = {}
    end

    TransmogIDDB.iconXOffset = iconXOffset
    optionsMenu:Hide()
end)

-- Load the saved position after WoW has made SavedVariables available. Invalid
-- or missing values fall back to the default, while old out-of-range values are
-- kept within the slider's current limits.
local function loadSavedPosition()
    local savedOffset
    if type(TransmogIDDB) == "table" then
        savedOffset = TransmogIDDB.iconXOffset
    end

    if type(savedOffset) == "number" then
        iconXOffset = math.max(MIN_ICON_X_OFFSET, math.min(savedOffset, MAX_ICON_X_OFFSET))
    else
        iconXOffset = DEFAULT_ICON_X_OFFSET
    end

    positionIcon()
end

-- Open or close the static settings panel. Setting the slider value also keeps
-- its label and thumb in sync with the icon's current position.
local function toggleOptionsMenu()
    if optionsMenu:IsShown() then
        optionsMenu:Hide()
        return
    end

    positionSlider:SetValue(iconXOffset)
    optionsMenu:Show()
end

-- Keep hiding the icon in one place so every non-matching target behaves alike.
local function hideIcon()
    icon:Hide()
end

icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Transmog detected")
    GameTooltip:AddLine("This target has at least one applied appearance or weapon illusion.", 1, 1, 1, true)
    GameTooltip:Show()
end)
icon:SetScript("OnLeave", GameTooltip_Hide)

icon:EnableMouse(true)

SLASH_TRANSMOGID1 = "/tmid"
SlashCmdList.TRANSMOGID = toggleOptionsMenu

-- Return the appearance source used by an equipped item in one inventory slot.
-- This lets us compare the equipped item with the inspect-transmog information.
local function getEquippedAppearanceSource(unit, inventorySlot)
    local itemLink = GetInventoryItemLink(unit, inventorySlot)
    if not itemLink then
        return nil
    end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    return sourceID
end

-- Inspect data is supplied one inventory slot at a time. A different appearance
-- source, a secondary appearance, or a weapon illusion means transmog is active.
local function hasAppliedTransmog(unit, infoList)
    for inventorySlot, info in ipairs(infoList or {}) do
        local equippedSourceID = getEquippedAppearanceSource(unit, inventorySlot)

        if equippedSourceID
            and info.appearanceID
            and info.appearanceID ~= 0
            and info.appearanceID ~= equippedSourceID then
            return true
        end

        if info.secondaryAppearanceID and info.secondaryAppearanceID ~= 0 then
            return true
        end

        if info.illusionID and info.illusionID ~= 0 then
            return true
        end
    end

    return false
end

-- Read the inspect result once WoW confirms it is ready, then show or hide the
-- icon based on the transmog checks above.
local function showInspectionResult()
    if not C_TransmogCollection or not C_TransmogCollection.GetInspectItemTransmogInfoList then
        hideIcon()
        return
    end

    local infoList = C_TransmogCollection.GetInspectItemTransmogInfoList() or {}
    if hasAppliedTransmog("target", infoList) then
        icon:Show()
    else
        hideIcon()
    end
end

-- Start an inspection only for a nearby player target. Targeting ourselves is a
-- deliberate test mode: show the icon without requiring inspect data.
local function inspectTarget()
    hideIcon()
    pendingGUID = nil

    if not UnitExists("target") or not UnitIsPlayer("target") then
        return
    end

    if UnitIsUnit("target", "player") then
        icon:Show()
        return
    end

    if not CanInspect("target") or not CheckInteractDistance("target", 1) then
        return
    end

    if GetTime() - lastInspectRequest < INSPECT_COOLDOWN_SECONDS then
        return
    end

    pendingGUID = UnitGUID("target")
    lastInspectRequest = GetTime()
    NotifyInspect("target")
end

-- Event-driven control flow:
--   ADDON_LOADED          saved settings become available
--   PLAYER_TARGET_CHANGED inspect the new target
--   INSPECT_READY         inspect data can now be evaluated
TransmogID:RegisterEvent("PLAYER_TARGET_CHANGED")
TransmogID:RegisterEvent("INSPECT_READY")
TransmogID:RegisterEvent("ADDON_LOADED")
TransmogID:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        -- ADDON_LOADED fires for every addon, so only initialise our own.
        if arg1 == addonName then
            loadSavedPosition()
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        inspectTarget()
        return
    end

    if event == "INSPECT_READY" and arg1 == pendingGUID and UnitGUID("target") == arg1 then
        -- Confirm the result still belongs to the target currently selected.
        showInspectionResult()
        pendingGUID = nil
    end
end)
