-- Test der Herausforderungen: Pruefung, Klartext, Annehmen, Auswertung, Scheitern, Abschluss, Titel (texlua tests/rules_test.lua)
local function Proxy()
    return setmetatable({}, { __index = function(_, k)
        if k == "child" or k == "label" or k == "scroll" then return Proxy() end
        return function() return Proxy() end
    end })
end
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
local now = 1000
_G.time = function() return now end
local fired, printed = {}, {}
local FW = { activeLocale = "enUS", modules = {}, Util = { IsSecret = function() return false end },
    Print = function(_, t) printed[#printed + 1] = t end, locales = {},
    Fire = function(_, e, ...) fired[#fired + 1] = e end,
    RegisterEvent = function() end, chardb = {} }
FW.L = setmetatable({}, { __index = function(_, k) return (FW.locales[k]) or k end })
function FW:AddLocale(loc, t) if loc == "enUS" then for k, v in pairs(t) do FW.locales[k] = v end end end
function FW:NewModule(name, opts)
    opts.db = { defs = {}, seq = 0, done = {}, titles = {} }
    self.modules[name] = opts
    return opts
end
local function Load(f) assert(loadfile(f))("Freewood-Core", FW) end
Load("Stats/StatsData.lua")
Load("Stats/AchData.lua")
Load("Core/RulesLocales.lua")
Load("Core/RulesData.lua")
Load("Core/Rules.lua")
local R = FW.Rules

-- Pruefung
eq(R.Validate(nil), nil, "kein Table")
eq(select(2, R.Validate({ name = "", goals = {} })), "RV_NAME", "Name fehlt")
eq(select(2, R.Validate({ name = "X", goals = {} })), "RV_GOALS", "ohne Ziele")
eq(select(2, R.Validate({ name = "X", goals = { { type = "evil" } } })), "RV_TYPE", "unbekannter Baustein")
eq(select(2, R.Validate({ name = "X", goals = { { type = "level", n = 999 } } })), "RV_NUM", "Zahl ausser Bereich")
local many = {}
for i = 1, 7 do many[i] = { type = "level", n = 10 } end
eq(select(2, R.Validate({ name = "X", goals = many })), "RV_MANY", "zu viele Ziele")
local good = {
    name = "Wehklagen\124 solo", desc = "d", bogus = "x",
    goals = { { type = "kill", id = 3654, name = "Mutanus", count = 1, inst = 43, extra = "x" } },
    rules = { { type = "nogroup" }, { type = "levelbelow", n = 25 }, { type = "deathsmax", n = 0 } },
    warns = { { type = "level", n = 24, text = "Gleich Stufe 25!" } },
    reward = { points = 20, title = "Solist", text = "Gut" },
}
local c = R.Validate(good)
eq(c ~= nil, true, "gueltig")
eq(c.name, "Wehklagen solo", "Steuerzeichen entfernt")
eq(c.bogus, nil, "unbekanntes Feld verworfen")
eq(c.goals[1].extra, nil, "unbekanntes Feld im Baustein verworfen")
eq(c.goals[1].iname ~= nil, true, "Instanzname aus Liste")
eq(#c.rules, 3, "drei Regeln")
eq(c.reward.points, 20, "Punkte")
eq(R.Validate({ name = "X", goals = { { type = "level", n = 10 } }, reward = { points = 5000 } }).reward.points, 0, "Punkte ausser Bereich -> 0")
eq(select(2, R.Validate({ name = "X", goals = { { type = "kill", id = 1, count = 1 } } })), "RV_NAME", "Ziel ohne Namen")
eq(select(2, R.Validate({ name = "X", goals = { { type = "level", n = 10 } }, warns = { { type = "start", text = "" } } })), "RV_TEXT", "Warntext leer")
-- Code wird nie uebernommen
local code = R.Validate({ name = "X", goals = { { type = "level", n = 10 } }, onDone = "os.execute('x')" })
eq(code.onDone, nil, "kein Code")

-- Klartext
local d = R.Describe(c)
eq(type(d) == "string" and d:find("Mutanus", 1, true) ~= nil, true, "Klartext nennt das Ziel")
eq(d:sub(-1), ".", "Klartext endet mit Punkt")

-- Speichern, Import
local id = R.Save(good)
eq(id, "L1", "erste Kennung")
eq(R.Get(id).src, "mine", "eigene Quelle")
eq(R.Import(good, "L1", "board"), nil, "eigene nicht ueberschreibbar")
eq(R.Import({ name = "" }, "B1", "board"), nil, "Import ungueltig")
eq(R.Import(good, "B1", "board"), "B1", "Import gueltig")
eq(R.Get("B1").src, "board", "Quelle board")
eq(#R.List(), 2, "zwei in der Liste")
eq(R.List()[1].src, "mine", "eigene zuerst")

-- Welt
local world = { level = 20, inGroup = false, groupSize = 1, zone = "Barrens", subzone = "", instName = nil }
R.worldFn = function() return world end

-- Annehmen
eq(R.Status(id), "new", "neu")
local ok = R.Accept(id)
eq(ok, true, "angenommen")
eq(R.Status(id), "active", "aktiv")
eq(R.ActiveCount(), 1, "eine aktive")
eq(select(2, R.CanAccept(id)), "CH_ALREADY", "schon aktiv")

-- Kill nur in der Instanz
R.OnKill("Mutanus", 3654)
eq(R.GoalProgress(R.Get(id).goals[1], 1, FW.chardb.rules.act[id], world), 0, "Kill ausserhalb zaehlt nicht")
world.instName, world.instId = "Wailing Caverns", 43
-- Gruppe -> gescheitert
world.inGroup, world.groupSize = true, 2
R.Step()
eq(R.Status(id), "failed", "Gruppe bricht ab")
eq(FW.chardb.rules.hist[id].reason, "nogroup", "Grund")
eq(printed[#printed]:find("Wehklagen", 1, true) ~= nil, true, "Hinweis gedruckt")
eq(R.ActiveCount(), 0, "keine aktive mehr")

-- Neuer Versuch nur ohne Verstoss
local okr, why = R.CanAccept(id)
eq(okr, false, "in Gruppe nicht annehmbar"); eq(why, "CH_BROKEN_nogroup", "Grund Gruppe")
world.inGroup, world.groupSize = false, 1
eq(R.Accept(id), true, "neuer Versuch")
eq(FW.chardb.rules.hist[id].tries, 2, "Versuche gezaehlt")
-- Warnung bei Stufe 24, einmalig
world.level = 24
local before = #printed
R.Step(); R.Step()
local warns = 0
for i = before + 1, #printed do if printed[i]:find("Gleich Stufe 25", 1, true) then warns = warns + 1 end end
eq(warns, 1, "Warnung genau einmal")
-- Stufe 25 -> gescheitert
world.level = 25
R.Step()
eq(R.Status(id), "failed", "Stufe 25 bricht ab")
-- Erfolg: Kill zaehlt vor Regelbruch (Boss gibt Stufe)
world.level = 20
R.Accept(id)
R.OnKill("Mutanus", 3654)
eq(R.Status(id), "done", "Ziel erreicht")
eq(R.Get(id) ~= nil and select(1, R.Points()), 20, "20 Punkte")
eq(R.Db().titles[id], "Solist", "Titel freigeschaltet")
eq(R.TitleText("c:" .. id), "Solist", "Titeltext")
eq(R.UnlockedTitles()[1].key, "c:" .. id, "Titelschluessel")
-- Zweiter Abschluss gibt keine Punkte mehr
eq(select(2, R.CanAccept(id)), "CH_ALREADY_DONE", "nicht erneut")

-- Zaehler, Stufe, Quest, Zeit
local id2 = R.Save({ name = "Springer", goals = { { type = "counter", key = "jumps", n = 5 } }, rules = { { type = "timelimit", n = 1 } } })
FW.Stats = { Rec = function() return { c = { jumps = 100 } } end, Key = function() return "Lacustat-X" end }
R.Accept(id2)
FW.Stats = { Rec = function() return { c = { jumps = 104 } } end, Key = function() return "Lacustat-X" end }
R.Step()
eq(R.Status(id2), "active", "4 von 5")
FW.Stats = { Rec = function() return { c = { jumps = 105 } } end, Key = function() return "Lacustat-X" end }
R.Step()
eq(R.Status(id2), "done", "5 von 5")
local id3 = R.Save({ name = "Eile", goals = { { type = "level", n = 60 } }, rules = { { type = "timelimit", n = 1 } } })
R.Accept(id3)
now = now + 61
R.Step()
eq(R.Status(id3), "failed", "Zeitlimit")
eq(FW.chardb.rules.hist[id3].reason, "timelimit", "Grund Zeit")

-- Quest
local id4 = R.Save({ name = "Auftrag", goals = { { type = "quest", id = 100, name = "Q" } } })
R.Accept(id4); R.OnQuest(99); eq(R.Status(id4), "active", "falsche Quest")
R.OnQuest(100); eq(R.Status(id4), "done", "Quest erledigt")

-- Tod
local id5 = R.Save({ name = "Unsterblich", goals = { { type = "level", n = 60 } }, rules = { { type = "deathsmax", n = 0 } } })
R.Accept(id5); R.OnDeath()
eq(R.Status(id5), "failed", "Tod beendet")

-- Aufgeben, Loeschen, Grenze
local id6 = R.Save({ name = "A", goals = { { type = "level", n = 60 } } })
R.Accept(id6); R.Abandon(id6)
eq(R.Status(id6), "new", "aufgegeben -> neu")
eq(R.Delete(id6), true, "geloescht")
eq(R.Get(id6), nil, "weg")
for i = 1, 5 do local x = R.Save({ name = "G" .. i, goals = { { type = "level", n = 60 } } }); R.Accept(x) end
local idx = R.Save({ name = "Sechste", goals = { { type = "level", n = 60 } } })
eq(select(2, R.Accept(idx)), "CH_TOO_MANY", "hoechstens 5 aktive")

-- Annehmen nicht moeglich, wenn Regel schon verletzt
FW.chardb.rules.act = {}
world.level = 30
local idl = R.Save({ name = "Zu spaet", goals = { { type = "level", n = 60 } }, rules = { { type = "levelbelow", n = 25 } } })
local okl, whyl = R.CanAccept(idl)
eq(okl, false, "Regel schon verletzt"); eq(whyl, "CH_BROKEN_levelbelow", "Grund")

-- Ereignisse melden
local seen = false
for _, e in ipairs(fired) do if e == "FW_CHALLENGE_DONE" then seen = true end end
eq(seen, true, "Ereignis DONE gefeuert")

-- Eigene Erfolge
local A = FW.Ach
local baseCount = #A.CATALOG
eq(select(2, R.ValidateAch({ name = "", key = "jumps", t = { 1 } })), "RV_NAME", "Erfolg ohne Name")
eq(select(2, R.ValidateAch({ name = "X", key = "nope", t = { 1 } })), "RV_CHOICE", "Erfolg unbekannter Zaehler")
eq(select(2, R.ValidateAch({ name = "X", key = "jumps", t = {} })), "RV_THRESH", "keine Schwellen")
eq(select(2, R.ValidateAch({ name = "X", key = "jumps", t = { 5, 5 } })), "RV_THRESH", "Schwellen muessen steigen")
eq(select(2, R.ValidateAch({ name = "X", key = "jumps", t = { 1, 2, 3, 4, 5 } })), "RV_THRESH", "hoechstens 4 Schwellen")
local aid = R.SaveAch({ name = "Huepfer\124", desc = "Springe {n} mal.", key = "jumps", t = { 10, 100, 1000 }, title = "der Springer" })
eq(aid, "A1", "erste Erfolgskennung")
eq(#A.CATALOG, baseCount + 1, "Erfolg im Katalog")
local ce = A.BY_ID["u_A1"]
eq(ce ~= nil and ce.cat, "custom", "Kategorie Eigene")
eq(A.Name(ce), "Huepfer", "Name bereinigt")
eq(ce.m({ c = { jumps = 55 } }), 55, "Messfunktion Zaehler")
eq(A.LevelFor(ce, 150), 2, "Stufe Silber")
eq(A.TitleOf(ce), "der Springer", "Titel")
eq(R.Import and R.ImportAch({ name = "Fremd", key = "kills", t = { 1 } }, "B9", "board"), "B9", "Erfolg importieren")
eq(#R.ListAch(), 2, "zwei eigene Erfolge")
eq(R.ListAch()[1].src, "mine", "eigene zuerst")
eq(R.ImportAch({ name = "Fremd", key = "kills", t = { 1 } }, "A1", "board"), nil, "eigene nicht ueberschreibbar")
eq(R.DeleteAch("A1"), true, "Erfolg geloescht")
eq(A.BY_ID["u_A1"], nil, "aus dem Katalog entfernt")
eq(#A.CATALOG, baseCount + 1, "nur der importierte bleibt")
local hasCat = false
for _, c in ipairs(A.CATS) do if c == "custom" then hasCat = true end end
eq(hasCat, true, "Kategorie vorhanden")

-- Partner
FW.chardb.rules.act = {}
local sent = {}
R.sendFn = function(t) sent[#sent + 1] = t end
_G.UnitName = function() return "Ich" end
world.level, world.inGroup, world.groupSize = 20, false, 1
local pid = R.Save({ name = "Zu zweit", goals = { { type = "level", n = 21 } }, rules = { { type = "partner" } } })
local pdef = R.Get(pid)
local hash = R.DefHash(pdef)
eq(R.HasPartnerRule(pdef), true, "Partnerregel erkannt")
eq(R.HasPartnerRule(R.Get(id2)), false, "keine Partnerregel")
eq(R.Accept(pid), true, "Partner-Herausforderung angenommen")
-- allein: Ziel erreicht, aber ohne Partner zaehlt es nicht
world.level = 21
R.Step()
eq(R.Status(pid), "active", "ohne Partner nicht geschafft")
-- Gruppe aus zwei: Ping wird gesendet
world.inGroup, world.groupSize = true, 2
FW.chardb.rules.act[pid].lastPing = nil
R.Step()
eq(sent[#sent], "A|" .. hash, "Ping mit Kennung")
-- eigene Nachricht und fremde Kennung zaehlen nicht
R.OnPartnerMessage("FWChal1", "A|" .. hash, "Ich")
eq(FW.chardb.rules.act[pid].partnerSeen, nil, "eigene Nachricht ignoriert")
R.OnPartnerMessage("FWChal1", "A|deadbeef", "Anna")
eq(FW.chardb.rules.act[pid].partnerSeen, nil, "andere Herausforderung ignoriert")
R.OnPartnerMessage("Falsch", "A|" .. hash, "Anna")
eq(FW.chardb.rules.act[pid].partnerSeen, nil, "falsches Praefix ignoriert")
-- Partner meldet sich: Ziel zaehlt
R.OnPartnerMessage("FWChal1", "A|" .. hash, "Anna")
eq(R.Status(pid), "done", "mit Partner geschafft")

-- Dritter kommt dazu -> gescheitert
local pid2 = R.Save({ name = "Zu zweit 2", goals = { { type = "level", n = 60 } }, rules = { { type = "partner" } } })
R.Accept(pid2)
R.OnPartnerMessage("FWChal1", "A|" .. R.DefHash(R.Get(pid2)), "Anna")
world.groupSize = 3
R.Step()
eq(R.Status(pid2), "failed", "dritter Spieler bricht ab"); eq(FW.chardb.rules.hist[pid2].reason, "partner", "Grund Partner")
-- Scheitern wird dem Partner gemeldet
local pid3 = R.Save({ name = "Zu zweit 3", goals = { { type = "level", n = 60 } }, rules = { { type = "partner" }, { type = "deathsmax", n = 0 } } })
world.groupSize = 2
R.Accept(pid3)
R.OnDeath()
eq(sent[#sent], "F|" .. R.DefHash(R.Get(pid3)), "Scheitern gemeldet")
-- Partner scheitert -> ich auch
local pid4 = R.Save({ name = "Zu zweit 4", goals = { { type = "level", n = 60 } }, rules = { { type = "partner" } } })
R.Accept(pid4)
R.OnPartnerMessage("FWChal1", "A|" .. R.DefHash(R.Get(pid4)), "Berta")
eq(R.Status(pid4), "active", "Partner da")
R.OnPartnerMessage("FWChal1", "F|" .. R.DefHash(R.Get(pid4)), "Berta")
eq(R.Status(pid4), "failed", "Partner gescheitert -> ich auch")
-- Ein Fremder (nicht der Partner) kann nicht abbrechen
local pid5 = R.Save({ name = "Zu zweit 5", goals = { { type = "level", n = 60 } }, rules = { { type = "partner" } } })
R.Accept(pid5)
R.OnPartnerMessage("FWChal1", "A|" .. R.DefHash(R.Get(pid5)), "Berta")
R.OnPartnerMessage("FWChal1", "F|" .. R.DefHash(R.Get(pid5)), "Carla")
eq(R.Status(pid5), "active", "Fremder Abbruch wirkt nicht")
-- Partner schweigt lange / Gruppe weg
now = now + 100
world.inGroup, world.groupSize = true, 2
R.Step()
eq(R.Status(pid5), "failed", "Partner schweigt")
R.sendFn = nil

print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
