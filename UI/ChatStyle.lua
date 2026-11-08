-- Freewood-Core: Chat verschoenern ("Blasen-Look light") im Chatfenster des Spiels.
-- Jede Zeile bekommt vor dem Anzeigen: Uhrzeit, einen farbigen Balken in der Kanalfarbe, den Absendernamen in Klassenfarbe
-- (ohne Klammern, wenn gewuenscht). Technik: AddMessage der Chatfenster wird eingehuellt (wie bei Chatter/Prat), kein
-- Chat-Filter. Geheime Werte werden unveraendert durchgereicht, bei jedem Fehler wird die Zeile unveraendert angezeigt.
-- Alles per Einstellung (Reiter Chat) abschaltbar. UNGEPRUEFT im Spiel.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local S = {}
FW.ChatStyle = S

S.DEFAULTS = {
    enabled = true,
    time = true,
    bar = true,
    classColor = true,
    brackets = false,      -- Klammern um Namen behalten
    barWidth = "thin",     -- thin, medium, wide
    spacing = 0,           -- Zeilenabstand in Pixeln (0 bis 8)
    bgOn = false,          -- Fensterhintergrund selbst bestimmen
    bgAlpha = 60,          -- Deckkraft in Prozent
    bgColor = { 0, 0, 0 },
    lineBg = false,        -- Versuch: Flaeche hinter jeder Zeile (Textfelder des Chatfensters werden ausgelesen)
    lineBgAlpha = 35,      -- Deckkraft in Prozent
    types = {},            -- [Art] = { bar = {r,g,b}, text = {r,g,b} }
}

-- Chat-Arten: Schluessel, Anzeigename (Locales), Eintraege in ChatTypeInfo
S.TYPES = {
    { "say", "CHATSTYLE_T_SAY", { "SAY" } },
    { "yell", "CHATSTYLE_T_YELL", { "YELL" } },
    { "emote", "CHATSTYLE_T_EMOTE", { "EMOTE", "TEXT_EMOTE" } },
    { "guild", "CHATSTYLE_T_GUILD", { "GUILD" } },
    { "officer", "CHATSTYLE_T_OFFICER", { "OFFICER" } },
    { "party", "CHATSTYLE_T_PARTY", { "PARTY", "PARTY_LEADER" } },
    { "raid", "CHATSTYLE_T_RAID", { "RAID", "RAID_LEADER", "RAID_WARNING" } },
    { "whisper", "CHATSTYLE_T_WHISPER", { "WHISPER", "WHISPER_INFORM" } },
    { "channel", "CHATSTYLE_T_CHANNEL", { "CHANNEL", "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5", "CHANNEL6", "CHANNEL7", "CHANNEL8", "CHANNEL9", "CHANNEL10" } },
    { "system", "CHATSTYLE_T_SYSTEM", { "SYSTEM" } },
}

local BAR_GLYPH = { thin = "\226\150\140", medium = "\226\150\136", wide = "\226\150\136\226\150\136" }   -- ▌ █ ██

local function Key3(r, g, b)
    return string.format("%d,%d,%d", math.floor((tonumber(r) or 0) * 100 + 0.5), math.floor((tonumber(g) or 0) * 100 + 0.5), math.floor((tonumber(b) or 0) * 100 + 0.5))
end

local typeIndex
function S.TypeIndex()
    if typeIndex then return typeIndex end
    typeIndex = {}
    local info = G.ChatTypeInfo
    if type(info) ~= "table" then return typeIndex end
    for _, t in ipairs(S.TYPES) do
        for _, ct in ipairs(t[3]) do
            local c = info[ct]
            if type(c) == "table" and c.r then
                local k = Key3(c.r, c.g, c.b)
                if not typeIndex[k] then typeIndex[k] = t[1] end
            end
        end
    end
    return typeIndex
end

-- Standardfarbe einer Art laut Spiel
function S.DefaultColor(typeKey)
    local info = G.ChatTypeInfo
    for _, t in ipairs(S.TYPES) do
        if t[1] == typeKey and type(info) == "table" then
            local c = info[t[3][1]]
            if type(c) == "table" and c.r then return c.r, c.g, c.b end
        end
    end
    return 1, 1, 1
end

-- Zeitangabe des Spiels am Zeilenanfang (Zeitstempel in den Chat-Einstellungen)
local function HasGameTime(text)
    local t = string.gsub(text, "^\124c%x%x%x%x%x%x%x%x", "")
    return string.find(t, "^%s*%[?%d%d?:%d%d") ~= nil
end

local MARK = "\124cff000001\124r"   -- unsichtbare Marke: Zeile wurde schon bearbeitet

local function Secret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) or false
end

function S.Opts()
    local st = FW.settings
    if type(st) ~= "table" then return S.DEFAULTS end
    if type(st.chatStyle) ~= "table" then st.chatStyle = {} end
    local o = st.chatStyle
    for k, v in pairs(S.DEFAULTS) do
        if o[k] == nil then
            if type(v) == "table" then
                local c = {}
                for k2, v2 in pairs(v) do c[k2] = v2 end
                v = c
            end
            o[k] = v
        end
    end
    return o
end

local function Hex(r, g, b)
    local function c(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format("\124cff%02x%02x%02x", c(r), c(g), c(b))
end

local function NameKey(link, shown)
    local n = string.match(link or "", "^player:([^:]+)")
    if n and n ~= "" then return n end
    return shown
end

-- Zeile umbauen; gibt neuen Text und Textfarbe zurueck (unveraendert, wenn nichts zu tun ist)
function S.Format(text, r, g, b)
    if type(text) ~= "string" or Secret(text) or text == "" then return text, r, g, b end
    local o = S.Opts()
    if not o.enabled then return text, r, g, b end
    if string.find(text, MARK, 1, true) then return text, r, g, b end
    local nr, ng, nb = tonumber(r), tonumber(g), tonumber(b)
    if Secret(r) or Secret(g) or Secret(b) then nr, ng, nb = nil, nil, nil end
    -- Art der Zeile ueber die Zeilenfarbe erkennen und eigene Farben anwenden
    local typeKey = (nr and ng and nb) and S.TypeIndex()[Key3(nr, ng, nb)] or nil
    local custom = typeKey and type(o.types) == "table" and o.types[typeKey] or nil
    local barR, barG, barB = nr, ng, nb
    if custom and type(custom.bar) == "table" then barR, barG, barB = custom.bar[1], custom.bar[2], custom.bar[3] end
    if custom and type(custom.text) == "table" then nr, ng, nb = custom.text[1], custom.text[2], custom.text[3] end
    local back = (nr and ng and nb) and Hex(nr, ng, nb) or nil
    local barHex = (barR and barG and barB) and Hex(barR, barG, barB) or nil

    if o.classColor or not o.brackets then
        local CL = FW.ChatLog
        text = string.gsub(text, "(\124H(player:[^\124]*)\124h)%[([^%]]*)%](\124h)", function(open, link, shown, close)
            local inner = o.brackets and ("[" .. shown .. "]") or shown
            if o.classColor and CL and CL.Info and CL.ClassColor then
                local tok = CL.Info(NameKey(link, shown))
                if tok then
                    local cr, cg, cb = CL.ClassColor(tok)
                    inner = Hex(cr, cg, cb) .. inner .. "\124r" .. (back or "")
                end
            end
            return open .. inner .. close
        end)
    end

    local pre = MARK
    if o.time and G.date and not HasGameTime(text) then
        pre = pre .. "\124cff8a8a8a" .. G.date("%H:%M") .. "\124r "
    end
    if o.bar and barHex then
        pre = pre .. barHex .. (BAR_GLYPH[o.barWidth] or BAR_GLYPH.thin) .. "\124r "
    end
    return pre .. text, nr, ng, nb
end

------------------------------------------------------------------------
-- Einhuellen von AddMessage
------------------------------------------------------------------------

local wrapped = setmetatable({}, { __mode = "k" })

local function Wrap(cf)
    if not cf or wrapped[cf] or type(cf.AddMessage) ~= "function" then return false end
    local orig = cf.AddMessage
    wrapped[cf] = orig
    cf.AddMessage = function(self, text, r, g, b, ...)
        local ok, t2, r2, g2, b2 = pcall(S.Format, text, r, g, b)
        if ok and type(t2) == "string" then text, r, g, b = t2, r2, g2, b2 end
        return orig(self, text, r, g, b, ...)
    end
    return true
end

function S.Unwrap(cf)
    local orig = wrapped[cf]
    if orig then cf.AddMessage = orig; wrapped[cf] = nil end
end

------------------------------------------------------------------------
-- Versuch: Flaeche hinter jeder Zeile
------------------------------------------------------------------------

local under = setmetatable({}, { __mode = "k" })    -- Chatfenster -> { tex = {...}, used = n }

-- Textfarbe -> Chat-Art, auch fuer eigene Textfarben
local function LineType(r, g, b)
    local o = S.Opts()
    local k = Key3(r, g, b)
    if type(o.types) == "table" then
        for key, c in pairs(o.types) do
            if type(c) == "table" and type(c.text) == "table" and Key3(c.text[1], c.text[2], c.text[3]) == k then return key end
        end
    end
    return S.TypeIndex()[k]
end

local function BgColor(typeKey, r, g, b)
    local o = S.Opts()
    local c = typeKey and type(o.types) == "table" and o.types[typeKey]
    if c and type(c.bg) == "table" then return c.bg[1], c.bg[2], c.bg[3] end
    if typeKey then return S.DefaultColor(typeKey) end
    return r, g, b
end

local function Pool(cf)
    local u = under[cf]
    if not u then u = { tex = {}, used = 0 }; under[cf] = u end
    return u
end

local function Tex(cf, u, i)
    local t = u.tex[i]
    if t then return t end
    local ok, tx = pcall(cf.CreateTexture, cf, nil, "BACKGROUND", nil, 7)
    if not ok or not tx then ok, tx = pcall(cf.CreateTexture, cf, nil, "BACKGROUND") end
    if not ok or not tx then return nil end
    u.tex[i] = tx
    return tx
end

local function HideUnder(cf, from)
    local u = under[cf]
    if not u then return end
    for i = from or 1, #u.tex do u.tex[i]:Hide() end
end

-- Zeilen des Chatfensters lesen: { { top, bottom, r, g, b } } (Abstand von der Oberkante des Fensters)
function S.ReadLines(cf)
    local out = {}
    if not (cf.GetRegions and cf.GetTop and cf.GetLeft) then return out, 0 end
    local cfTop, cfLeft, cfRight = cf:GetTop(), cf:GetLeft(), cf:GetRight()
    if not (cfTop and cfLeft and cfRight) then return out, 0 end
    local nFs = 0
    local regions = { cf:GetRegions() }
    for _, rg in ipairs(regions) do
        if rg.GetObjectType and rg:GetObjectType() == "FontString" then
            nFs = nFs + 1
            if rg:IsShown() then
                local txt = rg.GetText and rg:GetText()
                local top, bottom = rg:GetTop(), rg:GetBottom()
                if type(txt) == "string" and not Secret(txt) and txt ~= "" and top and bottom then
                    local r, g, b
                    if rg.GetTextColor then r, g, b = rg:GetTextColor() end
                    out[#out + 1] = { top = cfTop - top, bottom = cfTop - bottom, r = r, g = g, b = b, left = cfLeft, right = cfRight }
                end
            end
        end
    end
    return out, nFs
end

function S.UpdateUnder(cf)
    local o = S.Opts()
    if not (o.enabled and o.lineBg) then return HideUnder(cf, 1) end
    local lines = S.ReadLines(cf)
    local u = Pool(cf)
    local alpha = (tonumber(o.lineBgAlpha) or 35) / 100
    local pad = (tonumber(o.spacing) or 0) / 2 + 1
    local n = 0
    local cfTop = cf:GetTop()
    for _, ln in ipairs(lines) do
        if ln.r and ln.g and ln.b and not Secret(ln.r) then
            local key = LineType(ln.r, ln.g, ln.b)
            local r, g, b = BgColor(key, ln.r, ln.g, ln.b)
            n = n + 1
            local t = Tex(cf, u, n)
            if not t then n = n - 1; break end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, -(ln.top - pad))
            t:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 0, -(ln.top - pad))
            t:SetHeight(math.max(1, ln.bottom - ln.top + pad * 2))
            t:SetColorTexture(r, g, b, alpha)
            t:Show()
        end
    end
    HideUnder(cf, n + 1)
    u.used = n
    return n
end

local underFrame, underAcc = nil, 0
local function UnderTick(_, elapsed)
    underAcc = underAcc + (elapsed or 0)
    if underAcc < 0.1 then return end
    underAcc = 0
    local nwin = tonumber(G.NUM_CHAT_WINDOWS) or 10
    for i = 1, nwin do
        local cf = G["ChatFrame" .. i]
        if cf and cf.IsShown and cf:IsShown() then pcall(S.UpdateUnder, cf) end
    end
end

function S.StartUnder()
    if underFrame or not G.CreateFrame then return end
    underFrame = G.CreateFrame("Frame")
    underFrame:SetScript("OnUpdate", UnderTick)
end

-- Messung: was gibt das Chatfenster her? (/fwchat probe)
function S.Probe()
    local out = {}
    local function Add(...) out[#out + 1] = string.format(...) end
    local cf = G.ChatFrame1
    if not cf then Add("ChatFrame1 nicht gefunden"); return out end
    Add("Chatfenster: Typ %s, Methoden: GetRegions=%s GetNumMessages=%s GetNumVisibleLines=%s SetSpacing=%s", tostring(cf.GetObjectType and cf:GetObjectType()),
        tostring(cf.GetRegions ~= nil), tostring(cf.GetNumMessages ~= nil), tostring(cf.GetNumVisibleLines ~= nil), tostring(cf.SetSpacing ~= nil))
    Add("Felder: visibleLines=%s fontStringPool=%s", tostring(cf.visibleLines ~= nil), tostring(cf.fontStringPool ~= nil))
    local lines, nFs = S.ReadLines(cf)
    Add("Textfelder: %d, davon mit Text sichtbar: %d", nFs or 0, #lines)
    for i, ln in ipairs(lines) do
        if i > 4 then break end
        Add("  Zeile %d: oben %.0f, unten %.0f, Farbe %s/%s/%s, Art %s", i, ln.top, ln.bottom, tostring(ln.r and string.format("%.2f", ln.r)),
            tostring(ln.g and string.format("%.2f", ln.g)), tostring(ln.b and string.format("%.2f", ln.b)), tostring(ln.r and LineType(ln.r, ln.g, ln.b)))
    end
    local u = under[cf]
    Add("Hintergrundflaechen gezeichnet: %d (Einstellung %s)", u and u.used or 0, tostring(S.Opts().lineBg))
    return out
end

SLASH_FREEWOODCHATSTYLE1 = "/fwchat"
SlashCmdList = SlashCmdList or {}
SlashCmdList["FREEWOODCHATSTYLE"] = function(msg)
    msg = string.lower((string.gsub(msg or "", "^%s+", "")))
    if msg == "probe" then
        for _, l in ipairs(S.Probe()) do FW:Print(l) end
    else
        FW:Print("/fwchat probe")
    end
end

-- Zeilenabstand und Fensterhintergrund (nur wenn eingeschaltet)
function S.ApplyLook()
    local o = S.Opts()
    local n = tonumber(G.NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
        local cf = G["ChatFrame" .. i]
        if cf then
            if o.enabled and cf.SetSpacing then pcall(cf.SetSpacing, cf, tonumber(o.spacing) or 0) end
            if o.enabled and o.bgOn then
                local c = o.bgColor or { 0, 0, 0 }
                if G.FCF_SetWindowColor then pcall(G.FCF_SetWindowColor, cf, c[1] or 0, c[2] or 0, c[3] or 0) end
                if G.FCF_SetWindowAlpha then pcall(G.FCF_SetWindowAlpha, cf, (tonumber(o.bgAlpha) or 60) / 100) end
            end
        end
    end
end

function S.Install()
    local n = tonumber(G.NUM_CHAT_WINDOWS) or 10
    local count = 0
    for i = 1, n do
        local cf = G["ChatFrame" .. i]
        if cf and Wrap(cf) then count = count + 1 end
    end
    pcall(S.ApplyLook)
    pcall(S.StartUnder)
    return count
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function() pcall(S.Install) end)
FW:RegisterEvent("UPDATE_CHAT_WINDOWS", function() pcall(S.Install) end)
FW:RegisterEvent("UPDATE_CHAT_COLOR", function() typeIndex = nil end)

------------------------------------------------------------------------
-- Einstellungen
------------------------------------------------------------------------

local function OpenPicker(r, g, b, set)
    local picker = G.ColorPickerFrame
    if not picker then return end
    local function Changed()
        local nr, ng, nb = picker:GetColorRGB()
        set(nr, ng, nb)
    end
    local function Cancel() set(r, g, b) end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = Changed, cancelFunc = Cancel })
    else
        picker.hasOpacity = false
        picker.func = Changed
        picker.cancelFunc = Cancel
        picker:SetColorRGB(r, g, b)
        picker:Show()
    end
end

local function Swatch(parent, w, get, set, clear)
    local sw = UI.CreateButton(parent, "", w, 22, function()
        local r, g, b = get()
        OpenPicker(r, g, b, set)
    end, "default")
    local fill = sw:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT", sw, "TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -4, 4)
    function sw.Paint()
        local r, g, b = get()
        fill:SetColorTexture(r, g, b, 1)
    end
    sw.Paint()
    return sw
end

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("chat-style", {
        category = "chat",
        order = 20,
        height = 600,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATSTYLE_TITLE)
            local function Box(label, key)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return S.Opts()[key] == true end,
                    function(v) S.Opts()[key] = v and true or false; S.ApplyLook() end), { fit = true })
            end
            Box(L.CHATSTYLE_ENABLED, "enabled")
            Box(L.CHATSTYLE_TIME, "time")
            Box(L.CHATSTYLE_BAR, "bar")
            Box(L.CHATSTYLE_CLASS, "classColor")
            Box(L.CHATSTYLE_BRACKETS, "brackets")

            stack:Add(UI.CreateLabel(f, L.CHATSTYLE_BARWIDTH, { size = 12 }), { height = 16, gap = 10 })
            local names = { thin = L.CHATSTYLE_W_THIN, medium = L.CHATSTYLE_W_MEDIUM, wide = L.CHATSTYLE_W_WIDE }
            local dd = UI.CreateDropdown(f, 160, 22, {
                getOptions = function() return { { value = "thin", text = names.thin }, { value = "medium", text = names.medium }, { value = "wide", text = names.wide } } end,
                textOf = function(v) return names[v] or "" end,
                onChange = function(v) if v then S.Opts().barWidth = v end end,
            })
            dd:SetValue(S.Opts().barWidth)
            stack:Add(dd, { height = 22, gap = 4 })

            local spLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(spLabel, { height = 16, gap = 10 })
            local spacing = UI.CreateSlider(f, 240, { min = 0, max = 8, step = 1,
                get = function() return tonumber(S.Opts().spacing) or 0 end,
                set = function(v) S.Opts().spacing = v; S.ApplyLook() end })
            spacing.onText = function(v) spLabel:SetText(string.format(L.CHATSTYLE_SPACING, v)) end
            spacing:Refresh()
            stack:Add(spacing, { height = 20, gap = 2 })

            Box(L.CHATSTYLE_BGON, "bgOn")
            local bgRow = CreateFrame("Frame", nil, f)
            bgRow:SetSize(300, 26)
            local bgLabel = UI.CreateLabel(bgRow, L.CHATSTYLE_BGCOLOR, { size = 12 })
            bgLabel:SetPoint("LEFT", bgRow, "LEFT", 0, 0)
            local bgSw = Swatch(bgRow, 64, function() local c = S.Opts().bgColor or { 0, 0, 0 }; return c[1], c[2], c[3] end,
                function(r, g, b) S.Opts().bgColor = { r, g, b }; S.ApplyLook() end)
            bgSw:SetPoint("LEFT", bgRow, "LEFT", 190, 0)
            stack:Add(bgRow, { height = 26, gap = 4 })
            local bgLabel2 = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(bgLabel2, { height = 16, gap = 6 })
            local bgAlpha = UI.CreateSlider(f, 240, { min = 0, max = 100, step = 5,
                get = function() return tonumber(S.Opts().bgAlpha) or 60 end,
                set = function(v) S.Opts().bgAlpha = v; S.ApplyLook() end })
            bgAlpha.onText = function(v) bgLabel2:SetText(string.format(L.CHATSTYLE_BGALPHA, v)) end
            bgAlpha:Refresh()
            stack:Add(bgAlpha, { height = 20, gap = 2 })

            Box(L.CHATSTYLE_LINEBG, "lineBg")
            local lbLabel = UI.CreateLabel(f, "", { size = 12 })
            stack:Add(lbLabel, { height = 16, gap = 6 })
            local lbAlpha = UI.CreateSlider(f, 240, { min = 5, max = 100, step = 5,
                get = function() return tonumber(S.Opts().lineBgAlpha) or 35 end,
                set = function(v) S.Opts().lineBgAlpha = v end })
            lbAlpha.onText = function(v) lbLabel:SetText(string.format(L.CHATSTYLE_LINEBGALPHA, v)) end
            lbAlpha:Refresh()
            stack:Add(lbAlpha, { height = 20, gap = 2 })
            stack:Add(UI.CreateLabel(f, L.CHATSTYLE_HINT, { size = 11, color = "textDim" }), { height = 30, gap = 8 })
            return f
        end,
    })

    UI:RegisterSettingsSection("chat-style-colors", {
        category = "chat",
        order = 30,
        height = 440,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CHATSTYLE_COLORS)
            stack:Add(UI.CreateLabel(f, L.CHATSTYLE_COLORS_HINT, { size = 11, color = "textDim" }), { height = 44, gap = 4 })
            local head = CreateFrame("Frame", nil, f)
            head:SetSize(400, 18)
            local h1 = UI.CreateLabel(head, L.CHATSTYLE_COL_BAR, { size = 11, color = "textDim" }); h1:SetPoint("LEFT", head, "LEFT", 130, 0)
            local h2 = UI.CreateLabel(head, L.CHATSTYLE_COL_TEXT, { size = 11, color = "textDim" }); h2:SetPoint("LEFT", head, "LEFT", 192, 0)
            local h3 = UI.CreateLabel(head, L.CHATSTYLE_COL_BG, { size = 11, color = "textDim" }); h3:SetPoint("LEFT", head, "LEFT", 254, 0)
            stack:Add(head, { height = 18, gap = 2 })
            local swatches = {}
            for _, t in ipairs(S.TYPES) do
                local key = t[1]
                local row = CreateFrame("Frame", nil, f)
                row:SetSize(400, 26)
                local label = UI.CreateLabel(row, L[t[2]], { size = 12 })
                label:SetPoint("LEFT", row, "LEFT", 0, 0)
                local function Slot(kind) -- "bar" oder "text"
                    local function Get()
                        local c = S.Opts().types[key]
                        c = c and c[kind]
                        if type(c) == "table" then return c[1], c[2], c[3] end
                        return S.DefaultColor(key)
                    end
                    local function Set(r, g, b)
                        local ty = S.Opts().types
                        ty[key] = ty[key] or {}
                        ty[key][kind] = { r, g, b }
                        for _, w in ipairs(swatches) do w.Paint() end
                    end
                    return Swatch(row, 52, Get, Set)
                end
                local sb = Slot("bar"); sb:SetPoint("LEFT", row, "LEFT", 130, 0)
                local st = Slot("text"); st:SetPoint("LEFT", row, "LEFT", 192, 0)
                local sg = Slot("bg"); sg:SetPoint("LEFT", row, "LEFT", 254, 0)
                swatches[#swatches + 1] = sb; swatches[#swatches + 1] = st; swatches[#swatches + 1] = sg
                local rb = UI.CreateButton(row, L.CHATSTYLE_RESET, 76, 22, function()
                    S.Opts().types[key] = nil
                    for _, w in ipairs(swatches) do w.Paint() end
                end, "default")
                rb:SetPoint("LEFT", row, "LEFT", 314, 0)
                stack:Add(row, { height = 26, gap = 2 })
            end
            return f
        end,
    })
end
