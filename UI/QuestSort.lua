-- Freewood-Core: Sortierung fuer Blizzards Questlog (Kartenfenster) und die Questverfolgung (Beobachtungsliste).
-- Questlog: nach dem Aufbau der Liste (QuestLogQuests_Update) werden die Quests unter jeder Gebiets-Ueberschrift neu geordnet:
--   die Plaetze (layoutIndex, Abstand oben) bleiben, nur die Quests wechseln die Plaetze. Kampagnen bleiben in Blizzards Reihenfolge.
--   Auswahl im Zahnrad-Menue des Questlogs ("Sortierung").
-- Questverfolgung: BuildQuestWatchInfos des Quest-Moduls liefert die Reihenfolge; wir sortieren das Ergebnis. Knopf in der Ueberschrift.
-- Sortierungen: Standard, Stufe auf-/absteigend, Name A-Z/Z-A, Fortschritt (fast fertig zuerst), Entfernung (naechste zuerst).
-- Quelle der Rahmen: Blizzard QuestMapFrame.lua / Blizzard_QuestObjectiveTracker.lua (Stand 11/2026). Alles mit pcall und Pruefung.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local QS = {}
FW.QuestSort = QS

QS.MODES = { "default", "levelAsc", "levelDesc", "nameAsc", "nameDesc", "progress", "distance" }

QS.DEFAULTS = { enabled = true, log = "default", tracker = "default" }

local function Opts()
    local s = FW.settings
    if type(s) ~= "table" then return QS.DEFAULTS end
    if type(s.questsort) ~= "table" then s.questsort = {} end
    local o = s.questsort
    for k, v in pairs(QS.DEFAULTS) do if o[k] == nil then o[k] = v end end
    return o
end
QS.Opts = Opts

local function Secret(v) return G.issecretvalue and G.issecretvalue(v) or false end

function QS.ModeName(m)
    return FW.L["QS_MODE_" .. string.upper(tostring(m))] or tostring(m)
end
local function ShortName(m)
    return FW.L["QS_SHORT_" .. string.upper(tostring(m))] or tostring(m)
end

------------------------------------------------------------------------
-- Sortierschluessel
------------------------------------------------------------------------
local function LogInfo(questID)
    local C = G.C_QuestLog
    local idx = C and C.GetLogIndexForQuestID and C.GetLogIndexForQuestID(questID)
    return idx and C.GetInfo and C.GetInfo(idx) or nil
end

function QS.Level(questID)
    local info = LogInfo(questID)
    local lv = info and info.level
    if type(lv) == "number" and not Secret(lv) then return lv end
    return 0
end

-- Fortschritt 0..1 (erledigt = 1)
function QS.Progress(questID)
    local C = G.C_QuestLog
    if not C then return 0 end
    if C.IsComplete and C.IsComplete(questID) then return 1 end
    local objs = C.GetQuestObjectives and C.GetQuestObjectives(questID)
    local got, need = 0, 0
    for _, o in ipairs(objs or {}) do
        local req = o.numRequired
        if type(req) == "number" and req > 0 then
            need = need + req
            got = got + math.min(o.numFulfilled or 0, req)
        end
    end
    return need > 0 and got / need or 0
end

-- Entfernung (Quadrat), unbekannt = sehr gross
function QS.Distance(questID)
    local C = G.C_QuestLog
    local d = C and C.GetDistanceSqToQuest and C.GetDistanceSqToQuest(questID)
    if type(d) == "number" and not Secret(d) then return d end
    return math.huge
end

-- items: { id =, title =, level =, pos = } -> sortiert (stabil ueber pos), liefert dieselbe Liste
function QS.SortItems(items, mode)
    if mode == nil or mode == "default" then return items end
    for _, it in ipairs(items) do
        it.lname = string.lower(it.title or "")
        if mode == "progress" then it.m = QS.Progress(it.id)
        elseif mode == "distance" then it.m = QS.Distance(it.id) end
    end
    local function Less(a, b)
        if mode == "levelAsc" then
            if a.level ~= b.level then return a.level < b.level end
            if a.lname ~= b.lname then return a.lname < b.lname end
        elseif mode == "levelDesc" then
            if a.level ~= b.level then return a.level > b.level end
            if a.lname ~= b.lname then return a.lname < b.lname end
        elseif mode == "nameAsc" then
            if a.lname ~= b.lname then return a.lname < b.lname end
        elseif mode == "nameDesc" then
            if a.lname ~= b.lname then return a.lname > b.lname end
        elseif mode == "progress" then
            if a.m ~= b.m then return a.m > b.m end
            if a.level ~= b.level then return a.level < b.level end
        elseif mode == "distance" then
            if a.m ~= b.m then return a.m < b.m end
        end
        return a.pos < b.pos
    end
    table.sort(items, Less)
    return items
end

------------------------------------------------------------------------
-- Questlog (Kartenfenster)
------------------------------------------------------------------------
-- entries: { kind = "header" | "quest" | "boundary", frame = Rahmen mit layoutIndex/topPadding/info }
-- Quests direkt hinter einer normalen Gebiets-Ueberschrift werden untereinander umsortiert.
function QS.ArrangeLog(entries, mode)
    if mode == nil or mode == "default" then return false end
    table.sort(entries, function(a, b) return (a.frame.layoutIndex or 0) < (b.frame.layoutIndex or 0) end)
    local groups, cur, last = {}, nil, nil
    for _, e in ipairs(entries) do
        local li = e.frame.layoutIndex
        if e.kind == "header" then
            cur = {}
            groups[#groups + 1] = cur
            last = li
        elseif e.kind == "boundary" then
            cur = nil
        elseif e.kind == "quest" then
            if cur and li and last and li == last + 1 then
                cur[#cur + 1] = e
                last = li
            else
                cur = nil
            end
        end
    end
    local changed = false
    for _, g in ipairs(groups) do
        if #g >= 2 then
            local slots, items = {}, {}
            for k, e in ipairs(g) do
                slots[k] = { e.frame.layoutIndex, e.frame.topPadding }
                local info = e.frame.info or {}
                local id = e.frame.questID or info.questID
                local lv = info.level
                if type(lv) ~= "number" or Secret(lv) then lv = id and QS.Level(id) or 0 end
                items[k] = { id = id, title = info.title, level = lv, pos = k, e = e }
            end
            QS.SortItems(items, mode)
            for k, it in ipairs(items) do
                if it.pos ~= k then changed = true end
                it.e.frame.layoutIndex = slots[k][1]
                it.e.frame.topPadding = slots[k][2]
            end
        end
    end
    return changed
end

local function SortLog()
    local o = Opts()
    if not o.enabled or o.log == "default" then return end
    local sf = G.QuestScrollFrame
    if not sf or not sf.titleFramePool or not sf.headerFramePool or not sf.titleFramePool.EnumerateActive then return end
    local entries = {}
    for f in sf.headerFramePool:EnumerateActive() do entries[#entries + 1] = { kind = "header", frame = f } end
    for _, pn in ipairs({ "campaignHeaderFramePool", "campaignHeaderMinimalFramePool", "covenantCallingsHeaderFramePool" }) do
        local pool = sf[pn]
        if pool and pool.EnumerateActive then
            for f in pool:EnumerateActive() do entries[#entries + 1] = { kind = "boundary", frame = f } end
        end
    end
    for f in sf.titleFramePool:EnumerateActive() do entries[#entries + 1] = { kind = "quest", frame = f } end
    if QS.ArrangeLog(entries, o.log) and sf.Contents and sf.Contents.Layout then sf.Contents:Layout() end
end

local function HookLog()
    if QS.logHooked or not G.QuestLogQuests_Update or not G.hooksecurefunc then return end
    QS.logHooked = true
    G.hooksecurefunc("QuestLogQuests_Update", function() pcall(SortLog) end)
end

-- Zahnrad-Menue des Questlogs: Untermenue "Sortierung"
local function HookMenu()
    if QS.menuHooked or not (G.Menu and G.Menu.ModifyMenu) then return end
    QS.menuHooked = true
    pcall(G.Menu.ModifyMenu, "MENU_QUEST_MAP_FRAME_SETTINGS", function(_, root)
        if not Opts().enabled or not root or not root.CreateRadio then return end
        if root.CreateDivider then root:CreateDivider() end
        if root.CreateTitle then root:CreateTitle(FW.L.QS_LOG) end
        for _, m in ipairs(QS.MODES) do
            local mode = m
            root:CreateRadio(QS.ModeName(mode),
                function() return Opts().log == mode end,
                function() Opts().log = mode; QS.Refresh() end)
        end
    end)
end

------------------------------------------------------------------------
-- Questverfolgung (Beobachtungsliste)
------------------------------------------------------------------------
local function QuestOf(info) return info and info.quest end

-- infos: { { quest =, index = } ... } wie von BuildQuestWatchInfos; Aufrufer/Calling-Quests bleiben vorn
function QS.SortWatchInfos(infos, mode)
    if mode == nil or mode == "default" then return infos end
    local head, rest = {}, {}
    for _, info in ipairs(infos) do
        local q = QuestOf(info)
        local special = q and ((q.IsCalling and q:IsCalling()) or q.overridesSortOrder)
        if special then head[#head + 1] = info else rest[#rest + 1] = info end
    end
    local items = {}
    for k, info in ipairs(rest) do
        local q = QuestOf(info)
        local id = q and q.GetID and q:GetID()
        local info2 = id and LogInfo(id)
        items[k] = { id = id, title = (q and q.title) or (info2 and info2.title) or "", level = id and QS.Level(id) or 0, pos = k, info = info }
    end
    QS.SortItems(items, mode)
    local out = {}
    for _, info in ipairs(head) do out[#out + 1] = info end
    for _, it in ipairs(items) do out[#out + 1] = it.info end
    return out
end

-- Reihenfolge nach einer Liste von Quest-IDs (unbekannte hinten, in ihrer Reihenfolge)
function QS.OrderByIds(infos, ids)
    local pos = {}
    for k, id in ipairs(ids or {}) do pos[id] = k end
    local items = {}
    for k, info in ipairs(infos) do
        local q = QuestOf(info)
        local id = q and q.GetID and q:GetID()
        items[k] = { info = info, p = (id and pos[id]) or (100000 + k) }
    end
    table.sort(items, function(a, b) return a.p < b.p end)
    local out = {}
    for k, it in ipairs(items) do out[k] = it.info end
    return out
end

local function IdsOf(infos)
    local ids = {}
    for _, info in ipairs(infos) do
        local q = QuestOf(info)
        local id = q and q.GetID and q:GetID()
        if id then ids[#ids + 1] = id end
    end
    return ids
end

-- Solange Blizzard abgegebene Quests noch mit Animation anzeigt (zwischengespeicherte Bloecke), bleibt die letzte Reihenfolge
-- bestehen: Blizzards Zwischenspeicher setzt die Bloecke nach der alten Reihenfolge ein, eine neue Sortierung dazwischen
-- fuehrt zu uebereinanderliegenden Zeilen.
local SETTLE = 2.5     -- Sekunden nach Abgabe bis zum sauberen Neuaufbau
local DIST_TICK = 5    -- Sekunden: Entfernungs-Sortierung auf Aenderung pruefen

local function HookTracker()
    local t = G.QuestObjectiveTracker
    if not t or t.fwSortHooked or type(t.BuildQuestWatchInfos) ~= "function" then return end
    t.fwSortHooked = true
    local orig = t.BuildQuestWatchInfos
    t.BuildQuestWatchInfos = function(self, ...)
        local infos = orig(self, ...)
        local o = Opts()
        if not o.enabled or o.tracker == "default" or type(infos) ~= "table" then return infos end
        if (self.numCachedBlocks or 0) > 0 and QS.lastIds then
            local ok, res = pcall(QS.OrderByIds, infos, QS.lastIds)
            return ok and res or infos
        end
        local ok, res = pcall(QS.SortWatchInfos, infos, o.tracker)
        if ok and type(res) == "table" then
            QS.lastIds = IdsOf(res)
            return res
        end
        return infos
    end
end

-- Nach Abgabe/Entfernen: erst nach der Animation sauber neu aufbauen
local settlePending = false
local function Settle()
    if settlePending or not G.C_Timer or not G.C_Timer.After then return end
    settlePending = true
    G.C_Timer.After(SETTLE, function() settlePending = false; pcall(QS.Refresh) end)
end
QS.Settle = Settle
FW:RegisterEvent("QUEST_TURNED_IN", function() Settle() end)
FW:RegisterEvent("QUEST_REMOVED", function() Settle() end)

-- Entfernung aendert sich beim Laufen: Reihenfolge regelmaessig pruefen, nur bei Aenderung neu aufbauen
function QS.DistanceTick()
    local o = Opts()
    local t = G.QuestObjectiveTracker
    if not o.enabled or o.tracker ~= "distance" or not t or not t.BuildQuestWatchInfos then return false end
    if (t.numCachedBlocks or 0) > 0 then return false end
    local before = table.concat(QS.lastIds or {}, ",")
    local ok = pcall(t.BuildQuestWatchInfos, t)
    local after = table.concat(QS.lastIds or {}, ",")
    if ok and before ~= after and t.MarkDirty then pcall(t.MarkDirty, t); return true end
    return false
end

local function StartTicker()
    if QS.ticker or not G.C_Timer or not G.C_Timer.NewTicker then return end
    QS.ticker = G.C_Timer.NewTicker(DIST_TICK, function() pcall(QS.DistanceTick) end)
end

local function NextMode(cur, step)
    local n = #QS.MODES
    for i, m in ipairs(QS.MODES) do
        if m == cur then return QS.MODES[((i - 1 + step) % n) + 1] end
    end
    return QS.MODES[1]
end

local function UpdateButton()
    local b = QS.button
    if not b then return end
    local o = Opts()
    b:SetShown(o.enabled and true or false)
    b.text:SetText(string.format(FW.L.QS_BUTTON, ShortName(o.tracker)))
end

local function BuildButton()
    if QS.button then return end
    local t = G.QuestObjectiveTracker
    local h = t and t.Header
    if not h or not G.CreateFrame then return end
    local b = G.CreateFrame("Button", nil, h)
    b:SetSize(112, 16)
    if h.MinimizeButton then b:SetPoint("RIGHT", h.MinimizeButton, "LEFT", -6, 0) else b:SetPoint("RIGHT", h, "RIGHT", -24, 0) end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints()
    b.text:SetJustifyH("RIGHT")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, btn)
        local o = Opts()
        o.tracker = NextMode(o.tracker, btn == "RightButton" and -1 or 1)
        QS.Refresh()
    end)
    b:SetScript("OnEnter", function(self)
        if not G.GameTooltip then return end
        G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        G.GameTooltip:SetText(FW.L.QS_TRACKER)
        local cur = Opts().tracker
        for _, m in ipairs(QS.MODES) do
            if m == cur then G.GameTooltip:AddLine("> " .. QS.ModeName(m), 1, 0.82, 0.2) else G.GameTooltip:AddLine("   " .. QS.ModeName(m), 0.8, 0.8, 0.8) end
        end
        G.GameTooltip:AddLine(FW.L.QS_BUTTON_TIP, 0.6, 0.6, 0.6)
        G.GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    QS.button = b
    UpdateButton()
end

-- alles neu zeichnen lassen
function QS.Refresh()
    UpdateButton()
    if G.QuestLogQuests_Update then pcall(G.QuestLogQuests_Update) end
    local t = G.QuestObjectiveTracker
    if t and t.MarkDirty then pcall(t.MarkDirty, t) end
    FW:Fire("QUESTSORT_CHANGED")
end

local function Setup()
    pcall(HookLog)
    pcall(HookMenu)
    pcall(HookTracker)
    pcall(StartTicker)
    pcall(BuildButton)
    return QS.logHooked and QS.menuHooked and QS.button ~= nil
end
QS.Setup = Setup

local function Retry(n)
    if not Setup() and n > 0 and G.C_Timer then G.C_Timer.After(2, function() Retry(n - 1) end) end
end

FW:RegisterEvent("PLAYER_LOGIN", function() Retry(6) end)
FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if G.C_Timer then G.C_Timer.After(2, function() Retry(4) end) end
end)
FW:RegisterEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_ObjectiveTracker" or name == "Blizzard_UIPanels_Game" then Retry(2) end
end)

------------------------------------------------------------------------
-- Einstellungen: Reiter "Interface"
------------------------------------------------------------------------
if UI and UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("questsort", {
        category = "quest",
        order = 120,
        height = 230,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.QS_TITLE)
            local refreshers = {}
            stack:Add(UI.CreateCheckbox(f, L.QS_ENABLE,
                function() return Opts().enabled == true end,
                function(v) Opts().enabled = v and true or false; QS.Refresh() end), { fit = true })
            stack:Add(UI.CreateLabel(f, L.QS_HINT, { size = 11, color = "textDim" }), { height = 42, gap = 6 })
            local function ModeRow(label, key)
                stack:Add(UI.CreateLabel(f, label, { size = 12 }), { height = 16, gap = 8 })
                local dd = UI.CreateDropdown(f, 280, 22, {
                    getOptions = function()
                        local list = {}
                        for _, m in ipairs(QS.MODES) do list[#list + 1] = { value = m, text = QS.ModeName(m) } end
                        return list
                    end,
                    textOf = QS.ModeName,
                    onChange = function(v) if v then Opts()[key] = v; QS.Refresh() end end,
                })
                stack:Add(dd, { height = 26, gap = 2 })
                refreshers[#refreshers + 1] = function() dd:SetValue(Opts()[key]) end
                dd:SetValue(Opts()[key])
            end
            ModeRow(L.QS_LOG, "log")
            ModeRow(L.QS_TRACKER, "tracker")
            f.fwRefreshers = refreshers
            FW:On("QUESTSORT_CHANGED", function() for _, r in ipairs(refreshers) do r() end end, f)
            return f
        end,
        refresh = function(frame)
            if frame and frame.fwRefreshers then for _, r in ipairs(frame.fwRefreshers) do r() end end
        end,
    })
end
