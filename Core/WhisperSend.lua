-- Freewood-Core: Codex-Daten per Fluestern an den Entwickler senden (unsichtbar, Standard an, Einstellung "Daten an den Entwickler senden").
-- Auslastungstest: es wird der GANZE eigene Codex-Stand gesendet (alle teilbaren Datensaetze, nur was der Codex ohnehin teilt:
-- keine Gildendaten, kein Gold, keine Taschen, keine Post, kein Chat, keine Namen anderer Spieler), danach alle 24 Stunden wieder.
-- Ablauf: Hallo (H) -> Antwort "bereit" (A) -> Datenstuecke (P) mit Quittung (K) je Stueck. Stopp (S) vom Empfaenger pausiert 24 Stunden.
-- Ist ein Empfaenger offline, wird die Systemzeile ausgeblendet (siehe Whisper.lua) und der naechste Empfaenger versucht.
-- Zustand: FreewoodDB.whisperSend = { pos, nextRun, stopUntil, offline = { [name] = bis } }.

local ADDON, FW = ...

local G = _G
local W = FW.Whisper
if not W then return end

local S = {}
FW.WhisperSend = S

local RECORDS_PER_PACKET = 6
local PIECE = 190            -- Zeichen je Flüsternachricht
local PIECE_GAP = 0.25       -- Sekunden zwischen zwei Teilen (ca. 4 je Sekunde)
local ACK_TIMEOUT = 30       -- Sekunden bis eine Quittung als verloren gilt
local RETRIES = 3
local OFFLINE_PAUSE = 600    -- Sekunden, so lange gilt ein Empfaenger als offline
local STOP_PAUSE = 86400     -- Sekunden Pause nach "Stopp"
local RERUN = 86400          -- Sekunden bis zum naechsten kompletten Lauf
local START_DELAY_MIN, START_DELAY_SPAN = 60, 120

local function Now() return G.time and G.time() or 0 end
local function Clock() return G.GetTime and G.GetTime() or 0 end

local function St()
    if not FW.db then return nil end
    FW.db.whisperSend = FW.db.whisperSend or {}
    local s = FW.db.whisperSend
    s.offline = s.offline or {}
    return s
end

local run = nil   -- laufender Durchgang: { list = {keys}, i = naechster Index, target, id, waiting, tries, packet = {pieces}, active }

local function SelfIs(name)
    local me = W.SelfName()
    return me ~= nil and me:lower() == name:lower()
end

local function PickTarget(st)
    local now = Now()
    for _, name in ipairs(W.TARGETS) do
        if not SelfIs(name) and (st.offline[name:lower()] or 0) <= now then return name end
    end
    return nil
end

local function Codex() return FW.Codex end

local function RecordKeys()
    local c = Codex()
    local share = c and c.Share
    if not (share and share.Scan and share.OwnRecord) then return nil end
    local ok, list = pcall(share.Scan, true)
    if not ok or type(list) ~= "table" then return nil end
    local keys = {}
    for _, e in ipairs(list) do if e.key then keys[#keys + 1] = e.key end end
    table.sort(keys)
    return keys
end

local function BuildPacket(keys, from)
    local share = Codex().Share
    local n = RECORDS_PER_PACKET
    while n >= 1 do
        local chunk, last = {}, from - 1
        for i = from, math.min(from + n - 1, #keys) do
            local ok, rec = pcall(share.OwnRecord, keys[i])
            if ok and rec then chunk[#chunk + 1] = rec end
            last = i
        end
        if #chunk == 0 then return nil, last end
        local text = FW.Export and FW.Export.Encode and FW.Export.Encode("codex", { list = chunk })
        if text then return text, last end
        n = math.floor(n / 2)
        if n < 1 then return nil, last end
    end
    return nil, from
end

local function Split(text)
    local out = {}
    for i = 1, #text, PIECE do out[#out + 1] = text:sub(i, i + PIECE - 1) end
    return out
end

local Step

-- Ein einziger Zeitgeber-Strang: jeder neue Aufruf von Later ersetzt den alten
local gen = 0
local function Later(sec)
    gen = gen + 1
    local my = gen
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(math.max(1, sec), function() if my == gen then Step() end end)
    end
end

local function Pause(seconds)
    S.pausedUntil = Clock() + seconds
    if run then run.waiting = nil; run.active = false; run.target = nil end
    Later(seconds + 1)
end

local function SendPiece(r, idx)
    if run ~= r or not r.packet then return end
    local n = #r.packet
    local last = idx == n
    -- "wartet auf Quittung" schon vor dem letzten Teil setzen: die Quittung kann vor dem naechsten Zeitgeber eintreffen
    if last then r.waiting = "K" end
    local ok, res = W.Send(r.target, string.format("%d|%d|%d|%s", r.id, idx, n, r.packet[idx]), "P")
    if not ok then
        if res == "aus" then run = nil return end
        Pause(OFFLINE_PAUSE)
        return
    end
    if not last then
        G.C_Timer.After(PIECE_GAP, function() SendPiece(r, idx + 1) end)
        return
    end
    local id, tries = r.id, r.tries
    G.C_Timer.After(ACK_TIMEOUT, function()
        if run == r and r.waiting == "K" and r.id == id and r.tries == tries then
            r.tries = r.tries + 1
            if r.tries > RETRIES then
                Pause(OFFLINE_PAUSE)
            else
                r.waiting = "S"
                SendPiece(r, 1)
            end
        end
    end)
end

local function SendNextPacket(r)
    local st = St()
    if not st then return end
    while true do
        if r.i > #r.keys then
            st.pos = 0
            st.nextRun = Now() + RERUN
            st.lastDone = Now()
            run = nil
            FW:Fire("WHISPER_SEND_DONE")
            return
        end
        local text, last = BuildPacket(r.keys, r.i)
        r.nextI = (last or r.i) + 1
        if text then
            r.id = (r.id or 0) + 1
            r.packet = Split(text)
            r.tries = 0
            r.waiting = "S"
            return SendPiece(r, 1)
        end
        r.i = r.nextI
    end
end

-- Haupttakt: prueft Bedingungen und startet oder setzt fort
function Step()
    local st = St()
    if not st or not W.Enabled() then return end
    if S.pausedUntil and Clock() < S.pausedUntil then return Later(S.pausedUntil - Clock() + 1) end
    if G.InCombatLockdown and G.InCombatLockdown() then return Later(30) end
    local now = Now()
    if (st.stopUntil or 0) > now then return Later(math.min(3600, st.stopUntil - now + 1)) end
    if (st.nextRun or 0) > now and not run then return Later(math.min(3600, st.nextRun - now + 1)) end
    if run and run.waiting then return Later(10) end
    local target = PickTarget(st)
    if not target then return Later(OFFLINE_PAUSE) end
    if not run then
        local keys = RecordKeys()
        if not keys or #keys == 0 then st.nextRun = now + 3600; return Later(3600) end
        run = { keys = keys, i = math.min((st.pos or 0) + 1, #keys), id = 0 }
    end
    if run.target ~= target then run.target = target; run.active = false end
    if not run.active then
        -- Hallo: ist der Empfaenger da und nimmt er an?
        run.waiting = "A"
        local r = run
        local ok = W.Send(target, "1", "H")
        G.C_Timer.After(15, function()
            if run == r and r.waiting == "A" then
                r.waiting = nil
                st.offline[target:lower()] = Now() + OFFLINE_PAUSE
                r.target = nil
                Step()
            end
        end)
        return Later(20)
    end
    SendNextPacket(run)
    Later(15)
end

-- Antworten des Empfaengers
FW:On("WHISPER_DATA", function(sender, kind, body)
    local st = St()
    if not st or type(sender) ~= "string" then return end
    local isTarget = false
    for _, t in ipairs(W.TARGETS) do if t:lower() == sender:lower() then isTarget = true end end
    if not isTarget then return end
    if kind == "S" then
        st.stopUntil = Now() + STOP_PAUSE
        run = nil
    elseif kind == "A" then
        if run and run.waiting == "A" then
            run.waiting = nil
            run.active = true
            st.offline[sender:lower()] = nil
            Step()
        end
    elseif kind == "K" then
        local id = tonumber(body)
        if run and run.waiting == "K" and id == run.id then
            run.waiting = nil
            run.i = run.nextI or (run.i + RECORDS_PER_PACKET)
            st.pos = run.i - 1
            FW:Fire("WHISPER_SEND_PROGRESS", st.pos, #run.keys)
            if G.C_Timer then G.C_Timer.After(0.5, Step) end
        end
    end
end)

FW:On("WHISPER_OFFLINE", function(nameLower)
    local st = St()
    if not st then return end
    st.offline[nameLower] = Now() + OFFLINE_PAUSE
    if run then run.waiting = nil; run.active = false; run.target = nil end
    if G.C_Timer then G.C_Timer.After(1, Step) end
end)

function S.Status()
    local st = St() or {}
    return { pos = st.pos or 0, total = run and #run.keys or 0, stopUntil = st.stopUntil or 0, nextRun = st.nextRun or 0,
        lastDone = st.lastDone or 0, target = run and run.target, running = run ~= nil }
end

-- nach dem Anmelden mit Verzoegerung starten
FW:RegisterEvent("PLAYER_LOGIN", function()
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(START_DELAY_MIN + math.random() * START_DELAY_SPAN, Step)
    end
end)

-- Einstellung
local UI = FW.UI
if UI and UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("whisper-send", {
        category = "general",
        order = 61,
        height = 70,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.SETTINGS_WHISPERSEND_TITLE or "Developer data")
            stack:Add(UI.CreateCheckbox(f, L.SETTINGS_WHISPERSEND or "Send data to the developer (invisible, Codex data only)",
                function() return W.Enabled() end,
                function(v) W.SetEnabled(v) end), { fit = true })
            return f
        end,
    })
end
