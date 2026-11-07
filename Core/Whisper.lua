-- Freewood-Core: Daten per Fluestern (Addon-Nachricht, unsichtbar). VORBEREITET, im Spiel AUS (settings.whisperShare = false).
-- Im Spiel gemessen (7. November 2026): WHISPER-Addon-Nachrichten kommen an, erscheinen nicht im Chat, 100 Stueck an einem
-- Stueck ohne Drosselung (an sich selbst). Der Name muss der volle Name sein ("Pinky Freewood"). Ist der Empfaenger offline,
-- steht beim Sender die Systemzeile "Momentan ist kein Spieler mit dem Namen ... online".
--
-- Testlauf (0.13.1, ab 0.13.2 aus, siehe W.AUTO_TEST): Jeder Spieler mit diesem Core schickt EINMAL (je Account) eine Testnachricht an "Dr Freewood", 45 bis 150 Sekunden nach
-- dem Anmelden, nicht im Kampf. Das Protokoll liegt im Dev-Reiter "Fluestertest". Echte Daten bleiben aus (whisperShare = false).
--
-- Testnachrichten ("T|...") werden immer angenommen und protokolliert. Alles andere wird nur verarbeitet, wenn der Schalter an ist,
-- und nur von Spielern, die als bereit gemeldet sind (kommt spaeter; Whisper.Ready).
-- Protokoll: FreewoodDB.whisperLog (letzte 100 Eintraege) fuer den Dev-Reiter "Fluestertest".

local ADDON, FW = ...

local G = _G
local W = {}
FW.Whisper = W

local PREFIX = "FWWH1"
local MAX_LOG = 100
local MAX_LEN = 240

W.PREFIX = PREFIX
W.ready = {}   -- ready[nameLower] = Zeitpunkt, bis zu dem der Spieler als bereit gilt (spaeter)

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
function W.Log(dir, peer, text, res)
    local s = Store()
    if not s then return end
    s[#s + 1] = { t = Now(), dir = dir, peer = tostring(peer or "?"), text = (tostring(text or ""):gsub("|", "/")):sub(1, 60), res = res }
    while #s > MAX_LOG do table.remove(s, 1) end
    FW:Fire("WHISPER_LOG")
end

function W.GetLog()
    return Store() or {}
end

function W.ClearLog()
    if FW.db then FW.db.whisperLog = {} end
    FW:Fire("WHISPER_LOG")
end

function W.Armed()
    return FW.settings ~= nil and FW.settings.whisperShare == true
end

function W.SetArmed(on)
    if FW.settings then FW.settings.whisperShare = on and true or false end
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

-- Einzelne Nachricht senden. Rueckgabe: ok, Ergebnisname. kind "T" = Test (immer erlaubt), sonst nur bei eingeschaltetem Schalter.
function W.Send(name, text, kind)
    name = CleanName(name)
    if not name then return false, "Name" end
    if type(text) ~= "string" or text == "" or #text > MAX_LEN then return false, "Text" end
    if kind ~= "T" and not W.Armed() then return false, "aus" end
    local api = G.C_ChatInfo
    if not (api and api.SendAddonMessage) then return false, "keine Schnittstelle" end
    local ok, res = pcall(api.SendAddonMessage, PREFIX, (kind or "D") .. "|" .. text, "WHISPER", name)
    local rname = ok and ResultName(res) or "Fehler"
    W.Log("out", name, (kind or "D") .. "|" .. text, rname)
    return ok and (res == 0 or res == nil or rname == "Success"), rname
end

-- Ein Test, genau eine Nachricht je Aufruf
function W.SendTest(name)
    local me = W.SelfName() or "?"
    return W.Send(name, "test von " .. me .. " " .. (G.date and G.date("%H:%M:%S") or ""), "T")
end

-- Empfang
local function OnAddon(prefix, text, channel, sender)
    if prefix ~= PREFIX or Secret(text) or Secret(sender) then return end
    if channel ~= "WHISPER" then return end
    if type(text) ~= "string" or #text > 255 then return end
    local kind, body = text:match("^(%a)|(.*)$")
    if kind == "T" then
        W.Log("in", sender, text, "")
    elseif kind and W.Armed() then
        FW:Fire("WHISPER_DATA", sender, kind, body)
    end
end

-- einmaliger Testlauf an den Besitzer
W.TEST_TARGET = "Dr Freewood"

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

-- Der Testlauf ist beendet (Ziel erreicht: Test von einem fremden Spieler kam an). Zum erneuten Einschalten: W.AUTO_TEST = true.
W.AUTO_TEST = false

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
