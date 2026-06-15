local CrowLocation, CrowStart, CrowSynced, CrowStartTimer, CrowTimer, CrowTimerMin, CrowTimerSec
local Enemies, GroupMembers, FeignedPlayers = {}, {}, {}
local PingTimer = GetTime()
local ZoneChange, ZoneChangeTimer = false, nil
local RollingAll, RollsText, RollsIndex, RollsTimer = false, {}, nil, 1
local Winners = {}
local AutoInviting = false, AutoInvitingTimer
local TargetName
local TradingName

if CrowAlertsCheck == nil then
    CrowAlertsCheck = true
end

local function RegisterEvents(self, ...)
	for i=1,select("#", ...) do
		self:RegisterEvent(select(i, ...))
	end
end

local function UnregisterEvents(self, ...)
	for i=1,select("#", ...) do
		self:UnregisterEvent(select(i, ...))
	end
end

local function CreateCheckButton(name, parent, text, tooltip, xOff, yOff)
    local checkButton = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    checkButton.tooltip = tooltip
    checkButton:SetPoint("TOPLEFT", xOff, yOff)
    _G[name .. "Text"]:SetText(text)

    return checkButton
end

local function SendDetectedMessage(name, guildname)
    local SubZoneText

    if guildname then guildname = " <" .. guildname .. ">" else guildname = "" end
    if GetSubZoneText() == "" then SubZoneText = "" else SubZoneText = GetSubZoneText() .. ", " end

    if IsInGroup() and not IsInRaid() then
        SendChatMessage("DETECTED: " .. name .. guildname .. " - " .. SubZoneText .. GetZoneText(), "PARTY")
    elseif IsInRaid() then
        SendChatMessage("DETECTED: " .. name .. guildname .. " - " .. SubZoneText .. GetZoneText(), "RAID")
    elseif not IsInGroup() then
        print("DETECTED: " .. name .. guildname .. " - " .. SubZoneText .. GetZoneText())
    end
end

local function SendRollMessage(message)
    if IsInGroup() and not IsInRaid() then
        SendChatMessage(message, "PARTY")
    elseif IsInRaid() and IsRaidLeader() ~= 1 and IsRaidOfficer() ~= 1 then
        SendChatMessage(message, "RAID")
    elseif IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) then
        SendChatMessage(message, "RAID_WARNING")
    end
end

local CrowGuildButton = CreateFrame("Button", "CrowGuildButton", GuildFrameControlButton, "UIPanelButtonTemplate")
CrowGuildButton:SetSize(100, 20)
CrowGuildButton:SetText("Crow Control")
CrowGuildButton:SetPoint("TOP", 0, 24)
CrowGuildButton:SetScript("OnClick", function()
    CrowSettings:SetShown(not CrowSettings:IsShown())

    if CrowSettings:IsShown() then
        if UnitBuff("player","High-Risk") and not UnitBuff("player","Mercenary for Hire!") then
            RuleSetButton.text:SetText("Mercenary Mode")
            RuleSetButton:SetAttribute("macrotext", "/cast Mercenary for Hire!")
        elseif UnitBuff("player","Mercenary for Hire!") then
            RuleSetButton.text:SetText("PVE Mode")
            RuleSetButton:SetAttribute("macrotext", "/cast PvE Mode")
        elseif not UnitBuff("player","High-Risk") then
            RuleSetButton.text:SetText("High Risk/Merc")
            RuleSetButton:SetAttribute("macrotext", "/cast High-Risk (PVP)\n/cast Mercenary for Hire!")
        end
    end
end)

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

        if IsInGroup() then
            GroupMembers = {}
            for i = 1, GetNumGroupMembers() do
                if not IsInRaid() and UnitName("party" .. i) ~= nil then
                    GroupMembers[UnitName("party" .. i)] = true
                elseif IsInRaid() then
                    GroupMembers[UnitName("raid" .. i)] = true
                end
            end
        else
            GroupMembers = {}
        end
    end
end)
CrowSettings:Hide()

local CloseCrowSettings = CreateFrame("Button", "Close", CrowSettings, "UIPanelCloseButton")
CloseCrowSettings:SetPoint("TOPRIGHT", 6, 5)
CloseCrowSettings:SetScript("OnClick", function() CrowSettings:Hide() end)

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

CrowAlerts:RegisterEvent("CHAT_MSG_SYSTEM")
CrowAlerts:SetScript("OnEvent", function(self, event, ...)
    if CrowAlertsBox:GetChecked() and event == "CHAT_MSG_SYSTEM" then
        if string.find(arg1, "Crow's Cache") then
            if not CrowAlerts:IsShown() then
                CrowAlerts:Show()
                PlaySound("SummonRavenLord")
            end

            if string.find(arg1, "near") then
                CrowLocation = arg1:sub(string.find(arg1, "near") + 15, string.find(arg1, "|r!") - 1)
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
                    if CrowLocation then
                        CrowAlerts.text:SetText("Crow's Cache has been looted!\nLooter: |cFFFF0000" .. arg1:sub(arg1:find("by") + 3, arg1:find("!") - 1) .. "|r\nLocation: |cFFFF0000" .. CrowLocation .. "|r")
                    else
                        CrowAlerts.text:SetText("Crow's Cache has been looted!\nLooter: |cFFFF0000" .. arg1:sub(arg1:find("by") + 3, arg1:find("!") - 1) .. "|r")
                    end
                elseif string.find(arg1, "materialized") then
                    if CrowLocation then
                        CrowAlerts.text:SetText("Crow's Cache has materialized!\nLocation: |cFFFF0000" .. CrowLocation .. "|r")
                    else
                        CrowAlerts.text:SetText("Crow's Cache has materialized!")
                    end
                end

                CrowLocation = nil
                CrowStart = false
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

local CloseCrowAlerts = CreateFrame("Button", "CloseCrowAlerts", CrowAlerts, "UIPanelCloseButton")
CloseCrowAlerts:SetPoint("LEFT", -25, 0)
CloseCrowAlerts:SetScript("OnClick", function()
    CrowAlerts:Hide()
end)

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

local RaidWarningsBox = CreateCheckButton("RaidWarningsBox", CrowAlertsBox, "Announce Warnings on Pings/Enemies", "Announces pings, nearby enemies, and your target's name.", 0, -20)
RaidWarningsBox:SetScript("OnClick", function()
    RaidWarningsCheck = RaidWarningsBox:GetChecked()
    RaidWarningsBox:SetChecked(RaidWarningsCheck)
    TargetName = nil
end)

RegisterEvents(RaidWarningsBox, "PLAYER_TARGET_CHANGED", "PLAYER_LEAVE_COMBAT", "MINIMAP_PING", "COMBAT_LOG_EVENT", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "PLAYER_LEAVING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA")
RaidWarningsBox:SetScript("OnEvent", function(self, event, ...)
    if not RaidWarningsBox:GetChecked() then return end

    if event == "PLAYER_TARGET_CHANGED" and TargetName ~= UnitName("target") and UnitCanAttack("player", "target") and UnitIsPlayer("target") and not UnitIsDeadOrGhost("player") and not UnitIsDeadOrGhost("target") and IsInInstance() == nil and IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) then
        SendRollMessage("{Skull}" .. UnitName("target") .. "{Skull}")
        TargetName = UnitName("target")

    elseif event == "PLAYER_LEAVE_COMBAT" and TargetName and not UnitCanAttack("player", "target") and not UnitIsPlayer("target") then
        TargetName = nil

    elseif event == "MINIMAP_PING" and IsInInstance() == nil and IsInRaid() and (IsRaidLeader() == 1 or IsRaidOfficer() == 1) and GetTime() - PingTimer >= 1 then
        SendRollMessage(UnitName(arg1) .. " pinged the minimap!")
        PingTimer = GetTime()

    elseif event == "COMBAT_LOG_EVENT" and not ZoneChange and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        if arg2 == "SPELL_AURA_APPLIED" or arg2 == "SPELL_AURA_REMOVED" then
            if arg12 == "BUFF" and not Enemies[arg7] and not GroupMembers[arg7] and UnitName("player") ~= arg7 and string.sub(arg6, 5, 5) == "0" then
                Enemies[arg7] = GetTime()
                SendDetectedMessage(arg7, nil)
            end

        elseif arg4 ~= nil and not Enemies[arg4] and not GroupMembers[arg4] and UnitName("player") ~= arg4 and string.sub(arg3, 5, 5) == "0" then
            Enemies[arg4] = GetTime()
            SendDetectedMessage(arg4, nil)

        elseif arg7 ~= nil and not Enemies[arg7] and not GroupMembers[arg7] and UnitName("player") ~= arg7 and string.sub(arg6, 5, 5) == "0" then
            Enemies[arg7] = GetTime()
            SendDetectedMessage(arg7, nil)
        end

    elseif event == "PLAYER_TARGET_CHANGED" and not ZoneChange and UnitName("player") ~= UnitName("target") and UnitIsPlayer("target") and not GroupMembers[UnitName("target")] and not Enemies[UnitName("target")] and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        Enemies[UnitName("target")] = GetTime()
        SendDetectedMessage(UnitName("target"), GetGuildInfo("target"))

    elseif event == "UPDATE_MOUSEOVER_UNIT" and not ZoneChange and UnitName("player") ~= UnitName("mouseover") and UnitIsPlayer("mouseover") and not GroupMembers[UnitName("mouseover")] and not Enemies[UnitName("mouseover")] and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        Enemies[UnitName("mouseover")] = GetTime()
        SendDetectedMessage(UnitName("mouseover"), GetGuildInfo("mouseover"))

    elseif event == "NAME_PLATE_UNIT_ADDED" and not ZoneChange and not Enemies[UnitName(arg1)] and UnitIsPlayer(arg1) and not GroupMembers[UnitName(arg1)] and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        Enemies[UnitName(arg1)] = GetTime()
        SendDetectedMessage(UnitName(arg1), GetGuildInfo(arg1))

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and not ZoneChange and Enemies[arg1] and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        if arg2 == "Feign Death" then
            FeignedPlayers[arg1] = true
        end

        if arg2 == "Stealth" or arg2 == "Shadowmeld" or arg2 == "Vanish" then
            Enemies[arg1] = nil
        end

    elseif event == "COMBAT_LOG_EVENT" and arg2 == "UNIT_DIED" and not ZoneChange and FeignedPlayers[arg1] and Enemies[arg1] and GetZonePVPInfo() == "contested" and IsInInstance() == nil then
        Enemies[arg1] = nil
        FeignedPlayers[arg1] = nil

    elseif event == "PLAYER_LEAVING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        ZoneChange = true
        ZoneChangeTimer = 2

        for k, v in pairs(Enemies) do
            if GetTime() - v >= 10 then
                Enemies[k] = nil
            end
        end
    end
end)

local AutoRollBox = CreateCheckButton("AutoRollBox", RaidWarningsBox, "Auto Roll Loot", "Auto rolls Bloodforged Gear/Copper Marks. Type \"/rollall\" to roll.", 0, -20)
AutoRollBox:SetScript("OnClick", function()
    AutoRollCheck = AutoRollBox:GetChecked()
    AutoRollBox:SetChecked(AutoRollCheck)
end)

SLASH_ROLLALL1 = "/rollall"
SlashCmdList["ROLLALL"] = function(arg)
    if not IsInGroup() then
        return
    end
    
    local winner
    local item
    local OnlineGroupMembers = {}
    RollsText = {}
    Winners = {}
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitIsConnected(unit) == 1 then
            table.insert(OnlineGroupMembers, (UnitName(unit)))
        end
    end

    if not IsInRaid() then
        table.insert(OnlineGroupMembers, (UnitName("player")))
    end

    for i = 0, 5 do
        for j = 1, GetContainerNumSlots(i) do
            if GetContainerItemInfo(i,j) ~= nil and (string.find(select(7,GetContainerItemInfo(i,j)), "Bloodforged") and select(4,GetContainerItemInfo(i,j)) == 4 or string.find(select(7,GetContainerItemInfo(i,j)), "Copper Mark of War")) then
                winner = OnlineGroupMembers[math.random(#OnlineGroupMembers)]
                item = select(7,GetContainerItemInfo(i,j))
                table.insert(RollsText, winner .. " wins " .. item)
                
                if not Winners[winner] then
                    Winners[winner] = {item}
                else
                    table.insert(Winners[winner], item)
                end
            end
        end
    end

    if #RollsText == 1 then
        SendRollMessage(RollsText[1])
        RollsText = {}
    elseif #RollsText > 1 then
        RollingAll = true
        RollsIndex = #RollsText
        SendRollMessage(RollsText[RollsIndex])
    end
end

local AutoInviteButton = CreateFrame("Button", "AutoInviteButton", CrowSettings, "UIPanelButtonTemplate")
AutoInviteButton:SetSize(140, 30)
AutoInviteButton:SetText("Start Auto Invites")
AutoInviteButton:SetPoint("BOTTOM")
AutoInviteButton:SetScript("OnClick", function()
    if not AutoInviting and (IsInGroup() and IsPartyLeader() ~= 1 and not IsInRaid() or IsInRaid() and IsRaidLeader() ~= 1 and IsRaidOfficer() ~= 1) then
        print("Auto invite failed! You must be a group leader.")
        return
    end

    AutoInvitingTimer = 120
    AutoInviting = not AutoInviting
    AutoInviteButton:SetText(AutoInviting and "Stop Auto Invites" or "Start Auto Invites")

    if not AutoInviting then
        SendChatMessage("Crow's Cache invites have stopped!", "GUILD")
    elseif AutoInviting and CrowLocation and CrowTimer and CrowTimer > 0 then
        SendChatMessage("Crow's Cache is materializing in " .. CrowTimerMin .. " minute(s) in " .. CrowLocation .. ". Type \"inv\" for an invite! Must be " .. GetSpellLink("High-Risk (PVP)") .. GetSpellLink("Mercenary for Hire!") .. ".", "GUILD")
    else
        SendChatMessage("Crow's Cache invites have started! Type \"inv\" for an invite! Must be " .. GetSpellLink("High-Risk (PVP)") .. GetSpellLink("Mercenary for Hire!") .. ".", "GUILD")
    end
end)

RuleSetButton = CreateFrame("Button", nil, AutoInviteButton, "SecureActionButtonTemplate, UIPanelButtonTemplate")
RuleSetButton:SetSize(140, 30)
RuleSetButton:SetPoint("TOP", AutoInviteButton, 0, 28)
RuleSetButton:SetAttribute("type", "macro")
RuleSetButton.text = RuleSetButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
RuleSetButton.text:SetPoint("CENTER")
RuleSetButton.text:SetFont("Fonts\\FRIZQT__.TTF", 11)

RuleSetButton:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
RuleSetButton:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg2 == "High Risk (PvP)" then
        RuleSetButton.text:SetText("Mercenary Mode")
        RuleSetButton:SetAttribute("macrotext", "/cast Mercenary for Hire!")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg2 == "Mercenary for Hire!" then
        RuleSetButton.text:SetText("PVE Mode")
        RuleSetButton:SetAttribute("macrotext", "/cast PvE Mode")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg2 == "PvE Mode" then
        RuleSetButton.text:SetText("High Risk/Merc")
        RuleSetButton:SetAttribute("macrotext", "/cast High-Risk (PVP)\n/cast Mercenary for Hire!")
    end
end)

RegisterEvents(AutoInviteButton, "CHAT_MSG_GUILD", "PARTY_MEMBERS_CHANGED", "UI_INFO_MESSAGE")
AutoInviteButton:SetScript("OnEvent", function(self, event, ...)
    if AutoInviting and event == "CHAT_MSG_GUILD" and (string.lower(arg1) == "kawkaw" or string.lower(arg1) == "kaw" or string.lower(arg1) == "kaw kaw" or string.lower(arg1) == "crow" or string.lower(arg1) == "invite" or string.lower(arg1) == "inv" or string.lower(arg1) == "+") and (not IsInGroup() or IsRaidLeader() == 1 or IsRaidOfficer() == 1 or IsPartyLeader() == 1) then
        InviteUnit(arg2)

    elseif event == "PARTY_MEMBERS_CHANGED" then
        if AutoInviting then
            if not IsInRaid() and IsPartyLeader() == 1 then
                ConvertToRaid()
            end
        end

        if IsInGroup() then
            GroupMembers = {}
            for i = 1, GetNumGroupMembers() do
                if not IsInRaid() and UnitName("party" .. i) ~= nil then
                    GroupMembers[UnitName("party" .. i)] = true
                elseif IsInRaid() then
                    GroupMembers[UnitName("raid" .. i)] = true
                end
            end
        else
            GroupMembers = {}
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
    local WonSlots = {}

    for loot = 1, #Winners[TradingName] do
        ItemFound = false

        for i = 0, 5 do
            WonSlots[i] = WonSlots[i] or {}
            
            for j = 1, GetContainerNumSlots(i) do
                if not WonSlots[i][j] and GetContainerItemInfo(i,j) ~= nil and select(7,GetContainerItemInfo(i,j)) == Winners[TradingName][loot] then
                    UseContainerItem(i,j)
                    ItemFound = true
                    WonSlots[i][j] = true
                    break
                end
            end

            if ItemFound then
                break
            end
        end
    end

    if GetTradePlayerItemLink(1) ~= nil then
        AcceptTrade()
    end
end)

RegisterEvents(TradeRollButton, "TRADE_SHOW", "TRADE_CLOSED")
TradeRollButton:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SHOW" then
        if Winners[UnitName("NPC")] then
            TradingName = UnitName("NPC")
            TradeRollButton:Show()
        else
            TradeRollButton:Hide()
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
            CrowAlerts.text:SetText("Crow's Cache is materializing!\nLocation: |cFFFF0000" .. CrowLocation .. "|r\nTimer: |cFFFF0000" .. string.format("%02d:%02d", CrowTimerMin, CrowTimerSec) .. "|r")
        end
    end

    if ZoneChange then
        ZoneChangeTimer = ZoneChangeTimer - elapsed
        if ZoneChangeTimer <= 0 then
            ZoneChange = false
        end
    end

    if AutoInviting then
        AutoInvitingTimer = AutoInvitingTimer - elapsed
        if AutoInvitingTimer <= 0 then
            AutoInvitingTimer = 120

            if CrowLocation and CrowTimer and CrowTimer > 0 then
                SendChatMessage("Crow's Cache is materializing in " .. CrowTimerMin .. " minute(s) in " .. CrowLocation .. ". Type \"inv\" for an invite! Must be " .. GetSpellLink("High-Risk (PVP)") .. GetSpellLink("Mercenary for Hire!") .. ".", "GUILD")
            else
                SendChatMessage("Crow's Cache invites have started! Type \"inv\" for an invite! Must be " .. GetSpellLink("High-Risk (PVP)") .. GetSpellLink("Mercenary for Hire!") .. ".", "GUILD")
            end
        end
    end

    if RollingAll then
        RollsTimer = RollsTimer - elapsed
        if RollsTimer <= 0 then
            if RollsIndex == 1 then
                RollingAll = false
                RollsTimer = 1
                SendRollMessage("Trade with " .. UnitName("player") .. " if you won!")
                return
            end

            RollsTimer = 1
            RollsIndex = RollsIndex - 1
            SendRollMessage(RollsText[RollsIndex])
        end
    end
end)
