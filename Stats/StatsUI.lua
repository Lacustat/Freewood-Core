-- Freewood-Core: Statistik, Reiter
-- Zwei Unterreiter: "Charakter" (alle Zahlen des angemeldeten Charakters) und "Account" (Liste aller Charaktere plus Summe,
-- jeder Charakter einzeln aufrufbar). Die Zahlen stehen in Kategorien zum Auf- und Zuklappen (gemerkt je Account).
-- Knopf "Wegenetz anzeigen": zeigt das mit dem Charakter gelaufene Wegenetz (Freewood-Codex) auf der Weltkarte.

local ADDON, FW = ...

local UI = FW.UI
local Stats = FW.Stats
if not UI or not Stats then return end

local G = _G
local BTN_H, LIST_W, HEAD_H, LEFT_PAD = 26, 200, 24, 10
local VALUE_W = 190
local ROW_H = 18

local function Db() return Stats.Db() or { chars = {}, open = {} } end

local function CodexInfo()
    local C = FW.Codex
    if not C then return nil end
    local out = {}
    local ok, st = pcall(function() return C.Path and C.Path.Stats and C.Path.Stats() end)
    if ok and type(st) == "table" then out.cells, out.edges = st.cells, st.edges end
    local ok2, n = pcall(function() return C.Flight and C.Flight.Count and C.Flight.Count() end)
    if ok2 and type(n) == "number" then out.flights = n end
    out.kills = Stats.CodexKills and Stats.CodexKills(C)
    return (out.cells or out.flights or out.kills) and out or nil
end

local function ClassColor(class)
    local c = G.RAID_CLASS_COLORS and class and G.RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return UI.Color("text")
end

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    local mode = "char"                  -- "char" | "acct"
    local selected = nil                 -- Schluessel oder "ALL" (Account)
    local confirmKey

    ---------------- obere Leiste ----------------
    local subButtons = {}
    local function MakeSub(key, textKey, x, w)
        local b = UI.CreateButton(f, L[textKey], w, BTN_H, function()
            mode = key
            f.Refresh()
        end, "ghost")
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
        b.key = key
        subButtons[#subButtons + 1] = b
        return b
    end
    MakeSub("char", "STATS_SUB_CHAR", 0, 130)
    MakeSub("acct", "STATS_SUB_ACCOUNT", 136, 130)

    local pathButton = UI.CreateButton(f, "", 200, BTN_H, function()
        local PM = FW.Codex and FW.Codex.PathMap
        if PM and PM.Toggle then
            PM.Toggle()
            f.Refresh()
        else
            FW:Print(L.STATS_NEED_CODEX)
        end
    end, "default")
    pathButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    local allButton = UI.CreateButton(f, L.STATS_TOGGLE_ALL, 150, BTN_H, function()
        local open = Db().open
        local any = false
        for _, v in pairs(open) do if v then any = true end end
        f.openAll = not any
        for _, cat in ipairs(f.cats or {}) do open[cat.id] = f.openAll or nil end
        f.Render()
    end, "default")
    allButton:SetPoint("RIGHT", pathButton, "LEFT", -6, 0)

    ---------------- linke Liste (Account) ----------------
    local listScroll = UI.CreateScrollFrame(f)
    listScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 10))
    listScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, BTN_H + 8)
    listScroll:SetWidth(LIST_W)
    local listButtons = {}

    local removeButton = UI.CreateButton(f, L.STATS_REMOVE, LIST_W, BTN_H, function()
        if not selected or selected == "ALL" then return end
        if confirmKey ~= selected then
            confirmKey = selected
            f.Refresh()
            return
        end
        Db().chars[selected] = nil
        confirmKey, selected = nil, "ALL"
        f.Refresh()
    end, "default")
    removeButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)

    ---------------- rechts: Kategorien ----------------
    local scroll = UI.CreateScrollFrame(f)
    local child = scroll.child
    local heads = {}

    local function Head(i)
        local h = heads[i]
        if not h then
            h = UI.CreateButton(child, "", 100, HEAD_H, function(self)
                local open = Db().open
                open[self.catId] = (not open[self.catId]) or nil
                f.Render()
            end, "default")
            h.icon = h:CreateTexture(nil, "OVERLAY")
            h.icon:SetSize(HEAD_H - 6, HEAD_H - 6)
            h.icon:SetPoint("LEFT", h, "LEFT", 6, 0)
            h.label:ClearAllPoints()
            h.label:SetPoint("LEFT", h, "LEFT", HEAD_H + 6, 0)
            h.label:SetJustifyH("LEFT")
            heads[i] = h
        end
        return h
    end

    -- eine Zeile je Wert (ein einzeiliger Text je Label: mehrzeilige Texte zeigt der Forever-Client mit SetWordWrap(false) nur in der ersten Zeile)
    -- Jede Zeile ist ein Rahmen mit Hervorhebung beim Drueberfahren; die Labels haengen am Zeilenrahmen.
    local rowPool = {}
    local rowUsed = 0
    local function RowFrame()
        rowUsed = rowUsed + 1
        local p = rowPool[rowUsed]
        if not p then
            local row = CreateFrame("Frame", nil, child)
            row:SetHeight(ROW_H)
            row:EnableMouse(true)
            row.hl = row:CreateTexture(nil, "BACKGROUND")
            row.hl:SetAllPoints(row)
            row.hl:SetColorTexture(UI.Color("hover"))
            row.hl:Hide()
            row:SetScript("OnEnter", function(self) self.hl:Show() end)
            row:SetScript("OnLeave", function(self) self.hl:Hide() end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                local fn = scroll.scroll and scroll.scroll:GetScript("OnMouseWheel")
                if fn then fn(scroll.scroll, delta) end
            end)
            row.l = UI.CreateLabel(row, "", { size = 12, justifyV = "MIDDLE" })
            row.r = UI.CreateLabel(row, "", { size = 12, justify = "RIGHT", justifyV = "MIDDLE" })
            row.l:SetWordWrap(false); row.r:SetWordWrap(false)
            row.l:SetPoint("TOPLEFT", row, "TOPLEFT", LEFT_PAD, 0)
            row.l:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(VALUE_W + 14), 0)
            row.r:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, 0)
            row.r:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 0)
            row.r:SetWidth(VALUE_W)
            rowPool[rowUsed] = row
            p = row
        end
        return p
    end

    local function CurrentModel()
        local db = Db()
        if mode == "char" then
            local rec = Stats.Rec(false)
            if not rec then return nil end
            return Stats.Model(rec, { codex = CodexInfo() })
        end
        if not selected or (selected ~= "ALL" and not db.chars[selected]) then selected = "ALL" end
        if selected == "ALL" then
            local sum = Stats.Sum(db.chars)
            local cats = Stats.Model(sum, { codex = CodexInfo() })
            -- Charakterliste vorn
            local rows = {}
            rows[#rows + 1] = { L.STATS_CHARS_N, Stats.Num(sum.count or 0) }
            rows[#rows + 1] = { L.STATS_LEVELS, Stats.Num(sum.levelSum or 0) }
            for _, e in ipairs(Stats.CharList(db.chars)) do
                rows[#rows + 1] = { string.format("%s (%d)", e.name, e.level), string.format("%s | %s", Stats.Money(e.money), Stats.Duration(e.online)) }
            end
            table.insert(cats, 1, { id = "chars", title = L.STATS_C_CHARS, rows = rows })
            -- "Ueberblick" der Summe ersetzen: Name/Klasse sind hier leer
            for i, cat in ipairs(cats) do
                if cat.id == "overview" then
                    cat.rows = {
                        { L.STATS_PLAYED, Stats.Duration(sum.played or 0) },
                        { L.STATS_ONLINE, Stats.Duration(sum.c.online or 0) },
                        { L.STATS_REST, Stats.Duration(sum.c.restSecs or 0) },
                        { L.STATS_AFK, Stats.Duration(sum.c.afkSecs or 0) },
                    }
                elseif cat.id == "values" then
                    cat.rows = { { L.STATS_GOLDNOW, Stats.Money((sum.snap or {}).money) } }
                end
            end
            return cats
        end
        return Stats.Model(db.chars[selected], { codex = CodexInfo() })
    end

    function f.Render()
        local cats = CurrentModel()
        f.cats = cats or {}
        local open = Db().open
        local y = 0
        local n = 0
        rowUsed = 0
        if not cats then
            n = 1
            local h = Head(1)
            h.label:SetText(L.STATS_NONE)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
            h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, 0)
            h:Show()
        else
            for i, cat in ipairs(cats) do
                n = i
                local h = Head(i)
                h.catId = cat.id
                local icon = Stats.ICONS and Stats.ICONS[cat.id]
                if icon then h.icon:SetTexture("Interface\\Icons\\" .. icon); h.icon:Show() else h.icon:Hide() end
                local isOpen = open[cat.id] and true or false
                h.label:SetText((isOpen and "- " or "+ ") .. cat.title .. "  (" .. #cat.rows .. ")")
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -y)
                h:Show()
                y = y + HEAD_H + 4
                if isOpen then
                    for _, rw in ipairs(cat.rows) do
                        local row = RowFrame()
                        row.l:SetText(tostring(rw[1] or "")); row.r:SetText(tostring(rw[2] or ""))
                        row.hl:Hide()
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -y)
                        row:Show()
                        y = y + ROW_H
                    end
                    y = y + 8
                end
            end
        end
        for i = n + 1, #heads do heads[i]:Hide() end
        for i = rowUsed + 1, #rowPool do rowPool[i]:Hide() end
        scroll:SetContentHeight(math.max(y, 50))
    end

    function f.RefreshList()
        local db = Db()
        local entries = { { key = "ALL", text = L.STATS_ALL } }
        for _, e in ipairs(Stats.CharList(db.chars)) do
            entries[#entries + 1] = { key = e.key, text = string.format("%s  %d", e.name, e.level), class = e.class }
        end
        for i, e in ipairs(entries) do
            local b = listButtons[i]
            if not b then
                b = UI.CreateButton(listScroll.child, "", LIST_W - 14, BTN_H, function(self)
                    selected = self.key
                    confirmKey = nil
                    f.Refresh()
                end, "ghost")
                listButtons[i] = b
            end
            b.key = e.key
            b.label:SetText(e.text)
            if e.class then b.label:SetTextColor(ClassColor(e.class)) else b.label:SetTextColor(UI.Color("goldLight")) end
            b:SetStyle(e.key == selected and "primary" or "ghost")
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 0, -((i - 1) * (BTN_H + 4)))
            b:Show()
        end
        for i = #entries + 1, #listButtons do listButtons[i]:Hide() end
        listScroll:SetContentHeight(math.max(#entries * (BTN_H + 4), 50))
    end

    function f.Refresh()
        if not (G.InCombatLockdown and G.InCombatLockdown()) then
            pcall(Stats.UpdateInfo)
            pcall(Stats.Snapshot)
        end
        for _, b in ipairs(subButtons) do b:SetStyle(b.key == mode and "primary" or "ghost") end
        local acct = (mode == "acct")
        scroll:ClearAllPoints()
        if acct then
            listScroll:Show()
            f.RefreshList()
            scroll:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 10, -(BTN_H + 10))
            local current = Stats.Key()
            if selected and selected ~= "ALL" and selected ~= current then
                removeButton:Show()
                removeButton.label:SetText(confirmKey == selected and L.STATS_REMOVE_SURE or L.STATS_REMOVE)
            else
                removeButton:Hide()
            end
        else
            listScroll:Hide()
            removeButton:Hide()
            scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 10))
        end
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        local PM = FW.Codex and FW.Codex.PathMap
        pathButton.label:SetText((PM and PM.on) and L.STATS_PATH_HIDE or L.STATS_PATH_SHOW)
        f.Render()
    end

    f.acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = self.acc + (elapsed or 0)
        if self.acc < 5 then return end
        self.acc = 0
        if self:IsVisible() and not (G.InCombatLockdown and G.InCombatLockdown()) then self.Render() end
    end)
    f:SetScript("OnSizeChanged", function() f.Render() end)
    return f
end

UI:RegisterTab("stats", {
    label = function() return FW.L.TAB_STATS end,
    order = 95,
    build = Build,
    onShow = function(f) f.Refresh() end,
})
