local addonName = ...
local TransmogID = CreateFrame("Frame")
local pendingGUID
local lastInspectRequest = 0
local INSPECT_COOLDOWN_SECONDS = 2

local icon = CreateFrame("Frame", addonName .. "TargetIcon", TargetFrame)
icon:SetSize(18, 18)
icon:SetPoint("TOPRIGHT", TargetFrame, "TOPRIGHT", -24, -8)
icon:SetFrameStrata("MEDIUM")
icon:Hide()

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetAllPoints()
texture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\transmog-wardrobe")

local border = icon:CreateTexture(nil, "OVERLAY")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Transmog detected")
    GameTooltip:AddLine("This target has at least one applied appearance or weapon illusion.", 1, 1, 1, true)
    GameTooltip:Show()
end)
icon:SetScript("OnLeave", GameTooltip_Hide)

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
        icon:Hide()
        return
    end

    local infoList = C_TransmogCollection.GetInspectItemTransmogInfoList() or {}
    if hasAppliedTransmog("target", infoList) then
        icon:Show()
    else
        icon:Hide()
    end
end

local function inspectTarget()
    icon:Hide()
    pendingGUID = nil

    if not UnitExists("target") or not UnitIsPlayer("target") then
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
TransmogID:SetScript("OnEvent", function(_, event, guid)
    if event == "PLAYER_TARGET_CHANGED" then
        inspectTarget()
        return
    end

    if event == "INSPECT_READY" and guid == pendingGUID and UnitGUID("target") == guid then
        showInspectionResult()
        pendingGUID = nil
    end
end)

-- For Testing
-- SLASH_TRANSMOGID1 = "/tmidprobe"
-- SlashCmdList.TRANSMOGID = function()
--     if not C_TransmogCollection or not C_TransmogCollection.GetInspectItemTransmogInfoList then
--         print("TransmogID: inspect-transmog API is unavailable on this client.")
--         return
--     end

--     local infoList = C_TransmogCollection.GetInspectItemTransmogInfoList() or {}
--     print("TransmogID: " .. #infoList .. " inspect transmog records; detected=" .. tostring(hasAppliedTransmog("target", infoList)))

--     for index, info in ipairs(infoList) do
--         print(("  %d: appearance=%s equipped=%s secondary=%s illusion=%s"):format(
--             index,
--             tostring(info.appearanceID),
--             tostring(getEquippedAppearanceSource("target", index)),
--             tostring(info.secondaryAppearanceID),
--             tostring(info.illusionID)
--         ))
--     end
-- end
