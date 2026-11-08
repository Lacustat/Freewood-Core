-- Freewood-Core: Erfolge, Reiter, Hinweisfenster und Befehl
-- Reiter "Erfolge" mit Unterreitern "Charakter" und "Account", Kategorien, Fortschrittsbalken, Filter, Titelwahl.
-- Hinweisfenster oben in der Mitte bei neuen Stufen (abschaltbar). Befehl /fwerfolge (open | test | check).
-- UNGEPRUEFT im Spiel (Forever).

local ADDON, FW = ...

local UI = FW.UI
local A = FW.Ach
local Stats = FW.Stats
if not UI or not A or not Stats then return end

local G = _G
local BTN_H, ROW_H, HEAD_H = 26, 50, 24

local function Hex(c)
    local function B(v) return math.floor(v * 255 + 0.5) end
    return string.format("\124cff%02x%02x%02x", B(c[1]), B(c[2]), B(c[3]))
end
local function Db() return A.Db() or { acct = {}, notify = true, titleChat = true } end

------------------------------------------------------------------------
-- Hinweisfenster
------------------------------------------------------------------------

local toast, showFor = nil, 0
local queue = {}
local SHOW, FADE = 5, 0.8

local function EnsureToast()
    if toast then return toast end
    toast = CreateFrame("Frame", nil, G.UIParent)
    toast:SetSize(340, 58)
    toast:SetPoint("TOP", G.UIParent, "TOP", 0, -120)
    toast:SetFrameStrata("FULLSCREEN_DIALOG")
    toast:EnableMouse(true)
    toast.panel = UI.CreatePanel(toast, "bgDeep", "gold")
    toast.panel:SetAllPoints(toast)
    -- Beschriftung in einem eigenen Rahmen UEBER der Tafel (Kindrahmen liegen sonst ueber den Texten des Elternrahmens)
    toast.top = CreateFrame("Frame", nil, toast)
    toast.top:SetAllPoints(toast)
    toast.top:SetFrameLevel(toast.panel:GetFrameLevel() + 2)
    toast.medal = toast.top:CreateTexture(nil, "ARTWORK")
    toast.medal:SetSize(38, 38)
    toast.medal:SetPoint("LEFT", toast.top, "LEFT", 10, 0)
    toast.letter = UI.CreateLabel(toast.top, "", { size = 16, justify = "CENTER", color = "bgDeep" })
    toast.letter:SetPoint("CENTER", toast.medal, "CENTER", 0, 0)
    toast.head = UI.CreateLabel(toast.top, "", { size = 11, color = "textDim" })
    toast.head:SetPoint("TOPLEFT", toast.top, "TOPLEFT", 58, -9)
    toast.head:SetPoint("RIGHT", toast.top, "RIGHT", -10, 0)
    toast.head:SetWordWrap(false)
    toast.name = UI.CreateLabel(toast.top, "", { size = 14 })
    toast.name:SetPoint("TOPLEFT", toast.head, "BOTTOMLEFT", 0, -4)
    toast.name:SetPoint("RIGHT", toast.top, "RIGHT", -10, 0)
    toast.name:SetWordWrap(false)
    toast:SetScript("OnMouseUp", function()
        if FW.UI and FW.UI.Show then FW.UI:Show("ach") end
    end)
    toast:Hide()
    toast:SetScript("OnUpdate", function(self, elapsed)
        showFor = (showFor or 0) + (elapsed or 0)
        if showFor >= SHOW then
            local nxt = table.remove(queue, 1)
            if nxt then A.ShowToast(nxt) else self:Hide() end
        elseif showFor > SHOW - FADE then
            self:SetAlpha(math.max(0, (SHOW - showFor) / FADE))
        else
            self:SetAlpha(1)
        end
    end)
    return toast
end

-- item = { color = {r,g,b}, letter, head, text }
function A.ShowToast(item)
    local t = EnsureToast()
    local c = item.color or A.COLORS[3]
    t.medal:SetColorTexture(c[1], c[2], c[3], 1)
    t.letter:SetText(item.letter or "")
    t.head:SetText(item.head or "")
    t.name:SetText(item.text or "")
    showFor = 0
    t:SetAlpha(1)
    t:Show()
end

local function ItemFor(ev)
    local L = FW.L
    local lvl = ev.level
    local c = A.COLORS[lvl] or A.COLORS[1]
    local tier = L["ACH_TIER_" .. lvl]
    local head = ev.scope == "acct" and L.ACH_UNLOCKED_ACCT or L.ACH_UNLOCKED
    return {
        color = c, letter = (tier or ""):sub(1, 1), head = head,
        text = string.format("%s%s|r  %s  (+%d)", Hex(c), A.Name(ev.def), tier, A.POINTS[lvl] or 0),
    }
end

function A.OnToast(events)
    local L = FW.L
    local items = {}
    if #events > 3 then
        items[1] = { color = A.COLORS[3], letter = "!", head = L.ACH_UNLOCKED, text = string.format(L.ACH_UNLOCKED_N, #events) }
    else
        for _, ev in ipairs(events) do items[#items + 1] = ItemFor(ev) end
    end
    local t = EnsureToast()
    for _, it in ipairs(items) do
        if t:IsShown() then queue[#queue + 1] = it else A.ShowToast(it) end
    end
end

------------------------------------------------------------------------
-- Reiter
------------------------------------------------------------------------

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    local mode = "char"

    ---------------- obere Leiste ----------------
    local subs = {}
    local function MakeSub(key, textKey, x)
        local b = UI.CreateButton(f, L[textKey], 130, BTN_H, function() mode = key; f.Refresh() end, "ghost")
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
        b.key = key
        subs[#subs + 1] = b
    end
    MakeSub("char", "ACH_SUB_CHAR", 0)
    MakeSub("acct", "ACH_SUB_ACCOUNT", 136)

    f.sum = UI.CreateLabel(f, "", { size = 12, color = "textDim" })
    f.sum:SetPoint("LEFT", subs[2], "RIGHT", 16, 0)

    local filter = UI.CreateDropdown(f, 150, BTN_H, {
        getOptions = function()
            return { { value = "all", text = L.ACH_FILTER_ALL }, { value = "open", text = L.ACH_FILTER_OPEN }, { value = "done", text = L.ACH_FILTER_DONE } }
        end,
        onChange = function(v) Db().filter = v or "all"; f.Render() end,
    })
    filter:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    ---------------- zweite Zeile: Titel und Schalter ----------------
    local titleLabel = UI.CreateLabel(f, L.ACH_TITLE_LABEL, { size = 12 })
    titleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 12))
    local titleDD = UI.CreateDropdown(f, 230, 22, {
        getOptions = function()
            local list = { { value = "", text = L.ACH_TITLE_NONE } }
            for _, t in ipairs(A.TitleList()) do list[#list + 1] = t end
            return list
        end,
        textOf = function(v)
            if not v or v == "" then return L.ACH_TITLE_NONE end
            return A.TitleText(v) or L.ACH_TITLE_NONE
        end,
        onChange = function(v) Db().title = (v and v ~= "") and v or nil end,
    })
    titleDD:SetPoint("LEFT", titleLabel, "RIGHT", 8, 0)
    local chatBox = UI.CreateCheckbox(f, L.ACH_TITLE_CHAT, function() return Db().titleChat ~= false end, function(v) Db().titleChat = v and true or false end)
    chatBox:SetPoint("LEFT", titleDD, "RIGHT", 16, 0)
    local notifyBox = UI.CreateCheckbox(f, L.ACH_NOTIFY, function() return Db().notify ~= false end, function(v) Db().notify = v and true or false end)
    notifyBox:SetPoint("LEFT", chatBox, "RIGHT", 16, 0)

    ---------------- Liste ----------------
    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 46))
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local child = scroll.child

    local pool, used = {}, 0
    local emptyLabel
    local heads, headsUsed = {}, 0

    local function Wheel(frame)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta)
            local fn = scroll.scroll and scroll.scroll:GetScript("OnMouseWheel")
            if fn then fn(scroll.scroll, delta) end
        end)
    end

    local function Head()
        headsUsed = headsUsed + 1
        local h = heads[headsUsed]
        if not h then
            h = CreateFrame("Frame", nil, child)
            h:SetHeight(HEAD_H)
            h.bg = h:CreateTexture(nil, "BACKGROUND")
            h.bg:SetAllPoints()
            h.bg:SetColorTexture(UI.Color("card", 0.9))
            h.l = UI.CreateLabel(h, "", { size = 13, color = "goldLight" })
            h.l:SetPoint("LEFT", h, "LEFT", 10, 0)
            h.r = UI.CreateLabel(h, "", { size = 11, color = "textDim", justify = "RIGHT" })
            h.r:SetPoint("RIGHT", h, "RIGHT", -10, 0)
            Wheel(h)
            heads[headsUsed] = h
        end
        return h
    end

    local function Row()
        used = used + 1
        local r = pool[used]
        if not r then
            r = CreateFrame("Frame", nil, child)
            r:SetHeight(ROW_H)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints()
            r.medal = r:CreateTexture(nil, "ARTWORK")
            r.medal:SetSize(32, 32)
            r.medal:SetPoint("LEFT", r, "LEFT", 10, 0)
            r.letter = UI.CreateLabel(r, "", { size = 14, justify = "CENTER", color = "bgDeep" })
            r.letter:SetPoint("CENTER", r.medal, "CENTER", 0, 0)
            r.name = UI.CreateLabel(r, "", { size = 13 })
            r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 52, -6)
            r.name:SetWordWrap(false)
            r.desc = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
            r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
            r.desc:SetWordWrap(false)
            r.pips = {}
            for i = 1, 4 do
                local p = r:CreateTexture(nil, "ARTWORK")
                p:SetSize(10, 10)
                p:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12 - (4 - i) * 14, -8)
                r.pips[i] = p
            end
            r.track = r:CreateTexture(nil, "ARTWORK")
            r.track:SetHeight(6)
            r.track:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 52, 6)
            r.track:SetColorTexture(UI.Color("bgDeep"))
            r.fill = r:CreateTexture(nil, "OVERLAY")
            r.fill:SetHeight(6)
            r.fill:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 52, 6)
            r.prog = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT", color = "textDim" })
            r.prog:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -12, 4)
            r.prog:SetWordWrap(false)
            Wheel(r)
            pool[used] = r
        end
        return r
    end

    local function Fmt(n) return A.Num(n) end

    function f.Render()
        used, headsUsed = 0, 0
        local sdb = Stats.Db()
        local rec = Stats.Rec(false)
        local db = Db()
        local list
        if sdb then
            local sum = Stats.Sum(sdb.chars)
            list = A.View(mode, rec, sum, A.Context(sdb.chars), db.acct)
        else
            list = {}
        end
        local pts, max, done, total = A.Totals(list)
        f.sum:SetText(string.format(L.ACH_SUMMARY, Fmt(pts), Fmt(max), done, total))

        local filt = db.filter or "all"
        local width = (scroll:GetWidth() or 600) - 14
        if width < 200 then width = 600 end
        child:SetWidth(width)
        local barW = math.max(60, width - 52 - 140)
        local y, any = 0, false
        for _, cat in ipairs(A.CATS) do
            local items = {}
            local cp, cm = 0, 0
            for _, p in ipairs(list) do
                if p.def.cat == cat then
                    cp, cm = cp + p.points, cm + A.MaxPoints(p.def)
                    local isDone = p.level >= p.max
                    if filt == "all" or (filt == "open" and not isDone) or (filt == "done" and isDone) then items[#items + 1] = p end
                end
            end
            if #items > 0 then
                any = true
                local h = Head()
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                h:SetWidth(width)
                h.l:SetText(L["ACH_C_" .. cat])
                h.r:SetText(string.format("%s / %s", Fmt(cp), Fmt(cm)))
                h:Show()
                y = y + HEAD_H + 2
                for _, p in ipairs(items) do
                    local r = Row()
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                    r:SetWidth(width)
                    r.bg:SetColorTexture(UI.Color("bg", 0.55))
                    local e = p.def
                    local col = A.COLORS[p.level]
                    if col then
                        r.medal:SetColorTexture(col[1], col[2], col[3], 1)
                        r.letter:SetText((L["ACH_TIER_" .. p.level] or ""):sub(1, 1))
                    else
                        r.medal:SetColorTexture(0.25, 0.25, 0.28, 1)
                        r.letter:SetText("")
                    end
                    local title = A.TitleOf(e)
                    r.name:SetText(A.Name(e) .. (title and ("  \124cff9a9a9a<" .. title .. ">\124r") or ""))
                    r.name:SetTextColor(UI.Color(p.level >= p.max and "goldLight" or "text"))
                    r.desc:SetText(A.Desc(e, p.next or e.t[#e.t]))
                    for i = 1, 4 do
                        local inRange = i >= (e.from or 1) and i <= p.max
                        local pc = A.COLORS[i]
                        if not inRange then
                            r.pips[i]:SetColorTexture(0, 0, 0, 0)
                        elseif i <= p.level then
                            r.pips[i]:SetColorTexture(pc[1], pc[2], pc[3], 1)
                        else
                            r.pips[i]:SetColorTexture(0.22, 0.22, 0.25, 1)
                        end
                    end
                    r.track:SetWidth(barW)
                    r.fill:SetWidth(math.max(1, barW * p.frac))
                    if col then r.fill:SetColorTexture(col[1], col[2], col[3], 0.9) else r.fill:SetColorTexture(0.5, 0.5, 0.55, 0.9) end
                    local txt
                    if p.next then
                        txt = string.format("%s / %s", Fmt(p.value), Fmt(p.next))
                    else
                        txt = L.ACH_COMPLETE
                    end
                    if mode == "acct" and p.by and p.level > 0 then
                        local who = tostring(p.by):gsub("%-.*$", "")
                        txt = txt .. "  \124cff9a9a9a" .. string.format(L.ACH_BY, who) .. "\124r"
                    end
                    r.prog:SetText(txt)
                    r:Show()
                    y = y + ROW_H + 3
                end
                y = y + 6
            end
        end
        for i = used + 1, #pool do pool[i]:Hide() end
        for i = headsUsed + 1, #heads do heads[i]:Hide() end
        emptyLabel = emptyLabel or UI.CreateLabel(f, L.ACH_EMPTY, { size = 12, color = "textDim" })
        emptyLabel:ClearAllPoints()
        emptyLabel:SetPoint("TOP", scroll, "TOP", 0, -30)
        if any then emptyLabel:Hide() else emptyLabel:Show() end
        scroll:SetContentHeight(math.max(y, 1))
    end

    function f.Refresh()
        for _, b in ipairs(subs) do b:SetStyle(b.key == mode and "primary" or "ghost") end
        local db = Db()
        filter:SetValue(db.filter or "all")
        titleDD:SetValue(db.title or "")
        chatBox:Refresh()
        notifyBox:Refresh()
        f.Render()
    end

    f.acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = self.acc + (elapsed or 0)
        if self.acc < 6 then return end
        self.acc = 0
        if self:IsVisible() and not (G.InCombatLockdown and G.InCombatLockdown()) then self.Render() end
    end)
    f:SetScript("OnSizeChanged", function() f.Render() end)
    return f
end

UI:RegisterTab("ach", {
    label = function() return FW.L.TAB_ACH end,
    order = 96,
    build = Build,
    onShow = function(f)
        pcall(A.Check)
        f.Refresh()
    end,
})

------------------------------------------------------------------------
-- Befehl /fwerfolge
------------------------------------------------------------------------

G.SLASH_FWERFOLGE1 = "/fwerfolge"
G.SLASH_FWERFOLGE2 = "/fwachievements"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList["FWERFOLGE"] = function(msg)
    local L = FW.L
    local cmd = tostring(msg or ""):lower():match("^(%S*)") or ""
    if cmd == "test" then
        A.OnToast({ { def = A.BY_ID.jumps, level = 2, scope = "char" } })
    elseif cmd == "check" then
        local ev = A.Check(true)
        FW:Print(string.format(L.ACH_CHECK_DONE, ev and #ev or 0))
    else
        if FW.UI and FW.UI.Show then FW.UI:Show("ach") end
    end
end
