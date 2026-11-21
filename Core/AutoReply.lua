-- Freewood-Core: Auto-Antwort (seit 0.59.0, Auslöser, Emotes, Vorlagen und Export seit 0.60.0)
--
-- Eine Regel = Auslöser + Bedingungen + Aktion.
--   Auslöser (rule.kind): chat (Flüstern, Battle.net, Gilde, Offiziere, Gruppe, Schlachtzug), buff (Buff von einem
--     Spieler), friendon, guildon (kommt online), rollwon (Item beim Würfeln gewonnen), levelup (eigenes Level-up),
--     guildlevel (Level-up in der Gilde, über die Gildenliste, bis zu ~1 min später), nearlevel (Level-up in der
--     Umgebung: Gruppe, Ziel, sichtbare Namensplaketten), invite, trade, duel (Anfragen), rez (wiederbelebt worden),
--     groupjoin (tritt der Gruppe bei), guildjoin (neues Gildenmitglied), boss (Boss besiegt).
--   Bedingungen: Wortfilter (Zeile = UND, Zeilen = ODER, "Nie wenn"), über dich (AFK, DND, Gruppe, Schlachtzug, Kampf,
--     Instanz), über den anderen (Gildenmitglied, Gruppenmitglied, Freund), Uhrzeit von-bis, Klassen, Charakter,
--     einmal pro Sitzung je Spieler.
--   Aktion: Text, Emote oder beides. Text geht in denselben Chat, per Flüstern an die Person, in die Gilde oder in
--     Gruppe/Schlachtzug; Emote (Voice-Emotes) mit oder ohne Ziel. Zufällige Verzögerung von-bis.
-- Feste Schutzregeln: nie dir selbst, nie GMs, höchstens MAX_PER_MIN Aktionen pro Minute, 60 s Begrüßungssperre nach
-- dem Einloggen bei online/beitreten/Gilden-Level-up. Nicht möglich (Blizzard): Sagen, Schreien, Kanäle und eigener
-- Emote-Text ohne Tastendruck; Ticket mit angehängtem Chat.
--
-- Daten: FreewoodDB.autoReply = { on, rules, log, nextId } (Account; je Regel optional nur ein Charakter).

local ADDON, FW = ...
local G = _G

local AR = {}
FW.AutoReply = AR

AR.MAX_PER_MIN = 6
AR.LOG_MAX = 100
AR.BUFFER_SECONDS = 300
AR.IGNORE_WAIT = 20
AR.LOGIN_QUIET = 60
AR.SOURCES = { "WHISPER", "BN", "GUILD", "OFFICER", "PARTY", "RAID" }
AR.CONDS = { "afk", "dnd", "group", "raid", "combat", "instance" }
AR.OTHER = { "guild", "party", "friend" }
AR.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
AR.KINDS = { "chat", "buff", "friendon", "guildon", "rollwon", "levelup", "guildlevel", "nearlevel",
    "invite", "trade", "duel", "rez", "groupjoin", "guildjoin", "boss" }
-- Auslöser ohne andere Person (kein Flüstern, keine Bedingungen über den anderen)
AR.NOPERSON = { levelup = true, boss = true, rollwon = true }
-- Auslöser mit Filterfeld (Text, gegen den gefiltert wird)
AR.FILTERED = { chat = true, buff = true, rollwon = true, boss = true }
-- Begrüßungssperre nach dem Einloggen
AR.QUIET = { friendon = true, guildon = true, groupjoin = true, guildlevel = true, guildjoin = true, nearlevel = true }
-- Voice-Emotes (Charakter spricht), Wiki "List of emotes"
AR.EMOTES = { "HELLO", "BYE", "THANK", "WELCOME", "CONGRATULATE", "CHEER", "APPLAUD", "LAUGH", "CHUCKLE", "GIGGLE",
    "NOD", "NO", "YW", "OOPS", "WAIT", "FOLLOW", "HEALME", "HELPME", "OOM", "INCOMING", "CHARGE", "FLEE", "OPENFIRE",
    "ATTACKMYTARGET", "TRAIN", "ROAR", "FLIRT", "KISS", "BEG", "CRY", "MOURN", "GLOAT", "TAUNT", "RUDE", "SILLY",
    "ROFL", "GUFFAW", "CACKLE", "WHOA", "RASP", "VIOLIN", "CHICKEN" }

-- Chat-Ereignis -> Quelle der Regel und Kanal für "denselben Chat"
AR.EVENTS = {
    CHAT_MSG_WHISPER = { src = "WHISPER", reply = "WHISPER" },
    CHAT_MSG_BN_WHISPER = { src = "BN", reply = "BN" },
    CHAT_MSG_GUILD = { src = "GUILD", reply = "GUILD" },
    CHAT_MSG_OFFICER = { src = "OFFICER", reply = "OFFICER" },
    CHAT_MSG_PARTY = { src = "PARTY", reply = "PARTY" },
    CHAT_MSG_PARTY_LEADER = { src = "PARTY", reply = "PARTY" },
    CHAT_MSG_INSTANCE_CHAT = { src = "PARTY", reply = "INSTANCE_CHAT" },
    CHAT_MSG_INSTANCE_CHAT_LEADER = { src = "PARTY", reply = "INSTANCE_CHAT" },
    CHAT_MSG_RAID = { src = "RAID", reply = "RAID" },
    CHAT_MSG_RAID_LEADER = { src = "RAID", reply = "RAID" },
    CHAT_MSG_RAID_WARNING = { src = "RAID", reply = "RAID" },
}
AR.BUFFER_ONLY = { CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_CHANNEL = "CHANNEL",
    CHAT_MSG_EMOTE = "EMOTE", CHAT_MSG_WHISPER_INFORM = "WHISPER_INFORM", CHAT_MSG_BN_WHISPER_INFORM = "BN_INFORM" }

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

local function Secret(v) return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) end
local function Str(v) if type(v) ~= "string" or Secret(v) then return nil end return v end
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function AR.Now() return (G.GetTime and G.GetTime()) or 0 end
function AR.Clock() return (G.time and G.time()) or 0 end

function AR.Lower(s)
    s = tostring(s or ""):lower()
    return (s:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

-- Name für Vergleiche: klein, ohne "-Realm"
function AR.Norm(name)
    name = AR.Lower(Trim(name))
    return (name:gsub("%-[^%s]*$", ""))
end

-- Gleiche Person? Mit Vor- und Nachnamen genau; hat eine Seite nur den Vornamen (F-20), reicht der Vorname
function AR.SameName(a, b)
    a, b = AR.Norm(a), AR.Norm(b)
    if a == "" or b == "" then return false end
    if a == b then return true end
    local fa, fb = a:match("^(%S+)"), b:match("^(%S+)")
    if (not a:find(" ") or not b:find(" ")) and fa == fb then return true end
    return false
end

function AR.FirstName(name)
    name = tostring(name or "")
    return name:match("^([^%s%-]+)") or name
end

function AR.DB()
    local db = FW.db
    if type(db) ~= "table" then AR.memDB = AR.memDB or {} db = AR.memDB end
    db.autoReply = db.autoReply or {}
    local d = db.autoReply
    if d.on == nil then d.on = true end
    d.rules = d.rules or {}
    d.log = d.log or {}
    d.nextId = d.nextId or 1
    if not d.v60 then
        for _, r in ipairs(d.rules) do AR.Upgrade(r) end
        d.v60 = true
    end
    return d
end

function AR.CharKey()
    if FW.Util and FW.Util.GetPlayerKey then
        local ok, k = pcall(FW.Util.GetPlayerKey)
        if ok and k then return k end
    end
    return tostring(G.UnitName and G.UnitName("player") or "?")
end

-- Vorlage für "%s"/"%1$s" (Spieltexte, F-36) in ein Lua-Muster mit Fangstellen
function AR.TemplatePattern(t)
    if type(t) ~= "string" or t == "" then return nil end
    t = t:gsub("%%%d+%$([sd])", "%%%1")
    local p = t:gsub("([%%%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p .. "$"
end

------------------------------------------------------------------------
-- Regeln
------------------------------------------------------------------------

-- Fehlende Felder ergänzen (alte Regeln aus 0.59 und Importe)
function AR.Upgrade(r)
    r.kind = r.kind or "chat"
    r.src = r.src or {}
    r.cond = r.cond or {}
    for _, k in ipairs(AR.CONDS) do r.cond[k] = r.cond[k] or "any" end
    for _, k in ipairs(AR.OTHER) do r.cond[k] = r.cond[k] or "any" end
    r.classes = r.classes or {}
    r.classMode = r.classMode or "all"
    r.match, r.never, r.replies = r.match or "", r.never or "", r.replies or ""
    r.action = r.action or "text"
    if not r.dest then
        if r.kind == "chat" then r.dest = "same"
        elseif r.buffReply == "GROUP" then r.dest = "group"
        else r.dest = "whisper" end
    end
    r.buffReply = nil
    r.emote = r.emote or "THANK"
    if r.emoteTarget == nil then r.emoteTarget = true end
    r.delayMin = r.delayMin or 1
    r.delayMax = r.delayMax or 3
    r.cdRule = r.cdRule or 0
    r.cdPlayer = r.cdPlayer or 60
    r.ignoreAfter = r.ignoreAfter or 0
    r.timeFrom, r.timeTo = r.timeFrom or "", r.timeTo or ""
    if r.on == nil then r.on = true end
    return r
end

function AR.NewRule(kind, fields)
    local d = AR.DB()
    local id = d.nextId
    d.nextId = id + 1
    local r = { id = id, name = (FW.L and FW.L.AR_NEW_NAME or "Regel") .. " " .. id, kind = kind or "chat",
        src = (kind or "chat") == "chat" and { WHISPER = true } or {} }
    for k, v in pairs(fields or {}) do r[k] = v end
    AR.Upgrade(r)
    table.insert(d.rules, r)
    if FW.Fire then FW:Fire("AUTOREPLY_CHANGED") end
    return r
end

function AR.Find(id)
    for i, r in ipairs(AR.DB().rules) do if r.id == id then return r, i end end
    return nil
end

function AR.Delete(id)
    local _, i = AR.Find(id)
    if not i then return false end
    table.remove(AR.DB().rules, i)
    if FW.Fire then FW:Fire("AUTOREPLY_CHANGED") end
    return true
end

------------------------------------------------------------------------
-- Vorlagen (Texte in UI/AutoReply.lua: AR_T_<id> = Name, AR_T_<id>_R = Antworten, AR_T_<id>_M = Wörter)
------------------------------------------------------------------------

AR.TEMPLATES = {
    { id = "PORT", kind = "chat", src = { WHISPER = true }, classMode = "only", classes = { WARLOCK = true },
        cdPlayer = 120, ignoreAfter = 5 },
    { id = "GN", kind = "chat", src = { GUILD = true }, whole = true, cdRule = 300, cdPlayer = 0, dest = "same" },
    { id = "GLVL", kind = "guildlevel", dest = "guild", action = "text", cdPlayer = 0 },
    { id = "LVL", kind = "levelup", dest = "guild", action = "both", emote = "CHEER", emoteTarget = false, cdPlayer = 0 },
    { id = "BUFF", kind = "buff", dest = "whisper", action = "both", emote = "THANK", cdPlayer = 300,
        cond = { group = "yes" } },
    { id = "GJOIN", kind = "guildjoin", dest = "guild", action = "text", cdPlayer = 0 },
    { id = "PJOIN", kind = "groupjoin", dest = "group", action = "both", emote = "HELLO", emoteTarget = false, cdPlayer = 600 },
    { id = "REZ", kind = "rez", dest = "whisper", action = "both", emote = "THANK", cdPlayer = 60 },
    { id = "DUEL", kind = "duel", dest = "whisper", action = "text", cdPlayer = 300 },
    { id = "BOSS", kind = "boss", dest = "group", action = "both", emote = "CHEER", emoteTarget = false, cdRule = 30, cdPlayer = 0 },
    { id = "INVITE", kind = "invite", dest = "whisper", action = "text", cdPlayer = 120, cond = { dnd = "yes" } },
    { id = "FRIEND", kind = "friendon", dest = "whisper", action = "text", cdPlayer = 3600 },
}

function AR.FromTemplate(tid)
    local t
    for _, x in ipairs(AR.TEMPLATES) do if x.id == tid then t = x end end
    if not t then return nil end
    local L = FW.L or {}
    local f = {}
    for k, v in pairs(t) do
        if type(v) == "table" then local c = {} for a, b in pairs(v) do c[a] = b end f[k] = c else f[k] = v end
    end
    f.id = nil
    -- fehlende Texte liefern in FW.L den Schlüssel selbst zurück: dann leer lassen
    local function Txt(key, default)
        local v = L[key]
        if type(v) ~= "string" or v == key then return default end
        return v
    end
    f.name = Txt("AR_T_" .. tid, tid)
    f.replies = Txt("AR_T_" .. tid .. "_R", "")
    f.match = Txt("AR_T_" .. tid .. "_M", "")
    local r = AR.NewRule(t.kind, f)
    return r
end

------------------------------------------------------------------------
-- Export / Import (über Core/Export.lua, Datenart "autoreply")
------------------------------------------------------------------------

local KEEP = { "name", "on", "kind", "src", "match", "never", "whole", "cond", "classMode", "classes", "replies",
    "cdRule", "cdPlayer", "ignoreAfter", "report", "action", "dest", "emote", "emoteTarget", "delayMin", "delayMax",
    "timeFrom", "timeTo", "once" }

function AR.Strip(r)
    local o = {}
    for _, k in ipairs(KEEP) do o[k] = r[k] end
    return o
end

function AR.ExportRules(list)
    local E = FW.Export
    if not E or not E.Encode then return nil, "ERR_NOAPI" end
    local data = {}
    for _, r in ipairs(list) do data[#data + 1] = AR.Strip(r) end
    return E.Encode("autoreply", data)
end

function AR.ImportRules(text)
    local E = FW.Export
    if not E or not E.Decode then return nil, "ERR_NOAPI" end
    local payload, err = E.Decode(Trim(text))
    if not payload then return nil, err end
    if payload.k ~= "autoreply" or type(payload.d) ~= "table" then return nil, "ERR_KIND" end
    local n = 0
    for _, x in ipairs(payload.d) do
        if type(x) == "table" and type(x.kind) == "string" then
            local f = {}
            for _, k in ipairs(KEEP) do if x[k] ~= nil then f[k] = x[k] end end
            f.char = nil
            f.on = false     -- importierte Regeln erst prüfen, dann einschalten
            AR.NewRule(x.kind, f)
            n = n + 1
        end
    end
    return n
end

------------------------------------------------------------------------
-- Wortfilter
------------------------------------------------------------------------

function AR.Parse(text)
    local groups = {}
    text = AR.Lower(text or "")
    text = text:gsub("%s+oder%s+", "\n"):gsub("%s+or%s+", "\n"):gsub("|", "\n")
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local l = line:gsub("%s+und%s+", ","):gsub("%s+and%s+", ","):gsub("[&+]", ",")
        local g = {}
        for term in (l .. ","):gmatch("([^,]*),") do
            term = Trim(term)
            if term ~= "" then g[#g + 1] = term end
        end
        if #g > 0 then groups[#groups + 1] = g end
    end
    return groups
end

function AR.ParseList(text)
    local out = {}
    for term in (AR.Lower(text or "") .. ","):gmatch("([^,\n]*)[,\n]") do
        term = Trim(term)
        if term ~= "" then out[#out + 1] = term end
    end
    return out
end

local function IsLetter(c)
    if not c or c == "" then return false end
    local b = c:byte()
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128
end

function AR.Has(msg, term, whole)
    local start = 1
    while true do
        local a, b = msg:find(term, start, true)
        if not a then return false end
        if not whole then return true end
        if not IsLetter(msg:sub(a - 1, a - 1)) and not IsLetter(msg:sub(b + 1, b + 1)) then return true end
        start = a + 1
    end
end

function AR.Matches(rule, msg)
    msg = AR.Lower(msg or "")
    for _, t in ipairs(AR.ParseList(rule.never)) do
        if AR.Has(msg, t, rule.whole) then return false end
    end
    local groups = AR.Parse(rule.match)
    if #groups == 0 then return true end
    for _, g in ipairs(groups) do
        local all = true
        for _, t in ipairs(g) do
            if not AR.Has(msg, t, rule.whole) then all = false break end
        end
        if all then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Wer ist wer: Gilde, Gruppe, Freunde
------------------------------------------------------------------------

AR.guildRoster = {}      -- [Norm(name)] = { name, level }
AR.guildReady = false

function AR.ReadGuild()
    local out = {}
    if G.IsInGuild and G.IsInGuild() and G.GetNumGuildMembers and G.GetGuildRosterInfo then
        local n = G.GetNumGuildMembers() or 0
        for i = 1, n do
            local name, _, _, level = G.GetGuildRosterInfo(i)
            name = Str(name)
            if name then out[AR.Norm(name)] = { name = name, level = tonumber(level) } end
        end
    end
    return out
end

function AR.IsGuild(who)
    if not who then return false end
    if AR.guildRoster[AR.Norm(who)] then return true end
    for k in pairs(AR.guildRoster) do if AR.SameName(k, who) then return true end end
    return false
end

function AR.GroupUnits()
    local u = {}
    if AR.Env.raid() then
        for i = 1, 40 do u[#u + 1] = "raid" .. i end
    elseif AR.Env.group() then
        for i = 1, 4 do u[#u + 1] = "party" .. i end
    end
    return u
end

function AR.GroupNames()
    local out = {}
    for _, unit in ipairs(AR.GroupUnits()) do
        if G.UnitExists and G.UnitExists(unit) and not (G.UnitIsUnit and G.UnitIsUnit(unit, "player")) then
            local n = AR.UnitFull(unit)
            if n then out[#out + 1] = n end
        end
    end
    return out
end

function AR.IsParty(who)
    if not who then return false end
    for _, n in ipairs(AR.GroupNames()) do if AR.SameName(n, who) then return true end end
    return false
end

function AR.IsFriend(who)
    if not who then return false end
    local F = G.C_FriendList
    if F and F.GetNumFriends and F.GetFriendInfoByIndex then
        for i = 1, (F.GetNumFriends() or 0) do
            local info = F.GetFriendInfoByIndex(i)
            if type(info) == "table" and Str(info.name) and AR.SameName(info.name, who) then return true end
        end
    end
    return false
end

------------------------------------------------------------------------
-- Bedingungen
------------------------------------------------------------------------

AR.Env = {
    afk = function() return G.UnitIsAFK and G.UnitIsAFK("player") and true or false end,
    dnd = function() return G.UnitIsDND and G.UnitIsDND("player") and true or false end,
    group = function() return G.IsInGroup and G.IsInGroup() and true or false end,
    raid = function() return G.IsInRaid and G.IsInRaid() and true or false end,
    combat = function() return G.InCombatLockdown and G.InCombatLockdown() and true or false end,
    instance = function() if not G.IsInInstance then return false end local i = G.IsInInstance() return i and true or false end,
    class = function() if not G.UnitClass then return nil end local _, c = G.UnitClass("player") return c end,
    clock = function() return G.date and G.date("%H:%M") or "12:00" end,
}

local function ToMin(hhmm)
    local h, m = tostring(hhmm or ""):match("^%s*(%d%d?):?(%d%d)%s*$")
    if not h then return nil end
    h, m = tonumber(h), tonumber(m)
    if h > 23 or m > 59 then return nil end
    return h * 60 + m
end
AR.ToMin = ToMin

function AR.TimeOK(rule)
    local a, b = ToMin(rule.timeFrom), ToMin(rule.timeTo)
    if not a or not b or a == b then return true end
    local now = ToMin(AR.Env.clock()) or 0
    if a < b then return now >= a and now < b end
    return now >= a or now < b      -- über Mitternacht
end

-- info: { who, src } (für die Bedingungen über den anderen)
function AR.CondOK(rule, info)
    local cond = rule.cond or {}
    for _, k in ipairs(AR.CONDS) do
        local want = cond[k] or "any"
        if want ~= "any" then
            local fn = AR.Env[k]
            local v = fn and fn() or false
            if want == "yes" and not v then return false, k end
            if want == "no" and v then return false, k end
        end
    end
    if info and not AR.NOPERSON[rule.kind] then
        for _, k in ipairs(AR.OTHER) do
            local want = cond[k] or "any"
            if want ~= "any" then
                local v
                if k == "guild" then v = info.src == "GUILD" or info.src == "OFFICER" or AR.IsGuild(info.who)
                elseif k == "party" then v = info.src == "PARTY" or info.src == "RAID" or AR.IsParty(info.who)
                else v = info.src == "BN" or AR.IsFriend(info.who) end
                if want == "yes" and not v then return false, k end
                if want == "no" and v then return false, k end
            end
        end
    end
    if rule.classMode and rule.classMode ~= "all" then
        local c = AR.Env.class()
        local listed = c and rule.classes and rule.classes[c] and true or false
        if rule.classMode == "only" and not listed then return false, "class" end
        if rule.classMode == "not" and listed then return false, "class" end
    end
    if rule.char and rule.char ~= AR.CharKey() then return false, "char" end
    if not AR.TimeOK(rule) then return false, "time" end
    return true
end

------------------------------------------------------------------------
-- Zeitsperren, Zähler, Verlauf
------------------------------------------------------------------------

AR.lastRule, AR.lastPlayer, AR.counts, AR.sent, AR.asked, AR.onceDone = {}, {}, {}, {}, {}, {}

local function Key(rule, who) return rule.id .. "|" .. AR.Norm(who or "-") end

function AR.Cooldown(rule, who, now)
    now = now or AR.Now()
    local cdr = tonumber(rule.cdRule) or 0
    if cdr > 0 and AR.lastRule[rule.id] and now - AR.lastRule[rule.id] < cdr then return "rule" end
    local k = Key(rule, who)
    local cdp = tonumber(rule.cdPlayer) or 0
    if who and cdp > 0 and AR.lastPlayer[k] and now - AR.lastPlayer[k] < cdp then return "player" end
    if who and rule.once and AR.onceDone[k] then return "once" end
    local n = 0
    for i = #AR.sent, 1, -1 do
        if now - AR.sent[i] < 60 then n = n + 1 else table.remove(AR.sent, i) end
    end
    if n >= AR.MAX_PER_MIN then return "flood" end
    return nil
end

function AR.Log(entry)
    local log = AR.DB().log
    table.insert(log, 1, entry)
    while #log > AR.LOG_MAX do table.remove(log) end
    if FW.Fire then FW:Fire("AUTOREPLY_LOG") end
end

function AR.Fill(text, info)
    info = info or {}
    local me = AR.FirstName(G.UnitName and G.UnitName("player") or "")
    local lvl = info.level or (G.UnitLevel and G.UnitLevel("player")) or ""
    local cls = G.UnitClass and G.UnitClass("player") or ""
    local vars = {
        name = info.who and AR.FirstName(info.who) or "", me = me, level = tostring(lvl), item = info.item or "",
        zone = G.GetZoneText and G.GetZoneText() or "", class = tostring(cls or ""),
        time = G.date and G.date("%H:%M") or "", boss = info.boss or "", spell = info.spell or "",
    }
    text = text:gsub("{(%a+)}", function(k) if vars[k] then return tostring(vars[k]) end end)
    if #text > 255 then text = text:sub(1, 255) end
    return text
end

function AR.PickReply(rule, info)
    local list = {}
    for line in (tostring(rule.replies or "") .. "\n"):gmatch("([^\n]*)\n") do
        line = Trim(line)
        if line ~= "" then list[#list + 1] = line end
    end
    if #list == 0 then return nil end
    return AR.Fill(list[math.random(#list)], info)
end

------------------------------------------------------------------------
-- Ausführen
------------------------------------------------------------------------

function AR.Send(channel, text, target, bnID)
    if channel == "BN" then
        if bnID and type(G.BNSendWhisper) == "function" then return (pcall(G.BNSendWhisper, bnID, text)) end
        if FW.ChatLog and FW.ChatLog.BNSend then return FW.ChatLog.BNSend(target, text) end
        return false
    end
    if type(G.SendChatMessage) ~= "function" then return false end
    if channel == "WHISPER" then
        if not target then return false end
        return (pcall(G.SendChatMessage, text, "WHISPER", nil, target))
    end
    return (pcall(G.SendChatMessage, text, channel))
end

-- Voice-Emote; Forever hat entweder DoEmote oder den Ersatz C_ChatInfo.PerformEmote (Classic Era ab 1.15.9)
function AR.Emote(token, target)
    local C = G.C_ChatInfo
    if C and type(C.PerformEmote) == "function" then
        local ok = pcall(C.PerformEmote, token, target)
        if ok then return true end
    end
    if type(G.DoEmote) == "function" then
        local ok = pcall(G.DoEmote, token, target)
        if ok then return true end
    end
    return false
end

-- Wohin geht der Text?
function AR.Channel(rule, info)
    local dest = rule.dest or "same"
    if dest == "same" then
        if info.reply then return info.reply end
        dest = "whisper"
    end
    if dest == "whisper" then
        if info.src == "BN" then return "BN" end
        return info.who and "WHISPER" or nil
    end
    if dest == "guild" then return (G.IsInGuild == nil or G.IsInGuild()) and "GUILD" or nil end
    if dest == "group" then
        if AR.Env.raid() then return "RAID" end
        if AR.Env.group() then return "PARTY" end
        return nil
    end
    return nil
end

function AR.Fire(rule, info)
    local who = info.who
    local act = rule.action or "text"
    local text = (act == "text" or act == "both") and AR.PickReply(rule, info) or nil
    local channel = text and AR.Channel(rule, info) or nil
    local emote = (act == "emote" or act == "both") and rule.emote or nil
    if not (text and channel) and not emote then return false, "nothing" end
    local now = AR.Now()
    local k = Key(rule, who)
    AR.lastRule[rule.id] = now
    if who then AR.lastPlayer[k] = now AR.onceDone[k] = true end
    AR.sent[#AR.sent + 1] = now
    AR.counts[k] = (AR.counts[k] or 0) + 1
    local lo, hi = tonumber(rule.delayMin) or 1, tonumber(rule.delayMax) or 3
    if hi < lo then hi = lo end
    local delay = AR.DELAY or (lo + (hi - lo) * math.random())
    local function Go()
        local okText, okEmote
        if text and channel then okText = AR.Send(channel, text, who, info.bnID) end
        if emote then okEmote = AR.Emote(emote, rule.emoteTarget and who or nil) end
        AR.Log({ t = AR.Clock(), rule = rule.name, who = who or "-", src = channel or "EMOTE",
            msg = tostring(info.msg or ""):sub(1, 140),
            reply = (text and channel and text or "") .. (emote and ((text and channel) and "  " or "") .. "/" .. emote:lower() or ""),
            ok = not ((text and channel and not okText) or (emote and not okEmote)) })
    end
    if delay > 0 and G.C_Timer and G.C_Timer.After then G.C_Timer.After(delay, Go) else Go() end
    local limit = tonumber(rule.ignoreAfter) or 0
    if who and rule.kind == "chat" and limit > 0 and info.src ~= "BN" and AR.counts[k] >= limit and not AR.asked[AR.Norm(who)] then
        AR.asked[AR.Norm(who)] = true
        if AR.AskIgnore then AR.AskIgnore(who, rule) end
    end
    if rule.kind == "chat" and rule.report and who and AR.OpenReport then AR.OpenReport(who, info) end
    return true, text
end

function AR.IsSelf(who, guid)
    if guid and G.UnitGUID and guid == G.UnitGUID("player") then return true end
    if not who then return false end
    local me = G.UnitName and G.UnitName("player")
    if me and AR.Norm(who) == AR.Norm(me) then return true end
    local full = FW.Whisper and FW.Whisper.SelfName and FW.Whisper.SelfName()
    if full and AR.Norm(who) == AR.Norm(full) then return true end
    return false
end

AR.loginAt = AR.Now()

-- Gemeinsamer Eingang aller Auslöser. info: { who, guid, bnID, src, reply, msg (für den Filter), item, level, boss, spell }
-- Rückgabe: Liste der ausgeführten Regel-Ids (für Tests)
function AR.Trigger(kind, info)
    info = info or {}
    local d = AR.DB()
    if not d.on then return {} end
    if info.who and AR.IsSelf(info.who, info.guid) and info.src ~= "BN" then return {} end
    if AR.QUIET[kind] and AR.Now() - (AR.loginAt or 0) < AR.LOGIN_QUIET then return {} end
    local fired = {}
    for _, r in ipairs(d.rules) do
        if r.on and (r.kind or "chat") == kind and (kind ~= "chat" or (r.src and r.src[info.src]))
            and (not AR.FILTERED[kind] or AR.Matches(r, info.msg or ""))
            and AR.CondOK(r, info) and not AR.Cooldown(r, info.who) then
            if AR.Fire(r, info) then fired[#fired + 1] = r.id end
        end
    end
    return fired
end

------------------------------------------------------------------------
-- Auslöser: Chat
------------------------------------------------------------------------

function AR.OnChat(event, text, sender, flags, lineID, guid, bnID)
    local def = AR.EVENTS[event]
    text, sender = Str(text), Str(sender)
    if not def or not text or not sender then return {} end
    AR.Remember(def.src, sender, text, lineID, guid)
    if flags == "GM" or flags == "DEV" or flags == "GUIDE" then return {} end
    return AR.Trigger("chat", { who = sender, guid = guid, bnID = bnID, src = def.src, reply = def.reply, msg = text,
        lineID = lineID })
end

------------------------------------------------------------------------
-- Auslöser: Buff
------------------------------------------------------------------------

AR.lastBuff = {}

function AR.OnBuff(who, spell, guid)
    who = Str(who)
    if not who or AR.IsSelf(who, guid) then return {} end
    local now = AR.Now()
    local bk = AR.Norm(who) .. "|" .. tostring(spell)
    if AR.lastBuff[bk] and now - AR.lastBuff[bk] < 3 then return {} end
    AR.lastBuff[bk] = now
    return AR.Trigger("buff", { who = who, guid = guid, msg = spell or "", spell = spell })
end

function AR.UnitFull(unit)
    if not unit then return nil end
    local first, second
    if G.UnitFullName then first, second = G.UnitFullName(unit) end
    first, second = Str(first), Str(second)
    if first and second and second ~= "" and G.UnitIsPlayer and G.UnitIsPlayer(unit) and not second:find("%-") then
        return first .. " " .. second
    end
    local n = G.GetUnitName and Str(G.GetUnitName(unit, true))
    return n or first or (G.UnitName and Str(G.UnitName(unit)))
end

local function OnAura(unit, info)
    if unit ~= "player" or type(info) ~= "table" or type(info.addedAuras) ~= "table" then return end
    for _, a in ipairs(info.addedAuras) do
        local src = a.sourceUnit
        if a.isHelpful and type(src) == "string" and not Secret(src) and G.UnitIsPlayer and G.UnitIsPlayer(src)
            and not (G.UnitIsUnit and G.UnitIsUnit(src, "player")) then
            AR.auraSeen = true
            AR.OnBuff(AR.UnitFull(src), Str(a.name), G.UnitGUID and G.UnitGUID(src))
        end
    end
end

local function OnCombatLog()
    if AR.auraSeen or not G.CombatLogGetCurrentEventInfo then return end
    local _, sub, _, sGUID, sName, sFlags, _, dGUID, _, _, _, _, spellName, _, auraType = G.CombatLogGetCurrentEventInfo()
    if sub ~= "SPELL_AURA_APPLIED" or auraType ~= "BUFF" then return end
    if Secret(dGUID) or Secret(sGUID) or not G.UnitGUID or dGUID ~= G.UnitGUID("player") or sGUID == dGUID then return end
    local isPlayer = type(sFlags) == "number" and G.bit and G.bit.band(sFlags, 0x400) > 0
    if not isPlayer then return end
    AR.OnBuff(Str(sName), Str(spellName), sGUID)
end

------------------------------------------------------------------------
-- Auslöser: Systemzeilen (online, neues Gildenmitglied), Würfeln, Level-ups, Anfragen, Gruppe, Boss
------------------------------------------------------------------------

-- "|Hplayer:Name|h[Name]|h ist jetzt online." -> Name
function AR.ParseOnline(msg)
    local tmpl = Str(G.ERR_FRIEND_ONLINE_SS)
    if not msg or not tmpl then return nil end
    local tail = tmpl:match(".*|h(.-)$")
    if not tail or tail == "" or not msg:find(tail, 1, true) then return nil end
    return msg:match("|Hplayer:([^|:]+)")
end

function AR.OnSystem(msg)
    msg = Str(msg)
    if not msg then return end
    local who = AR.ParseOnline(msg)
    if who then
        if AR.IsFriend(who) then AR.Trigger("friendon", { who = who }) end
        if AR.IsGuild(who) then AR.Trigger("guildon", { who = who, src = "GUILD" }) end
        return
    end
    local p = AR.TemplatePattern(Str(G.ERR_GUILD_JOIN_S))
    local joined = p and msg:match(p)
    if joined then
        AR.Trigger("guildjoin", { who = joined, src = "GUILD" })
    end
end

function AR.OnBNOnline(bnID)
    if not bnID or not G.C_BattleNet or not G.C_BattleNet.GetAccountInfoByID then return end
    local ok, info = pcall(G.C_BattleNet.GetAccountInfoByID, bnID)
    if not ok or type(info) ~= "table" then return end
    local who = Str(info.accountName) or Str(info.battleTag)
    if who then AR.Trigger("friendon", { who = who, bnID = bnID, src = "BN" }) end
end

function AR.OnLoot(msg)
    msg = Str(msg)
    local p = AR.TemplatePattern(Str(G.LOOT_ROLL_YOU_WON))
    local item = msg and p and msg:match(p)
    if not item then return {} end
    local name = item:match("%[(.-)%]") or item
    return AR.Trigger("rollwon", { item = item, msg = name })
end

function AR.OnLevelUp(level)
    return AR.Trigger("levelup", { level = tonumber(level) })
end

-- Gildenliste: Level-ups vergleichen
function AR.OnGuildRoster()
    local fresh = AR.ReadGuild()
    local fired = {}
    if next(fresh) == nil then return fired end
    if AR.guildReady then
        for k, e in pairs(fresh) do
            local old = AR.guildRoster[k]
            if old and old.level and e.level and e.level > old.level and not AR.IsSelf(e.name) then
                for _, id in ipairs(AR.Trigger("guildlevel", { who = e.name, level = e.level, src = "GUILD" })) do
                    fired[#fired + 1] = id
                end
            end
        end
    end
    AR.guildRoster = fresh
    AR.guildReady = true
    return fired
end

-- Level-up in der Umgebung: Stufen je GUID merken, Anstieg melden
AR.levels = {}
function AR.OnUnitLevel(unit)
    if type(unit) ~= "string" or unit == "player" then return {} end
    if not (G.UnitIsPlayer and G.UnitIsPlayer(unit)) then return {} end
    if G.UnitIsUnit and G.UnitIsUnit(unit, "player") then return {} end
    local guid = G.UnitGUID and Str(G.UnitGUID(unit))
    local lvl = G.UnitLevel and tonumber(G.UnitLevel(unit))
    if not guid or not lvl or lvl <= 0 then return {} end
    local old = AR.levels[guid]
    AR.levels[guid] = lvl
    if old and lvl > old then
        return AR.Trigger("nearlevel", { who = AR.UnitFull(unit), guid = guid, level = lvl })
    end
    return {}
end

-- Beigetretene Gruppenmitglieder
AR.members = nil
function AR.OnRoster()
    local now = {}
    for _, n in ipairs(AR.GroupNames()) do now[AR.Norm(n)] = n end
    local fired = {}
    if AR.members and next(AR.members) ~= nil then
        for k, n in pairs(now) do
            if not AR.members[k] then
                for _, id in ipairs(AR.Trigger("groupjoin", { who = n, src = "PARTY" })) do fired[#fired + 1] = id end
            end
        end
    end
    -- wer selbst einer Gruppe beitritt, begrüßt nicht alle auf einmal: die erste Liste ist nur der Ausgangsstand
    AR.members = next(now) ~= nil and now or nil
    return fired
end

function AR.OnBoss(name)
    name = Str(name)
    if not name then return {} end
    local now = AR.Now()
    if AR.lastBoss == name and now - (AR.lastBossAt or 0) < 15 then return {} end
    AR.lastBoss, AR.lastBossAt = name, now
    return AR.Trigger("boss", { boss = name, msg = name })
end

------------------------------------------------------------------------
-- Verlauf der letzten 5 Minuten (für das Melde-Fenster)
------------------------------------------------------------------------

AR.buffer = {}

function AR.Remember(src, who, text, lineID, guid)
    local now = AR.Now()
    local b = AR.buffer
    b[#b + 1] = { t = now, clock = AR.Clock(), src = src, who = who, text = text, lineID = lineID, guid = guid }
    while b[1] and now - b[1].t > AR.BUFFER_SECONDS do table.remove(b, 1) end
    while #b > 500 do table.remove(b, 1) end
end

function AR.LinesOf(who)
    local out, now = {}, AR.Now()
    for _, e in ipairs(AR.buffer) do
        if now - e.t <= AR.BUFFER_SECONDS and AR.SameName(e.who, who) then out[#out + 1] = e end
    end
    return out
end

function AR.ReportText(who)
    local lines = {}
    for _, e in ipairs(AR.LinesOf(who)) do
        local ts = G.date and G.date("%H:%M:%S", e.clock) or tostring(e.clock)
        local dir = (e.src == "WHISPER_INFORM" or e.src == "BN_INFORM") and ("-> " .. e.who) or e.who
        lines[#lines + 1] = string.format("[%s] [%s] %s: %s", ts, e.src, dir, e.text)
    end
    return table.concat(lines, "\n"), #lines
end

------------------------------------------------------------------------
-- Ignorieren und Melden (Fenster in UI/AutoReply.lua)
------------------------------------------------------------------------

function AR.DoIgnore(who)
    local F = G.C_FriendList
    local ok, res
    if F and F.AddIgnore then ok, res = pcall(F.AddIgnore, who)
    elseif G.AddIgnore then ok, res = pcall(G.AddIgnore, who) end
    local L = FW.L or {}
    if FW.Print then
        if ok and res ~= false then FW:Print(string.format(L.AR_IGNORED or "%s is now on your ignore list.", who))
        else FW:Print(string.format(L.AR_IGNORE_FAIL or "Could not ignore %s.", who)) end
    end
    return ok and res ~= false
end

function AR.BlizzardReport(who, extra)
    extra = extra or {}
    local RF, RI, PL, E = G.ReportFrame, G.ReportInfo, G.PlayerLocation, G.Enum
    if RF and RF.InitiateReport and RI and RI.CreateReportInfoFromType and E and E.ReportType then
        local ok = pcall(function()
            local info = RI:CreateReportInfoFromType(E.ReportType.Chat)
            local loc
            if PL and extra.lineID and PL.CreateFromChatLineID then loc = PL:CreateFromChatLineID(extra.lineID)
            elseif PL and extra.guid and PL.CreateFromGUID then loc = PL:CreateFromGUID(extra.guid) end
            RF:InitiateReport(info, who, loc)
        end)
        if ok then return true end
    end
    local RS = G.C_ReportSystem
    if RS and RS.OpenReportPlayerDialog then
        local ok = pcall(RS.OpenReportPlayerDialog, "chat", who)
        if ok then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------

function AR.Setup()
    if AR.setup or not FW.RegisterEvent then return end
    AR.setup = true
    for ev in pairs(AR.EVENTS) do
        FW:RegisterEvent(ev, function(text, sender, _, _, _, flags, _, _, _, _, lineID, guid, bnID)
            AR.OnChat(ev, text, sender, flags, lineID, guid, bnID)
        end)
    end
    for ev, src in pairs(AR.BUFFER_ONLY) do
        FW:RegisterEvent(ev, function(text, who, _, _, _, _, _, _, _, _, lineID, guid)
            text, who = Str(text), Str(who)
            if text and who then AR.Remember(src, who, text, lineID, guid) end
        end)
    end
    FW:RegisterEvent("UNIT_AURA", OnAura)
    FW:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
    FW:RegisterEvent("CHAT_MSG_SYSTEM", function(msg) AR.OnSystem(msg) end)
    FW:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", function(id)
        if AR.Now() - (AR.loginAt or 0) >= AR.LOGIN_QUIET then AR.OnBNOnline(id) end
    end)
    FW:RegisterEvent("CHAT_MSG_LOOT", function(msg) AR.OnLoot(msg) end)
    FW:RegisterEvent("PLAYER_LEVEL_UP", function(level) AR.OnLevelUp(level) end)
    FW:RegisterEvent("GUILD_ROSTER_UPDATE", function() AR.OnGuildRoster() end)
    FW:RegisterEvent("UNIT_LEVEL", function(unit) AR.OnUnitLevel(unit) end)
    FW:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(unit) AR.OnUnitLevel(unit) end)
    FW:RegisterEvent("PLAYER_TARGET_CHANGED", function() AR.OnUnitLevel("target") end)
    FW:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        AR.OnRoster()
        for _, u in ipairs(AR.GroupUnits()) do if G.UnitExists and G.UnitExists(u) then AR.OnUnitLevel(u) end end
    end)
    FW:RegisterEvent("PARTY_INVITE_REQUEST", function(name) AR.Trigger("invite", { who = Str(name) }) end)
    FW:RegisterEvent("DUEL_REQUESTED", function(name) AR.Trigger("duel", { who = Str(name) }) end)
    FW:RegisterEvent("RESURRECT_REQUEST", function(name) AR.Trigger("rez", { who = Str(name) }) end)
    FW:RegisterEvent("TRADE_SHOW", function() AR.Trigger("trade", { who = AR.UnitFull("npc") }) end)
    FW:RegisterEvent("ENCOUNTER_END", function(_, name, _, _, success) if success == 1 then AR.OnBoss(name) end end)
    FW:RegisterEvent("BOSS_KILL", function(_, name) AR.OnBoss(name) end)
    FW:RegisterEvent("PLAYER_LOGIN", function() AR.loginAt = AR.Now() end)
    -- Gildenliste regelmäßig anfordern, solange es eine Regel "Level-up in der Gilde" gibt
    if G.C_Timer and G.C_Timer.NewTicker then
        G.C_Timer.NewTicker(60, function()
            for _, r in ipairs(AR.DB().rules) do
                if r.on and r.kind == "guildlevel" then
                    local gi = G.C_GuildInfo
                    if gi and gi.GuildRoster then pcall(gi.GuildRoster) elseif G.GuildRoster then pcall(G.GuildRoster) end
                    return
                end
            end
        end)
    end
end

AR.Setup()
