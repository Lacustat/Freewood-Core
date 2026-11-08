-- Freewood-Core: Herausforderungen und eigene Erfolge, Daten und Pruefung
--
-- Alles, was ein Spieler erstellt, sind reine DATEN (Tabellen), nie Lua-Code. Darum lassen sich Herausforderungen ueber das
-- Brett teilen: Jede Definition wird gegen die feste Liste unten geprueft (Rules.Validate) und nur in dieser Form angenommen.
--
-- Inhalt
--   1. Listen: Instanzen, Zonen, Zaehler
--   2. Bausteine (Rules.SPEC): Ziele, Regeln, Warnungen
--   3. Pruefung (Rules.Validate)
--   4. Klartext (Rules.Describe)
-- UNGEPRUEFT im Spiel (Forever).

local ADDON, FW = ...

local R = FW.Rules or {}
FW.Rules = R

local G = _G

------------------------------------------------------------------------
-- 1. Listen
------------------------------------------------------------------------

-- id = Karten-Kennung der Instanz (GetInstanceInfo), de/en = Namen
R.INSTANCES = {
    { id = 43, de = "Höhlen des Wehklagens", en = "Wailing Caverns" },
    { id = 36, de = "Die Todesminen", en = "The Deadmines" },
    { id = 33, de = "Burg Schattenfang", en = "Shadowfang Keep" },
    { id = 34, de = "Das Verlies", en = "The Stockade" },
    { id = 48, de = "Die Tiefschwarze Grotte", en = "Blackfathom Deeps" },
    { id = 90, de = "Gnomeregan", en = "Gnomeregan" },
    { id = 47, de = "Kral der Klingenhauer", en = "Razorfen Kraul" },
    { id = 189, de = "Das Scharlachrote Kloster", en = "Scarlet Monastery" },
    { id = 129, de = "Hügel der Klingenhauer", en = "Razorfen Downs" },
    { id = 70, de = "Uldaman", en = "Uldaman" },
    { id = 209, de = "Zul'Farrak", en = "Zul'Farrak" },
    { id = 349, de = "Maraudon", en = "Maraudon" },
    { id = 109, de = "Der Tempel von Atal'Hakkar", en = "The Temple of Atal'Hakkar" },
    { id = 230, de = "Die Schwarzfelstiefen", en = "Blackrock Depths" },
    { id = 229, de = "Die Schwarzfelsspitze", en = "Blackrock Spire" },
    { id = 429, de = "Düsterbruch", en = "Dire Maul" },
    { id = 289, de = "Scholomance", en = "Scholomance" },
    { id = 329, de = "Stratholme", en = "Stratholme" },
    { id = 249, de = "Onyxias Hort", en = "Onyxia's Lair" },
    { id = 409, de = "Der Geschmolzene Kern", en = "Molten Core" },
    { id = 309, de = "Zul'Gurub", en = "Zul'Gurub" },
    { id = 469, de = "Pechschwingenhort", en = "Blackwing Lair" },
    { id = 509, de = "Ruinen von Ahn'Qiraj", en = "Ruins of Ahn'Qiraj" },
    { id = 531, de = "Tempel von Ahn'Qiraj", en = "Temple of Ahn'Qiraj" },
    { id = 533, de = "Naxxramas", en = "Naxxramas" },
}

-- Zonen (Vanilla); eigene Namen sind ueber das Suchfenster ebenfalls moeglich (zid = 0)
R.ZONES = {
    { de = "Wald von Elwynn", en = "Elwynn Forest" }, { de = "Dun Morogh", en = "Dun Morogh" }, { de = "Tirisfal", en = "Tirisfal Glades" },
    { de = "Durotar", en = "Durotar" }, { de = "Mulgore", en = "Mulgore" }, { de = "Teldrassil", en = "Teldrassil" },
    { de = "Westfall", en = "Westfall" }, { de = "Loch Modan", en = "Loch Modan" }, { de = "Dunkelküste", en = "Darkshore" },
    { de = "Das Brachland", en = "The Barrens" }, { de = "Rotkammgebirge", en = "Redridge Mountains" }, { de = "Silberwald", en = "Silverpine Forest" },
    { de = "Steinkrallengebirge", en = "Stonetalon Mountains" }, { de = "Dämmerwald", en = "Duskwood" }, { de = "Sumpfland", en = "Wetlands" },
    { de = "Vorgebirge des Hügellands", en = "Hillsbrad Foothills" }, { de = "Eschental", en = "Ashenvale" }, { de = "Alteracgebirge", en = "Alterac Mountains" },
    { de = "Arathihochland", en = "Arathi Highlands" }, { de = "Tausend Nadeln", en = "Thousand Needles" }, { de = "Desolace", en = "Desolace" },
    { de = "Schlingendorntal", en = "Stranglethorn Vale" }, { de = "Sümpfe des Elends", en = "Swamp of Sorrows" }, { de = "Düstermarschen", en = "Dustwallow Marsh" },
    { de = "Feralas", en = "Feralas" }, { de = "Hinterland", en = "The Hinterlands" }, { de = "Tanaris", en = "Tanaris" },
    { de = "Sengende Schlucht", en = "Searing Gorge" }, { de = "Ödland", en = "Badlands" }, { de = "Die Verwüsteten Lande", en = "Blasted Lands" },
    { de = "Azshara", en = "Azshara" }, { de = "Teufelswald", en = "Felwood" }, { de = "Un'Goro-Krater", en = "Un'Goro Crater" },
    { de = "Winterquell", en = "Winterspring" }, { de = "Brennende Steppe", en = "Burning Steppes" }, { de = "Westliche Pestländer", en = "Western Plaguelands" },
    { de = "Östliche Pestländer", en = "Eastern Plaguelands" }, { de = "Silithus", en = "Silithus" }, { de = "Mondlichtung", en = "Moonglade" },
    { de = "Gebirgspass der Totenwinde", en = "Deadwind Pass" }, { de = "Sturmwind", en = "Stormwind City" }, { de = "Eisenschmiede", en = "Ironforge" },
    { de = "Darnassus", en = "Darnassus" }, { de = "Orgrimmar", en = "Orgrimmar" }, { de = "Donnerfels", en = "Thunder Bluff" }, { de = "Unterstadt", en = "Undercity" },
}

-- Zaehler der Statistik (rec.c), die fuer Ziele und eigene Erfolge zur Wahl stehen
R.COUNTERS = {
    { key = "kills", de = "Gegner besiegt", en = "Enemies defeated" },
    { key = "deaths", de = "Tode", en = "Deaths" },
    { key = "jumps", de = "Sprünge", en = "Jumps" },
    { key = "emotes", de = "Emotes", en = "Emotes" },
    { key = "casts", de = "Zauber gewirkt", en = "Spells cast" },
    { key = "combats", de = "Kämpfe", en = "Battles" },
    { key = "crafted", de = "Hergestellte Gegenstände", en = "Items crafted" },
    { key = "lootItems", de = "Erbeutete Gegenstände", en = "Items looted" },
    { key = "lootQ3", de = "Seltene (blaue) Gegenstände", en = "Rare (blue) items" },
    { key = "lootQ4", de = "Epische Gegenstände", en = "Epic items" },
    { key = "questsDone", de = "Abgeschlossene Quests", en = "Completed quests" },
    { key = "taxiTrips", de = "Flüge mit dem Flugmeister", en = "Flights taken" },
    { key = "chatMsgs", de = "Chatnachrichten", en = "Chat messages" },
    { key = "whispersIn", de = "Erhaltene Flüsternachrichten", en = "Whispers received" },
    { key = "mailsSent", de = "Verschickte Briefe", en = "Letters sent" },
    { key = "honorKills", de = "Ehrenhafte Siege", en = "Honorable kills" },
    { key = "loads", de = "Ladebildschirme", en = "Loading screens" },
}

local function Lang() return (FW.activeLocale == "deDE") and "de" or "en" end
R.Lang = Lang

function R.NameOfEntry(e) return e and (e[Lang()] or e.en or e.de) or nil end

function R.CounterEntry(key)
    for _, c in ipairs(R.COUNTERS) do if c.key == key then return c end end
    return nil
end

function R.InstanceEntry(id)
    for _, e in ipairs(R.INSTANCES) do if e.id == id then return e end end
    return nil
end

local function Lower(s) return tostring(s or ""):lower() end

-- Passt der Name der Welt zu einer Instanz-Angabe (Karten-Kennung oder Name in einer der beiden Sprachen)?
function R.InstanceMatch(spec, world)
    if not spec or not world then return false end
    if spec.inst and world.instId and spec.inst == world.instId then return true end
    local e = spec.inst and R.InstanceEntry(spec.inst)
    local n = Lower(world.instName)
    if n == "" then return false end
    if e and (Lower(e.de) == n or Lower(e.en) == n) then return true end
    return spec.iname ~= nil and Lower(spec.iname) == n
end

function R.ZoneMatch(spec, world)
    if not spec or not world then return false end
    local names = { Lower(spec.name) }
    local e = spec.zid and spec.zid > 0 and R.ZONES[spec.zid]
    if e then names[#names + 1] = Lower(e.de); names[#names + 1] = Lower(e.en) end
    local z, sz, inst = Lower(world.zone), Lower(world.subzone), Lower(world.instName)
    for _, n in ipairs(names) do
        if n ~= "" and (n == z or n == sz or n == inst) then return true end
    end
    return false
end

------------------------------------------------------------------------
-- 2. Bausteine
--   f = Felder: k (Schluessel), t = "pick" | "num" | "text" | "choice", kind = Suchart, nameKey = Feld fuer den Namen,
--   min / max, opt = darf fehlen, zero = ID 0 erlaubt, w = Breite im Editor
------------------------------------------------------------------------

local function Num(k, mn, mx, def) return { k = k, t = "num", min = mn, max = mx, def = def } end
local TXT = { k = "text", t = "text", max = 240 }

R.SPEC = {
    goal = {
        kill = { f = { { k = "id", t = "pick", kind = "units", nameKey = "name" }, Num("count", 1, 999, 1), { k = "inst", t = "pick", kind = "inst", nameKey = "iname", opt = true } } },
        level = { f = { Num("n", 2, 60, 10) } },
        quest = { f = { { k = "id", t = "pick", kind = "quests", nameKey = "name" } } },
        zone = { f = { { k = "zid", t = "pick", kind = "zone", nameKey = "name", zero = true } } },
        item = { f = { { k = "id", t = "pick", kind = "items", nameKey = "name" }, Num("count", 1, 9999, 1) } },
        counter = { f = { { k = "key", t = "choice" }, Num("n", 1, 10000000, 10) } },
    },
    rule = {
        nogroup = { f = {} },
        groupmax = { f = { Num("n", 2, 40, 2) } },
        levelbelow = { f = { Num("n", 2, 61, 25) } },
        deathsmax = { f = { Num("n", 0, 99, 0) } },
        timelimit = { f = { Num("n", 1, 600, 30) } },
        stayin = { f = { { k = "inst", t = "pick", kind = "inst", nameKey = "iname" } } },
        partner = { f = {} },
    },
    warn = {
        start = { f = { TXT } },
        level = { f = { Num("n", 2, 60, 24), TXT } },
        zone = { f = { { k = "zid", t = "pick", kind = "zone", nameKey = "name", zero = true }, TXT } },
        timeleft = { f = { Num("n", 1, 600, 5), TXT } },
    },
}
R.ORDER = {
    goal = { "kill", "level", "quest", "zone", "item", "counter" },
    rule = { "nogroup", "groupmax", "levelbelow", "deathsmax", "timelimit", "stayin", "partner" },
    warn = { "start", "level", "zone", "timeleft" },
}
R.LIMITS = { goal = 6, rule = 8, warn = 8, active = 5 }

------------------------------------------------------------------------
-- 3. Pruefung
------------------------------------------------------------------------

local function Str(s, max)
    s = tostring(s or ""):gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return (s:sub(1, max or 60))
end
R.Str = Str

local function Int(v, mn, mx)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v + 0.5)
    if mn and v < mn then return nil end
    if mx and v > mx then return nil end
    return v
end

local function Block(kind, b)
    if type(b) ~= "table" then return nil, "RV_BLOCK" end
    local spec = R.SPEC[kind][b.type]
    if not spec then return nil, "RV_TYPE" end
    local out = { type = b.type }
    for _, f in ipairs(spec.f) do
        local v = b[f.k]
        if f.t == "num" then
            local n = Int(v, f.min, f.max)
            if not n then return nil, "RV_NUM" end
            out[f.k] = n
        elseif f.t == "text" then
            local t = Str(v, f.max or 240)
            if t == "" then return nil, "RV_TEXT" end
            out[f.k] = t
        elseif f.t == "choice" then
            if not R.CounterEntry(v) then return nil, "RV_CHOICE" end
            out[f.k] = v
        elseif f.t == "pick" then
            local n = Int(v, f.zero and 0 or 1, 99999999)
            if not n then
                if f.opt and (v == nil or v == false) then
                    n = nil
                else
                    return nil, "RV_ID"
                end
            end
            out[f.k] = n
            if f.nameKey and n ~= nil then
                local nm = Str(b[f.nameKey], 60)
                if nm == "" and not (f.zero and n > 0) then
                    -- Name fehlt: bei Zonen aus der Liste ergibt er sich aus der ID
                    if f.kind == "zone" or f.kind == "inst" then nm = "" else return nil, "RV_NAME" end
                end
                out[f.nameKey] = nm ~= "" and nm or nil
            end
        end
    end
    -- Zone: Listeneintrag braucht keinen eigenen Namen; eigener Name (zid 0) schon
    if kind ~= "rule" and b.type == "zone" then
        if (out.zid or 0) == 0 and not out.name then return nil, "RV_NAME" end
        if (out.zid or 0) > #R.ZONES then return nil, "RV_ID" end
        if (out.zid or 0) > 0 then out.name = R.NameOfEntry(R.ZONES[out.zid]) end
    end
    -- Instanz ohne eigenen Namen: Name aus der Liste
    for _, key in ipairs({ "inst" }) do
        if out[key] and not out.iname then
            local e = R.InstanceEntry(out[key])
            if e then out.iname = R.NameOfEntry(e) end
        end
    end
    return out
end

-- Gibt eine saubere Kopie zurueck oder nil, Fehlerschluessel. Unbekannte Felder werden verworfen.
function R.Validate(def)
    if type(def) ~= "table" then return nil, "RV_DEF" end
    local out = { v = 1 }
    out.name = Str(def.name, 60)
    if out.name == "" then return nil, "RV_NAME" end
    out.desc = Str(def.desc, 300)
    out.author = Str(def.author, 40)
    for _, kind in ipairs({ "goal", "rule", "warn" }) do
        local src = def[kind .. "s"]
        out[kind .. "s"] = {}
        if type(src) ~= "table" then
            if kind == "goal" then return nil, "RV_GOALS" end
        else
            if #src > R.LIMITS[kind] then return nil, "RV_MANY" end
            for _, b in ipairs(src) do
                local ob, err = Block(kind, b)
                if not ob then return nil, err end
                out[kind .. "s"][#out[kind .. "s"] + 1] = ob
            end
        end
    end
    if #out.goals == 0 then return nil, "RV_GOALS" end
    local rw = type(def.reward) == "table" and def.reward or {}
    out.reward = { points = Int(rw.points, 0, 100) or 0, title = Str(rw.title, 30), text = Str(rw.text, 200) }
    return out
end

------------------------------------------------------------------------
-- 4. Klartext
------------------------------------------------------------------------

local function T(key, ...)
    local s = FW.L[key]
    if select("#", ...) > 0 then
        local ok, r = pcall(string.format, s, ...)
        if ok then return r end
    end
    return s
end
R.T = T

local function Where(b) return b.iname and (" " .. T("RD_IN", b.iname)) or "" end

function R.DescribeGoal(b)
    local t = b.type
    if t == "kill" then return T("RD_G_kill", b.name or ("#" .. tostring(b.id)), b.count or 1) .. Where(b)
    elseif t == "level" then return T("RD_G_level", b.n)
    elseif t == "quest" then return T("RD_G_quest", b.name or ("#" .. tostring(b.id)))
    elseif t == "zone" then return T("RD_G_zone", b.name or "?")
    elseif t == "item" then return T("RD_G_item", b.count or 1, b.name or ("#" .. tostring(b.id)))
    elseif t == "counter" then
        local c = R.CounterEntry(b.key)
        return T("RD_G_counter", b.n, c and R.NameOfEntry(c) or tostring(b.key))
    end
    return t
end

function R.DescribeRule(b)
    local t = b.type
    if t == "nogroup" then return T("RD_R_nogroup")
    elseif t == "groupmax" then return T("RD_R_groupmax", b.n)
    elseif t == "levelbelow" then return T("RD_R_levelbelow", b.n)
    elseif t == "deathsmax" then
        if (b.n or 0) == 0 then return T("RD_R_nodeath") end
        return T("RD_R_deathsmax", b.n)
    elseif t == "timelimit" then return T("RD_R_timelimit", b.n)
    elseif t == "stayin" then return T("RD_R_stayin", b.iname or "?")
    elseif t == "partner" then return T("RD_R_partner")
    end
    return t
end

function R.DescribeWarn(b)
    local t = b.type
    if t == "start" then return T("RD_W_start", b.text or "")
    elseif t == "level" then return T("RD_W_level", b.n, b.text or "")
    elseif t == "zone" then return T("RD_W_zone", b.name or "?", b.text or "")
    elseif t == "timeleft" then return T("RD_W_timeleft", b.n, b.text or "")
    end
    return t
end

-- Ein Absatz in Klartext: "Toete X ..., ohne Gruppe, ...".
function R.Describe(def)
    if type(def) ~= "table" then return "" end
    local goals = {}
    for _, g in ipairs(def.goals or {}) do goals[#goals + 1] = R.DescribeGoal(g) end
    local rules = {}
    for _, r in ipairs(def.rules or {}) do rules[#rules + 1] = R.DescribeRule(r) end
    local out = table.concat(goals, T("RD_AND"))
    if #rules > 0 then out = out .. T("RD_RULES_SEP") .. table.concat(rules, ", ") end
    return out .. "."
end
