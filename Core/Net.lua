-- Freewood-Core: weltweites Datennetz (Net)
--
-- Zweck: andere Freewood-Spieler finden, ohne dass etwas im Chat erscheint.
--   * Verborgener Kanal "FreewoodNet": dient NUR der Mitgliederliste (wer ist online). Im Kanal wird nie geschrieben
--     (Kanal-Addon-Nachrichten kommen im Spiel nicht an, F-21). Der Kanal wird aus allen Chatfenstern entfernt.
--   * Der Datentausch selbst laeuft ueber unsichtbare WHISPER-Addon-Nachrichten (Codex: CodexSync, Entwickler: WhisperSend).
--   * Eigene Kanaele sind je Fraktion getrennt: die Liste enthaelt nur Spieler der eigenen Fraktion.
--   * Namen werden nur im Speicher gehalten (nicht in der SavedVariable) und nach 15 Minuten ohne neue Liste verworfen.
--   * Einstellung settings.netShare (Standard AN): "Daten mit anderen Freewood-Spielern tauschen (weltweit)".
--
-- Admin-Charaktere (N.ADMINS): bekommen die Daten immer zuerst (WhisperSend, Posteingang FreewoodInboxDB im Dev-Modul).
-- Die Liste gilt je Realm; "*" gilt auf allen Realms. Dieselbe Liste ist die Eigentuemer-Liste des Codex (CodexOwners.lua).
--
-- Ereignisse: NET_ROSTER (Liste neu), NET_ADMIN_ONLINE (Name) wenn ein Admin neu in der Liste steht.
-- Noch nicht im Spiel geprueft: Mitgliederliste eines eigenen Kanals (ListChannelByName) auf Forever.

local ADDON, FW = ...

local G = _G
local N = {}
FW.Net = N

N.CHANNEL = "FreewoodNet"
N.ROSTER_EVERY = 300      -- Sekunden zwischen zwei Abfragen der Mitgliederliste
N.ROSTER_TTL = 900        -- so lange gilt eine Liste
N.COLLECT = 3             -- Sekunden, in denen Teile einer Liste gesammelt werden

-- Admin-Charaktere je Realm (Vor- und Nachname, genau wie im Spiel). Reihenfolge = Vorrang.
N.ADMINS = {
    ["*"] = {
        "Pinky Freewood",
        "Pinky Silberrücken",
        "Aroki Freewood",
        "Dr Freewood",
        "Greeny Freewood",
        "Reddy Freewood",
        "Aroki Steel",
        "Lujinja Steel",
    },
}

local function Secret(v) return G.issecretvalue and G.issecretvalue(v) or false end
local function Clock() return G.GetTime and G.GetTime() or 0 end

-- Vergleichsschluessel: klein, ohne Realm-Anhang ("-Realm") und ohne doppelte Leerzeichen
function N.Key(name)
    if type(name) ~= "string" or Secret(name) then return "" end
    local core = name:match("^([^%-]+)") or name
    core = core:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return core:lower()
end
local Key = N.Key

local function RealmName()
    local r = (G.GetNormalizedRealmName and G.GetNormalizedRealmName()) or (G.GetRealmName and G.GetRealmName())
    if type(r) ~= "string" or Secret(r) then return nil end
    return r
end

-- Admins fuer den aktuellen Realm: erst die des Realms, dann "*" (ohne doppelte)
function N.Admins()
    local out, seen = {}, {}
    local function Add(list)
        for _, n in ipairs(list or {}) do
            local k = Key(n)
            if k ~= "" and not seen[k] then seen[k] = true; out[#out + 1] = n end
        end
    end
    local realm = RealmName()
    if realm then
        Add(N.ADMINS[realm])
        Add(N.ADMINS[realm:gsub("%s", "")])
    end
    Add(N.ADMINS["*"])
    return out
end

function N.IsAdmin(name)
    local k = Key(name)
    if k == "" then return false end
    for _, n in ipairs(N.Admins()) do if Key(n) == k then return true end end
    return false
end

local function SelfName()
    local W = FW.Whisper
    return W and W.SelfName and W.SelfName() or (G.UnitName and G.UnitName("player"))
end

function N.SelfIsAdmin() return N.IsAdmin(SelfName()) end

function N.Enabled() return not (FW.settings and FW.settings.netShare == false) end

-- Empfaengerliste des Entwickler-Netzes = Admin-Liste
local function ApplyTargets()
    if FW.Whisper then FW.Whisper.TARGETS = N.Admins() end
end
ApplyTargets()

------------------------------------------------------------------------
-- Verborgener Kanal

local function ChannelId()
    if type(G.GetChannelName) ~= "function" then return nil end
    local ok, id = pcall(G.GetChannelName, N.CHANNEL)
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end
N.ChannelId = ChannelId

local function HideFromChat()
    if type(G.ChatFrame_RemoveChannel) ~= "function" then return end
    for i = 1, (G.NUM_CHAT_WINDOWS or 10) do
        local frame = G["ChatFrame" .. i]
        if frame then pcall(G.ChatFrame_RemoveChannel, frame, N.CHANNEL) end
    end
end

N.status = "off"

function N.Join()
    if not N.Enabled() then
        if ChannelId() and type(G.LeaveChannelByName) == "function" then pcall(G.LeaveChannelByName, N.CHANNEL) end
        N.status = "off"
        N.roster, N.rosterAt = {}, 0
        return false
    end
    if ChannelId() then
        N.status = "ok"
        HideFromChat()
        return true
    end
    if type(G.JoinChannelByName) ~= "function" then N.status = "unavailable" return false end
    if not pcall(G.JoinChannelByName, N.CHANNEL) then N.status = "failed" return false end
    HideFromChat()
    N.status = "joining"
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(3, function()
            HideFromChat()
            N.status = ChannelId() and "ok" or "failed"
            if N.status == "ok" then G.C_Timer.After(5, function() N.Refresh() end) end
        end)
    end
    return true
end

function N.SetEnabled(on)
    if FW.settings then FW.settings.netShare = on and true or false end
    N.Join()
    FW:Fire("NET_ROSTER")
end

------------------------------------------------------------------------
-- Mitgliederliste (nur im Speicher)

N.roster = {}      -- [Schluessel] = Name, wie das Spiel ihn liefert
N.rosterAt = 0
local collect = nil   -- { id, t, names = {}, any }

local function Busy()
    if G.InCombatLockdown and G.InCombatLockdown() then return true end
    if G.IsInInstance then
        local ok, inside = pcall(G.IsInInstance)
        if ok and inside then return true end
    end
    return false
end

-- Neue Liste uebernehmen; meldet Admins, die neu dazugekommen sind
function N.SetRoster(names)
    local old = N.roster or {}
    local fresh = {}
    for _, n in ipairs(names or {}) do
        if type(n) == "string" and not Secret(n) then
            local k = Key(n)
            if k ~= "" then fresh[k] = n end
        end
    end
    local hadList = N.rosterAt > 0 and Clock() - N.rosterAt <= N.ROSTER_TTL
    N.roster = fresh
    N.rosterAt = Clock()
    local me = Key(SelfName())
    for _, a in ipairs(N.Admins()) do
        local k = Key(a)
        if k ~= me and fresh[k] and not (hadList and old[k]) then FW:Fire("NET_ADMIN_ONLINE", a) end
    end
    FW:Fire("NET_ROSTER")
end

-- Liste gueltig? (sonst wissen wir nicht, wer online ist)
function N.Known()
    return N.Enabled() and N.rosterAt > 0 and Clock() - N.rosterAt <= N.ROSTER_TTL
end

-- true = online, false = nicht in der Liste, nil = unbekannt (keine gueltige Liste)
function N.Online(name)
    if not N.Known() then return nil end
    return N.roster[Key(name)] ~= nil
end

-- Admins, die laut Liste online sind (in Vorrang-Reihenfolge, ohne mich selbst)
function N.OnlineAdmins()
    local out = {}
    if not N.Known() then return out end
    local me = Key(SelfName())
    for _, a in ipairs(N.Admins()) do
        local k = Key(a)
        if k ~= me and N.roster[k] then out[#out + 1] = a end
    end
    return out
end

-- Andere Freewood-Spieler (ohne mich und ohne Admins), Namen wie vom Spiel geliefert
function N.Peers()
    local out = {}
    if not N.Known() then return out end
    local me = Key(SelfName())
    for k, n in pairs(N.roster) do
        if k ~= me and not N.IsAdmin(n) then out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

function N.Count()
    local c = 0
    for _ in pairs(N.roster) do c = c + 1 end
    return c
end

-- Abfrage starten: ueber Channels.lua (blendet die Listenausgabe im Chat waehrend der Abfrage aus)
function N.Refresh()
    if not N.Enabled() or Busy() then return false end
    local id = ChannelId()
    if not id then return false end
    collect = { id = id, t = Clock(), names = {}, any = false }
    local Ch = FW.Channels
    if Ch and Ch.Rescan and Ch.RefreshOne then
        Ch.Rescan()
        Ch.RefreshOne(id)
    elseif type(G.ListChannelByName) == "function" then
        pcall(G.ListChannelByName, id)
    end
    if G.C_Timer and G.C_Timer.After then
        local my = collect
        G.C_Timer.After(N.COLLECT + 4, function() N.Finish(my) end)
    end
    return true
end

-- Teile der Liste sammeln (eine lange Liste kann in mehreren Ereignissen kommen)
function N.OnList(text, a2, a3, a4, a5, a6, a7, num, chanName)
    if not collect or Secret(text) then return end
    if Clock() - collect.t > N.COLLECT + 4 then return end
    local match = tonumber(num) == collect.id
    if not match and type(chanName) == "string" and not Secret(chanName) then
        match = chanName:lower():find(N.CHANNEL:lower(), 1, true) ~= nil
    end
    if not match then return end
    local Ch = FW.Channels
    local names = Ch and Ch.ParseNames and Ch.ParseNames(text) or {}
    for _, n in ipairs(names) do collect.names[#collect.names + 1] = n end
    collect.any = true
end

-- Abschluss: gesammelte Teile oder (Rueckfall ohne Ereignis) die von Channels.lua gelesene Liste
function N.Finish(my)
    if not my or my ~= collect then return end
    collect = nil
    if my.any then return N.SetRoster(my.names) end
    local Ch = FW.Channels
    local e = Ch and Ch.byNum and Ch.byNum[my.id]
    if e and e.stamp and e.stamp >= my.t and e.listed then return N.SetRoster(e.listed) end
end

FW:RegisterEvent("CHAT_MSG_CHANNEL_LIST", N.OnList)

-- Takt: beitreten, Liste regelmaessig neu holen
local function Tick()
    if N.Enabled() then
        if not ChannelId() then N.Join() else N.Refresh() end
    end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(N.ROSTER_EVERY, Tick) end
end

FW:RegisterEvent("PLAYER_LOGIN", function()
    ApplyTargets()
    if G.C_Timer and G.C_Timer.After then
        G.C_Timer.After(8 + math.random() * 7, function() N.Join() end)
        G.C_Timer.After(30 + math.random() * 30, Tick)
    end
end)

-- Einstellung
local UI = FW.UI
if UI and UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("net-share", {
        category = "general",
        order = 60,
        height = 70,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.SETTINGS_NET_TITLE or "Freewood network")
            stack:Add(UI.CreateCheckbox(f, L.SETTINGS_NET or "Exchange data with other Freewood players (worldwide, invisible)",
                function() return N.Enabled() end,
                function(v) N.SetEnabled(v) end), { fit = true })
            return f
        end,
    })
end

-- /fwnet: Stand des Netzes
G.SLASH_FREEWOODNET1 = "/fwnet"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList.FREEWOODNET = function()
    local p = FW.Print and function(s) FW:Print(s) end or print
    local age = N.rosterAt > 0 and math.floor(Clock() - N.rosterAt) or -1
    p(string.format("Netz: %s, Kanal %s (%s), %d Spieler in der Liste (Alter %s s)",
        N.Enabled() and "an" or "aus", N.CHANNEL, N.status, N.Count(), age >= 0 and tostring(age) or "-"))
    local on = N.OnlineAdmins()
    p("Admins online: " .. (#on > 0 and table.concat(on, ", ") or "-"))
end
