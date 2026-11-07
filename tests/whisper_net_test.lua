-- Test des Fluester-Datennetzes: Sender (Core) <-> Senke (Dev) ueber eine nachgebaute Schnittstelle (texlua tests/whisper_net_test.lua)
local fails, n = 0, 0
local function eq(a, b, msg) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER: " .. msg .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")") end end

local clock, timers, queue, me = 0, {}, {}, "Alice Test"
_G.GetTime = function() return clock end
_G.time = function() return 1000000 + math.floor(clock) end
_G.date = os.date
_G.InCombatLockdown = function() return false end
_G.GetUnitName = function() return me end
_G.Enum = { SendAddonMessageResult = { Success = 0 } }
_G.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { t = clock + sec, fn = fn } end }
local online = { ["pinky freewood"] = true, ["dr freewood"] = true, ["alice test"] = true }
local sentTo = {}
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, text, ch, to)
        sentTo[to] = (sentTo[to] or 0) + 1
        if online[to:lower()] then queue[#queue + 1] = { to = to, from = me, text = text, prefix = prefix } end
        return 0
    end,
}

local handlers, events = {}, {}
local FW = { version = "test", db = {}, settings = {}, Print = function() end }
function FW:On(ev, fn) handlers[ev] = handlers[ev] or {}; table.insert(handlers[ev], fn) end
function FW:Fire(ev, ...) for _, fn in ipairs(handlers[ev] or {}) do fn(...) end end
function FW:RegisterEvent(ev, fn) events[ev] = events[ev] or {}; table.insert(events[ev], fn) end
_G.Freewood = FW

local keys = {}
for i = 1, 15 do keys[#keys + 1] = { key = "r" .. i, upd = i } end
FW.Codex = { Share = { Scan = function() return keys end, OwnRecord = function(k) return { k = k, data = string.rep("x", 90) } end } }
FW.Export = { Encode = function(kind, t)
    local s = kind .. ":"
    for _, r in ipairs(t.list) do s = s .. r.k .. "=" .. r.data .. ";" end
    if #s > 3000 then return nil end
    return s
end }

assert(loadfile("Core/Whisper.lua"))("Freewood-Core", FW)
assert(loadfile("Core/WhisperSend.lua"))("Freewood-Core", FW)
local NS = { Dev = {} }
assert(loadfile("../freewood-forever-dev/DevInbox.lua"))("Freewood-Dev", NS)
local W, Inbox = FW.Whisper, NS.Inbox

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

-- Sender-Seite: eigener Name fuer die Senke wird beim Zustellen gewechselt (me = Empfaenger)
FW.settings.whisperSend = nil
eq(W.Enabled(), true, "Standard: Senden an")
Run(0.25)
for _, fn in ipairs(events.PLAYER_LOGIN or {}) do fn() end
Run(400)
local st = Inbox.Stats()
eq(st.senders, 1, "Senke kennt einen Sender")
eq(Inbox.IsOwner(), false, "Alice ist kein Besitzer")
-- Senke ist nur aktiv, wenn der Besitzer-Charakter gerade 'me' ist; beim Zustellen wechselt me. Daten muessen angekommen sein:
eq(st.packets >= 3, true, "mehrere Pakete angekommen (" .. st.packets .. ")")
local total = 0
for _, e in ipairs(FreewoodInboxDB.entries) do total = total + #e.text end
eq(total > 15 * 90, true, "alle Datensaetze angekommen")
eq(FW.db.whisperSend.pos, 0, "Lauf abgeschlossen, Position zurueck")
eq(FW.db.whisperSend.nextRun > 1000000, true, "naechster Lauf gesetzt")
local firstPackets = st.packets
-- Erneuter Lauf: nichts doppelt (Dedupe)
FW.db.whisperSend.nextRun = 0
Run(400)
eq(Inbox.Stats().packets, firstPackets, "Wiederholung speichert nichts doppelt")

-- Stopp: Senke antwortet S, Sender pausiert
Inbox.SetStopped(true)
FW.db.whisperSend.nextRun = 0
FW.db.whisperSend.pos = 0
local before = Inbox.Stats().packets
Run(3700)
eq(Inbox.Stats().packets, before, "waehrend Stopp nichts gespeichert")
eq(FW.db.whisperSend.stopUntil > 1000000, true, "Sender pausiert nach Stopp")
-- nach Wiederfreigabe sendet er erst nach der Pause wieder
Inbox.SetStopped(false)
Run(3700)
eq(Inbox.Stats().packets, before, "Pause wird eingehalten")

-- Aus-Schalter
W.SetEnabled(false)
eq(select(2, W.Send("Pinky Freewood", "1", "H")), "aus", "H bei aus nicht gesendet")
eq(select(2, W.Send("Pinky Freewood", "1", "A")) ~= "aus", true, "Steuerart A geht immer")

-- Offline-Fallback: Pinky offline -> Dr Freewood
W.SetEnabled(true)
FW.db.whisperSend = nil
online["pinky freewood"] = false
Inbox.Clear()
timers = {}
for _, fn in ipairs(events.PLAYER_LOGIN or {}) do fn() end
Run(400)
eq(Inbox.Stats().packets >= 3, true, "Fallback auf Dr Freewood")

-- Limits
eq(Inbox.IsOwner(), false, "kein Besitzer als Alice")
me = "Dr Freewood"
eq(Inbox.IsOwner(), true, "Dr Freewood ist Besitzer")
me = "Alice Test"

print(string.format("%d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
