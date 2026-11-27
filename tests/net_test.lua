-- Test des weltweiten Netzes (Core 0.69.0): Admin-Liste, Mitgliederliste des verborgenen Kanals, Vorrang der Admins, Delta an den Posteingang
-- texlua tests/net_test.lua
local fails, n = 0, 0
local function eq(a, b, msg) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. msg .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

local clock, timers, queue, me = 0, {}, {}, "Alice Test"
_G.GetTime = function() return clock end
_G.time = function() return 1000000 + math.floor(clock) end
_G.date = os.date
_G.InCombatLockdown = function() return false end
_G.IsInInstance = function() return false end
_G.GetUnitName = function() return me end
_G.GetNormalizedRealmName = function() return "Forever" end
_G.Enum = { SendAddonMessageResult = { Success = 0 } }
_G.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { t = clock + sec, fn = fn } end }
local online = { ["pinky freewood"] = true, ["reddy freewood"] = true, ["alice test"] = true }
local sentTo = {}
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, text, ch, to)
        sentTo[to] = (sentTo[to] or 0) + 1
        if online[to:lower()] then queue[#queue + 1] = { to = to, from = me, text = text, prefix = prefix } end
        return 0
    end,
}
local joined, listed = false, 0
_G.GetChannelName = function(name) return (joined and name == "FreewoodNet") and 7 or 0 end
_G.JoinChannelByName = function(name) joined = true end
_G.LeaveChannelByName = function() joined = false end
_G.ListChannelByName = function(id) listed = listed + 1 end
local removed = 0
_G.NUM_CHAT_WINDOWS = 2
_G.ChatFrame1, _G.ChatFrame2 = {}, {}
_G.ChatFrame_RemoveChannel = function() removed = removed + 1 end

local handlers, events = {}, {}
local FW = { version = "test", db = {}, settings = {}, Print = function() end }
function FW:On(ev, fn) handlers[ev] = handlers[ev] or {}; table.insert(handlers[ev], fn) end
function FW:Fire(ev, ...) for _, fn in ipairs(handlers[ev] or {}) do fn(...) end end
function FW:RegisterEvent(ev, fn) events[ev] = events[ev] or {}; table.insert(events[ev], fn) end
_G.Freewood = FW
FW.Channels = { ParseNames = function(text)
    local out = {}
    for part in text:gmatch("[^,]+") do out[#out + 1] = (part:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%*", "")) end
    return out
end }

local keys = {}
for i = 1, 8 do keys[#keys + 1] = { key = "r" .. i, upd = i } end
FW.Codex = { Share = { Scan = function() return keys end, OwnRecord = function(k) return { k = k, data = string.rep("x", 90) } end } }
FW.Export = { Encode = function(kind, t)
    local s = kind .. ":"
    for _, r in ipairs(t.list) do s = s .. r.k .. "=" .. r.data .. ";" end
    return s
end }

assert(loadfile("Core/Whisper.lua"))("Freewood-Core", FW)
assert(loadfile("Core/Net.lua"))("Freewood-Core", FW)
assert(loadfile("Core/WhisperSend.lua"))("Freewood-Core", FW)
local NS = { Dev = {} }
assert(loadfile("../freewood-forever-dev/DevInbox.lua"))("Freewood-Dev", NS)
local W, Net, Inbox = FW.Whisper, FW.Net, NS.Inbox

local function Pump()
    while #queue > 0 do
        local m = table.remove(queue, 1)
        local keep = me
        me = m.to
        for _, fn in ipairs(events.CHAT_MSG_ADDON or {}) do fn(m.prefix, m.text, "WHISPER", m.from) end
        me = keep
    end
end
local function Run(seconds)
    local stop = clock + seconds
    while clock < stop do
        clock = clock + 0.25
        local due = {}
        for i = #timers, 1, -1 do if timers[i].t <= clock then table.insert(due, 1, table.remove(timers, i)) end end
        for _, tm in ipairs(due) do tm.fn() end
        Pump()
    end
end

-- Admin-Liste
eq(#Net.Admins(), 8, "8 Admins")
eq(W.TARGETS[1], "Pinky Freewood", "Empfaenger = Admin-Liste, Pinky zuerst")
eq(#W.TARGETS, 8, "alle Admins als Empfaenger")
eq(Net.IsAdmin("lujinja steel"), true, "Gross/klein egal")
eq(Net.IsAdmin("Aroki Steel-Forever"), true, "Realm-Anhang egal")
eq(Net.IsAdmin("Pinky Silberrücken"), true, "Umlaut")
eq(Net.IsAdmin("Bob Test"), false, "kein Admin")
Net.ADMINS["Forever"] = { "Realm Admin" }
eq(Net.Admins()[1], "Realm Admin", "Realm-Liste vor *")
eq(#Net.Admins(), 9, "Realm + *")
Net.ADMINS["Forever"] = nil

-- ohne Liste: unbekannt
eq(Net.Known(), false, "keine Liste")
eq(Net.Online("Pinky Freewood"), nil, "online unbekannt")

-- Beitreten, aus dem Chat entfernen
eq(Net.Enabled(), true, "Standard an")
Net.Join()
eq(joined, true, "Kanal beigetreten")
eq(removed >= 2, true, "aus den Chatfenstern entfernt")
Run(10)
eq(Net.status, "ok", "Status ok")

-- Liste in zwei Teilen
local adminOnline = {}
FW:On("NET_ADMIN_ONLINE", function(name) adminOnline[#adminOnline + 1] = name end)
eq(Net.Refresh(), true, "Abfrage gestartet")
eq(listed >= 1, true, "ListChannelByName aufgerufen")
for _, fn in ipairs(events.CHAT_MSG_CHANNEL_LIST) do fn("Bob Test, Reddy Freewood*", nil, nil, nil, nil, nil, nil, 7, "7. FreewoodNet") end
for _, fn in ipairs(events.CHAT_MSG_CHANNEL_LIST) do fn("Alice Test, Carl Test", nil, nil, nil, nil, nil, nil, 7, "7. FreewoodNet") end
for _, fn in ipairs(events.CHAT_MSG_CHANNEL_LIST) do fn("Fremd Kanal", nil, nil, nil, nil, nil, nil, 3, "3. Handel") end
Run(8)
eq(Net.Known(), true, "Liste gueltig")
eq(Net.Count(), 4, "vier Spieler (fremder Kanal nicht)")
eq(Net.Online("reddy freewood"), true, "Reddy online")
eq(Net.Online("Pinky Freewood"), false, "Pinky nicht in der Liste")
eq(#adminOnline, 1, "ein Admin neu online gemeldet")
eq(adminOnline[1], "Reddy Freewood", "Reddy gemeldet")
local peers = Net.Peers()
eq(#peers, 2, "Partner ohne mich und ohne Admins")
eq(peers[1] .. "," .. peers[2], "Bob Test,Carl Test", "Partnernamen")
-- gleiche Liste erneut: keine neue Meldung
Net.SetRoster({ "Bob Test", "Reddy Freewood", "Alice Test" })
eq(#adminOnline, 1, "keine doppelte Meldung")

-- Vorrang: Pinky waere per Fluestern erreichbar, steht aber nicht in der Liste -> Daten gehen an Reddy
FW.WhisperSend.Kick()
Run(400)
eq(sentTo["Pinky Freewood"], nil, "nichts an Pinky (nicht in der Liste)")
eq((sentTo["Reddy Freewood"] or 0) > 0, true, "Daten an Reddy")
local st = Inbox.Stats()
eq(st.packets >= 2, true, "im Posteingang angekommen (" .. st.packets .. ")")
eq(FW.db.whisperSend.sentUpd, 8, "Stand bestaetigt")

-- Pinky kommt online: Meldung, nach 1 bis 10 Minuten Delta an Pinky (Vorrang 1)
keys[#keys + 1] = { key = "r9", upd = 9 }
Net.SetRoster({ "Bob Test", "Reddy Freewood", "Alice Test", "Pinky Freewood" })
eq(adminOnline[#adminOnline], "Pinky Freewood", "Pinky gemeldet")
local before = Inbox.Stats().packets
Run(30)
eq(sentTo["Pinky Freewood"], nil, "nicht sofort")
Run(700)
eq((sentTo["Pinky Freewood"] or 0) > 0, true, "Delta an Pinky")
eq(Inbox.Stats().packets, before + 1, "genau ein neues Paket")
eq(FW.db.whisperSend.sentUpd, 9, "Stand nach Delta")

-- keiner der Admins online -> keine Sendung
Net.SetRoster({ "Bob Test", "Alice Test" })
keys[#keys + 1] = { key = "r10", upd = 10 }
FW.db.whisperSend.nextRun = 0
local p0, r0 = sentTo["Pinky Freewood"], sentTo["Reddy Freewood"]
FW.WhisperSend.Kick()
Run(300)
eq(sentTo["Pinky Freewood"], p0, "Pinky offline laut Liste")
eq(sentTo["Reddy Freewood"], r0, "Reddy offline laut Liste")

-- abschalten: Kanal verlassen, Liste vergessen
Net.SetEnabled(false)
eq(joined, false, "Kanal verlassen")
eq(Net.Known(), false, "Liste vergessen")
eq(#Net.Peers(), 0, "keine Partner")
eq(FW.settings.netShare, false, "Einstellung gespeichert")
-- Namen nicht in der SavedVariable
local function HasName(t, depth)
    if depth > 6 then return false end
    for k, v in pairs(t) do
        if (type(k) == "string" and k:find("Bob Test")) or (type(v) == "string" and v:find("Bob Test")) then return true end
        if type(v) == "table" and HasName(v, depth + 1) then return true end
    end
    return false
end
eq(HasName(FW.db, 0), false, "keine Spielernamen gespeichert")

print(string.format("net_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
