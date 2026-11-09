-- Test eigenes Chatfenster: Einordnung, Reiter-Filter, Eingabe, Speicher (texlua tests/chatwindow_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end
local function Proxy()
    return setmetatable({}, { __index = function() return function() return Proxy() end end })
end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
_G.UnitName = function() return "Pinky" end
_G.time = os.time
local ev, secret = {}, {}
local UI = setmetatable({ RegisterSettingsSection = function() end }, { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    RegisterEvent = function(_, e, f) ev[e] = f end, On = function() end, Fire = function() end,
    Util = { IsSecret = function(v) return secret[v] == true end },
    Whisper = { SelfName = function() return "Pinky Freewood" end } }
assert(loadfile("UI/ChatWindow.lua"))("Freewood-Core", FW)
local W = FW.ChatWindow
local RealOpenInput = W.OpenInput
assert(loadfile("UI/ChatWindowTabs.lua"))("Freewood-Core", FW)

local k, x = W.Classify("guild"); eq(k, "guild", "Gilde")
eq(W.Classify("group"), "group", "Gruppe")
k, x = W.Classify("w:Anna"); eq(k, "whisper", "Fluestern"); eq(x, "Anna", "Fluesterpartner")
k, x = W.Classify("c:Handel"); eq(k, "channel", "Kanal"); eq(x, "Handel", "Kanalname")
eq(W.Classify("xyz"), nil, "unbekannt")

W.Push("guild", "Anna", "hi", false)
W.Push("group", "Bob", "los", false)
W.Push("w:Cid", "Cid", "psst", false)
W.Push("c:3. Handel - Orgrimmar", "Dora", "WTS", false)
W.Push("c:1. Allgemein - Orgrimmar", "Dora", "hallo zusammen", false)
ev.CHAT_MSG_SAY("Hallo", "Eve")
ev.CHAT_MSG_YELL("Hilfe", "Fred")
ev.CHAT_MSG_EMOTE("tanzt", "Gus")
-- Standard-Reiter: Chat, Handel, Allgemein, Meldungen, Kampflog
local tabs = W.Tabs()
eq(#tabs, 5, "fuenf Standard-Reiter"); eq(tabs[1].id, "chat", "erster Reiter"); eq(W.TabName(tabs[1]), "CHATWIN_TAB_CHAT", "Name aus Textschluessel")
eq(#W.Visible("chat"), 6, "Chat: gilde, gruppe, fluestern, sagen, rufen, emote")
eq(#W.Visible("trade"), 1, "Handel nur der Handelskanal")
eq(#W.Visible("general"), 1, "Allgemein nur der Allgemein-Kanal")
eq(W.NormChannel("3. Handel - Orgrimmar"), "handel", "Kanalname vereinfacht")
eq(W.NormChannel("LokaleVerteidigung"), "lokaleverteidigung", "Kanalname ohne Zusatz")
-- Meldungen und Kampflog
ev.CHAT_MSG_SKILL("Dein Skill steigt.")
ev.CHAT_MSG_LOOT("Du erhaeltst Beute: [Stein].")
ev.CHAT_MSG_COMBAT_FACTION_CHANGE("Ruf bei Orgrimmar gestiegen.")
ev.CHAT_MSG_SYSTEM("Bogadin ist jetzt offline.")
ev.CHAT_MSG_SYSTEM("Bogadin ist jetzt offline.")
eq(#W.Visible("msgs"), 2, "Meldungen: Ruf und System (doppelte zusammengefasst)")
eq(#W.Visible("chat"), 8, "Skill und Beute stehen im Chat-Reiter")
W.Add("combat", "", "Du triffst Eber fuer 12.", false)
eq(#W.Visible("combat"), 1, "Kampflog")
eq(#W.Visible("chat"), 8, "Kampflog nicht im Chat")
secret["geheim2"] = true
ev.CHAT_MSG_SYSTEM("geheim2")
eq(#W.Visible("msgs"), 2, "geheime Systemmeldung uebersprungen")
-- Reihenfolge ueber mehrere Listen
local mixed = W.Visible("chat")
local ordered = true
for i = 2, #mixed do if mixed[i].q < mixed[i - 1].q then ordered = false end end
eq(ordered, true, "gemischte Liste in Reihenfolge")
-- Darstellung
eq(W.Style("guild"), "bubble", "Gilde Blase"); eq(W.Style("loot"), "line", "Beute Zeile"); eq(W.Style("emote"), "line", "Emote Zeile")
FW.settings.chatWin.styles = { loot = "bubble" }
eq(W.Style("loot"), "bubble", "Darstellung einstellbar")
FW.settings.chatWin.styles = nil

-- eigene Reiter verwalten
local nt = W.AddTab("Mein Reiter")
eq(#W.Tabs(), 6, "Reiter hinzugefuegt"); eq(W.Visible(nt.id)[1], nil, "neuer Reiter leer")
nt.groups.guild = true
eq(#W.Visible(nt.id), 1, "neuer Reiter zeigt Gilde")
W.TabSetChannel(nt, "Handel", true); eq(W.TabHasChannel(nt, "3. Handel - Stadt"), true, "Kanal im Reiter")
eq(#W.Visible(nt.id), 2, "Handel dazu")
W.TabSetChannel(nt, "handel", false); eq(W.TabHasChannel(nt, "Handel"), false, "Kanal entfernt")
nt.allChannels = true; eq(#W.Visible(nt.id), 3, "alle Kanaele (zwei)"); nt.allChannels = nil
eq(W.MoveTab(nt.id, -1), true, "nach links"); eq(W.Tabs()[5].id, nt.id, "Reihenfolge geaendert")
eq(W.MoveTab(W.Tabs()[1].id, -1), false, "ganz links bleibt")
local names = W.EditorChannelNames(nt)
eq(names[1] ~= nil, true, "Kanalliste")
W.Opts().tab = nt.id
eq(W.RemoveTab(nt.id), true, "Reiter geloescht"); eq(W.Opts().tab, "chat", "offener Reiter faellt auf den ersten")
eq(#W.Tabs(), 5, "wieder fuenf")
W.Opts().tab = "chat"
-- Ungelesen (Handel-Reiter bekommt Nachrichten, Chat ist offen)
W.unread = {}
W.Push("c:Handel", "Dora", "noch ein Angebot", false)
eq(W.unread.trade, 1, "ungelesen im Handel-Reiter"); eq(W.unread.chat, nil, "offener Reiter zaehlt nicht")

-- eigene Nachricht
ev.CHAT_MSG_SAY("ich", "Pinky")
eq(W.msgs[#W.msgs].o, true, "eigene Nachricht erkannt")
-- Geheimes wird uebersprungen
secret["geheim"] = true
local c = #W.msgs
ev.CHAT_MSG_SAY("geheim", "Eve")
eq(#W.msgs, c, "geheimer Text uebersprungen")
-- Speicher begrenzt
for i = 1, 500 do W.Push("guild", "A", "m" .. i, false) end
eq(#W.msgs <= 345, true, "Speicher begrenzt")

-- Eingabe
local kind, target, text = W.ParseInput("/g Hallo Welt", "all", nil); eq(kind, "guild", "/g"); eq(text, "Hallo Welt", "/g Text")
kind = W.ParseInput("/s hi", "guild", nil); eq(kind, "say", "/s")
kind = W.ParseInput("/y hi", "all", nil); eq(kind, "yell", "/y")
kind = W.ParseInput("/p hi", "all", nil); eq(kind, "group", "/p")
kind, target, text = W.ParseInput("/w Anna wie gehts", "all", nil); eq(kind, "whisper", "/w"); eq(target, "Anna", "/w Ziel"); eq(text, "wie gehts", "/w Text")
kind, target, text = W.ParseInput("/2 hallo", "all", nil); eq(kind, "channel", "/2"); eq(target, 2, "/2 Kanalnummer")
kind, target = W.ParseInput("/foo bar", "all", nil); eq(kind, nil, "unbekannter Befehl"); eq(target, "unknown", "Fehlerart")
kind, target = W.ParseInput("/w Anna", "all", nil); eq(target, "usage", "/w ohne Text")
kind = W.ParseInput("hallo", "guild", nil); eq(kind, "guild", "Gilden-Reiter sendet an Gilde")
kind = W.ParseInput("hallo", "group", nil); eq(kind, "group", "Gruppen-Reiter")
kind = W.ParseInput("hallo", "all", nil); eq(kind, "say", "Standard sagen")
kind, target = W.ParseInput("hallo", "guild", "Anna"); eq(kind, "whisper", "Fluesterziel hat Vorrang"); eq(target, "Anna", "Fluesterziel")
eq(W.ParseInput("   ", "all", nil), nil, "leer")

-- Senden
local sent = {}
_G.SendChatMessage = function(t, ch) sent[#sent + 1] = ch .. ":" .. t end
W.Send("say", nil, "a"); W.Send("yell", nil, "b")
eq(sent[1], "SAY:a", "senden sagen"); eq(sent[2], "YELL:b", "senden rufen")
FW.ChatLog = { Send = function(kd, tg, tx) sent[#sent + 1] = kd .. ":" .. tx end }
W.Send("guild", nil, "c"); eq(sent[3], "guild:c", "Gilde ueber ChatLog")

-- /r (Antworten) und andere unbekannte Befehle werden weitergereicht, /ra ist Schlachtzug
W.lastTell = nil
kind, target = W.ParseInput("/r hallo", "all", nil); eq(kind, nil, "/r wird weitergereicht"); eq(target, "unknown", "/r unbekannt")
kind = W.ParseInput("/ra hallo", "all", nil); eq(kind, "group", "/ra")

-- Spiel-Eingabefeld umleiten
FW.settings.chatWin.main = true
local opened
W.OpenInput = function(t) opened = t; return true end
W.MainActive = function() return true end
local closed = 0
local eb = { GetText = function() return "" end, ClearFocus = function() closed = closed + 1 end, Hide = function() closed = closed + 1 end,
    GetAttribute = function(_, k) if k == "chatType" then return "WHISPER" elseif k == "tellTarget" then return "Anna" end end }
eq(W.OnBlizzActivate(eb, false), true, "Aktivierung umgeleitet")
eq(opened, "", "Eingabe geoeffnet"); eq(closed >= 1, true, "Spiel-Feld geschlossen"); eq(W.target, "Anna", "Fluesterziel vom Antworten")
W.target = nil
opened = nil
eq(W.OnBlizzActivate(eb, true), false, "Umschalt: Spiel-Feld bleibt (Notausgang)"); eq(opened, nil, "nicht geoeffnet")
W.bypass = true; eq(W.OnBlizzActivate(eb, false), false, "Bypass"); W.bypass = false
W.MainActive = function() return false end
eq(W.OnBlizzActivate(eb, false), false, "Haupt-Chat aus: nichts umleiten")
W.MainActive = function() return true end
W.redirected = true
W.OnBlizzOpenChat("/")
eq(W.redirected, false, "Nachtragen setzt Marke zurueck")

-- Weiterreichen
local sentT
_G.ChatEdit_SendText = function(e) sentT = e.text end
local feb = { SetText = function(self, t) self.text = t end }
_G.DEFAULT_CHAT_FRAME = { editBox = feb }
eq(W.Forward("/roll 100"), true, "Weiterreichen"); eq(sentT, "/roll 100", "Text beim Spiel angekommen")
_G.ChatEdit_SendText = nil
eq(W.Forward("/roll"), false, "ohne Spiel-Funktion false")

-- eigene Nachrichten erkennen (auch ohne Kennzeichen vom Chat-Protokoll)
W.Push("guild", "Pinky", "ich in der Gilde", false); eq(W.msgs[#W.msgs].o, true, "eigene Gildennachricht rechts")
W.Push("guild", "Pinky-Realm", "mit Realm", false); eq(W.msgs[#W.msgs].o, true, "eigener Name mit Realm")
W.Push("guild", "Anna", "fremd", false); eq(W.msgs[#W.msgs].o, nil, "fremde Nachricht links")
W.Push("group", "Pinky Freewood", "voller Name", false); eq(W.msgs[#W.msgs].o, true, "voller eigener Name")

-- Tasten: Bindungen und Abfrage
_G.GetBindingKey = function(a) if a == "OPENCHAT" then return "ENTER", "F5" end end
local keys = W.BindingKeys("OPENCHAT", { "ENTER", "NUMPADENTER" })
eq(#keys, 3, "Tasten ohne Doppelte"); eq(keys[2], "F5", "zweite Taste aus dem Spiel")
local opened2
W.OpenInput = function(t) opened2 = t; return true end
_G.IsShiftKeyDown = function() return false end
W.MainActive = function() return true end
eq(W.HandleKey("ENTER"), true, "Enter oeffnet"); eq(opened2, "", "leer geoeffnet")
eq(W.HandleKey("F5"), true, "zweite Taste oeffnet")
eq(W.HandleKey("A"), false, "andere Taste wird weitergegeben")
_G.IsShiftKeyDown = function() return true end
_G.GetBindingKey = function(a) if a == "OPENCHATSLASH" then return "SHIFT-7" end end
eq(W.HandleKey("7"), true, "Schraegstrich auf deutscher Tastatur (Umschalt+7)"); eq(opened2, "/", "mit Schraegstrich geoeffnet")
_G.IsShiftKeyDown = function() return false end
FW.settings.chatWin.useBlizz = true
eq(W.UseBlizz(), true, "Feld des Spiels aktiv (Haupt-Chat an)")
eq(W.HandleKey("ENTER"), false, "Spiel-Feld-Modus: keine eigene Tastenabfrage")
eq(W.OnBlizzActivate({}, false), false, "Spiel-Feld-Modus: nichts umleiten")
FW.settings.chatWin.main = false
eq(W.UseBlizz(), false, "Spiel-Feld-Modus nur bei Haupt-Chat")

-- Kuerzel im Eingabefeld verbrauchen ("/g " springt auf Gilde)
local nt, ch = W.ConsumePrefix("/g Hallo"); eq(nt, "Hallo", "Kuerzel entfernt"); eq(ch.kind, "guild", "/g")
nt, ch = W.ConsumePrefix("/g "); eq(nt, "", "leer nach Kuerzel"); eq(ch.kind, "guild", "/g mit Leerzeichen")
nt, ch = W.ConsumePrefix("/g"); eq(nt, nil, "ohne Leerzeichen noch nicht")
nt, ch = W.ConsumePrefix("/s hi"); eq(ch.kind, "say", "/s")
nt, ch = W.ConsumePrefix("/y hi"); eq(ch.kind, "yell", "/y")
nt, ch = W.ConsumePrefix("/p hi"); eq(ch.kind, "group", "/p")
nt, ch = W.ConsumePrefix("/ra hi"); eq(ch.kind, "group", "/ra")
nt, ch = W.ConsumePrefix("/w Anna wie gehts"); eq(ch.kind, "whisper", "/w"); eq(ch.target, "Anna", "Fluesterziel"); eq(nt, "wie gehts", "Text nach Name")
nt, ch = W.ConsumePrefix("/w Anna"); eq(nt, nil, "/w ohne Leerzeichen nach dem Namen noch nicht")
nt, ch = W.ConsumePrefix("/2 hallo"); eq(ch.kind, "channel", "/2"); eq(ch.channel, 2, "Kanalnummer"); eq(nt, "hallo", "Text nach Kanal")
nt, ch = W.ConsumePrefix("/roll 100"); eq(nt, nil, "unbekannter Befehl bleibt im Feld")
nt, ch = W.ConsumePrefix("/e tanzt"); eq(nt, nil, "/e bleibt im Feld")
nt, ch = W.ConsumePrefix("Hallo /g "); eq(nt, nil, "nur am Anfang")
W.ApplyPrefix({ kind = "guild" }); eq(W.sendKind, "guild", "Ziel Gilde"); eq(W.target, nil, "Fluesterziel geloescht")
W.ApplyPrefix({ kind = "whisper", target = "Anna" }); eq(W.target, "Anna", "Fluesterziel gesetzt")
W.ApplyPrefix({ kind = "channel", channel = 3 }); eq(W.sendKind, "channel", "Kanal"); eq(W.channel, 3, "Kanalnummer gemerkt"); eq(W.target, nil, "Fluesterziel weg")
kind, target = W.ParseInput("hallo", "channel", nil, 3); eq(kind, "channel", "Standardziel Kanal"); eq(target, 3, "Kanalnummer")
kind = W.ParseInput("hallo", "yell", nil); eq(kind, "yell", "Standardziel Rufen")
W.ApplyPrefix({ kind = "say" })

-- Zeilen im Stil des Spiel-Chats
local Lc = setmetatable({}, { __index = function(_, k) return k end })
local pre, name, post, color = W.ClassicParts({ kind = "guild", s = "Anna" }, nil, Lc, "hi")
eq(pre, "[CHATWIN_TAB_GUILD] ", "Gildenkennung"); eq(name, "Anna", "Name"); eq(post, ": hi", "Text nach Name"); eq(type(color), "string", "Farbcode")
pre, name, post = W.ClassicParts({ kind = "say", s = "Bob" }, nil, Lc, "hallo"); eq(pre, "", "Sagen ohne Kennung"); eq(post, " CHATWIN_SAYS: hallo", "sagt")
pre, name, post = W.ClassicParts({ kind = "whisper", s = "Pinky", x = "Cid", o = true }, nil, Lc, "psst"); eq(pre, "CHATWIN_WHISPER_TO ", "An"); eq(name, "Cid", "Fluesterpartner")
pre, name, post = W.ClassicParts({ kind = "whisper", s = "Cid", x = "Cid" }, nil, Lc, "psst"); eq(name, "Cid", "Absender"); eq(post, " CHATWIN_WHISPERS: psst", "fluestert")
pre, name = W.ClassicParts({ kind = "emote", s = "Gus" }, nil, Lc, "Gus tanzt."); eq(pre, "Gus tanzt.", "Emote unveraendert"); eq(name, nil, "Emote ohne Name")
pre, name = W.ClassicParts({ kind = "channel", s = "Dora", x = "3. Handel - Stadt" }, nil, Lc, "WTS"); eq(pre, "[3. Handel - Stadt] ", "Kanalkennung")

-- Verlauf aus dem Spiel-Chat uebernehmen
eq(W.KindFromColor(0.25, 1, 0.25, "x"), "guild", "Gildenfarbe"); eq(W.KindFromColor(1, 1, 0, "x"), "system", "Gelb ist System")
eq(W.KindFromColor(nil), "addon", "ohne Farbe Addon"); eq(W.KindFromColor(1, 1, 1, "Anna CHATWIN_SAYS: hi"), "say", "weiss mit sagt")
eq(W.KindFromColor(1, 1, 1, "Adventure Binder: Ready"), "addon", "weiss sonst Addon")
W.msgs, W.lines, W.combat, W.imported = {}, {}, {}, nil
W.Add("say", "Live", "nach dem Anmelden", false)
local hist = {
    { "15:39 [Gilde] Anna: hallo", 0.25, 1, 0.25 }, { "Willkommen bei Musician", 1, 1, 0 },
    { "Adventure Binder: Ready", 1, 1, 1 }, { "\124cff000001\124r[3. Handel - Stadt] Dora: WTS", 1, 0.75, 0.75 },
}
_G.DEFAULT_CHAT_FRAME = { GetNumMessages = function() return #hist end, GetMessageInfo = function(_, i) local h = hist[i]; return h[1], h[2], h[3], h[4] end }
eq(W.ImportHistory(), true, "Verlauf uebernommen"); eq(W.imported, true, "nur einmal")
eq(#W.Visible("msgs"), 2, "System und Addon aus dem Verlauf")
eq(#W.Visible("trade"), 1, "Kanalzeile im Handel-Reiter"); eq(W.Visible("trade")[1].raw, true, "uebernommene Zeile roh")
eq(string.find(W.Visible("trade")[1].m, "000001", 1, true), nil, "Markierung entfernt")
local chatList = W.Visible("chat")
eq(#chatList, 2, "Gilde aus dem Verlauf plus Live"); eq(chatList[1].raw, true, "Verlauf steht vorn"); eq(chatList[2].kind, "say", "Live danach")
W.imported = nil; W.ImportHistory(); eq(#W.Visible("msgs"), 4, "zweiter Aufruf nach Zuruecksetzen (nur zur Kontrolle)")

-- Eingabefeld des Spiels wird im Haupt-Chat-Modus versteckt (umgehaengt) und zurueckgegeben
do
    local orig = {}
    local eb = { parent = orig }
    function eb:GetParent() return self.parent end
    function eb:SetParent(p) self.parent = p end
    _G.ChatFrame1EditBox = eb
    _G.NUM_CHAT_WINDOWS = 1
    W.HideBlizzard()
    eq(eb.parent ~= orig, true, "Eingabefeld umgehaengt")
    local hidden = eb.parent
    W.HideBlizzard()
    eq(eb.parent, hidden, "zweiter Aufruf aendert nichts")
    W.ShowBlizzard()
    eq(eb.parent, orig, "Eingabefeld zurueck am alten Platz")
    _G.ChatFrame1EditBox = nil
end
-- Links (Umschalt+Klick) in das eigene Eingabefeld
do
    local ib = {}
    W.SetInputForTest(ib)
    eq(W.InputBox(), ib, "Eingabefeld gesetzt")
    if ib then
        local got, focus = {}, false
        ib.HasFocus = function() return focus end
        ib.Insert = function(_, t) got[#got + 1] = t end
        local link = "|cffffffff|Hitem:6948::::::::60:::::|h[Hearthstone]|h|r"
        eq(W.InsertLink(link), false, "ohne Fokus nichts")
        focus = true
        eq(W.InsertLink(link), true, "mit Fokus eingefuegt"); eq(got[1], link, "Link im Feld")
        W.InsertLink(link)
        eq(#got, 1, "doppelter Aufruf im selben Moment zaehlt einmal")
        eq(W.InsertLink(42), false, "kein Text"); eq(W.InsertLink(""), false, "leerer Text")
        _G.GetTime = function() return 50 end
        W.InsertLink(link)
        eq(#got, 2, "spaeter wieder erlaubt")
    end
end
-- Eingabe-Verlauf
do
    W.Opts().hist = {}
    W.HistReset()
    eq(W.HistNav(-1, "x"), nil, "leerer Verlauf: nichts")
    W.HistPush("eins"); W.HistPush("zwei"); W.HistPush("zwei"); W.HistPush("   "); W.HistPush("")
    eq(#W.Opts().hist, 2, "doppelte und leere werden nicht gemerkt")
    eq(W.HistNav(1, "x"), nil, "runter ohne vorher hoch: nichts")
    eq(W.HistNav(-1, "halb"), "zwei", "hoch: letzte Eingabe")
    eq(W.HistNav(-1, "zwei"), "eins", "hoch: davor")
    eq(W.HistNav(-1, "eins"), nil, "hoch am Anfang: nichts")
    eq(W.HistNav(1, "eins"), "zwei", "runter: neuere")
    eq(W.HistNav(1, "zwei"), "halb", "ganz unten: angefangener Text zurueck")
    eq(W.HistNav(1, "halb"), nil, "unten: nichts")
    for i = 1, 60 do W.HistPush("t" .. i) end
    eq(#W.Opts().hist, 50, "hoechstens 50"); eq(W.Opts().hist[50], "t60", "neueste zuletzt")
    -- Taste
    local ib = { text = "abc", GetText = function(self) return self.text end, SetText = function(self, t) self.text = t end, SetCursorPosition = function(self, n) self.cur = n end }
    W.HistReset()
    _G.GetTime = function() return 100 end
    W.HistKey(ib, "UP")
    eq(ib.text, "t60", "Pfeil hoch setzt Text"); eq(ib.cur, 3, "Cursor ans Ende")
    W.HistKey(ib, "UP")
    eq(ib.text, "t60", "gleiche Taste im selben Moment zaehlt einmal")
    _G.GetTime = function() return 101 end
    W.HistKey(ib, "UP"); eq(ib.text, "t59", "naechster Druck: aeltere")
    _G.GetTime = function() return 102 end
    W.HistKey(ib, "DOWN"); eq(ib.text, "t60", "Pfeil runter")
    W.HistKey(ib, "LEFT"); eq(ib.text, "t60", "andere Tasten ignoriert")
end
-- Stufe in Zeilen
do
    local CLs = { Info = function(n) if n == "Anna" then return "MAGE", 42 end return nil end, ClassColor = function() return 1, 1, 1 end }
    local Ls = {}
    W.Opts().showLevel = true
    local pre, name, post = W.ClassicParts({ kind = "guild", s = "Anna" }, CLs, Ls, "hi")
    eq(name, "Anna", "Name bleibt allein"); eq(post:find("%[42%]") ~= nil, true, "Stufe hinter dem Namen"); eq(post:find(": hi", 1, true) ~= nil, true, "Text danach")
    local _, _, post2 = W.ClassicParts({ kind = "say", s = "Bert" }, CLs, Ls, "x")
    eq(post2:find("%[") , nil, "unbekannte Stufe: nichts")
    W.Opts().showLevel = false
    local _, _, post3 = W.ClassicParts({ kind = "guild", s = "Anna" }, CLs, Ls, "hi")
    eq(post3, ": hi", "abgeschaltet")
    W.Opts().showLevel = true
end
-- /r, Kontakte, Fluestern von aussen
do
    W.lastTell = nil
    W.contacts = {}
    eq(select(2, W.ParseInput("/r hallo")), "unknown", "/r ohne Gegenueber unbekannt")
    W.Add("whisper", "Anna", "huhu", false)
    eq(W.lastTell, "Anna", "letzter Fluesterer gemerkt")
    local k, t, m = W.ParseInput("/r hallo")
    eq(k, "whisper", "/r fluestert"); eq(t, "Anna", "Ziel Anna"); eq(m, "hallo", "Text")
    eq(select(1, W.ParseInput("/antwort hi")), "whisper", "/antwort")
    local txt, ch = W.ConsumePrefix("/r wie gehts")
    eq(txt, "wie gehts", "Kuerzel entfernt"); eq(ch.target, "Anna", "Ziel gesetzt")
    W.Add("whisper", "Ich", "an Bert", true, "Bert")
    eq(W.lastTell, "Anna", "eigene Fluesternachricht aendert /r nicht")
    W.Add("whisper", "Carla", "yo", false)
    eq(W.contacts[#W.contacts], "Carla", "Kontakte: neuester zuletzt"); eq(#W.contacts, 3, "Anna, Bert, Carla")
    W.target = nil
    eq(W.CycleContact(1), "Carla", "Tab: neuester zuerst")
    W.target = "Carla"; eq(W.CycleContact(1), "Bert", "Tab: naechster")
    W.target = "Anna"; eq(W.CycleContact(1), "Carla", "Tab: springt herum")
    W.target = "Carla"; eq(W.CycleContact(-1), "Anna", "Umschalt+Tab: zurueck")
    W.NoteContact("Anna"); eq(W.contacts[#W.contacts], "Anna", "Wiederholung nach vorn")
    eq(#W.contacts, 3, "keine Doppelten")
    for i = 1, 15 do W.NoteContact("P" .. i) end
    eq(#W.contacts, 10, "hoechstens 10")
    -- Fluestern von aussen: nur wenn der Haupt-Chat aktiv ist
    eq(W.StartWhisper(42), false, "kein Name")
    local box = { text = "", GetText = function(self) return self.text end, SetText = function(self, t) self.text = t end,
        HasFocus = function() return false end, SetFocus = function() end }
    W.SetInputForTest(box)
    W.MainActive = function() return false end
    eq(W.StartWhisper("Dora"), false, "ohne Haupt-Chat nichts")
    W.MainActive = function() return true end
    local opened
    W.OpenInput = function(t) opened = t; return true end
    eq(W.StartWhisper("Dora", "Hallo"), true, "mit Haupt-Chat: geoeffnet"); eq(W.target, "Dora", "Ziel gesetzt"); eq(W.sendKind, "whisper", "Art Fluestern"); eq(opened, "Hallo", "Text vorbelegt")
    W.StartWhisper("Emil"); eq(opened, "", "ohne Text leeres Feld"); eq(W.target, "Emil", "Ziel Emil")
    eq(W.StartWhisper("Geheim"), true, "normaler Name")
end
-- Wuerfelmeldungen
do
    _G.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
    _G.LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
    _G.LOOT_ROLL_WON = "%s won: %s"
    W.ResetRollPatterns()
    eq(W.IsRollText("Anna rolls 45 (1-100)"), true, "/roll erkannt")
    eq(W.IsRollText("|cffffff00Anna rolls 45 (1-100)|r"), true, "mit Farbcode")
    eq(W.IsRollText("Need Roll - 87 for |Hitem:1:0|h[Schwert]|h by Bert"), true, "Beute-Wurf")
    eq(W.IsRollText("Bert won: |Hitem:1:0|h[Schwert]|h"), true, "Gewinner")
    eq(W.IsRollText("Anna rolls many dice"), false, "kein Wurf")
    eq(W.IsRollText("Hallo Welt"), false, "normaler Text"); eq(W.IsRollText(42), false, "kein Text")
    -- deutsche Vorlage mit nummerierten Platzhaltern
    _G.RANDOM_ROLL_RESULT = "%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)"
    W.ResetRollPatterns()
    eq(W.IsRollText("Anna würfelt. Ergebnis: 45 (1-100)"), true, "deutsche Vorlage")
    -- doppelt (Ereignis und Spiel-Chat) zaehlt einmal
    local before = #W.lines
    W.AddSystem("Anna würfelt. Ergebnis: 12 (1-100)", "system")
    W.AddSystem("Anna würfelt. Ergebnis: 12 (1-100)", "loot")
    eq(#W.lines - before, 1, "gleiche Meldung nur einmal")
end
do -- /rollen und /würfeln gehen als /roll an das Spiel
    local sent = {}
    _G.ChatFrame1EditBox = { SetText = function(_, t) if t ~= "" then sent[#sent + 1] = t end end }
    _G.DEFAULT_CHAT_FRAME = nil
    _G.ChatEdit_SendText = function() end
    W.Forward("/rollen 50"); W.Forward("/würfeln"); W.Forward("/rollenx")
    eq(sent[1], "/roll 50", "/rollen -> /roll"); eq(sent[2], "/roll", "/würfeln -> /roll"); eq(sent[3], "/rollenx", "kein falscher Treffer")
end
do -- Pfeil-Abfrage: Ereignis und Abfrage derselben Taste zaehlen einmal, Abfrage allein wirkt
    local o = W.Opts(); o.hist = { "eins", "zwei" }; W.HistReset(); W.arrowLog = {}
    local box = { t = "", GetText = function(self) return self.t end, SetText = function(self, v) self.t = v end }
    W.HistKey(box, "UP", "Pfeil"); W.HistKey(box, "UP", "Abfrage")
    eq(box.t, "zwei", "Ereignis + Abfrage = ein Schritt")
    _G.GetTime = function() return 100 end
    W.hKeyAt = nil
    W.HistKey(box, "UP", "Abfrage")
    eq(box.t, "eins", "Abfrage allein geht eine Eintragung zurueck")
    eq(#W.arrowLog, 3, "Pfeilprotokoll")
end
do -- "kein Spieler ... online" wird nicht angezeigt
    eq(W.IsNotFoundText("Momentan ist kein Spieler mit dem Namen 'Banka Nahl' online."), true, "offline deutsch")
    eq(W.IsNotFoundText("|cffffff00Momentan ist kein Spieler mit dem Namen 'X' online.|r"), true, "mit Farbe")
    eq(W.IsNotFoundText("No player named 'Bob' is currently playing."), true, "offline englisch")
    eq(W.IsNotFoundText("Ihr erhaltet Beute: [Leichtes Leder]"), false, "andere Meldung")
    local before = #W.lines
    W.AddSystem("Momentan ist kein Spieler mit dem Namen 'Talon' online.", "system")
    eq(#W.lines, before, "nicht in die Zeilen")
end
do -- Spielermenue
    local calls, fwd = {}, {}
    _G.C_PartyInfo = { InviteUnit = function(n) calls[#calls + 1] = "invite:" .. n end }
    _G.C_FriendList = { AddFriend = function(n) calls[#calls + 1] = "friend:" .. n end, SendWho = function(q) calls[#calls + 1] = "who:" .. q end }
    local ids = {}
    for _, e in ipairs(W.MenuEntries("Anna")) do ids[#ids + 1] = e.id end
    eq(table.concat(ids, ","), "whisper,invite,friend,ignore,who", "alle Menuepunkte immer")
    eq(W.MenuAction("invite", "Anna"), true, "einladen"); eq(W.MenuAction("friend", "Anna"), true, "Freund")
    W.MenuAction("who", "Anna")
    eq(calls[1], "invite:Anna", "Einladung an Anna"); eq(calls[2], "friend:Anna", "Freund Anna"); eq(calls[3], 'who:n-"Anna"', "Wer-Abfrage")
    -- Ignorieren ohne Schnittstelle: Rueckfall auf den Chatbefehl
    local realFwd = W.Forward
    W.Forward = function(t) fwd[#fwd + 1] = t; return true end
    eq(W.MenuAction("ignore", "Anna"), true, "Ignorieren ueber Befehl"); eq(fwd[1], "/ignore Anna", "Befehl /ignore")
    _G.C_PartyInfo = nil
    W.MenuAction("invite", "Bert"); eq(fwd[2], "/invite Bert", "Rueckfall /invite")
    W.Forward = realFwd
    -- Standard: nur das eigene Menue; Spiel-Menue nur auf Wunsch
    local ref
    _G.SetItemRef = function(link, text, btn) ref = { link, btn }; _G.DropDownList1 = { IsShown = function() return true end } end
    W.ShowPlayerMenu("Bert"); eq(ref, nil, "Standard: Spiel-Menue wird nicht gerufen")
    W.Opts().gameMenu = true
    eq(W.ShowPlayerMenu("Bert"), true, "Menue geoeffnet"); eq(ref[1], "player:Bert", "Link"); eq(ref[2], "RightButton", "rechte Taste")
    eq(W.ShowPlayerMenu("Pinky"), false, "eigener Name: kein Menue")
    W.Opts().gameMenu = false; _G.SetItemRef = nil; _G.DropDownList1 = nil
end
do -- Blasenfarben
    UI.Color = function() return 0.2, 0.2, 0.2, 1 end
    local r, g, b = W.BubbleColor("guild", false); eq(type(r), "number", "Standardfarbe")
    r, g, b = W.BubbleColor("say", true); eq(r, 0.13, "eigene Blase blau")
    W.SetBubbleColor("guild", 0.1, 0.5, 0.2); r, g, b = W.BubbleColor("guild", false)
    eq(r, 0.1, "Gildenfarbe R"); eq(g, 0.5, "Gildenfarbe G"); eq(b, 0.2, "Gildenfarbe B")
    r = W.BubbleColor("yell", false); eq(r ~= 0.1, true, "andere Art unveraendert")
    W.SetBubbleColor("own", 0.9, 0.1, 0.1); eq(W.BubbleColor("guild", true), 0.9, "eigene Farbe gilt fuer eigene Nachrichten")
    W.SetBubbleColor("guild", nil); eq(W.BubbleColor("guild", false) ~= 0.1, true, "zurueckgesetzt")
    W.Opts().bubbleBg = { say = "kaputt" }; eq(type(W.BubbleColor("say", false)), "number", "kaputter Wert -> Standard")
    W.Opts().bubbleBg = nil
end
do -- nach dem Laden bleibt das Eingabefeld zu
    local focus, txt = false, "x"
    local box = { HasFocus = function() return focus end, SetFocus = function() focus = true end, ClearFocus = function() focus = false end,
        SetText = function(_, t) txt = t end, GetText = function() return txt end }
    W.SetInputForTest(box)
    local t = 500
    _G.GetTime = function() return t end
    W.OpenInput = RealOpenInput
    W.CloseAfterLoad()
    eq(W.OpenInput(""), false, "kurz nach dem Laden kein Oeffnen"); eq(focus, false, "kein Fokus")
    t = 503
    eq(W.OpenInput(""), true, "spaeter geht es"); eq(focus, true, "Fokus da")
    focus = true; txt = "alt"; W.CloseAfterLoad()
    eq(focus, false, "Fokus nach Laden weg"); eq(txt, "", "Text geleert")
    W.loadGuardUntil = nil
end
do -- Schrift je Schriftart des Textes
    eq(W.ScriptOf("Hallo Wörter äöü ß"), "latin", "deutsch bleibt Spielschrift")
    eq(W.ScriptOf("Привет"), "ext", "kyrillisch")
    eq(W.ScriptOf("Zażółć"), "ext", "polnisch")
    eq(W.ScriptOf("你好"), "cjk", "chinesisch"); eq(W.ScriptOf("こんにちは"), "cjk", "japanisch")
    eq(W.ScriptOf("안녕하세요"), "kr", "koreanisch"); eq(W.ScriptOf(nil), "latin", "kein Text")
    local set = {}
    local fs = { SetFont = function(self, path, size) set[#set + 1] = path; return path ~= "Fonts\\ARIALN.TTF" end }
    W.ResetFontPick()
    eq(W.FontFor(fs, "Привет", 11), "ext", "Schriftart ext")
    eq(set[1], "Fonts\\ARIALN.TTF", "erste Wahl probiert"); eq(set[2], "Fonts\\FRIZQT___CYR.TTF", "zweite Wahl, weil erste fehlte")
    local n0 = #set
    W.FontFor(fs, "Привет!", 11); eq(#set, n0, "gleiche Schriftart und Groesse: nichts neu setzen")
    W.FontFor(fs, "Hallo", 11); eq(fs.fwScript, "latin", "zurueck auf Spielschrift")
end
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
