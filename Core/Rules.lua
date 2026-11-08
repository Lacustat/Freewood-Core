-- Freewood-Core: Herausforderungen, Engine
--
-- Eine Herausforderung besteht aus Zielen (alle muessen erreicht werden), Regeln (ein Verstoss beendet sie als "gescheitert"),
-- Warnungen (Text zu einem Anlass) und einer Belohnung (Punkte, Titel, Text). Erstellt wird sie im Creator (Satz-Editor),
-- gespielt im Reiter "Herausforderungen". Gescheitert ist gescheitert: Hinweis, dann ist sie beendet; ein neuer Versuch ist moeglich.
-- Das ist Ehrensache: Ein Addon kann Verstoesse nur erkennen, nicht verhindern.
--
-- Daten:
--   Account (Modul "Rules"): db.defs[id] = Definition, db.done[id] = { by, at }, db.titles[id] = Titeltext
--   Charakter (FW.chardb.rules): act[id] = Zustand der laufenden Herausforderung, hist[id] = { st, at, reason, tries }
--
-- Inhalt
--   1. Speicher und Verwaltung
--   2. Welt und Auswertung
--   3. Ereignisse
--   4. Titel und Punkte
--   5. Eigene Erfolge
--   6. Partner
-- UNGEPRUEFT im Spiel (Forever).

local ADDON, FW = ...

local R = FW.Rules
if not R then return end

local G = _G

------------------------------------------------------------------------
-- 1. Speicher und Verwaltung
------------------------------------------------------------------------

if FW.NewModule then
    R.module = FW:NewModule("Rules", { defaults = { defs = {}, seq = 0, done = {}, titles = {}, ach = {}, aseq = 0 } })
end

function R.Db() return R.module and R.module.db or nil end

function R.Cdb()
    local c = FW.chardb
    if type(c) ~= "table" then return nil end
    c.rules = c.rules or { act = {}, hist = {} }
    c.rules.act = c.rules.act or {}
    c.rules.hist = c.rules.hist or {}
    return c.rules
end

function R.Now() return G.time and G.time() or 0 end

local function Clean(v)
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    return v
end

local function Say(text)
    if FW.Print then FW:Print(text) end
end

function R.Get(id)
    local db = R.Db()
    return db and db.defs[id] or nil
end

-- Neue oder geaenderte eigene Definition speichern. Rueckgabe: id oder nil, Fehlerschluessel
function R.Save(def, id)
    local db = R.Db()
    if not db then return nil, "RV_DEF" end
    local clean, err = R.Validate(def)
    if not clean then return nil, err end
    if id and db.defs[id] and db.defs[id].src ~= "mine" then id = nil end
    if not id then
        db.seq = (db.seq or 0) + 1
        id = "L" .. db.seq
    end
    clean.id = id
    clean.src = "mine"
    if clean.author == "" then clean.author = (FW.Stats and FW.Stats.Key and FW.Stats.Key() or ""):gsub("%-.*$", "") end
    db.defs[id] = clean
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return id
end

-- Von anderen erhalten (Brett, Import): immer gegen die feste Liste geprueft; src = "board" | "import"
function R.Import(def, id, src)
    local db = R.Db()
    if not db then return nil, "RV_DEF" end
    if type(id) ~= "string" or id == "" or #id > 60 then return nil, "RV_DEF" end
    local clean, err = R.Validate(def)
    if not clean then return nil, err end
    if db.defs[id] and db.defs[id].src == "mine" then return nil, "RV_DEF" end
    clean.id = id
    clean.src = src or "import"
    db.defs[id] = clean
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return id
end

function R.Delete(id)
    local db, c = R.Db(), R.Cdb()
    if not db or not db.defs[id] then return false end
    db.defs[id] = nil
    if c then c.act[id] = nil end
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return true
end

-- Liste aller Definitionen, eigene zuerst, dann nach Name
function R.List()
    local db = R.Db()
    local out = {}
    for id, def in pairs((db and db.defs) or {}) do out[#out + 1] = def end
    table.sort(out, function(a, b)
        if (a.src == "mine") ~= (b.src == "mine") then return a.src == "mine" end
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

-- Status fuer den angemeldeten Charakter: "active" | "done" | "failed" | "new"
function R.Status(id)
    local c = R.Cdb()
    if not c then return "new" end
    if c.act[id] then return "active", c.act[id] end
    local h = c.hist[id]
    if h then return h.st, h end
    return "new"
end

function R.ActiveCount()
    local c, n = R.Cdb(), 0
    for _ in pairs((c and c.act) or {}) do n = n + 1 end
    return n
end

------------------------------------------------------------------------
-- 2. Welt und Auswertung
------------------------------------------------------------------------

-- Was die Auswertung von der Spielwelt braucht (in Tests ersetzbar ueber R.worldFn)
function R.World()
    if R.worldFn then return R.worldFn() end
    local w = { level = 1, inGroup = false, groupSize = 1, zone = "", subzone = "", instName = nil, instId = nil }
    local function Call(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
        if not ok then return nil end
        return Clean(a), Clean(b), Clean(c), Clean(d), Clean(e), Clean(f), Clean(g), Clean(h)
    end
    w.level = tonumber(Call(G.UnitLevel, "player")) or 1
    local grouped = Call(G.IsInGroup) or Call(G.IsInRaid)
    w.inGroup = grouped and grouped ~= 0 and true or false
    local n = tonumber(Call(G.GetNumGroupMembers)) or 1
    w.groupSize = w.inGroup and math.max(2, n) or 1
    w.zone = Call(G.GetRealZoneText) or Call(G.GetZoneText) or ""
    w.subzone = Call(G.GetSubZoneText) or ""
    local name, typ, _, _, _, _, _, id = Call(G.GetInstanceInfo)
    if typ == "party" or typ == "raid" then w.instName, w.instId = name, tonumber(id) end
    return w
end

function R.ItemCount(id)
    local ok, n = pcall(function() return G.GetItemCount and G.GetItemCount(id) or 0 end)
    return ok and tonumber(n) or 0
end

function R.CounterValue(key)
    local rec = FW.Stats and FW.Stats.Rec and FW.Stats.Rec(false)
    return rec and rec.c and tonumber(rec.c[key]) or 0
end

-- Fortschritt eines Ziels: aktuell, gesamt
function R.GoalProgress(g, i, st, w)
    st = st or { prog = {}, base = {} }
    w = w or R.World()
    local t = g.type
    if t == "kill" then return math.min(st.prog[i] or 0, g.count), g.count
    elseif t == "level" then return math.min(w.level, g.n), g.n
    elseif t == "quest" or t == "zone" then return st.prog[i] == true and 1 or 0, 1
    elseif t == "item" then return math.min(R.ItemCount(g.id), g.count), g.count
    elseif t == "counter" then return math.min(math.max(0, R.CounterValue(g.key) - (st.base[g.key] or 0)), g.n), g.n
    end
    return 0, 1
end

local function GoalsDone(def, st, w)
    for i, g in ipairs(def.goals) do
        local cur, tot = R.GoalProgress(g, i, st, w)
        if cur < tot then return false end
    end
    return true
end

-- Verstoss gegen eine Regel? Rueckgabe: Schluessel des Grundes, Zahl dazu
function R.RuleBroken(r, st, w, def)
    local t = r.type
    if t == "nogroup" then
        if w.inGroup then return "nogroup" end
    elseif t == "groupmax" then
        if w.groupSize > r.n then return "groupmax", r.n end
    elseif t == "levelbelow" then
        if w.level >= r.n then return "levelbelow", r.n end
    elseif t == "deathsmax" then
        if (st.deaths or 0) > r.n then return "deathsmax", r.n end
    elseif t == "timelimit" then
        if R.Now() - (st.t0 or R.Now()) > r.n * 60 then return "timelimit", r.n end
    elseif t == "stayin" then
        local inside = R.InstanceMatch(r, w)
        if inside then st.inside, st.outAt = true, nil
        elseif st.inside then
            st.outAt = st.outAt or R.Now()
            if R.Now() - st.outAt >= 5 then return "stayin" end
        end
    elseif t == "partner" then
        if R.PartnerBroken and R.PartnerBroken(st, w, def) then return "partner" end
    end
    return nil
end

local function TimeLimit(def)
    for _, r in ipairs(def.rules or {}) do if r.type == "timelimit" then return r.n end end
    return nil
end

local function WarnDue(wr, st, w, def)
    local t = wr.type
    if t == "level" then return w.level >= wr.n
    elseif t == "zone" then return R.ZoneMatch(wr, w)
    elseif t == "timeleft" then
        local lim = TimeLimit(def)
        if not lim then return false end
        return (lim * 60 - (R.Now() - (st.t0 or R.Now()))) <= wr.n * 60
    end
    return false
end

-- Kann die Herausforderung jetzt angenommen werden? Rueckgabe: true oder false, Schluessel
function R.CanAccept(id)
    local def = R.Get(id)
    if not def then return false, "CH_NO_DEF" end
    local status = R.Status(id)
    if status == "active" then return false, "CH_ALREADY" end
    if status == "done" then return false, "CH_ALREADY_DONE" end
    if R.ActiveCount() >= R.LIMITS.active then return false, "CH_TOO_MANY" end
    local w = R.World()
    local st = { prog = {}, base = {}, t0 = R.Now(), deaths = 0 }
    for _, r in ipairs(def.rules) do
        if r.type ~= "stayin" and r.type ~= "partner" then
            local why = R.RuleBroken(r, st, w, def)
            if why then return false, "CH_BROKEN_" .. why, r.n end
        end
    end
    return true
end

function R.Notify(kind, def, text)
    if kind == "warn" or kind == "failed" or kind == "done" or kind == "accepted" then
        Say(string.format("[%s] %s", def.name, text or ""))
    end
    if R.OnNotify then pcall(R.OnNotify, kind, def, text) end
    FW:Fire("FW_CHALLENGE_" .. kind:upper(), def.id, text)
end

function R.Accept(id)
    local ok, why, n = R.CanAccept(id)
    if not ok then return false, why, n end
    local def, c = R.Get(id), R.Cdb()
    if not c then return false, "CH_NO_DEF" end
    local st = { prog = {}, base = {}, t0 = R.Now(), deaths = 0, warned = {} }
    for _, g in ipairs(def.goals) do
        if g.type == "counter" then st.base[g.key] = R.CounterValue(g.key) end
    end
    c.act[id] = st
    local h = c.hist[id]
    c.hist[id] = { st = "active", at = R.Now(), tries = ((h and h.tries) or 0) + 1 }
    R.Notify("accepted", def, string.format(FW.L.CH_ACCEPTED, def.name))
    for i, wr in ipairs(def.warns) do
        if wr.type == "start" then st.warned[i] = true; R.Notify("warn", def, wr.text) end
    end
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    R.Step()
    return true
end

function R.Abandon(id)
    local c = R.Cdb()
    if not c or not c.act[id] then return false end
    c.act[id] = nil
    local h = c.hist[id]
    if h then h.st = "new" end
    c.hist[id] = nil
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return true
end

function R.Fail(id, why, n)
    local c, def = R.Cdb(), R.Get(id)
    if not c or not c.act[id] then return false end
    c.act[id] = nil
    if def and why ~= "partner" and R.HasPartnerRule(def) then R.PartnerSend("F|" .. R.DefHash(def)) end
    local h = c.hist[id] or { tries = 1 }
    h.st, h.at, h.reason = "failed", R.Now(), why
    c.hist[id] = h
    if def then
        local reason = FW.L["RF_" .. tostring(why)]
        local ok, text = pcall(string.format, reason, n or 0)
        R.Notify("failed", def, string.format(FW.L.CH_FAILED, def.name, ok and text or reason))
    end
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return true
end

function R.Complete(id)
    local c, db, def = R.Cdb(), R.Db(), R.Get(id)
    if not c or not c.act[id] or not def then return false end
    c.act[id] = nil
    local h = c.hist[id] or { tries = 1 }
    h.st, h.at, h.reason = "done", R.Now(), nil
    c.hist[id] = h
    if db then
        local first = not db.done[id]
        db.done[id] = db.done[id] or { by = FW.Stats and FW.Stats.Key and FW.Stats.Key() or "?", at = R.Now() }
        if def.reward and def.reward.title and def.reward.title ~= "" then db.titles[id] = def.reward.title end
        local pts = def.reward and def.reward.points or 0
        local text = string.format(FW.L.CH_DONE, def.name, first and pts or 0)
        if def.reward and def.reward.text and def.reward.text ~= "" then text = text .. "  " .. def.reward.text end
        R.Notify("done", def, text)
    end
    FW:Fire("FW_CHALLENGES_CHANGED", id)
    return true
end

-- Eine laufende Herausforderung auswerten
function R.EvalOne(id, st, w)
    local def = R.Get(id)
    if not def then
        local c = R.Cdb()
        if c then c.act[id] = nil end
        return
    end
    st.prog, st.base, st.warned = st.prog or {}, st.base or {}, st.warned or {}
    for i, g in ipairs(def.goals) do
        if g.type == "zone" and not st.prog[i] and R.ZoneMatch(g, w) then st.prog[i] = true end
    end
    if GoalsDone(def, st, w) and (not R.HasPartnerRule(def) or st.partnerSeen) then R.Complete(id); return end
    R.PartnerPing(def, st, w)
    for _, r in ipairs(def.rules) do
        local why, n = R.RuleBroken(r, st, w, def)
        if why then R.Fail(id, why, n); return end
    end
    for i, wr in ipairs(def.warns) do
        if wr.type ~= "start" and not st.warned[i] and WarnDue(wr, st, w, def) then
            st.warned[i] = true
            R.Notify("warn", def, wr.text)
        end
    end
end

function R.Step()
    local c = R.Cdb()
    if not c then return end
    local ids = {}
    for id in pairs(c.act) do ids[#ids + 1] = id end
    if #ids == 0 then return end
    table.sort(ids)
    local w = R.World()
    for _, id in ipairs(ids) do
        local st = c.act[id]
        if st then pcall(R.EvalOne, id, st, w) end
    end
end

------------------------------------------------------------------------
-- 3. Ereignisse
------------------------------------------------------------------------

local function EachActive(fn)
    local c = R.Cdb()
    if not c then return end
    for id, st in pairs(c.act) do
        local def = R.Get(id)
        if def then fn(id, st, def) end
    end
end

function R.OnKill(name, unitId)
    local w
    EachActive(function(id, st, def)
        for i, g in ipairs(def.goals) do
            if g.type == "kill" and unitId and g.id == unitId then
                w = w or R.World()
                if not g.inst or R.InstanceMatch(g, w) then
                    st.prog[i] = math.min((st.prog[i] or 0) + 1, g.count)
                end
            end
        end
    end)
    R.Step()
end

function R.OnQuest(questId)
    EachActive(function(id, st, def)
        for i, g in ipairs(def.goals) do
            if g.type == "quest" and g.id == questId then st.prog[i] = true end
        end
    end)
    R.Step()
end

function R.OnDeath()
    EachActive(function(id, st) st.deaths = (st.deaths or 0) + 1 end)
    R.Step()
end

local owner = {}
local acc = 0
local ticker = G.CreateFrame and G.CreateFrame("Frame") or nil
if ticker and ticker.SetScript then
    ticker:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + (elapsed or 0)
        if acc < 2 then return end
        acc = 0
        if R.ActiveCount() > 0 then pcall(R.Step) end
    end)
end

if R.module then
    function R.module:OnEnable()
        local function On(ev, fn) FW:RegisterEvent(ev, fn, owner) end
        R.SyncAch()
        On("PLAYER_LEVEL_UP", function() R.Step() end)
        On("ZONE_CHANGED_NEW_AREA", function() R.Step() end)
        On("ZONE_CHANGED", function() R.Step() end)
        On("PLAYER_ENTERING_WORLD", function() R.Step() end)
        On("GROUP_ROSTER_UPDATE", function()
            local c = R.Cdb()
            for _, st in pairs((c and c.act) or {}) do st.lastPing = nil end
            R.Step()
        end)
        On("CHAT_MSG_ADDON", function(_, prefix, text, _, sender) R.OnPartnerMessage(prefix, text, sender) end)
        On("BAG_UPDATE_DELAYED", function() R.Step() end)
        On("PLAYER_DEAD", function() R.OnDeath() end)
        On("QUEST_TURNED_IN", function(_, questId) R.OnQuest(Clean(questId)) end)
        if FW.On then
            FW:On("CODEX_KILL", function(_, name, uid) R.OnKill(Clean(name), uid) end, owner)
            FW:On("QUEST_TURNED_IN_LOCAL", function(_, qid) R.OnQuest(qid) end, owner)
        end
    end
end

------------------------------------------------------------------------
-- 4. Titel und Punkte
------------------------------------------------------------------------

-- Titel aus Herausforderungen: { { key = "c:L1", text = "..." } }
function R.UnlockedTitles()
    local db, out = R.Db(), {}
    for id, text in pairs((db and db.titles) or {}) do out[#out + 1] = { key = "c:" .. id, text = text } end
    table.sort(out, function(a, b) return a.text < b.text end)
    return out
end

function R.TitleText(key)
    local db = R.Db()
    local id = type(key) == "string" and key:match("^c:(.+)$")
    return id and db and db.titles[id] or nil
end

-- Summe der Punkte aller (account-weit) abgeschlossenen Herausforderungen
function R.Points()
    local db, pts, n = R.Db(), 0, 0
    for id in pairs((db and db.done) or {}) do
        local def = db.defs[id]
        n = n + 1
        pts = pts + (def and def.reward and def.reward.points or 0)
    end
    return pts, n
end

------------------------------------------------------------------------
-- 5. Eigene Erfolge
--   Gespeichert im Account (db.ach[id]); in den Katalog der Erfolge (Kategorie "Eigene") eingehaengt. Zaehler kommen aus der Statistik.
------------------------------------------------------------------------

local function AchDb()
    local db = R.Db()
    if not db then return nil end
    db.ach = db.ach or {}
    return db
end

-- Katalog neu aufbauen: alle eigenen Eintraege entfernen, aus den Definitionen neu anlegen
function R.SyncAch()
    local A, db = FW.Ach, AchDb()
    if not A or not A.CATALOG or not db then return end
    local D = A.CATALOG
    for i = #D, 1, -1 do
        if D[i].custom then table.remove(D, i) end
    end
    local ids = {}
    for id in pairs(db.ach) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local d = db.ach[id]
        local key = d.key
        local e = {
            id = "u_" .. id, cat = "custom", custom = true,
            m = function(r) return tonumber(((r and r.c) or {})[key]) or 0 end,
            t = d.t, de = { d.name, d.desc }, en = { d.name, d.desc },
            title = (d.title and d.title ~= "") and { d.title, d.title } or nil,
            src = d.src, author = d.author,
        }
        D[#D + 1] = e
    end
    A.BY_ID = {}
    for i, e in ipairs(D) do e.idx = i; A.BY_ID[e.id] = e end
end

function R.GetAch(id)
    local db = AchDb()
    return db and db.ach[id] or nil
end

function R.ListAch()
    local db, out = AchDb(), {}
    for id, d in pairs((db and db.ach) or {}) do out[#out + 1] = d end
    table.sort(out, function(a, b)
        if (a.src == "mine") ~= (b.src == "mine") then return a.src == "mine" end
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

local function AfterAchChange(id)
    R.SyncAch()
    if FW.Ach and FW.Ach.Check then pcall(FW.Ach.Check, true) end
    FW:Fire("FW_CHALLENGES_CHANGED", id)
end

function R.SaveAch(def, id)
    local db = AchDb()
    if not db then return nil, "RV_DEF" end
    local clean, err = R.ValidateAch(def)
    if not clean then return nil, err end
    if id and db.ach[id] and db.ach[id].src ~= "mine" then id = nil end
    if not id then
        db.aseq = (db.aseq or 0) + 1
        id = "A" .. db.aseq
    end
    clean.id, clean.src = id, "mine"
    if clean.author == "" then clean.author = (FW.Stats and FW.Stats.Key and FW.Stats.Key() or ""):gsub("%-.*$", "") end
    db.ach[id] = clean
    AfterAchChange(id)
    return id
end

function R.ImportAch(def, id, src)
    local db = AchDb()
    if not db then return nil, "RV_DEF" end
    if type(id) ~= "string" or id == "" or #id > 60 then return nil, "RV_DEF" end
    local clean, err = R.ValidateAch(def)
    if not clean then return nil, err end
    if db.ach[id] and db.ach[id].src == "mine" then return nil, "RV_DEF" end
    clean.id, clean.src = id, src or "import"
    db.ach[id] = clean
    AfterAchChange(id)
    return id
end

function R.DeleteAch(id)
    local db = AchDb()
    if not db or not db.ach[id] then return false end
    db.ach[id] = nil
    AfterAchChange(id)
    return true
end

------------------------------------------------------------------------
-- 6. Partner
--   Regel "nur mit Partner": Die Gruppe darf nur aus zwei Spielern bestehen, und der andere muss dieselbe Herausforderung gestartet haben.
--   Das merken beide ueber Addon-Nachrichten in der Gruppe ("A|Kennung" = ich habe sie, "F|Kennung" = ich bin gescheitert).
--   Ziele zaehlen erst, wenn der Partner mindestens einmal gemeldet hat. Scheitert einer, scheitern beide.
------------------------------------------------------------------------

local PREFIX = "FWChal1"
local PING_EVERY, PARTNER_SILENCE, NOGROUP_GRACE = 20, 90, 10

function R.HasPartnerRule(def)
    for _, r in ipairs((def and def.rules) or {}) do if r.type == "partner" then return true end end
    return false
end

-- Kurze Kennung der Herausforderung (gleicher Name und gleicher Inhalt ergibt dieselbe Kennung, auch bei Fremden)
function R.DefHash(def)
    local text = tostring(def.name) .. "|" .. R.Describe(def)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 99999989 end
    return string.format("%x", h)
end

function R.PartnerSend(text)
    if R.sendFn then return R.sendFn(text) end
    local api = G.C_ChatInfo
    if api and api.SendAddonMessage and G.IsInGroup and G.IsInGroup() then
        pcall(api.SendAddonMessage, PREFIX, text, "PARTY")
    end
end

function R.PartnerPing(def, st, w)
    if not R.HasPartnerRule(def) or not w.inGroup then return end
    if R.Now() - (st.lastPing or -1000) >= PING_EVERY then
        st.lastPing = R.Now()
        R.PartnerSend("A|" .. R.DefHash(def))
    end
end

function R.PartnerBroken(st, w, def)
    if w.groupSize > 2 then return true end
    if st.partnerFailed then return true end
    if st.partnerSeen then
        if not w.inGroup then
            st.noGroupAt = st.noGroupAt or R.Now()
            if R.Now() - st.noGroupAt >= NOGROUP_GRACE then return true end
        else
            st.noGroupAt = nil
        end
        if R.Now() - (st.partnerAt or R.Now()) > PARTNER_SILENCE then return true end
    end
    return false
end

local function SelfName()
    local n = G.UnitName and G.UnitName("player")
    return type(n) == "string" and n or nil
end

function R.OnPartnerMessage(prefix, text, sender)
    if prefix ~= PREFIX or type(text) ~= "string" or #text > 40 then return end
    sender = Clean(sender)
    if type(sender) ~= "string" then return end
    local plain = sender
    if G.Ambiguate then
        local ok, v = pcall(G.Ambiguate, sender, "none")
        if ok and v then plain = v end
    end
    if plain == SelfName() then return end
    local kind, hash = text:match("^(%u)|(%x+)$")
    if not kind or (kind ~= "A" and kind ~= "F") then return end
    local hit = false
    EachActive(function(id, st, def)
        if R.HasPartnerRule(def) and R.DefHash(def) == hash then
            if kind == "A" then
                if st.partner and st.partner ~= plain and st.partnerSeen then return end
                st.partner, st.partnerSeen, st.partnerAt = plain, true, R.Now()
            else
                if st.partner == plain or not st.partner then st.partnerFailed = true end
            end
            hit = true
        end
    end)
    if hit then R.Step() end
end

if G.C_ChatInfo and G.C_ChatInfo.RegisterAddonMessagePrefix then pcall(G.C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
