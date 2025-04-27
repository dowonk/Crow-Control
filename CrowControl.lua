local CrowStart
local CrowSynced
local CrowStartTimer
local CrowTimer
local CrowTimerMin
local CrowTimerSec
local Location
local RollingAll
local Rolls = {}
local RollsIndex
local RollsTimer = 1
local Winners = {}
local AutoInviting = false
local AutoInvitingTimer
local TradingName

if CrowAlertsCheck == nil then
    CrowAlertsCheck = true
end

local function CreateCheckButton(name, parent, text, tooltip, xOff, yOff)
    local checkButton = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    checkButton.tooltip = tooltip
    checkButton:SetPoint("TOPLEFT", xOff, yOff)
    _G[name .. "Text"]:SetText(text)

    return checkButton
end

local CrowGuildButton = CreateFrame("Button", "CrowGuildButton", GuildFrameControlButton, "UIPanelButtonTemplate")
CrowGuildButton:SetSize(100, 20)
CrowGuildButton:SetText("Crow Control")
CrowGuildButton:SetPoint("TOP", 0, 24)
CrowGuildButton:SetScript("OnClick", function() CrowSettings:SetShown(not CrowSettings:IsShown()) end)

local CrowSettings = CreateFrame("Frame", "CrowSettings", GuildFrame, "DefaultPanelTemplate")
CrowSettings:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    insets = { top = 25 }
})
CrowSettings:SetPoint("TOPRIGHT", 266, -13)
CrowSettings:SetSize(300, 150)
CrowSettings.text = CrowSettings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CrowSettings.text:SetPoint("TOP", 0, -4)
CrowSettings.text:SetText("Crow Control Settings")
CrowSettings:SetScript("OnHide", function() CrowSettings:Hide() end)
CrowSettings:RegisterEvent("PLAYER_LOGIN")
CrowSettings:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CrowAlertsBox:SetChecked(CrowAlertsCheck)
        RaidWarningsBox:SetChecked(RaidWarningsCheck)
        AutoRollBox:SetChecked(AutoRollCheck)
    end
end)
CrowSettings:Hide()

local CloseCrowSettings = CreateFrame("Button", "Close", CrowSettings, "UIPanelCloseButton")
CloseCrowSettings:SetPoint("TOPRIGHT", 6, 5)
CloseCrowSettings:SetScript("OnClick", function() CrowSettings:Hide() end)

local CrowAlertsBox = CreateCheckButton("CrowAlertsBox", CrowSettings, "Show Crow's Cache Alerts", "Shows location/timer on top of screen.", 5, -25)
CrowAlertsBox:SetScript("OnClick", function()
	if CrowAlertsBox:GetChecked() == nil then
		CrowAlertsCheck = false
        CrowAlertsBox:SetChecked(CrowAlertsCheck)
		CrowAlerts:Hide()
    else
        CrowAlertsCheck = CrowAlertsBox:GetChecked()
        CrowAlertsBox:SetChecked(CrowAlertsCheck)
    end
end)

local RaidWarningsBox = CreateCheckButton("RaidWarningsBox", CrowAlertsBox, "Announce Raid Warnings on Target", "Announces your target's name when you switch targets.", 0, -20)
RaidWarningsBox:SetScript("OnClick", function()
    RaidWarningsCheck = RaidWarningsBox:GetChecked()
    RaidWarningsBox:SetChecked(RaidWarningsCheck)
end)

RaidWarningsBox:RegisterEvent("PLAYER_TARGET_CHANGED")
RaidWarningsBox:SetScript("OnEvent", function(self, event, ...)
    if RaidWarningsBox:GetChecked() and event == "PLAYER_TARGET_CHANGED" and UnitCanAttack("player", "target") and UnitIsPlayer("target") and not UnitIsDeadOrGhost("player") and not UnitIsDeadOrGhost("target") and UnitInBattleground("player") == nil and IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) then
        SendChatMessage("{Skull} " .. UnitName("target") .. " {Skull}", "RAID_WARNING")
    end
end)

local AutoRollBox = CreateCheckButton("AutoRollBox", RaidWarningsBox, "Auto Roll Loot", "Auto rolls Bloodforged Gear/Copper Marks. Must type prefix \"roll\" or \"rollall\" in raid chat", 0, -20)
AutoRollBox:SetScript("OnClick", function()
    AutoRollCheck = AutoRollBox:GetChecked()
    AutoRollBox:SetChecked(AutoRollCheck)
end)

AutoRollBox:RegisterAllEvents("CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER")
AutoRollBox:SetScript("OnEvent", function(self, event, ...)
    if AutoRollBox:GetChecked() and (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") and (string.lower(arg1):sub(1, 7) == "rollall" or string.lower(arg1):sub(1, 4) == "roll") and arg2 == UnitName("player") and IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) then
        if string.lower(arg1):sub(1, 7) == "rollall" then
            local winner
            local item
            Winners = {}

            for i = 0, 5 do
                for j = 1, GetContainerNumSlots(i) do
                    if GetContainerItemInfo(i,j) ~= nil and (string.find(select(7,GetContainerItemInfo(i,j)), "Bloodforged") or string.find(select(7,GetContainerItemInfo(i,j)), "Copper Mark of War")) then
                        winner = GetRaidRosterInfo(math.random(1, GetNumRaidMembers()))
                        item = select(7,GetContainerItemInfo(i,j))
                        table.insert(Rolls, winner .. " wins " .. item)
                        
                        if not Winners[winner] then
                            Winners[winner] = {item}
                        else
                            table.insert(Winners[winner], item)
                        end
                    end
                end
            end

            if #Rolls == 1 then
                SendChatMessage(Rolls[1], "RAID_WARNING")
                Rolls = {}
                return
            end
            
            RollingAll = true
            RollsIndex = #Rolls
            SendChatMessage(Rolls[RollsIndex], "RAID_WARNING")
            
        elseif string.lower(arg1):sub(1, 4) == "roll" then
            SendChatMessage(GetRaidRosterInfo(math.random(1, GetNumRaidMembers())) .. " wins " .. arg1:sub(5), "RAID_WARNING")
        end
    end
end)

local AutoInviteButton = CreateFrame("Button", "AutoInviteButton", CrowSettings, "UIPanelButtonTemplate")
AutoInviteButton:SetSize(150, 50)
AutoInviteButton:SetText("Start Auto Invites")
AutoInviteButton:SetPoint("BOTTOM")
AutoInviteButton:SetScript("OnClick", function()
    if not AutoInviting and not UnitBuff("player", "Mercenary for Hire!") then
        print("Auto invite failed! You must be in High Risk and Mercenary Mode.")
        return
    elseif not AutoInviting and (IsInGroup() and IsPartyLeader() ~= 1 and not IsInRaid() or IsInRaid() and IsRaidLeader() ~= 1 and IsRaidOfficer() ~= 1) then
        print("Auto invite failed! You must be a group leader.")
        return
    end

    AutoInvitingTimer = 120
    AutoInviting = not AutoInviting
    AutoInviteButton:SetText(AutoInviting and "Stop Auto Invites" or "Start Auto Invites")

    if not AutoInviting then
        SendChatMessage("Crow's Cache invites have stopped!", "GUILD")
    elseif AutoInviting and Location and CrowTimer and CrowTimer > 0 then
        SendChatMessage("KAWKAW! Crow's Cache invites have started! Type \"kawkaw\" for an invite! Materializing in " .. CrowTimerMin .. " minute(s) in " .. Location .. ".", "GUILD")
    else
        SendChatMessage("KAWKAW! Crow's Cache invites have started! Type \"kawkaw\" for an invite!", "GUILD")
    end
end)

AutoInviteButton:RegisterAllEvents("CHAT_MSG_GUILD", "PARTY_MEMBERS_CHANGED", "UI_INFO_MESSAGE")
AutoInviteButton:SetScript("OnEvent", function(self, event, ...)
    if AutoInviting and event == "CHAT_MSG_GUILD" and string.lower(arg1) == "kawkaw" and (not IsInGroup() or (IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) and not UnitInRaid(arg2)) or (IsPartyLeader() == 1 and not IsInRaid() and not UnitInParty(arg2) == 1)) then
        InviteUnit(arg2)

    elseif AutoInviting and event == "PARTY_MEMBERS_CHANGED" and not IsInRaid() and IsPartyLeader() == 1 then
        ConvertToRaid()

    elseif AutoInviting and event == "UI_INFO_MESSAGE" and string.find(arg1, "You cannot invite") then
        SendChatMessage("Invite failed! You must be in High Risk and Mercenary Mode.", "GUILD")
    end
end)

local CrowAlerts = CreateFrame("Frame")
CrowAlerts:SetPoint("TOP", -110, -5)
CrowAlerts:SetSize(40, 40)
CrowAlerts:SetMovable(true)
CrowAlerts:EnableMouse(true)
CrowAlerts:RegisterForDrag("LeftButton")
CrowAlerts:SetScript("OnDragStart", CrowAlerts.StartMoving)
CrowAlerts:SetScript("OnDragStop", CrowAlerts.StopMovingOrSizing)
CrowAlerts.tex = CrowAlerts:CreateTexture()
CrowAlerts.tex:SetAllPoints(CrowAlerts)
CrowAlerts.tex:SetTexture("interface/icons/inv_petraven2_black")
CrowAlerts.text = CrowAlerts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CrowAlerts.text:SetPoint("LEFT", 45, 0)
CrowAlerts.text:SetJustifyH("LEFT")
CrowAlerts:Hide()

local CloseCrowAlerts = CreateFrame("Button", "CloseCrowAlerts", CrowAlerts, "UIPanelCloseButton")
CloseCrowAlerts:SetPoint("LEFT", -25, 0)
CloseCrowAlerts:SetScript("OnClick", function() 
    CrowAlerts:Hide()
end)

CrowAlerts:RegisterEvent("CHAT_MSG_SYSTEM")
CrowAlerts:SetScript("OnEvent", function(self, event, ...)
    if CrowAlertsBox:GetChecked() and event == "CHAT_MSG_SYSTEM" then
        if string.find(arg1, "Crow's Cache") then
            if not CrowAlerts:IsShown() then
                CrowAlerts:Show()
                PlaySound("SummonRavenLord")
            end

            if string.find(arg1, "near") then
                Location = arg1:sub(string.find(arg1, "near") + 15, string.find(arg1, "|r!") - 1)
            end

            if string.find(arg1, "minute") or string.find(arg1, "seconds") then
                CrowStart = true
                CrowSynced = false
                CrowStartTimer = GetTime()

                if string.find(arg1, "minute") then
                    CrowTimer = tonumber(arg1:match("%d+", arg1:find("in"))) * 60
                elseif string.find(arg1, "seconds") then
                    CrowTimer = tonumber(arg1:match("%d+", arg1:find("in")))
                end

            elseif string.find(arg1, "looted") or string.find(arg1, "materialized") then
                if string.find(arg1, "looted") then
                    if Location then
                        CrowAlerts.text:SetText("Crow's Cache has been looted!\nLooter: |cFFFF0000" .. arg1:sub(arg1:find("by") + 3, arg1:find("!") - 1) .. "|r\nLocation: |cFFFF0000" .. Location .. "|r")
                    else
                        CrowAlerts.text:SetText("Crow's Cache has been looted!\nLooter: |cFFFF0000" .. arg1:sub(arg1:find("by") + 3, arg1:find("!") - 1) .. "|r")
                    end
                elseif string.find(arg1, "materialized") then
                    if Location then
                        CrowAlerts.text:SetText("Crow's Cache has materialized!\nLocation: |cFFFF0000" .. Location .. "|r")
                    else
                        CrowAlerts.text:SetText("Crow's Cache has materialized!")
                    end
                end
                
                CrowStart = false
                Location = nil
                CrowTimer = nil
                
                if AutoInviting then
                    AutoInviting = false
                    SendChatMessage("Crow's Cache invites have stopped!", "GUILD")
                    AutoInviteButton:SetText("Start Auto Invites")
                end
            end
        end
    end
end)

local TradeRollButton = CreateFrame("Button", "TradeRollButton", TradeFrameTradeButton, "UIPanelButtonTemplate")
TradeRollButton:SetSize(160, 20)
TradeRollButton:SetText("Trade Winnings")
TradeRollButton:SetPoint("Left", -170, 2)
TradeRollButton:Hide()
TradeRollButton:SetScript("OnClick",function()
    local ItemFound

    for loot = 1, #Winners[TradingName] do
        for i = 0, 5 do
            for j = 1, GetContainerNumSlots(i) do
                if GetContainerItemInfo(i,j) ~= nil and select(7,GetContainerItemInfo(i,j)) == Winners[TradingName][loot] then
                    UseContainerItem(i,j)
                    ItemFound = true
                    break
                end
            end

            if ItemFound then
                ItemFound = false
                break
            end
        end
    end
end)

TradeRollButton:RegisterAllEvents("TRADE_SHOW", "TRADE_CLOSED")
TradeRollButton:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SHOW" then
        if Winners[UnitName("NPC")] then
            TradingName = UnitName("NPC")
            TradeRollButton:Show()
        end

    elseif event == "TRADE_CLOSED" then
        if Winners[TradingName] then
            local ItemExists

            for loot = 1, #Winners[TradingName] do
                for i = 0, 5 do
                    for j = 1, GetContainerNumSlots(i) do
                        if GetContainerItemInfo(i,j) ~= nil and select(7,GetContainerItemInfo(i,j)) == Winners[TradingName][loot] then
                            ItemExists = true
                            return
                        end
                    end
                end
            end
        
            if not ItemExists then
                Winners[TradingName] = nil
                TradeRollButton:Hide()
            end
        end
    end
end)

local UpdateTimer = CreateFrame("Frame")
UpdateTimer:SetScript("OnUpdate", function(self, elapsed)
    if CrowStart and not CrowSynced then
        if elapsed <= 1 then
            CrowSynced = true
        elseif elapsed > 1 then
            CrowTimer = CrowTimer - (GetTime() - CrowStartTimer)
            return
        end
    end

    if CrowStart then
        CrowTimer = CrowTimer - elapsed
        if CrowTimer >= 0 then
            CrowTimerMin = math.floor(CrowTimer / 60)
            CrowTimerSec = CrowTimer % 60
            CrowAlerts.text:SetText("Crow's Cache is materializing!\nLocation: |cFFFF0000" .. Location .. "|r\nTimer: |cFFFF0000" .. string.format("%02d:%02d", CrowTimerMin, CrowTimerSec) .. "|r")
        end
    end

    if AutoInviting then
        AutoInvitingTimer = AutoInvitingTimer - elapsed
        if AutoInvitingTimer <= 0 then
            AutoInvitingTimer = 120

            if Location and CrowTimer and CrowTimer > 0 then
                SendChatMessage("KAWKAW! Crow's Cache invites have started! Type \"kawkaw\" for an invite! Materializing in " .. CrowTimerMin .. " minute(s) in " .. Location .. ".", "GUILD")
            else
                SendChatMessage("KAWKAW! Crow's Cache invites have started! Type \"kawkaw\" for an invite!", "GUILD")
            end
        end
    end

    if RollingAll then
        RollsTimer = RollsTimer - elapsed
        if RollsTimer <= 0 then
            RollsTimer = 1
            RollsIndex = RollsIndex - 1
            SendChatMessage(Rolls[RollsIndex], "RAID_WARNING")

            if RollsIndex == 1 then
                RollingAll = false
                Rolls = {}
            end
        end
    end
end)
