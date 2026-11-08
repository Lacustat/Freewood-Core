-- Freewood-Core: Erfolge, Daten und Auswertung
--
-- Eigene Erfolge fuer Charakter und Account (Forever hat keine Blizzard-Erfolge, nur das Legacy-System).
-- Jeder Erfolg hat bis zu vier Stufen: Bronze, Silber, Gold, Platin (Punkte 5 / 10 / 20 / 40).
--   Charakter: zaehlt nur den angemeldeten Charakter (Datensatz der Statistik, rec.ach[id] = { l = Stufe, at = Zeit }).
--   Account:   zaehlt die Summe aller Charaktere (Stats.Sum), gespeichert in db.acct[id] = { l, at, by = Charakter }.
-- Alle Zahlen kommen aus den vorhandenen Zaehlern der Statistik (rec.c, rec.z, rec.inst, rec.info). Neue Zaehler gibt es nicht.
-- UNGEPRUEFT im Spiel (Forever).
--
-- Inhalt
--   1. Stufen und Punkte
--   2. Hilfsfunktionen fuer Messwerte
--   3. Katalog
--   4. Auswertung (Value, Level, Progress, Points)
--   5. Speicher, Pruefung, Meldungen, Titel

local ADDON, FW = ...

local A = { version = 1 }
FW.Ach = A

local G = _G

------------------------------------------------------------------------
-- 1. Stufen und Punkte
------------------------------------------------------------------------

A.TIER_IDS = { "bronze", "silver", "gold", "platinum" }
A.POINTS = { 5, 10, 20, 40 }
A.COLORS = {
    { 0.80, 0.50, 0.20 },   -- Bronze
    { 0.78, 0.80, 0.86 },   -- Silber
    { 1.00, 0.82, 0.10 },   -- Gold
    { 0.55, 0.85, 1.00 },   -- Platin
}
A.TITLE_TIER = 3            -- ab Gold gibt es den Titel

------------------------------------------------------------------------
-- 2. Hilfsfunktionen fuer Messwerte (r = Datensatz eines Charakters oder Stats.Sum)
------------------------------------------------------------------------

local function C(key) return function(r) return ((r and r.c) or {})[key] or 0 end end
local function Hours(key) return function(r) return math.floor((((r and r.c) or {})[key] or 0) / 3600) end end
local function Gold(key) return function(r) return math.floor((((r and r.c) or {})[key] or 0) / 10000) end end
local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function Level(r) return tonumber(((r and r.info) or {}).level) or 0 end
local function Zones(r) return Count(r and r.z) end
local function Instances(r) return Count(r and r.inst) end
local function InstRuns(r) local n = 0 for _, v in pairs((r and r.inst) or {}) do n = n + (tonumber(v) or 0) end return n end
local function Played(r) return math.floor(math.max((r and r.played) or 0, ((r and r.c) or {}).online or 0) / 3600) end

------------------------------------------------------------------------
-- 3. Katalog
--   id, cat, m = Messfunktion(r, ctx), t = Schwellen (aufsteigend), from = Stufe der ersten Schwelle (Standard 1 = Bronze),
--   scope = "acct" nur Account, sonst beides, de/en = { Name, Beschreibung mit {n} }, title = { de, en } (optional)
------------------------------------------------------------------------

A.CATS = { "grow", "combat", "loot", "quest", "explore", "dungeon", "craft", "travel", "social", "pvp", "fun", "custom", "account" }

local D = {}
local function Add(id, cat, m, t, de, en, extra)
    local e = { id = id, cat = cat, m = m, t = t, de = de, en = en }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    D[#D + 1] = e
end

-- Aufstieg
Add("lvl", "grow", Level, { 10, 20, 40, 60 }, { "Aufsteiger", "Erreiche Stufe {n}." }, { "Climber", "Reach level {n}." },
    { title = { "der Aufsteiger", "the Climber" } })
Add("time", "grow", Played, { 1, 10, 100, 500 }, { "Zeit in Azeroth", "Verbringe {n} Std. im Spiel." }, { "Time in Azeroth", "Spend {n} hours in the game." },
    { title = { "der Dauerspieler", "the Long-Timer" } })
Add("casts", "grow", C("casts"), { 100, 1000, 10000, 50000 }, { "Zauberlehrling", "Wirke {n} Zauber." }, { "Sorcerer's Apprentice", "Cast {n} spells." })

-- Kampf
Add("kills", "combat", C("kills"), { 100, 1000, 10000, 100000 }, { "Schlächter", "Besiege {n} Gegner." }, { "Slayer", "Defeat {n} enemies." },
    { title = { "der Schlächter", "the Slayer" } })
Add("combats", "combat", C("combats"), { 50, 500, 5000, 25000 }, { "Raufbold", "Kämpfe {n} Kämpfe." }, { "Brawler", "Fight {n} battles." })
Add("combattime", "combat", Hours("combatSecs"), { 1, 10, 50, 200 }, { "Dauerkämpfer", "Kämpfe insgesamt {n} Std." }, { "Nonstop Fighter", "Spend {n} hours in combat." })
Add("deaths", "combat", C("deaths"), { 1, 10, 50, 250 }, { "Teppichkunde", "Sterbe {n} Mal." }, { "Carpet Inspector", "Die {n} times." },
    { title = { "der Teppichkunde", "the Carpet Inspector" } })

-- Beute und Geld
Add("loot", "loot", C("lootItems"), { 100, 1000, 5000, 20000 }, { "Sammler", "Erbeute {n} Gegenstände." }, { "Collector", "Loot {n} items." })
Add("blue", "loot", C("lootQ3"), { 1, 10, 50, 200 }, { "Blaues Wunder", "Erbeute {n} seltene (blaue) Gegenstände." }, { "Something Blue", "Loot {n} rare (blue) items." })
Add("epic", "loot", C("lootQ4"), { 1, 5, 25, 100 }, { "Episch!", "Erbeute {n} epische Gegenstände." }, { "Epic!", "Loot {n} epic items." })
Add("legend", "loot", C("lootQ5"), { 1 }, { "Legendär", "Erbeute {n} legendären Gegenstand." }, { "Legendary", "Loot {n} legendary item." }, { from = 4 })
Add("gold", "loot", Gold("maxMoney"), { 1, 10, 100, 1000 }, { "Goldfinger", "Besitze gleichzeitig {n} Gold." }, { "Goldfinger", "Hold {n} gold at once." })
Add("spent", "loot", Gold("moneySpent"), { 10, 100, 1000, 10000 }, { "Großer Spender", "Gib insgesamt {n} Gold aus." }, { "Big Spender", "Spend {n} gold in total." })
Add("trash", "loot", C("lootQ0"), { 50, 500, 2000, 10000 }, { "Müllsammler", "Erbeute {n} graue Gegenstände." }, { "Trash Collector", "Loot {n} gray items." },
    { title = { "der Müllsammler", "the Trash Collector" } })

-- Quests
Add("quests", "quest", C("questsDone"), { 25, 100, 500, 1000 }, { "Questmeister", "Schließe {n} Quests ab." }, { "Quest Master", "Complete {n} quests." },
    { title = { "Questmeister", "Quest Master" } })
Add("questxp", "quest", C("questXP"), { 10000, 100000, 1000000, 5000000 }, { "Lehrreich", "Erhalte {n} Erfahrung aus Quests." }, { "Educational", "Earn {n} experience from quests." })
Add("accepted", "quest", C("questsAccepted"), { 25, 100, 500, 1000 }, { "Auftragsannehmer", "Nimm {n} Quests an." }, { "Job Taker", "Accept {n} quests." })

-- Erkundung
Add("zones", "explore", Zones, { 3, 8, 15, 25 }, { "Entdecker", "Besuche {n} verschiedene Zonen." }, { "Explorer", "Visit {n} different zones." },
    { title = { "der Entdecker", "the Explorer" } })
Add("loads", "explore", C("loads"), { 10, 100, 500, 2000 }, { "Ladebalken-Freund", "Sieh {n} Ladebildschirme." }, { "Loading Bar Friend", "See {n} loading screens." })

-- Instanzen
Add("dungeons", "dungeon", Instances, { 1, 5, 10, 15 }, { "Verlies-Forscher", "Betritt {n} verschiedene Instanzen." }, { "Dungeon Delver", "Enter {n} different instances." })
Add("runs", "dungeon", InstRuns, { 1, 10, 50, 200 }, { "Verlies-Stammgast", "Betritt Instanzen {n} Mal." }, { "Dungeon Regular", "Enter instances {n} times." },
    { title = { "der Verlies-Stammgast", "the Dungeon Regular" } })
Add("groupt", "dungeon", Hours("groupSecs"), { 1, 10, 50, 200 }, { "Teamplayer", "Verbringe {n} Std. in einer Gruppe." }, { "Team Player", "Spend {n} hours in a group." })
Add("raidt", "dungeon", Hours("raidSecs"), { 1, 10, 50, 200 }, { "Schlachtzugs-Veteran", "Verbringe {n} Std. in einem Schlachtzug." }, { "Raid Veteran", "Spend {n} hours in a raid." })

-- Berufe
Add("crafted", "craft", C("crafted"), { 10, 100, 1000, 5000 }, { "Handwerker", "Stelle {n} Gegenstände her." }, { "Craftsman", "Craft {n} items." },
    { title = { "der Handwerker", "the Craftsman" } })

-- Reisen
Add("taxi", "travel", C("taxiTrips"), { 1, 25, 100, 500 }, { "Taxi bitte", "Fliege {n} Mal mit einem Flugmeister." }, { "Taxi, please", "Take {n} flights with a flight master." },
    { title = { "der Vielflieger", "the Frequent Flyer" } })
Add("taxit", "travel", Hours("taxiSecs"), { 1, 5, 20, 50 }, { "Fensterplatz", "Verbringe {n} Std. auf Flügen." }, { "Window Seat", "Spend {n} hours on flights." })
Add("jumps", "travel", C("jumps"), { 100, 1000, 10000, 50000 }, { "Hüpfer", "Springe {n} Mal." }, { "Hopper", "Jump {n} times." },
    { title = { "der Hüpfer", "the Hopper" } })

-- Gesellig
Add("chatmsg", "social", C("chatMsgs"), { 10, 100, 1000, 10000 }, { "Gesprächig", "Schreibe {n} Chatnachrichten." }, { "Talkative", "Send {n} chat messages." })
Add("chatchars", "social", C("chatChars"), { 1000, 10000, 100000, 500000 }, { "Vielredner", "Tippe {n} Zeichen in den Chat." }, { "Chatterbox", "Type {n} characters into chat." },
    { title = { "die Plaudertasche", "the Chatterbox" } })
Add("whisper", "social", C("whispersIn"), { 1, 10, 100, 500 }, { "Flüsterer", "Erhalte {n} Flüsternachrichten." }, { "Whisperer", "Receive {n} whispers." })
Add("emotes", "social", C("emotes"), { 10, 100, 500, 2000 }, { "Tänzer", "Nutze {n} Emotes." }, { "Dancer", "Use {n} emotes." })
Add("mail", "social", C("mailsSent"), { 1, 10, 50, 200 }, { "Brieffreund", "Verschicke {n} Briefe." }, { "Pen Pal", "Send {n} letters." })

-- PvP
Add("honor", "pvp", C("honorKills"), { 1, 25, 250, 1000 }, { "Ehrenhaft", "Erlange {n} Ehrenhafte Siege." }, { "Honorable", "Earn {n} honorable kills." })

-- Lustiges
Add("afk", "fun", Hours("afkSecs"), { 1, 10, 50, 200 }, { "Sofa-Held", "Sei insgesamt {n} Std. AFK." }, { "Couch Hero", "Be AFK for {n} hours in total." },
    { title = { "der Sofa-Held", "the Couch Hero" } })
Add("rest", "fun", Hours("restSecs"), { 1, 10, 50, 200 }, { "Dauercamper", "Ruhe dich insgesamt {n} Std. aus (Gasthaus oder Stadt)." }, { "Permanent Camper", "Rest for {n} hours in total (inn or city)." })

-- Account (nur Summe aller Charaktere)
Add("a_chars", "account", function(_, ctx) return ctx and ctx.chars or 0 end, { 2, 5, 10, 20 },
    { "Altoholic", "Spiele {n} verschiedene Charaktere." }, { "Altoholic", "Play {n} different characters." }, { scope = "acct", title = { "der Altoholic", "the Altoholic" } })
Add("a_classes", "account", function(_, ctx) return ctx and ctx.classes or 0 end, { 3, 5, 7, 9 },
    { "Klassenvielfalt", "Spiele {n} verschiedene Klassen." }, { "Class Variety", "Play {n} different classes." }, { scope = "acct" })
Add("a_max", "account", function(_, ctx) return ctx and ctx.maxed or 0 end, { 1, 2, 5, 9 },
    { "Stufe 60 mehrfach", "Bringe {n} Charaktere auf Stufe 60." }, { "Many Sixties", "Bring {n} characters to level 60." }, { scope = "acct" })

A.CATALOG = D
A.BY_ID = {}
for i, e in ipairs(D) do e.idx = i; A.BY_ID[e.id] = e end

------------------------------------------------------------------------
-- Texte
------------------------------------------------------------------------

local function Lang() return (FW.activeLocale == "deDE") and "de" or "en" end

local function Num(n)
    if FW.Stats and FW.Stats.Num then return FW.Stats.Num(n) end
    return tostring(math.floor((tonumber(n) or 0) + 0.5))
end
A.Num = Num

function A.Name(e) return (e[Lang()] or e.en)[1] end

-- Beschreibung mit der naechsten (oder letzten) Schwelle
function A.Desc(e, threshold)
    local txt = (e[Lang()] or e.en)[2]
    local n = threshold or e.t[#e.t]
    return (txt:gsub("{n}", function() return Num(n) end))
end

function A.TitleOf(e)
    if not e.title then return nil end
    return e.title[Lang() == "de" and 1 or 2]
end

------------------------------------------------------------------------
-- 4. Auswertung
------------------------------------------------------------------------

-- Stufe (0 bis 4) fuer einen Wert
function A.LevelFor(e, value)
    local lvl = 0
    local from = e.from or 1
    for k, th in ipairs(e.t) do
        if (value or 0) >= th then lvl = from + k - 1 end
    end
    return lvl
end

function A.MaxLevel(e) return (e.from or 1) + #e.t - 1 end

-- Fortschritt: value, level, maxLevel, next (naechste Schwelle oder nil), prev (letzte erreichte Schwelle oder 0), frac (0 bis 1)
function A.Progress(e, value)
    value = tonumber(value) or 0
    local lvl = A.LevelFor(e, value)
    local from = e.from or 1
    local k = lvl >= from and (lvl - from + 1) or 0
    local nextT = e.t[k + 1]
    local prev = k > 0 and e.t[k] or 0
    local frac = 1
    if nextT then frac = math.max(0, math.min(1, (value - prev) / math.max(1, nextT - prev))) end
    return { value = value, level = lvl, max = A.MaxLevel(e), next = nextT, prev = prev, frac = frac }
end

-- Punkte fuer eine erreichte Stufe (nur die Stufen dieses Erfolgs)
function A.PointsFor(e, level)
    local pts = 0
    for l = (e.from or 1), math.min(level or 0, A.MaxLevel(e)) do pts = pts + (A.POINTS[l] or 0) end
    return pts
end

function A.MaxPoints(e) return A.PointsFor(e, A.MaxLevel(e)) end

-- Zusatzwerte fuer Account-Erfolge
function A.Context(chars)
    local n, classes, maxed, seen = 0, 0, 0, {}
    for _, rec in pairs(chars or {}) do
        n = n + 1
        local info = rec.info or {}
        if type(info.class) == "string" and info.class ~= "" and not seen[info.class] then seen[info.class] = true; classes = classes + 1 end
        if (tonumber(info.level) or 0) >= 60 then maxed = maxed + 1 end
    end
    return { chars = n, classes = classes, maxed = maxed }
end

-- Liste fuer die Anzeige: view = "char" oder "acct"
function A.View(view, rec, sum, ctx, accDb)
    local out = {}
    for _, e in ipairs(D) do
        if view == "acct" or e.scope ~= "acct" then
            local r = (view == "acct") and sum or rec
            local value = e.m(r, ctx or {})
            local p = A.Progress(e, value)
            local saved = (view == "acct") and (accDb or {})[e.id] or ((rec and rec.ach) or {})[e.id]
            if type(saved) == "table" and (saved.l or 0) > p.level then p.level = saved.l end
            p.def = e
            p.at = type(saved) == "table" and saved.at or nil
            p.by = type(saved) == "table" and saved.by or nil
            p.points = A.PointsFor(e, p.level)
            out[#out + 1] = p
        end
    end
    return out
end

function A.Totals(list)
    local pts, max, done = 0, 0, 0
    for _, p in ipairs(list) do
        pts = pts + p.points
        max = max + A.MaxPoints(p.def)
        if p.level >= p.max then done = done + 1 end
    end
    return pts, max, done, #list
end

------------------------------------------------------------------------
-- 5. Speicher, Pruefung, Meldungen, Titel
------------------------------------------------------------------------

if FW.NewModule then
    A.module = FW:NewModule("Achievements", {
        defaults = { acct = {}, notify = true, titleChat = true, title = nil, filter = "all", init = false },
    })
end

function A.Db()
    return A.module and A.module.db or nil
end

local function Clean(v)
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    return v
end

local function Now() return G.time and G.time() or 0 end

-- Pruefen: neue Stufen merken, Meldung ausloesen. silent = ohne Meldung. Gibt die Liste neuer Stufen zurueck.
function A.Check(silent)
    local Stats = FW.Stats
    local db = A.Db()
    if not (Stats and db and Stats.Rec and Stats.Db) then return nil end
    local rec, key = Stats.Rec(false)
    local sdb = Stats.Db()
    if not rec or not sdb then return nil end
    rec.ach = rec.ach or {}
    db.acct = db.acct or {}
    local sum = Stats.Sum(sdb.chars)
    local ctx = A.Context(sdb.chars)
    local firstChar = not rec.achInit
    local firstAcct = not db.init
    local events = {}
    local now = Now()
    for _, e in ipairs(D) do
        if e.scope ~= "acct" then
            local lvl = A.LevelFor(e, Clean(e.m(rec, {})))
            local old = rec.ach[e.id]
            if lvl > ((old and old.l) or 0) then
                rec.ach[e.id] = { l = lvl, at = now }
                if not firstChar then events[#events + 1] = { def = e, level = lvl, scope = "char" } end
            end
        end
        local lvl2 = A.LevelFor(e, Clean(e.m(sum, ctx)))
        local old2 = db.acct[e.id]
        if lvl2 > ((old2 and old2.l) or 0) then
            db.acct[e.id] = { l = lvl2, at = now, by = key }
            if not firstAcct then events[#events + 1] = { def = e, level = lvl2, scope = "acct", by = key } end
        end
    end
    rec.achInit = true
    db.init = true
    if not silent and #events > 0 then A.Announce(events) end
    return events
end

function A.Announce(events)
    if FW.Fire then pcall(FW.Fire, FW, "FW_ACH_UNLOCKED", events) end
    local db = A.Db()
    if db and db.notify ~= false and A.OnToast then pcall(A.OnToast, events) end
end

-- Titel: freigeschaltet, wenn der Account-Fortschritt die Titel-Stufe erreicht hat
function A.UnlockedTitles()
    local db = A.Db()
    local out = {}
    if not db then return out end
    for _, e in ipairs(D) do
        local s = db.acct and db.acct[e.id]
        if e.title and s and (s.l or 0) >= A.TITLE_TIER then out[#out + 1] = e end
    end
    return out
end

-- Alle waehlbaren Titel: { { value = Schluessel, text = Titeltext } } (Erfolge und Herausforderungen)
function A.TitleList()
    local out = {}
    for _, e in ipairs(A.UnlockedTitles()) do out[#out + 1] = { value = e.id, text = A.TitleOf(e) } end
    local R = FW.Rules
    if R and R.UnlockedTitles then
        for _, t in ipairs(R.UnlockedTitles()) do out[#out + 1] = { value = t.key, text = t.text } end
    end
    return out
end

function A.TitleText(value)
    if not value or value == "" then return nil end
    local R = FW.Rules
    if type(value) == "string" and value:sub(1, 2) == "c:" then return R and R.TitleText and R.TitleText(value) or nil end
    local e = A.BY_ID[value]
    return e and A.TitleOf(e) or nil
end

function A.ActiveTitle()
    local db = A.Db()
    if not db or not db.title then return nil end
    if type(db.title) == "string" and db.title:sub(1, 2) == "c:" then
        local R = FW.Rules
        return R and R.TitleText and R.TitleText(db.title) or nil
    end
    local e = A.BY_ID[db.title]
    local s = db.acct and db.acct[db.title]
    if e and s and (s.l or 0) >= A.TITLE_TIER then return A.TitleOf(e) end
    return nil
end

-- Anhang fuer den Namen im Chatfenster (eigene Nachrichten); leer, wenn aus
function A.TitleTag()
    local db = A.Db()
    if not db or db.titleChat == false then return "" end
    local t = A.ActiveTitle()
    if not t then return "" end
    return "  \124cffffd100<" .. t .. ">\124r"
end

-- Aufruf durch Zeitgeber (alle 20 s, nicht im Kampf)
local acc, startedAt = 0, nil
local ticker = G.CreateFrame and G.CreateFrame("Frame") or nil
if ticker and ticker.SetScript then
    ticker:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        startedAt = (startedAt or 0) + (elapsed or 0)
        if acc < 20 or startedAt < 12 then return end
        acc = 0
        if G.InCombatLockdown and G.InCombatLockdown() then return end
        pcall(A.Check)
    end)
end
