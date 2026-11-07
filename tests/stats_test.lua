-- Test der Statistik: Hilfsfunktionen, Zuordnung, Model, Summe, Sammler und Reiter (texlua tests/stats_test.lua)
local function Proxy()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        if k == "height" then return 0 end
        if k == "label" or k == "child" then return Proxy() end
        return function(self, ...)
            if k == "GetWidth" or k == "GetHeight" then return 100 end
            if k == "GetStringHeight" then return 30 end
            if k == "IsVisible" or k == "IsShown" then return true end
            if k == "GetValue" then return 0 end
            return Proxy()
        end
    end })
end
local fails, n = 0, 0
local function eq(a, b, msg) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. msg .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.time = function() return 1000 end
_G.date = os.date
_G.GetTime = function() return 50 end
_G.InCombatLockdown = function() return false end
local registered, tabs, clicks = {}, {}, {}
local UI = setmetatable({
    RegisterTab = function(_, id, def) tabs[id] = def end,
    CreateButton = function(parent, text, w, h, cb) local b = Proxy(); clicks[text] = cb; return b end,
    Color = function() return 1, 1, 1 end,
}, { __index = function() return function() return Proxy() end end })
local FW = { L = setmetatable({ STATS_DUR_D = "%dd %dh %dm", STATS_DUR_H = "%dh %dm", STATS_DUR_M = "%dm %ds", STATS_DUR_S = "%ds" }, { __index = function(_, k) return k end }), UI = UI, activeLocale = "enUS", modules = {},
    Util = { IsSecret = function() return false end }, Print = function() end,
    RegisterEvent = function(_, ev, fn, owner) registered[ev] = { fn, owner } end, UnregisterEvent = function() end }
function FW:NewModule(name, opts) opts.db = { chars = {}, open = { overview = true } }; opts.db.chars = {}; self.modules[name] = opts; return opts end
local function Load(f) assert(loadfile(f))("Freewood-Core", FW) end
Load("Stats/StatsData.lua")
local S = FW.Stats

-- Muster aus Spielkonstanten
local p = S.PatternFor("You receive loot: %s.")
eq(("You receive loot: |cff0070dd|Hitem:1:0|h[Schwert]|h|r."):match(p) ~= nil, true, "Muster einfach")
local pm = S.PatternFor("You receive loot: %sx%d.")
local link, cnt = ("You receive loot: |cffffffff|Hitem:2|h[Stoff]|h|rx5."):match(pm)
eq(cnt, "5", "Muster mehrfach: Anzahl")
eq(("Wolf dies, you gain 5 experience."):match(S.PatternFor("%1$s dies, you gain %2$d experience.")), "Wolf", "Muster positional")
local pats = { { p = pm, kind = "loot", multi = true }, { p = p, kind = "loot" } }
local l, c2, kind = S.ParseLoot("You receive loot: |cffa335ee|Hitem:9|h[Beute]|h|rx3.", pats)
eq(c2, 3, "ParseLoot Anzahl"); eq(kind, "loot", "ParseLoot Art")
l, c2 = S.ParseLoot("You receive loot: |cff1eff00|Hitem:9|h[Beute]|h|r.", pats)
eq(c2, 1, "ParseLoot einzeln")
eq(S.ParseLoot("Anna receives loot: |cffffffff|Hitem:9|h[X]|h|r.", pats), nil, "fremde Beute ignoriert")
eq(S.QualityOfLink("|cffa335ee|Hitem:1|h[x]|h|r"), 4, "Qualitaet episch")
eq(S.QualityOfLink("|cff9d9d9d|Hitem:1|h[x]|h|r"), 0, "Qualitaet grau")

-- XP
local kp = S.PatternFor("%s dies, you gain %d experience.")
local op = S.PatternFor("You gain %d experience.")
local xp, kill = S.ParseXP("Wolf dies, you gain 54 experience.", kp, op)
eq(xp, 54, "XP Kill"); eq(kill, true, "XP Kill-Flag")
xp, kill = S.ParseXP("You gain 120 experience.", kp, op)
eq(xp, 120, "XP sonstiges"); eq(kill, false, "XP kein Kill")

-- Formate
FW.activeLocale = "enUS"
eq(S.Num(1234567), "1,234,567", "Zahl en")
eq(S.Num(12), "12", "Zahl klein")
FW.activeLocale = "deDE"
eq(S.Num(1234567), "1.234.567", "Zahl de")
eq(S.Km(1093.6), "1,0 km", "Kilometer de")
FW.activeLocale = "enUS"
eq(S.Money(123456), "12g 34s 56c", "Geld")
eq(S.Money(-250), "-2s 50c", "Geld negativ")
eq(S.Money(5), "5c", "Geld klein")
eq(S.Duration(3725), "1h 2m", "Dauer")
eq(S.Duration(90061), "1d 1h 1m", "Dauer Tage")

-- Geldquelle
eq(S.MoneySource(100, { merchant = true }), "vendorIn", "Quelle Verkauf")
eq(S.MoneySource(-100, { merchant = true }), "vendorOut", "Quelle Kauf")
eq(S.MoneySource(100, { questAge = 1 }), "quest", "Quelle Quest")
eq(S.MoneySource(100, { lootAge = 1 }), "loot", "Quelle Beute")
eq(S.MoneySource(100, { mail = true }), "mail", "Quelle Post")
eq(S.MoneySource(100, { lootAge = 9, questAge = 9 }), "other", "Quelle sonst")

-- Model und Summe
local rec = S.NewRecord()
rec.info = { name = "Anna", class = "HUNTER", level = 20, race = "Orc", faction = "Horde" }
rec.c = { combats = 4, combatSecs = 80, kills = 10, lootItems = 5, lootQ2 = 3, distFoot = 1000, distMount = 3000, m_loot = 500, moneyEarned = 600, moneySpent = 100, maxMoney = 700 }
rec.sp = { [75] = 40, [1978] = 5 }
rec.z = { ["Durotar"] = 1 }
rec.snap = { money = 700, health = 300, crit = 5.26 }
local cats = S.Model(rec, { codex = { cells = 12, edges = 30, flights = 4 } })
local ids = {}
for _, c in ipairs(cats) do ids[c.id] = c end
for _, id in ipairs({ "overview", "values", "combat", "xp", "gold", "loot", "travel", "social", "deaths" }) do eq(ids[id] ~= nil, true, "Kategorie " .. id) end
local function Find(cat, label) for _, r in ipairs(ids[cat].rows) do if r[1] == label then return r[2] end end end
eq(Find("combat", "STATS_COMBAVG"), "20s", "Kampfdauer Durchschnitt")
eq(Find("travel", "STATS_DIST_ALL"), "3.7 km", "Strecke gesamt")
eq(Find("gold", "STATS_NET"), "5s 0c", "Saldo")
eq(Find("values", "STATS_CRIT"), "5.3 %", "Prozent")
eq(Find("travel", "STATS_PATH_CELLS"), "12", "Wegenetz-Zellen")

local rec2 = S.NewRecord()
rec2.info = { name = "Bob", level = 30 }
rec2.c = { kills = 5, maxMoney = 900, combats = 1 }
rec2.snap = { money = 100 }
rec2.z = { ["Durotar"] = 1, ["Mulgore"] = 1 }
local sum = S.Sum({ a = rec, b = rec2 })
eq(sum.c.kills, 15, "Summe Kills"); eq(sum.c.maxMoney, 900, "Summe Maximum"); eq(sum.count, 2, "Summe Anzahl")
eq(sum.snap.money, 800, "Summe Gold"); eq(sum.levelSum, 50, "Summe Stufen")
local zc = 0 for _ in pairs(sum.z) do zc = zc + 1 end
eq(zc, 2, "Zonen vereint")
local list = S.CharList({ a = rec, b = rec2 })
eq(list[1].name, "Bob", "Liste nach Stufe")

-- Sammler (Spielwelt gespielt)
local money = 1000
_G.UnitName = function() return "Anna" end
_G.GetRealmName = function() return "Realm" end
_G.GetMoney = function() return money end
_G.UnitClass = function() return "Jaeger", "HUNTER" end
_G.UnitRace = function() return "Orc" end
_G.UnitFactionGroup = function() return "Horde" end
_G.UnitLevel = function() return 21 end
_G.GetRealZoneText = function() return "Durotar" end
_G.GetSubZoneText = function() return "Razor Hill" end
_G.IsInInstance = function() return false end
_G.hooksecurefunc = function() end
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
_G.COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience."
Load("Stats/StatsCollect.lua")
local mod = FW.modules.Stats
assert(mod and mod.OnEnable)
mod:OnEnable()
local r = S.Rec(false)
assert(r, "Datensatz angelegt")
eq(r.info.level, 21, "Info Stufe")
local function Fire(ev, ...) local h = registered[ev]; assert(h, "Ereignis " .. ev); h[1](h[2], ...) end
Fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:77|h[Epic]|h|r.")
Fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:78|h[Stoff]|h|rx4.")
eq(r.c.lootItems, 5, "Beute gezaehlt"); eq(r.c.lootQ4, 1, "episch"); eq(r.c.lootQ1, 4, "weiss")
eq(r.best and r.best.q, 4, "bester Fund")
Fire("CHAT_MSG_COMBAT_XP_GAIN", "Wolf dies, you gain 54 experience.")
eq(r.c.xp, 54, "XP"); eq(r.c.kills, 1, "Kill")
Fire("QUEST_ACCEPTED", 1); Fire("QUEST_TURNED_IN", 1, 200, 300)
eq(r.c.questsDone, 1, "Quest fertig"); eq(r.c.questXP, 200, "Quest-XP"); eq(r.c.questMoney, 300, "Quest-Gold")
money = 1300
Fire("PLAYER_MONEY")
eq(r.c.moneyEarned, 300, "Gold verdient"); eq(r.c.m_quest, 300, "Gold aus Quest")
money = 1100
Fire("PLAYER_MONEY")
eq(r.c.moneySpent, 200, "Gold ausgegeben")
Fire("PLAYER_REGEN_DISABLED"); Fire("PLAYER_REGEN_ENABLED")
eq(r.c.combats, 1, "Kampf gezaehlt")
Fire("PLAYER_DEAD"); eq(r.c.deaths, 1, "Tod"); eq(r.dz["Durotar"], 1, "Todeszone")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 75)
Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 99)
eq(r.c.casts, 1, "Zauber nur eigene"); eq(r.sp[75], 1, "Zauber 75")
Fire("PLAYER_ENTERING_WORLD"); eq(r.c.loads, 1, "Ladebildschirm"); eq(r.z["Durotar"] ~= nil, true, "Zone erfasst")

-- Reiter
Load("Stats/StatsUI.lua")
local def = tabs.stats
assert(def and def.build, "Reiter registriert")
local frame = def.build(Proxy())
def.onShow(frame)
clicks["STATS_SUB_ACCOUNT"]()
clicks["STATS_SUB_CHAR"]()
clicks["STATS_TOGGLE_ALL"]()
clicks["STATS_PATH_SHOW"] = clicks["STATS_PATH_SHOW"]
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
