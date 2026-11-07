-- Freewood-Core: Statistik, Weltabfragen (Quests, Ruf, Berufe, Talente, Ausruestung ...)
-- Liest nur. Jede Abfrage ist geschuetzt: fehlt eine Funktion im Client, fehlt nur ihre Zeile.
-- UNGEPRUEFT im Spiel (Forever): /fwstatprobe zeigt, welche Abfragen im Client antworten.

local ADDON, FW = ...

local Stats = FW.Stats
if not Stats then return end

local G = _G
local function Clean(v) if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end return v end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
    if not ok then return nil end
    return Clean(a), Clean(b), Clean(c), Clean(d), Clean(e), Clean(f), Clean(g), Clean(h), Clean(i), Clean(j), Clean(k)
end
local function Now() return G.time and G.time() or 0 end
local function Num(v) v = tonumber(v) return v end

local W = {}
Stats.World = W

------------------------------------------------------------------------
-- Zauber, Talente, Erfolge, Reittiere
------------------------------------------------------------------------

function W.Character(w)
    -- Zauber
    local spells
    local SB = G.C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo then
        local n = Call(SB.GetNumSpellBookSkillLines)
        if type(n) == "number" then
            spells = 0
            for i = 1, n do
                local info = Call(SB.GetSpellBookSkillLineInfo, i)
                if type(info) == "table" then spells = spells + (Num(info.numSpellBookItems) or 0) end
            end
        end
    end
    if not spells and G.GetNumSpellTabs and G.GetSpellTabInfo then
        local n = Call(G.GetNumSpellTabs)
        if type(n) == "number" then
            spells = 0
            for i = 1, n do
                local _, _, _, num = Call(G.GetSpellTabInfo, i)
                spells = spells + (Num(num) or 0)
            end
        end
    end
    w.spells = spells

    -- Talente
    if G.GetNumTalentTabs and G.GetTalentInfo then
        local tabs = Call(G.GetNumTalentTabs)
        if type(tabs) == "number" and tabs > 0 then
            local total = 0
            w.tt = {}
            for t = 1, tabs do
                local tabName = Call(G.GetTalentTabInfo, t)
                local num = Call(G.GetNumTalents, t) or 0
                local pts = 0
                for i = 1, num do
                    local _, _, _, _, rank = Call(G.GetTalentInfo, t, i)
                    pts = pts + (Num(rank) or 0)
                end
                total = total + pts
                if type(tabName) == "string" then w.tt[tabName] = pts end
            end
            w.talents = total
        end
    end

    -- Erfolge
    w.achPts = Call(G.GetTotalAchievementPoints)
    local done = Call(G.GetNumCompletedAchievements)
    if type(done) == "number" then w.achCount = done end

    -- Reittiere und Begleiter
    local MJ = G.C_MountJournal
    if MJ and MJ.GetMountIDs then
        local ids = Call(MJ.GetMountIDs)
        if type(ids) == "table" then w.mountsKnown = #ids end
    end
    if G.GetNumCompanions then
        w.mounts = w.mounts or Call(G.GetNumCompanions, "MOUNT")
        w.critters = Call(G.GetNumCompanions, "CRITTER")
    end
end

------------------------------------------------------------------------
-- Ruf
------------------------------------------------------------------------

function W.Reputation(w)
    local n = Call(G.GetNumFactions)
    if type(n) ~= "number" then
        local RI = G.C_Reputation
        n = RI and Call(RI.GetNumFactions)
    end
    if type(n) ~= "number" or not G.GetFactionInfo then return end
    local stand, list, count = {}, {}, 0
    for i = 1, n do
        local name, _, standing, bmin, bmax, value, _, _, isHeader = Call(G.GetFactionInfo, i)
        if type(name) == "string" and not isHeader and type(standing) == "number" then
            count = count + 1
            stand[standing] = (stand[standing] or 0) + 1
            local pct = (type(bmin) == "number" and type(bmax) == "number" and bmax > bmin and type(value) == "number") and (value - bmin) / (bmax - bmin) * 100 or 0
            list[#list + 1] = { name, standing, pct }
        end
    end
    w.repN, w.repStand = count, stand
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[3] > b[3] end)
    w.repTop = {}
    for i = 1, math.min(5, #list) do w.repTop[i] = list[i] end
end

------------------------------------------------------------------------
-- Berufe und Fertigkeiten
------------------------------------------------------------------------

function W.Skills(w)
    local n = Call(G.GetNumSkillLines)
    if type(n) ~= "number" or not G.GetSkillLineInfo then return end
    w.skillRank, w.skillMax = {}, {}
    local header
    for i = 1, n do
        local name, isHeader, _, rank, _, _, maxRank = Call(G.GetSkillLineInfo, i)
        if type(name) == "string" then
            if isHeader then
                header = name
            elseif type(rank) == "number" and type(maxRank) == "number" and maxRank > 0 then
                w.skillRank[name], w.skillMax[name] = rank, maxRank
            end
        end
    end
    -- bekannte Rezepte der geoeffneten Berufsfenster werden im Spiel nicht gespeichert; nur Fertigkeiten zaehlen
end

------------------------------------------------------------------------
-- Ausruestung und Taschen
------------------------------------------------------------------------

function W.Equipment(w)
    if not G.GetInventoryItemLink then return end
    local eq = { epic = 0, rare = 0, filled = 0, minI = nil, maxI = nil }
    for slot = 1, 19 do
        if slot ~= 4 and slot ~= 18 then
            local link = Call(G.GetInventoryItemLink, "player", slot)
            if type(link) == "string" then
                eq.filled = eq.filled + 1
                local _, _, quality, ilvl = Call(G.GetItemInfo, link)
                if type(quality) == "number" then
                    if quality >= 4 then eq.epic = eq.epic + 1 end
                    if quality >= 3 then eq.rare = eq.rare + 1 end
                end
                if type(ilvl) == "number" and ilvl > 0 then
                    eq.minI = eq.minI and math.min(eq.minI, ilvl) or ilvl
                    eq.maxI = eq.maxI and math.max(eq.maxI, ilvl) or ilvl
                end
            end
        end
    end
    w.eq = eq
end

function W.Bags(w)
    local GetLink = (G.C_Container and G.C_Container.GetContainerItemLink) or G.GetContainerItemLink
    local GetNum = (G.C_Container and G.C_Container.GetContainerNumSlots) or G.GetContainerNumSlots
    local GetInfo = (G.C_Container and G.C_Container.GetContainerItemInfo) or G.GetContainerItemInfo
    if not (GetLink and GetNum and G.GetItemInfo) then return end
    local value, items, gray = 0, 0, 0
    for bag = 0, tonumber(G.NUM_BAG_SLOTS) or 4 do
        local slots = Call(GetNum, bag)
        for slot = 1, (type(slots) == "number" and slots or 0) do
            local link = Call(GetLink, bag, slot)
            if type(link) == "string" then
                local count = 1
                local info, c2 = Call(GetInfo, bag, slot)
                if type(info) == "table" then count = Num(info.stackCount) or 1 elseif type(c2) == "number" then count = c2 end
                local _, _, quality, _, _, _, _, _, _, _, sell = Call(G.GetItemInfo, link)
                items = items + count
                if type(sell) == "number" then value = value + sell * count end
                if quality == 0 then gray = gray + count end
            end
        end
    end
    w.bagValue, w.bagItems, w.bagGray = value, items, gray
end

------------------------------------------------------------------------
-- Quests (Abgleich mit dem Codex)
------------------------------------------------------------------------

local qs = nil   -- laufende Pruefung

local function ZoneOfMap(m, cache)
    if type(m) ~= "number" then return nil end
    local z = cache[m]
    if z == nil then
        local info = G.C_Map and G.C_Map.GetMapInfo and Call(G.C_Map.GetMapInfo, m)
        z = type(info) == "table" and info.name or false
        cache[m] = z
    end
    return z or nil
end

local function FlagFn()
    local QL = G.C_QuestLog
    local fn = (QL and QL.IsQuestFlaggedCompleted) or G.IsQuestFlaggedCompleted
    if type(fn) == "function" then return fn end
    return nil
end

-- Liste aller erledigten Quests am Stueck, falls der Client sie liefert: Menge oder nil
local function CompletedSet()
    local QL = G.C_QuestLog
    if QL and QL.GetAllCompletedQuestIDs then
        local r = Call(QL.GetAllCompletedQuestIDs)
        if type(r) == "table" then
            local set = {}
            for _, v in pairs(r) do if type(v) == "number" then set[v] = true end end
            return set
        end
    end
    if type(G.GetQuestsCompleted) == "function" then
        local r = Call(G.GetQuestsCompleted)
        if type(r) == "table" then
            local set = {}
            for k, v in pairs(r) do if type(k) == "number" and v then set[k] = true end end
            return set
        end
    end
    return nil
end
W.CompletedSet = CompletedSet

local function Account(q, id, def, cache)
    q.done = q.done + 1
    if type(def) == "table" then
        q.xp = q.xp + (Num(def.xp) or 0)
        q.money = q.money + (Num(def.money) or 0)
        q.items = q.items + (type(def.fixed) == "table" and #def.fixed or 0)
        local lvl = Num(def.lvl)
        if lvl and lvl > q.maxLvl then q.maxLvl = lvl end
        local ref = def.turn or def.give
        local zone = ref and ZoneOfMap(ref.m, cache)
        if zone then q.zones[zone] = (q.zones[zone] or 0) + 1 end
    end
end

local function Finish(w, q, partial)
    local QL = G.C_QuestLog
    local _, inLog = Call(G.GetNumQuestLogEntries)
    if type(inLog) ~= "number" and QL and QL.GetNumQuestLogEntries then _, inLog = Call(QL.GetNumQuestLogEntries) end
    q.log = inLog
    q.partial = partial and 1 or nil
    q.at = Now()
    w.q = q
end

-- Prueft alle Quests des Codex (gestueckelt, damit das Spiel nicht stockt)
function W.ScanQuests(onDone)
    if qs then return end
    local rec = Stats.Rec()
    local codex = FW.Codex
    if not rec or not codex or not codex.V then return end
    local V = codex.V()
    if not V or type(V.quests) ~= "table" then return end
    local q = { done = 0, xp = 0, money = 0, items = 0, maxLvl = 0, zones = {} }
    local cache = {}
    local set = CompletedSet()
    local ids = {}
    if set then
        for id in pairs(set) do ids[#ids + 1] = id end
    else
        local flag = FlagFn()
        if not flag then return end
        qs = { flag = flag }
        for id in pairs(V.quests) do ids[#ids + 1] = id end
    end
    qs = qs or {}
    local i, total = 1, #ids
    local function Step()
        local stop = math.min(total, i + 199)
        while i <= stop do
            local id = ids[i]
            local yes = set and true or Call(qs.flag, id)
            if yes then Account(q, id, V.quests[id], cache) end
            i = i + 1
        end
        if i <= total then
            if G.C_Timer and G.C_Timer.After then G.C_Timer.After(0.05, Step) else Step() end
            return
        end
        qs = nil
        local r = Stats.Rec()
        if r then
            r.w = r.w or {}
            Finish(r.w, q, false)
        end
        if onDone then onDone() end
    end
    Step()
end

------------------------------------------------------------------------
-- Gesamtlauf
------------------------------------------------------------------------

function W.Refresh(withBags)
    local rec = Stats.Rec()
    if not rec then return end
    rec.w = rec.w or {}
    local w = rec.w
    for _, fn in ipairs({ W.Character, W.Reputation, W.Skills, W.Equipment, withBags and W.Bags or false }) do
        if fn then pcall(fn, w) end
    end
    w.at = Now()
end

------------------------------------------------------------------------
-- Probe: welche Abfragen antworten im Client?
------------------------------------------------------------------------

local PROBES = {
    { "C_QuestLog.IsQuestFlaggedCompleted", function() return G.C_QuestLog and G.C_QuestLog.IsQuestFlaggedCompleted end },
    { "IsQuestFlaggedCompleted", function() return G.IsQuestFlaggedCompleted end },
    { "C_QuestLog.GetAllCompletedQuestIDs", function() return G.C_QuestLog and G.C_QuestLog.GetAllCompletedQuestIDs end },
    { "GetQuestsCompleted", function() return G.GetQuestsCompleted end },
    { "C_QuestLog.GetNumQuestLogEntries", function() return G.C_QuestLog and G.C_QuestLog.GetNumQuestLogEntries end },
    { "GetNumFactions", function() return G.GetNumFactions end },
    { "GetFactionInfo", function() return G.GetFactionInfo end },
    { "GetNumSkillLines", function() return G.GetNumSkillLines end },
    { "GetSkillLineInfo", function() return G.GetSkillLineInfo end },
    { "GetNumTalentTabs", function() return G.GetNumTalentTabs end },
    { "GetTalentInfo", function() return G.GetTalentInfo end },
    { "C_SpellBook.GetNumSpellBookSkillLines", function() return G.C_SpellBook and G.C_SpellBook.GetNumSpellBookSkillLines end },
    { "GetNumSpellTabs", function() return G.GetNumSpellTabs end },
    { "GetTotalAchievementPoints", function() return G.GetTotalAchievementPoints end },
    { "C_MountJournal.GetMountIDs", function() return G.C_MountJournal and G.C_MountJournal.GetMountIDs end },
    { "GetNumCompanions", function() return G.GetNumCompanions end },
    { "GetAverageItemLevel", function() return G.GetAverageItemLevel end },
    { "C_Map.GetMapInfo", function() return G.C_Map and G.C_Map.GetMapInfo end },
    { "C_MapExplorationInfo.GetExploredAreaIDsAtPosition", function() return G.C_MapExplorationInfo and G.C_MapExplorationInfo.GetExploredAreaIDsAtPosition end },
}

function W.Probe()
    local lines = {}
    for _, p in ipairs(PROBES) do
        local ok, fn = pcall(p[2])
        lines[#lines + 1] = string.format("%s = %s", p[1], (ok and type(fn) == "function") and "ja" or "NEIN")
    end
    local set = CompletedSet()
    local n = 0
    if set then for _ in pairs(set) do n = n + 1 end end
    lines[#lines + 1] = "Erledigte Quests als Liste: " .. (set and (n .. " Eintraege") or "keine Liste")
    local flag = FlagFn()
    local codexN = 0
    local V = FW.Codex and FW.Codex.V and FW.Codex.V()
    if V and V.quests then for _ in pairs(V.quests) do codexN = codexN + 1 end end
    lines[#lines + 1] = string.format("Codex kennt %d Quests, Einzelabfrage %s", codexN, flag and "moeglich" or "NICHT moeglich")
    local rec = Stats.Rec()
    local w = rec and rec.w
    if w then
        lines[#lines + 1] = string.format("Zauber=%s Talente=%s Ruf=%s Erfolge=%s Ausruestung=%s",
            tostring(w.spells), tostring(w.talents), tostring(w.repN), tostring(w.achCount), tostring(w.eq and w.eq.filled))
        local nskill = 0
        for _ in pairs(w.skillRank or {}) do nskill = nskill + 1 end
        lines[#lines + 1] = "Fertigkeiten gelesen: " .. nskill
    end
    local db = Stats.Db()
    if db then db.probe = { at = Now(), lines = lines } end
    return lines
end

local owner = {}
local pending
local function Later(sec, fn)
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(sec, fn) end
end

-- Aufruf aus StatsCollect (nach dem Anmelden) und bei Questabgabe
function W.Start()
    Later(8, function() W.Refresh(true) end)
    Later(25, function() pcall(W.ScanQuests) end)
    FW:RegisterEvent("QUEST_TURNED_IN", function()
        if pending then return end
        pending = true
        Later(20, function() pending = nil; pcall(W.ScanQuests) end)
    end, owner)
end

G.SLASH_FWSTATPROBE1 = "/fwstatprobe"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList["FWSTATPROBE"] = function()
    W.Refresh(true)
    for _, line in ipairs(W.Probe()) do FW:Print(line) end
    pcall(W.ScanQuests, function()
        local rec = Stats.Rec()
        local q = rec and rec.w and rec.w.q
        if q then FW:Print(string.format("Quest-Abgleich: %d erledigt, %d Erfahrung", q.done, q.xp)) end
    end)
end
