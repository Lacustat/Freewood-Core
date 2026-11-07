-- Freewood-Core: Statistik, Daten
--
-- Sammelt Zahlen zu jedem Charakter (Account-weit gespeichert, Modul "Stats") und bereitet sie fuer den Reiter "Statistik" auf.
--   db.chars[Schluessel] = { info = {...}, c = {Zaehler}, z = {Zonen}, sz = {Unterzonen}, sp = {Zauber}, inst = {Instanzen},
--                            dz = {Todeszonen}, ch = {Kanaele}, snap = {Momentaufnahme}, best = {bester Fund}, first, last }
-- Alles stammt aus Ereignissen und eigenen Zaehlern; nichts davon ist im Spiel geprueft (Forever). Muster fuer Chatzeilen werden aus den
-- Spielkonstanten (LOOT_ITEM_SELF ...) gebaut, damit sie in jeder Sprache stimmen.
-- Geheime Werte (secret values) werden nie gerechnet: Alles geht durch Clean().

local ADDON, FW = ...

local Stats = { version = 1 }
FW.Stats = Stats

local G = _G

local function Clean(v)
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    return v
end
local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return Clean(a), Clean(b), Clean(c), Clean(d)
end

------------------------------------------------------------------------
-- Reine Hilfsfunktionen
------------------------------------------------------------------------

-- Spielkonstante mit %s/%d in ein Lua-Muster umwandeln: Treffer sind die Platzhalter in Reihenfolge
function Stats.PatternFor(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    p = p:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
    p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    return "^" .. p
end

-- Zaubername: gemerkter Name des Datensatzes, sonst die Abfragen des Clients (Forever: C_Spell), sonst "#id"
function Stats.SpellName(id, rec)
    local saved = rec and rec.spn and rec.spn[id]
    if type(saved) == "string" and saved ~= "" then return saved end
    local name
    local CS = G.C_Spell
    if CS and CS.GetSpellName then name = Call(CS.GetSpellName, id) end
    if not name and CS and CS.GetSpellInfo then
        local info = Call(CS.GetSpellInfo, id)
        name = type(info) == "table" and info.name or (type(info) == "string" and info) or nil
    end
    if not name and G.GetSpellInfo then
        local n = Call(G.GetSpellInfo, id)
        name = type(n) == "table" and n.name or n
    end
    if type(name) == "string" and name ~= "" then
        if rec then rec.spn = rec.spn or {}; rec.spn[id] = name end
        return name
    end
    return "#" .. tostring(id)
end

-- Qualitaet (0 grau .. 5 orange) aus einem Gegenstandslink
local QUALITY_COLOR = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
function Stats.QualityOfLink(link)
    if type(link) ~= "string" then return nil end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    return hex and QUALITY_COLOR[hex:lower()] or nil
end

-- Beutemeldung auswerten: gibt Link und Anzahl zurueck (nur eigene Beute). patterns = Liste von Mustern der eigenen Zeilen.
function Stats.ParseLoot(msg, patterns)
    if type(msg) ~= "string" then return nil end
    for _, e in ipairs(patterns or {}) do
        local a, b = msg:match(e.p)
        if a then
            local link, n = a, 1
            if e.multi then link, n = a, tonumber(b) or 1 end
            if link:find("|Hitem:", 1, true) or link:find("|c", 1, true) then
                return link, n, e.kind
            end
        end
    end
    return nil
end

-- Erfahrungspunkte aus einer XP-Meldung: gibt (Punkte, istKill)
function Stats.ParseXP(msg, killPat, otherPat)
    if type(msg) ~= "string" then return nil end
    if killPat then
        local _, xp = msg:match(killPat)
        if xp then return tonumber(xp), true end
    end
    if otherPat then
        local xp = msg:match(otherPat)
        if xp then return tonumber(xp), false end
    end
    local n = msg:match("(%d+)")
    return n and tonumber(n) or nil, false
end

function Stats.Num(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local s = tostring(math.abs(n))
    local sep = (FW.activeLocale == "deDE") and "." or ","
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
    if out:sub(1, 1) == sep then out = out:sub(2) end
    return (n < 0 and "-" or "") .. out
end

function Stats.Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out
    if g > 0 then out = string.format("%sg %ds %dc", Stats.Num(g), s, c)
    elseif s > 0 then out = string.format("%ds %dc", s, c)
    else out = string.format("%dc", c) end
    return (neg and "-" or "") .. out
end

function Stats.Duration(sec)
    sec = math.floor(tonumber(sec) or 0)
    local L = FW.L or {}
    local d, h, m = math.floor(sec / 86400), math.floor(sec / 3600) % 24, math.floor(sec / 60) % 60
    if d > 0 then return string.format(L.STATS_DUR_D or "%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format(L.STATS_DUR_H or "%dh %dm", h, m) end
    if m > 0 then return string.format(L.STATS_DUR_M or "%dm %ds", m, sec % 60) end
    return string.format(L.STATS_DUR_S or "%ds", sec)
end

function Stats.Km(yards)
    return string.format("%s km", (string.format("%.1f", (tonumber(yards) or 0) * 0.9144 / 1000):gsub("%.", FW.activeLocale == "deDE" and "," or ".")))
end

function Stats.Percent(n)
    return string.format("%s %%", (string.format("%.1f", tonumber(n) or 0):gsub("%.", FW.activeLocale == "deDE" and "," or ".")))
end

-- Geldaenderung einer Quelle zuordnen. ctx = { merchant, mail, auction, trade, questAge, lootAge } (Alter in Sekunden oder nil)
function Stats.MoneySource(delta, ctx)
    ctx = ctx or {}
    if ctx.trade then return "trade" end
    if ctx.auction then return "auction" end
    if ctx.mail then return "mail" end
    if ctx.merchant then return delta > 0 and "vendorIn" or "vendorOut" end
    if delta > 0 and ctx.questAge and ctx.questAge < 2 then return "quest" end
    if delta > 0 and ctx.lootAge and ctx.lootAge < 2 then return "loot" end
    return "other"
end

------------------------------------------------------------------------
-- Speicher
------------------------------------------------------------------------

function Stats.Db()
    local mod = FW.modules and FW.modules.Stats
    return mod and mod.db or nil
end

function Stats.Key()
    local name = Call(G.UnitName, "player")
    local realm = Call(G.GetRealmName)
    if type(name) ~= "string" then return nil end
    return name .. "-" .. tostring(realm or "?")
end

function Stats.NewRecord()
    return { info = {}, c = {}, z = {}, sz = {}, sp = {}, inst = {}, dz = {}, ch = {}, snap = {}, first = Now(), last = Now() }
end

function Stats.Rec(create)
    local db = Stats.Db()
    local key = Stats.Key()
    if not db or not key then return nil end
    db.chars = db.chars or {}
    local rec = db.chars[key]
    if not rec and create ~= false then
        rec = Stats.NewRecord()
        db.chars[key] = rec
    end
    return rec, key
end

local function Inc(tbl, k, n)
    tbl[k] = (tbl[k] or 0) + (n or 1)
end
Stats.Inc = Inc

-- Zaehler des aktuellen Charakters erhoehen
function Stats.Count(key, n)
    local rec = Stats.Rec()
    if rec then Inc(rec.c, key, n) end
end

------------------------------------------------------------------------
-- Aufbereitung: Kategorien mit Zeilen
------------------------------------------------------------------------

local QUAL = { [0] = "STATS_Q0", "STATS_Q1", "STATS_Q2", "STATS_Q3", "STATS_Q4", "STATS_Q5" }
local CHANNELS = { "SAY", "YELL", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER", "CHANNEL", "EMOTE", "INSTANCE_CHAT" }
Stats.CHANNELS = CHANNELS

local function Top(tbl, n, labelFn)
    local list = {}
    for k, v in pairs(tbl or {}) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return tostring(a.k) < tostring(b.k) end)
    local out = {}
    for i = 1, math.min(n, #list) do out[#out + 1] = { labelFn and labelFn(list[i].k) or tostring(list[i].k), list[i].v } end
    return out
end

local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

local function Row(rows, label, value)
    rows[#rows + 1] = { label, value }
end

-- Symbole der Kategorien (Standard-Symbole des Spiels)
Stats.ICONS = {
    overview = "INV_Misc_Note_01", values = "INV_Shield_06", combat = "Ability_Warrior_OffensiveStance", kills = "INV_Sword_04",
    xp = "INV_Misc_Book_09", gold = "INV_Misc_Coin_01", loot = "INV_Misc_Bag_10", travel = "INV_Misc_Map_01",
    social = "INV_Letter_02", quests = "INV_Scroll_03", charx = "Spell_Holy_PrayerOfHealing", rep = "INV_Shirt_GuildTabard_01",
    skills = "INV_Hammer_20", gear = "INV_Chest_Cloth_17", explore = "INV_Misc_Spyglass_02", deaths = "INV_Misc_Bone_HumanSkull_01",
    chars = "INV_Misc_Eye_01",
}

-- Kategorien fuer einen Datensatz. opts.codex = { cells, edges, worlds, flights } (Wegenetz und Fluege aus Freewood-Codex)
function Stats.Model(rec, opts)
    opts = opts or {}
    local L = FW.L or setmetatable({}, { __index = function(_, k) return k end })
    local c, info, snap = rec.c or {}, rec.info or {}, rec.snap or {}
    local cats = {}
    local function Cat(id, titleKey)
        local cat = { id = id, title = L[titleKey] or titleKey, rows = {} }
        cats[#cats + 1] = cat
        return cat.rows
    end

    -- Ueberblick
    local r = Cat("overview", "STATS_C_OVERVIEW")
    Row(r, L.STATS_NAME, tostring(info.name or "?"))
    Row(r, L.STATS_CLASS, tostring(info.classLocal or info.class or "?"))
    Row(r, L.STATS_RACE, tostring(info.race or "?"))
    Row(r, L.STATS_FACTION, tostring(info.faction or "?"))
    Row(r, L.STATS_LEVEL, tostring(info.level or "?"))
    if info.guild and info.guild ~= "" then Row(r, L.STATS_GUILD, info.guild .. (info.rank and (" (" .. info.rank .. ")") or "")) end
    Row(r, L.STATS_PLAYED, Stats.Duration(math.max(rec.played or 0, c.online or 0)))
    Row(r, L.STATS_ONLINE, Stats.Duration(c.online or 0))
    Row(r, L.STATS_REST, Stats.Duration(c.restSecs or 0))
    Row(r, L.STATS_AFK, Stats.Duration(c.afkSecs or 0))
    Row(r, L.STATS_FIRST, G.date and G.date("%d.%m.%Y %H:%M", rec.first or 0) or tostring(rec.first))
    Row(r, L.STATS_LAST, G.date and G.date("%d.%m.%Y %H:%M", rec.last or 0) or tostring(rec.last))

    -- Werte (Momentaufnahme)
    r = Cat("values", "STATS_C_VALUES")
    local function Snap(label, key, fmt)
        local v = snap[key]
        if v ~= nil then Row(r, label, fmt and fmt(v) or Stats.Num(v)) end
    end
    Snap(L.STATS_HEALTH, "health"); Snap(L.STATS_POWER, "power")
    Snap(L.STATS_STR, "str"); Snap(L.STATS_AGI, "agi"); Snap(L.STATS_STA, "sta"); Snap(L.STATS_INT, "int"); Snap(L.STATS_SPI, "spi")
    Snap(L.STATS_ARMOR, "armor"); Snap(L.STATS_AP, "ap"); Snap(L.STATS_RAP, "rap")
    Snap(L.STATS_SPELLPOWER, "sp"); Snap(L.STATS_HEALPOWER, "hp")
    Snap(L.STATS_CRIT, "crit", Stats.Percent); Snap(L.STATS_SCRIT, "scrit", Stats.Percent)
    Snap(L.STATS_DODGE, "dodge", Stats.Percent); Snap(L.STATS_PARRY, "parry", Stats.Percent); Snap(L.STATS_BLOCK, "block", Stats.Percent)
    Snap(L.STATS_SPEED, "speed", Stats.Percent)
    Snap(L.STATS_ILVL, "ilvl"); Snap(L.STATS_DURA, "dura", Stats.Percent)
    if snap.bagFree then Row(r, L.STATS_BAGS, string.format("%d / %d", snap.bagFree, snap.bagTotal or 0)) end
    if snap.at then Row(r, L.STATS_SNAPAT, G.date and G.date("%d.%m.%Y %H:%M", snap.at) or "") end

    -- Kampf
    r = Cat("combat", "STATS_C_COMBAT")
    Row(r, L.STATS_COMBATS, Stats.Num(c.combats))
    Row(r, L.STATS_COMBATTIME, Stats.Duration(c.combatSecs or 0))
    if (c.combats or 0) > 0 then Row(r, L.STATS_COMBAVG, Stats.Duration((c.combatSecs or 0) / c.combats)) end
    Row(r, L.STATS_KILLS, Stats.Num(c.kills))
    Row(r, L.STATS_HKILLS, Stats.Num(c.honorKills))
    Row(r, L.STATS_DEATHS, Stats.Num(c.deaths))
    Row(r, L.STATS_CASTS, Stats.Num(c.casts))
    for i, e in ipairs(Top(rec.sp, 8, function(id) return Stats.SpellName(id, rec) end)) do
        Row(r, string.format("%d. %s", i, e[1]), Stats.Num(e[2]))
    end

    -- Kills laut Codex (Account-weit, jede Kreatur einzeln)
    local ck = opts.codex and opts.codex.kills
    if ck then
        r = Cat("kills", "STATS_C_KILLS")
        Row(r, L.STATS_CK_TOTAL, Stats.Num(ck.total))
        Row(r, L.STATS_CK_SPECIES, Stats.Num(ck.species))
        Row(r, L.STATS_CK_LOOTED, Stats.Num(ck.looted))
        for i, e in ipairs(ck.top or {}) do Row(r, string.format("%d. %s", i, tostring(e[1])), Stats.Num(e[2])) end
    end

    -- Erfahrung und Quests
    r = Cat("xp", "STATS_C_XP")
    Row(r, L.STATS_XPTOTAL, Stats.Num(c.xp))
    Row(r, L.STATS_XPKILL, Stats.Num(c.xpKill))
    Row(r, L.STATS_XPQUEST, Stats.Num(c.questXP))
    Row(r, L.STATS_XPOTHER, Stats.Num(math.max(0, (c.xp or 0) - (c.xpKill or 0) - (c.questXP or 0))))
    Row(r, L.STATS_QACC, Stats.Num(c.questsAccepted))
    Row(r, L.STATS_QDONE, Stats.Num(c.questsDone))
    Row(r, L.STATS_QMONEY, Stats.Money(c.questMoney))

    -- Gold
    r = Cat("gold", "STATS_C_GOLD")
    if snap.money then Row(r, L.STATS_GOLDNOW, Stats.Money(snap.money)) end
    Row(r, L.STATS_EARNED, Stats.Money(c.moneyEarned))
    Row(r, L.STATS_SPENT, Stats.Money(c.moneySpent))
    Row(r, L.STATS_NET, Stats.Money((c.moneyEarned or 0) - (c.moneySpent or 0)))
    Row(r, L.STATS_GLOOT, Stats.Money(c.m_loot))
    Row(r, L.STATS_GQUEST, Stats.Money(c.m_quest))
    Row(r, L.STATS_GVENDOR_IN, Stats.Money(c.m_vendorIn))
    Row(r, L.STATS_GVENDOR_OUT, Stats.Money(c.m_vendorOut))
    Row(r, L.STATS_GMAIL, Stats.Money(c.m_mail))
    Row(r, L.STATS_GAUCTION, Stats.Money(c.m_auction))
    Row(r, L.STATS_GTRADE, Stats.Money(c.m_trade))
    Row(r, L.STATS_GOTHER, Stats.Money(c.m_other))
    Row(r, L.STATS_GMAX, Stats.Money(c.maxMoney))

    -- Beute
    r = Cat("loot", "STATS_C_LOOT")
    Row(r, L.STATS_LOOTALL, Stats.Num(c.lootItems))
    for q = 0, 5 do Row(r, L[QUAL[q]] or ("Q" .. q), Stats.Num(c["lootQ" .. q])) end
    Row(r, L.STATS_CRAFTED, Stats.Num(c.crafted))
    if rec.best and rec.best.link then Row(r, L.STATS_BEST, rec.best.link) end

    -- Reisen und Wege
    r = Cat("travel", "STATS_C_TRAVEL")
    local total = (c.distFoot or 0) + (c.distMount or 0) + (c.distSwim or 0) + (c.distFly or 0)
    Row(r, L.STATS_DIST_ALL, Stats.Km(total))
    Row(r, L.STATS_DIST_FOOT, Stats.Km(c.distFoot))
    Row(r, L.STATS_DIST_MOUNT, Stats.Km(c.distMount))
    Row(r, L.STATS_DIST_SWIM, Stats.Km(c.distSwim))
    Row(r, L.STATS_DIST_FLY, Stats.Km(c.distFly))
    Row(r, L.STATS_TAXI_TRIPS, Stats.Num(c.taxiTrips))
    Row(r, L.STATS_TAXI_TIME, Stats.Duration(c.taxiSecs or 0))
    Row(r, L.STATS_JUMPS, Stats.Num(c.jumps))
    Row(r, L.STATS_LOADS, Stats.Num(c.loads))
    Row(r, L.STATS_ZONES, Stats.Num(Count(rec.z)))
    Row(r, L.STATS_SUBZONES, Stats.Num(Count(rec.sz)))
    Row(r, L.STATS_INSTANCES, Stats.Num(c.instances))
    for i, e in ipairs(Top(rec.inst, 5)) do Row(r, string.format("%d. %s", i, e[1]), Stats.Num(e[2])) end
    if opts.codex then
        Row(r, L.STATS_PATH_CELLS, Stats.Num(opts.codex.cells))
        Row(r, L.STATS_PATH_EDGES, Stats.Num(opts.codex.edges))
        if opts.codex.flights then Row(r, L.STATS_FLIGHTS_KNOWN, Stats.Num(opts.codex.flights)) end
    end

    -- Soziales
    r = Cat("social", "STATS_C_SOCIAL")
    Row(r, L.STATS_MSGS, Stats.Num(c.chatMsgs))
    Row(r, L.STATS_CHARS, Stats.Num(c.chatChars))
    for _, ch in ipairs(CHANNELS) do
        local n = (rec.ch or {})[ch]
        if n and n > 0 then Row(r, L["STATS_CH_" .. ch] or ch, Stats.Num(n)) end
    end
    Row(r, L.STATS_WHISPERS_IN, Stats.Num(c.whispersIn))
    Row(r, L.STATS_MAILS, Stats.Num(c.mailsSent))
    Row(r, L.STATS_GROUP, Stats.Duration(c.groupSecs or 0))
    Row(r, L.STATS_RAID, Stats.Duration(c.raidSecs or 0))
    Row(r, L.STATS_EMOTES, Stats.Num(c.emotes))

    -- Welt (Abfragen im Spiel, siehe StatsWorld.lua)
    local w = rec.w or {}
    local q = w.q
    if q then
        r = Cat("quests", "STATS_C_QUESTS")
        Row(r, L.STATS_Q_DONE, Stats.Num(q.done))
        if q.log then Row(r, L.STATS_Q_LOG, Stats.Num(q.log)) end
        Row(r, L.STATS_Q_XP, Stats.Num(q.xp))
        Row(r, L.STATS_Q_MONEY, Stats.Money(q.money))
        Row(r, L.STATS_Q_ITEMS, Stats.Num(q.items))
        if (q.maxLvl or 0) > 0 then Row(r, L.STATS_Q_MAXLVL, Stats.Num(q.maxLvl)) end
        for i, e in ipairs(Top(q.zones, 6)) do Row(r, string.format("%d. %s", i, e[1]), Stats.Num(e[2])) end
    end
    if w.repN or w.talents or w.spells or w.achCount or w.mounts or w.mountsKnown then
        r = Cat("charx", "STATS_C_CHARX")
        if w.spells then Row(r, L.STATS_SPELLS_KNOWN, Stats.Num(w.spells)) end
        if w.talents then Row(r, L.STATS_TALENTS, Stats.Num(w.talents)) end
        for name, pts in pairs(w.tt or {}) do Row(r, "  " .. name, Stats.Num(pts)) end
        if w.achCount then Row(r, L.STATS_ACH, Stats.Num(w.achCount)) end
        if w.achPts then Row(r, L.STATS_ACH_PTS, Stats.Num(w.achPts)) end
        local m = w.mountsKnown or w.mounts
        if m then Row(r, L.STATS_MOUNTS, Stats.Num(m)) end
        if w.critters then Row(r, L.STATS_CRITTERS, Stats.Num(w.critters)) end
    end
    if w.repN then
        r = Cat("rep", "STATS_C_REP")
        Row(r, L.STATS_REP_N, Stats.Num(w.repN))
        local st = w.repStand or {}
        for id = 8, 5, -1 do
            local label = G["FACTION_STANDING_LABEL" .. id] or ("#" .. id)
            Row(r, label, Stats.Num(st[id] or 0))
        end
        for i, e in ipairs(w.repTop or {}) do
            Row(r, string.format("%d. %s", i, tostring(e[1])), string.format("%s (%s)", G["FACTION_STANDING_LABEL" .. (e[2] or 0)] or "?", Stats.Percent(e[3])))
        end
    end
    if w.skillRank and next(w.skillRank) then
        r = Cat("skills", "STATS_C_SKILLS")
        local list = {}
        for name, rank in pairs(w.skillRank) do list[#list + 1] = { name, rank, (w.skillMax or {})[name] or 0 } end
        table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
        for _, e in ipairs(list) do Row(r, e[1], string.format("%s / %s", Stats.Num(e[2]), Stats.Num(e[3]))) end
    end
    if w.eq or w.bagItems then
        r = Cat("gear", "STATS_C_GEAR")
        local eq = w.eq
        if eq then
            Row(r, L.STATS_EQ_FILLED, Stats.Num(eq.filled))
            Row(r, L.STATS_EQ_EPIC, Stats.Num(eq.epic))
            Row(r, L.STATS_EQ_RARE, Stats.Num(eq.rare))
            if eq.minI then Row(r, L.STATS_EQ_ILVL, string.format("%s - %s", Stats.Num(eq.minI), Stats.Num(eq.maxI))) end
        end
        if w.bagItems then
            Row(r, L.STATS_BAG_ITEMS, Stats.Num(w.bagItems))
            Row(r, L.STATS_BAG_GRAY, Stats.Num(w.bagGray or 0))
            Row(r, L.STATS_BAG_VALUE, Stats.Money(w.bagValue or 0))
        end
    end
    if opts.codex then
        r = Cat("explore", "STATS_C_EXPLORE")
        Row(r, L.STATS_ZONES_N, Stats.Num(Count(rec.z)))
        Row(r, L.STATS_SUBZONES_N, Stats.Num(Count(rec.sz)))
        if opts.codex.flights then Row(r, L.STATS_FLIGHTS_KNOWN, Stats.Num(opts.codex.flights)) end
        if opts.codex.cells then Row(r, L.STATS_PATH_CELLS, Stats.Num(opts.codex.cells)) end
    end

    -- Tode
    r = Cat("deaths", "STATS_C_DEATHS")
    Row(r, L.STATS_DEATHS, Stats.Num(c.deaths))
    for i, e in ipairs(Top(rec.dz, 5)) do Row(r, string.format("%d. %s", i, e[1]), Stats.Num(e[2])) end

    return cats
end

-- Kills aus den Codex-Daten (Account-weit): units[id].xp[Spielerstufe] = { n, ... } zaehlt jeden Kill mit Erfahrung,
-- units[id].k die gelooteten Leichen. Ergebnis wird 30 s gemerkt (die Tabelle hat tausende Eintraege).
local killCache
function Stats.CodexKills(codex)
    local now = Now()
    if killCache and now - killCache.at < 30 then return killCache.v end
    local db = codex and codex.db
    local units = db and db.units
    if type(units) ~= "table" then return nil end
    local total, species, looted = 0, 0, 0
    local per = {}
    for id, u in pairs(units) do
        if type(u) == "table" then
            local n = 0
            for _, e in pairs(type(u.xp) == "table" and u.xp or {}) do
                if type(e) == "table" then n = n + (tonumber(e.n) or 0) end
            end
            local k = tonumber(u.k) or 0
            looted = looted + k
            if n > 0 then
                total, species = total + n, species + 1
                per[id] = n
            end
        end
    end
    if total == 0 and looted == 0 then return nil end
    local top = Top(per, 8, function(id)
        local u = units[id]
        local name = type(u) == "table" and type(u.n) == "string" and u.n or nil
        return name or ("#" .. tostring(id))
    end)
    local v = { total = total, species = species, looted = looted, top = top }
    killCache = { at = now, v = v }
    return v
end

-- Summe aller Charaktere (Zaehler, Zonen usw.); info und snap beschreiben die Gesamtheit
function Stats.Sum(chars)
    local out = Stats.NewRecord()
    out.first, out.last = nil, 0
    local n, levels, maxLevel, money = 0, 0, 0, 0
    local function Merge(dst, src)
        for k, v in pairs(src or {}) do
            if type(v) == "number" then dst[k] = (dst[k] or 0) + v end
        end
    end
    for _, rec in pairs(chars or {}) do
        n = n + 1
        Merge(out.c, rec.c)
        Merge(out.sp, rec.sp)
        for k, v in pairs(rec.spn or {}) do out.spn = out.spn or {}; out.spn[k] = v end
        Merge(out.inst, rec.inst)
        Merge(out.dz, rec.dz)
        Merge(out.ch, rec.ch)
        for k in pairs(rec.z or {}) do out.z[k] = true end
        for k in pairs(rec.sz or {}) do out.sz[k] = true end
        out.c.maxMoney = math.max(out.c.maxMoney or 0, (rec.c or {}).maxMoney or 0)
        local lv = tonumber((rec.info or {}).level) or 0
        levels = levels + lv
        maxLevel = math.max(maxLevel, lv)
        money = money + (tonumber((rec.snap or {}).money) or 0)
        out.played = (out.played or 0) + math.max(rec.played or 0, (rec.c or {}).online or 0)
        if not out.first or (rec.first or 0) < out.first then out.first = rec.first end
        out.last = math.max(out.last, rec.last or 0)
    end
    -- Weltdaten: Zahlen und Zaehlertabellen summieren, Fertigkeiten je Name das Maximum
    out.w = { q = { done = 0, xp = 0, money = 0, items = 0, maxLvl = 0, zones = {} }, repStand = {}, tt = {}, skillRank = {}, skillMax = {}, eq = { epic = 0, rare = 0, filled = 0 } }
    local hasQ = false
    for _, rec in pairs(chars or {}) do
        local w = rec.w
        if w then
            for _, k in ipairs({ "spells", "talents", "achCount", "achPts", "mountsKnown", "mounts", "critters", "repN", "bagValue", "bagItems", "bagGray" }) do
                if type(w[k]) == "number" then out.w[k] = (out.w[k] or 0) + w[k] end
            end
            for k, v in pairs(w.repStand or {}) do out.w.repStand[k] = (out.w.repStand[k] or 0) + v end
            for k, v in pairs(w.tt or {}) do out.w.tt[k] = (out.w.tt[k] or 0) + v end
            for k, v in pairs(w.skillRank or {}) do
                if v > (out.w.skillRank[k] or 0) then out.w.skillRank[k], out.w.skillMax[k] = v, (w.skillMax or {})[k] end
            end
            if w.eq then for _, k in ipairs({ "epic", "rare", "filled" }) do out.w.eq[k] = out.w.eq[k] + (w.eq[k] or 0) end end
            if w.q then
                hasQ = true
                local q = out.w.q
                for _, k in ipairs({ "done", "xp", "money", "items" }) do q[k] = q[k] + (w.q[k] or 0) end
                q.maxLvl = math.max(q.maxLvl, w.q.maxLvl or 0)
                for k, v in pairs(w.q.zones or {}) do q.zones[k] = (q.zones[k] or 0) + v end
                if w.q.log then q.log = (q.log or 0) + w.q.log end
            end
        end
    end
    if not hasQ then out.w.q = nil end
    -- maxMoney wurde oben mit Merge aufsummiert: ueberschreiben
    local best = 0
    for _, rec in pairs(chars or {}) do best = math.max(best, (rec.c or {}).maxMoney or 0) end
    out.c.maxMoney = best
    out.first = out.first or Now()
    out.info = { name = string.format("%d", n), level = maxLevel, class = "-", race = "-", faction = "-" }
    out.snap = { money = money }
    out.count, out.levelSum = n, levels
    return out
end

-- Liste der Charaktere fuer die Account-Ansicht, hoechste Stufe zuerst
function Stats.CharList(chars)
    local list = {}
    for key, rec in pairs(chars or {}) do
        local info = rec.info or {}
        list[#list + 1] = { key = key, name = info.name or key, class = info.class, level = tonumber(info.level) or 0,
            money = tonumber((rec.snap or {}).money) or 0, online = (rec.c or {}).online or 0, last = rec.last or 0, rec = rec }
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    return list
end
