local addonName, ns = ...

local C_TEXT = {1, 1, 1, 1}
local C_OS = {0.6, 0.6, 0.6, 1}
local C_SOS = {0.0, 0.7, 1.0, 1}
local rows = {}

local f = CreateFrame("Frame", "SimpleRollFrame", UIParent)
ns.f = f 
f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetResizable(true)
f:SetMinResize(320, 150); f:SetMaxResize(600, 900); f:SetClampedToScreen(true)
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local resizeBtn = CreateFrame("Button", nil, f); resizeBtn:SetSize(16, 16); resizeBtn:SetPoint("BOTTOMRIGHT")
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end); resizeBtn:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

-- ==========================================
-- REAL-TIME WINDOW RESIZING
-- ==========================================
f:SetScript("OnSizeChanged", function(self, width, height)
    if self.scrollFrame and content then
        local newWidth = self.scrollFrame:GetWidth()
        content:SetWidth(newWidth)
        if type(rows) == "table" then
            for _, row in pairs(rows) do
                if row then row:SetWidth(newWidth) end
            end
        end
    end
end)

f:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground", edgeFile="Interface\\ChatFrame\\ChatFrameBackground", edgeSize=2, insets={left=2,right=2,top=2,bottom=2}})
local headerBg = f:CreateTexture(nil, "BACKGROUND"); headerBg:SetPoint("TOPLEFT", 2, -2); headerBg:SetPoint("TOPRIGHT", -2, -2); headerBg:SetHeight(34)
ns.headerBg = headerBg
local headerLine = f:CreateTexture(nil, "OVERLAY"); headerLine:SetHeight(1); headerLine:SetPoint("TOPLEFT", 2, -36); headerLine:SetPoint("TOPRIGHT", -2, -36); headerLine:SetTexture(0.7, 0.6, 0, 0.5)

local footerBg = f:CreateTexture(nil, "BACKGROUND")
footerBg:SetHeight(30)
footerBg:SetPoint("BOTTOMLEFT", 2, 2)
footerBg:SetPoint("BOTTOMRIGHT", -2, 2)
footerBg:SetTexture(0, 0, 0, 0.9) 

local credits = f:CreateFontString(nil, "OVERLAY", "GameFontDarkGraySmall")
credits:SetPoint("RIGHT", footerBg, "RIGHT", -25, 0) 
credits:SetText("made by zombik")

f.scrollFrame = CreateFrame("ScrollFrame", "SimpleRollMainScroll", f, "UIPanelScrollFrameTemplate")
ns.scrollFrame = f.scrollFrame
f.scrollFrame:SetPoint("TOPLEFT", 6, -64); f.scrollFrame:SetPoint("BOTTOMRIGHT", -28, 32) 
local content = CreateFrame("Frame", nil, f.scrollFrame); content:SetSize(300, 1); f.scrollFrame:SetScrollChild(content)

-- ==========================================
-- PERMANENT SUB-HEADER STATUS BAR (Timer + Notifications)
-- ==========================================
local toastFrame = CreateFrame("Frame", nil, f)
toastFrame:SetHeight(24) 
toastFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -36) 
toastFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -36)
toastFrame:SetFrameLevel(f:GetFrameLevel() + 5)
toastFrame:Show() 

toastFrame.bg = toastFrame:CreateTexture(nil, "BACKGROUND")
toastFrame.bg:SetAllPoints(); toastFrame.bg:SetTexture(0, 0, 0, 0.4) 
toastFrame.line = toastFrame:CreateTexture(nil, "OVERLAY")
toastFrame.line:SetHeight(1); toastFrame.line:SetPoint("BOTTOMLEFT", 0, 0); toastFrame.line:SetPoint("BOTTOMRIGHT", 0, 0); toastFrame.line:SetTexture(0.5, 0.5, 0.5, 0.5)
toastFrame.icon = toastFrame:CreateTexture(nil, "OVERLAY")
toastFrame.icon:SetSize(16, 16); toastFrame.icon:SetPoint("LEFT", 6, 0); toastFrame.icon:SetTexture("Interface\\GossipFrame\\GossipGossipIcon"); toastFrame.icon:SetAlpha(1) 

local tText = toastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tText:SetPoint("TOPLEFT", toastFrame, "TOPLEFT", 26, -5) 
tText:SetJustifyH("LEFT") 
tText:SetJustifyV("TOP")
tText:SetWordWrap(true)
tText:SetHeight(0) 
toastFrame.text = tText

toastFrame.timer = 0; toastFrame.holdTime = 4.5 ; toastFrame.fadeTime = 2.0; toastFrame.isActive = false
toastFrame.isTimer = false; toastFrame.endTime = 0; toastFrame.rwBreakpoints = {}

toastFrame:SetScript("OnUpdate", function(self, elapsed)
    if self.isTimer then
        self.bg:SetAlpha(0.9); self.text:SetAlpha(1)
        local timeLeft = self.endTime - GetTime()
        
        if timeLeft > 0 then
            self.text:SetText("Rolls close in: " .. math.ceil(timeLeft) .. "s")
            self.text:SetTextColor(1, 0.82, 0) 
            if ns.AmITimerHost then
                local currentCeil = math.ceil(timeLeft)
                for i = #self.rwBreakpoints, 1, -1 do
                    if currentCeil == self.rwBreakpoints[i] then
                        SendChatMessage("Rolling ends in " .. self.rwBreakpoints[i] .. " seconds!", "RAID_WARNING")
                        table.remove(self.rwBreakpoints, i)
                        break
                    end
                end
            end
        else
            self.isTimer = false; self.text:SetText("Rolls Closed!"); self.text:SetTextColor(1, 0.2, 0.2) 
            if ns.AmITimerHost then SendChatMessage("Rolls are now CLOSED!", "RAID_WARNING"); ns.AmITimerHost = false end
            ns.DB.Session.TimerExpired = true 
            self.timer = 0; self.isActive = true 
        end
        return
    end

    if not self.isActive then return end

    -- Loading message animation
    if self.isLoading then
        self.dotTimer = self.dotTimer + elapsed
        if self.dotTimer > 0.5 then
            self.dotTimer = 0
            self.dotCount = (self.dotCount + 1) % 4
            local dots = string.rep(".", self.dotCount)
            self.text:SetText(self.baseText .. dots)
        end
        self.bg:SetAlpha(0.9); self.text:SetAlpha(1)
        return
    end

    if self.isPermanent then
        self.bg:SetAlpha(0.9)
        self.text:SetAlpha(1)
        return 
    end

    self.timer = self.timer + elapsed
    
    if self.timer < self.holdTime then
        self.bg:SetAlpha(0.9); self.text:SetAlpha(1)
    elseif self.timer < (self.holdTime + self.fadeTime) then
        local progress = (self.timer - self.holdTime) / self.fadeTime
        local fadeAlpha = 1 - progress
        self.text:SetAlpha(fadeAlpha); self.bg:SetAlpha(0.4 + (0.5 * fadeAlpha)) 
    else
        self.text:SetText(""); self.text:SetAlpha(0); self.bg:SetAlpha(0.4); self.isActive = false
        self.isPermanent = false
        self:SetHeight(24)
        if ns.scrollFrame then
            ns.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -64)
        end
    end
end)

function ns.ShowToast(msg, r, g, b, isPerm, isLoading)
    if ns.DB.Config.disableToasts then return end
    toastFrame.isTimer = false; ns.AmITimerHost = false
    
    local tWidth = toastFrame:GetWidth()
    if not tWidth or tWidth < 50 then 
        tWidth = f:GetWidth(); if not tWidth or tWidth < 50 then tWidth = 340 end 
    end
    
    toastFrame.text:SetWidth(tWidth - 36)
    toastFrame.text:SetText(msg)
    toastFrame.text:SetTextColor(r or 1, g or 0.82, b or 0)
    
    local textHeight = toastFrame.text:GetStringHeight()
    local newHeight = math.max(24, textHeight + 10) 
    toastFrame:SetHeight(newHeight)
    
    if ns.scrollFrame then
        local offsetDiff = newHeight - 24
        ns.scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -64 - offsetDiff)
    end
    
    toastFrame.timer = 0; toastFrame.bg:SetAlpha(0.9); toastFrame.text:SetAlpha(1); toastFrame.isActive = true
    toastFrame.isPermanent = isPerm or isLoading
    toastFrame.isLoading = isLoading
    toastFrame.baseText = msg
    toastFrame.dotTimer = 0
    toastFrame.dotCount = 0
end

function ns.StartTimer(seconds)
    toastFrame.isLoading = false
    toastFrame.isPermanent = false
    toastFrame.isTimer = true; toastFrame.isActive = false; toastFrame.endTime = GetTime() + seconds
    toastFrame.rwBreakpoints = {}
    
    local ceilSecs = math.ceil(seconds)
    table.insert(toastFrame.rwBreakpoints, ceilSecs)
    
    local idealPoints = {60, 45, 30, 15, 10, 5, 4, 3, 2, 1}
    for _, p in ipairs(idealPoints) do
        if ceilSecs > p then table.insert(toastFrame.rwBreakpoints, p) end
    end
end

-- 2. Helpers
function ns.ApplyVisuals()
    if not ns.DB then return end
    f:SetBackdropColor(unpack(ns.DB.Config.bgColor))
    f:SetBackdropBorderColor(unpack(ns.DB.Config.borderColor))
    headerBg:SetTexture(unpack(ns.DB.Config.headerColor))
    
    if ns.DB.Config.windowScale then
        f:SetScale(ns.DB.Config.windowScale)
    end
    
    if ns.UpdateDisplay then ns.UpdateDisplay() end
end

function ns.GetRemainingTime()
    if toastFrame and toastFrame.isTimer and toastFrame.endTime then
        local rem = toastFrame.endTime - GetTime()
        return rem > 0 and rem or 0
    end
    return 0
end

local hf, hRows, hContent
local HIST_ROW_HEIGHT = 20

function ns.UpdateHistoryForSession(newWinners, itemLink)
    local timestamp = time()
    local i = 1
    while i <= #ns.DB.History do if ns.DB.History[i].session == ns.DB.Session.CurrentTime then table.remove(ns.DB.History, i) else i = i + 1 end end
    
    if not ns.DB.RaidLog then ns.DB.RaidLog = {} end
    local j = 1
    while j <= #ns.DB.RaidLog do if ns.DB.RaidLog[j].session == ns.DB.Session.CurrentTime then table.remove(ns.DB.RaidLog, j) else j = j + 1 end end

    local snapshotRollers = {}
    for _, r in ipairs(ns.DB.Rolls) do
        local info = ns.GetRollerInfo(r.name)
        local rnk = info and info.rank or -1 
        local rol = info and info.role or "DPS"
        local rollType = "OS"
        if r.isMS then rollType = "MS" elseif r.isSOS then rollType = "SOS" end
        table.insert(snapshotRollers, { name = r.name, roll = r.roll, type = rollType, rank = rnk, role = rol })
    end 

    for _, winData in ipairs(newWinners) do
        local entry = { session = ns.DB.Session.CurrentTime, time = timestamp, winner = winData.name, item = itemLink, reason = winData.reason, completed = false, rollers = snapshotRollers }
        
        table.insert(ns.DB.History, entry)
        if not ns.DB.Config.disableJSON then 
            table.insert(ns.DB.RaidLog, entry) 
        end
    end
    if hf and hf:IsShown() then hf.UpdateDisplay() end
end

function ns.AddManualHistory(winnerName, itemLink)
    if not ns.DB.RaidLog then ns.DB.RaidLog = {} end

    local entry = { session = ns.DB.Session.CurrentTime, time = time(), winner = winnerName, item = itemLink, reason = "Manual/Other Rule", completed = false }
    
    table.insert(ns.DB.History, entry)
    if not ns.DB.Config.disableJSON then 
        table.insert(ns.DB.RaidLog, entry) 
    end
    
    if hf and hf:IsShown() then hf.UpdateDisplay() end
end


local function GetRow(index)
    if not rows[index] then
        local row = CreateFrame("Frame", nil, content); row:SetSize(200, 28)
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row)
        
        row.pos = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.pos:SetPoint("LEFT", 4, 0); row.pos:SetWidth(25); row.pos:SetJustifyH("LEFT")
        
        row.roleIcon = row:CreateTexture(nil, "OVERLAY")
        row.roleIcon:SetSize(16, 16)
        row.roleIcon:SetPoint("LEFT", row.pos, "RIGHT", 2, 0)
        row.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        
        row.winBtn = CreateFrame("Button", nil, row); row.winBtn:SetSize(16, 16); row.winBtn:SetPoint("RIGHT", -4, 0)
        row.winBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); row.winBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        row.winBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Forced Win"); GameTooltip:Show() end)
        row.winBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        row.roll = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        row.roll:SetPoint("RIGHT", row.winBtn, "LEFT", -10, 0); row.roll:SetJustifyH("RIGHT")
        
        row.crown = row:CreateTexture(nil, "OVERLAY")
        row.crown:SetSize(16, 16); row.crown:SetPoint("RIGHT", row.roll, "LEFT", -5, 0); row.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon"); row.crown:Hide() 
        
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        row.name:SetPoint("LEFT", row.roleIcon, "RIGHT", 4, 0); row.name:SetPoint("RIGHT", row.crown, "LEFT", -5, 0)
        row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
        
        rows[index] = row
    end
    return rows[index]
end

ns.UpdateDisplay = function()
    if not ns.DB then return end
    local isHistory = (ns.HistoryPointer ~= nil)
    local displayRolls = ns.DB.Rolls
    local displayTitle = ns.DB.Session.ItemName
    local displayCount = ns.DB.Session.ItemCount
    local histData = nil
    
    if isHistory then
        histData = ns.DB.History[ns.HistoryPointer]
        displayRolls = histData.rollers or {}
        
        local tagText = histData.isSynced and "(Synced)" or "(History)"
        displayTitle = (histData.item or "Unknown Item") .. " |cff888888" .. tagText .. "|r"
        
        displayCount = 1
        if ns.HistoryPointer == 1 then ns.prevBtn:Disable() else ns.prevBtn:Enable() end
        ns.nextBtn:Enable()
    else
        if not ns.DB.History or #ns.DB.History == 0 then ns.prevBtn:Disable() else ns.prevBtn:Enable() end
        ns.nextBtn:Disable()
        ns.MaxPuG_MS = 0; ns.MaxPuG_OS = 0
        for _, data in ipairs(ns.DB.Rolls) do
            local info = ns.GetRollerInfo(data.name)
            if info == nil then 
                if data.isMS then if data.roll > ns.MaxPuG_MS then ns.MaxPuG_MS = data.roll end
                else if data.roll > ns.MaxPuG_OS then ns.MaxPuG_OS = data.roll end end
            end
        end
        
        table.sort(ns.DB.Rolls, ns.SortRolls)
    end
    
    local countStr = ""
    if displayCount > 1 then countStr = " (x"..displayCount..")" end
    if ns.titleText then ns.titleText:SetText(displayTitle .. countStr) end
    
    local numEntries = #displayRolls
    local rowH = ns.DB.Config.rowHeight
    local contentHeight = numEntries * rowH
    if contentHeight < 1 then contentHeight = 1 end
    content:SetSize(f.scrollFrame:GetWidth(), contentHeight)
    
    for _, row in pairs(rows) do row:Hide() end
    for i, data in ipairs(displayRolls) do
        local row = GetRow(i)
        row.crown:Hide(); row:SetHeight(rowH); row:SetWidth(f.scrollFrame:GetWidth()); 
        local font, _, flags = row.name:GetFont()
        row.name:SetFont(font, ns.DB.Config.fontSize, flags); row.pos:SetFont(font, ns.DB.Config.fontSize, flags); row.roll:SetFont(font, ns.DB.Config.fontSize, flags)
row:SetPoint("TOPLEFT", 0, -(i-1)*rowH); row:Show()
        if i % 2 == 0 then row.bg:SetTexture(0.25, 0.25, 0.25, 0.6) else row.bg:SetTexture(0.15, 0.15, 0.15, 0.6) end
        row.pos:SetText(i)
        
        local playerRole = "DPS"
        if isHistory then
            playerRole = data.role or "DPS"
        else
            local info = ns.GetRollerInfo(data.name)
            if info and info.role then playerRole = info.role end
        end
        
        if playerRole == "TANK" then 
            row.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64) 
        elseif playerRole == "HEALER" then 
            row.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64) 
        else 
            row.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64) 
        end
        
        local isMS, isSOS = data.isMS, data.isSOS
        if isHistory then 
            isMS = (data.type == "MS") or data.isMS
            isSOS = (data.type == "SOS") or data.isSOS 
        end
        
        local classHex = "ffffffff"
        local rollerInfo = ns.GetRollerInfo(data.name)
        
        if rollerInfo and rollerInfo.class then 
            classHex = ns.GetClassHex(rollerInfo.class)
        else
            local _, engClass = UnitClass(data.name)
            if engClass then classHex = ns.GetClassHex(engClass) end
        end
        
        local nameStr = "|c" .. classHex .. data.name .. "|r"
        
        if isHistory then
            if data.rank and data.rank > 0 then nameStr = nameStr .. " |cffaaaaff(Rank " .. data.rank .. ")|r"
            elseif data.rank == 0 then nameStr = nameStr .. " |cffaaaaff(Rank 0)|r"
            else nameStr = nameStr .. " |cff888888(PuG)|r" end
        else
            if not ns.IgnoreRanks then
                if rollerInfo then
                    if rollerInfo.rank > 0 then nameStr = nameStr .. " |cffaaaaff(Rank " .. rollerInfo.rank .. ")|r" else nameStr = nameStr .. " |cffaaaaff(Rank 0)|r" end
                else nameStr = nameStr .. " |cff888888(PuG)|r" end
            end
        end
        
        if isHistory then
            if histData and histData.winner == data.name then row.crown:Show() end
        else
            if (ns.VerifiedWinners and ns.VerifiedWinners[data.name]) or (ns.PinnedWinners and ns.PinnedWinners[data.name]) then row.crown:Show() end
        end
        if data.isLate then nameStr = nameStr .. " |cffff0000(LATE)|r" end
        row.name:SetText(nameStr)
        
        if ns.IgnoreRanks and not isHistory then
            row.roll:SetText(data.roll); row.roll:SetTextColor(unpack(C_TEXT))
        else
            if isMS then row.roll:SetText(data.roll .. " (MS)"); row.roll:SetTextColor(unpack(C_TEXT))
            elseif isSOS then row.roll:SetText(data.roll .. " |cff00b2ff(SOS)|r"); row.roll:SetTextColor(unpack(C_SOS))
            else row.roll:SetText(data.roll .. " |cff999999(OS)|r"); row.roll:SetTextColor(unpack(C_OS)) end
        end
        
        row.winBtn:SetScript("OnClick", function() 
            if not (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) then return end
            
            if isHistory then
                local histData = ns.DB.History[ns.HistoryPointer]
                if histData and ns.EditHistoryWinner then
                    ns.EditHistoryWinner(histData.time, histData.item, data.name, "Manual Reassign")
                end
            else
                local msg = "[SR] " .. data.name .. " won by other rule " .. ns.DB.Session.ItemName
                ns.VerifiedWinners = ns.VerifiedWinners or {}
                wipe(ns.VerifiedWinners)
                ns.VerifiedWinners[data.name] = true
                
                if ns.AddManualHistory then ns.AddManualHistory(data.name, ns.DB.Session.ItemName) end
                if ns.UpdateDisplay then ns.UpdateDisplay() end 
                
                local chatType = "SAY"
                if GetNumRaidMembers() > 0 then chatType = "RAID" elseif GetNumPartyMembers() > 0 then chatType = "PARTY" end
                SendChatMessage(msg, chatType)
                
                local sessionID = tostring(math.floor(ns.DB.Session.CurrentTime))
                local payload = sessionID .. ":" .. data.name
                if chatType == "RAID" or chatType == "PARTY" then SendAddonMessage("DBMv4-SR", payload, chatType)
                else SendAddonMessage("DBMv4-SR", payload, "WHISPER", UnitName("player")) end
            end
        end)

        local isEffectiveAdmin = (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) and not ns.HideAdmin
        if isEffectiveAdmin then row.winBtn:Show() else row.winBtn:Hide() end
        
        row.name:SetTextColor(1, 1, 1, 1)
        
        if i <= displayCount then
            row.pos:SetTextColor(unpack(ns.DB.Config.winnerColor)); row.roll:SetTextColor(unpack(ns.DB.Config.winnerColor)) 
        else
            row.pos:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

ns.HistoryPointer = nil
local prevBtn = CreateFrame("Button", nil, f)
ns.prevBtn = prevBtn
prevBtn:SetSize(20, 20); prevBtn:SetPoint("TOPLEFT", 8, -10)
prevBtn:SetNormalFontObject("GameFontHighlightLarge"); prevBtn:SetHighlightFontObject("GameFontNormalLarge"); prevBtn:SetDisabledFontObject("GameFontDisableLarge")
prevBtn:SetText("<")
prevBtn:SetScript("OnClick", function()
    if not ns.DB.History or #ns.DB.History == 0 then return end
    if ns.HistoryPointer == nil then ns.HistoryPointer = #ns.DB.History
    elseif ns.HistoryPointer > 1 then ns.HistoryPointer = ns.HistoryPointer - 1 end
    ns.UpdateDisplay(); ns.UpdatePermissions()
end)

local nextBtn = CreateFrame("Button", nil, f)
ns.nextBtn = nextBtn
nextBtn:SetSize(20, 20); nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
nextBtn:SetNormalFontObject("GameFontHighlightLarge"); nextBtn:SetHighlightFontObject("GameFontNormalLarge"); nextBtn:SetDisabledFontObject("GameFontDisableLarge")
nextBtn:SetText(">")
nextBtn:SetScript("OnClick", function()
    if ns.HistoryPointer == nil then return end
    if ns.HistoryPointer < #ns.DB.History then ns.HistoryPointer = ns.HistoryPointer + 1
    else ns.HistoryPointer = nil end 
    ns.UpdateDisplay(); ns.UpdatePermissions()
end)

local titleBtn = CreateFrame("Button", nil, f)
titleBtn:SetSize(150, 20); titleBtn:SetPoint("LEFT", nextBtn, "RIGHT", 5, 0) 
local titleText = titleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT"); titleText:SetJustifyH("LEFT"); titleText:SetText("Rolling for..."); titleText:SetTextColor(1, 0.82, 0, 1)
titleBtn:SetFontString(titleText)
ns.titleText = titleText
titleBtn:SetScript("OnEnter", function(self)
    local linkToShow = ns.DB.Session.ItemName
    if ns.HistoryPointer and ns.DB.History and ns.DB.History[ns.HistoryPointer] then linkToShow = ns.DB.History[ns.HistoryPointer].item end
    if linkToShow and linkToShow ~= "Rolling for..." then GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); GameTooltip:SetHyperlink(linkToShow); GameTooltip:Show() end
end)
titleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local closeBtn = CreateFrame("Button", nil, f)
closeBtn:SetSize(22, 22); closeBtn:SetPoint("TOPRIGHT", -6, -6)
closeBtn:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeSize = 1 })
closeBtn:SetBackdropColor(0.4, 0, 0, 1); closeBtn:SetBackdropBorderColor(0.5, 0, 0, 1)
local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); closeText:SetPoint("CENTER"); closeText:SetText("X")
closeBtn:SetScript("OnClick", function() f:Hide() end)

local menuBtn = CreateFrame("Button", nil, f)
ns.menuBtn = menuBtn 
menuBtn:SetSize(24, 24)
menuBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)

-- hamburger
local function CreateMenuLine(yOffset)
    local line = menuBtn:CreateTexture(nil, "ARTWORK")
    line:SetSize(14, 2)
    line:SetTexture(1, 1, 1, 1)
    line:SetPoint("CENTER", 0, yOffset)
    return line
end

menuBtn.lineTop = CreateMenuLine(5)
menuBtn.lineMid = CreateMenuLine(0)
menuBtn.lineBot = CreateMenuLine(-5)

menuBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

menuBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Menu"); GameTooltip:Show() end)
menuBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
menuBtn:SetScript("OnClick", function() ns.ToggleMenu() end)

menuBtn:SetScript("OnMouseDown", function(self)
    self.lineTop:SetPoint("CENTER", 1, 4)
    self.lineMid:SetPoint("CENTER", 1, -1)
    self.lineBot:SetPoint("CENTER", 1, -6)
end)
menuBtn:SetScript("OnMouseUp", function(self)
    self.lineTop:SetPoint("CENTER", 0, 5)
    self.lineMid:SetPoint("CENTER", 0, 0)
    self.lineBot:SetPoint("CENTER", 0, -5)
end)

local announceBtn = CreateFrame("Button", nil, f)
ns.announceBtn = announceBtn 
announceBtn:SetSize(24, 24); announceBtn:SetPoint("RIGHT", menuBtn, "LEFT", -5, 0)
announceBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up"); announceBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
announceBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Announce Winner"); GameTooltip:Show() end)
announceBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
announceBtn:SetScript("OnClick", function() 
    toastFrame.isTimer = false; ns.AmITimerHost = false
    table.sort(ns.DB.Rolls, ns.SortRolls) 
    
    if #ns.DB.Rolls == 0 then print("|cff00ff00SimpleRoll|r: No rolls to report."); return end
    
    local chatType = "SAY"
    if GetNumRaidMembers() > 0 then chatType = "RAID" elseif GetNumPartyMembers() > 0 then chatType = "PARTY" end
    
    local msg = "[SR] Winners: "
    local isToken = ns.ForceTokenMode or ns.IsTokenItem(ns.DB.Session.ItemName)
    local winnersForHistory = {}

local foundCount = 0
    for i = 1, #ns.DB.Rolls do
        local entry = ns.DB.Rolls[i]
        if not (ns.VerifiedWinners and ns.VerifiedWinners[entry.name]) then
            foundCount = foundCount + 1
            if foundCount > ns.DB.Session.ItemCount then break end 
            
            if foundCount > 1 then msg = msg .. ", " end
            
            local info = ns.GetRollerInfo(entry.name)
            local reasonText = ""
            local winText = ""
            
            if entry.isMS then
                local rankStr = "PuG"; local rankVal = 0
                if info then rankStr = "Rank "..info.rank; rankVal = info.rank end
                
                local usedTokenRule = false
                local prioTag = ""
                
                if isToken and info then
                    if info.role == "TANK" then 
                        usedTokenRule = true
                        prioTag = "TankPrio"
                    elseif info.role == "HEALER" then 
                        usedTokenRule = true
                        prioTag = "HealPrio"
                    end
                end
                
                if usedTokenRule then
                    winText = entry.name .. " (" .. rankStr .. ", " .. prioTag .. ")"
                    reasonText = "Rank " .. rankVal .. " + " .. prioTag
                else
                    winText = entry.name .. " (" .. rankStr .. ", " .. entry.roll .. ")"
                    reasonText = "Rank " .. rankVal .. " + Roll " .. entry.roll
                end
            else
                winText = entry.name .. " (" .. entry.roll .. ")"
                reasonText = "Roll " .. entry.roll .. " (OS/SOS)"
            end
            
            msg = msg .. foundCount .. ". " .. winText
            table.insert(winnersForHistory, { name = entry.name, reason = reasonText })
        end
    end
    
    if #winnersForHistory > 0 then
        ns.VerifiedWinners = ns.VerifiedWinners or {}
        wipe(ns.VerifiedWinners)
        local winnerNames = {}
        for _, w in ipairs(winnersForHistory) do 
            table.insert(winnerNames, w.name) 
            ns.VerifiedWinners[w.name] = true
        end
        
        ns.UpdateHistoryForSession(winnersForHistory, ns.DB.Session.ItemName)
        if ns.UpdateDisplay then ns.UpdateDisplay() end 
        
        local sessionID = tostring(math.floor(ns.DB.Session.CurrentTime))
        local payload = sessionID .. ":" .. table.concat(winnerNames, ",")
        
        if chatType == "RAID" or chatType == "PARTY" then SendAddonMessage("DBMv4-SR", payload, chatType)
        else SendAddonMessage("DBMv4-SR", payload, "WHISPER", UnitName("player")) end
    end
    SendChatMessage(msg, chatType)
end)

-- RANK TOGGLE BUTTON (Raw Rolls)
local rankToggleBtn = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
ns.rankToggleBtn = rankToggleBtn 
rankToggleBtn:SetSize(24, 24) 
rankToggleBtn:SetPoint("LEFT", f, "BOTTOMLEFT", 5, 17) 
rankToggleBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Toggle Raw Rolls"); GameTooltip:Show() end)
rankToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
rankToggleBtn:SetScript("OnClick", function(self) 
    ns.IgnoreRanks = self:GetChecked(); ns.UpdateDisplay() 
    local chatType = "WHISPER"; local target = UnitName("player")
    if GetNumRaidMembers() > 0 then chatType = "RAID"; target = nil elseif GetNumPartyMembers() > 0 then chatType = "PARTY"; target = nil end
    local stateStr = ns.IgnoreRanks and "1" or "0" 
    SendAddonMessage("SR_RULE", "1:RAW:" .. stateStr, chatType, target)
end)

-- TOKEN TOGGLE BUTTON (Force Token)
local tokenToggleBtn = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
ns.tokenToggleBtn = tokenToggleBtn
tokenToggleBtn:SetSize(24, 24)
tokenToggleBtn:SetPoint("LEFT", rankToggleBtn, "RIGHT", 5, 0) 
tokenToggleBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Force Token Priority"); GameTooltip:Show() end)
tokenToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
tokenToggleBtn:SetScript("OnClick", function(self) 
    ns.ForceTokenMode = self:GetChecked(); ns.UpdateDisplay() 
    local chatType = "WHISPER"; local target = UnitName("player")
    if GetNumRaidMembers() > 0 then chatType = "RAID"; target = nil elseif GetNumPartyMembers() > 0 then chatType = "PARTY"; target = nil end
    local stateStr = ns.ForceTokenMode and "1" or "0" 
    SendAddonMessage("SR_RULE", "1:TOKEN:" .. stateStr, chatType, target)
end)
tokenToggleBtn:SetScript("OnUpdate", function(self)
    if not ns.DB then return end 
    if ns.IsTokenItem(ns.DB.Session.ItemName) then
        self:SetChecked(true); self:Disable()
    else
        self:Enable()
        if not ns.ForceTokenMode then self:SetChecked(false) end
    end
end)

-- ADMIN VIEW TOGGLE
local adminToggleBtn = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
ns.adminToggleBtn = adminToggleBtn
adminToggleBtn:SetSize(26, 26); adminToggleBtn:SetChecked(false) 
ns.HideAdmin = true

adminToggleBtn.lbl = adminToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
adminToggleBtn.lbl:SetPoint("RIGHT", adminToggleBtn, "LEFT", -2, 0)
adminToggleBtn.lbl:SetText("Admin")
adminToggleBtn.lbl:SetTextColor(0.5, 0.5, 0.5)

adminToggleBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Toggle Admin Controls"); GameTooltip:Show() end)
adminToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
adminToggleBtn:SetScript("OnClick", function(self) 
    ns.HideAdmin = not self:GetChecked()
    if self:GetChecked() then
        self.lbl:SetTextColor(1, 0.82, 0)
    else
        self.lbl:SetTextColor(0.5, 0.5, 0.5)
    end
    
    ns.UpdatePermissions()
    if ns.UpdateDisplay then ns.UpdateDisplay() end
end)


-- ==========================================
-- TIMER CONTROLS (DYNAMICALLY ANCHORED)
-- ==========================================
local timerBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
ns.timerBtn = timerBtn
timerBtn:SetSize(80, 22)
timerBtn:SetPoint("LEFT", tokenToggleBtn, "RIGHT", 15, 0) 
timerBtn:SetText("Start Timer")

local timerBox = CreateFrame("EditBox", "SimpleRollTimerInput", f, "InputBoxTemplate")
ns.timerBox = timerBox
timerBox:SetSize(25, 20)
timerBox:SetPoint("LEFT", timerBtn, "RIGHT", 8, 0)
timerBox:SetAutoFocus(false); timerBox:SetNumeric(true); timerBox:SetMaxLetters(2); timerBox:SetText("15") 

timerBtn:SetScript("OnClick", function()
    local secs = tonumber(timerBox:GetText())
    if not secs or secs <= 0 then return end
    if not (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) then return end
    
    local sessionID = "1"; local payload = sessionID .. ":" .. secs
    local chatType = "WHISPER"; local target = UnitName("player")
    if GetNumRaidMembers() > 0 then chatType = "RAID"; target = nil elseif GetNumPartyMembers() > 0 then chatType = "PARTY"; target = nil end
    
    SendAddonMessage("SR_TIMER", payload, chatType, target)
    ns.AmITimerHost = true 
end)

-- 4. Permissions Updater
ns.UpdatePermissions = function()
    local isActuallyAuthorized = false
    if GetNumRaidMembers() > 0 then
        isActuallyAuthorized = IsRaidLeader() or IsRaidOfficer()
    elseif GetNumPartyMembers() > 0 then
        isActuallyAuthorized = IsPartyLeader()
    end
    
    local isHistory = (ns.HistoryPointer ~= nil)
    local isEffectiveAdmin = isActuallyAuthorized and not ns.HideAdmin
    
    local lastBtn = ns.menuBtn
    
    if isActuallyAuthorized and not isHistory then 
        ns.adminToggleBtn:Show()
        ns.adminToggleBtn:SetPoint("RIGHT", lastBtn, "LEFT", -5, 0)
        
        lastBtn = ns.adminToggleBtn.lbl 
    else 
        ns.adminToggleBtn:Hide() 
    end
    
    if isEffectiveAdmin and not isHistory then 
        ns.announceBtn:Show()
        ns.announceBtn:SetPoint("RIGHT", lastBtn, "LEFT", -10, 0) 
        lastBtn = ns.announceBtn
        
        -- Show the footer controls
        if ns.rankToggleBtn then ns.rankToggleBtn:Show() end
        if ns.tokenToggleBtn then ns.tokenToggleBtn:Show() end
        if ns.timerBtn then ns.timerBtn:Show() end
        if ns.timerBox then ns.timerBox:Show() end
    else 
        ns.announceBtn:Hide()
        
        -- Hide the footer controls
        if ns.rankToggleBtn then ns.rankToggleBtn:Hide() end
        if ns.tokenToggleBtn then ns.tokenToggleBtn:Hide() end
        if ns.timerBtn then ns.timerBtn:Hide() end
        if ns.timerBox then ns.timerBox:Hide() end
    end
end

-- Hook Roster Updates to auto-hide permissions
local tEventFrame = CreateFrame("Frame")
tEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
tEventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
tEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
tEventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
tEventFrame:SetScript("OnEvent", ns.UpdatePermissions)

-- WINDOW FOR MISSING PLAYERS
function ns.ShowMissingWindow(missingList)
    local f = CreateFrame("Frame", "SimpleRollMissingFrame", UIParent)
    f:SetSize(400, 300); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(true); f.bg:SetTexture(0, 0, 0, 0.9)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -5, -5)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOP", 0, -10); f.title:SetText("Missing from Guild")
    
    local sf = CreateFrame("ScrollFrame", "SimpleRollMissingScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 20, -40); sf:SetPoint("BOTTOMRIGHT", -40, 20)
    local content = CreateFrame("EditBox", nil, sf)
    content:SetMultiLine(true); content:SetFontObject(ChatFontNormal); content:SetWidth(320); content:SetAutoFocus(false)
    content:SetScript("OnEscapePressed", function() f:Hide() end)
    
    sf:SetScrollChild(content)
    content:SetText(table.concat(missingList, " ")); content:HighlightText() 
    f:Show()
end

local menuFrame, raidPopup, adminToolsFrame

ns.ToggleAdminTools = function()
    if not adminToolsFrame then
        adminToolsFrame = CreateFrame("Frame", "SimpleRollAdminTools", UIParent)
        adminToolsFrame:SetSize(200, 160); adminToolsFrame:SetPoint("CENTER"); adminToolsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        adminToolsFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
        adminToolsFrame:SetBackdropColor(0,0,0,1)
        
        local closeBtn = CreateFrame("Button", nil, adminToolsFrame, "UIPanelCloseButton"); closeBtn:SetPoint("TOPRIGHT", -2, -2); closeBtn:SetScript("OnClick", function() adminToolsFrame:Hide() end)
        local title = adminToolsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -15); title:SetText("Admin Tools")
        
        local function CreateATBtn(text, yOffset, func)
            local b = CreateFrame("Button", nil, adminToolsFrame, "UIPanelButtonTemplate")
            b:SetSize(140, 25); b:SetPoint("TOP", 0, yOffset); b:SetText(text)
            b:SetScript("OnClick", function() func(); adminToolsFrame:Hide() end)
            return b
        end
        
        CreateATBtn("Start JSON logging", -45, function()
            if not raidPopup then
                raidPopup = CreateFrame("Frame", nil, UIParent)
                raidPopup:SetSize(300, 120); raidPopup:SetPoint("CENTER"); raidPopup:SetFrameStrata("FULLSCREEN_DIALOG")
                raidPopup:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=16, insets={left=5,right=5,top=5,bottom=5}})
                raidPopup:SetBackdropColor(0,0,0,1)
                raidPopup.lbl = raidPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal"); raidPopup.lbl:SetPoint("TOP", 0, -15); raidPopup.lbl:SetText("Enter Raid Name:")
                raidPopup.edit = CreateFrame("EditBox", nil, raidPopup, "InputBoxTemplate"); raidPopup.edit:SetSize(180, 20); raidPopup.edit:SetPoint("TOP", 0, -40); raidPopup.edit:SetAutoFocus(true)
                raidPopup.ok = CreateFrame("Button", nil, raidPopup, "UIPanelButtonTemplate"); raidPopup.ok:SetSize(80, 22); raidPopup.ok:SetPoint("BOTTOMLEFT", 40, 15); raidPopup.ok:SetText("Start")
                raidPopup.ok:SetScript("OnClick", function() 
                    local name = raidPopup.edit:GetText(); if name == "" then name = "Raid " .. date("%Y-%m-%d") end
                    ns.StartNewRaid(name); raidPopup:Hide()
                end)
                raidPopup.cancel = CreateFrame("Button", nil, raidPopup, "UIPanelButtonTemplate"); raidPopup.cancel:SetSize(80, 22); raidPopup.cancel:SetPoint("BOTTOMRIGHT", -40, 15); raidPopup.cancel:SetText("Cancel")
                raidPopup.cancel:SetScript("OnClick", function() raidPopup:Hide() end)
            end
            raidPopup.edit:SetText("ICC " .. date("%Y-%m-%d")); raidPopup:Show()
        end)
        
        CreateATBtn("Export JSON", -75, function()
            if not ef then
                ef = CreateFrame("Frame", nil, UIParent); ef:SetSize(400,300); ef:SetPoint("CENTER"); ef:SetFrameStrata("FULLSCREEN_DIALOG")
                ef:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); ef:SetBackdropColor(0,0,0,1)
                local ec = CreateFrame("Button",nil,ef,"UIPanelCloseButton"); ec:SetPoint("TOPRIGHT",-5,-5); ec:SetScript("OnClick", function() ef:Hide() end)
                local es = CreateFrame("ScrollFrame","SRExp",ef,"UIPanelScrollFrameTemplate"); es:SetPoint("TOPLEFT",10,-10); es:SetPoint("BOTTOMRIGHT",-30,10)
                local eb = CreateFrame("EditBox",nil,es); eb:SetMultiLine(true); eb:SetSize(360,280); eb:SetFontObject(ChatFontNormal); es:SetScrollChild(eb)
                eb:SetScript("OnTextChanged", function(s,u) if u then s:SetText(s.last); s:HighlightText() else s.last=s:GetText() end end); eb:SetScript("OnEscapePressed", function() ef:Hide() end)
                ef.box = eb
            end
            ef.box:SetText(ns.GenerateJSON()); ef.box:HighlightText(); ef.box:SetFocus(); ef:Show()
        end)
        
        CreateATBtn("Sync Guild Note Ranks", -105, function() ns.SyncGuildRanks() end)
    end
    
    if adminToolsFrame:IsShown() then adminToolsFrame:Hide() else adminToolsFrame:Show() end
end

ns.ToggleMenu = function()
    if not menuFrame then
        menuFrame = CreateFrame("Frame", nil, f)
        menuFrame:SetSize(120, 140); menuFrame:SetPoint("TOPRIGHT", menuBtn, "BOTTOMRIGHT", 0, -5); menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        menuFrame:EnableMouse(true); menuFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1})
        menuFrame:SetBackdropColor(0,0,0,0.95); menuFrame:SetBackdropBorderColor(0.5,0.5,0.5,1); menuFrame:Hide()
        
        local function CreateMenuBtn(text, func)
            local b = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate"); b:SetSize(110, 22); b:SetText(text)
            b:SetScript("OnClick", function() func(); menuFrame:Hide() end); b:SetFrameLevel(menuFrame:GetFrameLevel() + 10); return b
        end
        
        menuFrame.btnHistory = CreateMenuBtn("Loot History", ns.ToggleHistory)
        menuFrame.btnRaider = CreateMenuBtn("Raider List", ns.ToggleRaiderList)
        menuFrame.btnAdminTools = CreateMenuBtn("Admin Tools", ns.ToggleAdminTools)
        menuFrame.btnReset = CreateMenuBtn("Reset Rolls", function()
            if not (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) then return end
            local chatType = "WHISPER"
            local target = UnitName("player")
            if GetNumRaidMembers() > 0 then chatType = "RAID"; target = nil
            elseif GetNumPartyMembers() > 0 then chatType = "PARTY"; target = nil end
            SendAddonMessage("SR_RESET", "1:wipe", chatType, target)
            ns.ToggleMenu() 
        end)
        menuFrame.btnSettings = CreateMenuBtn("Settings", ns.ToggleSettings)
    end
    
    if menuFrame:IsShown() then
        menuFrame:Hide()
    else
        local isAuthorized = (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0)) and not ns.HideAdmin
        menuFrame.btnHistory:SetPoint("TOP", 0, -5)
        if isAuthorized then
            menuFrame:SetHeight(140)
            menuFrame.btnRaider:Show(); menuFrame.btnRaider:SetPoint("TOP", menuFrame.btnHistory, "BOTTOM", 0, -5)
            menuFrame.btnAdminTools:Show(); menuFrame.btnAdminTools:SetPoint("TOP", menuFrame.btnRaider, "BOTTOM", 0, -5)
            menuFrame.btnReset:Show(); menuFrame.btnReset:SetPoint("TOP", menuFrame.btnAdminTools, "BOTTOM", 0, -5)
            menuFrame.btnSettings:SetPoint("TOP", menuFrame.btnReset, "BOTTOM", 0, -5)
        else
            -- Raiders see a shorter menu
            menuFrame:SetHeight(85) 
            menuFrame.btnRaider:Show(); menuFrame.btnRaider:SetPoint("TOP", menuFrame.btnHistory, "BOTTOM", 0, -5)
            menuFrame.btnAdminTools:Hide(); menuFrame.btnReset:Hide()
            menuFrame.btnSettings:SetPoint("TOP", menuFrame.btnRaider, "BOTTOM", 0, -5)
        end
        menuFrame:Show()
    end
end

local rlf, ef, DragGhost

-- ==========================================
-- HISTORY EDITOR POPUP
-- ==========================================
local histEditPopup
function ns.ShowHistEdit(hTime, hItem, oldWinner)
    if not histEditPopup then
        histEditPopup = CreateFrame("Frame", nil, UIParent)
        histEditPopup:SetSize(300, 120); histEditPopup:SetPoint("CENTER"); histEditPopup:SetFrameStrata("FULLSCREEN_DIALOG")
        histEditPopup:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=16, insets={left=5,right=5,top=5,bottom=5}})
        histEditPopup:SetBackdropColor(0,0,0,1)
        
        histEditPopup.lbl = histEditPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        histEditPopup.lbl:SetPoint("TOP", 0, -15)
        
        histEditPopup.edit = CreateFrame("EditBox", nil, histEditPopup, "InputBoxTemplate")
        histEditPopup.edit:SetSize(180, 20); histEditPopup.edit:SetPoint("TOP", 0, -40); histEditPopup.edit:SetAutoFocus(true)
        histEditPopup.edit:SetScript("OnEscapePressed", function() histEditPopup:Hide() end)
        
        histEditPopup.ok = CreateFrame("Button", nil, histEditPopup, "UIPanelButtonTemplate")
        histEditPopup.ok:SetSize(80, 22); histEditPopup.ok:SetPoint("BOTTOMLEFT", 40, 15); histEditPopup.ok:SetText("Save")
        
        histEditPopup.cancel = CreateFrame("Button", nil, histEditPopup, "UIPanelButtonTemplate")
        histEditPopup.cancel:SetSize(80, 22); histEditPopup.cancel:SetPoint("BOTTOMRIGHT", -40, 15); histEditPopup.cancel:SetText("Cancel")
        histEditPopup.cancel:SetScript("OnClick", function() histEditPopup:Hide() end)
    end
    
    histEditPopup.lbl:SetText("New winner for " .. (hItem or "Item") .. ":")
    histEditPopup.edit:SetText(oldWinner or "")
    histEditPopup.edit:HighlightText()
    
    histEditPopup.ok:SetScript("OnClick", function()
        local newName = histEditPopup.edit:GetText()
        if newName and newName ~= "" then
            if ns.EditHistoryWinner then ns.EditHistoryWinner(hTime, hItem, newName, "Manual Reassign") end
            histEditPopup:Hide()
        end
    end)
    
    histEditPopup.edit:SetScript("OnEnterPressed", function() histEditPopup.ok:Click() end)
    histEditPopup:Show()
end

ns.ToggleHistory = function()
    if not hf then
        hf = CreateFrame("Frame", "SimpleRollHistoryFrame", UIParent); hf:SetSize(500, 400); hf:SetPoint("CENTER"); hf:SetFrameStrata("DIALOG"); hf:SetMovable(true); hf:EnableMouse(true); hf:SetResizable(true); hf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); hf:SetBackdropColor(0,0,0,0.95); hf:SetBackdropBorderColor(0.6,0.6,0.6,1)
        hf:SetScript("OnDragStart", hf.StartMoving); hf:SetScript("OnDragStop", hf.StopMovingOrSizing)
        local hTitle = hf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); hTitle:SetPoint("TOP", 0, -10); hTitle:SetText("Loot History")
        local hClose = CreateFrame("Button", nil, hf, "UIPanelCloseButton"); hClose:SetPoint("TOPRIGHT", 0, 0); hClose:SetScript("OnClick", function() hf:Hide() end)
        local hClear = CreateFrame("Button", nil, hf, "UIPanelButtonTemplate"); hClear:SetSize(80, 22); hClear:SetPoint("TOPLEFT", 10, -10); hClear:SetText("Clear"); hClear:SetScript("OnClick", function() ns.DB.History = {}; hf.UpdateDisplay() end)
        local hScroll = CreateFrame("ScrollFrame", "SimpleRollHistoryScroll", hf, "UIPanelScrollFrameTemplate"); hScroll:SetPoint("TOPLEFT", 10, -40); hScroll:SetPoint("BOTTOMRIGHT", -30, 20); hContent = CreateFrame("Frame", nil, hScroll); hContent:SetSize(1,1); hScroll:SetScrollChild(hContent)
        local hResize = CreateFrame("Button", nil, hf); hResize:SetSize(16,16); hResize:SetPoint("BOTTOMRIGHT"); hResize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); hResize:SetScript("OnMouseDown", function() hf:StartSizing("BOTTOMRIGHT") end); hResize:SetScript("OnMouseUp", function() hf:StopMovingOrSizing() end)
        hRows = {}
        hf.UpdateDisplay = function()
            local data = ns.DB.History or {}
            hContent:SetSize(hScroll:GetWidth(), #data * HIST_ROW_HEIGHT)
            for _, r in pairs(hRows) do r:Hide() end
            
            local isEffectiveAdmin = (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) and not ns.HideAdmin
            
            for i, entry in ipairs(data) do
                if not hRows[i] then
                    local r = CreateFrame("Frame", nil, hContent); r:SetSize(450, HIST_ROW_HEIGHT)
                    
                    r.del = CreateFrame("Button", nil, r); r.del:SetSize(16,16); r.del:SetPoint("LEFT"); r.del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.del:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                    r.chk = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.chk:SetSize(20,20); r.chk:SetPoint("LEFT", r.del, "RIGHT", 2, 0)
                    
                    r.editBtn = CreateFrame("Button", nil, r)
                    r.editBtn:SetSize(16, 16)
                    r.editBtn:SetPoint("LEFT", r.chk, "RIGHT", 4, 0)
                    r.editBtn:SetNormalTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
                    r.editBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                    r.editBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Reassign Winner"); GameTooltip:Show() end)
                    r.editBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    
                    r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); 
                    r.txt:SetPoint("LEFT", r.editBtn, "RIGHT", 5, 0); r.txt:SetPoint("RIGHT", 0, 0); r.txt:SetJustifyH("LEFT")
                    hRows[i] = r
                end
                
                local r = hRows[i]; r:SetPoint("TOPLEFT", 0, -(i-1)*HIST_ROW_HEIGHT); r:SetWidth(hScroll:GetWidth()); r:Show()
                r.txt:SetText(date("%H:%M", entry.time).." " .. entry.winner .. " won " .. (entry.item or "?") .. " ("..entry.reason..")")
                r.chk:SetChecked(entry.completed); r.chk:SetScript("OnClick", function(s) entry.completed = s:GetChecked() end)
                r.del:SetScript("OnClick", function() table.remove(ns.DB.History, i); hf.UpdateDisplay() end)
                
                r.editBtn:SetScript("OnClick", function() ns.ShowHistEdit(entry.time, entry.item, entry.winner) end)
                
                if isEffectiveAdmin then
                    r.del:Show(); r.editBtn:Show()
                    r.chk:SetPoint("LEFT", r.del, "RIGHT", 2, 0)
                    r.txt:SetPoint("LEFT", r.editBtn, "RIGHT", 5, 0)
                else
                    r.del:Hide(); r.editBtn:Hide()
                    r.chk:SetPoint("LEFT", r, "LEFT", 4, 0)
                    r.txt:SetPoint("LEFT", r.chk, "RIGHT", 5, 0)
                end
            end
        end
        hf:SetScript("OnShow", hf.UpdateDisplay); hf:SetScript("OnSizeChanged", function() if hf:IsShown() then hf.UpdateDisplay() end end)
        hf:Hide()
    end
    if hf:IsShown() then hf:Hide() else hf:Show() end
end

ns.ToggleRaiderList = function()
    if not rlf then
        rlf = CreateFrame("Frame", "SimpleRollRaiderList", UIParent)
        rlf:SetSize(420, 540); rlf:SetPoint("CENTER"); rlf:SetFrameStrata("DIALOG"); rlf:SetMovable(true); rlf:EnableMouse(true); rlf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); rlf:SetBackdropColor(0,0,0,0.95); rlf:SetBackdropBorderColor(0.5,0.5,0.5,1)
        rlf:SetScript("OnDragStart", rlf.StartMoving); rlf:SetScript("OnDragStop", rlf.StopMovingOrSizing)
        local rlClose = CreateFrame("Button", nil, rlf, "UIPanelCloseButton"); rlClose:SetPoint("TOPRIGHT",0,0); rlClose:SetScript("OnClick", function() rlf:Hide() end)
        local rlTitle = rlf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); rlTitle:SetPoint("TOP",0,-10); rlTitle:SetText("Raider List")
        local DraggingInfo = { active = false }
        DragGhost = CreateFrame("Frame", nil, UIParent); DragGhost:SetSize(100,20); DragGhost:SetFrameStrata("TOOLTIP"); DragGhost:Hide(); DragGhost.t = DragGhost:CreateFontString(nil,"OVERLAY","GameFontNormal"); DragGhost.t:SetPoint("CENTER")
        DragGhost:SetScript("OnUpdate", function(s) local x,y = GetCursorPosition(); local sc = UIParent:GetEffectiveScale(); s:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/sc, y/sc) end)
        
        local SlotButtons = {}
        for g=1,8 do
            SlotButtons[g] = {}
            local gf = CreateFrame("Frame", nil, rlf); gf:SetSize(190, 100)
            local col = (g-1)%2; local row = math.floor((g-1)/2); gf:SetPoint("TOPLEFT", 15+(col*200), -60-(row*115))
            gf.t = gf:CreateFontString(nil, "OVERLAY", "GameFontNormal"); gf.t:SetPoint("TOP",0,15); gf.t:SetText("Group "..g)
            for s=1,5 do
                local b = CreateFrame("Button", nil, gf); b:SetSize(180,18); b:SetPoint("TOP",0,-5-((s-1)*19))
                b.bg = b:CreateTexture(nil,"BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetTexture(0.1,0.1,0.1,0.4)
                
                b.roleIcon = CreateFrame("Button", nil, b); b.roleIcon:SetSize(16, 16); b.roleIcon:SetPoint("LEFT", 2, 0)
                b.roleIcon.tex = b.roleIcon:CreateTexture(nil, "OVERLAY"); b.roleIcon.tex:SetAllPoints(); b.roleIcon.tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
                
                b.demoteBtn = CreateFrame("Button", nil, b); b.demoteBtn:SetSize(20, 16); b.demoteBtn:SetPoint("RIGHT", -2, 0)
                b.demoteBtn.text = b.demoteBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.demoteBtn.text:SetPoint("CENTER")

                b.t = b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.t:SetPoint("LEFT", b.roleIcon, "RIGHT", 4, 0); b.t:SetPoint("RIGHT", b.demoteBtn, "LEFT", -4, 0); b.t:SetJustifyH("CENTER")
                
                b:RegisterForClicks("LeftButtonUp","RightButtonUp")
                b.g = g; b.s = s; SlotButtons[g][s] = b
            end
        end

        local editPopup = CreateFrame("EditBox", nil, rlf, "InputBoxTemplate"); editPopup:SetSize(130, 20); editPopup:Hide(); editPopup:SetAutoFocus(true)
        editPopup:SetScript("OnEnterPressed", function(box)
            local val = box:GetText(); if val and val ~= "" then ns.DB.Roster[box.g][box.s] = { name = val, class = "PRIEST", role = "DPS", isDemoted = false }; rlf.Update() end
            box:Hide()
        end)
        editPopup:SetScript("OnEscapePressed", function(box) box:Hide() end)

        local btnScan = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnScan:SetSize(100,25); btnScan:SetPoint("BOTTOMLEFT",20,10); btnScan:SetText("Scan")
        btnScan:SetScript("OnClick", function() ns.ScanRaidToRoster(); rlf.Update() end)

local btnSync = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate")
        btnSync:SetSize(80, 25); btnSync:SetPoint("BOTTOM", 0, 10); btnSync:SetText("Sync")
        btnSync.cdTimer = 0
        
        btnSync:SetScript("OnUpdate", function(self, elapsed)
            if self.cdTimer > 0 then
                self.cdTimer = self.cdTimer - elapsed
                if self.cdTimer <= 0 then
                    self:Enable()
                    self:SetText("Sync")
                else
                    self:SetText(math.ceil(self.cdTimer))
                end
            end
        end)
        
        btnSync:SetScript("OnClick", function(self)
            if not (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0)) then return end
            if self.cdTimer > 0 then return end
            
            self.cdTimer = 10
            self:Disable()
            
            local chatType = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
            
            SendAddonMessage("SR_SYNC", "ROSTER_CLEAR:", chatType)
            
            ns.GlobalSyncQueue = {}
            for g = 1, 8 do
                for s = 1, 5 do
                    local d = ns.DB.Roster[g][s]
                    if d and d.name then
                        local payload = string.format("%d^%d^%s^%s^%s^%s", g, s, d.name, d.class or "PRIEST", d.role or "DPS", d.isDemoted and "1" or "0")
                        table.insert(ns.GlobalSyncQueue, "ROSTER_UPDATE:" .. payload)
                    end
                end
            end
            table.insert(ns.GlobalSyncQueue, "DONE:")
            
            if not ns.GlobalSyncFrame then ns.GlobalSyncFrame = CreateFrame("Frame") end
            ns.GlobalSyncTimer = 0
            ns.GlobalSyncFrame:SetScript("OnUpdate", function(f, elapsed)
                ns.GlobalSyncTimer = ns.GlobalSyncTimer + elapsed
                if ns.GlobalSyncTimer > 0.15 then
                    ns.GlobalSyncTimer = 0
                    if #ns.GlobalSyncQueue > 0 then
                        local outMsg = table.remove(ns.GlobalSyncQueue, 1)
                        SendAddonMessage("SR_SYNC", outMsg, chatType)
                    else
                        f:SetScript("OnUpdate", nil)
                    end
                end
            end)
            
            if ns.ShowToast then ns.ShowToast("Syncing Roster to Raid...", 1, 0.82, 0) end
        end)

        local btnExp = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnExp:SetSize(100,25); btnExp:SetPoint("BOTTOMRIGHT",-20,10); btnExp:SetText("Export")
        btnExp:SetScript("OnClick", function()
            if not ef then
                ef = CreateFrame("Frame", nil, UIParent); ef:SetSize(400,300); ef:SetPoint("CENTER"); ef:SetFrameStrata("FULLSCREEN_DIALOG"); ef:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); ef:SetBackdropColor(0,0,0,1)
                local ec = CreateFrame("Button",nil,ef,"UIPanelCloseButton"); ec:SetPoint("TOPRIGHT",-5,-5); ec:SetScript("OnClick", function() ef:Hide() end)
                local es = CreateFrame("ScrollFrame","SRExp",ef,"UIPanelScrollFrameTemplate"); es:SetPoint("TOPLEFT",10,-10); es:SetPoint("BOTTOMRIGHT",-30,10)
                local eb = CreateFrame("EditBox",nil,es); eb:SetMultiLine(true); eb:SetSize(360,280); eb:SetFontObject(ChatFontNormal); es:SetScrollChild(eb)
                eb:SetScript("OnTextChanged", function(s,u) if u then s:SetText(s.last); s:HighlightText() else s.last=s:GetText() end end); eb:SetScript("OnEscapePressed", function() ef:Hide() end)
                ef.box = eb
            end
            local str = ""
            for g=1,8 do
                local t = {}
                for s=1,5 do if ns.DB.Roster[g][s] then table.insert(t, ns.DB.Roster[g][s].name) end end
                if #t > 0 then str = str .. "Group "..g..": "..table.concat(t, " ").."\n" end
            end
            ef.box:SetText(str); ef.box:HighlightText(); ef.box:SetFocus(); ef:Show()
        end)

        local btnClear = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnClear:SetSize(80,22); btnClear:SetPoint("TOPRIGHT",-30,-10); btnClear:SetText("Clear")
        btnClear:SetScript("OnClick", function() for g=1,8 do for s=1,5 do ns.DB.Roster[g][s] = nil end end; rlf.Update() end)

        rlf.Update = function()
            ns.ValidateRoster()
            local isAuthorized = (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0)) and not ns.HideAdmin
            if isAuthorized then btnScan:Show(); btnClear:Show(); btnSync:Show() else btnScan:Hide(); btnClear:Hide(); btnSync:Hide() end

            for g=1,8 do for s=1,5 do
                local d = ns.DB.Roster[g][s]; local b = SlotButtons[g][s]
                if not isAuthorized then
                    b:SetScript("OnMouseDown", nil); b:SetScript("OnMouseUp", nil); b.roleIcon:SetScript("OnClick", nil); b.demoteBtn:SetScript("OnClick", nil)
                else
                    b.roleIcon:SetScript("OnClick", function()
                        if not ns.DB.Roster[g][s] then return end
                        local current = ns.DB.Roster[g][s].role or "DPS"
                        if current == "DPS" then ns.DB.Roster[g][s].role = "TANK" elseif current == "TANK" then ns.DB.Roster[g][s].role = "HEALER" else ns.DB.Roster[g][s].role = "DPS" end
                        rlf.Update()
                    end)
                    b.demoteBtn:SetScript("OnClick", function()
                        if not ns.DB.Roster[g][s] then return end
                        ns.DB.Roster[g][s].isDemoted = not ns.DB.Roster[g][s].isDemoted; rlf.Update()
                    end)
                    b:SetScript("OnMouseDown", function(self, button)
                        if button=="LeftButton" and ns.DB.Roster[g][s] then DraggingInfo = { active=true, g=g, s=s, data=ns.DB.Roster[g][s] }; DragGhost.t:SetText(DraggingInfo.data.name); DragGhost:Show(); self.t:SetAlpha(0.3) end
                    end)
                    b:SetScript("OnMouseUp", function(self, button)
                        if DraggingInfo.active then
                            DraggingInfo.active = false; DragGhost:Hide(); SlotButtons[DraggingInfo.g][DraggingInfo.s].t:SetAlpha(1)
                            local target = GetMouseFocus()
                            if target and target.g and target.s then
                                local tg, ts = target.g, target.s; local temp = ns.DB.Roster[tg][ts]
                                ns.DB.Roster[tg][ts] = DraggingInfo.data; ns.DB.Roster[DraggingInfo.g][DraggingInfo.s] = temp; rlf.Update()
                            end
                        else
                            if button=="RightButton" then ns.DB.Roster[g][s] = nil; rlf.Update()
                            elseif button=="LeftButton" then
                                editPopup:ClearAllPoints(); editPopup:SetPoint("CENTER", self, "CENTER", 0, 0); editPopup:SetFrameLevel(self:GetFrameLevel()+5)
                                editPopup.g = g; editPopup.s = s; local d = ns.DB.Roster[g][s]; editPopup:SetText(d and d.name or ""); editPopup:Show(); editPopup:SetFocus()
                            end
                        end
                    end)
                end

                if d and d.name then 
                    b.t:SetText("|c"..ns.GetClassHex(d.class)..d.name.."|r")
                    b.bg:SetTexture(0.3,0.3,0.3,0.6); b.roleIcon:Show()
                    local role = d.role or "DPS"
                    if role == "TANK" then b.roleIcon.tex:SetTexCoord(0, 19/64, 22/64, 41/64) elseif role == "HEALER" then b.roleIcon.tex:SetTexCoord(20/64, 39/64, 1/64, 20/64) else b.roleIcon.tex:SetTexCoord(20/64, 39/64, 22/64, 41/64) end
                    if isAuthorized then
                        b.demoteBtn:Show()
                        if d.isDemoted then b.demoteBtn.text:SetText("-1"); b.demoteBtn.text:SetTextColor(1, 0.2, 0.2) else b.demoteBtn.text:SetText("R"); b.demoteBtn.text:SetTextColor(0.5, 0.5, 0.5) end
                    else b.demoteBtn:Hide() end
                else 
                    b.t:SetText(""); b.bg:SetTexture(0.1,0.1,0.1,0.4); b.roleIcon:Hide(); b.demoteBtn:Hide()
                end
            end end
            if ns.UpdateDisplay then ns.UpdateDisplay() end
        end
        rlf:SetScript("OnShow", rlf.Update)
        rlf:Hide()
    end
    if rlf:IsShown() then rlf:Hide() else rlf:Show() end
end

local sf
ns.ToggleSettings = function()
    if not sf then
        sf = CreateFrame("Frame", nil, UIParent); sf:SetSize(300, 370); sf:SetPoint("CENTER"); sf:SetFrameStrata("DIALOG")
        sf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1})
        sf:SetBackdropColor(0,0,0,0.9); sf:SetBackdropBorderColor(1,1,1,1); sf:EnableMouse(true)
        local sc = CreateFrame("Button",nil,sf,"UIPanelCloseButton"); sc:SetPoint("TOPRIGHT",-5,-5); sc:SetScript("OnClick", function() sf:Hide() end)
        local st = sf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); st:SetPoint("TOP",0,-10); st:SetText("Settings")
        
        local function MkSl(lbl, min, max, step, k, y)
            local s = CreateFrame("Slider", "SimpleRoll_S_"..k, sf, "OptionsSliderTemplate")
            s:SetPoint("TOP",0,y); s:SetMinMaxValues(min,max); s:SetValueStep(step); s:SetWidth(180)
            _G[s:GetName().."Low"]:SetText(min); _G[s:GetName().."High"]:SetText(max)
            local t = s:CreateFontString(nil,"OVERLAY","GameFontNormal"); t:SetPoint("BOTTOM",s,"TOP",0,0)
            
            s:SetScript("OnShow", function() 
                local val = ns.DB.Config[k] or min
                s:SetValue(val); t:SetText(lbl..": "..string.format("%.2f", val)) 
            end)
            
            s:SetScript("OnValueChanged", function(self, v) 
                local snapped = math.floor(v / step + 0.5) * step
                ns.DB.Config[k] = snapped
                t:SetText(lbl..": "..string.format("%.2f", snapped))
                ns.ApplyVisuals() 
            end)
        end
        
        MkSl("Row Height", 15, 50, 1, "rowHeight", -50)
        MkSl("Font Size", 8, 24, 1, "fontSize", -100)
        MkSl("Window Scale", 0.5, 2.0, 0.05, "windowScale", -150)
        
        local tChk = CreateFrame("CheckButton", "SimpleRoll_S_Toast", sf, "UICheckButtonTemplate")
        tChk:SetPoint("TOPLEFT", 30, -195)
        tChk.text = tChk:CreateFontString(nil, "OVERLAY", "GameFontNormal"); tChk.text:SetPoint("LEFT", tChk, "RIGHT", 5, 0); tChk.text:SetText("Enable Footer Notifications")
        tChk:SetScript("OnShow", function(self) self:SetChecked(not ns.DB.Config.disableToasts) end)
        tChk:SetScript("OnClick", function(self) 
            ns.DB.Config.disableToasts = not self:GetChecked() 
            if self:GetChecked() then ns.ShowToast("Notifications Enabled!", 0, 1, 0) end
        end)

        local jChk = CreateFrame("CheckButton", "SimpleRoll_S_JSON", sf, "UICheckButtonTemplate")
        jChk:SetPoint("TOPLEFT", 30, -230)
        jChk.text = jChk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        jChk.text:SetPoint("LEFT", jChk, "RIGHT", 5, 0)
        jChk.text:SetText("Disable JSON Export Logging")
        jChk:SetScript("OnShow", function(self) self:SetChecked(ns.DB.Config.disableJSON) end)
        jChk:SetScript("OnClick", function(self) 
            ns.DB.Config.disableJSON = self:GetChecked() and true or false 
        end)
        
        local wipeBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        wipeBtn:SetSize(180, 24)
        wipeBtn:SetPoint("BOTTOM", 0, 20)
        wipeBtn:SetText("Wipe All History & Data")
        
        local wipeText = wipeBtn:GetFontString()
        if wipeText then wipeText:SetTextColor(1, 0.2, 0.2) end
        
        wipeBtn:SetScript("OnClick", function()
            ns.DB.History = {}
            ns.DB.RaidLog = {}
            if hf and hf.UpdateDisplay then hf.UpdateDisplay() end
            if ns.ShowToast then ns.ShowToast("All History & JSON Data Wiped!", 1, 0.2, 0.2) end
        end)
        
        sf:Hide()
    end
    if sf:IsShown() then sf:Hide() else sf:Show() end
end