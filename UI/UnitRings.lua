-- Freewood-Core: Ring-Anzeige fuer Leben und Ressourcen neben dem Charakter (Einstellungen > Interface).
-- Ebenen von aussen nach innen: 1 Mana-Ring (nur Druide in Katzen-/Baerengestalt), 2 Ressourcenring (Mana, Wut, Energie ...),
-- 3 Lebensring, 4 Portrait (runde Maske). Jede Ebene ist ein einzelner Ring mit eigener Dicke, Richtung und eigenem Haken; darueber
-- liegt eine Kontur (Bild frame_<farbe>.tga: gruen=Leben, blau=Mana, rot=Wut, gelb=Energie, weiss=andere).
-- Alles ist standardmaessig AUS. Blizzards Spielerfenster ausblenden (nur Transparenz), Verschieben per Ziehen, Groesse per Regler.
-- Zeichnen (glatter Zeiger, auch bei geheimen Werten): zwei Halbringe (Media\Rings\half<stufe>.tga) werden gedreht und je an einer
-- Haelfte des Rings beschnitten (Frame:SetClipsChildren). Der Drehwinkel kommt aus dem Prozentwert: bei lesbaren Werten gerechnet,
-- bei geheimen Werten (Spieler auf Forever) aus einer Kurve des Spiels (UnitHealthPercent(..., Kurve)); Texture:SetRotation nimmt
-- geheime Werte an. Die Sicht-Probe /fwspin hat das am 9. November bestaetigt.
-- UNGEPRUEFT im Spiel: Live-Werte unter 100 %, Leistungs-Prozentfunktion mit Kurve, Farbkurve fuer das Leben, Richtung je Ring.

local ADDON, FW = ...

local UI = FW.UI
local G = _G

local R = {}
FW.UnitRings = R

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Rings\\"
local FILLK = 0.936          -- Fuellung liegt innerhalb der Kontur: Durchmesser der Fuellung = Ringgroesse * FILLK
local DURATION = 1000          -- Laenge der Pseudo-Abklingzeit in Sekunden; der Prozentwert steckt im "Start"

FW:AddLocale("enUS", {
    RINGS_TITLE = "Unit rings (life and resources)",
    RINGS_NOTE = "Shows your life and your resources as rings next to the character. Layers from the outside in: 1 druid mana (only in cat or bear form), 2 resource (mana, rage, energy ...), 3 life, 4 portrait. Everything is off by default. Drag the rings with the mouse while \"Move\" is on.",
    RINGS_ON = "Show rings",
    RINGS_DMANA = "Layer 1: druid mana ring (only in cat or bear form)",
    RINGS_POWER = "Layer 2: resource ring (mana, rage, energy ...)",
    RINGS_HEALTH = "Layer 3: life ring",
    RINGS_PORTRAIT = "Layer 4: portrait inside the rings",
    RINGS_DMANA_REV = "Druid mana ring counter-clockwise",
    RINGS_POWER_REV = "Resource ring counter-clockwise",
    RINGS_HEALTH_REV = "Life ring counter-clockwise",
    RINGS_HIDEBLIZZ = "Hide Blizzard's player frame",
    RINGS_HIDEFULL = "Only show when not full",
    RINGS_UNLOCK = "Move (drag the rings)",
    RINGS_SIZE = "Size: %d",
    RINGS_DMANA_THICK = "Druid mana ring thickness: %d",
    RINGS_POWER_THICK = "Resource ring thickness: %d",
    RINGS_HEALTH_THICK = "Life ring thickness: %d",
})
FW:AddLocale("deDE", {
    RINGS_TITLE = "Ring-Anzeige (Leben und Ressourcen)",
    RINGS_NOTE = "Zeigt dein Leben und deine Ressourcen als Ringe neben dem Charakter. Ebenen von außen nach innen: 1 Druiden-Mana (nur in Katzen- oder Bärengestalt), 2 Ressource (Mana, Wut, Energie ...), 3 Leben, 4 Porträt. Alles ist standardmäßig aus. Mit \"Verschieben\" kannst du die Ringe mit der Maus ziehen.",
    RINGS_ON = "Ringe anzeigen",
    RINGS_DMANA = "Ebene 1: Druiden-Mana-Ring (nur in Katzen- oder Bärengestalt)",
    RINGS_POWER = "Ebene 2: Ressourcenring (Mana, Wut, Energie ...)",
    RINGS_HEALTH = "Ebene 3: Lebensring",
    RINGS_PORTRAIT = "Ebene 4: Porträt in den Ringen",
    RINGS_DMANA_REV = "Druiden-Mana-Ring gegen den Uhrzeigersinn",
    RINGS_POWER_REV = "Ressourcenring gegen den Uhrzeigersinn",
    RINGS_HEALTH_REV = "Lebensring gegen den Uhrzeigersinn",
    RINGS_HIDEBLIZZ = "Blizzards Spielerfenster ausblenden",
    RINGS_HIDEFULL = "Nur anzeigen, wenn nicht voll",
    RINGS_UNLOCK = "Verschieben (Ringe ziehen)",
    RINGS_SIZE = "Größe: %d",
    RINGS_DMANA_THICK = "Dicke Druiden-Mana-Ring: %d",
    RINGS_POWER_THICK = "Dicke Ressourcenring: %d",
    RINGS_HEALTH_THICK = "Dicke Lebensring: %d",
})

local DEFAULTS = {
    on = false, dmana = false, power = false, health = false, portrait = false, hideBlizz = false, hideFull = false,
    unlock = false, size = 120, x = 160, y = 0,
    dmanaThick = 3, powerThick = 3, healthThick = 3,   -- Dicke je Ring, Stufe 1 (duenn) bis 6 (dick); 3 = bisheriges Aussehen
    dmanaRev = false, powerRev = false, healthRev = false,   -- true = gegen den Uhrzeigersinn
}

-- Ebenen von aussen nach innen
R.ORDER = { "dmana", "power", "health" }

function R.Opts()
    local s = FW.settings
    if type(s) ~= "table" then return DEFAULTS end
    if type(s.unitRings) ~= "table" then s.unitRings = {} end
    local o = s.unitRings
    for k, v in pairs(DEFAULTS) do
        if o[k] == nil then o[k] = v end
    end
    return o
end

local function Num(v)
    if v == nil then return nil end
    if FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

local function IsSecret(v)
    return FW.Util and FW.Util.IsSecret and FW.Util.IsSecret(v) and true or false
end

-- Anteil 0..1 aus aktuellem und maximalem Wert
function R.Fraction(cur, max)
    cur, max = Num(cur), Num(max)
    if not cur or not max or max <= 0 then return 0 end
    local f = cur / max
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    return f
end

local function Lerp(a, b, t) return a + (b - a) * t end

-- gruen -> orange -> rot
function R.HealthColor(frac)
    if frac >= 0.5 then
        local t = (1 - frac) / 0.5
        return Lerp(0.2, 1.0, t), Lerp(0.85, 0.55, t), Lerp(0.2, 0.1, t)
    end
    local t = (0.5 - frac) / 0.5
    return Lerp(1.0, 0.9, t), Lerp(0.55, 0.1, t), Lerp(0.1, 0.1, t)
end

local POWER_COLORS = {
    [0] = { 0.2, 0.45, 1.0 },   -- Mana
    [1] = { 1.0, 0.15, 0.15 },  -- Wut
    [2] = { 1.0, 0.5, 0.25 },   -- Fokus
    [3] = { 1.0, 0.95, 0.2 },   -- Energie
    [6] = { 0.0, 0.8, 1.0 },    -- Runenmacht
}

function R.PowerColor(ptype)
    local c = G.PowerBarColor and ptype ~= nil and G.PowerBarColor[ptype]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    c = POWER_COLORS[ptype or 0] or POWER_COLORS[0]
    return c[1], c[2], c[3]
end

R.LEVELS = 6

function R.Level(v)
    v = math.floor((tonumber(v) or 3) + 0.5)
    if v < 1 then v = 1 elseif v > R.LEVELS then v = R.LEVELS end
    return v
end

-- Dicke eines Rings als Anteil am Radius (aus Media\Rings\Rings.lua)
function R.Thickness(level)
    local t = FW.RingThickness
    return t and t[R.Level(level)] or 0.16
end

---------------------------------------------------------------------
-- Druide und Ebenen
---------------------------------------------------------------------

function R.IsDruid()
    if R.druid == nil then
        local _, token = nil, nil
        if G.UnitClassBase then token = G.UnitClassBase("player")
        elseif G.UnitClass then _, token = G.UnitClass("player") end
        if token == nil then return false end   -- noch nicht bekannt: spaeter nochmal fragen
        R.druid = (token == "DRUID")
    end
    return R.druid
end

-- Druide in Katzen-/Baerengestalt: die Hauptressource ist nicht Mana, das Mana soll trotzdem zu sehen sein
function R.DruidManaActive()
    if not R.IsDruid() then return false end
    local pt = G.UnitPowerType and Num((G.UnitPowerType("player")))
    return pt ~= nil and pt ~= 0
end

-- Eingeschaltete Ebenen von aussen nach innen (die Druiden-Ebene nur fuer Druiden; ihr Platz bleibt auch ausserhalb der Gestalt frei)
function R.Slots(o)
    local list = {}
    for _, key in ipairs(R.ORDER) do
        if o[key] and (key ~= "dmana" or R.IsDruid()) then list[#list + 1] = key end
    end
    return list
end

-- Groessen der Ringe und des Portraits (Pixel). Der aeusserste Ring hat die volle Groesse, jeder naechste liegt innerhalb der
-- Dicke des Vorgaengers (plus kleiner Abstand), das Portrait innerhalb des innersten Rings.
function R.Layout(o)
    local S = o.size or 120
    local lay = { outer = S, diam = {}, slots = R.Slots(o) }
    local d, lastThick = S, 0.16
    for i, key in ipairs(lay.slots) do
        if i > 1 then
            local prev = lay.slots[i - 1]
            d = math.floor(lay.diam[prev] * FILLK * (1 - R.Thickness(o[prev .. "Thick"]) - 0.03) + 0.5)
        end
        lay.diam[key] = d
        lastThick = R.Thickness(o[key .. "Thick"])
    end
    lay.portrait = math.floor(d * FILLK * (1 - lastThick - 0.06) + 0.5)
    return lay
end

---------------------------------------------------------------------
-- Zeichnen
---------------------------------------------------------------------

local function NewRing(parent)
    local ring = {}
    ring.frame = G.CreateFrame("Frame", nil, parent)          -- Behaelter in voller Ringgroesse
    ring.fill = G.CreateFrame("Frame", nil, ring.frame)        -- Fuellung, etwas kleiner (innerhalb der Kontur)
    ring.fill:SetPoint("CENTER", ring.frame, "CENTER", 0, 0)
    ring.track = ring.fill:CreateTexture(nil, "BACKGROUND")    -- dunkler Hintergrundring (der leere Teil)
    ring.track:SetAllPoints(ring.fill)
    ring.track:SetTexture(PATH .. "ring3.tga")
    ring.track:SetVertexColor(0.12, 0.12, 0.12, 0.7)
    -- zwei Haelften: jede in einem Frame, der nur ihre Haelfte des Rings zeigt; das Bild darin (ganzer Ring gross, nur linke Haelfte
    -- gefuellt) wird um den Ringmittelpunkt gedreht
    for _, side in ipairs({ "R", "L" }) do
        local clip = G.CreateFrame("Frame", nil, ring.fill)
        if clip.SetClipsChildren then clip:SetClipsChildren(true) end
        local tex = clip:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(PATH .. "half3.tga")
        tex:SetPoint("CENTER", ring.fill, "CENTER", 0, 0)
        ring["clip" .. side], ring["tex" .. side] = clip, tex
    end
    ring.level = 3
    -- Kontur: eigener Frame ueber der Fuellung
    ring.top = G.CreateFrame("Frame", nil, ring.frame)
    ring.top:SetAllPoints(ring.frame)
    ring.line = ring.top:CreateTexture(nil, "OVERLAY")
    ring.line:SetAllPoints(ring.top)
    ring.line:SetTexture(PATH .. "frame_white.tga")
    return ring
end

-- Ebenen-Reihenfolge der Frames: Kontur ueber der Fuellung
function R.SetFrameLevels(ring, base)
    if not ring.frame.SetFrameLevel then return end
    ring.frame:SetFrameLevel(base)
    ring.fill:SetFrameLevel(base + 1)
    ring.clipR:SetFrameLevel(base + 2)
    ring.clipL:SetFrameLevel(base + 2)
    ring.top:SetFrameLevel(base + 8)
    ring.baseLevel = base
end

-- Kontur-Bild einer Ebene: Leben gruen, Mana blau, Wut rot, Energie gelb; andere Ressourcen: weisse Kontur in der Ressourcenfarbe
function R.LineFor(key, ptype)
    if key == "health" then return PATH .. "frame_green.tga" end
    local t = key == "dmana" and 0 or ptype
    if t == 0 then return PATH .. "frame_blue.tga" end
    if t == 1 then return PATH .. "frame_red.tga" end
    if t == 3 then return PATH .. "frame_yellow.tga" end
    return PATH .. "frame_white.tga", true
end

function R.SetLine(ring, key, ptype)
    local path, tint = R.LineFor(key, ptype)
    local k = path .. (tint and tostring(ptype) or "")
    if ring.lineKey == k then return end
    ring.lineKey = k
    ring.line:SetTexture(path)
    if tint then ring.line:SetVertexColor(R.PowerColor(ptype)) else ring.line:SetVertexColor(1, 1, 1, 1) end
end

-- Rohwerte (aktuell, maximal) einer Ebene
local function RawValues(kind)
    if kind == "health" then
        return G.UnitHealth and G.UnitHealth("player"), G.UnitHealthMax and G.UnitHealthMax("player")
    elseif kind == "dmana" then
        return G.UnitPower and G.UnitPower("player", 0), G.UnitPowerMax and G.UnitPowerMax("player", 0)
    end
    return G.UnitPower and G.UnitPower("player"), G.UnitPowerMax and G.UnitPowerMax("player")
end

-- Anteil lesen: Rueckgabe Anteil, Quelle ("wert" = lesbar, "secret" = geheim, "test")
function R.Read(kind)
    if R.force then return R.force, "test" end
    local cur, max = RawValues(kind)
    if Num(cur) and Num(max) then return R.Fraction(cur, max), "wert" end
    return 0, "secret"
end

---------------------------------------------------------------------
-- Zeiger: zwei gedrehte, halbiert beschnittene Halbringe
---------------------------------------------------------------------

local function Clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

-- Drehwinkel der beiden Haelften fuer einen Anteil (im Uhrzeigersinn gefuellt; Rotation in WoW ist gegen den Uhrzeigersinn positiv,
-- daher negativ). Rechte Haelfte 0..180 Grad, linke 180..360 Grad.
function R.Angles(frac, ccw)
    local a = frac * 360
    local r, l = -math.rad(Clamp(a, 0, 180)), -math.rad(Clamp(a, 180, 360))
    if ccw then return -r, -l end
    return r, l
end

-- Kurven des Spiels: Anteil 0..1 -> Drehwinkel (die Kurve rechnet im Spiel; das Addon sieht nur geheime Werte)
function R.Curves()
    if R.curves ~= nil then return R.curves or nil end
    R.curves = false
    local cu = G.C_CurveUtil
    if not cu or not cu.CreateCurve then return nil end
    local ok, c = pcall(function()
        local pi = math.pi
        local function C(p0, p1, p2)
            local cv = cu.CreateCurve()
            cv:AddPoint(0, p0); cv:AddPoint(0.5, p1); cv:AddPoint(1, p2)
            return cv
        end
        return {
            cw = { R = C(0, -pi, -pi), L = C(-pi, -pi, -2 * pi) },
            ccw = { R = C(0, pi, pi), L = C(pi, pi, 2 * pi) },
        }
    end)
    if ok then R.curves = c end
    return R.curves or nil
end

-- Farbkurve fuers Leben (rot -> orange -> gruen), falls das Spiel Farbkurven kennt
function R.ColorCurve()
    if R.ccurve ~= nil then return R.ccurve or nil end
    R.ccurve = false
    local cu = G.C_CurveUtil
    if not cu or not cu.CreateColorCurve or not G.CreateColor then return nil end
    local ok, c = pcall(function()
        local cv = cu.CreateColorCurve()
        cv:AddPoint(0, G.CreateColor(0.9, 0.1, 0.1, 1))
        cv:AddPoint(0.5, G.CreateColor(1.0, 0.55, 0.1, 1))
        cv:AddPoint(1, G.CreateColor(0.2, 0.85, 0.2, 1))
        return cv
    end)
    if ok then R.ccurve = c end
    return R.ccurve or nil
end

-- geheime Prozentfunktion mit Kurve: Wert (geheim) oder nil
local function PercentWith(kind, curve)
    local fn = kind == "health" and G.UnitHealthPercent or G.UnitPowerPercent
    if not fn or not curve then return nil end
    local ok, v
    if kind == "health" then ok, v = pcall(fn, "player", false, curve)
    else ok, v = pcall(fn, "player", kind == "dmana" and 0 or nil, false, curve) end
    if not ok then return nil end
    return v
end

-- Drehwinkel beider Haelften aus einer Kurve (geheime Werte): rechts, links
function R.SecretAngles(kind, ccw)
    local cs = R.Curves()
    if not cs then return nil end
    local set = ccw and cs.ccw or cs.cw
    local rr = PercentWith(kind, set.R)
    local rl = PercentWith(kind, set.L)
    if rr == nil or rl == nil then return nil end
    return rr, rl
end

-- Farbe des Lebens bei geheimem Wert: r, g, b (koennen geheim sein) oder nil
function R.SecretHealthColor()
    local cc = R.ColorCurve()
    if not cc then return nil end
    local col = PercentWith("health", cc)
    if col == nil then return nil end
    local ok, r, g, b = pcall(function() return col:GetRGB() end)
    if not ok then return nil end
    return r, g, b
end

-- Richtung: im Uhrzeigersinn (Standard) oder dagegen. Gegen den Uhrzeigersinn ist das Spiegelbild: Bilder gespiegelt, Beschnitt-
-- Frames vertauscht (die "rechte" Haelfte sitzt links), Drehung umgekehrt.
function R.SetDirection(ring, ccw)
    ccw = ccw and true or false
    if ring.ccw == ccw then return end
    ring.ccw = ccw
    local right, left = ccw and "TOPLEFT" or "TOPRIGHT", ccw and "TOPRIGHT" or "TOPLEFT"
    ring.clipR:ClearAllPoints(); ring.clipR:SetPoint(right, ring.fill, right, 0, 0)
    ring.clipL:ClearAllPoints(); ring.clipL:SetPoint(left, ring.fill, left, 0, 0)
    local a, b = ccw and 1 or 0, ccw and 0 or 1
    ring.texR:SetTexCoord(a, b, 0, 1)
    ring.texL:SetTexCoord(a, b, 0, 1)
end

-- Dicke eines Rings umstellen: Hintergrund- und Halbring-Bilder tauschen
function R.SetLevel(ring, level)
    level = R.Level(level)
    if ring.level == level then return end
    ring.level = level
    ring.track:SetTexture(PATH .. "ring" .. level .. ".tga")
    ring.texR:SetTexture(PATH .. "half" .. level .. ".tga")
    ring.texL:SetTexture(PATH .. "half" .. level .. ".tga")
end

-- Zeiger setzen: Drehwinkel (normale Zahlen oder geheime Werte) und Farbe
function R.SetSweep(ring, rr, rl, r, g, b)
    ring.texR:SetRotation(rr)
    ring.texL:SetRotation(rl)
    if r ~= nil then
        ring.texR:SetVertexColor(r, g, b, 1)
        ring.texL:SetVertexColor(r, g, b, 1)
    end
end

function R.Build()
    if R.frame then return R.frame end
    local f = G.CreateFrame("Frame", "FreewoodUnitRings", G.UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f.hl = f:CreateTexture(nil, "BACKGROUND")
    f.hl:SetAllPoints(f)
    f.hl:SetColorTexture(1, 1, 1, 0.08)
    f.hl:Hide()
    f.portrait = f:CreateTexture(nil, "ARTWORK")
    f.portrait:Hide()
    if f.CreateMaskTexture and f.portrait.AddMaskTexture then
        local m = f:CreateMaskTexture()
        m:SetTexture(PATH .. "mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.portrait)
        f.portrait:AddMaskTexture(m)
        f.mask = m
    end
    R.rings = {}
    for _, key in ipairs(R.ORDER) do R.rings[key] = NewRing(f) end
    f:SetScript("OnDragStart", function(self) if R.Opts().unlock then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local px, py = G.UIParent:GetCenter()
        if cx and px then
            local o = R.Opts()
            o.x, o.y = math.floor(cx - px + 0.5), math.floor(cy - py + 0.5)
        end
    end)
    f:RegisterForDrag("LeftButton")
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + (dt or 0)
        if acc < 0.05 then return end
        acc = 0
        R.Update()
    end)
    R.frame = f
    return f
end

function R.UpdatePortrait()
    local f = R.frame
    local o = R.Opts()
    if not f or not o.portrait then return end
    if G.SetPortraitTexture then pcall(G.SetPortraitTexture, f.portrait, "player") end
end

function R.ApplyBlizz()
    local pf = G.PlayerFrame
    if not pf or not pf.SetAlpha then return end
    local o = R.Opts()
    if o.on and o.hideBlizz then
        if pf:GetAlpha() ~= 0 then pf:SetAlpha(0) end
        R.blizzHidden = true
    elseif R.blizzHidden then
        pf:SetAlpha(1)
        R.blizzHidden = false
    end
end

-- Groessen, Lage, Sichtbarkeit; bei jeder Einstellungsaenderung
function R.Apply()
    local o = R.Opts()
    if not o.on then
        if R.frame then R.frame:Hide() end
        R.ApplyBlizz()
        return
    end
    local f = R.Build()
    local lay = R.Layout(o)
    f:SetSize(lay.outer, lay.outer)
    f:ClearAllPoints()
    f:SetPoint("CENTER", G.UIParent, "CENTER", o.x or 0, o.y or 0)
    f:EnableMouse(o.unlock and true or false)
    if o.unlock then f.hl:Show() else f.hl:Hide() end

    for _, key in ipairs(R.ORDER) do
        local ring = R.rings[key]
        ring.frame:Hide()
    end
    R.active = lay.slots
    for i, key in ipairs(lay.slots) do
        local ring = R.rings[key]
        local s = lay.diam[key]
        R.SetLevel(ring, o[key .. "Thick"])
        ring.size = s
        ring.fsize = math.floor(s * FILLK + 0.5)
        ring.fill:SetSize(ring.fsize, ring.fsize)
        for _, side in ipairs({ "R", "L" }) do
            ring["clip" .. side]:SetSize(ring.fsize / 2, ring.fsize)
            ring["tex" .. side]:SetSize(ring.fsize, ring.fsize)
        end
        ring.ccw = nil
        R.SetDirection(ring, o[key .. "Rev"])
        ring.frame:SetSize(s, s)
        ring.frame:ClearAllPoints()
        ring.frame:SetPoint("CENTER", f, "CENTER", 0, 0)
        R.SetFrameLevels(ring, (f.GetFrameLevel and f:GetFrameLevel() or 1) + i * 12)
        ring.frame:Show()
    end
    if o.portrait then
        f.portrait:SetSize(lay.portrait, lay.portrait)
        f.portrait:ClearAllPoints()
        f.portrait:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.portrait:Show()
        R.UpdatePortrait()
    else
        f.portrait:Hide()
    end
    f:Show()
    R.ApplyBlizz()
    R.Update()
end

-- Farbe einer Ebene (bei lesbarem Anteil frac)
local function RingColor(key, frac)
    if key == "health" then return R.HealthColor(frac) end
    if key == "dmana" then return R.PowerColor(0) end
    local pt = G.UnitPowerType and Num((G.UnitPowerType("player")))
    return R.PowerColor(pt)
end

function R.Update()
    local o = R.Opts()
    local f = R.frame
    if not o.on or not f then return end
    -- ein Druide wird erst nach dem Anmelden erkannt: dann Ebenen neu aufbauen
    if R.IsDruid() ~= R.layoutDruid then
        R.layoutDruid = R.IsDruid()
        if o.dmana then R.Apply(); return end
    end
    local allFull, any = true, false
    R.src = R.src or {}
    for _, key in ipairs(R.active or {}) do
        local ring = R.rings[key]
        local show = key ~= "dmana" or R.DruidManaActive()
        if not show then
            ring.frame:Hide()
        else
            ring.frame:Show()
            local ccw = o[key .. "Rev"] and true or false
            local frac, src = R.Read(key)
            R.src[key] = src
            local r, g, b = RingColor(key, frac)
            R.SetLine(ring, key, G.UnitPowerType and Num((G.UnitPowerType("player"))))
            R.SetDirection(ring, ccw)
            local rr, rl
            if src == "secret" then
                rr, rl = R.SecretAngles(key, ccw)
                if key == "health" then
                    local sr, sg, sb = R.SecretHealthColor()
                    if sr ~= nil then r, g, b = sr, sg, sb else r, g, b = 0.2, 0.85, 0.2 end
                end
                frac = 0.5   -- Wert unbekannt: gilt als "nicht voll"
                if rr == nil then rr, rl = R.Angles(0, ccw) end   -- keine Kurve: leer
            else
                rr, rl = R.Angles(frac, ccw)
            end
            R.SetSweep(ring, rr, rl, r, g, b)
            any = true
            if frac < 0.999 then allFull = false end
        end
    end
    local full = any and allFull
    if o.hideFull and full and not o.unlock then f:SetAlpha(0) else f:SetAlpha(1) end
    R.ApplyBlizz()
end

-- Fehlersuche: /fwring debug   |   /fwring test 60  (alle Ringe auf 60 % zwingen)   |   /fwring test  (zurueck)
function R.Debug()
    local function S(v) return tostring(v) end
    local function P(t) if FW.Print then FW:Print(t) else print(t) end end
    local o = R.Opts()
    P("Ringe: an=" .. S(o.on) .. " Druide=" .. S(R.IsDruid()) .. " Mana-Ring=" .. S(o.dmana) .. " Ressource=" .. S(o.power) .. " Leben=" .. S(o.health) .. " Groesse=" .. S(o.size))
    local f = R.frame
    if not f then P("kein Frame gebaut (Ringe aus?)"); return end
    P(string.format("Frame: sichtbar=%s alpha=%s Groesse=%s", S(f:IsShown()), S(f:GetAlpha()), S(f:GetWidth())))
    for _, key in ipairs(R.active or {}) do
        local ring = R.rings[key]
        local fr, src = R.Read(key)
        local sr, sl = nil, nil
        if src == "secret" then sr, sl = R.SecretAngles(key, o[key .. "Rev"]) end
        P(string.format("%s: Anteil=%.3f Quelle=%s Stufe=%s Groesse=%s Richtung=%s | Drehwinkel aus Kurve: %s/%s | Klemm-Frame=%s",
            key, fr, S(src), S(ring.level), S(ring.size), o[key .. "Rev"] and "gegen" or "mit", S(sr ~= nil), S(sl ~= nil), S(ring.clipR.SetClipsChildren ~= nil)))
    end
    do
        local fn = G.UnitHealthPercent
        local scale = G.CurveConstants and G.CurveConstants.ScaleTo100
        local ok, v = false, nil
        if fn then ok, v = pcall(fn, "player", false, scale) end
        P("Prozent-Funktion: ok=" .. S(ok) .. " Ergebnis=" .. (IsSecret(v) and "secret" or S(type(v) == "number" and v or type(v))) .. " | Kurven=" .. S(R.Curves() ~= nil) .. " Farbkurve=" .. S(R.ColorCurve() ~= nil))
    end
    P("UnitHealth=" .. (IsSecret(G.UnitHealth and G.UnitHealth("player")) and "secret" or "normal")
        .. " UnitHealthPercent=" .. S(G.UnitHealthPercent ~= nil) .. " CreateMaskTexture=" .. S(f.CreateMaskTexture ~= nil))
end

if G.SlashCmdList then
    G.SLASH_FWRING1 = "/fwring"
    G.SlashCmdList["FWRING"] = function(msg)
        msg = tostring(msg or "")
        local cmd, arg = msg:match("^(%S*)%s*(%S*)")
        if cmd == "test" then
            local v = tonumber(arg)
            R.force = v and math.max(0, math.min(1, v / 100)) or nil
            R.Update()
            if FW.Print then FW:Print(R.force and ("Ring-Test: " .. arg .. " %") or "Ring-Test aus") end
        else
            R.Debug()
        end
    end
end

FW:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    local ok = pcall(R.Apply)
    if not ok and FW.Print and R.Opts().on then FW:Print("Freewood: Ring-Anzeige konnte nicht aufgebaut werden.") end
end)
FW:RegisterEvent("UNIT_PORTRAIT_UPDATE", function(unit)
    if unit == nil or unit == "player" then pcall(R.UpdatePortrait) end
end)
FW:RegisterEvent("UNIT_MODEL_CHANGED", function(unit)
    if unit == nil or unit == "player" then pcall(R.UpdatePortrait) end
end)

---------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("unit-rings", {
        category = "interface",
        order = 20,
        height = 800,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.RINGS_TITLE)
            stack:Add(UI.CreateLabel(f, L.RINGS_NOTE, { size = 11, color = "textDim", justifyV = "TOP" }), { fit = true, gap = 8 })
            local function Check(key, label)
                stack:Add(UI.CreateCheckbox(f, label,
                    function() return R.Opts()[key] == true end,
                    function(v) R.Opts()[key] = v and true or false; pcall(R.Apply) end), { fit = true, gap = 4 })
            end
            Check("on", L.RINGS_ON)
            Check("dmana", L.RINGS_DMANA)
            Check("power", L.RINGS_POWER)
            Check("health", L.RINGS_HEALTH)
            Check("portrait", L.RINGS_PORTRAIT)
            Check("dmanaRev", L.RINGS_DMANA_REV)
            Check("powerRev", L.RINGS_POWER_REV)
            Check("healthRev", L.RINGS_HEALTH_REV)
            Check("hideBlizz", L.RINGS_HIDEBLIZZ)
            Check("hideFull", L.RINGS_HIDEFULL)
            Check("unlock", L.RINGS_UNLOCK)
            local function Slider(key, label, lo, hi, step)
                local lab = UI.CreateLabel(f, "", { size = 12 })
                stack:Add(lab, { height = 16, gap = 8 })
                local sl = UI.CreateSlider(f, 240, {
                    min = lo, max = hi, step = step,
                    get = function() return R.Opts()[key] end,
                    set = function(v) R.Opts()[key] = v; pcall(R.Apply) end,
                })
                sl.onText = function(v) lab:SetText(string.format(label, v)) end
                sl:Refresh()
                stack:Add(sl, { height = 20, gap = 2 })
            end
            Slider("size", L.RINGS_SIZE, 60, 300, 5)
            Slider("dmanaThick", L.RINGS_DMANA_THICK, 1, R.LEVELS, 1)
            Slider("powerThick", L.RINGS_POWER_THICK, 1, R.LEVELS, 1)
            Slider("healthThick", L.RINGS_HEALTH_THICK, 1, R.LEVELS, 1)
            return f
        end,
    })
end
