local addonName, ns = ...

ns.Defaults = {
    Config = {
        rowHeight = 28,
        fontSize = 12,
        bgColor = {0.1, 0.1, 0.1, 0.95},
        borderColor = {0.0, 0.0, 0.0, 1},
        headerColor = {0.05, 0.05, 0.05, 1},
        winnerColor = {0.2, 1, 0.2, 1},
        disableJSON = true,
    },
    Roster = {},
    History = {},
    RaidLog = {},
    Rolls = {},
    Session = { ItemName = "Rolling for...", ItemCount = 1, CurrentTime = 0 },
    Pos = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 340, height = 400, isVisible = true }
}

ns.IgnoreRanks = false
ns.ForceTokenMode = false
ns.RollDatabase = {}
ns.MyGuildName = "WipeMeBabyOneMoreTime"

ns.MaxPuG_MS = 0
ns.MaxPuG_OS = 0

function ns.ValidateRoster()
    if not ns.DB.Roster then ns.DB.Roster = {} end
    for i = 1, 8 do
        if not ns.DB.Roster[i] or type(ns.DB.Roster[i]) ~= "table" then
            ns.DB.Roster[i] = {nil, nil, nil, nil, nil}
        end
    end
end

function ns.InitDB()
    if not SimpleRoll_GlobalDB then SimpleRoll_GlobalDB = {} end
    ns.DB = SimpleRoll_GlobalDB
    if not ns.DB.Config then ns.DB.Config = {} end
    for k, v in pairs(ns.Defaults.Config) do if ns.DB.Config[k] == nil then ns.DB.Config[k] = v end end
    if not ns.DB.History then ns.DB.History = {} end
    if not ns.DB.RaidLog then ns.DB.RaidLog = {} end -- NEW: Persistent Log
    if not ns.DB.Rolls then ns.DB.Rolls = {} end
    
    if not ns.DB.Raid then ns.DB.Raid = { Name = "Unsaved Raid", StartTime = time() } end 
    
    if not ns.DB.Session then ns.DB.Session = { ItemName = "Rolling for...", ItemCount = 1, CurrentTime = GetTime() } end
    if not ns.DB.Pos then ns.DB.Pos = ns.Defaults.Pos end
    ns.ValidateRoster()
end

function ns.ParseDatabase()
    ns.RollDatabase = {} 
    if not SimpleRoll_RawText then return end
    
    local count = 0
    local currentName = nil 
    
    for line in SimpleRoll_RawText:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        local lowerLine = string.lower(line)
        local nameFound = line:match("^%d+%.%s*(%S+)")
        if nameFound then currentName = nameFound end
        
        if currentName then
            local rankVal = lowerLine:match("rank:?%s*(%d+)")
            local epVal = lowerLine:match("points:?%s*(%d+)") or lowerLine:match("ep:?%s*(%d+)")
            if rankVal then
                ns.RollDatabase[currentName] = { rank = tonumber(rankVal), ep = tonumber(epVal) or 0 }
                count = count + 1
                currentName = nil
            end
        end
    end
    print("|cff00ff00SimpleRoll|r: Loaded " .. count .. " ranks from DB.")
end

function ns.GetRosterData(name)
    if not ns.DB.Roster then return nil end
    for g = 1, 8 do
        for s = 1, 5 do
            local entry = ns.DB.Roster[g][s]
            if entry and entry.name == name then
                return entry
            end
        end
    end
    return nil
end

function ns.GetRollerInfo(name)
    local info = nil
    if ns.RollDatabase[name] then 
        info = { rank = ns.RollDatabase[name].rank, ep = ns.RollDatabase[name].ep }
    end

    if not info then
        local unitID = nil
        if UnitName("player") == name then unitID = "player" end
        if not unitID then
            if GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do
                    if GetRaidRosterInfo(i) == name then unitID = "raid"..i; break end
                end
            elseif GetNumPartyMembers() > 0 then
                for i = 1, GetNumPartyMembers() do
                    if UnitName("party"..i) == name then unitID = "party"..i; break end
                end
            end
        end

        if unitID and GetGuildInfo(unitID) == ns.MyGuildName then 
            info = { rank = 0, ep = 0 }
        end
    end

    if info then
        local rosterData = ns.GetRosterData(name)
        if rosterData then
            if rosterData.isDemoted then
                info.rank = info.rank - 1
                if info.rank < 0 then info.rank = 0 end
            end
            if rosterData.role then info.role = rosterData.role end
        end
        if not info.role then info.role = "DPS" end 
        return info
    end

    return nil 
end

function ns.IsTokenItem(name)
    if not name then return false end
    if string.find(name, "Conqueror") or string.find(name, "Protector") or string.find(name, "Vanquisher") then
        return true
    end
    return false
end

function ns.SortRolls(a, b)
    -- 1. DEFINE THE TIERS (MS > SOS > OS)
    local tierA = 1
    if a.isMS then tierA = 3 elseif a.isSOS then tierA = 2 end
    
    local tierB = 1
    if b.isMS then tierB = 3 elseif b.isSOS then tierB = 2 end
    
    if tierA ~= tierB then
        return tierA > tierB
    end
    
    -- 2. IF BOTH ARE MAIN SPEC (Tier 3) -> Check Ranks & Tokens
    if tierA == 3 and not ns.IgnoreRanks then
        local infoA = ns.GetRollerInfo(a.name)
        local infoB = ns.GetRollerInfo(b.name)
        
        local threshold = ns.MaxPuG_MS or 0
        local a_Qualifies = (infoA == nil) or (a.roll >= threshold)
        local b_Qualifies = (infoB == nil) or (b.roll >= threshold)
        
        if a_Qualifies and not b_Qualifies then return true end
        if b_Qualifies and not a_Qualifies then return false end
        
        -- Token Priority Check (Tank > Heal > DPS)
        local isToken = ns.ForceTokenMode or ns.IsTokenItem(ns.DB.Session.ItemName)
        if isToken then
            local roleScore = { TANK = 3, HEALER = 2, DPS = 1 }
            local rA = 1; if infoA and infoA.role then rA = roleScore[infoA.role] or 1 end
            local rB = 1; if infoB and infoB.role then rB = roleScore[infoB.role] or 1 end
            
            if rA ~= rB then return rA > rB end
        end
        local rankA = infoA and infoA.rank or 99
        local rankB = infoB and infoB.rank or 99
        
        if rankA ~= rankB then 
            return rankA < rankB 
        end
    end
    if a.roll ~= b.roll then
        return a.roll > b.roll
    end
    
    return a.name < b.name
end

function ns.GetClassHex(class)
    if not class or not RAID_CLASS_COLORS[class] then return "ffffffff" end
    local c = RAID_CLASS_COLORS[class]
    return string.format("ff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
end

function ns.ScanRaidToRoster()
    ns.ValidateRoster()
    local NewRoster = {}; for i=1,8 do NewRoster[i] = {nil,nil,nil,nil,nil} end
    local raidMembers = {}
    local numRaiders = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if numRaiders > 0 then
        print("|cff00ff00SimpleRoll|r: Scanning "..numRaiders.." raid members...")
        for i = 1, numRaiders do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            if name and subgroup and subgroup >= 1 and subgroup <= 8 then
                raidMembers[name] = true
                local existing = ns.GetRosterData(name)
                local role = "DPS"
                local demoted = false
                if existing then role = existing.role; demoted = existing.isDemoted end
                for s = 1, 5 do if not NewRoster[subgroup][s] then NewRoster[subgroup][s] = { name = name, class = class, role = role, isDemoted = demoted }; break end end
            end
        end
    else
        print("|cff00ff00SimpleRoll|r: Scanning Party/Solo...")
        local myName = UnitName("player"); local _, myClass = UnitClass("player")
        local ex = ns.GetRosterData(myName); local r="DPS"; local d=false; if ex then r=ex.role; d=ex.isDemoted end
        NewRoster[1][1] = { name = myName, class = myClass, role = r, isDemoted = d }; raidMembers[myName] = true
        if GetNumPartyMembers and GetNumPartyMembers() > 0 then
            for i=1, GetNumPartyMembers() do
                local n = UnitName("party"..i); local _, c = UnitClass("party"..i)
                if n then raidMembers[n]=true; if i+1<=5 then 
                    local ex = ns.GetRosterData(n); local r="DPS"; local d=false; if ex then r=ex.role; d=ex.isDemoted end
                    NewRoster[1][i+1]={name=n,class=c,role=r,isDemoted=d} 
                end end
            end
        end
    end
    for g=1,8 do for s=1,5 do
        local e = ns.DB.Roster[g][s]
        if e and e.name and not raidMembers[e.name] then
            if not NewRoster[g][s] then NewRoster[g][s] = e
            else
                local placed = false
                for ns_idx=1,5 do if not NewRoster[g][ns_idx] then NewRoster[g][ns_idx]=e; placed=true; break end end
                if not placed then for ng=8,1,-1 do for ns_idx=1,5 do if not NewRoster[ng][ns_idx] then NewRoster[ng][ns_idx]=e; placed=true; break end end if placed then break end end end
            end
        end
    end end
    ns.DB.Roster = NewRoster
end

-- Starts a new raid instance: Wipes history, resets penalties, sets name
function ns.StartNewRaid(raidName)
    ns.DB.Raid = { Name = raidName, StartTime = time() }
    ns.DB.History = {}
    ns.DB.RaidLog = {} 
    if ns.DB.Roster then
        for g=1,8 do
            for s=1,5 do
                if ns.DB.Roster[g][s] then
                    ns.DB.Roster[g][s].isDemoted = false
                end
            end
        end
    end
    print("|cff00ff00SimpleRoll|r: Raid '"..raidName.."' started. History and Penalties wiped.")
end

-- Generates a JSON string from RaidLog (Background Data), NOT History (Visual Data)
function ns.GenerateJSON()
    local function escape(s) return string.gsub(s, '"', '\\"') end
    
    local json = "{\n"
    json = json .. '  "raidName": "' .. escape(ns.DB.Raid.Name or "Unknown") .. '",\n'
    json = json .. '  "startTime": ' .. (ns.DB.Raid.StartTime or 0) .. ',\n'
    json = json .. '  "exportTime": ' .. time() .. ',\n'
    
    -- Roster
    json = json .. '  "roster": [\n'
    local rEntries = {}
    for g=1,8 do for s=1,5 do
        local d = ns.DB.Roster[g][s]
        if d and d.name then
            local p = 0; if d.isDemoted then p = 1 end
            table.insert(rEntries, string.format('    {"name": "%s", "class": "%s", "role": "%s", "penalty": %d}', escape(d.name), d.class or "", d.role or "DPS", p))
        end
    end end
    json = json .. table.concat(rEntries, ",\n") .. '\n  ],\n'
    
    -- Loot (From RaidLog)
    json = json .. '  "loot": [\n'
    local hEntries = {}
    local logData = ns.DB.RaidLog or {}
    for _, h in ipairs(logData) do
        local lootItem = string.format('    {\n      "winner": "%s",\n      "item": "%s",\n      "reason": "%s",\n      "timestamp": %d', escape(h.winner), escape(h.item), escape(h.reason), h.time)
        
        -- Add detailed rollers if they exist
        if h.rollers and #h.rollers > 0 then
            lootItem = lootItem .. ',\n      "rollers": [\n'
            local rollEntries = {}
            for _, r in ipairs(h.rollers) do
                table.insert(rollEntries, string.format('        {"name": "%s", "roll": %d, "type": "%s", "rank": %d, "role": "%s"}', escape(r.name), r.roll, r.type, r.rank, r.role))
            end
            lootItem = lootItem .. table.concat(rollEntries, ",\n") .. '\n      ]\n    }'
        else
            lootItem = lootItem .. '\n    }'
        end
        table.insert(hEntries, lootItem)
    end
    json = json .. table.concat(hEntries, ",\n") .. '\n  ]\n'
    
    json = json .. "}"
    return json
end