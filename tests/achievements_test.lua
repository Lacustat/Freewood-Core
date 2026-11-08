-- Test der Erfolge: Stufen, Fortschritt, Pruefung, Account, Titel, Hinweise, Reiter (texlua tests/achievements_test.lua)
local function Proxy()
    return setmetatable({}, { __index = function(_, k)
        if k == "child" or k == "label" or k == "scroll" then return Proxy() end
        return function(_, ...)
            if k == "GetWidth" or k == "GetHeight" then return 600 end
            if k == "IsVisible" or k == "IsShown" then return true end
            return Proxy()
        end
    end })
end
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.time = function() return 5000 end
_G.GetLocale = function() return "enUS" end
_G.InCombatLockdown = function() return false end
local tabs = {}
local UI = setmetatable({ RegisterTab = function(_, id, def) tabs[id] = def end, Color = function() return 1, 1, 1 end },
    { __index = function() return function() return Proxy() end end })
local fired = {}
local FW = { UI = UI, activeLocale = "enUS", modules = {}, Util = { IsSecret = function() return false end }, Print = function() end,
    L = setmetatable({}, { __index = function(_, k) return k end }),
    Fire = function(_, e, ...) fired[#fired + 1] = e end,
    RegisterEvent = function() end }
function FW:NewModule(name, opts)
    opts.db = { acct = {}, notify = true, titleChat = true }
    self.modules[name] = opts
    return opts
end
local function Load(f) assert(loadfile(f))("Freewood-Core", FW) end
Load("Stats/StatsData.lua")
Load("Stats/AchData.lua")
local A, S = FW.Ach, FW.Stats

-- Katalog
eq(#A.CATALOG >= 38, true, "mindestens 38 Erfolge")
local ids = {}
for _, e in ipairs(A.CATALOG) do
    eq(ids[e.id], nil, "Kennung einmalig " .. e.id); ids[e.id] = true
    eq(#e.t >= 1 and #e.t <= 4, true, "Schwellen 1 bis 4 " .. e.id)
    eq(A.MaxLevel(e) <= 4, true, "hoechste Stufe <= Platin " .. e.id)
    for i = 2, #e.t do eq(e.t[i] > e.t[i - 1], true, "Schwellen steigen " .. e.id) end
    eq(type(e.de[1]) == "string" and type(e.en[2]) == "string", true, "Texte " .. e.id)
    eq(e.de[2]:find("{n}", 1, true) ~= nil and e.en[2]:find("{n}", 1, true) ~= nil, true, "Platzhalter {n} " .. e.id)
end

-- Stufen und Fortschritt
local jumps = A.BY_ID.jumps
eq(A.LevelFor(jumps, 0), 0, "keine Stufe")
eq(A.LevelFor(jumps, 100), 1, "Bronze bei 100"); eq(A.LevelFor(jumps, 999), 1, "Bronze bis 999")
eq(A.LevelFor(jumps, 1000), 2, "Silber"); eq(A.LevelFor(jumps, 10000), 3, "Gold"); eq(A.LevelFor(jumps, 999999), 4, "Platin")
local p = A.Progress(jumps, 550)
eq(p.level, 1, "Fortschritt Stufe"); eq(p.next, 1000, "naechste Schwelle"); eq(p.prev, 100, "letzte Schwelle")
eq(math.floor(p.frac * 100), 50, "halbe Strecke (550 zwischen 100 und 1000)")
eq(A.Progress(jumps, 70000).next, nil, "am Ende keine naechste Schwelle")
eq(A.Progress(jumps, 70000).frac, 1, "am Ende voll")
-- Erfolg mit nur einer Stufe ab Platin
local legend = A.BY_ID.legend
eq(A.LevelFor(legend, 1), 4, "legendaer = Platin"); eq(A.MaxLevel(legend), 4, "legendaer hoechste Stufe")
eq(A.PointsFor(legend, 4), 40, "nur die Platin-Punkte"); eq(A.PointsFor(jumps, 4), 75, "alle vier Stufen 5+10+20+40")
eq(A.PointsFor(jumps, 2), 15, "Bronze plus Silber")
eq(A.Desc(jumps, 1000), "Jump 1,000 times.", "Beschreibung mit Schwelle")
FW.activeLocale = "deDE"
eq(A.Name(jumps), "Hüpfer", "deutscher Name"); eq(A.TitleOf(jumps), "der Hüpfer", "deutscher Titel")
FW.activeLocale = "enUS"

-- Pruefung mit Statistik-Datensatz
local sdb = { chars = {} }
S.Db = function() return sdb end
local me = "Pinky-Realm"
S.Key = function() return me end
S.Rec = function(create)
    local r = sdb.chars[me]
    if not r and create ~= false then r = S.NewRecord(); sdb.chars[me] = r end
    return r, me
end
local rec = S.Rec()
rec.info = { level = 12, class = "MAGE", name = "Pinky" }
rec.c.jumps = 150; rec.c.kills = 5; rec.c.afkSecs = 3700; rec.c.maxMoney = 25000
local toasts = {}
A.OnToast = function(ev) toasts[#toasts + 1] = ev end
local ev = A.Check()
eq(#ev, 0, "erste Pruefung stumm (nichts gemeldet)"); eq(#toasts, 0, "kein Hinweis beim Start")
eq(rec.ach.jumps.l, 1, "Bronze fuer Springen gemerkt"); eq(rec.ach.lvl.l, 1, "Stufe 10 = Bronze")
eq(rec.ach.afk.l, 1, "AFK 1 Std. = Bronze"); eq(rec.ach.gold.l, 1, "2 Gold = Bronze (Gold-Wert 2)")
eq(A.Db().acct.jumps.l, 1, "Account Bronze"); eq(A.Db().acct.jumps.by, me, "Account: von wem")
rec.c.jumps = 1200
ev = A.Check()
eq(#ev, 2, "Springen char und acct neu"); eq(ev[1].level, 2, "Silber"); eq(#toasts, 1, "Hinweis ausgeloest"); eq(fired[#fired], "FW_ACH_UNLOCKED", "Ereignis")
eq(rec.ach.jumps.l, 2, "Silber gemerkt")
rec.c.jumps = 50
ev = A.Check(); eq(#ev, 0, "Stufen fallen nie zurueck"); eq(rec.ach.jumps.l, 2, "Stufe bleibt")
A.Db().notify = false
rec.c.jumps = 20000; A.Check(); eq(#toasts, 1, "ohne Hinweis kein Fenster")
A.Db().notify = true
-- stumm
rec.c.jumps = 70000; local before = #toasts; A.Check(true); eq(#toasts, before, "stumm meldet nichts")

-- Account: zweiter Charakter, Summe, Klassen
sdb.chars["Zed-Realm"] = S.NewRecord()
sdb.chars["Zed-Realm"].info = { level = 60, class = "WARRIOR", name = "Zed" }
sdb.chars["Zed-Realm"].c.kills = 2000
local ctx = A.Context(sdb.chars)
eq(ctx.chars, 2, "zwei Charaktere"); eq(ctx.classes, 2, "zwei Klassen"); eq(ctx.maxed, 1, "ein 60er")
A.Check()
eq(A.Db().acct.a_chars.l, 1, "Altoholic Bronze (2 Charaktere)")
eq(A.Db().acct.kills.l, 2, "Account-Kills 2005 = Silber")
eq(rec.ach.kills, nil, "char kills (5) nicht von Zed beeinflusst")
eq(rec.ach.a_chars, nil, "Account-Erfolg nicht beim Charakter")
eq(A.Db().acct.lvl.l, 4, "Account-Stufe = hoechster Charakter (60 = Platin)")

-- View
local sum = S.Sum(sdb.chars)
local cv = A.View("char", rec, sum, ctx, A.Db().acct)
local av = A.View("acct", rec, sum, ctx, A.Db().acct)
eq(#av - #cv, 3, "Account zeigt 3 Zusatzerfolge")
local pts, max, done, total = A.Totals(cv)
eq(total, #cv, "Gesamtzahl"); eq(pts > 0 and pts < max, true, "Punkte sinnvoll"); eq(done >= 1, true, "Springen komplett (70000 = Platin)")

-- Titel
local db = A.Db()
eq(A.ActiveTitle(), nil, "kein Titel gewaehlt"); eq(A.TitleTag(), "", "leerer Anhang")
db.title = "jumps"
eq(A.ActiveTitle(), "the Hopper", "Titel wird gefunden (Account Platin)")
eq(A.TitleTag():find("the Hopper", 1, true) ~= nil, true, "Anhang mit Titel")
db.titleChat = false; eq(A.TitleTag(), "", "Titel im Chat aus")
db.titleChat = true
db.title = "kills"; db.acct.kills.l = 2
eq(A.ActiveTitle(), nil, "Titel erst ab Gold")
local unlocked = A.UnlockedTitles(); local hasJumps = false
for _, e in ipairs(unlocked) do if e.id == "jumps" then hasJumps = true end end
eq(hasJumps, true, "Springen-Titel freigeschaltet")

-- Reiter
Load("Stats/AchUI.lua")
eq(type(tabs.ach), "table", "Reiter ach registriert"); eq(tabs.ach.order > 95, true, "nach der Statistik")
local f = tabs.ach.build(Proxy())
f.Refresh(); f.Render()
eq(f ~= nil, true, "Reiter baut ohne Fehler")
A.OnToast({ { def = A.BY_ID.jumps, level = 2, scope = "char" } })
A.OnToast({ { def = A.BY_ID.jumps, level = 1, scope = "char" }, { def = A.BY_ID.kills, level = 1, scope = "char" }, { def = A.BY_ID.loot, level = 1, scope = "char" }, { def = A.BY_ID.epic, level = 1, scope = "char" } })
eq(type(SlashCmdList["FWERFOLGE"]), "function", "Befehl /fwerfolge")
SlashCmdList["FWERFOLGE"]("test"); SlashCmdList["FWERFOLGE"]("check")

print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
