-- Test: Battle.net-Fluestern im Chat-Protokoll (texlua tests/bnwhisper_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, tostring(a), tostring(b)) end end
_G.FreewoodDB = {}
_G.UnitName = function(u) return u == "player" and "Pinky Freewood" or nil end
_G.UnitExists = function() return false end
_G.time = function() return 1000 end
_G.CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.C_Timer = { After = function() end }
_G.SendChatMessage = function() end
_G.hooksecurefunc = function() end
local sent, normal = {}, {}
_G.SendChatMessage = function(t, kind, _, target) normal[#normal + 1] = { t, kind, target } end
_G.BNSendWhisper = function(id, t) sent[#sent + 1] = { id, t } end
-- Freundesliste: Kennung 17 = Lujin#2467 (Kontoname wechselt je Sitzung: "|Kq5|k")
_G.BNGetNumFriends = function() return 2 end
local friends = { { bnetAccountID = 17, battleTag = "Lujin#2467", accountName = "|Kq5|k" },
    { bnetAccountID = 23, battleTag = "Exclaime#1111", accountName = "|Kq9|k" } }
_G.C_BattleNet = {
    GetFriendAccountInfo = function(i) return friends[i] end,
    GetAccountInfoByID = function(id) for _, f in ipairs(friends) do if f.bnetAccountID == id then return f end end end,
}
local events, fired, printed = {}, {}, {}
local FW = { chardb = {}, RegisterEvent = function(_, e, f) events[e] = f end, Print = function(_, t) printed[#printed + 1] = t end,
    Fire = function(_, e, ...) fired[#fired + 1] = { e, ... } end }
FW.L = setmetatable({}, { __index = function(_, k) return k end })
assert(loadfile("Core/ChatLog.lua"))("Freewood-Core", FW)
local CL = FW.ChatLog

eq(CL.IsBN("BN:Lujin#2467"), true, "BN-Name erkannt")
eq(CL.IsBN("Helgwen Brannor"), false, "Charakter ist kein BN-Name")
eq(CL.Display("BN:Lujin#2467"), "Lujin", "Anzeige ohne Nummer")
eq(CL.Display("Helgwen Brannor"), "Helgwen Brannor", "Charakter unveraendert")
eq(CL.BNNameFromID(17), "BN:Lujin#2467", "Name aus Kennung")
eq(CL.BNFromAccountName("|Kq9|k"), "BN:Exclaime#1111", "Kontoname aus der Freundesliste")
eq(CL.BNID("BN:Exclaime#1111"), 23, "Kennung aus BattleTag")

-- eingehend: 13. Wert = Kennung
events.CHAT_MSG_BN_WHISPER("hi Pinky", "|Kq5|k", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 17)
local lines = CL.Lines("w:BN:Lujin#2467") or {}
eq(#lines, 1, "eingehende Nachricht im eigenen Reiter")
eq(lines[1] and lines[1].s, "BN:Lujin#2467", "Absender als BN-Name")
eq(fired[1] and fired[1][1], "CHAT_BN_WHISPER", "Hinweis fuer Benachrichtigung")
local open = false
for _, w in ipairs(CL.OpenWhispers()) do if w.name == "BN:Lujin#2467" then open = true end end
eq(open, true, "Fluester-Reiter offen")
-- ausgehend
eq(CL.BNSend("BN:Lujin#2467", "hallo zurueck"), true, "gesendet")
eq(sent[1] and sent[1][1], 17, "an die richtige Kennung")
CL.Send("whisper", "BN:Exclaime#1111", "huhu")
eq(sent[2] and sent[2][1], 23, "CL.Send nimmt bei BN-Namen Battle.net")
eq(#normal, 0, "kein normales Fluestern")
CL.Send("whisper", "Helgwen Brannor", "hey")
eq(normal[1] and normal[1][3], "Helgwen Brannor", "Charakter weiter normal")
events.CHAT_MSG_BN_WHISPER_INFORM("hallo zurueck", "|Kq5|k", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 17)
lines = CL.Lines("w:BN:Lujin#2467") or {}
eq(#lines, 2, "eigene Nachricht im Reiter")
eq(lines[2] and lines[2].o, 1, "als eigene markiert")
-- unbekannter Freund: Hinweis, nichts gesendet
eq(CL.BNSend("BN:Niemand#0000", "x"), false, "unbekannt: nicht gesendet")
eq(printed[#printed], "CHAT_BN_UNKNOWN", "Hinweis im Chat")
-- ohne C_BattleNet: alte Funktionen
_G.C_BattleNet = nil
_G.BNGetFriendInfo = function(i) local f = friends[i] return f.bnetAccountID, f.accountName, f.battleTag end
_G.BNGetFriendInfoByID = function(id) for _, f in ipairs(friends) do if f.bnetAccountID == id then return f.bnetAccountID, f.accountName, f.battleTag end end end
eq(CL.BNNameFromID(23), "BN:Exclaime#1111", "alte Funktion: Name aus Kennung")
print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
