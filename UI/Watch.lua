-- Freewood-Core: Beobachten-Fenster. Eine eigene Merkliste fuer Rezepte (und Items) mit ihren Materialien.
-- Das Blizzard-Beobachten klappt nur fuer Rezepte, die man selbst kennt; diese Liste klappt fuer jedes Rezept,
-- dessen Materialien bekannt sind (zum Beispiel aus der Gilde). Der Taschenbestand wird live angezeigt.
-- Andere Module nutzen sie ueber FW.Watch.Add({ key, name, itemId, spellId, mats = { { i = Item, n = Anzahl } } }).
-- Befehl: /fwwatch. Gespeichert pro Charakter (FreewoodCharDB.watch). UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

FW:AddLocale("enUS", {
    WATCH_TITLE = "Watch list",
    WATCH_EMPTY = "Nothing watched yet. Use \"Watch\" in a recipe list (for example in the guild module).",
    WATCH_TOTAL = "Total materials",
    WATCH_CLEAR = "Clear list",
    WATCH_REMOVE = "Remove",
    WATCH_FULL = "The watch list is full (30 entries).",
    WATCH_ADDED = "Added to the watch list: %s",
    WATCH_MISSING = "missing %d",
    WATCH_HAVE_ALL = "complete",
    WATCH_NO_MATS = "No materials known for this recipe.",
    WATCH_HELP = "/fwwatch: open the watch list, /fwwatch clear: empty it",
})
FW:AddLocale("deDE", {
    WATCH_TITLE = "Beobachten",
    WATCH_EMPTY = "Noch nichts beobachtet. Nutze „Beobachten“ in einer Rezeptliste (zum Beispiel im Gilden-Modul).",
    WATCH_TOTAL = "Material gesamt",
    WATCH_CLEAR = "Liste leeren",
    WATCH_REMOVE = "Entfernen",
    WATCH_FULL = "Die Beobachtungsliste ist voll (30 Einträge).",
    WATCH_ADDED = "Zur Beobachtungsliste hinzugefügt: %s",
    WATCH_MISSING = "es fehlen %d",
    WATCH_HAVE_ALL = "komplett",
    WATCH_NO_MATS = "Für dieses Rezept sind keine Materialien bekannt.",
    WATCH_HELP = "/fwwatch: Beobachtungsliste öffnen, /fwwatch clear: leeren",
})

local Watch = {}
FW.Watch = Watch

local MAX_ENTRIES = 30
local ROW_H = 16

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

------------------------------------------------------------------------
-- Daten
------------------------------------------------------------------------

local function Store()
    local db = G.FreewoodCharDB
    if type(db) ~= "table" then return { list = {} } end
    if type(db.watch) ~= "table" then db.watch = { list = {} } end
    if type(db.watch.list) ~= "table" then db.watch.list = {} end
    return db.watch
end

function Watch.List() return Store().list end

function Watch.Find(key)
    for i, e in ipairs(Store().list) do
        if e.key == key then return e, i end
    end
    return nil
end

local function Changed()
    FW:Fire("WATCH_CHANGED")
end

-- entry: key (Pflicht), name, itemId, spellId, mats = { { i, n } }, qty (Standard 1)
function Watch.Add(entry)
    if type(entry) ~= "table" or not entry.key then return false end
    local st = Store()
    local e = Watch.Find(entry.key)
    if e then
        e.qty = math.min(99, (e.qty or 1) + (entry.qty or 1))
        if entry.mats and #entry.mats > 0 then e.mats = entry.mats end
        if entry.itemId then e.itemId = entry.itemId end
        Changed()
        return true
    end
    if #st.list >= MAX_ENTRIES then
        if FW.Print then FW:Print(FW.L.WATCH_FULL) end
        return false
    end
    local mats = {}
    for _, m in ipairs(entry.mats or {}) do
        if tonumber(m.i) and #mats < 12 then mats[#mats + 1] = { i = tonumber(m.i), n = math.max(1, tonumber(m.n) or 1) } end
    end
    st.list[#st.list + 1] = {
        key = entry.key, name = entry.name, itemId = tonumber(entry.itemId), spellId = tonumber(entry.spellId),
        qty = math.max(1, math.min(99, tonumber(entry.qty) or 1)), mats = mats,
    }
    Changed()
    if FW.Print then FW:Print(string.format(FW.L.WATCH_ADDED, tostring(entry.name or entry.key))) end
    return true
end

function Watch.Remove(key)
    local _, i = Watch.Find(key)
    if not i then return false end
    table.remove(Store().list, i)
    Changed()
    return true
end

function Watch.SetQty(key, qty)
    local e = Watch.Find(key)
    if not e then return false end
    qty = math.floor(tonumber(qty) or 1)
    if qty < 1 then return Watch.Remove(key) end
    e.qty = math.min(99, qty)
    Changed()
    return true
end

function Watch.Clear()
    Store().list = {}
    Changed()
end

function Watch.Have(itemId)
    itemId = tonumber(itemId)
    if not itemId then return 0 end
    local get = G.C_Item and G.C_Item.GetItemCount
    local ok, n
    if get then ok, n = pcall(get, itemId, true) end
    if not ok or type(n) ~= "number" or Secret(n) then
        if G.GetItemCount then ok, n = pcall(G.GetItemCount, itemId, true) end
    end
    if ok and type(n) == "number" and not Secret(n) then return n end
    return 0
end

function Watch.ItemName(id)
    id = tonumber(id)
    if not id then return nil end
    local ci = G.C_Item
    if ci and ci.GetItemNameByID then
        local ok, n = pcall(ci.GetItemNameByID, id)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    local get = (ci and ci.GetItemInfo) or G.GetItemInfo
    if get then
        local ok, n = pcall(get, id)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    if ci and ci.RequestLoadItemDataByID then pcall(ci.RequestLoadItemDataByID, id) end
    return nil
end

-- Gesamtbedarf: { { i, need, have }, ... } nach Name sortiert
function Watch.Totals()
    local need = {}
    for _, e in ipairs(Store().list) do
        for _, m in ipairs(e.mats or {}) do
            need[m.i] = (need[m.i] or 0) + m.n * (e.qty or 1)
        end
    end
    local out = {}
    for id, n in pairs(need) do out[#out + 1] = { i = id, need = n, have = Watch.Have(id), name = Watch.ItemName(id) or ("#" .. id) } end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local win, rows = nil, {}

local function Tip(self)
    if not G.GameTooltip or not self.link then return end
    G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = G.GameTooltip.SetHyperlink and pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, self.link)
    if not ok then G.GameTooltip:AddLine(self.text or "?") end
    G.GameTooltip:Show()
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, win.scroll.child)
    r:SetHeight(ROW_H)
    r:EnableMouse(true)
    r.label = UI.CreateLabel(r, "", { size = 12 })
    r.label:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.label:SetPoint("RIGHT", r, "RIGHT", -150, 0)
    r.label:SetWordWrap(false)
    r.right = UI.CreateLabel(r, "", { size = 11, justify = "RIGHT" })
    r.right:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.minus = UI.CreateButton(r, "-", 20, 16, function() if r.key then local e = Watch.Find(r.key); if e then Watch.SetQty(r.key, (e.qty or 1) - 1) end end end)
    r.plus = UI.CreateButton(r, "+", 20, 16, function() if r.key then local e = Watch.Find(r.key); if e then Watch.SetQty(r.key, (e.qty or 1) + 1) end end end)
    r.del = UI.CreateButton(r, "X", 20, 16, function() if r.key then Watch.Remove(r.key) end end)
    r.del:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.plus:SetPoint("RIGHT", r.del, "LEFT", -3, 0)
    r.minus:SetPoint("RIGHT", r.plus, "LEFT", -3, 0)
    r:SetScript("OnEnter", Tip)
    r:SetScript("OnLeave", function() if G.GameTooltip then G.GameTooltip:Hide() end end)
    rows[i] = r
    return r
end

local function Vis(f, on) if on then f:Show() else f:Hide() end end

local function Use(r, kind, key, text, link, rightText)
    r.key, r.link, r.text = key, link, text
    r.label:SetText(text or "")
    Vis(r.minus, kind == "entry")
    Vis(r.plus, kind == "entry")
    Vis(r.del, kind == "entry")
    r.right:SetText(rightText or "")
    Vis(r.right, kind ~= "entry")
    r:Show()
end

local function Color(have, need)
    if have >= need then return "|cff66dd66" end
    if have > 0 then return "|cffffd24a" end
    return "|cffee6655"
end

function Watch.Refresh()
    if not win or not win:IsShown() then return end
    local L = FW.L
    local list = Store().list
    local n = 0
    local y = 0
    local function Next(kind, key, text, link, right, indent)
        n = n + 1
        local r = GetRow(n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", win.scroll.child, "TOPLEFT", indent or 0, -y)
        r:SetPoint("TOPRIGHT", win.scroll.child, "TOPRIGHT", 0, -y)
        Use(r, kind, key, text, link, right)
        y = y + ROW_H + (kind == "entry" and 2 or 0)
    end
    Vis(win.empty, #list == 0)
    for _, e in ipairs(list) do
        local nm = e.name or (e.itemId and Watch.ItemName(e.itemId)) or e.key
        local link = e.itemId and ("item:" .. e.itemId) or (e.spellId and ("spell:" .. e.spellId)) or nil
        Next("entry", e.key, "|cffe8c46a" .. nm .. "|r  x" .. (e.qty or 1), link)
        if #(e.mats or {}) == 0 then
            Next("line", nil, "|cff9a978c   " .. L.WATCH_NO_MATS .. "|r", nil, nil, 10)
        end
        for _, m in ipairs(e.mats or {}) do
            local need = m.n * (e.qty or 1)
            local have = Watch.Have(m.i)
            Next("line", nil, string.format("   %s%d/%d|r  %s", Color(have, need), math.min(have, need), need, Watch.ItemName(m.i) or ("#" .. m.i)), "item:" .. m.i, nil, 10)
        end
        y = y + 4
    end
    local tot = Watch.Totals()
    if #tot > 0 and #list > 1 then
        Next("line", nil, "|cffc89b3c" .. L.WATCH_TOTAL .. "|r", nil, nil, 0)
        for _, t in ipairs(tot) do
            Next("line", nil, string.format("   %s%d/%d|r  %s", Color(t.have, t.need), math.min(t.have, t.need), t.need, t.name), "item:" .. t.i, nil, 10)
        end
    end
    for i = n + 1, #rows do rows[i]:Hide(); rows[i].key = nil end
    win.scroll:SetContentHeight(y + 8)
end

local function Build()
    local L = FW.L
    local w = UI.CreatePanel(UIParent, "bgDeep", "gold")
    w:SetSize(360, 460)
    w:SetPoint("RIGHT", UIParent, "RIGHT", -60, 40)
    w:SetFrameStrata("MEDIUM")
    w:EnableMouse(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function(self) self:StartMoving() end)
    w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local title = UI.CreateLabel(w, L.WATCH_TITLE, { font = "heading", size = 14, color = "goldLight" })
    title:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -12)
    local close = UI.CreateButton(w, "X", 24, 22, function() w:Hide() end)
    close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -8)
    local clear = UI.CreateButton(w, L.WATCH_CLEAR, 110, 22, function() Watch.Clear() end)
    clear:SetPoint("RIGHT", close, "LEFT", -6, 0)
    w.scroll = UI.CreateScrollFrame(w)
    w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 14, -40)
    w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -14, 14)
    w.empty = UI.CreateLabel(w.scroll.child, L.WATCH_EMPTY, { size = 12, color = "textDim", justifyV = "TOP" })
    w.empty:SetPoint("TOPLEFT", w.scroll.child, "TOPLEFT", 2, -4)
    w.empty:SetPoint("TOPRIGHT", w.scroll.child, "TOPRIGHT", -2, -4)
    w.empty:SetWordWrap(true)
    w:SetScript("OnShow", function() Watch.Refresh() end)
    w:Hide()
    return w
end

function Watch.Show()
    if not win then win = Build() end
    win:Show()
    Watch.Refresh()
end

function Watch.Toggle()
    if not win then win = Build() end
    if win:IsShown() then win:Hide() else Watch.Show() end
end

local pending = false
local function Later()
    if pending then return end
    pending = true
    local function Run() pending = false; pcall(Watch.Refresh) end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(0.4, Run) else Run() end
end
FW:On("WATCH_CHANGED", function() pcall(Watch.Refresh) end)
FW:RegisterEvent("BAG_UPDATE_DELAYED", function() if win and win:IsShown() then Later() end end, Watch)
FW:RegisterEvent("GET_ITEM_INFO_RECEIVED", function() if win and win:IsShown() then Later() end end, Watch)

SLASH_FREEWOODWATCH1 = "/fwwatch"
SLASH_FREEWOODWATCH2 = "/fwbeobachten"
G.SlashCmdList = G.SlashCmdList or {}
G.SlashCmdList["FREEWOODWATCH"] = function(msg)
    msg = string.lower(strtrim and strtrim(msg or "") or (msg or ""))
    if msg == "clear" or msg == "leeren" then Watch.Clear(); return end
    Watch.Toggle()
end
