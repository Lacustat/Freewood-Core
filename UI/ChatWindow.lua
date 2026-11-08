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
    tab = "chat",         -- Kennung des offenen Reiters
    main = false,         -- Freewood-Chat ersetzt den Spiel-Chat (Spiel-Chat unsichtbar, Enter oeffnet unser Eingabefeld)
    detach = false,       -- Eingabefeld getrennt vom Fenster, nur beim Tippen sichtbar
    moveInput = false,    -- Eingabefeld zum Verschieben dauerhaft zeigen
    inX = 34, inY = 300, inW = 460,
    fontSize = 11,        -- Schriftgroesse in den Blasen und Zeilen
    maxW = 78,            -- groesste Breite einer Blase in Prozent des Fensters
    compact = true,       -- kompakte Blasen
    combatMirror = true,  -- Kampflog des Spiels in den Reiter spiegeln
    classic = false,      -- Aussehen wie der Chat des Spiels: nur Zeilen, schlichter Hintergrund
}

local CAPS = { msgs = 300, lines = 300, combat = 200 }
local MAX_ROWS = 60
local MIN_W, MIN_H = 520, 200
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

-- Nachrichtengruppen: Kennung, Textschluessel, Bereich (chat/msgs), Standard-Darstellung (bubble/line)
W.GROUPS = {
    { "say", "CHATWIN_K_SAY", "chat", "bubble" },
    { "yell", "CHATWIN_K_YELL", "chat", "bubble" },
    { "emote", "CHATWIN_K_EMOTE", "chat", "line" },
    { "guild", "CHAT_GUILD", "chat", "bubble" },
    { "group", "CHAT_GROUP", "chat", "bubble" },
    { "whisper", "CHAN_WHISPER", "chat", "bubble" },
    { "skill", "CHATWIN_G_SKILL", "msgs", "line" },
    { "xp", "CHATWIN_G_XP", "msgs", "line" },
    { "loot", "CHATWIN_G_LOOT", "msgs", "line" },
    { "money", "CHATWIN_G_MONEY", "msgs", "line" },
    { "rep", "CHATWIN_G_REP", "msgs", "line" },
    { "honor", "CHATWIN_G_HONOR", "msgs", "line" },
    { "tradeskill", "CHATWIN_G_TRADESKILL", "msgs", "line" },
    { "system", "CHATWIN_G_SYSTEM", "msgs", "line" },
    { "addon", "CHATWIN_G_ADDON", "msgs", "line" },
    { "combat", "CHATWIN_G_COMBAT", "msgs", "line" },
}
W.KINDS = {}
local DEFAULT_STYLE = { channel = "bubble" }
for _, g in ipairs(W.GROUPS) do W.KINDS[#W.KINDS + 1] = g[1]; DEFAULT_STYLE[g[1]] = g[4] end
W.KINDS[#W.KINDS + 1] = "channel"
-- Arten, die von Menschen geschrieben werden (Liste "msgs"); alles andere sind Meldungen (Liste "lines"), Kampflog separat
W.CHAT_KIND = { say = true, yell = true, emote = true, guild = true, group = true, whisper = true, channel = true }

local KIND_COLOR = {
    say = { 1, 1, 1 }, yell = { 1, 0.25, 0.25 }, emote = { 1, 0.5, 0.25 }, guild = { 0.25, 1, 0.25 },
    group = { 0.67, 0.67, 1 }, whisper = { 1, 0.5, 1 }, channel = { 1, 0.75, 0.75 },
    skill = { 0.5, 0.8, 1 }, xp = { 0.75, 0.55, 1 }, loot = { 0.6, 0.9, 0.5 }, money = { 1, 0.85, 0.3 },
    rep = { 0.4, 0.7, 1 }, honor = { 1, 0.6, 0.25 }, tradeskill = { 0.7, 0.9, 1 }, system = { 1, 1, 0.3 },
    addon = { 0.8, 0.8, 0.8 }, combat = { 0.9, 0.6, 0.6 },
}
local KIND_LABEL = { say = "CHATWIN_K_SAY", yell = "CHATWIN_K_YELL", emote = "CHATWIN_K_EMOTE", guild = "CHAT_GUILD", group = "CHAT_GROUP",
    whisper = "CHAN_WHISPER" }

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

-- Darstellung je Art: "bubble" oder "line"
function W.Style(kind)
    local st = W.Opts().styles
    if type(st) == "table" and (st[kind] == "bubble" or st[kind] == "line") then return st[kind] end
    return DEFAULT_STYLE[kind] or "bubble"
end

------------------------------------------------------------------------
-- Reiter (frei einstellbar): jeder zeigt eine Auswahl von Gruppen und Kanaelen
------------------------------------------------------------------------

local function Set(list)
    local t = {}
    for _, k in ipairs(list) do t[k] = true end
    return t
end

function W.DefaultTabs()
    return {
        { id = "chat", nameKey = "CHATWIN_TAB_CHAT",
            groups = Set({ "say", "yell", "emote", "guild", "group", "whisper", "skill", "xp", "loot", "money" }) },
        { id = "trade", nameKey = "CHATWIN_TAB_TRADE", groups = {}, channels = { "Handel", "Trade" } },
        { id = "general", nameKey = "CHATWIN_TAB_GENERAL", groups = {}, channels = { "Allgemein", "General" } },
        { id = "msgs", nameKey = "CHATWIN_TAB_MSGS", groups = Set({ "rep", "honor", "tradeskill", "system", "addon" }) },
        { id = "combat", nameKey = "CHATWIN_TAB_COMBAT", groups = Set({ "combat" }) },
    }
end

function W.Tabs()
    local o = W.Opts()
    if type(o.tabs) ~= "table" or #o.tabs == 0 then o.tabs = W.DefaultTabs() end
    return o.tabs
end

function W.FindTab(id)
    for i, t in ipairs(W.Tabs()) do
        if t.id == id then return t, i end
    end
end

function W.CurrentTab()
    local o = W.Opts()
    local t = W.FindTab(o.tab)
    if not t then t = W.Tabs()[1]; o.tab = t.id end
    return t
end

function W.TabName(t)
    local L = FW.L
    return t.name or (t.nameKey and L[t.nameKey]) or t.id
end

function W.AddTab(name)
    local o = W.Opts()
    local tabs = W.Tabs()
    local id
    repeat
        o.tabSeq = (tonumber(o.tabSeq) or 0) + 1
        id = "t" .. o.tabSeq
    until not W.FindTab(id)
    local t = { id = id, name = name or id, groups = {}, channels = {} }
    tabs[#tabs + 1] = t
    return t
end

function W.RemoveTab(id)
    local tabs = W.Tabs()
    if #tabs <= 1 then return false end
    local _, i = W.FindTab(id)
    if not i then return false end
    table.remove(tabs, i)
    W.unread[id] = nil
    if W.Opts().tab == id then W.Opts().tab = tabs[1].id end
    return true
end

function W.MoveTab(id, dir)
    local tabs = W.Tabs()
    local t, i = W.FindTab(id)
    local j = i and i + dir
    if not t or j < 1 or j > #tabs then return false end
    tabs[i], tabs[j] = tabs[j], tabs[i]
    return true
end

-- Kanalname vergleichbar machen: "3. Handel - Orgrimmar" -> "handel"
function W.NormChannel(name)
    if type(name) ~= "string" then return "" end
    local n = string.lower(name)
    n = string.gsub(n, "^%d+%.%s*", "")
    n = string.gsub(n, "%s*%-.*$", "")
    n = string.gsub(n, "^%s+", "")
    n = string.gsub(n, "%s+$", "")
    return n
end

function W.TabAccepts(t, m)
    if m.kind == "channel" then
        if t.allChannels then return true end
        local n = W.NormChannel(m.x)
        for _, c in ipairs(t.channels or {}) do
            if W.NormChannel(c) == n then return true end
        end
        return false
    end
    return t.groups ~= nil and t.groups[m.kind] == true
end

-- gesehene Kanaele merken (fuer die Auswahl im Reiter-Editor)
function W.NoteChannel(name)
    local n = W.NormChannel(name)
    if n == "" then return end
    local o = W.Opts()
    if type(o.knownChannels) ~= "table" then o.knownChannels = {} end
    for _, c in ipairs(o.knownChannels) do
        if W.NormChannel(c) == n then return end
    end
    local disp = string.gsub(name, "^%d+%.%s*", "")
    disp = string.gsub(disp, "%s*%-.*$", "")
    o.knownChannels[#o.knownChannels + 1] = disp
end

------------------------------------------------------------------------
-- Nachrichten
------------------------------------------------------------------------

W.msgs = {}      -- von Menschen geschrieben (Sagen, Gilde, Fluestern, Kanaele ...)
W.lines = {}     -- Meldungen (Beute, Erfahrung, System, Addons ...)
W.combat = {}    -- Kampflog
W.seq = 0
W.unread = {}
W.version = 0
W.target = nil          -- Fluesterziel nach Klick auf einen Namen
W.sendKind = "say"      -- wohin das Eingabefeld ohne Befehl sendet (say, yell, guild, group, channel)
W.channel = nil         -- Kanalnummer bei sendKind "channel"

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

local function Now() return (G.time and G.time()) or 0 end

local IsMe

local function ListName(kind)
    if kind == "combat" then return "combat" end
    if W.CHAT_KIND[kind] then return "msgs" end
    return "lines"
end

function W.Add(kind, sender, text, out, extra)
    if not kind or type(text) ~= "string" or text == "" or Secret(text) then return end
    if type(sender) ~= "string" or Secret(sender) then sender = "?" end
    if not out and W.CHAT_KIND[kind] and kind ~= "emote" and IsMe and IsMe(sender) then out = true end
    W.seq = W.seq + 1
    local msg = { t = Now(), s = sender, m = text, kind = kind, o = out and true or nil, x = extra, q = W.seq }
    local ln = ListName(kind)
    local list = W[ln]
    list[#list + 1] = msg
    if #list > CAPS[ln] + 40 then
        local new = {}
        for i = #list - CAPS[ln] + 1, #list do new[#new + 1] = list[i] end
        W[ln] = new
    end
    if kind == "channel" and extra then W.NoteChannel(extra) end
    W.version = W.version + 1
    local cur = W.CurrentTab()
    local visible, unreadChanged = false, false
    for _, t in ipairs(W.Tabs()) do
        if W.TabAccepts(t, msg) then
            if t.id == cur.id then
                visible = true
            elseif W.CHAT_KIND[kind] and kind ~= "emote" then
                W.unread[t.id] = (W.unread[t.id] or 0) + 1
                unreadChanged = true
            end
        end
    end
    if visible and W.Dirty then W.Dirty() end
    if unreadChanged and W.DirtyTabs then W.DirtyTabs() end
end

function W.Push(key, sender, text, out)
    local kind, extra = W.Classify(key)
    if kind then W.Add(kind, sender, text, out, extra) end
end

-- Nachrichten eines Reiters (aelteste zuerst)
function W.Visible(tabId)
    local t = W.FindTab(tabId) or W.Tabs()[1]
    local out, used = {}, 0
    for _, name in ipairs({ "msgs", "lines", "combat" }) do
        local before = #out
        for _, m in ipairs(W[name]) do
            if W.TabAccepts(t, m) then out[#out + 1] = m end
        end
        if #out > before then used = used + 1 end
    end
    if used > 1 then table.sort(out, function(a, b) return a.q < b.q end) end
    return out
end

------------------------------------------------------------------------
-- Eingabe: Ziel bestimmen
------------------------------------------------------------------------

-- Rueckgabe: Art ("say", "yell", "guild", "group", "whisper", "channel"), Ziel, Text; oder nil, Fehlertext
function W.ParseInput(text, tabKey, target, channel)
    if type(text) ~= "string" then return nil end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return nil end
    local cmd, rest = string.match(text, "^/(%S+)%s*(.*)$")
    if cmd then
        cmd = string.lower(cmd)
        if cmd == "s" or cmd == "say" then return "say", nil, rest, true end
        if cmd == "y" or cmd == "yell" or cmd == "sch" then return "yell", nil, rest, true end
        if cmd == "g" or cmd == "gilde" or cmd == "guild" then return "guild", nil, rest, true end
        if cmd == "p" or cmd == "party" or cmd == "gruppe" or cmd == "ra" or cmd == "raid" then return "group", nil, rest, true end
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
    if tabKey == "yell" then return "yell", nil, text end
    if tabKey == "channel" and channel then return "channel", channel, text end
    return "say", nil, text
end

-- Tippt man "/g " (Befehl mit Leerzeichen), wird das Kuerzel aus dem Feld genommen und das Ziel umgestellt.
-- Rueckgabe: neuer Text, Aenderung { kind=, target=, channel= }; nil, wenn nichts zu tun ist
function W.ConsumePrefix(text)
    if type(text) ~= "string" then return nil end
    local c1, who, rest = string.match(text, "^/(%a+)%s+(%S+)%s(.*)$")
    if c1 then
        c1 = string.lower(c1)
        if c1 == "w" or c1 == "whisper" or c1 == "t" or c1 == "tell" then
            return rest, { kind = "whisper", target = who }
        end
    end
    local cmd, tail = string.match(text, "^/(%w+)%s(.*)$")
    if not cmd then return nil end
    cmd = string.lower(cmd)
    if cmd == "s" or cmd == "say" then return tail, { kind = "say" } end
    if cmd == "y" or cmd == "yell" or cmd == "sch" then return tail, { kind = "yell" } end
    if cmd == "g" or cmd == "gilde" or cmd == "guild" then return tail, { kind = "guild" } end
    if cmd == "p" or cmd == "party" or cmd == "gruppe" or cmd == "ra" or cmd == "raid" then return tail, { kind = "group" } end
    local n = tonumber(cmd)
    if n and n >= 1 and n <= 20 then return tail, { kind = "channel", channel = n } end
    return nil
end

function W.ApplyPrefix(ch)
    if type(ch) ~= "table" then return end
    if ch.kind == "whisper" then
        W.target = ch.target
    elseif ch.kind == "channel" then
        W.sendKind, W.channel, W.target = "channel", ch.channel, nil
    else
        W.sendKind, W.channel, W.target = ch.kind, nil, nil
    end
    if W.RefreshInput then W.RefreshInput() end
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

function IsMe(sender)
    if type(sender) ~= "string" or sender == "" or Secret(sender) then return false end
    local short = string.match(sender, "^([^%-]+)") or sender
    local n = G.UnitName and G.UnitName("player")
    if type(n) == "string" and not Secret(n) and (sender == n or short == n) then return true end
    local Wh = FW.Whisper
    local full = Wh and Wh.SelfName and Wh.SelfName()
    if type(full) == "string" and not Secret(full) then
        if sender == full or short == full then return true end
        local fshort = string.match(full, "^([^%-]+)")
        if fshort and (sender == fshort or short == fshort) then return true end
    end
    return false
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

local STYLE_KEY = { say = "say", yell = "yell", emote = "emote", guild = "guild", group = "party", whisper = "whisper", channel = "channel" }
local function TextColor(kind)
    local S = FW.ChatStyle
    local key = STYLE_KEY[kind]
    if S and S.Opts and key then
        local ty = S.Opts().types
        local e = type(ty) == "table" and ty[key] or nil
        if e and type(e.text) == "table" then return e.text[1], e.text[2], e.text[3] end
        if S.DefaultColor then
            local ok, r, g, b = pcall(S.DefaultColor, key)
            if ok and type(r) == "number" then return r, g, b end
        end
    end
    return KindColor(kind)
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

-- Position (links unten) eines Rahmens in Einheiten von UIParent
local function PosOf(fr)
    local left, bottom = fr:GetLeft(), fr:GetBottom()
    local ui = G.UIParent and G.UIParent.GetEffectiveScale and G.UIParent:GetEffectiveScale() or 1
    local me = fr.GetEffectiveScale and fr:GetEffectiveScale() or ui
    if left and bottom and ui > 0 then
        return math.floor(left * me / ui + 0.5), math.floor(bottom * me / ui + 0.5)
    end
end

-- Teile einer Zeile im Stil des Spiel-Chats: [Gilde] Name: Text, Name sagt: Text, An Name: Text
-- Rueckgabe: vorher, Name (nil bei Emotes), nachher, Farbcode des Namens
function W.ClassicParts(m, CL, L, txt)
    local who = m.s or "?"
    local kind = m.kind
    local function NameColor(name)
        local cls = CL and CL.Info and CL.Info(name)
        local r, g, b = 0.9, 0.89, 0.84
        if CL and CL.ClassColor then r, g, b = CL.ClassColor(cls) end
        return Hex(r, g, b)
    end
    if kind == "emote" then return txt, nil, "", "" end
    if kind == "say" then return "", who, " " .. (L.CHATWIN_SAYS or "says") .. ": " .. txt, NameColor(who) end
    if kind == "yell" then return "", who, " " .. (L.CHATWIN_YELLS or "yells") .. ": " .. txt, NameColor(who) end
    if kind == "whisper" then
        if m.o then
            local to = m.x or who
            return (L.CHATWIN_WHISPER_TO or "To") .. " ", to, ": " .. txt, NameColor(to)
        end
        return "", who, " " .. (L.CHATWIN_WHISPERS or "whispers") .. ": " .. txt, NameColor(who)
    end
    local tag
    if kind == "guild" then tag = L.CHATWIN_TAB_GUILD or "Guild"
    elseif kind == "group" then tag = L.CHATWIN_TAB_GROUP or "Group"
    else tag = m.x or "" end
    return "[" .. tag .. "] ", who, ": " .. txt, NameColor(who)
end

-- Steht der Mauszeiger auf dem Namen in der ersten Zeile einer Zeile?
function W.CursorInName(panel, hit)
    if not (G.GetCursorPosition and panel.GetLeft and panel.GetTop) then return false end
    local cx, cy = G.GetCursorPosition()
    local l, t = panel:GetLeft(), panel:GetTop()
    local sc = panel.GetEffectiveScale and panel:GetEffectiveScale() or 1
    if not (cx and cy and l and t) or sc == 0 then return false end
    local x = cx / sc - l - 8
    local y = t - cy / sc
    return x >= hit[1] - 2 and x <= hit[2] + 2 and y >= 0 and y <= (tonumber(W.Opts().fontSize) or 11) + 6
end

function W.Draw()
    if not built then return end
    local o = W.Opts()
    local CL = FW.ChatLog
    local L = FW.L
    local tab = W.CurrentTab()
    local list = W.Visible(tab.id)
    local n = #list
    local first = math.max(1, n - MAX_ROWS + 1)
    local chat = built.chat
    local areaW = chat.child:GetWidth()
    if not areaW or areaW < 150 then areaW = (o.w or 560) - 40 end
    local fs = math.max(8, math.min(20, tonumber(o.fontSize) or 11))
    local compact = o.compact ~= false
    local avs = compact and 28 or 36
    local topPad = compact and 5 or 7
    local botPad = compact and 6 or 11
    local textY = topPad + fs + 5
    local classic = o.classic == true
    local maxBub = math.floor(areaW * (tonumber(o.maxW) or 78) / 100)
    if built.fontApplied ~= fs then UI.SetFont(built.measure, "body", fs); built.fontApplied = fs end
    local atBottom = stick or (chat.scroll:GetVerticalScroll() >= lastH - lastViewH - 8)
    local y, idx = 4, 0
    for i = first, n do
        local m = list[i]
        idx = idx + 1
        local b = Bubble(idx, chat.child)
        if b.fs ~= fs then
            UI.SetFont(b.name, "body", fs)
            UI.SetFont(b.text, "body", fs)
            UI.SetFont(b.time, "body", math.max(8, fs - 2))
            b.fs = fs
        end
        local line = classic or m.raw == true or W.Style(m.kind) == "line"
        local kr, kg, kb = KindColor(m.kind)
        local tr, tg, tb = TextColor(m.kind)
        local nameHit
        local txt = m.m or ""
        local links = ParseLinks(txt)
        local who = m.s or "?"
        built.measure:SetText(Plain(txt))
        local tw = built.measure:GetStringWidth() or 0
        if tw <= 0 then tw = maxBub end
        local ph, rowH, pw
        b.bar:SetColorTexture(kr, kg, kb, line and 0.8 or 1)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", chat.child, "TOPLEFT", 0, -y)
        b.avBtn:ClearAllPoints(); b.lvl:ClearAllPoints(); b.panel:ClearAllPoints()
        b.text:ClearAllPoints(); b.name:ClearAllPoints(); b.time:ClearAllPoints()
        if line then
            -- einfache Zeile: Uhrzeit, Text in der Farbe der Art, keine Blase
            b.avBtn:Hide(); b.lvl:SetText(""); b.name:SetText(""); b.time:SetText("")
            b.bg:SetColorTexture(0, 0, 0, 0)
            pw = areaW - 16
            local stamp = Stamp(m.t)
            local prefix = stamp ~= "" and (Hex(0.55, 0.55, 0.6) .. stamp .. "\124r  ") or ""
            local full = prefix .. txt
            if W.CHAT_KIND[m.kind] and not m.raw then
                local pre, name, post, color = W.ClassicParts(m, CL, L, txt)
                if name then
                    full = prefix .. pre .. color .. name .. "\124r" .. post
                    built.measure:SetText(Plain(prefix .. pre))
                    local x0 = built.measure:GetStringWidth() or 0
                    built.measure:SetText(name)
                    nameHit = { x0, x0 + (built.measure:GetStringWidth() or 0), name = m.kind == "whisper" and m.o and m.x or who }
                else
                    full = prefix .. pre
                end
            end
            b.text:SetTextColor(tr, tg, tb)
            b.text:SetWidth(pw - 14)
            b.text:SetText(full)
            b.text:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 8, -2)
            local th = (b.text.GetStringHeight and b.text:GetStringHeight()) or 14
            if not th or th < 12 then th = 12 end
            ph = math.floor(th + 4)
            rowH = ph
            b.panel:SetPoint("TOPLEFT", b, "TOPLEFT", 6, 0)
        else
            local own = m.o == true
            b.avBtn:Show()
            b.avBtn:SetSize(avs, avs)
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
            b.name:SetText(who .. (tag ~= "" and (Hex(kr, kg, kb) .. tag .. "\124r") or ""))
            b.time:SetText(Stamp(m.t))
            local nameW = (b.name:GetStringWidth() or 60) + (b.time:GetStringWidth() or 40) + 40
            pw = math.floor(math.max(math.min(math.max(tw, nameW) + 22, maxBub), 110))
            b.text:SetTextColor(UI.Color("text"))
            b.text:SetWidth(pw - 20)
            b.text:SetText(txt)
            b.name:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -topPad)
            b.time:SetPoint("TOPRIGHT", b.panel, "TOPRIGHT", -8, -(topPad + 1))
            b.text:SetPoint("TOPLEFT", b.panel, "TOPLEFT", 10, -textY)
            local th = (b.text.GetStringHeight and b.text:GetStringHeight()) or 14
            if not th or th < 12 then th = 12 end
            ph = math.floor(th + textY + botPad)
            if own then b.bg:SetColorTexture(0.13, 0.27, 0.46, 0.95) else b.bg:SetColorTexture(UI.Color("card", 0.95)) end
            rowH = math.max(ph, avs + 15)
            if own then
                b.avBtn:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, 0)
                b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
                b.panel:SetPoint("TOPRIGHT", b.avBtn, "TOPLEFT", -8, 0)
            else
                b.avBtn:SetPoint("TOPLEFT", b, "TOPLEFT", 6, 0)
                b.lvl:SetPoint("TOP", b.avBtn, "BOTTOM", 0, -1)
                b.panel:SetPoint("TOPLEFT", b.avBtn, "TOPRIGHT", 8, 0)
            end
        end
        b.panel:SetSize(pw, ph)
        b:SetSize(areaW - 8, rowH)
        local sender = (who ~= "?" and who ~= "" and (not line or W.CHAT_KIND[m.kind])) and who or nil
        if nameHit then sender = nameHit.name end
        b.avBtn:SetScript("OnClick", function() if sender then SetTarget(sender) end end)
        b.panel:SetScript("OnClick", function(_, btn)
            if btn == "RightButton" then
                if sender then SetTarget(sender) end
            elseif nameHit and W.CursorInName(b.panel, nameHit) then
                SetTarget(nameHit.name)
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
        y = y + rowH + (line and 2 or 8)
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
    local u = W.unread[t.id]
    local txt = W.TabName(t)
    if u and u > 0 then txt = txt .. " (" .. u .. ")" end
    return txt
end

local tabBtns = {}

-- Aussehen eines Reiter-Knopfs: Freewood (Gold) oder Spiel-Chat (klein, flach, dunkel)
local function StyleTab(b)
    local classic = W.Opts().classic == true
    local active = b.fwActive
    b:SetHeight(classic and 18 or 22)
    if classic then
        b.bg:SetColorTexture(0, 0, 0, active and 0.7 or (b.fwHover and 0.6 or 0.4))
        UI.SetBorderColor(b, "bronze", active and 0.9 or 0.2)
        if active then b.label:SetTextColor(1, 0.82, 0) else b.label:SetTextColor(0.62, 0.62, 0.62) end
    else
        b.bg:SetColorTexture(UI.Color(active and "gold" or (b.fwHover and "hover" or "card")))
        UI.SetBorderColor(b, active and "goldLight" or (b.fwHover and "gold" or "bronze"))
        if active then b.label:SetTextColor(UI.Color("bgDeep")) else b.label:SetTextColor(UI.Color("text")) end
    end
end

local function MakeTabButton(head)
    local b = CreateFrame("Button", nil, head)
    b:SetSize(60, 22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    UI.AddBorder(b, "bronze")
    b.label = UI.CreateLabel(b, "", { size = 12, justify = "CENTER" })
    b.label:SetPoint("CENTER", 0, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self, mouse) W.TabClick(self.fwTabId, mouse) end)
    b:SetScript("OnDragStart", function() if not W.Opts().locked and frame then frame:StartMoving() end end)
    b:SetScript("OnDragStop", function() if frame then frame:StopMovingOrSizing(); W.SavePosition() end end)
    b:SetScript("OnEnter", function(self) self.fwHover = true; StyleTab(self) end)
    b:SetScript("OnLeave", function(self) self.fwHover = false; StyleTab(self) end)
    function b:SetLabel(text) self.label:SetText(text or "") end
    return b
end

function W.TabClick(id, mouse)
    if mouse == "RightButton" then
        if W.OpenTabEditor then W.OpenTabEditor(id) end
    else
        W.SelectTab(id)
    end
end

-- Reiterleiste: Knoepfe je Reiter nach Textbreite, "+" dahinter, bei Platzmangel schmaler
function W.LayoutTabs()
    if not (built and built.head) then return end
    local head = built.head
    local tabs = W.Tabs()
    local cur = W.CurrentTab().id
    local avail = (tonumber(head:GetWidth()) or 520) - 4 - 28 - 28 - 6
    local widths, total = {}, 0
    for i, t in ipairs(tabs) do
        local btn = tabBtns[i]
        if not btn then
            btn = MakeTabButton(head)
            tabBtns[i] = btn
        end
        btn.fwTabId = t.id
        btn:SetLabel(TabText(t))
        local w = math.floor(math.max(48, math.min(150, (btn.label:GetStringWidth() or 40) + 22)))
        widths[i] = w
        total = total + w + 2
    end
    local scale = total > avail and avail / total or 1
    local x = 4
    for i, t in ipairs(tabs) do
        local btn = tabBtns[i]
        local w = math.floor(math.max(36, widths[i] * scale))
        btn:SetWidth(w)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", head, "LEFT", x, 0)
        btn.fwActive = (t.id == cur)
        StyleTab(btn)
        btn:Show()
        x = x + w + 2
    end
    for i = #tabs + 1, #tabBtns do tabBtns[i]:Hide() end
    if built.plus then
        built.plus:SetHeight(W.Opts().classic and 18 or 22)
        built.plus:ClearAllPoints()
        built.plus:SetPoint("LEFT", head, "LEFT", x + 2, 0)
    end
end

local function RefreshTabs()
    W.LayoutTabs()
end
W.RefreshTabs = RefreshTabs

local tabsDirty = false
function W.DirtyTabs() tabsDirty = true end

function W.SelectTab(id)
    if not W.FindTab(id) then return end
    W.Opts().tab = id
    W.unread[id] = nil
    stick = true
    RefreshTabs()
    if W.RefreshInput then W.RefreshInput() end
    W.Draw()
end

function W.CycleSend()
    local order = { say = "guild", guild = "group", group = "say" }
    W.sendKind = order[W.sendKind or "say"] or "say"
    if W.RefreshInput then W.RefreshInput() end
end

function W.RefreshInput()
    if not built then return end
    local L = FW.L
    local label, kind
    local k = W.sendKind or "say"
    if W.target then
        label = (L.CHATWIN_TO or "To") .. ": " .. W.target .. "  (x)"; kind = "whisper"
    elseif k == "guild" then label = L.CHAT_GUILD; kind = "guild"
    elseif k == "group" then label = L.CHAT_GROUP; kind = "group"
    elseif k == "yell" then label = L.CHATWIN_K_YELL; kind = "yell"
    elseif k == "channel" and W.channel then label = (L.CHATWIN_CHANNEL or "Channel") .. " " .. W.channel; kind = "channel"
    else label = L.CHATWIN_K_SAY; kind = "say" end
    built.target:SetText(label or "")
    local r, g, b = KindColor(kind)
    if kind == "say" then r, g, b = UI.Color("goldLight") end
    built.target:SetTextColor(r, g, b)
end

function W.SavePosition()
    if not frame then return end
    local o = W.Opts()
    local px, py = PosOf(frame)
    if px then o.point, o.x, o.y = "BOTTOMLEFT", px, py end
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

function W.LayoutHead()
    if not (built and built.head and frame) then return end
    local head, classic = built.head, W.Opts().classic == true
    head:ClearAllPoints()
    if classic then
        -- wie im Spiel: Reiter klein ueber dem Fenster, keine Kopfleiste
        head:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 1)
        head:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 1)
        head:SetHeight(19)
        built.close:Hide()
    else
        head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        head:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        head:SetHeight(30)
        built.close:Show()
    end
    if frame.SetClampRectInsets then pcall(frame.SetClampRectInsets, frame, 0, 0, classic and -20 or 0, 0) end
end

function W.ApplyLook()
    if not built then return end
    local o = W.Opts()
    local classic = o.classic == true
    local a = (tonumber(o.alpha) or 85) / 100
    if classic then
        local r, g, b = 0, 0, 0
        local S = FW.ChatStyle
        local so = S and S.Opts and S.Opts() or nil
        if so and so.bgOn then
            local c = so.bgColor or { 0, 0, 0 }
            r, g, b = c[1] or 0, c[2] or 0, c[3] or 0
            a = (tonumber(so.bgAlpha) or 60) / 100
        end
        built.bg:SetColorTexture(r, g, b, a)
        if UI.SetBorderColor then UI.SetBorderColor(frame, "bronze", 0) end
        built.inputFrame.bg:SetColorTexture(0, 0, 0, 0.6)
        UI.SetBorderColor(built.inputFrame, "bronze", 0.35)
    else
        built.bg:SetColorTexture(UI.Color("bgDeep", a))
        if UI.SetBorderColor then UI.SetBorderColor(frame, "bronze") end
        built.inputFrame.bg:SetColorTexture(UI.Color("bgDeep"))
        UI.SetBorderColor(built.inputFrame, "bronze")
    end
    if built.sendBtn then if classic then built.sendBtn:Hide() else built.sendBtn:Show() end end
    if built.input and built.inputFrame then
        built.input:ClearAllPoints()
        built.input:SetPoint("TOPLEFT", built.inputFrame, "TOPLEFT", 106, -3)
        built.input:SetPoint("BOTTOMRIGHT", built.inputFrame, "BOTTOMRIGHT", classic and -8 or -80, 3)
    end
    if built.grip then if o.locked then built.grip:Hide() else built.grip:Show() end end
    if built.classicApplied ~= classic then
        built.classicApplied = classic
        W.LayoutHead()
        W.LayoutInput()
        W.RefreshTabs()
    end
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
    -- ohne Fenster darf der Spiel-Chat nicht versteckt bleiben
    if not o.enabled and o.main then W.SetMain(false) end
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
    built.head = head
    head:SetFrameLevel(frame:GetFrameLevel() + 3)
    built.plus = UI.CreateButton(head, "+", 22, 22, function() if W.NewTab then W.NewTab() end end, "default")
    local close = UI.CreateButton(head, "x", 22, 22, function() W.SetShown(false) end, "default")
    close:SetPoint("RIGHT", head, "RIGHT", -4, 0)
    built.close = close

    -- Eingabe (eigener Rahmen: unten im Fenster oder getrennt, siehe W.LayoutInput)
    local ibox = UI.CreatePanel(frame, "bgDeep", "bronze")
    built.inputFrame = ibox
    ibox:SetHeight(28)
    ibox:EnableMouse(true)
    ibox:SetMovable(true)
    ibox:RegisterForDrag("LeftButton")
    ibox:SetScript("OnDragStart", function(self)
        if W.Detached() and W.Opts().moveInput then self:StartMoving() end
    end)
    ibox:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local px, py = PosOf(self)
        if px then local o = W.Opts(); o.inX, o.inY = px, py end
        W.LayoutInput()
    end)
    built.moveHint = UI.CreateLabel(ibox, L.CHATWIN_MOVE_HINT or "", { size = 10, color = "goldLight", justify = "RIGHT" })
    built.moveHint:SetPoint("BOTTOMRIGHT", ibox, "TOPRIGHT", 0, 2)
    built.moveHint:Hide()
    local sendBtn = UI.CreateButton(ibox, L.CHAT_SEND, 72, 22, function() W.DoSend() end)
    built.sendBtn = sendBtn
    sendBtn:SetPoint("RIGHT", ibox, "RIGHT", -3, 0)
    local tgt = CreateFrame("Button", nil, ibox)
    tgt:SetPoint("LEFT", ibox, "LEFT", 6, 0)
    tgt:SetHeight(22)
    tgt:SetWidth(96)
    built.target = UI.CreateLabel(tgt, "", { size = 11, color = "goldLight", justify = "LEFT" })
    built.target:SetPoint("LEFT", tgt, "LEFT", 0, 0)
    tgt:SetScript("OnClick", function() if W.target then SetTarget(nil) else W.CycleSend() end end)
    local input = CreateFrame("EditBox", nil, ibox)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", ibox, "TOPLEFT", 106, -3)
    input:SetPoint("BOTTOMRIGHT", ibox, "BOTTOMRIGHT", -80, 3)
    input:SetMaxLetters(255)
    UI.SetFont(input, "body", 12)
    input:SetTextColor(UI.Color("text"))
    local ihint = UI.CreateLabel(ibox, L.CHAT_INPUT, { size = 12, color = "textDim" })
    ihint:SetPoint("LEFT", ibox, "LEFT", 110, 0)
    input:SetScript("OnEnterPressed", function() W.DoSend() end)
    input:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    input:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        if t == "//" and W.openedAt and (G.GetTime and G.GetTime() or 0) - W.openedAt < 0.3 then self:SetText("/"); return end
        local newText, change = W.ConsumePrefix(t)
        if change then
            W.ApplyPrefix(change)
            self:SetText(newText)
            return
        end
        if t == "" then ihint:Show() else ihint:Hide() end
    end)
    input:SetScript("OnEditFocusGained", function() W.UpdateInputVisibility() end)
    input:SetScript("OnEditFocusLost", function() W.UpdateInputVisibility() end)
    built.input = input

    -- Chatbereich
    built.chat = UI.CreateScrollFrame(frame)
    built.chat:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -34)
    built.chat:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 40)
    frame.fwChat = built.chat
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
    frame:SetScript("OnSizeChanged", function() W.Dirty(); W.DirtyTabs() end)

    local lastCheck = 0
    frame:SetScript("OnUpdate", function()
        local now = G.GetTime and G.GetTime() or 0
        if W.importAt and not W.imported and now >= W.importAt then
            if not pcall(W.ImportHistory) or not W.imported then W.importAt = now + 2 end
        end
        if dirty and now - dirtyAt >= 0.15 then pcall(W.Draw); pcall(RefreshTabs); tabsDirty = false
        elseif tabsDirty then tabsDirty = false; pcall(RefreshTabs) end
        if now - lastCheck >= 2 then
            lastCheck = now
            if W.Opts().main then pcall(W.ApplyMain) end
            if W.inputTestUntil and now >= W.inputTestUntil then W.inputTestUntil = nil; W.UpdateInputVisibility() end
        end
    end)

    W.ApplyPosition()
    W.LayoutInput()
    W.ApplyLook()
    RefreshTabs()
    W.RefreshInput()
    if o.enabled then frame:Show() else frame:Hide() end
    W.Dirty()
    return true
end

------------------------------------------------------------------------
-- Eingabefeld: Senden, Platzierung, Sichtbarkeit
------------------------------------------------------------------------

function W.Detached() return W.Opts().detach == true end

function W.UpdateInputVisibility(force)
    if not (built and built.inputFrame) then return end
    local f, o = built.inputFrame, W.Opts()
    local now = G.GetTime and G.GetTime() or 0
    local testing = W.inputTestUntil and now < W.inputTestUntil
    if W.UseBlizz() then
        -- unser Rahmen ist nur Anker und Ziehgriff, getippt wird im Feld des Spiels
        if o.moveInput or testing or force then f:Show() else f:Hide() end
        if o.moveInput then built.moveHint:Show() else built.moveHint:Hide() end
        built.input:EnableMouse(not o.moveInput)
        return
    end
    if not W.Detached() then f:Show(); built.moveHint:Hide(); built.input:EnableMouse(true); return end
    local focus = built.input:HasFocus()
    if force or o.moveInput or testing or focus then f:Show() else f:Hide() end
    if o.moveInput then built.moveHint:Show() else built.moveHint:Hide() end
    built.input:EnableMouse(not o.moveInput)
end

function W.LayoutInput()
    if not (built and built.inputFrame and frame) then return end
    local f, o = built.inputFrame, W.Opts()
    f:ClearAllPoints()
    local bottom
    if W.Detached() then
        f:SetParent(G.UIParent)
        f:SetFrameStrata("DIALOG")
        f:SetSize(math.max(200, tonumber(o.inW) or 460), 28)
        f:SetPoint("BOTTOMLEFT", G.UIParent, "BOTTOMLEFT", o.inX or 34, o.inY or 300)
        bottom = 6
    else
        f:SetParent(frame)
        f:SetFrameStrata("MEDIUM")
        f:SetFrameLevel(frame:GetFrameLevel() + 5)
        f:SetHeight(28)
        f:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
        f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 6)
        bottom = 40
    end
    local classic = o.classic == true
    built.chat:ClearAllPoints()
    built.chat:SetPoint("TOPLEFT", frame, "TOPLEFT", classic and 4 or 6, classic and -4 or -34)
    built.chat:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", classic and -4 or -6, bottom)
    W.UpdateInputVisibility()
    stick = true
    W.Dirty()
end

function W.TestInput()
    if not built then return end
    W.inputTestUntil = (G.GetTime and G.GetTime() or 0) + 5
    W.UpdateInputVisibility(true)
end

-- Befehl an das Chatsystem des Spiels weiterreichen (alles, was wir nicht selbst kennen)
function W.Forward(text)
    local dc = G.DEFAULT_CHAT_FRAME
    local eb = (dc and dc.editBox) or G.ChatFrame1EditBox
    if not (eb and eb.SetText and G.ChatEdit_SendText) then return false end
    local ok = pcall(function()
        eb:SetText(text)
        G.ChatEdit_SendText(eb, 1)
    end)
    pcall(eb.SetText, eb, "")
    return ok
end

function W.DoSend()
    if not built then return end
    local L = FW.L
    local input = built.input
    local txt = input:GetText() or ""
    local o = W.Opts()
    local now = G.GetTime and G.GetTime() or 0
    if txt == "" and W.openedAt and now - W.openedAt < 0.3 then return end   -- die Taste, die das Feld geoeffnet hat
    local kind, target, msg, explicit = W.ParseInput(txt, W.sendKind, W.target, W.channel)
    local done = false
    if kind then
        if explicit and (kind == "say" or kind == "yell" or kind == "guild" or kind == "group") then
            W.sendKind, W.channel, W.target = kind, nil, nil        -- wie im Spiel: der Befehl stellt das Ziel dauerhaft ein
            W.RefreshInput()
        end
        if msg == "" and explicit then done = true else done = W.Send(kind, target, msg) and true or false end
    elseif target == "unknown" or target == "usage" then
        done = W.Forward(txt)
        if not done and FW.Print then FW:Print(L.CHATWIN_UNKNOWN_CMD or "Unknown command") end
    else
        done = txt == "" or string.find(txt, "^%s*$") ~= nil
    end
    if done then
        input:SetText("")
        if W.Detached() or o.main then input:ClearFocus() else input:SetFocus() end
    end
end

-- Eingabe von aussen oeffnen (Enter, "/", Antworten ...)
function W.OpenInput(text)
    if not (built and built.input) then return false end
    W.UpdateInputVisibility(true)
    built.input:SetText(type(text) == "string" and text or "")
    W.openedAt = G.GetTime and G.GetTime() or 0
    built.input:SetFocus()
    return true
end

------------------------------------------------------------------------
-- System-Meldungen (Beute, Erfahrung, Wuerfeln, "ist jetzt offline", Addon-Ausgaben)
------------------------------------------------------------------------

local EVENT_KIND = {
    CHAT_MSG_SYSTEM = "system", CHAT_MSG_PET_INFO = "system", CHAT_MSG_COMBAT_MISC_INFO = "system",
    CHAT_MSG_BG_SYSTEM_NEUTRAL = "system", CHAT_MSG_BG_SYSTEM_ALLIANCE = "system", CHAT_MSG_BG_SYSTEM_HORDE = "system",
    CHAT_MSG_TARGETICONS = "system", CHAT_MSG_ACHIEVEMENT = "system", CHAT_MSG_RAID_BOSS_EMOTE = "system",
    CHAT_MSG_SKILL = "skill", CHAT_MSG_COMBAT_XP_GAIN = "xp", CHAT_MSG_LOOT = "loot", CHAT_MSG_CURRENCY = "loot",
    CHAT_MSG_MONEY = "money", CHAT_MSG_COMBAT_FACTION_CHANGE = "rep", CHAT_MSG_COMBAT_HONOR_GAIN = "honor",
    CHAT_MSG_TRADESKILLS = "tradeskill",
}
local recentSys, recentN = {}, 0

-- Farbe einer Zeile des Spiel-Chats einer Art zuordnen (fuer den uebernommenen Verlauf)
local HISTORY_COLORS = {
    { "guild", 0.25, 1, 0.25 }, { "group", 0.67, 0.67, 1 }, { "whisper", 1, 0.5, 1 }, { "yell", 1, 0.25, 0.25 },
    { "channel", 1, 0.75, 0.75 }, { "system", 1, 1, 0 },
}
function W.KindFromColor(r, g, b, text)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return "addon" end
    for _, c in ipairs(HISTORY_COLORS) do
        if math.abs(r - c[2]) < 0.12 and math.abs(g - c[3]) < 0.12 and math.abs(b - c[4]) < 0.12 then return c[1] end
    end
    if r > 0.9 and g > 0.9 and b > 0.9 then
        local says = FW.L and FW.L.CHATWIN_SAYS
        if says and type(text) == "string" and string.find(text, " " .. says .. ":", 1, true) then return "say" end
        return "addon"
    end
    return "system"
end

-- letzte Zeilen des Spiel-Chats uebernehmen (einmal nach dem Anmelden), damit das Fenster nicht leer startet
function W.ImportHistory()
    if W.imported then return true end
    local cf = G.DEFAULT_CHAT_FRAME or G.ChatFrame1
    if not (cf and cf.GetNumMessages and cf.GetMessageInfo) then W.imported = true; return true end
    local okn, total = pcall(cf.GetNumMessages, cf)
    if not okn or type(total) ~= "number" or total <= 0 then return false end
    W.imported = true
    local add = { msgs = {}, lines = {} }
    local n = 0
    for i = math.max(1, total - 99), total do
        local ok, text, r, g, b = pcall(cf.GetMessageInfo, cf, i)
        if ok and type(text) == "string" and text ~= "" and not Secret(text) then
            text = string.gsub(text, "\124cff000001\124r", "")
            n = n + 1
            local kind = W.KindFromColor(r, g, b, text)
            local m = { s = "", m = text, kind = kind, raw = true, q = -1000 + n }
            if kind == "channel" then
                local plain = string.gsub(string.gsub(text, "\124c%x%x%x%x%x%x%x%x", ""), "\124r", "")
                m.x = string.match(plain, "%[(%d+%.%s*[^%]]-)%]")
            end
            local list = add[ListName(kind)]
            if list then list[#list + 1] = m end
        end
    end
    for _, name in ipairs({ "msgs", "lines" }) do
        local items = add[name]
        if #items > 0 then
            for _, m in ipairs(W[name]) do items[#items + 1] = m end
            W[name] = items
        end
    end
    W.version = W.version + 1
    if W.Dirty then W.Dirty() end
    return true
end

function W.AddSystem(text, kind)
    if type(text) ~= "string" or text == "" or Secret(text) then return end
    kind = kind or "system"
    local plain = string.gsub(string.gsub(string.gsub(text, "\124H.-\124h(.-)\124h", "%1"), "\124c%x%x%x%x%x%x%x%x", ""), "\124r", "")
    local now = G.GetTime and G.GetTime() or 0
    local key = kind .. plain
    local last = recentSys[key]
    if last and now - last < 1 then return end
    recentN = recentN + 1
    if recentN > 60 then recentSys, recentN = {}, 0 end
    recentSys[key] = now
    W.Add(kind, "", text, false)
end

for e, k in pairs(EVENT_KIND) do
    FW:RegisterEvent(e, function(text) W.AddSystem(text, k) end)
end

-- Ausgaben anderer Addons (print) gehen ohne Farbangabe an den Spiel-Chat
function W.HookPrints()
    if W.printHooked then return end
    local cf = G.DEFAULT_CHAT_FRAME or G.ChatFrame1
    if not (cf and G.hooksecurefunc and cf.AddMessage) then return end
    W.printHooked = true
    pcall(G.hooksecurefunc, cf, "AddMessage", function(_, text, r)
        if r ~= nil then return end
        W.AddSystem(text, "addon")
    end)
end

------------------------------------------------------------------------
-- Haupt-Chat-Modus: Spiel-Chat unsichtbar, Enter und "/" oeffnen unser Eingabefeld
------------------------------------------------------------------------

local ebFree, ebParent
local hiddenParent
local parked = {}
local styled = {}  -- Eingabefelder im Freewood-Design (Weg B), siehe StyleOne

local function Park(f)
    if not (f and f.SetParent and f.GetParent) then return end
    local ok, par = pcall(f.GetParent, f)
    if not ok or not par or par == hiddenParent then return end
    if pcall(f.SetParent, f, hiddenParent) then parked[f] = parked[f] or par end
end

local EXTRA_FRAMES = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }

function W.HideBlizzard()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", nil, G.UIParent)
        hiddenParent:Hide()
    end
    for i = 1, tonumber(G.NUM_CHAT_WINDOWS) or 10 do
        Park(G["ChatFrame" .. i])
        Park(G["ChatFrame" .. i .. "Tab"])
        Park(G["ChatFrame" .. i .. "ButtonFrame"])
    end
    for _, name in ipairs(EXTRA_FRAMES) do Park(G[name]) end
    -- Eingabefelder des Spiels (stehen oft dauerhaft sichtbar am Bildschirm): ausser Weg B
    -- (dort sind sie unser Eingabefeld) und waehrend der Notausgang sie offen hat
    for i = 1, tonumber(G.NUM_CHAT_WINDOWS) or 10 do
        local eb = G["ChatFrame" .. i .. "EditBox"]
        if eb and not styled[eb] and not (ebFree and ebFree == eb) then Park(eb) end
    end
end

function W.ShowBlizzard()
    for f, par in pairs(parked) do
        pcall(f.SetParent, f, par)
        parked[f] = nil
    end
end

function W.MainActive()
    return W.Opts().main == true and built ~= nil and frame ~= nil and frame:IsShown() == true
end

-- Das Spiel will sein Eingabefeld oeffnen (Enter, "/", Antworten): bei uns oeffnen
function W.OnBlizzActivate(eb, shift)
    W.redirected = false
    if W.bypass or shift or W.UseBlizz() or not W.MainActive() then return false end
    local text, ct, tt = "", nil, nil
    if type(eb) == "table" then
        if eb.GetText then
            local ok, v = pcall(eb.GetText, eb)
            if ok and type(v) == "string" and not Secret(v) then text = v end
        end
        if eb.GetAttribute then
            local ok, a = pcall(eb.GetAttribute, eb, "chatType")
            if ok then ct = a end
            ok, a = pcall(eb.GetAttribute, eb, "tellTarget")
            if ok then tt = a end
        end
        if G.ChatEdit_DeactivateChat then
            pcall(G.ChatEdit_DeactivateChat, eb)
        else
            pcall(function() if eb.ClearFocus then eb:ClearFocus() end; if eb.Hide then eb:Hide() end end)
        end
    end
    if ct == "WHISPER" and type(tt) == "string" and tt ~= "" and not Secret(tt) then
        W.target = tt
        if W.RefreshInput then W.RefreshInput() end
    end
    W.redirected = true
    W.OpenInput(text)
    return true
end

-- ChatFrame_OpenChat(text) setzt den Text erst nach dem Oeffnen: nachtragen
function W.OnBlizzOpenChat(text)
    if not W.redirected then return end
    W.redirected = false
    if type(text) == "string" and text ~= "" and not Secret(text) and built and built.input then
        built.input:SetText(text)
    end
end

function W.BlizzEditBox()
    local dc = G.DEFAULT_CHAT_FRAME
    return (dc and dc.editBox) or G.ChatFrame1EditBox
end


-- Notausgang (Umschalt+Enter): das normale Eingabefeld des Spiels sichtbar oeffnen
function W.OpenBlizzard(text)
    if not G.ChatFrame_OpenChat then return false end
    local eb = W.BlizzEditBox()
    W.bypass = true
    if eb and eb.SetParent and eb.GetParent then
        local ok, par = pcall(eb.GetParent, eb)
        if ok and par and par ~= G.UIParent then
            ebFree, ebParent = eb, par
            pcall(eb.SetParent, eb, G.UIParent)
        end
    end
    local ok = pcall(G.ChatFrame_OpenChat, text or "")
    W.bypass = false
    return ok
end

local function ReleaseBlizzBox(eb)
    if ebFree and eb == ebFree and ebParent then
        pcall(ebFree.SetParent, ebFree, ebParent)
        ebFree, ebParent = nil, nil
    end
end

function W.InstallHooks()
    if W.hooksDone then return end
    W.hooksDone = true
    local hs = G.hooksecurefunc
    if not hs then return end
    local n = 0
    if G.ChatEdit_ActivateChat and pcall(hs, "ChatEdit_ActivateChat", function(eb)
        if W.UseBlizz() then pcall(W.StyleBlizzEdit, true) end
        W.OnBlizzActivate(eb, G.IsShiftKeyDown and G.IsShiftKeyDown() or false)
    end) then n = n + 1; W.hookActivate = true end
    if G.ChatFrame_OpenChat and pcall(hs, "ChatFrame_OpenChat", function(text) W.OnBlizzOpenChat(text) end) then n = n + 1 end
    if G.ChatEdit_DeactivateChat and pcall(hs, "ChatEdit_DeactivateChat", function(eb) ReleaseBlizzBox(eb) end) then n = n + 1 end
    if G.ChatEdit_InsertLink and pcall(hs, "ChatEdit_InsertLink", function(link)
        if built and built.input and type(link) == "string" and not Secret(link) and built.input:HasFocus() then
            built.input:Insert(link)
        end
    end) then n = n + 1 end
    W.hookCount = n
end

-- Tastenbelegung ueber Ueberschreibungen: Umschalt+Enter = Notausgang immer; Enter und "/" nur, wenn die Hooks fehlen
local bindOwner, bindPending
local function MakeButton(name, fn)
    local b = G[name]
    if not b then
        b = CreateFrame("Button", name, G.UIParent)
        b:SetSize(1, 1)
        b:SetScript("OnClick", function() fn() end)
    end
    return b
end

function W.ApplyBindings(on)
    if not (G.SetOverrideBindingClick and G.ClearOverrideBindings) then return end
    if G.InCombatLockdown and G.InCombatLockdown() then bindPending = true; return end
    bindPending = false
    bindOwner = bindOwner or CreateFrame("Frame", nil, G.UIParent)
    pcall(G.ClearOverrideBindings, bindOwner)
    if not on or W.UseBlizz() then return end
    MakeButton("FreewoodChatBlizzButton", function() W.OpenBlizzard("") end)
    pcall(G.SetOverrideBindingClick, bindOwner, true, "SHIFT-ENTER", "FreewoodChatBlizzButton")
    MakeButton("FreewoodChatEnterButton", function() W.OpenInput("") end)
    MakeButton("FreewoodChatSlashButton", function() W.OpenInput("/") end)
    for _, k in ipairs(W.BindingKeys("OPENCHAT", { "ENTER", "NUMPADENTER" })) do
        pcall(G.SetOverrideBindingClick, bindOwner, true, k, "FreewoodChatEnterButton")
    end
    for _, k in ipairs(W.BindingKeys("OPENCHATSLASH", { "/" })) do
        pcall(G.SetOverrideBindingClick, bindOwner, true, k, "FreewoodChatSlashButton")
    end
end

-- Tasten, die im Spiel fuer eine Belegung eingestellt sind (plus Standardtasten)
function W.BindingKeys(action, defaults)
    local out, seen = {}, {}
    local function Add(k) if type(k) == "string" and k ~= "" and not seen[k] then seen[k] = true; out[#out + 1] = k end end
    if G.GetBindingKey then
        local ok, k1, k2 = pcall(G.GetBindingKey, action)
        if ok then Add(k1); Add(k2) end
    end
    for _, k in ipairs(defaults or {}) do Add(k) end
    return out
end

-- Tastenabfrage ohne Bindungen und Haken: ein Rahmen hoert mit und gibt alle anderen Tasten weiter
local keyFrame
local function KeyCombo(key)
    local mod = ""
    if G.IsAltKeyDown and G.IsAltKeyDown() then mod = mod .. "ALT-" end
    if G.IsControlKeyDown and G.IsControlKeyDown() then mod = mod .. "CTRL-" end
    if G.IsShiftKeyDown and G.IsShiftKeyDown() then mod = mod .. "SHIFT-" end
    return mod .. tostring(key)
end

function W.HandleKey(key)
    if W.bypass or W.UseBlizz() or not W.MainActive() then return false end
    if built and built.input and built.input:HasFocus() then return false end
    local combo = KeyCombo(key)
    if combo == "SHIFT-ENTER" or combo == "SHIFT-NUMPADENTER" then
        return W.OpenBlizzard("") and true or false
    end
    for _, k in ipairs(W.BindingKeys("OPENCHAT", { "ENTER", "NUMPADENTER" })) do
        if k == combo then return W.OpenInput("") end
    end
    for _, k in ipairs(W.BindingKeys("OPENCHATSLASH", { "/" })) do
        if k == combo then return W.OpenInput("/") end
    end
    return false
end

function W.ApplyKeyListener(on)
    if on and not keyFrame then
        keyFrame = CreateFrame("Frame", nil, G.UIParent)
        keyFrame:SetScript("OnKeyDown", function(self, key)
            local handled = false
            local ok, res = pcall(W.HandleKey, key)
            if ok and res then handled = true end
            if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, not handled) end
        end)
    end
    if keyFrame then
        pcall(keyFrame.EnableKeyboard, keyFrame, on and true or false)
        if on and keyFrame.SetPropagateKeyboardInput then pcall(keyFrame.SetPropagateKeyboardInput, keyFrame, true) end
    end
end

-- Eingabefeld des Spiels im Freewood-Design (Weg B): an unseren Rahmen anhaengen, Aussehen umstellen

local function EditBoxes()
    local list = {}
    for i = 1, tonumber(G.NUM_CHAT_WINDOWS) or 10 do
        local e = G["ChatFrame" .. i .. "EditBox"]
        if e then list[#list + 1] = e end
    end
    return list
end

function W.UseBlizz()
    local o = W.Opts()
    return o.main == true and o.useBlizz == true
end

local function StyleOne(eb, on)
    local st = styled[eb]
    if on then
        if not st then
            st = { alphas = {}, points = {} }
            local okp, par = pcall(eb.GetParent, eb)
            st.parent = okp and par or nil
            if eb.GetNumPoints and eb.GetPoint then
                for i = 1, eb:GetNumPoints() do st.points[i] = { eb:GetPoint(i) } end
            end
            st.h = eb.GetHeight and eb:GetHeight() or nil
            if eb.GetRegions then
                for _, r in ipairs({ eb:GetRegions() }) do
                    if r.GetObjectType and r:GetObjectType() == "Texture" and r.GetAlpha then
                        st.alphas[r] = r:GetAlpha()
                        r:SetAlpha(0)
                    end
                end
            end
            st.skin = UI.CreatePanel(eb, "bgDeep", "bronze")
            st.skin:SetAllPoints(eb)
            st.skin:SetFrameLevel(math.max(0, (eb:GetFrameLevel() or 1) - 1))
            styled[eb] = st
        end
        st.skin:Show()
        eb:SetParent(G.UIParent)
        eb:SetFrameStrata("DIALOG")
        eb:ClearAllPoints()
        eb:SetPoint("BOTTOMLEFT", built.inputFrame, "BOTTOMLEFT", 0, 0)
        eb:SetPoint("BOTTOMRIGHT", built.inputFrame, "BOTTOMRIGHT", 0, 0)
        eb:SetHeight(28)
    elseif st then
        for r, a in pairs(st.alphas) do pcall(r.SetAlpha, r, a) end
        st.skin:Hide()
        if st.parent then pcall(eb.SetParent, eb, st.parent) end
        pcall(eb.ClearAllPoints, eb)
        for _, pt in ipairs(st.points) do pcall(eb.SetPoint, eb, unpack(pt)) end
        if st.h then pcall(eb.SetHeight, eb, st.h) end
        styled[eb] = nil
    end
end

function W.StyleBlizzEdit(on)
    if on and not (built and built.inputFrame) then on = false end
    for _, eb in ipairs(EditBoxes()) do pcall(StyleOne, eb, on) end
end

FW:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if bindPending then W.ApplyBindings(W.Opts().main == true and built ~= nil) end
end)

function W.ApplyMain()
    local o = W.Opts()
    local active = o.main and built and frame and frame:IsShown() and true or false
    if active then
        W.InstallHooks()
        W.HideBlizzard()
        W.HookPrints()
    else
        W.StyleBlizzEdit(false)
        W.ShowBlizzard()
    end
    local blizz = active and W.UseBlizz()
    if blizz then W.StyleBlizzEdit(true) elseif active then W.StyleBlizzEdit(false); W.HideBlizzard() end
    W.ApplyKeyListener(active and not blizz)
    local mode = (active and "main" or "off") .. (blizz and "B" or "A")
    if W.bindMode ~= mode then
        W.bindMode = mode
        W.ApplyBindings(active)
    end
    W.UpdateInputVisibility()
end

function W.SetMain(on)
    local o = W.Opts()
    o.main = on and true or false
    if o.main then
        o.enabled = true
        W.Build()
        if not built then o.main = false else frame:Show(); stick = true; W.Dirty() end
    end
    W.ApplyMain()
end

function W.Probe()
    local function Has(n) return G[n] ~= nil and "ja" or "nein" end
    local dc = G.DEFAULT_CHAT_FRAME
    local lines = {
        "ChatEdit_ActivateChat: " .. Has("ChatEdit_ActivateChat") .. ", ChatFrame_OpenChat: " .. Has("ChatFrame_OpenChat")
            .. ", ChatEdit_DeactivateChat: " .. Has("ChatEdit_DeactivateChat") .. ", ChatEdit_SendText: " .. Has("ChatEdit_SendText")
            .. ", ChatEdit_InsertLink: " .. Has("ChatEdit_InsertLink"),
        "DEFAULT_CHAT_FRAME: " .. Has("DEFAULT_CHAT_FRAME") .. ", editBox: " .. ((dc and dc.editBox) and "ja" or "nein")
            .. ", ChatFrame1EditBox: " .. Has("ChatFrame1EditBox") .. ", SetOverrideBindingClick: " .. Has("SetOverrideBindingClick"),
        "Haken gesetzt: " .. tostring(W.hookCount or 0) .. ", Aktivierung abgefangen: " .. tostring(W.hookActivate == true)
            .. ", Haupt-Chat: " .. tostring(W.Opts().main == true),
    }
    if G.GetBindingKey then
        local ok, k1, k2 = pcall(G.GetBindingKey, "OPENCHAT")
        lines[#lines + 1] = "Taste OPENCHAT: " .. tostring(ok and k1 or "?") .. " " .. tostring(ok and k2 or "")
    end
    lines[#lines + 1] = "Eingabe: " .. (W.UseBlizz() and "Feld des Spiels im Freewood-Design (Weg B)" or "eigenes Feld (Weg A)")
        .. ", Tastenabfrage: " .. ((G.SetOverrideBindingClick and "Bindungen ja") or "Bindungen nein")
    for _, l in ipairs(lines) do if FW.Print then FW:Print(l) end end
    return lines
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
    pcall(W.InstallHooks)
    pcall(W.HookPrints)
    if not W.imported and not W.importAt then W.importAt = (G.GetTime and G.GetTime() or 0) + 1.5 end
    pcall(W.ApplyMain)
end)
FW:RegisterEvent("UPDATE_CHAT_WINDOWS", function()
    if W.Opts().main then pcall(W.ApplyMain) end
end)

SLASH_FREEWOODCHATWIN1 = "/fwchatwin"
SlashCmdList = SlashCmdList or {}
SlashCmdList["FREEWOODCHATWIN"] = function(arg)
    arg = string.lower(string.gsub(arg or "", "%s+", ""))
    if arg == "probe" then W.Probe(); return end
    W.SetShown(not (W.Opts().enabled))
end

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-window", {
        category = "chat",
        order = 5,
        height = 800,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATWIN_TITLE)
            stack:Add(UI.CreateLabel(f, L.CHATWIN_HINT, { size = 11, color = "textDim" }), { fit = true, gap = 4 })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_ENABLED,
                function() return W.Opts().enabled == true end,
                function(v) W.SetShown(v) end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_CLASSIC,
                function() return W.Opts().classic == true end,
                function(v) W.Opts().classic = v and true or false; stick = true; W.ApplyLook(); W.Dirty() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_LOCKED,
                function() return W.Opts().locked == true end,
                function(v) W.Opts().locked = v and true or false; W.ApplyLook() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_MAIN,
                function() return W.Opts().main == true end,
                function(v) W.SetMain(v) end), { fit = true })
            stack:Add(UI.CreateLabel(f, L.CHATWIN_MAIN_HINT, { size = 11, color = "textDim" }), { fit = true, gap = 2 })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_USE_BLIZZ,
                function() return W.Opts().useBlizz == true end,
                function(v) W.Opts().useBlizz = v and true or false; W.ApplyMain(); W.LayoutInput() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_DETACH,
                function() return W.Opts().detach == true end,
                function(v) W.Opts().detach = v and true or false; W.LayoutInput() end), { fit = true })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_MOVE_INPUT,
                function() return W.Opts().moveInput == true end,
                function(v) W.Opts().moveInput = v and true or false; W.UpdateInputVisibility() end), { fit = true })
            local wLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(wLabel, { height = 16, gap = 8 })
            local wSlider = UI.CreateSlider(f, 240, { min = 200, max = 900, step = 10,
                get = function() return tonumber(W.Opts().inW) or 460 end,
                set = function(v) W.Opts().inW = v; W.LayoutInput() end })
            wSlider.onText = function(v) wLabel:SetText(string.format(L.CHATWIN_INPUT_W, v)) end
            wSlider:Refresh()
            stack:Add(wSlider, { height = 20, gap = 2 })
            stack:Add(UI.CreateButton(f, L.CHATWIN_TEST_INPUT, 260, 24, function() W.Build(); W.TestInput() end), { height = 24, gap = 8 })
            local fLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(fLabel, { height = 16, gap = 10 })
            local fSlider = UI.CreateSlider(f, 240, { min = 8, max = 16, step = 1,
                get = function() return tonumber(W.Opts().fontSize) or 11 end,
                set = function(v) W.Opts().fontSize = v; stick = true; W.Dirty() end })
            fSlider.onText = function(v) fLabel:SetText(string.format(L.CHATWIN_FONTSIZE, v)) end
            fSlider:Refresh()
            stack:Add(fSlider, { height = 20, gap = 2 })
            local mLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(mLabel, { height = 16, gap = 8 })
            local mSlider = UI.CreateSlider(f, 240, { min = 40, max = 95, step = 5,
                get = function() return tonumber(W.Opts().maxW) or 78 end,
                set = function(v) W.Opts().maxW = v; stick = true; W.Dirty() end })
            mSlider.onText = function(v) mLabel:SetText(string.format(L.CHATWIN_MAXW, v)) end
            mSlider:Refresh()
            stack:Add(mSlider, { height = 20, gap = 2 })
            stack:Add(UI.CreateCheckbox(f, L.CHATWIN_COMPACT,
                function() return W.Opts().compact ~= false end,
                function(v) W.Opts().compact = v and true or false; stick = true; W.Dirty() end), { fit = true, gap = 8 })
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
