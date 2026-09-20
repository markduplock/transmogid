local addonName = ...
local TransmogID = CreateFrame("Frame")

local pendingGUID
local lastInspectRequest = 0
local INSPECT_COOLDOWN_SECONDS = 2

local DEFAULT_ICON_X_OFFSET = -10
local DEFAULT_ICON_Y_OFFSET = 0
local MIN_ICON_X_OFFSET = -200
local MAX_ICON_X_OFFSET = 0
local MIN_ICON_Y_OFFSET = -90
local MAX_ICON_Y_OFFSET = 0
local iconXOffset = DEFAULT_ICON_X_OFFSET
local iconYOffset = DEFAULT_ICON_Y_OFFSET
local BASE_ICON_SIZE = 18
local MIN_ICON_SCALE = 1
local MAX_ICON_SCALE = 4
local PREVIEW_SCALE_MARGIN = BASE_ICON_SIZE * (MAX_ICON_SCALE - 1) / 2
local iconScale = MIN_ICON_SCALE
local previewTarget
local previewIcon

local icon = CreateFrame("Frame", addonName .. "TargetIcon", TargetFrame)
icon:SetSize(BASE_ICON_SIZE, BASE_ICON_SIZE)
icon:SetFrameStrata("MEDIUM")
icon:Hide()

local function positionIcon()
    local centreX = iconXOffset - BASE_ICON_SIZE / 2
    local centreY = iconYOffset - BASE_ICON_SIZE / 2
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", TargetFrame, "TOPRIGHT", centreX, centreY)
    if previewIcon then
        previewIcon:ClearAllPoints()
        previewIcon:SetPoint("CENTER", previewTarget, "TOPRIGHT", centreX, centreY)
    end
end

local function resizeIcon()
    icon:SetSize(BASE_ICON_SIZE * iconScale, BASE_ICON_SIZE * iconScale)
    if previewIcon then
        previewIcon:SetSize(BASE_ICON_SIZE * iconScale, BASE_ICON_SIZE * iconScale)
    end
end

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetAllPoints()
texture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\transmog-wardrobe")

local border = icon:CreateTexture(nil, "OVERLAY")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

local optionsMenu = CreateFrame("Frame", addonName .. "OptionsMenu", UIParent)
optionsMenu:SetSize(250, 224)
optionsMenu:SetFrameStrata("DIALOG")
optionsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
optionsMenu:Hide()

local menuBackground = optionsMenu:CreateTexture(nil, "BACKGROUND")
menuBackground:SetAllPoints()
menuBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

local previewPanel = CreateFrame("Frame", nil, optionsMenu)
previewPanel:SetPoint("BOTTOM", optionsMenu, "TOP", 0, 8)

local previewBackground = previewPanel:CreateTexture(nil, "BACKGROUND")
previewBackground:SetAllPoints()
previewBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

local previewTitle = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
previewTitle:SetPoint("TOP", 0, -10)
previewTitle:SetText("Player frame preview")

previewTarget = CreateFrame("Frame", nil, previewPanel)
previewTarget:SetPoint("TOPRIGHT", previewPanel, "TOPRIGHT",
    -20 - PREVIEW_SCALE_MARGIN, -36 - PREVIEW_SCALE_MARGIN)

local previewArtwork = previewTarget:CreateTexture(nil, "ARTWORK")
previewArtwork:SetPoint("TOPRIGHT", previewTarget, "TOPRIGHT", 0, 0)
previewArtwork:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\player-frame-preview")
previewArtwork:SetTexCoord(0, 244 / 256, 0, 92 / 128)

previewIcon = CreateFrame("Frame", nil, previewTarget)
local previewTexture = previewIcon:CreateTexture(nil, "ARTWORK")
previewTexture:SetAllPoints()
previewTexture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\transmog-wardrobe")

local previewBorder = previewIcon:CreateTexture(nil, "OVERLAY")
previewBorder:SetPoint("TOPLEFT", -1, 1)
previewBorder:SetPoint("BOTTOMRIGHT", 1, -1)
previewBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")

local function refreshPreview()
    local width, height = TargetFrame:GetSize()
    if not width or width <= 0 then width = 250 end
    if not height or height <= 0 then height = 100 end
    previewTarget:SetSize(width, height)
    local artworkHeight = width * 92 / 244
    previewArtwork:SetSize(width, artworkHeight)
    local maxIconSize = BASE_ICON_SIZE * MAX_ICON_SCALE
    local previewHeight = math.max(height, artworkHeight, -MIN_ICON_Y_OFFSET + maxIconSize)
        + 56 + PREVIEW_SCALE_MARGIN
    previewPanel:SetSize(
        math.max(width, -MIN_ICON_X_OFFSET + maxIconSize) + 40 + PREVIEW_SCALE_MARGIN,
        previewHeight
    )
    optionsMenu:ClearAllPoints()
    optionsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, -(previewHeight + 8) / 2)
    resizeIcon()
    positionIcon()
end

local menuTitle = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
menuTitle:SetPoint("TOP", 0, -10)
menuTitle:SetText("Transmog ID settings")

local xPositionLabel = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
xPositionLabel:SetPoint("TOP", 0, -50)
local yPositionLabel = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
yPositionLabel:SetPoint("TOP", 0, -96)
local scaleLabel = optionsMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
scaleLabel:SetPoint("TOP", 0, -142)

local xPositionSlider = CreateFrame("Slider", nil, optionsMenu)
xPositionSlider:SetPoint("TOPLEFT", 18, -30)
xPositionSlider:SetPoint("TOPRIGHT", -18, -30)
xPositionSlider:SetHeight(16)
xPositionSlider:SetOrientation("HORIZONTAL")
xPositionSlider:SetMinMaxValues(MIN_ICON_X_OFFSET, MAX_ICON_X_OFFSET)
xPositionSlider:SetValueStep(1)
if xPositionSlider.SetObeyStepOnDrag then
    xPositionSlider:SetObeyStepOnDrag(true)
end
xPositionSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

local xSliderTrack = xPositionSlider:CreateTexture(nil, "BACKGROUND")
xSliderTrack:SetPoint("LEFT")
xSliderTrack:SetPoint("RIGHT")
xSliderTrack:SetHeight(8)
xSliderTrack:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")

xPositionSlider:SetScript("OnValueChanged", function(_, value)
    iconXOffset = value
    positionIcon()
    xPositionLabel:SetText(("Horizontal position: %d"):format(value))
end)

local yPositionSlider = CreateFrame("Slider", nil, optionsMenu)
yPositionSlider:SetPoint("TOPLEFT", 18, -76)
yPositionSlider:SetPoint("TOPRIGHT", -18, -76)
yPositionSlider:SetHeight(16)
yPositionSlider:SetOrientation("HORIZONTAL")
yPositionSlider:SetMinMaxValues(MIN_ICON_Y_OFFSET, MAX_ICON_Y_OFFSET)
yPositionSlider:SetValueStep(1)
if yPositionSlider.SetObeyStepOnDrag then
    yPositionSlider:SetObeyStepOnDrag(true)
end
yPositionSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

local ySliderTrack = yPositionSlider:CreateTexture(nil, "BACKGROUND")
ySliderTrack:SetPoint("LEFT")
ySliderTrack:SetPoint("RIGHT")
ySliderTrack:SetHeight(8)
ySliderTrack:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")

yPositionSlider:SetScript("OnValueChanged", function(_, value)
    iconYOffset = value
    positionIcon()
    yPositionLabel:SetText(("Vertical position: %d"):format(value))
end)

local scaleSlider = CreateFrame("Slider", nil, optionsMenu)
scaleSlider:SetPoint("TOPLEFT", 18, -122)
scaleSlider:SetPoint("TOPRIGHT", -18, -122)
scaleSlider:SetHeight(16)
scaleSlider:SetOrientation("HORIZONTAL")
scaleSlider:SetMinMaxValues(MIN_ICON_SCALE, MAX_ICON_SCALE)
scaleSlider:SetValueStep(0.1)
if scaleSlider.SetObeyStepOnDrag then
    scaleSlider:SetObeyStepOnDrag(true)
end
scaleSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

local scaleSliderTrack = scaleSlider:CreateTexture(nil, "BACKGROUND")
scaleSliderTrack:SetPoint("LEFT")
scaleSliderTrack:SetPoint("RIGHT")
scaleSliderTrack:SetHeight(8)
scaleSliderTrack:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")

scaleSlider:SetScript("OnValueChanged", function(_, value)
    iconScale = value
    resizeIcon()
    scaleLabel:SetText(("Scale: %.1fx"):format(value))
end)

local menuOriginalSettings

local function syncSettingsControls()
    xPositionSlider:SetValue(iconXOffset)
    yPositionSlider:SetValue(iconYOffset)
    scaleSlider:SetValue(iconScale)
    xPositionLabel:SetText(("Horizontal position: %d"):format(iconXOffset))
    yPositionLabel:SetText(("Vertical position: %d"):format(iconYOffset))
    scaleLabel:SetText(("Scale: %.1fx"):format(iconScale))
end

local function cancelSettings()
    if menuOriginalSettings then
        iconXOffset = menuOriginalSettings.iconXOffset
        iconYOffset = menuOriginalSettings.iconYOffset
        iconScale = menuOriginalSettings.iconScale
        resizeIcon()
        positionIcon()
        syncSettingsControls()
        menuOriginalSettings = nil
    end
    optionsMenu:Hide()
end

local savePositionButton = CreateFrame("Button", nil, optionsMenu, "UIPanelButtonTemplate")
savePositionButton:SetSize(110, 22)
savePositionButton:SetPoint("BOTTOMLEFT", 10, 10)
savePositionButton:SetText("Save settings")
savePositionButton:SetScript("OnClick", function()
    if type(TransmogIDDB) ~= "table" then
        TransmogIDDB = {}
    end

    TransmogIDDB.iconXOffset = iconXOffset
    TransmogIDDB.iconYOffset = iconYOffset
    TransmogIDDB.iconScale = iconScale
    menuOriginalSettings = nil
    optionsMenu:Hide()
end)

local cancelButton = CreateFrame("Button", nil, optionsMenu, "UIPanelButtonTemplate")
cancelButton:SetSize(110, 22)
cancelButton:SetPoint("BOTTOMRIGHT", -10, 10)
cancelButton:SetText("Cancel")
cancelButton:SetScript("OnClick", cancelSettings)

local resetButton = CreateFrame("Button", nil, optionsMenu, "UIPanelButtonTemplate")
resetButton:SetSize(160, 22)
resetButton:SetPoint("BOTTOM", 0, 38)
resetButton:SetText("Reset to defaults")
resetButton:SetScript("OnClick", function()
    iconXOffset = DEFAULT_ICON_X_OFFSET
    iconYOffset = DEFAULT_ICON_Y_OFFSET
    iconScale = MIN_ICON_SCALE
    resizeIcon()
    positionIcon()
    syncSettingsControls()
end)

local function loadSavedPosition()
    local savedXOffset
    local savedYOffset
    local savedScale
    if type(TransmogIDDB) == "table" then
        savedXOffset = TransmogIDDB.iconXOffset
        savedYOffset = TransmogIDDB.iconYOffset
        savedScale = TransmogIDDB.iconScale
    end

    if type(savedXOffset) == "number" then
        iconXOffset = math.max(MIN_ICON_X_OFFSET, math.min(savedXOffset, MAX_ICON_X_OFFSET))
    else
        iconXOffset = DEFAULT_ICON_X_OFFSET
    end

    if type(savedYOffset) == "number" then
        iconYOffset = math.max(MIN_ICON_Y_OFFSET, math.min(savedYOffset, MAX_ICON_Y_OFFSET))
    else
        iconYOffset = DEFAULT_ICON_Y_OFFSET
    end

    if type(savedScale) == "number" then
        iconScale = math.max(MIN_ICON_SCALE, math.min(savedScale, MAX_ICON_SCALE))
    else
        iconScale = MIN_ICON_SCALE
    end

    resizeIcon()
    positionIcon()
end

local function toggleOptionsMenu()
    if optionsMenu:IsShown() then
        cancelSettings()
        return
    end

    menuOriginalSettings = {
        iconXOffset = iconXOffset,
        iconYOffset = iconYOffset,
        iconScale = iconScale,
    }
    syncSettingsControls()
    refreshPreview()
    optionsMenu:Show()
end

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

local function getEquippedAppearanceSource(unit, inventorySlot)
    local itemLink = GetInventoryItemLink(unit, inventorySlot)
    if not itemLink then
        return nil
    end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    return sourceID
end

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

local function inspectTarget()
    hideIcon()
    pendingGUID = nil

    if not UnitExists("target") or not UnitIsPlayer("target") then
        return
    end

    if UnitIsUnit("target", "player") then
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

TransmogID:RegisterEvent("PLAYER_TARGET_CHANGED")
TransmogID:RegisterEvent("INSPECT_READY")
TransmogID:RegisterEvent("ADDON_LOADED")
TransmogID:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
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
        showInspectionResult()
        pendingGUID = nil
    end
end)

