-- Freewood-Core: Auto-Antwort (seit 0.59.0)
--
-- Regeln antworten automatisch auf Chatnachrichten (Flüstern, Battle.net, Gilde, Offiziere, Gruppe, Schlachtzug)
-- oder auf Ereignisse (ein anderer Spieler bufft dich). Je Regel: Wortfilter (Zeile = UND-Gruppe, Zeilen = ODER,
-- "Nie wenn"), Bedingungen (AFK, DND, Gruppe, Schlachtzug: egal / nur wenn / nie wenn), Klassen, Charakter,
-- mehrere Antworten (zufällig), Pause je Regel, Pause je Spieler, Ignorieren nach N Antworten (20-s-Fenster zum
-- Abbrechen) und ein Melde-Fenster mit dem Chatverlauf der Person aus den letzten 5 Minuten.
--
-- Nicht möglich (Blizzard sperrt es): Sagen/Schreien/Kanäle ohne Tastendruck (darum kein "Local"), ein Ticket mit
-- angehängtem Chat (C_ReportSystem.SendReport ist für Addons gesperrt). Feste Schutzregeln: nie sich selbst, nie
-- GMs, nie auf Blizzards AFK/DND-Antworten, höchstens MAX_PER_MIN Antworten pro Minute insgesamt.
--
-- Daten: FreewoodDB.autoReply = { on, rules = { ... }, log = { ... }, nextId } (Account; je Regel optional nur
-- für einen Charakter).

local ADDON, FW = ...
local G = _G

local AR = {}
FW.AutoReply = AR

AR.MAX_PER_MIN = 6
AR.LOG_MAX = 100
AR.BUFFER_SECONDS = 300
AR.IGNORE_WAIT = 20
AR.SOURCES = { "WHISPER", "BN", "GUILD", "OFFICER", "PARTY", "RAID" }
AR.CONDS = { "afk", "dnd", "group", "raid" }
AR.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- Chat-Ereignis -> Quelle der Regel und Kanal der Antwort
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
-- nur für den Verlauf des Melde-Fensters
AR.BUFFER_ONLY = { CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_CHANNEL = "CHANNEL",
    CHAT_MSG_EMOTE = "EMOTE", CHAT_MSG_WHISPER_INFORM = "WHISPER_INFORM", CHAT_MSG_BN_WHISPER_INFORM = "BN_INFORM" }

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v)
end

local function Str(v)
    if type(v) ~= "string" or Secret(v) then return nil end
    return v
end

function AR.Now() return (G.GetTime and G.GetTime()) or 0 end
function AR.Clock() return (G.time and G.time()) or 0 end

-- Kleinschreibung mit deutschen Umlauten (string.lower kennt nur ASCII)
function AR.Lower(s)
    s = tostring(s or ""):lower()
    return (s:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"))
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function AR.DB()
    local db = FW.db
    if type(db) ~= "table" then
        AR.memDB = AR.memDB or {}
        db = AR.memDB
    end
    db.autoReply = db.autoReply or {}
    local d = db.autoReply
    if d.on == nil then d.on = true end
    d.rules = d.rules or {}
    d.log = d.log or {}
    d.nextId = d.nextId or 1
    return d
end

function AR.CharKey()
    if FW.Util and FW.Util.GetPlayerKey then
        local ok, k = pcall(FW.Util.GetPlayerKey)
        if ok and k then return k end
    end
    return tostring(G.UnitName and G.UnitName("player") or "?")
end

-- Vorname (Forever: "Vor Nachname"; sonst "Name-Realm")
function AR.FirstName(name)
    name = tostring(name or "")
    return name:match("^([^%s%-]+)") or name
end

------------------------------------------------------------------------
-- Regeln
------------------------------------------------------------------------

function AR.NewRule(kind)
    local d = AR.DB()
    local id = d.nextId
    d.nextId = id + 1
    local r = {
        id = id, name = (FW.L and FW.L.AR_NEW_NAME or "Regel") .. " " .. id, on = true, kind = kind or "chat",
        src = { WHISPER = true }, match = "", never = "", whole = false,
        cond = { afk = "any", dnd = "any", group = "any", raid = "any" },
        classMode = "all", classes = {}, char = nil,
        replies = "", cdRule = 0, cdPlayer = 60, ignoreAfter = 0, report = false, buffReply = "WHISPER",
    }
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
-- Wortfilter
------------------------------------------------------------------------

-- "portest und bezahle\nport UND gold" -> { {"portest","bezahle"}, {"port","gold"} }
-- UND: " und ", "&", "+", ","   ODER: neue Zeile, " oder ", "|"
function AR.Parse(text)
    local groups = {}
    text = AR.Lower(text or "")
    text = text:gsub("%s+oder%s+", "\n"):gsub("|", "\n")
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local l = line:gsub("%s+und%s+", ","):gsub("[&+]", ",")
        local g = {}
        for term in (l .. ","):gmatch("([^,]*),") do
            term = Trim(term)
            if term ~= "" then g[#g + 1] = term end
        end
        if #g > 0 then groups[#groups + 1] = g end
    end
    return groups
end

-- "scherz, spaß" -> { "scherz", "spaß" }
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

-- Kommt term in msg vor (msg schon klein)? whole = nur ganze Wörter
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

-- Passt die Nachricht zum Filter der Regel? Leerer Filter = jede Nachricht.
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
-- Bedingungen
------------------------------------------------------------------------

-- Umgebung (in Tests ersetzbar)
AR.Env = {
    afk = function() return G.UnitIsAFK and G.UnitIsAFK("player") and true or false end,
    dnd = function() return G.UnitIsDND and G.UnitIsDND("player") and true or false end,
    group = function() return G.IsInGroup and G.IsInGroup() and true or false end,
    raid = function() return G.IsInRaid and G.IsInRaid() and true or false end,
    class = function() if not G.UnitClass then return nil end local _, c = G.UnitClass("player") return c end,
}

function AR.CondOK(rule)
    for _, k in ipairs(AR.CONDS) do
        local want = rule.cond and rule.cond[k] or "any"
        if want ~= "any" then
            local fn = AR.Env[k]
            local v = fn and fn() or false
            if want == "yes" and not v then return false, k end
            if want == "no" and v then return false, k end
        end
    end
    if rule.classMode and rule.classMode ~= "all" then
        local c = AR.Env.class()
        local listed = c and rule.classes and rule.classes[c] and true or false
        if rule.classMode == "only" and not listed then return false, "class" end
        if rule.classMode == "not" and listed then return false, "class" end
    end
    if rule.char and rule.char ~= AR.CharKey() then return false, "char" end
    return true
end

------------------------------------------------------------------------
-- Zeitsperren, Zähler, Verlauf
------------------------------------------------------------------------

AR.lastRule = {}       -- [id] = Zeit der letzten Antwort
AR.lastPlayer = {}     -- [id.."|"..wer] = Zeit
AR.counts = {}         -- [id.."|"..wer] = Antworten in dieser Sitzung
AR.sent = {}           -- Zeiten aller Antworten (Schutz: MAX_PER_MIN)
AR.asked = {}          -- [wer] = Ignore-Fenster schon gezeigt

local function Key(rule, who) return rule.id .. "|" .. AR.Lower(who) end

function AR.Cooldown(rule, who, now)
    now = now or AR.Now()
    local cdr = tonumber(rule.cdRule) or 0
    if cdr > 0 and AR.lastRule[rule.id] and now - AR.lastRule[rule.id] < cdr then return "rule" end
    local cdp = tonumber(rule.cdPlayer) or 0
    local k = Key(rule, who)
    if cdp > 0 and AR.lastPlayer[k] and now - AR.lastPlayer[k] < cdp then return "player" end
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

-- Zufällige Antwort, Platzhalter {name} = Vorname des anderen, {me} = eigener Vorname
function AR.PickReply(rule, who)
    local list = {}
    for line in (tostring(rule.replies or "") .. "\n"):gmatch("([^\n]*)\n") do
        line = Trim(line)
        if line ~= "" then list[#list + 1] = line end
    end
    if #list == 0 then return nil end
    local text = list[math.random(#list)]
    local me = AR.FirstName(G.UnitName and G.UnitName("player") or "")
    text = text:gsub("{name}", (AR.FirstName(who):gsub("%%", "%%%%"))):gsub("{me}", (me:gsub("%%", "%%%%")))
    if #text > 255 then text = text:sub(1, 255) end
    return text
end

------------------------------------------------------------------------
-- Senden
------------------------------------------------------------------------

-- Rückgabe ok
function AR.Send(channel, text, target, bnID)
    if channel == "BN" then
        if bnID and type(G.BNSendWhisper) == "function" then return (pcall(G.BNSendWhisper, bnID, text)) end
        if FW.ChatLog and FW.ChatLog.BNSend then return FW.ChatLog.BNSend(target, text) end
        return false
    end
    if type(G.SendChatMessage) ~= "function" then return false end
    if channel == "WHISPER" then
        return (pcall(G.SendChatMessage, text, "WHISPER", nil, target))
    end
    return (pcall(G.SendChatMessage, text, channel))
end

-- Eine Antwort wirklich ausführen (nach den Prüfungen)
function AR.Fire(rule, who, channel, msg, extra)
    local text = AR.PickReply(rule, who)
    if not text then return false, "noreply" end
    local now = AR.Now()
    AR.lastRule[rule.id] = now
    AR.lastPlayer[Key(rule, who)] = now
    AR.sent[#AR.sent + 1] = now
    local k = Key(rule, who)
    AR.counts[k] = (AR.counts[k] or 0) + 1
    local delay = AR.DELAY or 1.2
    local function Go()
        local ok = AR.Send(channel, text, who, extra and extra.bnID)
        AR.Log({ t = AR.Clock(), rule = rule.name, who = who, src = channel, msg = tostring(msg or ""):sub(1, 140),
            reply = text, ok = ok and true or false })
    end
    if delay > 0 and G.C_Timer and G.C_Timer.After then G.C_Timer.After(delay, Go) else Go() end
    -- Ignorieren nach N Antworten (nicht bei Battle.net)
    local limit = tonumber(rule.ignoreAfter) or 0
    if limit > 0 and channel ~= "BN" and AR.counts[k] >= limit and not AR.asked[AR.Lower(who)] then
        AR.asked[AR.Lower(who)] = true
        if AR.AskIgnore then AR.AskIgnore(who, rule) end
    end
    if rule.report and AR.OpenReport then AR.OpenReport(who, extra) end
    return true, text
end

------------------------------------------------------------------------
-- Eingang: Chatnachricht
------------------------------------------------------------------------

function AR.IsSelf(who, guid)
    if guid and G.UnitGUID and guid == G.UnitGUID("player") then return true end
    local me = G.UnitName and G.UnitName("player")
    if not who or not me then return false end
    local w = AR.Lower(who)
    me = AR.Lower(me)
    if w == me then return true end
    local full = FW.Whisper and FW.Whisper.SelfName and FW.Whisper.SelfName()
    if full and w == AR.Lower(full) then return true end
    return false
end

-- event: Name des Chat-Ereignisses; Rückgabe: Liste der ausgeführten Regeln (für Tests)
function AR.OnChat(event, text, sender, flags, lineID, guid, bnID)
    local def = AR.EVENTS[event]
    text, sender = Str(text), Str(sender)
    if not def or not text or not sender then return {} end
    AR.Remember(def.src, sender, text, lineID, guid)
    local d = AR.DB()
    if not d.on then return {} end
    if flags == "GM" or flags == "DEV" or flags == "GUIDE" then return {} end
    if def.src ~= "BN" and AR.IsSelf(sender, guid) then return {} end
    local fired = {}
    for _, r in ipairs(d.rules) do
        if r.on and (r.kind or "chat") == "chat" and r.src and r.src[def.src] and AR.CondOK(r) and AR.Matches(r, text)
            and not AR.Cooldown(r, sender) then
            local ok = AR.Fire(r, sender, def.reply, text, { lineID = lineID, guid = guid, bnID = bnID })
            if ok then fired[#fired + 1] = r.id end
        end
    end
    return fired
end

------------------------------------------------------------------------
-- Eingang: Buff von einem anderen Spieler
------------------------------------------------------------------------

AR.lastBuff = {}

-- who: voller Name des Spielers, spell: Name des Zaubers
function AR.OnBuff(who, spell, guid)
    who = Str(who)
    if not who or AR.IsSelf(who, guid) then return {} end
    local now = AR.Now()
    local bk = AR.Lower(who) .. "|" .. tostring(spell)
    if AR.lastBuff[bk] and now - AR.lastBuff[bk] < 3 then return {} end
    AR.lastBuff[bk] = now
    local d = AR.DB()
    if not d.on then return {} end
    local fired = {}
    for _, r in ipairs(d.rules) do
        if r.on and r.kind == "buff" and AR.CondOK(r) and AR.Matches(r, spell or "") and not AR.Cooldown(r, who) then
            local ch = "WHISPER"
            if r.buffReply == "GROUP" then
                ch = (AR.Env.raid() and "RAID") or (AR.Env.group() and "PARTY") or "WHISPER"
            end
            local ok = AR.Fire(r, who, ch, spell, { guid = guid })
            if ok then fired[#fired + 1] = r.id end
        end
    end
    return fired
end

-- Voller Name einer Einheit (Forever: Vor- und Nachname; UnitName liefert nur den Vornamen, F-20)
function AR.UnitFull(unit)
    if not unit then return nil end
    local first, second
    if G.UnitFullName then first, second = G.UnitFullName(unit) end
    first, second = Str(first), Str(second)
    if first and second and second ~= "" then
        if G.UnitIsPlayer and G.UnitIsPlayer(unit) and not second:find("%-") then return first .. " " .. second end
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

-- Ersatz über den Kampflog, falls UNIT_AURA keine Quelle liefert
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

-- Zeilen, an denen who beteiligt war (von ihm oder eigene Flüster an ihn)
function AR.LinesOf(who)
    local out, w, now = {}, AR.Lower(who), AR.Now()
    local wf = AR.Lower(AR.FirstName(who))
    for _, e in ipairs(AR.buffer) do
        local ew = AR.Lower(e.who)
        if now - e.t <= AR.BUFFER_SECONDS and (ew == w or AR.Lower(AR.FirstName(e.who)) == wf and ew:find(wf, 1, true) == 1) then
            out[#out + 1] = e
        end
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
-- Ignorieren und Melden (ausführende Teile; die Fenster stehen in UI/AutoReply.lua)
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

-- Blizzards Melde-Fenster für die Person öffnen (abschicken musst du selbst). Rückgabe ok
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
end

AR.Setup()
