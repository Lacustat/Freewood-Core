-- Test 0.59.0/0.60.0: Auto-Antwort (Filter, Bedingungen, Pausen, Schutz, Ignorieren, Melden, Auslöser, Emotes,
-- Vorlagen, Export, Reiter)   texlua tests/autoreply_test.lua
local sent, timers, printed, emotes = {}, {}, {}, {}
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
local hhmm = "12:00"
_G.date = function(f) if f == "%H:%M" then return hhmm end return "12:00:00" end
_G.UnitName = function(u) if u == "player" then return "Dr" end return "X" end
_G.UnitGUID = function(u) if u == "player" then return "Player-1" end return "Player-" .. u end
_G.UnitClass = function() return "Hexenmeister", "WARLOCK" end
_G.UnitLevel = function() return 20 end
local afk, inGroup, inRaid, inCombat = false, false, false, false
_G.UnitIsAFK = function() return afk end
_G.UnitIsDND = function() return false end
_G.IsInGroup = function() return inGroup end
_G.IsInRaid = function() return inRaid end
_G.InCombatLockdown = function() return inCombat end
_G.IsInInstance = function() return false end
_G.IsInGuild = function() return true end
_G.GetZoneText = function() return "Elwynn" end
_G.SendChatMessage = function(text, ch, _, target) sent[#sent + 1] = { text = text, ch = ch, to = target } end
_G.BNSendWhisper = function(id, text) sent[#sent + 1] = { text = text, ch = "BN", to = id } end
_G.DoEmote = function(t, target) emotes[#emotes + 1] = { t = t, to = target } end
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
local ignored = {}
local friends = { "Lena Licht" }
_G.C_FriendList = {
    AddIgnore = function(n) ignored[#ignored + 1] = n return true end,
    GetNumFriends = function() return #friends end,
    GetFriendInfoByIndex = function(i) return { name = friends[i] } end,
}
local roster = { { "Anna Berg", 10 }, { "Bob Bau", 30 } }
_G.GetNumGuildMembers = function() return #roster end
_G.GetGuildRosterInfo = function(i) return roster[i][1], "", 0, roster[i][2] end
_G.ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h ist jetzt online."
_G.ERR_GUILD_JOIN_S = "%s ist der Gilde beigetreten."
_G.LOOT_ROLL_YOU_WON = "Ihr habt gewonnen: %1$s"

assert(loadfile("Core/AutoReply.lua"))("Freewood-Core", FW)
local AR = FW.AutoReply
AR.DELAY = 1
AR.MAX_PER_MIN = 1000   -- Flutschutz erst unten gezielt prüfen
AR.loginAt = -1000
for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "UNIT_AURA", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
    "PLAYER_LEVEL_UP", "GUILD_ROSTER_UPDATE", "UNIT_LEVEL", "GROUP_ROSTER_UPDATE", "DUEL_REQUESTED",
    "RESURRECT_REQUEST", "PARTY_INVITE_REQUEST", "ENCOUNTER_END", "TRADE_SHOW" }) do
    assert(events[ev], "Ereignis " .. ev)
end

-- 0.60.1: Kampflog nie anmelden (für Addons gesperrt, F-38)
assert(not events.COMBAT_LOG_EVENT_UNFILTERED, "kein Kampflog")

-- Filter: Beispiel von Lacustat
local r = { match = "Portest UND bezahle", never = "", whole = false }
assert(AR.Matches(r, "Hey ich bezahle dir 2g wenn du mich zu dir Portest"), "UND")
assert(not AR.Matches(r, "Kannst du mich porten?"), "nur ein Wort")
r.match = "portest und bezahle\nport + gold"
assert(AR.Matches(r, "port mich bitte, gebe gold"), "zweite Zeile = ODER")
r.match = "port oder summon"
assert(AR.Matches(r, "summon pls"), "oder")
r.match = "port" r.whole = true
assert(not AR.Matches(r, "Portest du mich?") and AR.Matches(r, "einen Port bitte"), "ganzes Wort")
r.whole = false r.never = "scherz, spaß"
assert(not AR.Matches(r, "port, nur Spaß"), "Nie wenn")
assert(AR.TemplatePattern("Ihr habt gewonnen: %1$s") == "^Ihr habt gewonnen: (.+)$", AR.TemplatePattern("Ihr habt gewonnen: %1$s"))
assert(AR.SameName("Max Mustermann", "max mustermann-Forever") and AR.SameName("Max", "Max Mustermann")
    and not AR.SameName("Max Mustermann", "Max Meier"), "Namen")

-- alte Regel aus 0.59 wird übernommen
FW.db.autoReply = { rules = { { id = 7, name = "Alt", on = true, kind = "buff", buffReply = "GROUP", src = {}, cond = { afk = "any" } } }, nextId = 8 }
local old = AR.DB().rules[1]
assert(old.dest == "group" and old.action == "text" and old.cond.friend == "any" and old.buffReply == nil, "Upgrade")
FW.db.autoReply = nil

-- Chat: Flüstern
local rule = AR.NewRule("chat", { match = "port und bezahle", replies = "Sorry {name}, ich porte nicht.", cdPlayer = 60, ignoreAfter = 3 })
local asked
AR.AskIgnore = function(who) asked = who end
events.CHAT_MSG_WHISPER("ich bezahle 2g fürs port", "Max Mustermann", nil, nil, nil, "", nil, nil, nil, nil, 7, "Player-9") Flush()
assert(#sent == 1 and sent[1].ch == "WHISPER" and sent[1].to == "Max Mustermann" and sent[1].text == "Sorry Max, ich porte nicht.", "geflüstert")
events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann") Flush()
assert(#sent == 1, "Pause je Spieler")
now = now + 61 events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann") Flush()
now = now + 61 events.CHAT_MSG_WHISPER("bezahle port", "Max Mustermann") Flush()
assert(#sent == 3 and asked == "Max Mustermann", "Ignore-Fenster nach 3")
assert(AR.DoIgnore("Max Mustermann") and ignored[1] == "Max Mustermann")
now = now + 61
events.CHAT_MSG_WHISPER("bezahle port", "Dr", nil, nil, nil, "", nil, nil, nil, nil, 11, "Player-1")
events.CHAT_MSG_WHISPER("bezahle port", "Gm Hans", nil, nil, nil, "GM") Flush()
assert(#sent == 3, "selbst, GM")

-- Bedingungen über den anderen
rule.cond.friend = "yes"
events.CHAT_MSG_WHISPER("bezahle port", "Fremd Er") Flush()
assert(#sent == 3, "kein Freund")
events.CHAT_MSG_WHISPER("bezahle port", "Lena Licht") Flush()
assert(#sent == 4, "Freund")
rule.cond.friend = "any" rule.cond.guild = "no"
AR.OnGuildRoster()
now = now + 61
events.CHAT_MSG_WHISPER("bezahle port", "Anna Berg") Flush()
assert(#sent == 4, "nie bei Gildenmitgliedern")
rule.cond.guild = "any" rule.cond.party = "yes"
inGroup = true
_G.UnitExists = function(u) return u == "party1" end
_G.UnitIsPlayer = function() return true end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitFullName = function(u) if u == "party1" then return "Gus", "Gruppe" end return "Lena", "Licht" end
events.CHAT_MSG_WHISPER("bezahle port", "Gus Gruppe") Flush()
assert(#sent == 5, "Gruppenmitglied")
rule.cond.party = "any" inGroup = false
-- Uhrzeit über Mitternacht
rule.timeFrom, rule.timeTo = "22:00", "06:00"
assert(not AR.CondOK(rule), "12 Uhr nicht")
hhmm = "23:30" assert(AR.CondOK(rule), "23:30 ja")
hhmm = "05:59" assert(AR.CondOK(rule), "05:59 ja")
hhmm = "12:00" rule.timeFrom, rule.timeTo = "", ""
-- Kampf
rule.cond.combat = "no" inCombat = true
assert(not AR.CondOK(rule)) inCombat = false rule.cond.combat = "any"
-- einmal pro Sitzung
rule.once = true rule.cdPlayer = 0
now = now + 100
events.CHAT_MSG_WHISPER("bezahle port", "Neu Er") Flush()
events.CHAT_MSG_WHISPER("bezahle port", "Neu Er") Flush()
assert(#sent == 6, "einmal")
AR.Delete(rule.id)

-- Text und Emote, Emote auf die Person
local th = AR.NewRule("chat", { src = { WHISPER = true }, match = "danke", action = "both", emote = "THANK", emoteTarget = true, replies = "Gern!" })
events.CHAT_MSG_WHISPER("danke dir", "Lena Licht") Flush()
assert(sent[#sent].text == "Gern!" and emotes[#emotes].t == "THANK" and emotes[#emotes].to == "Lena Licht", "Text + Emote")
th.action = "emote" th.emoteTarget = false now = now + 100
local n = #sent
events.CHAT_MSG_WHISPER("danke", "Lena Licht") Flush()
assert(#sent == n and emotes[#emotes].to == nil, "nur Emote ohne Ziel")
_G.C_ChatInfo = { PerformEmote = function(t, target) emotes[#emotes + 1] = { t = t, to = target, new = true } end }
now = now + 100
events.CHAT_MSG_WHISPER("danke", "Lena Licht") Flush()
assert(emotes[#emotes].new, "neue Emote-Funktion zuerst")
_G.C_ChatInfo = nil
AR.Delete(th.id)

-- Online: Freund und Gildenmitglied
local fo = AR.NewRule("friendon", { replies = "Hallo {name}!", dest = "whisper" })
local go = AR.NewRule("guildon", { replies = "Hi {name}", dest = "guild" })
events.CHAT_MSG_SYSTEM("|Hplayer:Lena Licht|h[Lena Licht]|h ist jetzt online.") Flush()
assert(sent[#sent].to == "Lena Licht" and sent[#sent].text == "Hallo Lena!", "Freund online")
events.CHAT_MSG_SYSTEM("|Hplayer:Bob Bau|h[Bob Bau]|h ist jetzt online.") Flush()
assert(sent[#sent].ch == "GUILD" and sent[#sent].text == "Hi Bob", "Gilde online")
-- Begrüßungssperre nach dem Einloggen
AR.loginAt = now n = #sent now = now + 5
events.CHAT_MSG_SYSTEM("|Hplayer:Anna Berg|h[Anna Berg]|h ist jetzt online.") Flush()
assert(#sent == n, "60 s still nach dem Einloggen")
AR.loginAt = -1000
AR.Delete(fo.id) AR.Delete(go.id)

-- Vorlagentexte (sonst aus UI/AutoReply.lua)
for k, v in pairs({ AR_T_GJOIN_R = "Willkommen, {name}!", AR_T_LVL_R = "Stufe {level}!", AR_T_GLVL_R = "Grats zu {level}, {name}!",
    AR_T_DUEL_R = "Keine Duelle", AR_T_REZ_R = "Danke, {name}!", AR_T_BOSS_R = "gg!", AR_T_PORT_R = "Sorry {name}" }) do rawset(FW.L, k, v) end
-- Neues Gildenmitglied
local gj = AR.FromTemplate("GJOIN")
events.CHAT_MSG_SYSTEM("Cleo Cloud ist der Gilde beigetreten.") Flush()
assert(sent[#sent].ch == "GUILD" and sent[#sent].text:find("Cleo", 1, true), "Willkommen")
AR.Delete(gj.id)

-- Item gewonnen
local won = AR.NewRule("rollwon", { replies = "Danke für {item}!", dest = "group", match = "" })
inGroup = true
events.CHAT_MSG_LOOT("Ihr habt gewonnen: |cff1eff00|Hitem:1|h[Grüner Hut]|h|r") Flush()
assert(sent[#sent].ch == "PARTY" and sent[#sent].text:find("Grüner Hut", 1, true), "gewonnen")
won.match = "schwert" n = #sent now = now + 100
events.CHAT_MSG_LOOT("Ihr habt gewonnen: |cff1eff00|Hitem:2|h[Roter Hut]|h|r") Flush()
assert(#sent == n, "Itemfilter")
AR.Delete(won.id) inGroup = false

-- Eigenes Level-up
local lv = AR.FromTemplate("LVL")
events.PLAYER_LEVEL_UP(21) Flush()
assert(sent[#sent].ch == "GUILD" and sent[#sent].text:find("21", 1, true) and emotes[#emotes].t == "CHEER", "Level-up")
AR.Delete(lv.id)

-- Level-up in der Gilde
local gl = AR.FromTemplate("GLVL")
AR.OnGuildRoster()
roster[2][2] = 31
events.GUILD_ROSTER_UPDATE() Flush()
assert(sent[#sent].ch == "GUILD" and sent[#sent].text:find("31", 1, true) and sent[#sent].text:find("Bob", 1, true), "Gilden-Level-up")
AR.Delete(gl.id)

-- Level-up in der Umgebung
local nl = AR.NewRule("nearlevel", { replies = "Grats {name}!", dest = "whisper" })
local lvls = { nameplate1 = 14 }
_G.UnitLevel = function(u) return lvls[u] or 20 end
_G.UnitFullName = function() return "Zara", "Zorn" end
AR.OnUnitLevel("nameplate1")
n = #sent
lvls.nameplate1 = 15
events.UNIT_LEVEL("nameplate1") Flush()
assert(#sent == n + 1 and sent[#sent].to == "Zara Zorn", "Level-up in der Umgebung")
AR.Delete(nl.id)

-- Anfragen, Wiederbelebung
local du = AR.FromTemplate("DUEL")
events.DUEL_REQUESTED("Kai Kampf") Flush()
assert(sent[#sent].to == "Kai Kampf", "Duell")
local rz = AR.FromTemplate("REZ")
events.RESURRECT_REQUEST("Pia Priester") Flush()
assert(sent[#sent].to == "Pia Priester" and emotes[#emotes].t == "THANK" and emotes[#emotes].to == "Pia Priester", "Rez")
AR.Delete(du.id) AR.Delete(rz.id)

-- Gruppe: Beitritt erst nach dem Ausgangsstand
local pj = AR.NewRule("groupjoin", { replies = "Hallo {name}!", dest = "group", cdPlayer = 0 })
inGroup = true
local members = { party1 = true }
_G.UnitExists = function(u) return members[u] end
_G.UnitFullName = function(u) if u == "party1" then return "Gus", "Gruppe" end return "Nina", "Neu" end
n = #sent
events.GROUP_ROSTER_UPDATE() Flush()
assert(#sent == n, "Ausgangsstand ohne Gruß")
members.party2 = true
events.GROUP_ROSTER_UPDATE() Flush()
assert(#sent == n + 1 and sent[#sent].text == "Hallo Nina!" and sent[#sent].ch == "PARTY", "Beitritt")
AR.Delete(pj.id)

-- Boss
local bo = AR.FromTemplate("BOSS")
events.ENCOUNTER_END(1, "Van Cleef", 1, 5, 1) Flush()
assert(sent[#sent].ch == "PARTY" and emotes[#emotes].t == "CHEER", "Boss")
n = #sent
events.ENCOUNTER_END(1, "Van Cleef", 1, 5, 0) Flush()
assert(#sent == n, "nicht bei Niederlage")
AR.Delete(bo.id) inGroup = false

-- Schutz: höchstens 6 pro Minute
now = now + 200
AR.MAX_PER_MIN = 6
local spam = AR.NewRule("chat", { src = { PARTY = true }, replies = "hi", cdPlayer = 0 })
local before = #sent
for i = 1, 10 do events.CHAT_MSG_PARTY("x", "P" .. i .. " Q") end
Flush()
assert(#sent - before <= AR.MAX_PER_MIN, "Flutschutz")
AR.Delete(spam.id)
AR.MAX_PER_MIN = 1000

-- Melden
now = now + 200
local rep = AR.NewRule("chat", { match = "noob", replies = "...", report = true })
local opened
AR.OpenReport = function(who) opened = who end
events.CHAT_MSG_WHISPER_INFORM("lass mich", "Troll Kopf")
events.CHAT_MSG_WHISPER("du noob", "Troll Kopf") Flush()
assert(opened == "Troll Kopf", "Melde-Fenster")
local text, lines = AR.ReportText("Troll Kopf")
assert(lines == 2 and text:find("-> Troll Kopf", 1, true), text)
AR.Delete(rep.id)

-- Export / Import über Core/Export.lua (Attrappe)
local store
FW.Export = { Encode = function(k, d) store = { k = k, d = d } return "FW1:" .. k end,
    Decode = function(t) if t == "FW1:autoreply" then return store end return nil, "ERR_FORMAT" end }
local tpl = AR.FromTemplate("PORT")
assert(tpl.classes.WARLOCK and tpl.replies:find("{name}", 1, true), "Vorlage")
local code = AR.ExportRules({ tpl })
assert(code == "FW1:autoreply" and store.d[1].id == nil and store.d[1].kind == "chat", "Export ohne id")
local count = #AR.DB().rules
assert(AR.ImportRules(code) == 1 and #AR.DB().rules == count + 1 and AR.DB().rules[count + 1].on == false, "Import aus")
assert(not AR.ImportRules("Quatsch"), "falscher Code")

AR.DB().on = false
before = #sent
events.CHAT_MSG_WHISPER("port und gold", "Max Mustermann") Flush()
assert(#sent == before, "Hauptschalter aus")
AR.DB().on = true
print("autoreply logic: ok")

-- Reiter bauen (Attrappen; Kästchen fragen ihren Wert sofort ab wie im Spiel)
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
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
local tabDef
local dds = {}
FW.UI = {
    CreatePanel = function() return W() end,
    CreateLabel = function() return W() end,
    CreateButton = function(_, _, _, _, fn) local b = W() if fn then b.scripts = { OnClick = fn } end return b end,
    CreateCheckbox = function(_, _, g, s) local c = W() c.get, c.set = g, s g() c.Refresh = function() g() end return c end,
    CreateScrollFrame = function() return W() end,
    CreateTextArea = function() return W() end,
    CreateDropdown = function(_, _, _, o) local d = W() d.opts = o d.SetValue = function(s, v) s.value = v end o.getOptions() dds[#dds + 1] = d return d end,
    CreateInfoIcon = function() return W() end,
    CreateStack = function() return { Add = function(_, w) return w end, Layout = function() end } end,
    SetFont = function() end, Color = function() return 1, 1, 1 end,
}
function FW.UI:RegisterTab(id, def) tabDef = def end
assert(loadfile("UI/AutoReply.lua"))("Freewood-Core", FW)
assert(tabDef and tabDef.order == 870, "Reiter angemeldet")
local page = tabDef.build(W())
tabDef.onShow()
local boss = AR.FromTemplate("BOSS")
page.Load(boss)
assert(page.State().dest == "group", "Ziel passt zum Auslöser ohne Person")
page.Save()
assert(boss.action == "both" and boss.emote == "CHEER", "Formular speichert ohne Verlust")
for _, d in ipairs(dds) do if d.opts.onChange and d.value == "boss" then d.opts.onChange("chat") end end
assert(page.State().kind == "chat", "Auslöser umgestellt")
assert(FW.L.TAB_AUTOREPLY == "Auto-Antwort" and FW.L.AR_K_rollwon, "deutsche Texte")
print("autoreply tab: ok")
