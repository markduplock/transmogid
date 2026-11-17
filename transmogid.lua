--[[
	addon version: 1.1
	client version: 1.6.1
	Interface version: 16001
]]

local addonName = ...
local TransmogID = CreateFrame("Frame")

local pendingGUID
local nextInspectTime = 0
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
optionsMenu:EnableMouse(true)
optionsMenu:SetFrameStrata("DIALOG")
optionsMenu:SetPoint("CENTER")
optionsMenu:Hide()

local menuBackground = optionsMenu:CreateTexture(nil, "BACKGROUND")
menuBackground:SetAllPoints()
menuBackground:SetColorTexture(0.05, 0.05, 0.05, 0.95)

local menuTitle = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menuTitle:SetPoint("TOP", 0, -12)
menuTitle:SetText("Transmog ID settings")

local instructions = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
instructions:SetPoint("TOP", menuTitle, "BOTTOM", 0, -8)
instructions:SetText("Drag the icon to move it. Scroll over it to resize.")

previewTarget = CreateFrame("Frame", nil, optionsMenu)

local previewPortrait = previewTarget:CreateTexture(nil, "BACKGROUND")
local previewHealth = previewTarget:CreateTexture(nil, "BACKGROUND")
previewHealth:SetColorTexture(0, 0.75, 0, 1)
local previewPower = previewTarget:CreateTexture(nil, "BACKGROUND")
previewPower:SetColorTexture(0, 0.35, 0.85, 1)
local previewArtwork = previewTarget:CreateTexture(nil, "ARTWORK")
previewArtwork:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")

-- The default frame and its texture-frame child share the same bounds.
-- Reuse their child anchors, including when the live target frame is hidden.
local function placePreviewRegion(region, live, point, width, height, x, y)
	local relativePoint = point
	if live then
		local anchor, parent, relative, offsetX, offsetY = live:GetPoint(1)
		if anchor and (parent == TargetFrame or parent == TargetFrameTextureFrame) then
			point, relativePoint, x, y = anchor, relative, offsetX, offsetY
			width, height = live:GetSize()
		end
	end
	region:ClearAllPoints()
	region:SetSize(width, height)
	region:SetPoint(point, previewTarget, relativePoint, x, y)
end

previewIcon = CreateFrame("Frame", nil, previewTarget)
local previewTexture = previewIcon:CreateTexture(nil, "ARTWORK")
previewTexture:SetAllPoints()
previewTexture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\transmog-wardrobe")

local previewBorder = previewIcon:CreateTexture(nil, "OVERLAY")
previewBorder:SetPoint("TOPLEFT", -1, 1)
previewBorder:SetPoint("BOTTOMRIGHT", 1, -1)
previewBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")

local settingsLabel = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
settingsLabel:SetPoint("BOTTOM", 0, 72)

local function updateSettingsLabel()
	settingsLabel:SetText(("X %d     Y %d     Scale %.1fx"):format(iconXOffset, iconYOffset, iconScale))
end

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(value, maximum))
end

local function cursorInPreview()
	local x, y = GetCursorPosition()
	local scale = previewTarget:GetEffectiveScale()
	return x / scale, y / scale
end

previewIcon:EnableMouse(true)
previewIcon:SetScript("OnMouseDown", function(self, button)
	if button ~= "LeftButton" then
		return
	end

	local startX, startY = cursorInPreview()
	local originalX, originalY = iconXOffset, iconYOffset
	self:SetScript("OnUpdate", function()
		local x, y = cursorInPreview()
		local offsetX = clamp(math.floor(originalX + (x - startX) + 0.5), MIN_ICON_X_OFFSET, MAX_ICON_X_OFFSET)
		local offsetY = clamp(math.floor(originalY + (y - startY) + 0.5), MIN_ICON_Y_OFFSET, MAX_ICON_Y_OFFSET)
		if offsetX ~= iconXOffset or offsetY ~= iconYOffset then
			iconXOffset, iconYOffset = offsetX, offsetY
			positionIcon()
			updateSettingsLabel()
		end
	end)
end)
previewIcon:SetScript("OnMouseUp", function(self, button)
	local update = self:GetScript("OnUpdate")
	if button == "LeftButton" and update then
		update()
		self:SetScript("OnUpdate", nil)
	end
end)
previewIcon:SetScript("OnHide", function(self)
	self:SetScript("OnUpdate", nil)
end)

previewIcon:EnableMouseWheel(true)
previewIcon:SetScript("OnMouseWheel", function(_, delta)
	iconScale = clamp((math.floor(iconScale * 10 + 0.5) + delta) / 10, MIN_ICON_SCALE, MAX_ICON_SCALE)
	resizeIcon()
	updateSettingsLabel()
end)

local function refreshPreview()
	local width, height = TargetFrame:GetSize()
	if not width or width <= 0 then
		width = 250
	end
	if not height or height <= 0 then
		height = 100
	end
	previewTarget:SetSize(width, height)
	local scale = TargetFrame:GetEffectiveScale() / optionsMenu:GetEffectiveScale()
	previewTarget:SetScale(scale)
	previewTarget:SetPoint(
		"TOPRIGHT",
		optionsMenu,
		"TOPRIGHT",
		-20 / scale - PREVIEW_SCALE_MARGIN,
		-56 / scale - PREVIEW_SCALE_MARGIN
	)

	local borderTexture = TargetFrame.borderTexture or TargetFrameTextureFrameTexture
	placePreviewRegion(previewArtwork, borderTexture, "CENTER", 230, 99, 18.5, -4)
	if borderTexture then
		previewArtwork:SetTexCoord(borderTexture:GetTexCoord())
	else
		previewArtwork:SetTexCoord(26 / 256, 1, 1 / 128, 100 / 128)
	end
	placePreviewRegion(previewPortrait, TargetFrame.portrait or TargetFramePortrait, "TOPRIGHT", 64, 64, -24, -16)
	SetPortraitTexture(previewPortrait, "player")
	placePreviewRegion(previewHealth, TargetFrame.healthbar or TargetFrameHealthBar, "TOPRIGHT", 119, 12, -90, -45)
	placePreviewRegion(previewPower, TargetFrame.manabar or TargetFrameManaBar, "TOPRIGHT", 119, 12, -90, -56)
	-- Allow room for the largest icon at either end of its travel.
	local iconExtent = BASE_ICON_SIZE * (1 + MAX_ICON_SCALE) / 2
	optionsMenu:SetSize(
		math.max(280, (math.max(width, -MIN_ICON_X_OFFSET + iconExtent) + PREVIEW_SCALE_MARGIN) * scale + 40),
		(math.max(height, -MIN_ICON_Y_OFFSET + iconExtent) + PREVIEW_SCALE_MARGIN) * scale + 156
	)
	updateSettingsLabel()
end

local menuOriginalSettings

local function cancelSettings()
	if menuOriginalSettings then
		iconXOffset = menuOriginalSettings.iconXOffset
		iconYOffset = menuOriginalSettings.iconYOffset
		iconScale = menuOriginalSettings.iconScale
		resizeIcon()
		positionIcon()
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
	updateSettingsLabel()
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
		iconXOffset = clamp(savedXOffset, MIN_ICON_X_OFFSET, MAX_ICON_X_OFFSET)
	else
		iconXOffset = DEFAULT_ICON_X_OFFSET
	end

	if type(savedYOffset) == "number" then
		iconYOffset = clamp(savedYOffset, MIN_ICON_Y_OFFSET, MAX_ICON_Y_OFFSET)
	else
		iconYOffset = DEFAULT_ICON_Y_OFFSET
	end

	if type(savedScale) == "number" then
		iconScale = clamp(savedScale, MIN_ICON_SCALE, MAX_ICON_SCALE)
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

		if
			equippedSourceID
			and info.appearanceID
			and info.appearanceID ~= 0
			and info.appearanceID ~= equippedSourceID
		then
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
	TransmogID:SetScript("OnUpdate", nil)
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

	local now = GetTime()
	if now < nextInspectTime then
		TransmogID:SetScript("OnUpdate", function()
			if GetTime() >= nextInspectTime then
				inspectTarget()
			end
		end)
		return
	end

	pendingGUID = UnitGUID("target")
	nextInspectTime = now + INSPECT_COOLDOWN_SECONDS
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
