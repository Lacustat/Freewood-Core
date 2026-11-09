-- Freewood-Core: Wuerfelfenster. Zwei kleine Fenster:
--  1) Beute-Wuerfe: je Gegenstand eine Liste [Gegenstandssymbol][Wuerfel][Zahl][Spielername], Tooltip am Symbol.
--  2) Handwuerfe (/roll) in der Gruppe: [Wuerfel][Zahl][Name], sortiert nach dem besten Wurf, mit Knoepfen "Wuerfeln" und "Schliessen".
-- Quelle sind die Chat-Meldungen des Spiels (CHAT_MSG_LOOT, CHAT_MSG_SYSTEM und die Zeilen, die das Chatfenster sieht). Die Textvorlagen
-- kommen aus den Spiel-Variablen (LOOT_ROLL_*, RANDOM_ROLL_RESULT) und werden nach Typ (Zahl, Gegenstandslink, Name) ausgewertet,
-- damit die Reihenfolge der Platzhalter in einer Sprache nicht stoert. Beide Fenster lassen sich in den Einstellungen abschalten.
-- UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local R = {}
FW.RollWindow = R

FW:AddLocale("enUS", {
    ROLLWIN_TITLE = "Loot rolls",
    ROLLWIN_TITLE_HAND = "Roll",
    ROLLWIN_BTN_ROLL = "Roll",
    ROLLWIN_BTN_CLOSE = "Close",
    ROLLWIN_NEED = "Need",
    ROLLWIN_GREED = "Greed",
    ROLLWIN_DE = "Disenchant",
    ROLLWIN_WON = "Winner",
    ROLLWIN_WAIT = "waiting ...",
    ROLLWIN_SECTION = "Roll windows",
    ROLLWIN_HINT = "Small windows that list who rolled what. Test with /fwroll.",
    ROLLWIN_LOOT = "Show a window for loot rolls (item, roll, number, player)",
    ROLLWIN_HAND = "Show a window for manual /roll in the group (sorted, with Roll and Close buttons)",
    ROLLWIN_TEST_DONE = "Roll windows: demo shown.",
})
FW:AddLocale("deDE", {
    ROLLWIN_TITLE = "Beute-Würfe",
    ROLLWIN_TITLE_HAND = "Würfeln",
    ROLLWIN_BTN_ROLL = "Würfeln",
    ROLLWIN_BTN_CLOSE = "Schließen",
    ROLLWIN_NEED = "Bedarf",
    ROLLWIN_GREED = "Gier",
    ROLLWIN_DE = "Entzaubern",
    ROLLWIN_WON = "Gewinner",
    ROLLWIN_WAIT = "wartet ...",
    ROLLWIN_SECTION = "Würfelfenster",
    ROLLWIN_HINT = "Kleine Fenster, die zeigen, wer was gewürfelt hat. Test mit /fwroll.",
    ROLLWIN_LOOT = "Fenster für Beute-Würfe zeigen (Gegenstand, Würfel, Zahl, Spieler)",
    ROLLWIN_HAND = "Fenster für Handwürfe (/roll) in der Gruppe zeigen (sortiert, mit Knöpfen Würfeln und Schließen)",
    ROLLWIN_TEST_DONE = "Würfelfenster: Beispiel gezeigt.",
})

R.DEFAULTS = { loot = true, hand = true }

function R.Opts()
    local s = FW.settings
    if type(s) ~= "table" then return R.DEFAULTS end
    if type(s.rollWin) ~= "table" then s.rollWin = {} end
    local o = s.rollWin
    for k, v in pairs(R.DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

function R.Now() return G.GetTime and G.GetTime() or 0 end

-- Testnaht: ist der Spieler in einer Gruppe?
function R.InGroup()
    if G.IsInGroup and G.IsInGroup() then return true end
    if G.IsInRaid and G.IsInRaid() then return true end
    return false
end

local function SelfName()
    local n = G.UnitName and G.UnitName("player")
    if type(n) == "string" and not Secret(n) then return n end
    return "?"
end

------------------------------------------------------------------------
-- Textvorlagen
------------------------------------------------------------------------

-- Vorlage des Spiels -> Muster mit Fangklammern; caps = Typen ("s"/"d") in der Reihenfolge der Platzhalter
local function Compile(fmt)
    local pat, caps, pos = "", {}, 1
    while true do
        local i, j, _, kind = string.find(fmt, "%%(%d*)%$?([sd])", pos)
        if not i then break end
        pat = pat .. string.gsub(string.sub(fmt, pos, i - 1), "%W", "%%%0") .. (kind == "d" and "(%-?%d+)" or "(.-)")
        caps[#caps + 1] = kind
        pos = j + 1
    end
    pat = "^" .. pat .. string.gsub(string.sub(fmt, pos), "%W", "%%%0") .. "$"
    return pat, caps
end

-- Reihenfolge ist wichtig: die genaueren Vorlagen zuerst
local TYPES = {
    { "LOOT_ROLL_ROLLED_NEED_ROLE_BONUS", "rolled", "need" },
    { "LOOT_ROLL_ROLLED_NEED", "rolled", "need" },
    { "LOOT_ROLL_ROLLED_GREED", "rolled", "greed" },
    { "LOOT_ROLL_ROLLED_DE", "rolled", "de" },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "need" },
    { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "greed" },
    { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "de" },
    { "LOOT_ROLL_YOU_WON", "won", nil, true },
    { "LOOT_ROLL_WON", "won" },
    { "LOOT_ROLL_ALL_PASSED", "allpassed" },
    { "LOOT_ROLL_NEED_SELF", "chose", "need", true },
    { "LOOT_ROLL_GREED_SELF", "chose", "greed", true },
    { "LOOT_ROLL_DISENCHANT_SELF", "chose", "de", true },
    { "LOOT_ROLL_NEED", "chose", "need" },
    { "LOOT_ROLL_GREED", "chose", "greed" },
    { "LOOT_ROLL_DISENCHANT", "chose", "de" },
    { "LOOT_ROLL_PASSED_SELF_AUTO", "pass", nil, true },
    { "LOOT_ROLL_PASSED_SELF", "pass", nil, true },
    { "LOOT_ROLL_PASSED_AUTO_FEMALE", "pass" },
    { "LOOT_ROLL_PASSED_AUTO", "pass" },
    { "LOOT_ROLL_PASSED", "pass" },
}

local compiled
local function Compiled()
    if compiled then return compiled end
    compiled = {}
    for _, t in ipairs(TYPES) do
        local f = G[t[1]]
        if type(f) == "string" and f ~= "" then
            local pat, caps = Compile(f)
            compiled[#compiled + 1] = { pat = pat, caps = caps, what = t[2], kind = t[3], me = t[4] }
        end
    end
    local f = G.RANDOM_ROLL_RESULT
    if type(f) == "string" and f ~= "" then
        local pat, caps = Compile(f)
        compiled.hand = { pat = pat, caps = caps }
    end
    return compiled
end
function R.ResetPatterns() compiled = nil end

local function Plain(text)
    text = string.gsub(text, "\124c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "\124r", "")
    return text
end

-- Name ohne Link und Klammern
local function CleanName(s)
    s = string.gsub(s, "\124H.-\124h(.-)\124h", "%1")
    s = string.gsub(s, "^%[(.*)%]$", "%1")
    return s
end

-- Aus den Fangwerten: Zahl(en), Gegenstandslink, Namen
local function Split(vals, caps)
    local nums, strs, item = {}, {}, nil
    for i, v in ipairs(vals) do
        if caps[i] == "d" then
            nums[#nums + 1] = tonumber(v)
        elseif not item and string.find(v, "\124Hitem", 1, true) then
            item = v
        else
            strs[#strs + 1] = v
        end
    end
    return nums, item, strs
end

------------------------------------------------------------------------
-- Daten
------------------------------------------------------------------------

R.items = {}          -- Beute-Wuerfe: Liste von { key, link, rolls = { [Name] = { player, kind, value } }, winner, doneAt, t }
R.hand = { rolls = {}, last = 0 }
R.lootDismissed, R.handDismissed = false, false
R.itemSeq = 0
R.seen = {}
R.seenN = 0

local MAX_ITEMS = 6
local DONE_KEEP = 25       -- Sekunden, die ein erledigter Gegenstand stehen bleibt
local OPEN_KEEP = 150      -- Sekunden, nach denen ein offener Gegenstand ohne Neuigkeit verschwindet
local HAND_IDLE = 45       -- Sekunden Ruhe, danach beginnt eine neue Handwurf-Runde

local function ItemKey(link)
    return string.match(link, "\124H(item:[^\124]*)\124h") or link
end

local function FindItem(link)
    local key = ItemKey(link)
    for _, it in ipairs(R.items) do
        if it.key == key then return it end
    end
end

local function GetItem(link)
    local it = FindItem(link)
    local now = R.Now()
    if it then it.t = now; return it end
    R.itemSeq = R.itemSeq + 1
    it = { key = ItemKey(link), link = link, rolls = {}, seq = R.itemSeq, t = now }
    R.items[#R.items + 1] = it
    while #R.items > MAX_ITEMS do table.remove(R.items, 1) end
    R.lootDismissed = false
    return it
end
R.GetItem = GetItem

local function Roll(it, player)
    local r = it.rolls[player]
    if not r then
        r = { player = player }
        it.rolls[player] = r
    end
    return r
end

-- Eine Meldung des Spiels auswerten. Rueckgabe: Art ("loot", "hand") oder nil
function R.Feed(text)
    if type(text) ~= "string" or text == "" or Secret(text) then return nil end
    local plain = Plain(text)
    -- gleiche Zeile aus Ereignis und Chat-Hook zaehlt einmal
    local now = R.Now()
    local last = R.seen[plain]
    if last and now - last < 1 then return nil end
    R.seenN = R.seenN + 1
    if R.seenN > 80 then R.seen, R.seenN = {}, 0 end
    R.seen[plain] = now

    local C = Compiled()
    for _, c in ipairs(C) do
        local vals = { string.match(plain, c.pat) }
        if #vals == #c.caps and #vals > 0 then
            local nums, item, strs = Split(vals, c.caps)
            if item then
                local player = c.me and SelfName() or (strs[1] and CleanName(strs[1]))
                if c.what == "rolled" and player and nums[1] then
                    local it = GetItem(item)
                    local r = Roll(it, player)
                    r.kind, r.value = c.kind, nums[1]
                elseif c.what == "chose" and player then
                    local it = GetItem(item)
                    local r = Roll(it, player)
                    r.kind = c.kind
                elseif c.what == "pass" and player then
                    local it = GetItem(item)
                    it.passes = (it.passes or 0) + 1
                elseif c.what == "won" and player then
                    local it = GetItem(item)
                    it.winner, it.doneAt = player, now
                    if nums[1] then
                        local r = Roll(it, player)
                        r.kind = r.kind or c.kind
                        r.value = r.value or nums[1]
                    end
                elseif c.what == "allpassed" then
                    local it = GetItem(item)
                    it.doneAt = now
                else
                    return nil
                end
                R.Update()
                return "loot"
            end
        end
    end
    local h = C.hand
    if h then
        local vals = { string.match(plain, h.pat) }
        if #vals == #h.caps and #vals > 0 then
            local nums, _, strs = Split(vals, h.caps)
            if strs[1] and nums[1] then
                R.AddHand(CleanName(strs[1]), nums[1], nums[2] or 1, nums[3] or 100)
                return "hand"
            end
        end
    end
    return nil
end

function R.AddHand(player, value, lo, hi)
    if not R.InGroup() then return false end
    local now = R.Now()
    local h = R.hand
    if h.last > 0 and now - h.last > HAND_IDLE then h.rolls = {} end
    h.last = now
    h.rolls[player] = { player = player, value = value, lo = lo, hi = hi, t = now }
    h.lo, h.hi = h.lo or lo, h.hi or hi
    if #R.HandSorted() == 1 then h.lo, h.hi = lo, hi end
    R.handDismissed = false
    R.Update()
    return true
end

function R.HandSorted()
    local list = {}
    for _, r in pairs(R.hand.rolls) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if a.t ~= b.t then return a.t < b.t end
        return a.player < b.player
    end)
    return list
end

local KIND_ORDER = { need = 1, greed = 2, de = 3 }

-- Zeilen fuer das Beute-Fenster: je Gegenstand die Wuerfe (Bedarf vor Gier vor Entzaubern, dann hoechste Zahl)
function R.LootRows()
    local rows = {}
    for _, it in ipairs(R.items) do
        local list = {}
        for _, r in pairs(it.rolls) do list[#list + 1] = r end
        table.sort(list, function(a, b)
            local ka, kb = KIND_ORDER[a.kind or ""] or 9, KIND_ORDER[b.kind or ""] or 9
            if ka ~= kb then return ka < kb end
            local va, vb = a.value or -1, b.value or -1
            if va ~= vb then return va > vb end
            return a.player < b.player
        end)
        if #list == 0 then
            rows[#rows + 1] = { item = it, empty = true }
        else
            for _, r in ipairs(list) do
                rows[#rows + 1] = { item = it, roll = r, winner = (it.winner == r.player) }
            end
        end
    end
    return rows
end

-- Alte Eintraege entfernen; Rueckgabe: wurde etwas entfernt
function R.Prune()
    local now = R.Now()
    local changed = false
    for i = #R.items, 1, -1 do
        local it = R.items[i]
        if (it.doneAt and now - it.doneAt > DONE_KEEP) or (not it.doneAt and now - it.t > OPEN_KEEP) then
            table.remove(R.items, i)
            changed = true
        end
    end
    return changed
end

function R.Reset()
    R.items, R.hand = {}, { rolls = {}, last = 0 }
    R.lootDismissed, R.handDismissed = false, false
    R.seen, R.seenN = {}, 0
end

------------------------------------------------------------------------
-- Oberflaeche
------------------------------------------------------------------------

local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_H, ROW_GAP = 24, 2
local WIDTH = 310

local function IconFor(link)
    local ok, a, b, c, d, e = pcall(function() return G.GetItemInfoInstant(link) end)
    if ok and e then return e end
    ok, a, b, c, d, e = pcall(function() return G.GetItemInfo(link) end)
    if ok then
        local icon = select(10, G.GetItemInfo(link))
        if icon then return icon end
    end
    return QUESTION
end
R.IconFor = IconFor

local function ColorOf(fs, key)
    if fs and fs.SetTextColor and UI.Color then fs:SetTextColor(UI.Color(key)) end
end

local function SavePos(f, key)
    local o = R.Opts()
    local cx, cy = f:GetCenter()
    local ax, ay = G.UIParent:GetCenter()
    if cx and ax and cy and ay then
        o[key] = { x = math.floor(cx - ax + 0.5), y = math.floor(cy - ay + 0.5) }
    end
end

local function MakeWindow(key, title, defX, defY)
    local f = UI.CreatePanel(G.UIParent, "panel", "bronze")
    f:SetSize(WIDTH, 80)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, key) end)
    local p = R.Opts()[key]
    f:ClearAllPoints()
    f:SetPoint("CENTER", G.UIParent, "CENTER", p and p.x or defX, p and p.y or defY)
    f.title = UI.CreateLabel(f, title, { size = 13 })
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    ColorOf(f.title, "gold")
    f.rows = {}
    f:Hide()
    return f
end

local function MakeRow(f, i)
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(WIDTH - 16, ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(ROW_H - 2, ROW_H - 2)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints()
    row.icon:SetScript("OnEnter", function(self)
        local link = self.link
        if not link then return end
        G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local id = string.match(link, "\124H(item:[^\124]*)\124h")
        if not pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, id or link) then
            G.GameTooltip:SetText(string.match(link, "%[(.-)%]") or "?")
        end
        G.GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function() G.GameTooltip:Hide() end)
    row.dice = row:CreateTexture(nil, "ARTWORK")
    row.dice:SetSize(18, 18)
    row.dice:SetTexture(DICE)
    row.value = row:CreateFontString(nil, "OVERLAY")
    UI.SetFont(row.value, "body", 13)
    row.value:SetWidth(34)
    row.value:SetJustifyH("RIGHT")
    row.name = row:CreateFontString(nil, "OVERLAY")
    UI.SetFont(row.name, "body", 12)
    row.name:SetJustifyH("LEFT")
    row.tag = row:CreateFontString(nil, "OVERLAY")
    UI.SetFont(row.tag, "body", 10)
    row.tag:SetJustifyH("RIGHT")
    row.tag:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    return row
end

local function PlaceRow(f, row, i, withIcon)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28 - (i - 1) * (ROW_H + ROW_GAP))
    row.dice:ClearAllPoints()
    row.value:ClearAllPoints()
    row.name:ClearAllPoints()
    local x = 2
    if withIcon then
        row.icon:Show()
        x = ROW_H + 4
    else
        row.icon:Hide()
    end
    row.dice:SetPoint("LEFT", row, "LEFT", x, 0)
    row.value:SetPoint("LEFT", row.dice, "RIGHT", 2, 0)
    row.name:SetPoint("LEFT", row.value, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.tag, "LEFT", -4, 0)
end

local lootF, handF

local function KindText(kind)
    local L = FW.L
    if kind == "need" then return L.ROLLWIN_NEED end
    if kind == "greed" then return L.ROLLWIN_GREED end
    if kind == "de" then return L.ROLLWIN_DE end
    return ""
end

local function BuildLoot()
    if lootF then return lootF end
    local L = FW.L
    lootF = MakeWindow("lootPos", L.ROLLWIN_TITLE, 330, 120)
    lootF.close = UI.CreateButton(lootF, L.ROLLWIN_BTN_CLOSE, 90, 22, function()
        R.lootDismissed = true
        lootF:Hide()
    end)
    local acc = 0
    lootF:SetScript("OnUpdate", function(_, el)
        acc = acc + (el or 0)
        if acc < 1 then return end
        acc = 0
        if R.Prune() then R.Update() end
    end)
    return lootF
end

local function BuildHand()
    if handF then return handF end
    local L = FW.L
    handF = MakeWindow("handPos", L.ROLLWIN_TITLE_HAND, -330, 120)
    handF.roll = UI.CreateButton(handF, L.ROLLWIN_BTN_ROLL, 100, 24, function()
        local h = R.hand
        local lo, hi = h.lo or 1, h.hi or 100
        if G.RandomRoll then pcall(G.RandomRoll, lo, hi)
        elseif G.RunMacroText then pcall(G.RunMacroText, "/roll " .. lo .. "-" .. hi) end
    end, "primary")
    handF.close = UI.CreateButton(handF, L.ROLLWIN_BTN_CLOSE, 100, 24, function()
        R.handDismissed = true
        handF:Hide()
    end)
    return handF
end

local function RefreshLoot()
    local rows = R.LootRows()
    if not R.Opts().loot or R.lootDismissed or #rows == 0 then
        if lootF then lootF:Hide() end
        return
    end
    local f = BuildLoot()
    local L = FW.L
    local n = math.min(#rows, 16)
    for i = 1, n do
        local row = f.rows[i] or MakeRow(f, i)
        f.rows[i] = row
        PlaceRow(f, row, i, true)
        local d = rows[i]
        row.icon.link = d.item.link
        row.icon.tex:SetTexture(IconFor(d.item.link))
        if d.empty then
            row.dice:Hide()
            row.value:SetText("")
            row.name:SetText(L.ROLLWIN_WAIT)
            ColorOf(row.name, "textDim")
            row.tag:SetText("")
        else
            row.dice:Show()
            row.value:SetText(d.roll.value and tostring(d.roll.value) or "...")
            row.name:SetText(d.roll.player)
            row.tag:SetText(d.winner and L.ROLLWIN_WON or KindText(d.roll.kind))
            local key = d.winner and "gold" or "text"
            ColorOf(row.value, key)
            ColorOf(row.name, key)
            ColorOf(row.tag, d.winner and "gold" or "textDim")
        end
        local r, g, b, a = 1, 1, 1, 0
        if d.winner then r, g, b, a = 0.78, 0.61, 0.24, 0.22
        elseif i % 2 == 0 then a = 0.06 end
        row.bg:SetColorTexture(r, g, b, a)
        row:Show()
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f:SetHeight(28 + n * (ROW_H + ROW_GAP) + 34)
    f.close:ClearAllPoints()
    f.close:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    f:Show()
end

local function RefreshHand()
    local list = R.HandSorted()
    if not R.Opts().hand or R.handDismissed or #list == 0 then
        if handF then handF:Hide() end
        return
    end
    local f = BuildHand()
    local n = math.min(#list, 16)
    for i = 1, n do
        local row = f.rows[i] or MakeRow(f, i)
        f.rows[i] = row
        PlaceRow(f, row, i, false)
        local d = list[i]
        row.dice:Show()
        row.value:SetText(tostring(d.value))
        row.name:SetText(d.player)
        local extra = ""
        if d.lo ~= (R.hand.lo or 1) or d.hi ~= (R.hand.hi or 100) then extra = d.lo .. "-" .. d.hi end
        row.tag:SetText(extra)
        local key = i == 1 and "gold" or "text"
        ColorOf(row.value, key)
        ColorOf(row.name, key)
        ColorOf(row.tag, "textDim")
        row.bg:SetColorTexture(0.78, 0.61, 0.24, i == 1 and 0.22 or (i % 2 == 0 and 0.06 or 0))
        row:Show()
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f:SetHeight(28 + n * (ROW_H + ROW_GAP) + 38)
    f.roll:ClearAllPoints()
    f.roll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 36, 8)
    f.close:ClearAllPoints()
    f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 8)
    f:Show()
end

R.noUI = false
function R.Update()
    if R.noUI then return end
    local ok, err = pcall(function() RefreshLoot(); RefreshHand() end)
    if not ok then
        R.lastError = err
        if not R.errShown and FW.Print then
            R.errShown = true
            FW:Print("Würfelfenster: " .. tostring(err))
        end
    end
end

-- Beispiel zum Ansehen (/fwroll)
function R.Demo()
    local now = R.Now()
    R.Reset()
    local link = "\124cff0070dd\124Hitem:2589:0:0:0:0:0:0:0\124h[Leinenstoff]\124h\124r"
    local link2 = "\124cffa335ee\124Hitem:12940:0:0:0:0:0:0:0\124h[Dunkles Rüstzeug]\124h\124r"
    local it = GetItem(link)
    Roll(it, "Anna").kind, Roll(it, "Anna").value = "need", 87
    Roll(it, "Bert").kind, Roll(it, "Bert").value = "need", 42
    Roll(it, SelfName()).kind, Roll(it, SelfName()).value = "greed", 95
    it.winner, it.doneAt = "Anna", now
    local it2 = GetItem(link2)
    Roll(it2, "Cora").kind, Roll(it2, "Cora").value = "greed", 12
    Roll(it2, "Dino").kind = "need"
    local saved = R.InGroup
    R.InGroup = function() return true end
    R.AddHand("Anna", 64, 1, 100)
    R.AddHand("Bert", 91, 1, 100)
    R.AddHand(SelfName(), 23, 1, 100)
    R.InGroup = saved
    R.Update()
end

------------------------------------------------------------------------
-- Ereignisse, Befehl, Einstellungen
------------------------------------------------------------------------

for _, e in ipairs({ "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM" }) do
    FW:RegisterEvent(e, function(text) R.Feed(text) end)
end

FW:RegisterEvent("START_LOOT_ROLL", function(rollID)
    if Secret(rollID) or not G.GetLootRollItemLink then return end
    local ok, link = pcall(G.GetLootRollItemLink, rollID)
    if ok and type(link) == "string" and not Secret(link) then
        GetItem(link)
        R.Update()
    end
end)

if G.SlashCmdList then
    G.SLASH_FWROLL1 = "/fwroll"
    G.SlashCmdList["FWROLL"] = function()
        R.Demo()
        if FW.Print then FW:Print(FW.L.ROLLWIN_TEST_DONE) end
    end
end

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("roll-window", {
        category = "chat",
        order = 6,
        height = 150,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.ROLLWIN_SECTION)
            stack:Add(UI.CreateLabel(f, L.ROLLWIN_HINT, { size = 11, color = "textDim" }), { fit = true, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, L.ROLLWIN_LOOT,
                function() return R.Opts().loot == true end,
                function(v) R.Opts().loot = v and true or false; R.Update() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.ROLLWIN_HAND,
                function() return R.Opts().hand == true end,
                function(v) R.Opts().hand = v and true or false; R.Update() end), { fit = true })
            return f
        end,
    })
end
