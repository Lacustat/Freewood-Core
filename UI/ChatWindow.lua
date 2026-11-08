-- Freewood-Core: eigenes Chatfenster mit Blasen (Aussehen wie der Reiter "Kanaele"). Das Chatfenster des Spiels bleibt unveraendert.
-- Quellen: Core/ChatLog.lua ruft FW.ChatWindow.Push(key, sender, text, eigeneNachricht) auf (Gilde, Gruppe, Fluestern, Kanaele);
-- Sagen, Rufen und Emotes kommen direkt aus den Chat-Ereignissen. Nachrichten liegen nur im Speicher (letzte 300).
-- Eingabefeld: kein Autofokus (sonst nimmt es der Tastatur den Fokus, siehe F-28). UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local W = {}
FW.ChatWindow = W

W.DEFAULTS = {
    enabled = true,
    locked = false,
    point = "BOTTOMLEFT", x = 34, y = 340, w = 560, h = 300,
    alpha = 85,           -- Deckkraft des Fensterhintergrunds in Prozent
    say = true,           -- Sagen und Rufen
    emote = false,
    tab = "all",
}

local MAX_MSGS = 300
local MAX_BUBBLES = 40
local MIN_W, MIN_H = 360, 200
local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    MAGE = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    ROGUE = "Interface\\Icons\\Ability_Stealth",
    DRUID = "Interface\\Icons\\Spell_Nature_HealingTouch",
    HUNTER = "Interface\\Icons\\Ability_Marksmanship",
    SHAMAN = "Interface\\Icons\\Spell_Nature_BloodLust",
    PRIEST = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    WARLOCK = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    PALADIN = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

-- Arten und Reiter
W.KINDS = { "say", "yell", "emote", "guild", "group", "whisper", "channel" }
W.TABS = {
    { "all", "CHATWIN_TAB_ALL", nil },
    { "say", "CHATWIN_TAB_SAY", { say = true, yell = true, emote = true } },
    { "guild", "CHATWIN_TAB_GUILD", { guild = true } },
    { "group", "CHATWIN_TAB_GROUP", { group = true } },
    { "whisper", "CHATWIN_TAB_WHISPER", { whisper = true } },
    { "channel", "CHATWIN_TAB_CHANNEL", { channel = true } },
}
local KIND_COLOR = {
    say = { 1, 1, 1 }, yell = { 1, 0.25, 0.25 }, emote = { 1, 0.5, 0.25 }, guild = { 0.25, 1, 0.25 },
    group = { 0.67, 0.67, 1 }, whisper = { 1, 0.5, 1 }, channel = { 1, 0.75, 0.75 },
}
local KIND_LABEL = { say = "CHATWIN_K_SAY", yell = "CHATWIN_K_YELL", emote = "CHATWIN_K_EMOTE", guild = "CHAT_GUILD", group = "CHAT_GROUP",
    whisper = "CHAN_WHISPER", channel = nil }

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

function W.Opts()
    local s = FW.settings
    if type(s) ~= "table" then return W.DEFAULTS end
    if type(s.chatWin) ~= "table" then s.chatWin = {} end
    local o = s.chatWin
    for k, v in pairs(W.DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

------------------------------------------------------------------------
-- Nachrichten
------------------------------------------------------------------------

W.msgs = {}
W.unread = {}
W.version = 0
W.target = nil          -- Fluesterziel nach Klick auf einen Namen

-- Schluessel des Chat-Protokolls -> Art, Zusatz (Kanalname / Fluesterpartner)
function W.Classify(key)
    if key == "guild" then return "guild" end
    if key == "group" then return "group" end
    if type(key) ~= "string" then return nil end
    local pre, rest = string.sub(key, 1, 2), string.sub(key, 3)
    if pre == "w:" then return "whisper", rest end
    if pre == "c:" then return "channel", rest end
    return nil
end

function W.KindEnabled(kind)
    local o = W.Opts()
    if kind == "say" or kind == "yell" then return o.say ~= false end
    if kind == "emote" then return o.emote == true end
    return true
end

local function Now() return (G.time and G.time()) or 0 end

function W.Add(kind, sender, text, out, extra)
    if not kind or type(text) ~= "string" or text == "" or Secret(text) then return end
    if type(sender) ~= "string" or Secret(sender) then sender = "?" end
    if not W.KindEnabled(kind) then return end
    local list = W.msgs
    list[#list + 1] = { t = Now(), s = sender, m = text, kind = kind, o = out and true or nil, x = extra }
    if #list > MAX_MSGS + 40 then
        local new = {}
        for i = #list - MAX_MSGS + 1, #list do new[#new + 1] = list[i] end
        W.msgs = new
    end
    W.version = W.version + 1
    -- ungelesen zaehlen (fuer den Reiter, der gerade nicht offen ist)
    local cur = W.Opts().tab or "all"
    for _, t in ipairs(W.TABS) do
        if t[1] ~= "all" and t[3] and t[3][kind] and cur ~= t[1] and cur ~= "all" then
            W.unread[t[1]] = (W.unread[t[1]] or 0) + 1
        end
    end
    if W.Dirty then W.Dirty() end
end

function W.Push(key, sender, text, out)
    local kind, extra = W.Classify(key)
    if kind then W.Add(kind, sender, text, out, extra) end
end

-- Nachrichten eines Reiters (aelteste zuerst)
function W.Visible(tabKey)
    local def
    for _, t in ipairs(W.TABS) do if t[1] == tabKey then def = t end end
    local set = def and def[3] or nil
    local out = {}
    for _, m in ipairs(W.msgs) do
        if (not set or set[m.kind]) and W.KindEnabled(m.kind) then out[#out + 1] = m end
    end
    return out
end

------------------------------------------------------------------------
-- Eingabe: Ziel bestimmen
------------------------------------------------------------------------

-- Rueckgabe: Art ("say", "yell", "guild", "group", "whisper", "channel"), Ziel, Text; oder nil, Fehlertext
function W.ParseInput(text, tabKey, target)
    if type(text) ~= "string" then return nil end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return nil end
    local cmd, rest = string.match(text, "^/(%S+)%s*(.*)$")
    if cmd then
        cmd = string.lower(cmd)
        if cmd == "s" or cmd == "say" then return "say", nil, rest end
        if cmd == "y" or cmd == "yell" or cmd == "sch" then return "yell", nil, rest end
        if cmd == "g" or cmd == "gilde" or cmd == "guild" then return "guild", nil, rest end
        if cmd == "p" or cmd == "party" or cmd == "gruppe" or cmd == "r" or cmd == "raid" then return "group", nil, rest end
        if cmd == "w" or cmd == "whisper" or cmd == "t" or cmd == "tell" then
            local who, msg = string.match(rest, "^(%S+)%s+(.+)$")
            if who then return "whisper", who, msg end
            return nil, "usage"
        end
        local n = tonumber(cmd)
        if n then return "channel", n, rest end
        return nil, "unknown"
    end
    if target and target ~= "" then return "whisper", target, text end
    if tabKey == "guild" then return "guild", nil, text end
    if tabKey == "group" then return "group", nil, text end
    return "say", nil, text
end

function W.Send(kind, target, text)
    if not kind or type(text) ~= "string" or text == "" or not G.SendChatMessage then return false end
    local CL = FW.ChatLog
    if kind == "say" then pcall(G.SendChatMessage, text, "SAY")
    elseif kind == "yell" then pcall(G.SendChatMessage, text, "YELL")
    elseif CL and CL.Send then CL.Send(kind, target, text)
    else return false end
    return true
end

------------------------------------------------------------------------
-- Sagen, Rufen, Emotes aus den Chat-Ereignissen
------------------------------------------------------------------------

local function IsMe(sender)
    if type(sender) ~= "string" then return false end
    local n = G.UnitName and G.UnitName("player")
    if type(n) == "string" and not Secret(n) and sender == n then return true end
    local Wh = FW.Whisper
    local full = Wh and Wh.SelfName and Wh.SelfName()
    return type(full) == "string" and sender == full
end

local function OnSpeech(kind, text, sender, textEmote)
    if type(text) ~= "string" or Secret(text) or type(sender) ~= "string" or Secret(sender) then return end
    local out = IsMe(sender)
    if textEmote then out = false end
    W.Add(kind, sender, text, out)
end

FW:RegisterEvent("CHAT_MSG_SAY", function(text, sender) OnSpeech("say", text, sender) end)
FW:RegisterEvent("CHAT_MSG_YELL", function(text, sender) OnSpeech("yell", text, sender) end)
FW:RegisterEvent("CHAT_MSG_EMOTE", function(text, sender) OnSpeech("emote", (sender or "?") .. " " .. tostring(text or ""), sender) end)
FW:RegisterEvent("CHAT_MSG_TEXT_EMOTE", function(text, sender) OnSpeech("emote", text, sender, true) end)

------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------

local frame, built
local bubbles = {}
local dirty, dirtyAt = false, 0

local function Hex(r, g, b)
    return string.format("\124cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Plain(t)
    local CL = FW.ChatLog
    if CL and CL.Plain then return CL.Plain(t) end
    return tostring(t or "")
end

local function KindColor(kind)
    local c = KIND_COLOR[kind] or { 1, 1, 1 }
    local S = FW.ChatStyle
    if S and S.Opts then
        local ty = S.Opts().types
        local key = (kind == "yell" and "yell") or (kind == "say" and "say") or (kind == "emote" and "emote") or (kind == "guild" and "guild")
            or (kind == "group" and "party") or (kind == "whisper" and "whisper") or (kind == "channel" and "channel") or nil
        local e = key and type(ty) == "table" and ty[key]
        if e and type(e.bar) == "table" then return e.bar[1], e.bar[2], e.bar[3] end
    end
    return c[1], c[2], c[3]
end

function W.Dirty() dirty, dirtyAt = true, (G.GetTime and G.GetTime() or 0) end

local function ParseLinks(text)
    local out, pos = {}, 1
    text = text or ""
    while true do
        local a, b, data, name = string.find(text, "\124H([^\124]+)\124h%[(.-)%]\124h", pos)
        if not a then break end
        out[#out + 1] = { data = data, name = name }
        pos = b + 1
        if #out >= 8 then break end
    end
    return out
end

local function Stamp(t)
    if not (t and G.date) then return "" end
    local ok, s = pcall(G.date, "%H:%M", t)
    return ok and s or ""
end

local function Bubble(i, parent)
    local b = bubbles[i]
    if b then return b end
    b = CreateFrame("Frame", nil, parent)
    b:SetHeight(60)
    b.avBtn = CreateFrame("Button", nil, b)
    b.avBtn:SetSize(36, 36)
    b.av = b.avBtn:CreateTexture(nil, "ARTWORK")
    b.av:SetAllPoints()
    b.lvl = UI.CreateLabel(b, "", { size = 11, color = "textDim" })
    b.panel = CreateFrame("Button", nil, b)
    b.panel:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.bg = b.panel:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bar = b.panel:CreateTexture(nil, "BORDER")
    b.bar:SetWidth(3)
    b.bar:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 0, 0)
    b.bar:SetPoint("BOTTOMLEFT", b.panel, "BOTTOMLEFT", 0, 0)
    b.hl = b.panel:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.05)
    b.name = UI.CreateLabel(b.panel, "", { size = 12, justify = "LEFT" })
    b.name:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -7)
    b.time = UI.CreateLabel(b.panel, "", { size = 10, color = "textDim", justify = "RIGHT" })
    b.time:SetPoint("TOPRIGHT", b.panel, "TOPRIGHT", -8, -8)
    b.text = UI.CreateLabel(b.panel, "", { size = 12, justify = "LEFT", justifyV = "TOP" })
    b.text:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -24)
    bubbles[i] = b
    return b
end

local function SetTarget(name)
    W.target = name
    if W.RefreshInput then W.RefreshInput() end
end

local function ShowLink(lk)
    local full = "\124cffffffff\124H" .. lk.data .. "\124h[" .. lk.name .. "]\124h\124r"
    if G.SetItemRef then pcall(G.SetItemRef, lk.data, full, "LeftButton") end
end

local lastH, lastViewH, stick = 0, 0, true

function W.Draw()
    if not built then return end
    local o = W.Opts()
    local CL = FW.ChatLog
    local L = FW.L
    local list = W.Visible(o.tab or "all")
    local n = #list
    local first = math.max(1, n - MAX_BUBBLES + 1)
    local chat = built.chat
    local areaW = chat.child:GetWidth()
    if not areaW or areaW < 150 then areaW = (o.w or 560) - 40 end
    local maxBub = math.floor(areaW * 0.78)
    local atBottom = stick or (chat.scroll:GetVerticalScroll() >= lastH - lastViewH - 8)
    local y, idx = 6, 0
    for i = first, n do
        local m = list[i]
        idx = idx + 1
        local b = Bubble(idx, chat.child)
        local own = m.o == true
        local who = m.s or "?"
        local cls, lv
        if CL and CL.Info then cls, lv = CL.Info(who) end
        b.av:SetTexture((cls and CLASS_ICONS[cls]) or QMARK)
        b.av:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.lvl:SetText(lv and tostring(lv) or "")
        local nr, ng, nb = 0.9, 0.89, 0.84
        if CL and CL.ClassColor then nr, ng, nb = CL.ClassColor(cls) end
        b.name:SetTextColor(nr, ng, nb)
        local tag = ""
        if m.kind == "channel" then tag = m.x and ("  [" .. m.x .. "]") or ""
        elseif m.kind == "whisper" then tag = "  [" .. (L.CHAN_WHISPER or "Whisper") .. "]"
        elseif KIND_LABEL[m.kind] then tag = "  [" .. (L[KIND_LABEL[m.kind]] or m.kind) .. "]" end
        local kr, kg, kb = KindColor(m.kind)
        b.name:SetText(who .. (tag ~= "" and (Hex(kr, kg, kb) .. tag .. "\124r") or ""))
        b.time:SetText(Stamp(m.t))
        local txt = m.m or ""
        built.measure:SetText(Plain(txt))
        local tw = built.measure:GetStringWidth() or 0
        if tw <= 0 then tw = maxBub end
        local nameW = (b.name:GetStringWidth() or 60) + (b.time:GetStringWidth() or 40) + 40
        local pw = math.floor(math.max(math.min(math.max(tw, nameW) + 22, maxBub), 110))
        b.text:SetWidth(pw - 20)
        b.text:SetText(txt)
        local th = (b.text.GetStringHeight and b.text:GetStringHeight()) or 14
        if not th or th < 14 then th = 14 end
        local ph = math.floor(th + 38)
        b.panel:SetSize(pw, ph)
        if own then b.bg:SetColorTexture(0.13, 0.27, 0.46, 0.95) else b.bg:SetColorTexture(UI.Color("card", 0.95)) end
        b.bar:SetColorTexture(kr, kg, kb, 1)
        local rowH = math.max(ph, 56)
        b:SetSize(areaW - 8, rowH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", chat.child, "TOPLEFT", 0, -y)
        b.avBtn:ClearAllPoints(); b.lvl:ClearAllPoints(); b.panel:ClearAllPoints()
        if own then
            b.avBtn:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, 0)
            b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
            b.panel:SetPoint("TOPRIGHT", b.avBtn, "TOPLEFT", -8, 0)
        else
            b.avBtn:SetPoint("TOPLEFT", b, "TOPLEFT", 6, 0)
            b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
            b.panel:SetPoint("TOPLEFT", b.avBtn, "TOPRIGHT", 8, 0)
        end
        local links = ParseLinks(txt)
        local sender = who
        b.avBtn:SetScript("OnClick", function() if sender ~= "?" then SetTarget(sender) end end)
        b.panel:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                if sender ~= "?" then SetTarget(sender) end
            elseif #links >= 1 then
                ShowLink(links[1])
            end
        end)
        if #links == 1 then
            local lk = links[1]
            b.panel:SetScript("OnEnter", function()
                if G.GameTooltip then
                    pcall(G.GameTooltip.SetOwner, G.GameTooltip, b.panel, "ANCHOR_RIGHT")
                    pcall(G.GameTooltip.SetHyperlink, G.GameTooltip, lk.data)
                    pcall(G.GameTooltip.Show, G.GameTooltip)
                end
            end)
            b.panel:SetScript("OnLeave", function() if G.GameTooltip then pcall(G.GameTooltip.Hide, G.GameTooltip) end end)
        else
            b.panel:SetScript("OnEnter", nil)
            b.panel:SetScript("OnLeave", nil)
        end
        b:Show()
        y = y + rowH + 8
    end
    idx = idx + 1
    while bubbles[idx] do bubbles[idx]:Hide(); idx = idx + 1 end
    local viewH = chat.scroll:GetHeight() or 200
    chat:SetContentHeight(math.max(1, y))
    lastH, lastViewH = y, viewH
    if atBottom then
        chat.scroll:SetVerticalScroll(math.max(0, y - viewH))
        chat.UpdateScroll()
    end
    stick = false
    dirty = false
end

local function TabText(t)
    local L = FW.L
    local u = W.unread[t[1]]
    local txt = L[t[2]] or t[1]
    if u and u > 0 then txt = txt .. " (" .. u .. ")" end
    return txt
end

local function RefreshTabs()
    if not built then return end
    local cur = W.Opts().tab or "all"
    for _, tb in ipairs(built.tabs) do
        tb.btn:SetLabel(TabText(tb.def))
        tb.btn:SetStyle(tb.def[1] == cur and "primary" or "default")
    end
end

function W.SelectTab(key)
    W.Opts().tab = key
    W.unread[key] = nil
    stick = true
    RefreshTabs()
    if W.RefreshInput then W.RefreshInput() end
    W.Draw()
end

function W.RefreshInput()
    if not built then return end
    local L = FW.L
    local o = W.Opts()
    local label
    if W.target then
        label = (L.CHATWIN_TO or "To") .. ": " .. W.target .. "  (x)"
    elseif o.tab == "guild" then label = L.CHAT_GUILD
    elseif o.tab == "group" then label = L.CHAT_GROUP
    else label = L.CHATWIN_K_SAY end
    built.target:SetText(label or "")
end

function W.SavePosition()
    if not frame then return end
    local o = W.Opts()
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local ui = G.UIParent and G.UIParent.GetEffectiveScale and G.UIParent:GetEffectiveScale() or 1
    local me = frame.GetEffectiveScale and frame:GetEffectiveScale() or ui
    if left and bottom and ui > 0 then
        o.point, o.x, o.y = "BOTTOMLEFT", math.floor(left * me / ui + 0.5), math.floor(bottom * me / ui + 0.5)
    end
    local w, h = frame:GetWidth(), frame:GetHeight()
    if w and h then o.w, o.h = math.floor(w + 0.5), math.floor(h + 0.5) end
end

function W.ApplyPosition()
    if not frame then return end
    local o = W.Opts()
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", o.x or 34, o.y or 340)
    frame:SetSize(math.max(MIN_W, o.w or 560), math.max(MIN_H, o.h or 300))
end

function W.ApplyLook()
    if not built then return end
    local o = W.Opts()
    built.bg:SetColorTexture(UI.Color("bgDeep", (tonumber(o.alpha) or 85) / 100))
    if built.grip then if o.locked then built.grip:Hide() else built.grip:Show() end end
end

-- Auf den Platz des Spiel-Chats setzen
function W.MoveToGameChat()
    local cf = G.ChatFrame1
    if not (cf and frame and cf.GetLeft) then return false end
    local left, bottom, w, h = cf:GetLeft(), cf:GetBottom(), cf:GetWidth(), cf:GetHeight()
    if not (left and bottom and w and h) then return false end
    local ui = G.UIParent.GetEffectiveScale and G.UIParent:GetEffectiveScale() or 1
    local sc = (cf.GetEffectiveScale and cf:GetEffectiveScale() or ui) / ui
    local o = W.Opts()
    o.x, o.y = math.floor(left * sc + 0.5), math.floor(bottom * sc + 0.5)
    o.w, o.h = math.floor(w * sc + 0.5), math.floor(h * sc + 0.5)
    W.ApplyPosition()
    stick = true
    W.Dirty()
    return true
end

function W.ResetPosition()
    local o = W.Opts()
    o.point, o.x, o.y, o.w, o.h = W.DEFAULTS.point, W.DEFAULTS.x, W.DEFAULTS.y, W.DEFAULTS.w, W.DEFAULTS.h
    W.ApplyPosition()
    stick = true
    W.Dirty()
end

function W.SetShown(on)
    local o = W.Opts()
    o.enabled = on and true or false
    if on then W.Build() end
    if frame then if o.enabled then frame:Show(); stick = true; W.Dirty() else frame:Hide() end end
end

function W.Build()
    if built or not G.UIParent or not UI.CreateScrollFrame then return built ~= nil end
    local L = FW.L
    local o = W.Opts()
    frame = CreateFrame("Frame", "FreewoodChatWindow", G.UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then pcall(frame.SetResizeBounds, frame, MIN_W, MIN_H)
    elseif frame.SetMinResize then pcall(frame.SetMinResize, frame, MIN_W, MIN_H) end
    built = { tabs = {} }
    built.bg = frame:CreateTexture(nil, "BACKGROUND")
    built.bg:SetAllPoints()
    UI.AddBorder(frame, "bronze")

    -- Kopfzeile mit Reitern (zum Verschieben anfassen)
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    head:SetHeight(30)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() if not W.Opts().locked then frame:StartMoving() end end)
    head:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); W.SavePosition() end)
    local x = 4
    for _, def in ipairs(W.TABS) do
        local btn = UI.CreateButton(head, TabText(def), 74, 22, function() W.SelectTab(def[1]) end, "default")
        btn:SetPoint("LEFT", head, "LEFT", x, 0)
        x = x + 76
        built.tabs[#built.tabs + 1] = { def = def, btn = btn }
    end
    local close = UI.CreateButton(head, "x", 22, 22, function() W.SetShown(false) end, "default")
    close:SetPoint("RIGHT", head, "RIGHT", -4, 0)

    -- Eingabe
    local ibox = UI.CreatePanel(frame, "bgDeep", "bronze")
    ibox:SetHeight(28)
    ibox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
    ibox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -100, 6)
    local tgt = CreateFrame("Button", nil, ibox)
    tgt:SetPoint("LEFT", ibox, "LEFT", 6, 0)
    tgt:SetHeight(22)
    tgt:SetWidth(96)
    built.target = UI.CreateLabel(tgt, "", { size = 11, color = "goldLight", justify = "LEFT" })
    built.target:SetPoint("LEFT", tgt, "LEFT", 0, 0)
    tgt:SetScript("OnClick", function() SetTarget(nil) end)
    local input = CreateFrame("EditBox", nil, ibox)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", ibox, "TOPLEFT", 106, -3)
    input:SetPoint("BOTTOMRIGHT", ibox, "BOTTOMRIGHT", -8, 3)
    input:SetMaxLetters(255)
    UI.SetFont(input, "body", 12)
    input:SetTextColor(UI.Color("text"))
    local ihint = UI.CreateLabel(ibox, L.CHAT_INPUT, { size = 12, color = "textDim" })
    ihint:SetPoint("LEFT", ibox, "LEFT", 110, 0)
    local function DoSend()
        local txt = input:GetText() or ""
        local kind, target, msg = W.ParseInput(txt, W.Opts().tab, W.target)
        if not kind then
            if target == "unknown" and FW.Print then FW:Print(L.CHATWIN_UNKNOWN_CMD or "Unknown command") end
            return
        end
        if W.Send(kind, target, msg) then input:SetText("") end
    end
    input:SetScript("OnEnterPressed", function() DoSend(); input:SetFocus() end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnTextChanged", function(self)
        if (self:GetText() or "") == "" then ihint:Show() else ihint:Hide() end
    end)
    local sendBtn = UI.CreateButton(frame, L.CHAT_SEND, 88, 28, DoSend)
    sendBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    built.input = input

    -- Chatbereich
    built.chat = UI.CreateScrollFrame(frame)
    built.chat:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -34)
    built.chat:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 40)
    built.measure = frame:CreateFontString(nil, "OVERLAY")
    UI.SetFont(built.measure, "body", 12)
    built.measure:Hide()

    -- Groesse aendern
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local gt = grip:CreateTexture(nil, "OVERLAY")
    gt:SetAllPoints()
    gt:SetColorTexture(UI.Color("bronze", 0.8))
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetScript("OnMouseDown", function() if not W.Opts().locked then frame:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); W.SavePosition(); stick = false; W.Dirty() end)
    built.grip = grip
    frame:SetScript("OnSizeChanged", function() W.Dirty() end)

    frame:SetScript("OnUpdate", function()
        if dirty then
            local now = G.GetTime and G.GetTime() or 0
            if now - dirtyAt >= 0.15 then pcall(W.Draw); RefreshTabs() end
        end
    end)

    W.ApplyPosition()
    W.ApplyLook()
    RefreshTabs()
    W.RefreshInput()
    if o.enabled then frame:Show() else frame:Hide() end
    W.Dirty()
    return true
end

function W.Test()
    local me = G.UnitName and G.UnitName("player") or "Test"
    W.Add("guild", me, (FW.L.BUBBLE_TEST_TEXT or "Test"), true)
    W.Add("say", "Testspieler", (FW.L.BUBBLE_TEST_TEXT or "Test"), false)
end

FW:On("FW_DB_READY", function()
    if W.Opts().enabled then pcall(W.Build) end
end)
FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if W.Opts().enabled then pcall(W.Build) end
end)

SLASH_FREEWOODCHATWIN1 = "/fwchatwin"
SlashCmdList = SlashCmdList or {}
SlashCmdList["FREEWOODCHATWIN"] = function()
    W.SetShown(not (W.Opts().enabled))
end

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-window", {
        category = "chat",
        order = 5,
        height = 400,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATWIN_TITLE)
            stack:Add(UI.CreateLabel(f, L.CHATWIN_HINT, { size = 11, color = "textDim" }), { height = 44, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_ENABLED,
                function() return W.Opts().enabled == true end,
                function(v) W.SetShown(v) end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_LOCKED,
                function() return W.Opts().locked == true end,
                function(v) W.Opts().locked = v and true or false; W.ApplyLook() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_SAY,
                function() return W.Opts().say ~= false end,
                function(v) W.Opts().say = v and true or false; W.Dirty() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_EMOTE,
                function() return W.Opts().emote == true end,
                function(v) W.Opts().emote = v and true or false; W.Dirty() end), { fit = true })
            local aLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(aLabel, { height = 16, gap = 10 })
            local alpha = UI.CreateSlider(f, 240, { min = 20, max = 100, step = 5,
                get = function() return tonumber(W.Opts().alpha) or 85 end,
                set = function(v) W.Opts().alpha = v; W.ApplyLook() end })
            alpha.onText = function(v) aLabel:SetText(string.format(L.CHATWIN_ALPHA, v)) end
            alpha:Refresh()
            stack:Add(alpha, { height = 20, gap = 2 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_TO_GAMECHAT, 260, 24, function() W.Build(); W.MoveToGameChat() end), { height = 24, gap = 10 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_RESET, 260, 24, function() W.Build(); W.ResetPosition() end), { height = 24, gap = 4 })
            stack:Add(UI.CreateButton(f, L.BUBBLE_TEST, 260, 24, function() W.Build(); W.Test() end), { height = 24, gap = 4 })
            return f
        end,
    })
end
