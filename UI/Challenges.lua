-- Freewood-Core: Herausforderungen, Reiter und Hinweise
-- Reiter "Herausforderungen": eigene und erhaltene (Brett) Herausforderungen mit Fortschritt, Annehmen, Aufgeben, erneut versuchen;
-- Titelwahl. Warnungen, "gescheitert" und "geschafft" erscheinen in einem Hinweisfeld oben in der Mitte (und im Chat).
-- UNGEPRUEFT im Spiel (Forever).

local ADDON, FW = ...

local UI = FW.UI
local R = FW.Rules
if not UI or not R then return end

local G = _G
local BTN_H, ROW_H = 26, 104

local function Db() return R.Db() or { defs = {}, done = {}, titles = {} } end

------------------------------------------------------------------------
-- Hinweisfeld
------------------------------------------------------------------------

local banner, bQueue, bShow, bFor = nil, {}, 0, 0
local KIND = {
    warn = { border = "goldLight", head = "CH_WARN_HEAD", secs = 10 },
    failed = { border = "danger", head = "CH_FAILED_HEAD", secs = 10 },
    done = { border = "success", head = "CH_DONE_HEAD", secs = 7 },
    accepted = { border = "bronze", head = "CH_ACCEPTED_HEAD", secs = 4 },
}

local function EnsureBanner()
    if banner then return banner end
    banner = UI.CreatePanel(G.UIParent, "bgDeep", "goldLight")
    banner:SetSize(540, 84)
    banner:SetPoint("TOP", G.UIParent, "TOP", 0, -200)
    banner:SetFrameStrata("FULLSCREEN_DIALOG")
    banner:EnableMouse(true)
    banner.head = UI.CreateLabel(banner, "", { font = "heading", size = 13, color = "goldLight" })
    banner.head:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -10)
    banner.head:SetPoint("RIGHT", banner, "RIGHT", -14, 0)
    banner.head:SetWordWrap(false)
    banner.text = UI.CreateLabel(banner, "", { size = 12, justifyV = "TOP" })
    banner.text:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -30)
    banner.text:SetWidth(512); banner.text:SetHeight(48)
    banner.text:SetWordWrap(true)
    banner:SetScript("OnMouseUp", function()
        if FW.UI and FW.UI.Show then FW.UI:Show("challenges") end
        banner:Hide(); bFor = 99
    end)
    banner:Hide()
    banner:SetScript("OnUpdate", function(self, elapsed)
        bFor = bFor + (elapsed or 0)
        if bFor >= bShow then
            local nxt = table.remove(bQueue, 1)
            if nxt then R.ShowBanner(nxt) else self:Hide() end
        elseif bFor > bShow - 0.8 then
            self:SetAlpha(math.max(0, (bShow - bFor) / 0.8))
        else
            self:SetAlpha(1)
        end
    end)
    return banner
end

function R.ShowBanner(item)
    local b = EnsureBanner()
    local k = KIND[item.kind] or KIND.warn
    UI.SetBorderColor(b, k.border, 1)
    b.head:SetText(string.format("%s: %s", FW.L[k.head], item.name or ""))
    b.text:SetText(item.text or "")
    bShow, bFor = k.secs, 0
    b:SetAlpha(1)
    b:Show()
end

function R.OnNotify(kind, def, text)
    if not KIND[kind] then return end
    local item = { kind = kind, name = def.name, text = text }
    local b = EnsureBanner()
    if b:IsShown() and bFor < bShow then bQueue[#bQueue + 1] = item else R.ShowBanner(item) end
end

------------------------------------------------------------------------
-- Reiter
------------------------------------------------------------------------

local function Build(content)
    local L = FW.L
    local f = CreateFrame("Frame", nil, content)
    local filter = "all"

    f.sum = UI.CreateLabel(f, "", { size = 12, color = "textDim" })
    f.sum:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -6)

    local filterDD = UI.CreateDropdown(f, 150, BTN_H, {
        getOptions = function()
            return {
                { value = "all", text = L.CH_FILTER_ALL }, { value = "active", text = L.CH_FILTER_ACTIVE },
                { value = "new", text = L.CH_FILTER_NEW }, { value = "done", text = L.CH_FILTER_DONE },
                { value = "failed", text = L.CH_FILTER_FAILED },
            }
        end,
        onChange = function(v) filter = v or "all"; f.Render() end,
    })
    filterDD:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)

    local titleLabel = UI.CreateLabel(f, L.CH_TITLE_LABEL, { size = 12 })
    titleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 10))
    local A = FW.Ach
    local titleDD
    if A and A.TitleList then
        titleDD = UI.CreateDropdown(f, 230, 22, {
            getOptions = function()
                local list = { { value = "", text = L.ACH_TITLE_NONE } }
                for _, t in ipairs(A.TitleList()) do list[#list + 1] = t end
                return list
            end,
            textOf = function(v) return (A.TitleText and A.TitleText(v)) or L.ACH_TITLE_NONE end,
            onChange = function(v)
                local adb = A.Db()
                if adb then adb.title = (v and v ~= "") and v or nil end
            end,
        })
        titleDD:SetPoint("LEFT", titleLabel, "RIGHT", 8, 0)
    end
    local honor = UI.CreateLabel(f, L.CH_HONOR, { size = 10, color = "textDim", justifyV = "TOP" })
    honor:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 38))
    honor:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    honor:SetHeight(26)
    honor:SetWordWrap(true)

    local scroll = UI.CreateScrollFrame(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(BTN_H + 70))
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local child = scroll.child
    local pool, used = {}, 0
    local emptyLabel

    local function Wheel(frame)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta)
            local fn = scroll.scroll and scroll.scroll:GetScript("OnMouseWheel")
            if fn then fn(scroll.scroll, delta) end
        end)
    end

    local function Row()
        used = used + 1
        local r = pool[used]
        if r then return r end
        r = UI.CreatePanel(child, "card", "bronze")
        r:SetHeight(ROW_H - 6)
        r.name = UI.CreateLabel(r, "", { size = 13 })
        r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -8)
        r.name:SetWordWrap(false)
        r.status = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT" })
        r.status:SetPoint("TOPRIGHT", r, "TOPRIGHT", -12, -9)
        r.desc = UI.CreateLabel(r, "", { size = 11, color = "textDim", justifyV = "TOP" })
        r.desc:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -28)
        r.desc:SetHeight(30)
        r.desc:SetWordWrap(true)
        r.prog = UI.CreateLabel(r, "", { size = 11, color = "goldLight" })
        r.prog:SetPoint("TOPLEFT", r, "TOPLEFT", 12, -62)
        r.prog:SetWordWrap(false)
        r.rew = UI.CreateLabel(r, "", { size = 10, color = "textDim" })
        r.rew:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 12, 6)
        r.rew:SetWordWrap(false)
        r.btn = UI.CreateButton(r, "", 130, 26, function(self)
            local id, st = self.cid, self.mode
            if st == "accept" then
                local ok, why, n = R.Accept(id)
                if not ok then
                    local text = FW.L[why] or tostring(why)
                    local okf, t2 = pcall(string.format, text, n or 0)
                    FW:Print(okf and t2 or text)
                end
            elseif st == "abandon" then
                R.Abandon(id)
            end
            f.Render()
        end, "primary")
        r.btn:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -12, 8)
        Wheel(r)
        pool[used] = r
        return r
    end

    local COLORS = { active = "goldLight", done = "success", failed = "danger", new = "textDim" }

    function f.Render()
        used = 0
        local db = Db()
        local all = R.List()
        local items = {}
        for _, def in ipairs(all) do
            local status, st = R.Status(def.id)
            if filter == "all" or filter == status then items[#items + 1] = { def = def, status = status, st = st } end
        end
        local pts, nDone = R.Points()
        f.sum:SetText(string.format(L.CH_SUMMARY, pts, R.ActiveCount(), R.LIMITS.active, nDone))
        local width = (scroll:GetWidth() or 600) - 14
        if width < 300 then width = 600 end
        child:SetWidth(width)
        local w = R.World()
        local y = 0
        for _, it in ipairs(items) do
            local def, status, st = it.def, it.status, it.st
            local r = Row()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            r:SetWidth(width)
            r.name:SetWidth(width - 180)
            r.name:SetText(def.name .. (def.author and def.author ~= "" and ("  \124cff9a9a9a" .. string.format(L.CH_BY, def.author) .. "\124r") or ""))
            r.status:SetText(L["CH_STATUS_" .. status])
            r.status:SetTextColor(UI.Color(COLORS[status] or "text"))
            r.desc:SetWidth(width - 24)
            r.desc:SetText((def.desc ~= "" and (def.desc .. "  ") or "") .. R.Describe(def))
            if status == "active" then
                local parts = {}
                for i, g in ipairs(def.goals) do
                    local cur, tot = R.GoalProgress(g, i, st, w)
                    parts[#parts + 1] = string.format("%s: %d/%d", R.DescribeGoal(g), cur, tot)
                end
                r.prog:SetText(table.concat(parts, "  |  "))
                r.prog:SetWidth(width - 24)
            elseif status == "failed" then
                local h = st
                local reason = h and h.reason and FW.L["RF_" .. tostring(h.reason)]
                if reason then
                    local okf, t2 = pcall(string.format, reason, 0)
                    r.prog:SetText(string.format(L.CH_REASON, okf and t2 or reason))
                else
                    r.prog:SetText("")
                end
                r.prog:SetWidth(width - 24)
            else
                r.prog:SetText("")
            end
            local rw = {}
            if def.reward and (def.reward.points or 0) > 0 then rw[#rw + 1] = string.format(L.CH_REWARD_POINTS, def.reward.points) end
            if def.reward and def.reward.title and def.reward.title ~= "" then rw[#rw + 1] = string.format(L.CH_REWARD_TITLE, def.reward.title) end
            r.rew:SetText(#rw > 0 and string.format(L.CH_REWARD, table.concat(rw, ", ")) or "")
            r.btn.cid = def.id
            if status == "active" then
                r.btn.mode = "abandon"; r.btn:SetLabel(L.CH_ABANDON); r.btn:SetStyle("default"); r.btn:Show()
            elseif status == "done" then
                r.btn:Hide()
            else
                r.btn.mode = "accept"; r.btn:SetLabel(status == "failed" and L.CH_RETRY or L.CH_ACCEPT); r.btn:SetStyle("primary"); r.btn:Show()
            end
            r:Show()
            y = y + ROW_H
        end
        for i = used + 1, #pool do pool[i]:Hide() end
        emptyLabel = emptyLabel or UI.CreateLabel(f, L.CH_EMPTY, { size = 12, color = "textDim", justifyV = "TOP" })
        emptyLabel:ClearAllPoints()
        emptyLabel:SetPoint("TOPLEFT", scroll, "TOPLEFT", 8, -20)
        emptyLabel:SetWidth(520)
        emptyLabel:SetWordWrap(true)
        if #items == 0 then emptyLabel:Show() else emptyLabel:Hide() end
        scroll:SetContentHeight(math.max(y, 1))
    end

    function f.Refresh()
        filterDD:SetValue(filter)
        if titleDD then
            local adb = A and A.Db and A.Db()
            titleDD:SetValue(adb and adb.title or "")
        end
        f.Render()
    end

    f.acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = self.acc + (elapsed or 0)
        if self.acc < 3 then return end
        self.acc = 0
        if self:IsVisible() and not (G.InCombatLockdown and G.InCombatLockdown()) then self.Render() end
    end)
    f:SetScript("OnSizeChanged", function() f.Render() end)
    FW:On("FW_CHALLENGES_CHANGED", function() if f:IsVisible() then f.Render() end end, f)
    return f
end

UI:RegisterTab("challenges", {
    label = function() return FW.L.TAB_CHALLENGES end,
    order = 97,
    build = Build,
    onShow = function(f) f.Refresh() end,
})
