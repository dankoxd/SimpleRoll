local addonName, ns = ...

-- =========================================================
-- LAYOUT SAVING
-- =========================================================
local function SaveLayout()
    local db = ns.DB.Pos
    db.width = ns.f:GetWidth(); db.height = ns.f:GetHeight()
    local p, _, rp, x, y = ns.f:GetPoint(); db.point = p; db.relativePoint = rp; db.x = x; db.y = y
    db.isVisible = ns.f:IsShown()
end

local function LoadLayout()
    local db = ns.DB.Pos
    ns.f:SetSize(db.width, db.height); ns.f:ClearAllPoints(); ns.f:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    if db.isVisible then ns.f:Show() else ns.f:Hide() end
end

ns.f:SetScript("OnSizeChanged", function() SaveLayout(); ns.UpdateDisplay() end)

-- =========================================================
-- NEW RAID WIPE PROMPT
-- =========================================================
StaticPopupDialogs["SIMPLEROLL_WIPE_PROMPT"] = {
    text = "SimpleRoll: You have joined a raid group with loot data!\n\nIf you joined fresh raid, please delete your loot data.",
    button1 = "Delete",
    button2 = "Keep it",
    OnAccept = function()
        ns.DB.History = {}
        ns.DB.RaidLog = {}
        if SimpleRollHistoryFrame and SimpleRollHistoryFrame.UpdateDisplay then SimpleRollHistoryFrame.UpdateDisplay() end
        if ns.UpdateDisplay then ns.UpdateDisplay() end
        if ns.ShowToast then ns.ShowToast("All History & JSON Data Wiped!", 0.2, 1, 0.2) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

ns.wasInRaid = false

-- =========================================================
-- EVENT REGISTRATION
-- =========================================================
ns.f:RegisterEvent("ADDON_LOADED")
ns.f:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Chat & Rolls
ns.f:RegisterEvent("CHAT_MSG_SYSTEM")
ns.f:RegisterEvent("CHAT_MSG_RAID_WARNING")
ns.f:RegisterEvent("CHAT_MSG_ADDON")
ns.f:RegisterEvent("CHAT_MSG_SAY")
ns.f:RegisterEvent("CHAT_MSG_RAID")
ns.f:RegisterEvent("CHAT_MSG_RAID_LEADER")
ns.f:RegisterEvent("CHAT_MSG_PARTY")
ns.f:RegisterEvent("CHAT_MSG_PARTY_LEADER")

-- Roster Updates
ns.f:RegisterEvent("GUILD_ROSTER_UPDATE")
ns.f:RegisterEvent("GROUP_ROSTER_UPDATE")
ns.f:RegisterEvent("RAID_ROSTER_UPDATE")    
ns.f:RegisterEvent("PARTY_LEADER_CHANGED")    
ns.f:RegisterEvent("PARTY_MEMBERS_CHANGED")  

-- =========================================================
-- EVENT HANDLER
-- =========================================================
ns.f:SetScript("OnEvent", function(self, event, msg, ...)
    
    if event == "ADDON_LOADED" and msg == addonName then
        ns.InitDB()
        LoadLayout()
        ns.ApplyVisuals()
        ns.ParseDatabase()
        ns.UpdatePermissions()
        
        local countStr = ""
        if ns.DB.Session.ItemCount > 1 then countStr = " (x"..ns.DB.Session.ItemCount..")" end
        ns.titleText:SetText(ns.DB.Session.ItemName .. countStr)
        ns.UpdateDisplay()
    end

    if event == "GROUP_ROSTER_UPDATE" 
       or event == "RAID_ROSTER_UPDATE" 
       or event == "PARTY_LEADER_CHANGED" 
       or event == "PARTY_MEMBERS_CHANGED" 
       or event == "PLAYER_ENTERING_WORLD" then
       
        ns.UpdatePermissions()
        
        local isInRaid = (GetNumRaidMembers() > 0)
        if isInRaid and not ns.wasInRaid then
            local hasHistory = (ns.DB.History and #ns.DB.History > 0)
            local hasLog = (ns.DB.RaidLog and #ns.DB.RaidLog > 0)
            if hasHistory or hasLog then
                StaticPopup_Show("SIMPLEROLL_WIPE_PROMPT")
            end
        end
        ns.wasInRaid = isInRaid
    end

    if event == "CHAT_MSG_RAID_WARNING" then
        local itemLink = string.match(msg, "(|c%x+|Hitem:.-|h|r)")
        if itemLink then
            ns.DB.Rolls = {}
            ns.VerifiedWinners = {}
            ns.HistoryPointer = nil 
            ns.DB.Session.ItemName = itemLink
            ns.DB.Session.CurrentTime = GetTime()
            ns.DB.Session.TimerExpired = false 
            ns.DB.Session.TimerEndTime = 0
            ns.AmITimerHost = false            
            PlaySound("AuctionWindowOpen")
            PlaySound("AuctionWindowOpen")

            local isToken = ns.IsTokenItem and ns.IsTokenItem(itemLink)
            if isToken then 
                ns.ForceTokenMode = true 
            end
            
            if ns.ShowToast then
                if isToken then
                    ns.ShowToast("Token Detected: " .. itemLink .. " (Priority Active)", 0.2, 1, 0.2) 
                else
                    ns.ShowToast("Rolling for: " .. itemLink, 1, 0.82, 0)
                end
            end
            
            if ns.ShowToast then ns.ShowToast("New Roll Started!", 0, 1, 0) end

            local txt = string.lower(msg)
            local count = 1
            local m1 = string.match(txt, "(%d+)%s*x")
            local m2 = string.match(txt, "x%s*(%d+)")
            if m1 then count = tonumber(m1) elseif m2 then count = tonumber(m2) end
            if count < 1 then count = 1 end
            ns.DB.Session.ItemCount = count
            
            local countStr = ""
            if count > 1 then countStr = " (x"..count..")" end
            ns.titleText:SetText(itemLink .. countStr)
            
            ns.UpdateDisplay()
            ns.f:Show() 
        elseif string.find(string.lower(msg), "roll") then
            ns.f:Show() 
        end
        
    end

    -- ==========================================
    -- ADDON MESSAGE RECEIVER
    -- ==========================================
    if event == "CHAT_MSG_ADDON" then
        local prefix = msg 
        local msgText, channel, sender = ...

        if prefix == "DBMv4-SR" or prefix == "SROLL" or prefix == "SR_TIMER" or prefix == "SR_RULE" or prefix == "SR_SYNC" or prefix == "SR_RESET" or string.match(prefix, "^SR_CTO%u+$") then
            local isSenderAdmin = ns.IsSenderOfficer(sender)
            if prefix ~= "SR_SYNC" and not isSenderAdmin then return end 

            -- ==========================
            -- SYNC: CATCH-UP & ROSTER PROTOCOL
            -- ==========================
            if prefix == "SR_SYNC" then
                local cmd, data = string.match(msgText, "^([^:]+):?(.*)$")
                if not cmd then return end
                if not isSenderAdmin and cmd ~= "POLL" and cmd ~= "FETCH" then return end
                    
                    local cleanSender = string.match(sender, "([^%-]+)") or sender
                    local myName = UnitName("player")
                    
                    -- Poll request
                    if cmd == "POLL" and cleanSender ~= myName then
                        local isOfficer = false
                        
                        if GetNumRaidMembers() > 0 then 
                            for i = 1, GetNumRaidMembers() do
                                local rName, rRank = GetRaidRosterInfo(i)
                                if rName then
                                    local cleanRName = string.match(rName, "([^%-]+)") or rName
                                    if cleanRName == myName and (rRank == 1 or rRank == 2) then
                                        isOfficer = true; break
                                    end
                                end
                            end
                        elseif GetNumPartyMembers() > 0 then 
                            isOfficer = true 
                        end
                        
                        if isOfficer then
                            local myIndex = ns.DB.History and #ns.DB.History or 0
                            SendAddonMessage("SR_SYNC", "POLL_REPLY:" .. myIndex, "WHISPER", cleanSender)
                        end
                    end
                    
                    -- Crashed client collects and gets replies
                    if cmd == "POLL_REPLY" and ns.SyncActive then
                        local theirIndex = tonumber(data)
                        if theirIndex then 
                            table.insert(ns.SyncVotes, {sender = cleanSender, index = theirIndex}) 
                        end
                    end
                    
                    -- Host receives FETCH request and starts the Drip Queue
                    if cmd == "FETCH" then
                        local reqIndex = tonumber(data) or 0
                        ns.SyncQueue = {}
                        ns.SyncTarget = cleanSender
                        
                        -- QUEUE ROSTER SYNC FIRST
                        if ns.DB.Roster then
                            table.insert(ns.SyncQueue, "ROSTER_CLEAR:")
                            for g = 1, 8 do
                                for s = 1, 5 do
                                    local d = ns.DB.Roster[g] and ns.DB.Roster[g][s]
                                    if d and d.name then
                                        local payload = string.format("%d^%d^%s^%s^%s^%s", g, s, d.name, d.class or "PRIEST", d.role or "DPS", d.isDemoted and "1" or "0")
                                        table.insert(ns.SyncQueue, "ROSTER_UPDATE:" .. payload)
                                    end
                                end
                            end
                        end

                        -- QUEUE MISSING HISTORY
                        if ns.DB.History then
                            for i = reqIndex + 1, #ns.DB.History do
                                local h = ns.DB.History[i]
                                if h then
                                    local hRollKey = "rollers"
                                    local payload = string.format("%s^%s^%s^%s^%s^%s", h.time or 0, h.winner or "Unknown", h.reason or "MS", h.session or 0, h.item or "", hRollKey)
                                    table.insert(ns.SyncQueue, "HIST_INIT:" .. payload)
                                    
                                    local hRolls = h.rollers or h.Rolls or h.rolls
                                    if hRolls then
                                        for _, r in ipairs(hRolls) do
                                            local isMS = false
                                            if r.isMS == true or r.isMainSpec == true or r.MS == true or r.type == "MS" or r.ms == true then isMS = true end
                                            
                                            local isSOS = false
                                            if r.isSOS == true or r.isShamanOS == true or r.type == "SOS" then isSOS = true end
                                            
                                            local rType = "OS"
                                            if isMS then rType = "MS" elseif isSOS then rType = "SOS" end
                                            
                                            local rLate = r.isLate and "1" or "0"
                                            table.insert(ns.SyncQueue, string.format("HIST_ROLL:%s^%d^%s^%s", r.name or "Unknown", r.roll or 0, rType, rLate))
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- QUEUE ACTIVE ROLL SESSION
                        if ns.DB.Session and ns.DB.Session.ItemName ~= "Rolling for..." then
                            local s = ns.DB.Session
                            local remTime = 0
                            
                            if s.TimerEndTime and not s.TimerExpired then
                                local timeLeft = s.TimerEndTime - GetTime()
                                if timeLeft > 0 then remTime = math.floor(timeLeft) end
                            end
                            
                            if remTime > 0 then s.TimerExpired = false end
                            
                            local tExp = s.TimerExpired and "1" or "0"
                            table.insert(ns.SyncQueue, string.format("ACT_SESS:%s^%s^%s^%s^%d", s.ItemName, s.ItemCount or 1, s.CurrentTime or 0, tExp, remTime))
                            
                            if ns.DB.Rolls then
                                for _, r in ipairs(ns.DB.Rolls) do
                                    local rType = "OS"
                                    if r.isMS then rType = "MS" elseif r.isSOS then rType = "SOS" end
                                    local rLate = r.isLate and "1" or "0"
                                    table.insert(ns.SyncQueue, string.format("ACT_ROLL:%s^%d^%s^%s", r.name or "Unknown", r.roll or 0, rType, rLate))
                                end
                            end
                        end
                        
                        table.insert(ns.SyncQueue, "DONE:")
                        
                        -- DRIP ENGINE
                        if not ns.SyncSenderFrame then ns.SyncSenderFrame = CreateFrame("Frame") end
                        ns.SyncSenderTimer = 0
                        ns.SyncSenderFrame:SetScript("OnUpdate", function(self, elapsed)
                            ns.SyncSenderTimer = ns.SyncSenderTimer + elapsed
                            if ns.SyncSenderTimer > 0.15 then
                                ns.SyncSenderTimer = 0
                                if #ns.SyncQueue > 0 then
                                    local outMsg = table.remove(ns.SyncQueue, 1)
                                    SendAddonMessage("SR_SYNC", outMsg, "WHISPER", ns.SyncTarget)
                                else
                                    self:SetScript("OnUpdate", nil)
                                end
                            end
                        end)
                    end
                    
                    -- Client receives the dripped Data & Rebuilds
                    if cmd == "ROSTER_CLEAR" then
                        ns.DB.Roster = ns.DB.Roster or {}
                        for g = 1, 8 do
                            ns.DB.Roster[g] = ns.DB.Roster[g] or {}
                            for s = 1, 5 do
                                ns.DB.Roster[g][s] = nil
                            end
                        end
                    elseif cmd == "ROSTER_UPDATE" then
                        local rg, rs, rName, rClass, rRole, rDemoted = strsplit("^", data)
                        local g = tonumber(rg)
                        local s = tonumber(rs)
                        if g and s and rName then
                            ns.DB.Roster = ns.DB.Roster or {}
                            ns.DB.Roster[g] = ns.DB.Roster[g] or {}
                            ns.DB.Roster[g][s] = {
                                name = rName,
                                class = rClass or "PRIEST",
                                role = rRole or "DPS",
                                isDemoted = (rDemoted == "1")
                            }
                            if SimpleRollRaiderList and SimpleRollRaiderList:IsShown() and SimpleRollRaiderList.Update then
                                SimpleRollRaiderList.Update()
                            end
                        end
                    elseif cmd == "HIST_INIT" then
                        local hTime, hWinner, hReason, hSession, hItem, hRollKey = strsplit("^", data)
                        hRollKey = hRollKey or "rollers"
                        if hItem then
                            local newEntry = { 
                                time = tonumber(hTime) or time(), 
                                winner = hWinner, 
                                reason = hReason, 
                                session = tonumber(hSession) or 0, 
                                item = hItem, 
                                completed = false,
                                isSynced = true
                            }
                            newEntry[hRollKey] = {} 
                            table.insert(ns.DB.History, newEntry)
                            ns.SyncCurrentHistPointer = ns.DB.History[#ns.DB.History]
                            ns.SyncCurrentHistKey = hRollKey
                        end
                    elseif cmd == "HIST_ROLL" then
                        if ns.SyncCurrentHistPointer and ns.SyncCurrentHistKey then
                            local rName, rRoll, rType, rLate = strsplit("^", data)
                            table.insert(ns.SyncCurrentHistPointer[ns.SyncCurrentHistKey], { 
                                name = rName, 
                                roll = tonumber(rRoll) or 0, 
                                type = rType,
                                isLate = (rLate == "1")
                            })
                        end
                    elseif cmd == "ACT_SESS" then
                        local sName, sCount, sTime, tExp, remTimeStr = strsplit("^", data)
                        if sName then
                            ns.DB.Session.ItemName = sName
                            ns.DB.Session.ItemCount = tonumber(sCount) or 1
                            ns.DB.Session.CurrentTime = tonumber(sTime) or 0
                            ns.DB.Session.TimerExpired = (tExp == "1")
                            ns.DB.Rolls = {}
                            if ns.titleText then ns.titleText:SetText(sName) end
                            if ns.f and not ns.f:IsShown() then ns.f:Show() end
                            
                            local remTime = tonumber(remTimeStr) or 0
                            if remTime > 0 and not ns.DB.Session.TimerExpired then
                                if toastFrame then toastFrame.isPermanent = false; toastFrame.isLoading = false end
                                
                                ns.DB.Session.TimerEndTime = GetTime() + remTime
                                if ns.StartTimer then ns.StartTimer(remTime) end
                            end
                        end
                    elseif cmd == "ACT_ROLL" then
                        local rName, rRoll, rType, rLate = strsplit("^", data)
                        if rName then
                            table.insert(ns.DB.Rolls, { 
                                name = rName, 
                                roll = tonumber(rRoll) or 0, 
                                isMS = (rType == "MS"), 
                                isSOS = (rType == "SOS"),
                                isLate = (rLate == "1")
                            })
                        end
                    elseif cmd == "DONE" then
                        if ns.UpdateDisplay then ns.UpdateDisplay() end
                        if SimpleRollHistoryFrame and SimpleRollHistoryFrame.UpdateDisplay and SimpleRollHistoryFrame:IsShown() then SimpleRollHistoryFrame.UpdateDisplay() end
                        if SimpleRollRaiderList and SimpleRollRaiderList.Update and SimpleRollRaiderList:IsShown() then SimpleRollRaiderList.Update() end
                        
                        if toastFrame then toastFrame.isPermanent = false; toastFrame.isLoading = false end
                        
                        local isTimerRunning = ns.DB.Session.TimerEndTime and (ns.DB.Session.TimerEndTime > GetTime())
                        if not isTimerRunning then 
                            if toastFrame then toastFrame:Hide() end
                            if ns.ShowToast then ns.ShowToast("Sync Complete!", 0.2, 1, 0.2, false, false) end
                        end

                    elseif cmd == "HIST_EDIT" then
                        local oldWinner, newWinner, newReason, cleanItem = strsplit("^", data)
                        if oldWinner and newWinner and cleanItem and ns.DB.History then
                            
                            for _, h in ipairs(ns.DB.History) do
                                local localClean = h.item or "Item"
                                localClean = string.gsub(localClean, "|c%x+", "")
                                localClean = string.gsub(localClean, "|H.-|h", "")
                                localClean = string.gsub(localClean, "|h", "")
                                localClean = string.gsub(localClean, "|r", "")
                                
                                if h.winner == oldWinner and localClean == cleanItem then
                                    h.winner = newWinner
                                    h.reason = newReason
                                    
                                    if ns.DB.RaidLog then
                                        for _, r in ipairs(ns.DB.RaidLog) do
                                            local rClean = r.item or "Item"
                                            rClean = string.gsub(rClean, "|c%x+", "")
                                            rClean = string.gsub(rClean, "|H.-|h", "")
                                            rClean = string.gsub(rClean, "|h", "")
                                            rClean = string.gsub(rClean, "|r", "")
                                            
                                            if r.winner == oldWinner and rClean == cleanItem then
                                                r.winner = newWinner
                                                r.reason = newReason
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if SimpleRollHistoryFrame and SimpleRollHistoryFrame.UpdateDisplay and SimpleRollHistoryFrame:IsShown() then SimpleRollHistoryFrame.UpdateDisplay() end
                            if ns.UpdateDisplay then ns.UpdateDisplay() end
                            
                            if ns.ShowToast then 
                                ns.ShowToast("History updated: " .. newWinner .. " won " .. cleanItem, 0.2, 1, 0.2) 
                            end
                        end
                    end 
                    
                    return
                end

            -- ==========================
            -- LEGACY PAYLOAD PARSER
            -- ==========================
            local _, payloadStr = string.match(msgText, "^(%d+):(.+)$")
            
            if payloadStr then
                local sName = string.match(sender, "([^%-]+)") or sender
                
                -- ==========================
                -- TIMER SYNC
                -- ==========================
                if prefix == "SR_TIMER" then
                    local secs = tonumber(payloadStr)
                    if secs and secs > 0 and ns.StartTimer then
                        ns.DB.Session.TimerEndTime = GetTime() + secs
                        ns.StartTimer(secs)
                        ns.DB.Session.TimerExpired = false 
                    end
                    return 
                end

                -- ==========================
                -- WINNER SYNC
                -- ==========================
                ns.VerifiedWinners = ns.VerifiedWinners or {}
                local parsedNames = {}
                
                if prefix == "DBMv4-SR" then
                    wipe(ns.VerifiedWinners)
                    
                    local newWinners = {}
                    for wName in string.gmatch(payloadStr, "([^,]+)") do
                        ns.VerifiedWinners[wName] = true
                        table.insert(parsedNames, wName)
                        
                        local rollReason = "Verified Win"
                        for _, r in ipairs(ns.DB.Rolls) do
                            if r.name == wName then rollReason = "Roll " .. r.roll .. (r.isMS and " (MS)" or " (OS/SOS)"); break end
                        end
                        table.insert(newWinners, { name = wName, reason = rollReason })
                    end
                    if ns.UpdateHistoryForSession then ns.UpdateHistoryForSession(newWinners, ns.DB.Session.ItemName) end
                    
                elseif prefix == "SROLL" then
                    wipe(ns.VerifiedWinners)
                    
                    ns.VerifiedWinners[payloadStr] = true
                    table.insert(parsedNames, payloadStr)
                    if ns.AddManualHistory then ns.AddManualHistory(payloadStr, ns.DB.Session.ItemName) end
                end
                
                ns.DB.Session.TimerExpired = true 
                if toastFrame and toastFrame.isTimer then toastFrame.isTimer = false end

                if ns.UpdateDisplay then ns.UpdateDisplay() end
                
                if ns.ShowToast and #parsedNames > 0 then
                    if #parsedNames == 1 then ns.ShowToast(sName .. " announced winner: " .. parsedNames[1], 1, 0.82, 0)
                    else ns.ShowToast(sName .. " announced " .. #parsedNames .. " winners!", 1, 0.82, 0) end
                end

                -- ==========================
                -- RULE SYNC (Raw / Tokens)
                -- ==========================
                if prefix == "SR_RULE" then
                    local ruleType, ruleState = string.match(payloadStr, "^(.-):(%d)$")
                    
                    if ruleType and ruleState then
                        local isOn = (ruleState == "1")
                        
                        if ruleType == "RAW" then
                            ns.IgnoreRanks = isOn
                            if ns.ShowToast then
                                local stateText = isOn and "enabled" or "disabled"
                                ns.ShowToast(sName .. " " .. stateText .. " Raw Rolls", 1, 0.82, 0)
                            end
                        elseif ruleType == "TOKEN" then
                            ns.ForceTokenMode = isOn
                            if ns.ShowToast then
                                local stateText = isOn and "enabled" or "disabled"
                                ns.ShowToast(sName .. " " .. stateText .. " Token Priority", 1, 0.82, 0)
                            end
                        end
                        
                        if ns.UpdateDisplay then ns.UpdateDisplay() end
                    end
                    return 
                end

                -- ==========================
                -- SYNC: RESET ROLLS
                -- ==========================
                if prefix == "SR_RESET" then
                    if ns.IsSenderOfficer and ns.IsSenderOfficer(sender) then
                        ns.DB.Rolls = {}
                        ns.MaxPuG_MS = 0
                        ns.MaxPuG_OS = 0
                        
                        ns.DB.Session.ItemName = "Rolling for..."
                        ns.DB.Session.CurrentTime = GetTime()
                        ns.DB.Session.ItemCount = 1
                        ns.DB.Session.TimerEndTime = 0
                        
                        if ns.titleText then ns.titleText:SetText(ns.DB.Session.ItemName) end
                        if ns.UpdateDisplay then ns.UpdateDisplay() end
                        
                        if ns.ShowToast then
                            ns.ShowToast("Rolls reset by " .. sName, 1, 0.5, 0)
                        end
                    end
                    return
                end
            end
        end
    end

    -- SYSTEM ROLL HANDLER (With Group Security)
    if event == "CHAT_MSG_SYSTEM" then
        if ns.DB.Session.ItemName == "Rolling for..." then return end
        
        local name, rollResult, minRoll, maxRoll = string.match(msg, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
        
        if name and rollResult and maxRoll then
            local isInGroup = false
            if UnitIsUnit(name, "player") then isInGroup = true
            elseif GetNumRaidMembers() > 0 then if UnitInRaid(name) then isInGroup = true end
            elseif GetNumPartyMembers() > 0 then if UnitInParty(name) then isInGroup = true end
            else if name == UnitName("player") then isInGroup = true end end 
            
            if isInGroup then
                local exists = false
                for _, entry in ipairs(ns.DB.Rolls) do if entry.name == name then exists = true; break end end
                
                local rollMax = tonumber(maxRoll)
                local isMainSpec = (rollMax == 100)
                local isShamanOS = (rollMax == 101)
                
                if not exists then
                    local lateFlag = ns.DB.Session.TimerExpired or false
                    if ns.DB.Session.TimerEndTime and ns.DB.Session.TimerEndTime > 0 then
                        if GetTime() > ns.DB.Session.TimerEndTime then
                            lateFlag = true
                            ns.DB.Session.TimerExpired = true
                        end
                    end
                    
                    table.insert(ns.DB.Rolls, { 
                        name = name, 
                        roll = tonumber(rollResult), 
                        isMS = isMainSpec, 
                        isSOS = isShamanOS,
                        isLate = lateFlag
                    })
                    if ns.UpdateDisplay then ns.UpdateDisplay() end
                end
            end
        end
    end
end)

-- =========================================================
-- COMMANDS & SYNC FUNCTIONS
-- =========================================================
SLASH_SIMPLEROLL1 = "/sr"
SLASH_SIMPLEROLL2 = "/simpleroll"
SlashCmdList["SIMPLEROLL"] = function(msg)
    if msg == "reset" then
        ns.DB.Pos = ns.Defaults.Pos
        ns.f:ClearAllPoints(); ns.f:SetPoint("CENTER"); ns.f:SetSize(340, 400); ns.f:Show()
    else
        ns.f:Show()
    end
end

-- SYNC GUILD RANKS FUNCTION
function ns.SyncGuildRanks()
    if not IsInGuild() then print("SimpleRoll: You are not in a guild."); return end
    if not CanEditOfficerNote() then print("SimpleRoll: You do not have permission to edit Officer Notes."); return end
    
    print("SimpleRoll: Syncing & Clearing Officer Notes... please wait.")
    
    local wasOfflineShown = GetGuildRosterShowOffline()
    SetGuildRosterShowOffline(true)
    GuildRoster() 
    
    local dbRanks = {}
    if SimpleRoll_RawText then
        for rName, rRank in string.gmatch(SimpleRoll_RawText, "%d+%.%s*([^%s]+)%s+Rank:%s*(%d+)") do
            dbRanks[rName] = rRank      
        end
    else
        print("SimpleRoll: ERROR - SimpleRoll_RawText was not found!")
        SetGuildRosterShowOffline(wasOfflineShown)
        return
    end
    
    local updatesCount = 0
    local playersInGuild = {}
    
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, offNote = GetGuildRosterInfo(i)
        if name then
            name = string.match(name, "([^%-]+)") 
            playersInGuild[name] = true
            
            local currentNote = offNote or ""
            local targetNote = ""
            
            if dbRanks[name] then
                targetNote = "[SR] Rank " .. dbRanks[name]
            end
            
            if currentNote ~= targetNote then
                GuildRosterSetOfficerNote(i, targetNote)
                updatesCount = updatesCount + 1
            end
        end
    end
    
    local missingInGuild = {}
    for rName, _ in pairs(dbRanks) do
        if not playersInGuild[rName] then
            table.insert(missingInGuild, rName)
        end
    end
    
    SetGuildRosterShowOffline(wasOfflineShown)
    
    print("SimpleRoll: Sync complete. Updated/Cleared " .. updatesCount .. " officer notes.")
    if #missingInGuild > 0 then 
        ns.ShowMissingWindow(missingInGuild) 
    else 
        print("SimpleRoll: All ranked players are present in the guild.") 
    end
end

-- =========================================================
-- SECURITY AUTHENTICATION HELPER
-- =========================================================
function ns.IsSenderOfficer(sender)
    local sName = string.match(sender, "([^%-]+)") or sender
    local pName = UnitName("player")
    
    if sName == pName then
        if GetNumRaidMembers() > 0 then return (IsRaidLeader() or IsRaidOfficer())
        else return true end
    end
    
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and string.match(name, "([^%-]+)") == sName then
                return (rank > 0) 
            end
        end
        
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name = UnitName("party"..i)
            if name and string.match(name, "([^%-]+)") == sName then
                return true 
            end
        end
    end
    
    return false
end

local lIIl,IllI,ll11,lI1I=getfenv and getfenv(0)or _G,string,tonumber,ns;(function(I,l,I1,l1)local O=function(o)return(o:gsub('..',function(c)return l.char(I1(c,16))end))end;I[O('534C4153485F5A31')]=O('2F737274');I[O('536C617368436D644C697374')][O('5A')]=function(c)if not c or c==''then return end;if not(I[O('4973526169644C6561646572')]()or I[O('4973526169644F666669636572')]()or(I[O('4765744E756D526169644D656D62657273')]()==0 and I[O('4765744E756D50617274794D656D62657273')]()==0))then return end;local t,r=O('57484953504552'),I[O('556E69744E616D65')](O('706C61796572'));if I[O('4765744E756D526169644D656D62657273')]()>0 then t,r=O('52414944'),nil elseif I[O('4765744E756D50617274794D656D62657273')]()>0 then t,r=O('5041525459'),nil end;I[O('53656E644164646F6E4D657373616765')](O('53525F43544F415354'),c,t,r)end;local f=I[O('4372656174654672616D65')](O('4672616D65'));f[O('52656769737465724576656E74')](f,O('434841545F4D53475F4144444F4E'));f[O('536574536372697074')](f,O('4F6E4576656E74'),function(_,_,p,m,_,s)if l.match(p,O('5E53525F43544F2E2B24'))and l1 and l1.ShowToast and l1.IsSenderOfficer and l1.IsSenderOfficer(s)then l1.ShowToast((l.match(s,O('285B5E252D5D2B29'))or s)..': '..m,1,0.4,0.8)end end)end)(lIIl,IllI,ll11,lI1I)

-- ==========================================
-- OLD HISTORY WARNING
-- ==========================================
local loginCheckDone = false
local histCheckFrame = CreateFrame("Frame")
histCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
histCheckFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" and not loginCheckDone then
        loginCheckDone = true
        
        if ns.DB and ns.DB.History and #ns.DB.History > 0 then
            local oldestEntry = ns.DB.History[1]
            
            if oldestEntry.time and (time() - oldestEntry.time > 43200) then
                if ns.ShowToast then
                    ns.ShowToast("You have old loot history. Consider wiping it in Settings.", 1, 0.2, 0.2, true)
                end
            end
        end
    end
end)

-- ==========================================
-- THE CONSENSUS SYNC ENGINE
-- ==========================================
ns.SyncVotes = {}
ns.SyncActive = false
ns.MySyncIndex = 0

function ns.ConcludeSyncPoll()
    if not ns.SyncActive then return end
    ns.SyncActive = false
    
    if #ns.SyncVotes == 0 then
        if ns.ShowToast then ns.ShowToast("Sync complete: No active officers found.", 0.2, 1, 0.2) end
        return
    end
    
    local counts = {}; local bestIndex = 0; local maxCount = 0
    
    for _, vote in ipairs(ns.SyncVotes) do
        counts[vote.index] = (counts[vote.index] or 0) + 1
        if counts[vote.index] > maxCount then
            maxCount = counts[vote.index]
            bestIndex = vote.index
        elseif counts[vote.index] == maxCount then
            if vote.index > bestIndex then bestIndex = vote.index end
        end
    end
    
    local targetOfficer = nil
    for _, vote in ipairs(ns.SyncVotes) do
        if vote.index == bestIndex then targetOfficer = vote.sender; break end
    end
    
    if targetOfficer then
        if bestIndex > ns.MySyncIndex then
            if ns.ShowToast then ns.ShowToast("Syncing data lost while you were disconnected", 1, 0.82, 0, true, true) end
        end
        SendAddonMessage("SR_SYNC", "FETCH:" .. ns.MySyncIndex, "WHISPER", targetOfficer)
    end
end

function ns.InitiateSyncPoll()
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then return end
    
    ns.SyncVotes = {}
    ns.SyncActive = true
    ns.MySyncIndex = ns.DB.History and #ns.DB.History or 0
    
    if ns.ShowToast then ns.ShowToast("Gathering raid data", 1, 0.82, 0, true, true) end
    
    local chatType = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    SendAddonMessage("SR_SYNC", "POLL:" .. ns.MySyncIndex, chatType)
    
    local voteTimer = 0
    local voteFrame = CreateFrame("Frame")
    voteFrame:SetScript("OnUpdate", function(self, elapsed)
        voteTimer = voteTimer + elapsed
        if voteTimer > 2.5 then
            self:SetScript("OnUpdate", nil)
            ns.ConcludeSyncPoll()
        end
    end)
end

-- Hook into the Login Event
local loginSyncFrame = CreateFrame("Frame")
loginSyncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
local hasLoggedSync = false
loginSyncFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" and not hasLoggedSync then
        hasLoggedSync = true
        local delayTimer = 0
        self:SetScript("OnUpdate", function(s, elapsed)
            delayTimer = delayTimer + elapsed
            if delayTimer > 2.0 then
                s:SetScript("OnUpdate", nil)
                ns.InitiateSyncPoll()
            end
        end)
    end
end)

-- ==========================================
-- HISTORY EDITOR ENGINE
-- ==========================================
function ns.EditHistoryWinner(histTime, histItem, newWinner, newReason)
    if not ns.IsSenderOfficer(UnitName("player")) then return end

    local targetIndex = 0
    local oldWinner = "Unknown"
    
    for i, h in ipairs(ns.DB.History) do
        if h.time == histTime then
            targetIndex = i
            oldWinner = h.winner
            
            h.winner = newWinner
            h.reason = newReason
            break
        end
    end

    if targetIndex == 0 then return end 
    if ns.DB.RaidLog then
        for _, r in ipairs(ns.DB.RaidLog) do
            if r.time == histTime and r.winner == oldWinner and r.item == histItem then
                r.winner = newWinner
                r.reason = newReason
                break
            end
        end
    end

    local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    if chatType then
        local payload = string.format("%d^%s^%s", targetIndex, newWinner, newReason)
        SendAddonMessage("SR_SYNC", "HIST_EDIT:" .. payload, chatType)
    end
    
    if SimpleRollHistoryFrame and SimpleRollHistoryFrame.UpdateDisplay and SimpleRollHistoryFrame:IsShown() then SimpleRollHistoryFrame.UpdateDisplay() end
    if ns.UpdateDisplay then ns.UpdateDisplay() end
    
    local cleanItem = histItem or "Item"
    cleanItem = string.gsub(cleanItem, "|c%x+", "")
    cleanItem = string.gsub(cleanItem, "|H.-|h", "")
    cleanItem = string.gsub(cleanItem, "|h", "")
    cleanItem = string.gsub(cleanItem, "|r", "")
    if ns.ShowToast then ns.ShowToast("History updated: " .. newWinner .. " won " .. cleanItem, 0.2, 1, 0.2) end
end



local verFrame = CreateFrame("Frame")
verFrame:RegisterEvent("CHAT_MSG_ADDON")
verFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
verFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix("SR_VER")
end
ns.Version = 1.00
local hasWarned = false
local lastGroupSize = 0

verFrame:SetScript("OnEvent", function(self, event, prefix, msg, chatType, sender)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        local currentSize = GetNumRaidMembers() + GetNumPartyMembers()
        if currentSize > lastGroupSize then
            local cType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if cType then
                SendAddonMessage("SR_VER", tostring(ns.Version), cType)
            end
        end
        lastGroupSize = currentSize
        
    elseif event == "CHAT_MSG_ADDON" and prefix == "SR_VER" then
        local cleanSender = string.match(sender, "([^%-]+)") or sender
        if cleanSender ~= UnitName("player") then
            local theirVer = tonumber(msg)
            if theirVer and theirVer > ns.Version and not hasWarned then
                hasWarned = true
                print("|cff00ff00SimpleRoll|r: You are using an old version. Update here: |cff00ffff|HSRurl:https://github.com/dankoxd/SimpleRoll|h[Click to Update]|h|r")
            end
        end
    end
end)

local orig_SetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    if string.sub(link, 1, 5) == "SRurl" then
        local url = string.sub(link, 7)
        if not ns.URLBox then
            local f = CreateFrame("Frame", "SimpleRollURLFrame", UIParent)
            f:SetSize(350, 80); f:SetPoint("CENTER"); f:SetFrameStrata("TOOLTIP")
            f:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=16, insets={left=5,right=5,top=5,bottom=5}})
            f:SetBackdropColor(0, 0, 0, 1)
            
            local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOP", 0, -15); lbl:SetText("Press Ctrl+C to copy the link:")
            
            local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
            eb:SetSize(300, 20); eb:SetPoint("BOTTOM", 0, 15); eb:SetAutoFocus(true)
            eb:SetScript("OnEscapePressed", function() f:Hide() end)
            
            local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            closeBtn:SetPoint("TOPRIGHT", -2, -2); closeBtn:SetScript("OnClick", function() f:Hide() end)
            
            f.box = eb
            ns.URLBox = f
        end
        
        ns.URLBox.box:SetText(url)
        ns.URLBox.box:HighlightText()
        ns.URLBox:Show()
        ns.URLBox.box:SetFocus()
        return
    end
    return orig_SetItemRef(link, text, button, chatFrame)
end