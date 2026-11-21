-- Test 0.59.0: Auto-Antwort (Filter UND/ODER, Bedingungen, Pausen, Schutz, Ignorieren, Melden, Buff, Reiter)
-- texlua tests/autoreply_test.lua
local sent, timers, printed = {}, {}, {}
local now, clock = 1000, 1700000000
local events, onHandlers = {}, {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), db = {} }
function FW:Print(t) printed[#printed + 1] = t end
function FW:Fire(ev, ...) for _, h in ipairs(onHandlers[ev] or {}) do h(...) end end
function FW:On(ev, fn) onHandlers[ev] = onHandlers[ev] or {} table.insert(onHandlers[ev], fn) end
function FW:RegisterEvent(ev, fn) events[ev] = fn return true end
function FW:AddLocale(_, t) for k, v in pairs(t) do rawset(FW.L, k, v) end end
FW.Util = { IsSecret = function() return false end, GetPlayerKey = function() return "Dr-Forever" end }
_G.Freewood = FW
_G.GetTime = function() return now end
_G.time = function() return clock end
_G.date = function(f, t) return "12:00:00" end
_G.UnitName = function(u) if u == "player" then return "Dr" end return "X" end
_G.UnitGUID = function(u) if u == "player" then return "Player-1" end return "Player-" .. u end
_G.UnitClass = function() return "Hexenmeister", "WARLOCK" end
local afk, inGroup, inRaid = false, false, false
_G.UnitIsAFK = function() return afk end
_G.UnitIsDND = function() return false end
_G.IsInGroup = function() return inGroup end
_G.IsInRaid = function() return inRaid end
_G.SendChatMessage = function(text, ch, _, target) sent[#sent + 1] = { text = text, ch = ch, to = target } end
_G.BNSendWhisper = function(id, text) sent[#sent + 1] = { text = text, ch = "BN", to = id } end
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
local ignored = {}
_G.C_FriendList = { AddIgnore = function(n) ignored[#ignored + 1] = n return true end }

assert(loadfile("Core/AutoReply.lua"))("Freewood-Core", FW)
local AR = FW.AutoReply
assert(events.CHAT_MSG_WHISPER and events.CHAT_MSG_GUILD and events.UNIT_AURA, "Ereignisse angemeldet")

-- Filter: Beispiel von Lacustat
local r = { match = "Portest UND bezahle", never = "", whole = false }
assert(AR.Matches(r, "Hey ich bezahle dir 2g wenn du mich zu dir Portest"), "UND")
assert(not AR.Matches(r, "Kannst du mich porten?"), "nur ein Wort")
r.match = "portest und bezahle\nport + gold"
assert(AR.Matches(r, "port mich bitte, gebe gold"), "zweite Zeile = ODER")
r.match = "port oder summon"
assert(AR.Matches(r, "summon pls"), "oder")
r.match = "port" r.whole = true
assert(not AR.Matches(r, "Portest du mich?"), "ganzes Wort")
assert(AR.Matches(r, "kannst du mir einen Port machen"), "ganzes Wort gefunden")
r.whole = false r.never = "scherz, spaß"
assert(not AR.Matches(r, "port, nur Spaß"), "Nie wenn (mit Umlaut, groß/klein)")
assert(AR.Matches({ match = "", never = "" }, "egal"), "leer = alles")
assert(AR.Lower("ÄÖÜ") == "äöü")

-- Regel anlegen
local rule = AR.NewRule("chat")
rule.match = "port und bezahle"
rule.replies = "Sorry {name}, ich porte nicht.\nNein danke."
rule.cdPlayer = 60
rule.ignoreAfter = 3
local asked
AR.AskIgnore = function(who) asked = who end
AR.DELAY = 1

-- Flüstern -> Antwort per Flüstern an den vollen Namen
events.CHAT_MSG_WHISPER("ich bezahle dir 2g fürs port", "Max Mustermann", nil, nil, nil, "", nil, nil, nil, nil, 7, "Player-9")
assert(#sent == 0, "erst nach der Pause")
Flush()
assert(#sent == 1 and sent[1].ch == "WHISPER" and sent[1].to == "Max Mustermann", "geflüstert")
assert(sent[1].text == "Sorry Max, ich porte nicht." or sent[1].text == "Nein danke.", sent[1].text)
assert(AR.DB().log[1].who == "Max Mustermann" and AR.DB().log[1].ok, "Verlauf")

-- Pause je Spieler
events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann", nil, nil, nil, "", nil, nil, nil, nil, 8, "Player-9") Flush()
assert(#sent == 1, "Pause je Spieler")
now = now + 61
events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann", nil, nil, nil, "", nil, nil, nil, nil, 9, "Player-9") Flush()
assert(#sent == 2, "nach der Pause wieder")
-- Ignorieren nach 3 Antworten
now = now + 61
events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann", nil, nil, nil, "", nil, nil, nil, nil, 10, "Player-9") Flush()
assert(#sent == 3 and asked == "Max Mustermann", "Ignore-Fenster nach 3")
assert(AR.DoIgnore("Max Mustermann") and ignored[1] == "Max Mustermann", "AddIgnore")

-- nie sich selbst, nie GMs, nicht aus der Gilde (Quelle aus)
now = now + 61
events.CHAT_MSG_WHISPER("bezahle port", "Dr", nil, nil, nil, "", nil, nil, nil, nil, 11, "Player-1") Flush()
events.CHAT_MSG_WHISPER("bezahle port", "Gm Hans", nil, nil, nil, "GM", nil, nil, nil, nil, 12, "Player-5") Flush()
events.CHAT_MSG_GUILD("bezahle port", "Anna Berg") Flush()
assert(#sent == 3, "selbst, GM, Gilde aus")

-- Bedingungen: nur wenn AFK
rule.cond.afk = "yes"
events.CHAT_MSG_WHISPER("bezahle port", "Neu Er", nil, nil, nil, "", nil, nil, nil, nil, 13, "Player-6") Flush()
assert(#sent == 3, "nicht AFK")
afk = true
events.CHAT_MSG_WHISPER("bezahle port", "Neu Er", nil, nil, nil, "", nil, nil, nil, nil, 14, "Player-6") Flush()
assert(#sent == 4, "AFK")
rule.cond.afk = "any"
-- Klassen
rule.classMode = "not" rule.classes = { WARLOCK = true }
assert(not AR.CondOK(rule), "nicht Hexenmeister")
rule.classMode = "only"
assert(AR.CondOK(rule), "nur Hexenmeister")
rule.classMode = "all"
-- Charakter
rule.char = "Anderer-Forever"
assert(not AR.CondOK(rule), "anderer Charakter")
rule.char = nil

-- Gilde: Pause der Regel ("Gute Nacht")
local gn = AR.NewRule("chat")
gn.src = { GUILD = true } gn.match = "gute nacht\ngn8" gn.replies = "Gute Nacht!" gn.cdRule = 300 gn.cdPlayer = 0
events.CHAT_MSG_GUILD("Gute Nacht zusammen", "Anna Berg") Flush()
events.CHAT_MSG_GUILD("gn8", "Bob Bau") Flush()
assert(#sent == 5 and sent[5].ch == "GUILD" and sent[5].to == nil, "einmal in der Gilde")
now = now + 301
events.CHAT_MSG_GUILD("gn8", "Bob Bau") Flush()
assert(#sent == 6, "nach Ablauf wieder")

-- Schutz: höchstens 6 pro Minute
local spam = AR.NewRule("chat")
spam.src = { PARTY = true } spam.match = "" spam.replies = "hi" spam.cdPlayer = 0
for i = 1, 10 do events.CHAT_MSG_PARTY("x", "P" .. i .. " Q") end
Flush()
local party = 0
for _, s in ipairs(sent) do if s.ch == "PARTY" then party = party + 1 end end
assert(party <= AR.MAX_PER_MIN, "Flutschutz " .. party)
AR.Delete(spam.id)

-- Battle.net
now = now + 120
local bn = AR.NewRule("chat")
bn.src = { BN = true } bn.match = "" bn.replies = "Bin gleich da"
events.CHAT_MSG_BN_WHISPER("hallo", "|Kq1|k", nil, nil, nil, "", nil, nil, nil, nil, 20, nil, 42) Flush()
assert(sent[#sent].ch == "BN" and sent[#sent].to == 42, "Battle.net-Antwort")
AR.Delete(bn.id)

-- Buff von einem Spieler -> Dank
now = now + 120
local buff = AR.NewRule("buff")
buff.match = "" buff.replies = "Danke für den Buff, {name}!" buff.cdPlayer = 300
_G.UnitIsPlayer = function() return true end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitFullName = function(u) return "Lena", "Licht" end
events.UNIT_AURA("player", { addedAuras = { { isHelpful = true, sourceUnit = "party1", name = "Machtwort: Seelenstärke" } } })
Flush()
assert(sent[#sent].ch == "WHISPER" and sent[#sent].to == "Lena Licht" and sent[#sent].text == "Danke für den Buff, Lena!", "Buff-Dank")
local n = #sent
events.UNIT_AURA("player", { addedAuras = { { isHelpful = true, sourceUnit = "party1", name = "Arkane Intelligenz" } } })
Flush()
assert(#sent == n, "Pause je Spieler beim Buff")
buff.buffReply = "GROUP" inGroup = true
now = now + 400
events.UNIT_AURA("player", { addedAuras = { { isHelpful = true, sourceUnit = "party1", name = "Segen" } } })
Flush()
assert(sent[#sent].ch == "PARTY", "Dank in der Gruppe")

-- Melden: Verlauf der letzten 5 Minuten
local rep = AR.NewRule("chat")
rep.src = { WHISPER = true } rep.match = "noob" rep.replies = "..." rep.report = true
local opened
AR.OpenReport = function(who) opened = who end
events.CHAT_MSG_WHISPER_INFORM("lass mich", "Troll Kopf")
events.CHAT_MSG_WHISPER("du noob", "Troll Kopf", nil, nil, nil, "", nil, nil, nil, nil, 30, "Player-7") Flush()
assert(opened == "Troll Kopf", "Melde-Fenster")
local text, lines = AR.ReportText("Troll Kopf")
assert(lines == 2 and text:find("du noob", 1, true) and text:find("-> Troll Kopf", 1, true), text)
now = now + 301
local _, l2 = AR.ReportText("Troll Kopf")
assert(l2 == 0, "nach 5 Minuten weg")

-- Hauptschalter
AR.DB().on = false
local before = #sent
events.CHAT_MSG_GUILD("gute nacht", "Zed Zett") Flush()
assert(#sent == before, "aus")
AR.DB().on = true

print("autoreply logic: ok")

-- Reiter bauen (Attrappen)
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.GetScript(f, k) return f.scripts and f.scripts[k] end
function M.Show(f) f.shown = true end
function M.Hide(f) f.shown = false end
function M.IsShown(f) return f.shown ~= false end
function M.IsVisible(f) return f.shown ~= false end
local function W()
    local o = setmetatable({}, M)
    o.edit = setmetatable({ text = "" }, M)
    o.edit.GetText = function(e) return e.text end
    o.edit.SetText = function(e, x) e.text = x end
    o.child = setmetatable({}, M)
    o.label = setmetatable({}, M)
    o.CreateTexture = function() return setmetatable({}, M) end
    o.GetText = function(s) return s.edit.text end
    o.SetText = function(s, x) s.edit.text = x or "" end
    return o
end
_G.CreateFrame = function() return W() end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
local tabDef
FW.UI = {
    CreatePanel = function() return W() end,
    CreateLabel = function() return W() end,
    CreateButton = function(_, _, _, _, fn) local b = W() if fn then b.scripts = { OnClick = fn } end return b end,
    CreateCheckbox = function(_, _, g, s) local c = W() c.get, c.set = g, s return c end,
    CreateScrollFrame = function() return W() end,
    CreateTextArea = function() return W() end,
    CreateDropdown = function(_, _, _, o) local d = W() d.opts = o d.SetValue = function(s, v) s.value = v end return d end,
    CreateInfoIcon = function() return W() end,
    CreateStack = function() return { Add = function(_, w) return w end, Layout = function() end } end,
    SetFont = function() end, Color = function() return 1, 1, 1 end,
}
function FW.UI:RegisterTab(id, def) tabDef = def end
assert(loadfile("UI/AutoReply.lua"))("Freewood-Core", FW)
assert(tabDef and tabDef.order == 870, "Reiter angemeldet")
local page = tabDef.build(W())
tabDef.onShow()
assert(page.Load and page.Save, "Formular")
page.Load(AR.DB().rules[1])
page.Save()
assert(AR.DB().rules[1].match == "port und bezahle" and AR.DB().rules[1].cdPlayer == 60, "Formular laedt und speichert ohne Verlust")
assert(FW.L.TAB_AUTOREPLY == "Auto-Antwort", "deutsche Texte")
print("autoreply tab: ok")
