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

-- Messung in Forever: die globale Tabelle ChatTypeInfo ist leer (0 Eintraege). Dann gelten die Standardfarben von Blizzard.
local FALLBACK = {
    SAY = { 1, 1, 1 }, YELL = { 1, 0.25, 0.25 }, EMOTE = { 1, 0.5, 0.25 }, TEXT_EMOTE = { 1, 0.5, 0.25 },
    GUILD = { 0.25, 1, 0.25 }, OFFICER = { 0.25, 0.75, 0.25 }, PARTY = { 0.67, 0.67, 1 }, PARTY_LEADER = { 0.46, 0.78, 1 },
    RAID = { 1, 0.5, 0 }, RAID_LEADER = { 1, 0.28, 0.04 }, RAID_WARNING = { 1, 0.28, 0 },
    WHISPER = { 1, 0.5, 1 }, WHISPER_INFORM = { 1, 0.5, 1 }, SYSTEM = { 1, 1, 0 },
    CHANNEL = { 1, 0.75, 0.75 },
}
for i = 1, 10 do FALLBACK["CHANNEL" .. i] = FALLBACK.CHANNEL end

local function CTColor(ct)
    local info = G.ChatTypeInfo
    local c = type(info) == "table" and info[ct] or nil
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    local f = FALLBACK[ct]
    if f then return f[1], f[2], f[3] end
    return nil
end

local typeIndex
function S.TypeIndex()
    if typeIndex then return typeIndex end
    typeIndex = {}
    for _, t in ipairs(S.TYPES) do
        for _, ct in ipairs(t[3]) do
            local r, g, b = CTColor(ct)
            if r then
                local k = Key3(r, g, b)
                if not typeIndex[k] then typeIndex[k] = t[1] end
            end
        end
    end
    return typeIndex
end

-- Standardfarbe einer Art laut Spiel
function S.DefaultColor(typeKey)
    for _, t in ipairs(S.TYPES) do
        if t[1] == typeKey then
            local r, g, b = CTColor(t[3][1])
            if r then return r, g, b end
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
-- Messung in Forever: die Zeilen sind Textfelder im Unterrahmen cf.FontStringContainer (nicht im Chatfenster selbst);
-- zusaetzlich gibt es cf.visibleLines und cf.fontStringPool.
local function LineRegions(cf)
    local list, seen = {}, {}
    local function Take(rg)
        if type(rg) == "table" and not seen[rg] then seen[rg] = true; list[#list + 1] = rg end
    end
    local box = cf.FontStringContainer
    if type(box) == "table" and box.GetRegions then
        local ok, regs = pcall(function() return { box:GetRegions() } end)
        if ok then for _, rg in ipairs(regs) do Take(rg) end end
    end
    if #list == 0 and type(cf.visibleLines) == "table" then
        for _, v in pairs(cf.visibleLines) do Take(v) end
    end
    if #list == 0 and cf.GetRegions then
        local ok, regs = pcall(function() return { cf:GetRegions() } end)
        if ok then for _, rg in ipairs(regs) do Take(rg) end end
    end
    return list
end

function S.ReadLines(cf)
    local out = {}
    if not (cf.GetTop and cf.GetLeft) then return out, 0 end
    local cfTop, cfLeft, cfRight = cf:GetTop(), cf:GetLeft(), cf:GetRight()
    if not (cfTop and cfLeft and cfRight) then return out, 0 end
    local nFs = 0
    local regions = LineRegions(cf)
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
    Add("Felder: visibleLines=%s fontStringPool=%s FontStringContainer=%s", tostring(cf.visibleLines ~= nil), tostring(cf.fontStringPool ~= nil), tostring(cf.FontStringContainer ~= nil))
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

------------------------------------------------------------------------
-- Vollstaendiges Protokoll des Chatfensters (/fwchat dump)
------------------------------------------------------------------------

local DUMP_MAX = 900

local function Safe(fn, ...)
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
    return nil
end

local function Short(v)
    if v == nil then return "nil" end
    if type(v) == "string" then
        if Secret(v) then return "<geheim>" end
        v = string.gsub(v, "\124", "\124\124")
        if #v > 70 then v = string.sub(v, 1, 70) .. "..." end
        return "'" .. v .. "'"
    end
    if type(v) == "number" then
        if Secret(v) then return "<geheim>" end
        return (v == math.floor(v)) and string.format("%d", v) or string.format("%.2f", v)
    end
    return tostring(v)
end

local function Num(v) if type(v) == "number" and not Secret(v) then return v end return nil end

local function Points(o)
    if not o.GetNumPoints then return "?" end
    local n = Num(Safe(o.GetNumPoints, o)) or 0
    local out = {}
    for i = 1, n do
        local pt, rel, rp, x, y = Safe(o.GetPoint, o, i)
        local relName = rel and (rel.GetName and Safe(rel.GetName, rel)) or (rel and "?") or "-"
        out[#out + 1] = string.format("%s->%s:%s(%s,%s)", Short(pt), tostring(relName), Short(rp), Short(x), Short(y))
    end
    return table.concat(out, " ")
end

local function Describe(o, add, indent)
    local typ = o.GetObjectType and Safe(o.GetObjectType, o) or "?"
    local name = o.GetName and Safe(o.GetName, o) or nil
    local w, h = o.GetWidth and Safe(o.GetWidth, o), o.GetHeight and Safe(o.GetHeight, o)
    local shown = o.IsShown and Safe(o.IsShown, o)
    local line = string.format("%s%s %s shown=%s size=%sx%s punkte=[%s]", indent, tostring(typ), Short(name), tostring(shown), Short(w), Short(h), Points(o))
    if o.GetDrawLayer then
        local layer, sub = Safe(o.GetDrawLayer, o)
        line = line .. string.format(" layer=%s/%s", tostring(layer), Short(sub))
    end
    if typ == "FontString" then
        local txt = o.GetText and Safe(o.GetText, o)
        local r, g, b, a = nil, nil, nil, nil
        if o.GetTextColor then r, g, b, a = Safe(o.GetTextColor, o) end
        local font, size, flags = nil, nil, nil
        if o.GetFont then font, size, flags = Safe(o.GetFont, o) end
        line = line .. string.format(" text=%s farbe=%s/%s/%s/%s schrift=%s %s %s textbreite=%s hoehe=%s ausr=%s",
            Short(txt), Short(r), Short(g), Short(b), Short(a), Short(font), Short(size), Short(flags),
            Short(o.GetStringWidth and Safe(o.GetStringWidth, o)), Short(o.GetStringHeight and Safe(o.GetStringHeight, o)),
            Short(o.GetJustifyH and Safe(o.GetJustifyH, o)))
    elseif typ == "Texture" then
        local tex = o.GetTexture and Safe(o.GetTexture, o)
        local atlas = o.GetAtlas and Safe(o.GetAtlas, o)
        local r, g, b, a = nil, nil, nil, nil
        if o.GetVertexColor then r, g, b, a = Safe(o.GetVertexColor, o) end
        line = line .. string.format(" textur=%s atlas=%s farbe=%s/%s/%s/%s alpha=%s", Short(tex), Short(atlas), Short(r), Short(g), Short(b), Short(a), Short(o.GetAlpha and Safe(o.GetAlpha, o)))
    end
    add(line)
end

local METHODS = { "GetNumMessages", "GetMessageInfo", "GetNumVisibleLines", "GetScrollOffset", "GetMaxLines", "SetSpacing", "GetSpacing",
    "GetFading", "SetFading", "GetFadeDuration", "GetTimeVisible", "GetIndentedWordWrap", "SetIndentedWordWrap", "AddMessage", "RefreshDisplay",
    "ScrollUp", "ScrollDown", "ScrollToBottom", "AtBottom", "GetInsertMode", "GetFont", "SetFont", "GetNumRegions", "GetNumChildren",
    "SetOnDisplayRefreshedCallback", "GetTextCopyable", "SetHyperlinksEnabled", "GetHyperlinksEnabled", "SetClampRectInsets", "GetBackgroundColor",
    "SetBackdrop", "GetFontObject", "Clear", "GetNumLines", "GetLineInfo", "ForEachVisibleLine", "EnumerateVisibleLineFontStrings" }

local function FieldList(o)
    local t = {}
    local ok = pcall(function()
        for k, v in pairs(o) do t[#t + 1] = tostring(k) .. ":" .. type(v) end
    end)
    table.sort(t)
    return t
end

local function MethodTable(o)
    local out = {}
    pcall(function()
        local mt = getmetatable(o)
        local idx = mt and mt.__index
        if type(idx) == "table" then
            for k, v in pairs(idx) do if type(v) == "function" then out[#out + 1] = tostring(k) end end
        end
    end)
    table.sort(out)
    return out
end

function S.Dump()
    local lines = {}
    local function Add(l)
        if #lines < DUMP_MAX then lines[#lines + 1] = l
        elseif #lines == DUMP_MAX then lines[#lines + 1] = "... Protokoll gekuerzt" end
    end
    local ver, build, bdate, toc = nil, nil, nil, nil
    if G.GetBuildInfo then ver, build, bdate, toc = Safe(G.GetBuildInfo) end
    Add(string.format("Kopf: Freewood-Core ChatStyle, Spielversion %s Build %s Datum %s Interface %s, Zeit %s", Short(ver), Short(build), Short(bdate), Short(toc), G.date and G.date("%Y-%m-%d %H:%M:%S") or "?"))
    Add(string.format("Chatfenster: NUM_CHAT_WINDOWS=%s, CHAT_FRAMES=%s, CVar showTimestamps=%s", Short(G.NUM_CHAT_WINDOWS), type(G.CHAT_FRAMES) == "table" and tostring(#G.CHAT_FRAMES) or "?",
        Short(G.GetCVar and Safe(G.GetCVar, "showTimestamps"))))
    -- Chatfarben
    local names = {}
    if type(G.ChatTypeInfo) == "table" then for k in pairs(G.ChatTypeInfo) do names[#names + 1] = k end end
    table.sort(names)
    Add("ChatTypeInfo: " .. #names .. " Eintraege")
    for _, k in ipairs(names) do
        local c = G.ChatTypeInfo[k]
        if type(c) == "table" and c.r then Add(string.format("  %s = %s/%s/%s", k, Short(c.r), Short(c.g), Short(c.b))) end
    end
    local n = tonumber(G.NUM_CHAT_WINDOWS) or 10
    for i = 1, n do
        local cf = G["ChatFrame" .. i]
        if cf then
            Add("")
            Add("=== ChatFrame" .. i .. " ===")
            Describe(cf, Add, "")
            if G.GetChatWindowInfo then
                local nm, fs, r, g, b, a, shown, locked, docked = Safe(G.GetChatWindowInfo, i)
                Add(string.format("GetChatWindowInfo: name=%s schriftgroesse=%s farbe=%s/%s/%s alpha=%s sichtbar=%s gesperrt=%s angedockt=%s", Short(nm), Short(fs), Short(r), Short(g), Short(b), Short(a), Short(shown), Short(locked), Short(docked)))
            end
            Add(string.format("Skala=%s, wirksame Skala=%s, Strata=%s, Ebene=%s", Short(cf.GetScale and Safe(cf.GetScale, cf)), Short(cf.GetEffectiveScale and Safe(cf.GetEffectiveScale, cf)),
                Short(cf.GetFrameStrata and Safe(cf.GetFrameStrata, cf)), Short(cf.GetFrameLevel and Safe(cf.GetFrameLevel, cf))))
            Add(string.format("Lage: links=%s rechts=%s oben=%s unten=%s", Short(cf.GetLeft and Safe(cf.GetLeft, cf)), Short(cf.GetRight and Safe(cf.GetRight, cf)), Short(cf.GetTop and Safe(cf.GetTop, cf)), Short(cf.GetBottom and Safe(cf.GetBottom, cf))))
            local avail = {}
            for _, m in ipairs(METHODS) do avail[#avail + 1] = m .. "=" .. ((cf[m] ~= nil) and "ja" or "nein") end
            Add("Methoden (Auswahl): " .. table.concat(avail, " "))
            if i == 1 then
                local ms = MethodTable(cf)
                Add("Methoden der Klasse (" .. #ms .. "): " .. table.concat(ms, ","))
                local fl = FieldList(cf)
                Add("Felder des Objekts (" .. #fl .. "): " .. table.concat(fl, ","))
            end
            -- Zahlen
            if cf.GetNumMessages then Add("Nachrichten gespeichert: " .. Short(Safe(cf.GetNumMessages, cf))) end
            if cf.GetNumVisibleLines then Add("sichtbare Zeilen: " .. Short(Safe(cf.GetNumVisibleLines, cf))) end
            if cf.GetScrollOffset then Add("Scroll-Versatz: " .. Short(Safe(cf.GetScrollOffset, cf))) end
            if cf.GetMaxLines then Add("Maximale Zeilen: " .. Short(Safe(cf.GetMaxLines, cf))) end
            if cf.GetSpacing then Add("Zeilenabstand: " .. Short(Safe(cf.GetSpacing, cf))) end
            -- letzte Nachrichten
            if cf.GetNumMessages and cf.GetMessageInfo then
                local total = Num(Safe(cf.GetNumMessages, cf)) or 0
                for idx = math.max(1, total - 5), total do
                    local text, r, g, b, id = Safe(cf.GetMessageInfo, cf, idx)
                    Add(string.format("  Nachricht %d: text=%s farbe=%s/%s/%s id=%s", idx, Short(text), Short(r), Short(g), Short(b), Short(id)))
                end
            end
            -- Regionen
            local okR, allR = pcall(function() return { cf:GetRegions() } end)
            local regs = okR and allR or {}
            Add("Regionen: " .. #regs)
            -- Hauptfenster vollstaendig, die uebrigen nur kurz (Platz im Protokoll)
            for ri, rg in ipairs(regs) do
                if i > 1 and ri > 4 then Add("  ... weitere Regionen nicht ausgegeben"); break end
                if type(rg) == "table" then Describe(rg, Add, "  R ") end
            end
            -- Zeilen im FontStringContainer (alle)
            if i == 1 and type(cf.FontStringContainer) == "table" and cf.FontStringContainer.GetRegions then
                local okC, cr = pcall(function() return { cf.FontStringContainer:GetRegions() } end)
                cr = okC and cr or {}
                Add("Zeilen im FontStringContainer: " .. #cr)
                for _, rg in ipairs(cr) do if type(rg) == "table" then Describe(rg, Add, "  Z ") end end
            end
            -- Kinder
            local ok, kids = pcall(function() return { cf:GetChildren() } end)
            kids = ok and kids or {}
            Add("Kinder: " .. #kids)
            for _, k in ipairs(kids) do
                if type(k) == "table" and i <= 2 then
                    Describe(k, Add, "  K ")
                    local okr, kr = pcall(function() return { k:GetRegions() } end)
                    if okr then
                        for ri, rg in ipairs(kr) do
                            if ri > 6 then Add("    ... weitere Regionen"); break end
                            if type(rg) == "table" then Describe(rg, Add, "    KR ") end
                        end
                    end
                end
            end
            -- bekannte Teile
            for _, part in ipairs({ "Background", "EditBox", "ButtonFrame", "ResizeButton", "Tab", "ScrollBar", "ScrollToBottomButton", "FontStringContainer" }) do
                local o = cf[part] or G["ChatFrame" .. i .. part]
                if type(o) == "table" then Describe(o, Add, "  Teil " .. part .. ": ") end
            end
        end
    end
    return lines
end

function S.SaveDump()
    local lines = S.Dump()
    local db = G.FreewoodDB
    if type(db) == "table" then
        db.chatDump = { at = G.date and G.date("%Y-%m-%d %H:%M:%S") or "", lines = lines }
    end
    return #lines
end

SLASH_FREEWOODCHATSTYLE1 = "/fwchat"
SlashCmdList = SlashCmdList or {}
SlashCmdList["FREEWOODCHATSTYLE"] = function(msg)
    msg = string.lower((string.gsub(msg or "", "^%s+", "")))
    if msg == "probe" then
        for _, l in ipairs(S.Probe()) do FW:Print(l) end
    elseif msg == "dump" then
        local n = S.SaveDump()
        FW:Print(string.format("Chatfenster-Protokoll: %d Zeilen gespeichert. Mit /reload in die Datei schreiben: WTF\\Account\\<KONTO>\\SavedVariables\\Freewood-Core.lua, Eintrag chatDump.", n))
    else
        FW:Print("/fwchat probe, /fwchat dump")
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
