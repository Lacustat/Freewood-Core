-- Freewood-Core: Daten per Fluestern (Addon-Nachricht, unsichtbar).
-- Im Spiel gemessen (7. November 2026): WHISPER-Addon-Nachrichten kommen an (auch von fremden Spielern), erscheinen nicht im Chat,
-- 100 Stueck an einem Stueck ohne Drosselung (an sich selbst). Der Name muss der volle Name sein ("Pinky Freewood").
-- Ist der Empfaenger offline, steht beim Sender sonst die Systemzeile "Momentan ist kein Spieler mit dem Namen ... online";
-- sie wird hier ausgeblendet (Filter) und als "offline" gemeldet (Ereignis WHISPER_OFFLINE).
--
-- Nachrichten: "<Art>|<Text>". Arten: T Test, H Hallo, A Antwort "bereit", K Quittung, S Stopp, P Datenstueck.
-- Senden der Arten H und P nur bei eingeschalteter Einstellung settings.whisperSend (Standard AN, "Daten an den Entwickler senden").
-- Steuerarten (T, A, K, S) gehen immer. Protokoll: FreewoodDB.whisperLog (letzte 100 Eintraege) fuer den Dev-Reiter "Fluestertest".

local ADDON, FW = ...

local G = _G
local W = {}
FW.Whisper = W

local PREFIX = "FWWH1"
local MAX_LOG = 100
local MAX_LEN = 240

W.PREFIX = PREFIX
W.TARGETS = { "Pinky Freewood", "Dr Freewood" }   -- Empfaenger in dieser Reihenfolge
W.TEST_TARGET = "Dr Freewood"
W.last = nil   -- letzte Sendung { name = klein, t = GetTime }

local function Secret(v)
    return G.issecretvalue and G.issecretvalue(v) or false
end

local function Now() return G.time and G.time() or 0 end

local function Store()
    if not FW.db then return nil end
    FW.db.whisperLog = FW.db.whisperLog or {}
    return FW.db.whisperLog
end

local function ResultName(res)
    if type(res) == "number" and G.Enum and G.Enum.SendAddonMessageResult then
        for k, v in pairs(G.Enum.SendAddonMessageResult) do
            if v == res then return k end
        end
    end
    return tostring(res)
end

-- Protokoll: { t = Zeit, dir = "out"|"in", peer = Name, text = Text, res = Ergebnis }
-- Datenstuecke (P) und Quittungen werden nicht einzeln protokolliert (zu viele), nur Test, Hallo, Antwort, Stopp.
function W.Log(dir, peer, text, res)
    local s = Store()
    if not s then return end
    s[#s + 1] = { t = Now(), dir = dir, peer = tostring(peer or "?"), text = (tostring(text or ""):gsub("|", "/")):sub(1, 60), res = res or "" }
    while #s > MAX_LOG do table.remove(s, 1) end
    FW:Fire("WHISPER_LOG")
end

function W.GetLog() return Store() or {} end

function W.ClearLog()
    if FW.db then FW.db.whisperLog = {} end
    FW:Fire("WHISPER_LOG")
end

-- Einstellung "Daten an den Entwickler senden" (Standard AN)
function W.Enabled()
    return not (FW.settings and FW.settings.whisperSend == false)
end

function W.SetEnabled(on)
    if FW.settings then FW.settings.whisperSend = on and true or false end
end

-- Eigener voller Name (Vor- und Nachname), soweit das Spiel ihn liefert
function W.SelfName()
    local n = G.GetUnitName and G.GetUnitName("player", true)
    if type(n) == "string" and not Secret(n) and n:find(" ") then return n end
    local first, second = G.UnitFullName and G.UnitFullName("player")
    if type(first) == "string" and not Secret(first) then
        if type(second) == "string" and not Secret(second) and second ~= "" then return first .. " " .. second end
        return first
    end
    return nil
end

local function CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if name == "" or #name > 40 or name:find("[|%c]") then return nil end
    return name
end

local QUIET = { P = true, K = true, L = true, M = true }

-- Einzelne Nachricht senden. Rueckgabe: ok, Ergebnisname. Art T/A/K/S immer erlaubt, H und P nur bei eingeschalteter Einstellung.
function W.Send(name, text, kind)
    name = CleanName(name)
    if not name then return false, "Name" end
    if type(text) ~= "string" or text == "" or #text > MAX_LEN then return false, "Text" end
    kind = kind or "D"
    if (kind == "H" or kind == "P" or kind == "D") and not W.Enabled() then return false, "aus" end
    local api = G.C_ChatInfo
    if not (api and api.SendAddonMessage) then return false, "keine Schnittstelle" end
    W.last = { name = name:lower(), t = G.GetTime and G.GetTime() or 0 }
    local ok, res = pcall(api.SendAddonMessage, PREFIX, kind .. "|" .. text, "WHISPER", name)
    local rname = ok and ResultName(res) or "Fehler"
    if not QUIET[kind] then W.Log("out", name, kind .. "|" .. text, rname) end
    return ok and (res == 0 or res == nil or rname == "Success"), rname
end

-- Ein Test, genau eine Nachricht je Aufruf
function W.SendTest(name)
    local me = W.SelfName() or "?"
    return W.Send(name, "test von " .. me .. " " .. (G.date and G.date("%H:%M:%S") or ""), "T")
end

------------------------------------------------------------------------
-- Standort des Fluesterpartners (nur zwischen Spielern mit Freewood)
-- Art L = Anfrage (Text "1"), Art M = Antwort "mapID|x|y|Gebiet" (x, y in Tausendstel). Geantwortet wird nur an Spieler, denen ich
-- selbst gefluestert habe, sowie Gilde und Gruppe, und nur bei eingeschalteter Einstellung settings.shareLocation (Standard AN).
------------------------------------------------------------------------

W.loc = {}      -- loc[klein] = { m, x, y, zone, t }
W.talked = {}   -- klein -> true: ich habe diesem Spieler gefluestert
local LOC_GAP, LOC_TTL = 20, 120

local function Key(name) return type(name) == "string" and name:lower() or "" end
local function Short(name) return type(name) == "string" and (name:match("^([^%-]+)") or name) or "" end

function W.NoteTalked(name) if type(name) == "string" and name ~= "" then W.talked[Key(Short(name))] = true end end

local function InGroupOrGuild(name)
    local short = Key(Short(name))
    local CL = FW.ChatLog
    if CL and CL.guild then
        for _, g in ipairs(CL.guild) do if Key(Short(g.name)) == short then return true end end
    end
    for i = 1, 4 do
        local u = "party" .. i
        if G.UnitExists and G.UnitExists(u) and G.UnitName and Key(Short(G.UnitName(u))) == short then return true end
    end
    local n = (G.IsInRaid and G.IsInRaid() and G.GetNumGroupMembers and G.GetNumGroupMembers()) or 0
    for i = 1, n do
        local u = "raid" .. i
        if G.UnitExists and G.UnitExists(u) and G.UnitName and Key(Short(G.UnitName(u))) == short then return true end
    end
    return false
end

function W.CanShareWith(name)
    if FW.settings and FW.settings.shareLocation == false then return false end
    return W.talked[Key(Short(name))] == true or InGroupOrGuild(name)
end

-- Eigene Position: mapID, x, y (0..1), Gebietsname; nil in Instanzen oder bei geheimen Werten
function W.MyLocation()
    local CM = G.C_Map
    if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition) then return nil end
    local ok, m = pcall(CM.GetBestMapForUnit, "player")
    if not ok or type(m) ~= "number" or Secret(m) then return nil end
    local ok2, pos = pcall(CM.GetPlayerMapPosition, m, "player")
    if not ok2 or not pos or not pos.GetXY then return nil end
    local ok3, x, y = pcall(pos.GetXY, pos)
    if not ok3 or type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    local zone
    if CM.GetMapInfo then
        local ok4, info = pcall(CM.GetMapInfo, m)
        if ok4 and type(info) == "table" and type(info.name) == "string" and not Secret(info.name) then zone = info.name end
    end
    return m, x, y, zone or (G.GetZoneText and G.GetZoneText()) or ""
end

-- Karte zu einem Gebietsnamen (aus Gilden- oder Freundesliste): sucht in allen Karten unter dem Kosmos (946) und merkt sich die Namen.
-- Gleicher Name auf mehreren Karten: Gebiet (Zone) vor Kontinent oder Stadtteil. Rueckgabe: mapID oder nil.
local zoneMaps
local function BuildZoneMaps()
    zoneMaps = {}
    local CM = G.C_Map
    if not (CM and CM.GetMapChildrenInfo) then return end
    for _, root in ipairs({ 946, 947 }) do
        local ok, list = pcall(CM.GetMapChildrenInfo, root, nil, true)
        if ok and type(list) == "table" then
            for _, info in ipairs(list) do
                local nm = type(info) == "table" and info.name
                if type(nm) == "string" and not Secret(nm) and type(info.mapID) == "number" then
                    local k = nm:lower()
                    local old = zoneMaps[k]
                    local isZone = G.Enum and G.Enum.UIMapType and info.mapType == G.Enum.UIMapType.Zone
                    if not old or (isZone and not old.zone) then zoneMaps[k] = { m = info.mapID, zone = isZone } end
                end
            end
        end
    end
end
function W.ZoneMapID(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not zoneMaps then BuildZoneMaps() end
    local e = zoneMaps[name:lower()]
    return e and e.m or nil
end
function W.ResetZoneMaps() zoneMaps = nil end

-- Anfrage an einen Spieler (hoechstens alle LOC_GAP Sekunden je Name). Rueckgabe: true, wenn gesendet.
local lastAsk = {}
function W.RequestLocation(name)
    local k = Key(name)
    if k == "" then return false end
    local now = G.GetTime and G.GetTime() or 0
    if lastAsk[k] and now - lastAsk[k] < LOC_GAP then return false end
    lastAsk[k] = now
    return (W.Send(name, "1", "L")) and true or false
end

-- Letzte bekannte Antwort { m, x, y, zone, t } oder nil (aelter als LOC_TTL zaehlt nicht mehr)
function W.GetLocation(name)
    local r = W.loc[Key(Short(name))] or W.loc[Key(name)]
    if not r then return nil end
    local now = G.GetTime and G.GetTime() or 0
    if now - r.t > LOC_TTL then return nil end
    return r
end

local function OnLocRequest(sender)
    if not W.CanShareWith(sender) then return end
    local m, x, y, zone = W.MyLocation()
    if not m then return end
    local body = string.format("%d|%d|%d|%s", m, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5), (tostring(zone):gsub("|", "/")))
    W.Send(sender, body, "M")
end

local function OnLocReply(sender, body)
    local m, x, y, zone = tostring(body):match("^(%d+)|(%d+)|(%d+)|(.*)$")
    m, x, y = tonumber(m), tonumber(x), tonumber(y)
    if not (m and x and y) or x > 1000 or y > 1000 then return end
    local rec = { m = m, x = x / 1000, y = y / 1000, zone = zone or "", t = G.GetTime and G.GetTime() or 0 }
    W.loc[Key(Short(sender))] = rec
    FW:Fire("WHISPER_LOCATION", sender, rec)
end

-- Empfang
local function OnAddon(prefix, text, channel, sender)
    if prefix ~= PREFIX or Secret(text) or Secret(sender) then return end
    if channel ~= "WHISPER" then return end
    if type(text) ~= "string" or #text > 255 or type(sender) ~= "string" then return end
    local kind, body = text:match("^(%a)|(.*)$")
    if kind == "T" then
        W.Log("in", sender, text, "")
    elseif kind == "L" then
        pcall(OnLocRequest, sender)
    elseif kind == "M" then
        pcall(OnLocReply, sender, body)
    elseif kind then
        FW:Fire("WHISPER_DATA", sender, kind, body)
    end
end

-- "Momentan ist kein Spieler mit dem Namen 'X' online." nach einer Sendung an X ausblenden und als offline melden
local function SystemFilter(_, _, msg, ...)
    if type(msg) ~= "string" or Secret(msg) or not W.last then return false end
    local now = G.GetTime and G.GetTime() or 0
    if now - W.last.t > 6 then return false end
    if msg:lower():find(W.last.name, 1, true) then
        FW:Fire("WHISPER_OFFLINE", W.last.name)
        return true
    end
    return false
end
if G.ChatFrame_AddMessageEventFilter then
    pcall(G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", SystemFilter)
end

-- Der Testlauf ist beendet (Ziel erreicht). Zum erneuten Einschalten: W.AUTO_TEST = true.
W.AUTO_TEST = false

local function AutoTest()
    local db = FW.db
    if not db or db.whisperTestDone then return end
    if G.InCombatLockdown and G.InCombatLockdown() then
        if G.C_Timer then G.C_Timer.After(30, AutoTest) end
        return
    end
    local me = W.SelfName()
    db.whisperTestDone = { t = Now(), version = FW.version or "?" }
    if me and me:lower() == W.TEST_TARGET:lower() then return end
    local ok, res = W.SendTest(W.TEST_TARGET)
    db.whisperTestDone.res = tostring(res)
end

local function StartAutoTest()
    if not W.AUTO_TEST then return end
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(45 + math.random() * 105, AutoTest)
    end
end

local function Register()
    local api = G.C_ChatInfo
    if api and api.RegisterAddonMessagePrefix then pcall(api.RegisterAddonMessagePrefix, PREFIX)
    elseif G.RegisterAddonMessagePrefix then pcall(G.RegisterAddonMessagePrefix, PREFIX) end
end
Register()
FW:RegisterEvent("PLAYER_LOGIN", Register)
FW:RegisterEvent("PLAYER_LOGIN", StartAutoTest)
FW:RegisterEvent("CHAT_MSG_ADDON", OnAddon)
