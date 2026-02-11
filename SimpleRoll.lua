local addonName, ns = ...
local DB

local Defaults = {
    Config = {
        rowHeight = 28,
        fontSize = 12,
        bgColor = {0.1, 0.1, 0.1, 0.95},
        borderColor = {0.0, 0.0, 0.0, 1},
        headerColor = {0.05, 0.05, 0.05, 1},
        winnerColor = {0.2, 1, 0.2, 1},
    },
    Roster = {},
    History = {},
    Rolls = {},
    Session = { ItemName = "Rolling for...", ItemCount = 1, CurrentTime = 0 },
    Pos = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 340, height = 400, isVisible = true }
}

local function ValidateRoster()
    if not DB.Roster then DB.Roster = {} end
    for i = 1, 8 do
        if not DB.Roster[i] or type(DB.Roster[i]) ~= "table" then
            DB.Roster[i] = {nil, nil, nil, nil, nil}
        end
    end
end

local function InitDB()
    if not SimpleRoll_GlobalDB then SimpleRoll_GlobalDB = {} end
    DB = SimpleRoll_GlobalDB
    if not DB.Config then DB.Config = {} end
    for k, v in pairs(Defaults.Config) do if DB.Config[k] == nil then DB.Config[k] = v end end
    if not DB.History then DB.History = {} end
    if not DB.Rolls then DB.Rolls = {} end
    if not DB.Session then DB.Session = { ItemName = "Rolling for...", ItemCount = 1, CurrentTime = GetTime() } end
    if not DB.Pos then DB.Pos = Defaults.Pos end
    ValidateRoster()
end

local RollDatabase = {}

local function ParseDatabase()
    RollDatabase = {} 
    if not SimpleRoll_RawText then return end
    
    local count = 0
    local currentName = nil 
    
    for line in SimpleRoll_RawText:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        local lowerLine = string.lower(line)
        
        local nameFound = line:match("^%d+%.%s*(%S+)")
        if nameFound then
            currentName = nameFound
        end
        
        if currentName then
            local rankVal = lowerLine:match("rank:?%s*(%d+)")
            local epVal = lowerLine:match("points:?%s*(%d+)") or lowerLine:match("ep:?%s*(%d+)")
            
            if rankVal then
                RollDatabase[currentName] = { 
                    rank = tonumber(rankVal), 
                    ep = tonumber(epVal) or 0
                }
                count = count + 1
                currentName = nil
            end
        end
    end
    if count > 0 then
        print("|cff00ff00SimpleRoll|r: Loaded " .. count .. " ranks from DB.")
    else
        print("|cffff0000SimpleRoll|r: DB Loaded but 0 ranks found. Check format.")
    end
end

local function GetRollerInfo(name)
    if RollDatabase[name] then return RollDatabase[name] end
    return nil
end

local IgnoreRanks = false 
local C_TEXT = {1, 1, 1, 1}
local C_OS = {0.6, 0.6, 0.6, 1}
local C_SOS = {0.0, 0.7, 1.0, 1}

local UpdateDisplay, ToggleRaiderList, ToggleHistory, ToggleSettings, ScanRaidToRoster, UpdatePermissions, ToggleMenu

local f = CreateFrame("Frame", "SimpleRollFrame", UIParent)
f:SetFrameStrata("HIGH"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetResizable(true)
f:SetMinResize(320, 250); f:SetMaxResize(600, 900); f:SetClampedToScreen(true)
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local resizeBtn = CreateFrame("Button", nil, f); resizeBtn:SetSize(16, 16); resizeBtn:SetPoint("BOTTOMRIGHT")
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end); resizeBtn:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

f:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground", edgeFile="Interface\\ChatFrame\\ChatFrameBackground", edgeSize=2, insets={left=2,right=2,top=2,bottom=2}})
local headerBg = f:CreateTexture(nil, "BACKGROUND"); headerBg:SetPoint("TOPLEFT", 2, -2); headerBg:SetPoint("TOPRIGHT", -2, -2); headerBg:SetHeight(34)
local headerLine = f:CreateTexture(nil, "OVERLAY"); headerLine:SetHeight(1); headerLine:SetPoint("TOPLEFT", 2, -36); headerLine:SetPoint("TOPRIGHT", -2, -36); headerLine:SetTexture(0.7, 0.6, 0, 0.5)

local credits = f:CreateFontString(nil, "OVERLAY", "GameFontDarkGraySmall")
credits:SetPoint("BOTTOMRIGHT", -30, 5); credits:SetText("made by zombik")

f.scrollFrame = CreateFrame("ScrollFrame", "SimpleRollMainScroll", f, "UIPanelScrollFrameTemplate")
f.scrollFrame:SetPoint("TOPLEFT", 6, -40); f.scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6) 
local content = CreateFrame("Frame", nil, f.scrollFrame); content:SetSize(300, 1); f.scrollFrame:SetScrollChild(content)

local function ApplyVisuals()
    if not DB then return end
    f:SetBackdropColor(unpack(DB.Config.bgColor))
    f:SetBackdropBorderColor(unpack(DB.Config.borderColor))
    headerBg:SetTexture(unpack(DB.Config.headerColor))
    if UpdateDisplay then UpdateDisplay() end
end

local function GetClassHex(class)
    if not class or not RAID_CLASS_COLORS[class] then return "ffffffff" end
    local c = RAID_CLASS_COLORS[class]
    return string.format("ff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
end

local hf, hRows, hContent
local HIST_ROW_HEIGHT = 20

local function UpdateHistoryForSession(newWinners, itemLink)
    local timestamp = time()
    local i = 1
    while i <= #DB.History do
        if DB.History[i].session == DB.Session.CurrentTime then table.remove(DB.History, i) else i = i + 1 end
    end
    for _, winData in ipairs(newWinners) do
        table.insert(DB.History, {
            session = DB.Session.CurrentTime,
            time = timestamp,
            winner = winData.name,
            item = itemLink,
            reason = winData.reason,
            completed = false
        })
    end
    if hf and hf:IsShown() then hf.UpdateDisplay() end
end

local function AddManualHistory(winnerName, itemLink)
    table.insert(DB.History, {
        session = DB.Session.CurrentTime,
        time = time(),
        winner = winnerName,
        item = itemLink,
        reason = "Manual/Other Rule",
        completed = false
    })
    if hf and hf:IsShown() then hf.UpdateDisplay() end
end

local rows = {}
local function GetRow(index)
    if not rows[index] then
        local row = CreateFrame("Frame", nil, content); row:SetSize(200, 28)
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row)
        row.pos = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); row.pos:SetPoint("LEFT", 4, 0); row.pos:SetWidth(25); row.pos:SetJustifyH("LEFT")
        row.winBtn = CreateFrame("Button", nil, row); row.winBtn:SetSize(16, 16); row.winBtn:SetPoint("RIGHT", -4, 0)
        row.winBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); row.winBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        row.winBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Forced Win"); GameTooltip:Show() end)
        row.winBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.roll = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); row.roll:SetPoint("RIGHT", row.winBtn, "LEFT", -10, 0); row.roll:SetJustifyH("RIGHT")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); row.name:SetPoint("LEFT", row.pos, "RIGHT", 4, 0); row.name:SetPoint("RIGHT", row.roll, "LEFT", -10, 0); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
        rows[index] = row
    end
    return rows[index]
end

local function SortRolls(a, b)
    if IgnoreRanks then
        if a.roll ~= b.roll then return a.roll > b.roll end
        return a.name < b.name
    end
    
    local function GetPriorityScore(entry)
        if entry.isMS then return 3 end
        if entry.isSOS then return 2 end
        return 1
    end
    
    local scoreA = GetPriorityScore(a)
    local scoreB = GetPriorityScore(b)
    if scoreA ~= scoreB then return scoreA > scoreB end
    
    if a.isMS then
        local infoA = GetRollerInfo(a.name)
        local infoB = GetRollerInfo(b.name)
        local hasRankA = (infoA ~= nil)
        local hasRankB = (infoB ~= nil)
        
        if hasRankA and not hasRankB then return true end
        if hasRankB and not hasRankA then return false end
        
        if hasRankA and hasRankB then
            if infoA.rank ~= infoB.rank then 
                return infoA.rank > infoB.rank
            end
        end
    end
    
    if a.roll ~= b.roll then return a.roll > b.roll end
    return a.name < b.name
end

UpdateDisplay = function()
    if not DB then return end
    table.sort(DB.Rolls, SortRolls)
    local numEntries = #DB.Rolls
    local rowH = DB.Config.rowHeight
    local contentHeight = numEntries * rowH
    if contentHeight < 1 then contentHeight = 1 end
    content:SetSize(f.scrollFrame:GetWidth(), contentHeight)
    for _, row in pairs(rows) do row:Hide() end
    for i, data in ipairs(DB.Rolls) do
        local row = GetRow(i)
        row:SetHeight(rowH); row:SetWidth(f.scrollFrame:GetWidth()); 
        local font, _, flags = row.name:GetFont()
        row.name:SetFont(font, DB.Config.fontSize, flags); row.pos:SetFont(font, DB.Config.fontSize, flags); row.roll:SetFont(font, DB.Config.fontSize, flags)
        row:SetPoint("TOPLEFT", 0, -(i-1)*rowH); row:Show()
        if i % 2 == 0 then row.bg:SetTexture(0.25, 0.25, 0.25, 0.6) else row.bg:SetTexture(0.15, 0.15, 0.15, 0.6) end
        row.pos:SetText(i)
        
        local info = GetRollerInfo(data.name)
        local nameStr = data.name
        
        if not IgnoreRanks then
            if info then 
                nameStr = nameStr .. " |cffaaaaff(Rank " .. info.rank .. ")|r"
            else
                nameStr = nameStr .. " |cff888888(-)|r"
            end
        end
        
        row.name:SetText(nameStr)
        if IgnoreRanks then
            row.roll:SetText(data.roll); row.roll:SetTextColor(unpack(C_TEXT))
        else
            if data.isMS then row.roll:SetText(data.roll .. " (MS)"); row.roll:SetTextColor(unpack(C_TEXT))
            elseif data.isSOS then row.roll:SetText(data.roll .. " |cff00b2ff(SOS)|r"); row.roll:SetTextColor(unpack(C_SOS))
            else row.roll:SetText(data.roll .. " |cff999999(OS)|r"); row.roll:SetTextColor(unpack(C_OS)) end
        end
        row.winBtn:SetScript("OnClick", function() 
            if not (IsRaidLeader() or IsRaidOfficer() or (GetNumRaidMembers()==0 and GetNumPartyMembers()==0)) then return end
            local msg = "SimpleRoll: " .. data.name .. " won by other rule " .. DB.Session.ItemName
            AddManualHistory(data.name, DB.Session.ItemName)
            SendChatMessage(msg, "RAID")
        end)
        if i <= DB.Session.ItemCount then
            row.pos:SetTextColor(unpack(DB.Config.winnerColor)); row.name:SetTextColor(unpack(DB.Config.winnerColor)); row.roll:SetTextColor(unpack(DB.Config.winnerColor)) 
        else
            row.pos:SetTextColor(0.5, 0.5, 0.5); row.name:SetTextColor(unpack(C_TEXT))
        end
    end
end

local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 10, -10); titleText:SetJustifyH("LEFT"); titleText:SetText("Rolling for..."); titleText:SetTextColor(1, 0.82, 0, 1)

local closeBtn = CreateFrame("Button", nil, f)
closeBtn:SetSize(22, 22); closeBtn:SetPoint("TOPRIGHT", -6, -6)
closeBtn:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeSize = 1 })
closeBtn:SetBackdropColor(0.4, 0, 0, 1); closeBtn:SetBackdropBorderColor(0.5, 0, 0, 1)
local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); closeText:SetPoint("CENTER"); closeText:SetText("X")
closeBtn:SetScript("OnClick", function() f:Hide() end)

local menuBtn = CreateFrame("Button", nil, f)
menuBtn:SetSize(24, 24); menuBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
menuBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
menuBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
menuBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Menu"); GameTooltip:Show() end)
menuBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
menuBtn:SetScript("OnClick", function() ToggleMenu() end)

local announceBtn = CreateFrame("Button", nil, f)
announceBtn:SetSize(24, 24); announceBtn:SetPoint("RIGHT", menuBtn, "LEFT", -5, 0)
announceBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up"); announceBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
announceBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Announce Winner"); GameTooltip:Show() end)
announceBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
announceBtn:SetScript("OnClick", function() 
    table.sort(DB.Rolls, SortRolls) 
    if #DB.Rolls == 0 then print("|cff00ff00SimpleRoll|r: No rolls to report."); return end
    local chatType = "SAY"
    if IsInRaid() then chatType = "RAID" elseif IsInGroup() then chatType = "PARTY" end
    local msg = "SimpleRoll Winners: "
    for i = 1, DB.Session.ItemCount do
        local entry = DB.Rolls[i]
        if not entry then break end 
        if i > 1 then msg = msg .. ", " end
        msg = msg .. i .. ". " .. entry.name .. " (" .. entry.roll .. ")"
        
        local info = GetRollerInfo(entry.name)
        local rankStr = "PuG"
        if info then rankStr = "Rank "..info.rank end
    end
    SendChatMessage(msg, chatType)
end)

local rankToggleBtn = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
rankToggleBtn:SetSize(26, 26); rankToggleBtn:SetPoint("RIGHT", announceBtn, "LEFT", -5, 0)
rankToggleBtn.text = rankToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rankToggleBtn.text:SetPoint("RIGHT", rankToggleBtn, "LEFT", 0, 0); rankToggleBtn.text:SetText("Raw")
rankToggleBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Toggle Raw Rolls"); GameTooltip:Show() end)
rankToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
rankToggleBtn:SetScript("OnClick", function(self) IgnoreRanks = self:GetChecked(); UpdateDisplay() end)

local menuFrame
ToggleMenu = function()
    if not menuFrame then
        menuFrame = CreateFrame("Frame", nil, f)
        menuFrame:SetSize(120, 100)
        menuFrame:SetPoint("TOPRIGHT", menuBtn, "BOTTOMRIGHT", 0, -5)
        menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        menuFrame:EnableMouse(true)
        menuFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1})
        menuFrame:SetBackdropColor(0,0,0,0.95); menuFrame:SetBackdropBorderColor(0.5,0.5,0.5,1)
        menuFrame:Hide()
        
        local function CreateMenuBtn(text, func)
            local b = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
            b:SetSize(110, 22); b:SetText(text)
            b:SetScript("OnClick", function() func(); menuFrame:Hide() end)
            b:SetFrameLevel(menuFrame:GetFrameLevel() + 10)
            return b
        end
        
        menuFrame.btnHistory = CreateMenuBtn("Loot History", ToggleHistory)
        menuFrame.btnRaider = CreateMenuBtn("Raider List", ToggleRaiderList)
        menuFrame.btnReset = CreateMenuBtn("Reset Rolls", function()
            DB.Rolls = {}; DB.Session.ItemName = "Rolling for..."; DB.Session.CurrentTime = GetTime(); DB.Session.ItemCount = 1
            titleText:SetText(DB.Session.ItemName); UpdateDisplay()
        end)
        menuFrame.btnSettings = CreateMenuBtn("Settings", ToggleSettings)
    end
    
    if menuFrame:IsShown() then
        menuFrame:Hide()
    else
        local isAuthorized = IsRaidLeader() or IsRaidOfficer()
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then isAuthorized = true end
        
        menuFrame.btnHistory:SetPoint("TOP", 0, -5)
        if isAuthorized then
            menuFrame:SetHeight(115)
            menuFrame.btnRaider:Show(); menuFrame.btnRaider:SetPoint("TOP", menuFrame.btnHistory, "BOTTOM", 0, -5)
            menuFrame.btnReset:Show(); menuFrame.btnReset:SetPoint("TOP", menuFrame.btnRaider, "BOTTOM", 0, -5)
            menuFrame.btnSettings:SetPoint("TOP", menuFrame.btnReset, "BOTTOM", 0, -5)
        else
            menuFrame:SetHeight(60)
            menuFrame.btnRaider:Hide(); menuFrame.btnReset:Hide()
            menuFrame.btnSettings:SetPoint("TOP", menuFrame.btnHistory, "BOTTOM", 0, -5)
        end
        menuFrame:Show()
    end
end

UpdatePermissions = function()
    local isAuthorized = IsRaidLeader() or IsRaidOfficer()
    if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then isAuthorized = true end
    if isAuthorized then announceBtn:Show() else announceBtn:Hide() end
    if announceBtn:IsShown() then rankToggleBtn:SetPoint("RIGHT", announceBtn, "LEFT", -5, 0)
    else rankToggleBtn:SetPoint("RIGHT", menuBtn, "LEFT", -5, 0) end
end

local rlf, ef, DragGhost

ToggleHistory = function()
    if not hf then
        hf = CreateFrame("Frame", "SimpleRollHistoryFrame", UIParent); hf:SetSize(500, 400); hf:SetPoint("CENTER"); hf:SetFrameStrata("DIALOG"); hf:SetMovable(true); hf:EnableMouse(true); hf:SetResizable(true); hf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); hf:SetBackdropColor(0,0,0,0.95); hf:SetBackdropBorderColor(0.6,0.6,0.6,1)
        hf:SetScript("OnDragStart", hf.StartMoving); hf:SetScript("OnDragStop", hf.StopMovingOrSizing)
        local hTitle = hf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); hTitle:SetPoint("TOP", 0, -10); hTitle:SetText("Loot History")
        local hClose = CreateFrame("Button", nil, hf, "UIPanelCloseButton"); hClose:SetPoint("TOPRIGHT", 0, 0); hClose:SetScript("OnClick", function() hf:Hide() end)
        local hClear = CreateFrame("Button", nil, hf, "UIPanelButtonTemplate"); hClear:SetSize(80, 22); hClear:SetPoint("TOPLEFT", 10, -10); hClear:SetText("Clear"); hClear:SetScript("OnClick", function() DB.History = {}; hf.UpdateDisplay() end)
        local hScroll = CreateFrame("ScrollFrame", "SimpleRollHistoryScroll", hf, "UIPanelScrollFrameTemplate"); hScroll:SetPoint("TOPLEFT", 10, -40); hScroll:SetPoint("BOTTOMRIGHT", -30, 20); hContent = CreateFrame("Frame", nil, hScroll); hContent:SetSize(1,1); hScroll:SetScrollChild(hContent)
        local hResize = CreateFrame("Button", nil, hf); hResize:SetSize(16,16); hResize:SetPoint("BOTTOMRIGHT"); hResize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); hResize:SetScript("OnMouseDown", function() hf:StartSizing("BOTTOMRIGHT") end); hResize:SetScript("OnMouseUp", function() hf:StopMovingOrSizing() end)
        hRows = {}
        hf.UpdateDisplay = function()
            local data = DB.History or {}
            hContent:SetSize(hScroll:GetWidth(), #data * HIST_ROW_HEIGHT)
            for _, r in pairs(hRows) do r:Hide() end
            for i, entry in ipairs(data) do
                if not hRows[i] then
                    local r = CreateFrame("Frame", nil, hContent); r:SetSize(450, HIST_ROW_HEIGHT)
                    r.del = CreateFrame("Button", nil, r); r.del:SetSize(16,16); r.del:SetPoint("LEFT"); r.del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.del:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
                    r.chk = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.chk:SetSize(20,20); r.chk:SetPoint("LEFT", r.del, "RIGHT", 2, 0)
                    r.txt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.txt:SetPoint("LEFT", r.chk, "RIGHT", 5, 0); r.txt:SetPoint("RIGHT", 0, 0); r.txt:SetJustifyH("LEFT")
                    hRows[i] = r
                end
                local r = hRows[i]; r:SetPoint("TOPLEFT", 0, -(i-1)*HIST_ROW_HEIGHT); r:SetWidth(hScroll:GetWidth()); r:Show()
                r.txt:SetText(date("%H:%M", entry.time).." " .. entry.winner .. " won " .. (entry.item or "?") .. " ("..entry.reason..")")
                r.chk:SetChecked(entry.completed); r.chk:SetScript("OnClick", function(s) entry.completed = s:GetChecked() end)
                r.del:SetScript("OnClick", function() table.remove(DB.History, i); hf.UpdateDisplay() end)
            end
        end
        hf:SetScript("OnShow", hf.UpdateDisplay); hf:SetScript("OnSizeChanged", function() if hf:IsShown() then hf.UpdateDisplay() end end)
        hf:Hide()
    end
    if hf:IsShown() then hf:Hide() else hf:Show() end
end

ScanRaidToRoster = function()
    ValidateRoster()
    local NewRoster = {}; for i=1,8 do NewRoster[i] = {nil,nil,nil,nil,nil} end
    local raidMembers = {}
    local numRaiders = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if numRaiders > 0 then
        print("|cff00ff00SimpleRoll|r: Scanning "..numRaiders.." raid members...")
        for i = 1, numRaiders do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            if name and subgroup and subgroup >= 1 and subgroup <= 8 then
                raidMembers[name] = true
                for s = 1, 5 do if not NewRoster[subgroup][s] then NewRoster[subgroup][s] = { name = name, class = class }; break end end
            end
        end
    else
        print("|cff00ff00SimpleRoll|r: Scanning Party/Solo...")
        local myName = UnitName("player"); local _, myClass = UnitClass("player")
        NewRoster[1][1] = { name = myName, class = myClass }; raidMembers[myName] = true
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            for i=1, GetNumPartyMembers() do
                local n = UnitName("party"..i); local _, c = UnitClass("party"..i)
                if n then raidMembers[n]=true; if i+1<=5 then NewRoster[1][i+1]={name=n,class=c} end end
            end
        end
    end
    for g=1,8 do for s=1,5 do
        local e = DB.Roster[g][s]
        if e and e.name and not raidMembers[e.name] then
            if not NewRoster[g][s] then NewRoster[g][s] = e
            else
                local placed = false
                for ns=1,5 do if not NewRoster[g][ns] then NewRoster[g][ns]=e; placed=true; break end end
                if not placed then for ng=8,1,-1 do for ns=1,5 do if not NewRoster[ng][ns] then NewRoster[ng][ns]=e; placed=true; break end end if placed then break end end end
            end
        end
    end end
    DB.Roster = NewRoster
end

ToggleRaiderList = function()
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
                b.t = b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.t:SetPoint("CENTER")
                b:RegisterForClicks("LeftButtonUp","RightButtonUp")
                local editPopup = CreateFrame("EditBox", nil, rlf, "InputBoxTemplate")
                editPopup:SetSize(130, 20); editPopup:Hide(); editPopup:SetAutoFocus(true)
                editPopup:SetScript("OnEnterPressed", function(box)
                    local val = box:GetText(); if val and val ~= "" then DB.Roster[box.g][box.s] = { name = val, class = "PRIEST" }; rlf.Update() end; box:Hide()
                end)
                editPopup:SetScript("OnEscapePressed", function(box) box:Hide() end)
                b:SetScript("OnMouseDown", function(self, button)
                    if button=="LeftButton" and DB.Roster[g][s] then
                        DraggingInfo = { active=true, g=g, s=s, data=DB.Roster[g][s] }
                        DragGhost.t:SetText(DraggingInfo.data.name); DragGhost:Show(); self.t:SetAlpha(0.3)
                    end
                end)
                b:SetScript("OnMouseUp", function(self, button)
                    if DraggingInfo.active then
                        DraggingInfo.active = false; DragGhost:Hide(); SlotButtons[DraggingInfo.g][DraggingInfo.s].t:SetAlpha(1)
                        local target = GetMouseFocus()
                        if target and target.g and target.s then
                            local tg, ts = target.g, target.s
                            local temp = DB.Roster[tg][ts]
                            DB.Roster[tg][ts] = DraggingInfo.data
                            DB.Roster[DraggingInfo.g][DraggingInfo.s] = temp
                            rlf.Update()
                        end
                    else
                        if button=="RightButton" then DB.Roster[g][s] = nil; rlf.Update()
                        elseif button=="LeftButton" then
                            editPopup:ClearAllPoints(); editPopup:SetPoint("CENTER", self, "CENTER", 0, 0); editPopup:SetFrameLevel(self:GetFrameLevel()+5)
                            editPopup.g = g; editPopup.s = s; local d = DB.Roster[g][s]; editPopup:SetText(d and d.name or ""); editPopup:Show(); editPopup:SetFocus()
                        end
                    end
                end)
                b.g = g; b.s = s
                SlotButtons[g][s] = b
            end
        end
        rlf.Update = function()
            ValidateRoster()
            for g=1,8 do for s=1,5 do
                local d = DB.Roster[g][s]; local b = SlotButtons[g][s]
                if d and d.name then b.t:SetText("|c"..GetClassHex(d.class)..d.name.."|r"); b.bg:SetTexture(0.3,0.3,0.3,0.6)
                else b.t:SetText(""); b.bg:SetTexture(0.1,0.1,0.1,0.4) end
            end end
        end
        local btnScan = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnScan:SetSize(100,25); btnScan:SetPoint("BOTTOMLEFT",20,10); btnScan:SetText("Scan"); btnScan:SetScript("OnClick", function() ScanRaidToRoster(); rlf.Update() end)
        local btnExp = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnExp:SetSize(100,25); btnExp:SetPoint("BOTTOMRIGHT",-20,10); btnExp:SetText("Export"); btnExp:SetScript("OnClick", function()
            if not ef then
                ef = CreateFrame("Frame", nil, UIParent); ef:SetSize(400,300); ef:SetPoint("CENTER"); ef:SetFrameStrata("FULLSCREEN_DIALOG")
                ef:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1}); ef:SetBackdropColor(0,0,0,1)
                local ec = CreateFrame("Button",nil,ef,"UIPanelCloseButton"); ec:SetPoint("TOPRIGHT",-5,-5); ec:SetScript("OnClick", function() ef:Hide() end)
                local es = CreateFrame("ScrollFrame","SRExp",ef,"UIPanelScrollFrameTemplate"); es:SetPoint("TOPLEFT",10,-10); es:SetPoint("BOTTOMRIGHT",-30,10)
                local eb = CreateFrame("EditBox",nil,es); eb:SetMultiLine(true); eb:SetSize(360,280); eb:SetFontObject(ChatFontNormal); es:SetScrollChild(eb)
                eb:SetScript("OnTextChanged", function(s,u) if u then s:SetText(s.last); s:HighlightText() else s.last=s:GetText() end end); eb:SetScript("OnEscapePressed", function() ef:Hide() end)
                ef.box = eb
            end
            local str = ""
            for g=1,8 do
                local t = {}
                for s=1,5 do if DB.Roster[g][s] then table.insert(t, DB.Roster[g][s].name) end end
                if #t > 0 then str = str .. "Group "..g..": "..table.concat(t, ", ").."\n" end
            end
            ef.box:SetText(str); ef.box:HighlightText(); ef.box:SetFocus(); ef:Show()
        end)
        local btnClear = CreateFrame("Button", nil, rlf, "UIPanelButtonTemplate"); btnClear:SetSize(80,22); btnClear:SetPoint("TOPRIGHT",-30,-10); btnClear:SetText("Clear"); btnClear:SetScript("OnClick", function() for g=1,8 do for s=1,5 do DB.Roster[g][s] = nil end end; rlf.Update() end)
        rlf:SetScript("OnShow", rlf.Update)
        rlf:Hide()
    end
    if rlf:IsShown() then rlf:Hide() else rlf:Show() end
end

ToggleSettings = function()
    if not sf then
        sf = CreateFrame("Frame", nil, UIParent); sf:SetSize(300,350); sf:SetPoint("CENTER"); sf:SetFrameStrata("DIALOG")
        sf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\ChatFrame\\ChatFrameBackground",edgeSize=1})
        sf:SetBackdropColor(0,0,0,0.9); sf:SetBackdropBorderColor(1,1,1,1); sf:EnableMouse(true)
        local sc = CreateFrame("Button",nil,sf,"UIPanelCloseButton"); sc:SetPoint("TOPRIGHT",-5,-5); sc:SetScript("OnClick", function() sf:Hide() end)
        local st = sf:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); st:SetPoint("TOP",0,-10); st:SetText("Settings")
        local function MkSl(lbl, min, max, k, y)
            local s = CreateFrame("Slider", "SimpleRoll_S_"..k, sf, "OptionsSliderTemplate")
            s:SetPoint("TOP",0,y); s:SetMinMaxValues(min,max); s:SetValueStep(1); s:SetWidth(180)
            _G[s:GetName().."Low"]:SetText(min); _G[s:GetName().."High"]:SetText(max)
            local t = s:CreateFontString(nil,"OVERLAY","GameFontNormal"); t:SetPoint("BOTTOM",s,"TOP",0,0)
            s:SetScript("OnShow", function() s:SetValue(DB.Config[k]); t:SetText(lbl..": "..DB.Config[k]) end)
            s:SetScript("OnValueChanged", function(self,v) DB.Config[k]=v; t:SetText(lbl..": "..string.format("%.2f",v)); ApplyVisuals() end)
        end
        MkSl("Row Height", 15, 50, "rowHeight", -50)
        MkSl("Font Size", 8, 24, "fontSize", -100)
        sf:Hide()
    end
    if sf:IsShown() then sf:Hide() else sf:Show() end
end

local function SaveLayout()
    local db = DB.Pos
    db.width = f:GetWidth(); db.height = f:GetHeight()
    local p, _, rp, x, y = f:GetPoint(); db.point = p; db.relativePoint = rp; db.x = x; db.y = y
    db.isVisible = f:IsShown()
end

local function LoadLayout()
    local db = DB.Pos
    f:SetSize(db.width, db.height); f:ClearAllPoints(); f:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    if db.isVisible then f:Show() else f:Hide() end
end

f:SetScript("OnSizeChanged", function() SaveLayout(); UpdateDisplay() end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_RAID_WARNING")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_RAID_LEADER")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_SAY")

f:SetScript("OnEvent", function(self, event, msg, ...)
    if event == "ADDON_LOADED" and msg == addonName then
        InitDB()
        LoadLayout()
        ApplyVisuals()
        ParseDatabase()
        UpdatePermissions()
        
        local countStr = ""
        if DB.Session.ItemCount > 1 then countStr = " (x"..DB.Session.ItemCount..")" end
        titleText:SetText(DB.Session.ItemName .. countStr)
        UpdateDisplay()
    end

    if event == "GROUP_ROSTER_UPDATE" then UpdatePermissions() end

    if event == "CHAT_MSG_RAID_WARNING" then
        local itemLink = string.match(msg, "(|c%x+|Hitem:.-|h|r)")
        if itemLink then
            DB.Rolls = {}
            DB.Session.ItemName = itemLink
            DB.Session.CurrentTime = GetTime()
            
            local txt = string.lower(msg)
            local count = 1
            local m1 = string.match(txt, "(%d+)%s*x")
            local m2 = string.match(txt, "x%s*(%d+)")
            if m1 then count = tonumber(m1) elseif m2 then count = tonumber(m2) end
            if count < 1 then count = 1 end
            DB.Session.ItemCount = count
            
            local countStr = ""
            if count > 1 then countStr = " (x"..count..")" end
            titleText:SetText(itemLink .. countStr)
            
            UpdateDisplay()
            f:Show() 
        elseif string.find(string.lower(msg), "roll") then
            f:Show() 
        end
    end

    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_SAY" then
        if string.find(msg, "SimpleRoll Winners:") then
            local newWinners = {}
            for index, name, rollVal in string.gmatch(msg, "(%d+)%.%s*([^%s]+)%s*%((%d+)%)") do
                local info = GetRollerInfo(name)
                local rankStr = "PuG"
                if info then rankStr = "Rank "..info.rank end
                local reasonText = "Roll "..rollVal.." ("..rankStr..")"
                table.insert(newWinners, { name = name, reason = reasonText })
            end
            if #newWinners > 0 then UpdateHistoryForSession(newWinners, DB.Session.ItemName) end
        elseif string.find(msg, "SimpleRoll:") and string.find(msg, "won by other rule") then
            local winner = string.match(msg, "SimpleRoll:%s*(.*)%s*won by other rule")
            if winner then AddManualHistory(winner, DB.Session.ItemName) end
        end
    end

    if event == "CHAT_MSG_SYSTEM" then
        if DB.Session.ItemName == "Rolling for..." then return end
        local name, rollResult, minRoll, maxRoll = string.match(msg, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
        if name and rollResult and maxRoll then
            local exists = false
            for _, entry in ipairs(DB.Rolls) do if entry.name == name then exists = true end end
            local rollMax = tonumber(maxRoll)
            local isMainSpec = (rollMax == 100)
            local isShamanOS = (rollMax == 101)
            if not exists then
                table.insert(DB.Rolls, { name = name, roll = tonumber(rollResult), isMS = isMainSpec, isSOS = isShamanOS })
                UpdateDisplay()
            end
        end
    end
end)

SLASH_SIMPLEROLL1 = "/sr"
SLASH_SIMPLEROLL2 = "/simpleroll"
SlashCmdList["SIMPLEROLL"] = function(msg)
    if msg == "reset" then
        DB.Pos = Defaults.Pos
        f:ClearAllPoints(); f:SetPoint("CENTER"); f:SetSize(340, 400); f:Show()
    else
        f:Show()
    end
end
