-- Freewood-Core: Reiter "Design" in den Einstellungen. Farben ueber den Farbwaehler, Transparenz der Flaechen,
-- Schriftart und Schriftgroesse der Haupt-Reiter. Einstellungen in FreewoodDB.settings.design:
--   { colors = { [Schluessel] = "rrggbb" }, alpha = 30..100, tabSize = 9..20, fontHeading = Pfad, fontBody = Pfad }
-- Umfaerben im laufenden Spiel: Kit.lua merkt jede Textur/jeden Text, der seine Farbe aus UI.Color bekam (UI.tracked);
-- dazu kommen die festen Teile des Hauptfensters aus MainWindow.xml (STATIC unten). Fehlt der Haken in die Methodentabellen
-- (UI.liveColors == false), gelten Farbaenderungen nach /reload. Die Schriftart fuer normale Texte gilt ebenfalls nach /reload.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local D = {}
FW.Design = D

D.KEYS = {
    { "bgDeep", "DESIGN_C_BGDEEP" }, { "bg", "DESIGN_C_BG" }, { "panel", "DESIGN_C_PANEL" }, { "card", "DESIGN_C_CARD" },
    { "hover", "DESIGN_C_HOVER" }, { "gold", "DESIGN_C_GOLD" }, { "goldLight", "DESIGN_C_GOLDLIGHT" }, { "bronze", "DESIGN_C_BRONZE" },
    { "text", "DESIGN_C_TEXT" }, { "textDim", "DESIGN_C_TEXTDIM" },
}

D.FONTS = {
    { "", "DESIGN_FONT_DEFAULT" },
    { "Fonts\\FRIZQT__.TTF", nil, "Friz Quadrata" },
    { "Fonts\\ARIALN.TTF", nil, "Arial Narrow" },
    { "Fonts\\MORPHEUS.TTF", nil, "Morpheus" },
    { "Fonts\\SKURRI.TTF", nil, "Skurri" },
}

-- Waehlbare Gesamtdesigns. Das Standarddesign hat keinen Eintrag (= die Farben aus Kit.lua).
-- Ein Design mit "frame" bekommt ein eigenes Fensteraufbau-Modul (UI/ThemeLegion.lua).
D.THEMES = {
    legion = {
        name = "DESIGN_THEME_LEGION",
        colors = {
            bgDeep = "d4c08f", bg = "e8d9b0", panel = "dcc99a", card = "efe2bf", hover = "bf9a5c",
            gold = "8a5a14", goldLight = "5a1a0a", bronze = "7a5a2a",
            text = "1a1208", textDim = "5c4a2c",
            danger = "9a2a20", success = "2f7a2f",
        },
    },
}
D.THEME_ORDER = { "default", "legion" }

local DEFAULTS = { alpha = 100, tabSize = 13, fontHeading = "", fontBody = "", theme = "default" }

local function Opts()
    local s = FW.settings
    if type(s) ~= "table" then return { colors = {}, alpha = 100, tabSize = 13, fontHeading = "", fontBody = "", theme = "default" } end
    if type(s.design) ~= "table" then s.design = {} end
    local o = s.design
    if type(o.colors) ~= "table" then o.colors = {} end
    for k, v in pairs(DEFAULTS) do if o[k] == nil then o[k] = v end end
    return o
end
D.Opts = Opts

local function ToHex(r, g, b)
    local function c(v) return string.format("%02x", math.max(0, math.min(255, math.floor(v * 255 + 0.5)))) end
    return c(r) .. c(g) .. c(b)
end

-- feste Teile des Hauptfensters (Farben stehen in MainWindow.xml): { Pfad, Schluessel, Grundtransparenz }
local STATIC = {
    { "Bg", "bg", 0.97 }, { "BorderTop", "bronze", 1 }, { "BorderBottom", "bronze", 1 }, { "BorderLeft", "bronze", 1 }, { "BorderRight", "bronze", 1 },
    { "Header.Bg", "bgDeep", 1 }, { "Header.Accent", "gold", 0.55 }, { "TabBar.Bg", "panel", 1 }, { "TabBar.Line", "bronze", 0.5 },
    { "Footer.Bg", "bgDeep", 1 },
}

local function ApplyStatic()
    local w = UI.window
    if not w then return end
    for _, e in ipairs(STATIC) do
        local obj = w
        for part in string.gmatch(e[1], "[^%.]+") do obj = obj and obj[part] end
        if obj and obj.SetColorTexture then obj:SetColorTexture(UI.Color(e[2], e[3])) end
    end
end

function D.Recolor()
    ApplyStatic()
    for region, rec in pairs(UI.tracked) do
        pcall(function()
            if rec.kind == "tex" then region:SetColorTexture(UI.Color(rec.key, rec.a))
            else region:SetTextColor(UI.Color(rec.key, rec.a)) end
        end)
    end
end

local pending
local function RecolorSoon()
    if pending then return end
    pending = true
    local function Run() pending = false; D.Recolor() end
    if G.C_Timer and G.C_Timer.After then G.C_Timer.After(0.08, Run) else Run() end
end

local function ApplyColors()
    local o = Opts()
    for key, def in pairs(UI.hexDefault) do UI.hex[key] = def end
    local th = D.THEMES[o.theme]
    if th then
        for key, hex in pairs(th.colors) do
            if UI.hexDefault[key] then UI.hex[key] = hex end
        end
    end
    for key, hex in pairs(o.colors) do
        if UI.hexDefault[key] and type(hex) == "string" and #hex == 6 then UI.hex[key] = hex end
    end
    UI.alphaFactor = math.max(0.3, math.min(1, (o.alpha or 100) / 100))
    UI.ResetColorCache()
end

local function FontOk(path)
    if path == "" then return true end
    local f = D.testFont
    if not f then f = UIParent:CreateFontString(nil, "OVERLAY"); D.testFont = f end
    local ok, res = pcall(f.SetFont, f, path, 12, "")
    return ok and res ~= false
end

local function ApplyFonts()
    local o = Opts()
    UI.fontOverride.heading = FontOk(o.fontHeading) and o.fontHeading or ""
    UI.fontOverride.body = FontOk(o.fontBody) and o.fontBody or ""
    UI.tabFontSize = math.max(9, math.min(20, o.tabSize or 13))
    if UI.window and UI.ApplyTabFont then UI:ApplyTabFont(UI.tabFontSize) end
end

function D.ApplyAll()
    ApplyColors()
    ApplyFonts()
    D.Recolor()
end

function D.SetColor(key, r, g, b)
    if not UI.hexDefault[key] then return end
    local o = Opts()
    if r then o.colors[key] = ToHex(r, g, b) else o.colors[key] = nil end
    ApplyColors()
    RecolorSoon()
    FW:Fire("DESIGN_CHANGED")
end

function D.ResetColors()
    local o = Opts()
    o.colors = {}
    ApplyColors()
    RecolorSoon()
    FW:Fire("DESIGN_CHANGED")
end

-- Gesamtdesign: "default" oder ein Schluessel aus D.THEMES
function D.GetTheme()
    local t = Opts().theme
    return D.THEMES[t] and t or "default"
end

function D.IsTheme(name)
    return D.GetTheme() == name
end

function D.SetTheme(name)
    if name ~= "default" and not D.THEMES[name] then name = "default" end
    Opts().theme = name
    ApplyColors()
    if FW.ThemeLegion then FW.ThemeLegion.Apply(name == "legion") end
    D.Recolor()
    FW:Fire("DESIGN_CHANGED")
end

function D.SetAlpha(percent)
    Opts().alpha = percent
    ApplyColors()
    RecolorSoon()
end

function D.SetTabSize(size)
    Opts().tabSize = size
    ApplyFonts()
end

function D.SetFont(kind, path)
    local o = Opts()
    if kind == "heading" then o.fontHeading = path else o.fontBody = path end
    ApplyFonts()
    FW:Fire("DESIGN_CHANGED")
end

FW:On("FW_DB_READY", function() D.ApplyAll() end)

------------------------------------------------------------------------
-- Farbwaehler
------------------------------------------------------------------------
local function OpenPicker(key)
    local r, g, b = UI.Color(key)
    local picker = G.ColorPickerFrame
    if not picker then return end
    local function Changed()
        local nr, ng, nb = picker:GetColorRGB()
        D.SetColor(key, nr, ng, nb)
    end
    local function Cancel() D.SetColor(key, r, g, b) end
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

------------------------------------------------------------------------
-- Einstellungen: Reiter "Design"
------------------------------------------------------------------------
local function FontOptions()
    local L = FW.L
    local list = {}
    for _, f in ipairs(D.FONTS) do
        if FontOk(f[1]) then list[#list + 1] = { value = f[1], text = f[2] and L[f[2]] or f[3] } end
    end
    return list
end

local function FontName(path)
    for _, f in ipairs(D.FONTS) do
        if f[1] == path then return f[2] and FW.L[f[2]] or f[3] end
    end
    return path
end

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("design", {
        category = "design",
        order = 10,
        height = 700,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.DESIGN_TITLE)
            local refreshers = {}
            -- Gesamtdesign waehlen
            stack:Add(UI.CreateLabel(f, L.DESIGN_THEME, { size = 12 }), { height = 16, gap = 2 })
            local function ThemeOptions()
                local list = {}
                for _, id in ipairs(D.THEME_ORDER) do
                    list[#list + 1] = { value = id, text = id == "default" and L.DESIGN_THEME_DEFAULT or L[D.THEMES[id].name] }
                end
                return list
            end
            local themeDd = UI.CreateDropdown(f, 260, 22, {
                getOptions = ThemeOptions,
                textOf = function(v) return v == "default" and L.DESIGN_THEME_DEFAULT or (D.THEMES[v] and L[D.THEMES[v].name]) or tostring(v) end,
                onChange = function(v) if v ~= nil and v ~= D.GetTheme() then D.SetTheme(v) end end,
            })
            themeDd:SetValue(D.GetTheme())
            stack:Add(themeDd, { height = 22, gap = 4 })
            refreshers[#refreshers + 1] = function() themeDd:SetValue(D.GetTheme()) end
            stack:Add(UI.CreateLabel(f, L.DESIGN_THEME_NOTE, { size = 11, color = "textDim" }), { height = 44, gap = 6 })

            stack:Add(UI.CreateLabel(f, L.DESIGN_HINT, { size = 11, color = "textDim" }), { height = 30, gap = 4 })

            for _, k in ipairs(D.KEYS) do
                local key = k[1]
                local row = CreateFrame("Frame", nil, f)
                row:SetSize(300, 26)
                local label = UI.CreateLabel(row, L[k[2]], { size = 12 })
                label:SetPoint("LEFT", row, "LEFT", 0, 0)
                local sw = UI.CreateButton(row, "", 64, 22, function() OpenPicker(key) end, "default")
                sw:SetPoint("LEFT", row, "LEFT", 190, 0)
                local fill = sw:CreateTexture(nil, "OVERLAY")
                fill:SetPoint("TOPLEFT", sw, "TOPLEFT", 4, -4)
                fill:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -4, 4)
                local function Paint()
                    local hex = UI.hex[key] or "ffffff"
                    fill:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1)
                end
                Paint()
                refreshers[#refreshers + 1] = Paint
                stack:Add(row, { height = 26, gap = 2 })
            end
            local reset = UI.CreateButton(f, L.DESIGN_RESET, 220, 24, function() D.ResetColors() end, "default")
            stack:Add(reset, { height = 24, gap = 8 })

            local function Slider(label, lo, hi, step, get, set)
                local lab = UI.CreateLabel(f, "", { size = 12 })
                stack:Add(lab, { height = 16, gap = 12 })
                local sl = UI.CreateSlider(f, 240, { min = lo, max = hi, step = step, get = get, set = set })
                sl.onText = function(v) lab:SetText(string.format(label, v)) end
                sl:Refresh()
                stack:Add(sl, { height = 20, gap = 2 })
                refreshers[#refreshers + 1] = function() sl:Refresh() end
            end
            Slider(L.DESIGN_ALPHA, 30, 100, 5, function() return Opts().alpha end, function(v) D.SetAlpha(v) end)

            stack:Add(UI.CreateLabel(f, L.DESIGN_FONT_TITLE, { size = 13, color = "goldLight" }), { height = 18, gap = 14 })
            Slider(L.DESIGN_TABSIZE, 9, 20, 1, function() return Opts().tabSize end, function(v) D.SetTabSize(v) end)

            local function FontDropdown(title, kind, key)
                stack:Add(UI.CreateLabel(f, title, { size = 12 }), { height = 16, gap = 10 })
                local dd = UI.CreateDropdown(f, 220, 22, {
                    getOptions = FontOptions,
                    textOf = function(v) return FontName(v or "") end,
                    onChange = function(v) if v ~= nil then D.SetFont(kind, v) end end,
                })
                dd:SetValue(Opts()[key] or "")
                stack:Add(dd, { height = 22, gap = 4 })
                refreshers[#refreshers + 1] = function() dd:SetValue(Opts()[key] or "") end
            end
            FontDropdown(L.DESIGN_FONT_HEAD, "heading", "fontHeading")
            FontDropdown(L.DESIGN_FONT_BODY, "body", "fontBody")
            stack:Add(UI.CreateLabel(f, L.DESIGN_FONT_NOTE, { size = 11, color = "textDim" }), { height = 30, gap = 6 })
            stack:Add(UI.CreateButton(f, L.DESIGN_RELOAD, 220, 24, function() G.ReloadUI() end, "primary"), { height = 24, gap = 8 })

            f.fwRefreshers = refreshers
            FW:On("DESIGN_CHANGED", function() for _, r in ipairs(refreshers) do r() end end, f)
            return f
        end,
        refresh = function(frame)
            if frame and frame.fwRefreshers then for _, r in ipairs(frame.fwRefreshers) do r() end end
        end,
    })
end
