-- Freewood-Core: Holzknoepfe und Holz-Rollbalken fuer das Design "Legion der Affen".
-- Gilt fuer alle Freewood-Module, solange das Gesamtdesign Legion aktiv ist (UI.LegionSkin.Apply(true) aus ThemeLegion).
-- Knopf: Holzplanke mit Seil und Eisenecken, in drei Teilen (links, Mitte gedehnt, rechts) nach Groesse; drei Zustaende
-- (normal / Maus darueber / gedrueckt). Zu kleine Knoepfe bleiben flach. Rollbalken: Schiene und Schieber aus Holz.
-- Umschalten pro Fenster: Frame.fwPlankMode = "on" (immer), "off" (nie) oder nil (folgt dem Gesamtdesign).
-- Bilder: Media/Design/Legion/plank.tga (512x1024) und scrollbar.tga (256x1024).

local FW = _G.Freewood
if not FW or not FW.UI then return end
local UI = FW.UI

local S = { active = false }
UI.LegionSkin = S

local PATH = "Interface\\AddOns\\Freewood-Core\\Media\\Design\\Legion\\"

local buttons = setmetatable({}, { __mode = "k" })
local scrolls = setmetatable({}, { __mode = "k" })

------------------------------------------------------------------------
-- Knoepfe
------------------------------------------------------------------------

-- Plankenbild: 3 Zustaende je 512x170 uebereinander (oben normal, Mitte Maus darueber, unten gedrueckt)
local P_W, P_H = 512, 1024
local PLANK_H = 170
local CAP_PX = 120               -- Seil und Eisenecke links/rechts
local BODY_FRAC = 0.85           -- Anteil der Holzplanke an der Bildhoehe (ohne Seilenden)
local TOP_FRAC = 0.12            -- Abstand der Oberkante der Planke von der Bildoberkante
-- Zwei Formen: "full" = Planke mit Seil und Eisenecken, "slim" = nur Holz mit dem normalen Rand (kleine Knoepfe)
local FULL_H, FULL_W = 22, 78
local SLIM_H, SLIM_W = 18, 28
local SLIM_U0, SLIM_U1 = 0.28, 0.72          -- Holzmitte der Planke (ohne Seile und Ecken)
local SLIM_V0, SLIM_V1 = 22 / PLANK_H, 158 / PLANK_H
local LABEL_INSET = 0.8          -- Anteil der Seilenden-Breite, den der Text freihaelt
local ARROW_SPACE = 14           -- Platz fuer den Pfeil eines Dropdowns

local function Mode(frame)
    local f, n = frame, 0
    while f and n < 12 do
        if f.fwPlankMode then return f.fwPlankMode end
        f = f.GetParent and f:GetParent() or nil
        n = n + 1
    end
    return nil
end

function S.Wants(frame)
    local m = Mode(frame)
    if m == "off" then return false end
    if m == "on" then return true end
    return S.active
end

local function Kind(b)
    if not S.Wants(b) then return nil end
    local h, w = b:GetHeight() or 0, b:GetWidth() or 0
    if b.fwPlankForce == "slim" then      -- z. B. Spaltenkoepfe: immer schlank, auch wenn schmal
        return (h >= 14 and w >= 16) and "slim" or nil
    end
    if h >= FULL_H and w >= FULL_W then return "full" end
    if h >= SLIM_H and w >= SLIM_W then return "slim" end
    return nil
end

local function Row(state)      -- v-Bereich eines Zustands
    local y0 = (state - 1) * PLANK_H
    return y0 / P_H, (y0 + PLANK_H) / P_H
end

local function BuildPlank(b)
    local p = {}
    local function Tex(l, r)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(PATH .. "plank.tga")
        t.u0, t.u1 = l, r
        return t
    end
    p.left, p.mid, p.right = Tex(0, CAP_PX / P_W), Tex(CAP_PX / P_W, 1 - CAP_PX / P_W), Tex(1 - CAP_PX / P_W, 1)
    p.slim = Tex(SLIM_U0, SLIM_U1)
    p.slim.slim = true
    b.fwPlank = p
end

local function AllTex(p) return { p.left, p.mid, p.right, p.slim } end

-- Beschriftung (nur "full"): zwischen die Seilenden zentrieren, zu lange Texte kuerzen statt ueber die Enden zu laufen
local function SaveLabel(b)
    if b.fwLabelSaved then return end
    local l = b.label
    local pts = {}
    if l.GetNumPoints and l.GetPoint then
        for i = 1, l:GetNumPoints() do
            local pt, rel, rpt, x, y = l:GetPoint(i)
            pts[#pts + 1] = { pt, rel, rpt, x, y }
        end
    end
    b.fwLabelSaved = { points = pts, justify = l.GetJustifyH and l:GetJustifyH() or "CENTER" }
    local a = b.arrow
    if a and a.GetPoint then
        local pt, rel, rpt, x, y = a:GetPoint(1)
        b.fwArrowSaved = { pt, rel, rpt, x, y }
    end
end

local function FitLabel(b, cap)
    SaveLabel(b)
    local inset = math.floor(cap * LABEL_INSET + 0.5)
    local right = inset
    local l = b.label
    l:ClearAllPoints()
    if b.arrow then
        right = inset + ARROW_SPACE
        b.arrow:ClearAllPoints()
        b.arrow:SetPoint("RIGHT", b, "RIGHT", -inset, 0)
    end
    l:SetPoint("LEFT", b, "LEFT", inset, 0)
    l:SetPoint("RIGHT", b, "RIGHT", -right, 0)
    l:SetJustifyH("CENTER")
    if l.SetWordWrap then l:SetWordWrap(false) end
    b.fwLabelFit = true
end

local function RestoreLabel(b)
    if not b.fwLabelFit then return end
    b.fwLabelFit = nil
    local sv, l = b.fwLabelSaved, b.label
    if not sv then return end
    l:ClearAllPoints()
    if #sv.points == 0 then
        l:SetPoint("CENTER", b, "CENTER", 0, 0)
    else
        for _, pt in ipairs(sv.points) do l:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
    end
    l:SetJustifyH(sv.justify or "CENTER")
    if l.SetWordWrap then l:SetWordWrap(b.arrow and false or true) end
    local a, as = b.arrow, b.fwArrowSaved
    if a and as then
        a:ClearAllPoints()
        a:SetPoint(as[1], as[2], as[3], as[4], as[5])
    end
end

local function Layout(b)
    local p = b.fwPlank
    if not p then return end
    local h = b:GetHeight() or FULL_H
    if b.fwPlankKind == "slim" then
        p.slim:ClearAllPoints()
        p.slim:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
        p.slim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        return
    end
    local artH = h / BODY_FRAC
    local scale = artH / PLANK_H
    local cap = CAP_PX * scale
    local up = TOP_FRAC * artH
    p.left:ClearAllPoints()
    p.left:SetPoint("TOPLEFT", b, "TOPLEFT", -2, up)
    p.left:SetSize(cap, artH)
    p.right:ClearAllPoints()
    p.right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, up)
    p.right:SetSize(cap, artH)
    p.mid:ClearAllPoints()
    p.mid:SetPoint("TOPLEFT", p.left, "TOPRIGHT", 0, 0)
    p.mid:SetPoint("BOTTOMRIGHT", p.right, "BOTTOMLEFT", 0, 0)
    FitLabel(b, cap)
end

local function Paint(b, hovered, enabled, style)
    local p = b.fwPlank
    if not p or not b.fwPlankOn then return end
    local state = 1
    if enabled and b.fwDown then state = 3
    elseif b.fwStyleName == "primary" or (hovered and enabled) then state = 2 end
    local v0, v1 = Row(state)
    if b.fwPlankKind == "slim" then
        local h = v1 - v0
        p.slim:SetTexCoord(SLIM_U0, SLIM_U1, v0 + SLIM_V0 * h, v0 + SLIM_V1 * h)
    else
        for _, t in ipairs({ p.left, p.mid, p.right }) do
            t:SetTexCoord(t.u0, t.u1, v0, v1)
        end
    end
    b.label:SetTextColor(0.97, 0.92, 0.78, 1)
end

local function Switch(b)
    local kind = Kind(b)
    if kind == b.fwPlankKind then
        if kind then Layout(b) end
        return
    end
    b.fwPlankKind = kind
    b.fwPlankOn = kind and true or false
    local bd = b.fwBorder
    if kind then
        if not b.fwPlank then BuildPlank(b) end
        b.bg:Hide()
        for _, t in ipairs(AllTex(b.fwPlank)) do t:Hide() end
        if kind == "slim" then
            b.fwPlank.slim:Show()
            RestoreLabel(b)
        else
            for _, t in ipairs({ b.fwPlank.left, b.fwPlank.mid, b.fwPlank.right }) do t:Show() end
        end
        -- Rand: bei der schlanken Form bleibt er (Holz mit Rand), bei der vollen Planke sind Seil und Ecken der Rand
        if bd then for _, k in ipairs({ "top", "bottom", "left", "right" }) do bd[k]:SetShown(kind == "slim") end end
        Layout(b)
        b.fwSkinPaint = Paint
    else
        if b.fwPlank then
            for _, t in ipairs(AllTex(b.fwPlank)) do t:Hide() end
        end
        RestoreLabel(b)
        b.bg:Show()
        if bd then for _, k in ipairs({ "top", "bottom", "left", "right" }) do bd[k]:Show() end end
        b.fwSkinPaint = nil
    end
    -- Farben neu setzen (RefreshButton ruft Paint bzw. stellt die Standardfarben her)
    if b.SetStyle then b:SetStyle(b.fwStyleName) end
end

-- Knopf immer als schlanke Planke zeigen (ohne Seil), solange das Holzdesign gilt
function S.ForceSlim(b)
    b.fwPlankForce = "slim"
    if S.Wants(b) or b.fwPlankOn then Switch(b) end
end

function S.Button(b)
    buttons[b] = true
    b:HookScript("OnMouseDown", function(self) self.fwDown = true if self.SetStyle then self:SetStyle(self.fwStyleName) end end)
    b:HookScript("OnMouseUp", function(self) self.fwDown = false if self.SetStyle then self:SetStyle(self.fwStyleName) end end)
    b:HookScript("OnSizeChanged", function(self)
        if S.Wants(self) or self.fwPlankOn then Switch(self) end
    end)
    if S.Wants(b) then Switch(b) end
end

------------------------------------------------------------------------
-- Rollbalken
------------------------------------------------------------------------

local A_W, A_H = 256, 1024
local TRACK_W, TRACK_H, TRACK_CAP = 64, 672, 56
local THUMB_X, THUMB_H, THUMB_STEP, THUMB_CAP = 64, 168, 170, 40
local BAR_W = 12

local function Parts(parent, layer, x0, x1, y0, h, cap)
    -- senkrechte 3-Teilung: oben, Mitte gedehnt, unten
    local function T(v0, v1)
        local t = parent:CreateTexture(nil, layer)
        t:SetTexture(PATH .. "scrollbar.tga")
        t:SetTexCoord(x0 / A_W, x1 / A_W, (y0 + v0) / A_H, (y0 + v1) / A_H)
        return t
    end
    return { top = T(0, cap), mid = T(cap, h - cap), bottom = T(h - cap, h) }
end

local function Stretch(parts, frame, width, h, cap)
    local capU = cap * (width / 64)
    parts.top:ClearAllPoints()
    parts.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    parts.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    parts.top:SetHeight(capU)
    parts.bottom:ClearAllPoints()
    parts.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    parts.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    parts.bottom:SetHeight(capU)
    parts.mid:ClearAllPoints()
    parts.mid:SetPoint("TOPLEFT", parts.top, "BOTTOMLEFT", 0, 0)
    parts.mid:SetPoint("BOTTOMRIGHT", parts.bottom, "TOPRIGHT", 0, 0)
end

local function ThumbState(sc, state)
    local y0 = (state - 1) * THUMB_STEP
    for _, k in ipairs({ "top", "mid", "bottom" }) do
        local t = sc.thumbParts[k]
        local l, r, t0, t1 = t.l, t.r, t.v0, t.v1
        t:SetTexCoord(l / A_W, r / A_W, (y0 + t0) / A_H, (y0 + t1) / A_H)
    end
end

local function BuildScroll(sc)
    local holder, thumb = sc.holder, sc.thumb
    -- Schiene: eigener Rahmen, folgt dem Ein-/Ausblenden der Schiene (fwSkinSync)
    local tf = CreateFrame("Frame", nil, holder)
    tf:SetWidth(BAR_W)
    tf:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    tf:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    sc.trackFrame = tf
    sc.trackParts = Parts(tf, "BACKGROUND", 0, TRACK_W, 0, TRACK_H, TRACK_CAP)
    Stretch(sc.trackParts, tf, BAR_W, TRACK_H, TRACK_CAP)
    -- Schieber
    sc.thumbParts = {}
    local cap, h = THUMB_CAP, THUMB_H
    local defs = { top = { 0, cap }, mid = { cap, h - cap }, bottom = { h - cap, h } }
    for k, v in pairs(defs) do
        local t = thumb:CreateTexture(nil, "OVERLAY")
        t:SetTexture(PATH .. "scrollbar.tga")
        t.l, t.r, t.v0, t.v1 = THUMB_X, THUMB_X + 64, v[1], v[2]
        sc.thumbParts[k] = t
    end
    Stretch(sc.thumbParts, thumb, BAR_W, THUMB_H, THUMB_CAP)
    ThumbState(sc, 1)
    thumb:HookScript("OnEnter", function() if sc.on then ThumbState(sc, 2) end end)
    thumb:HookScript("OnLeave", function() if sc.on then ThumbState(sc, 1) end end)
    thumb:HookScript("OnMouseDown", function() if sc.on then ThumbState(sc, 3) end end)
    thumb:HookScript("OnMouseUp", function() if sc.on then ThumbState(sc, thumb:IsMouseOver() and 2 or 1) end end)
end

local function ScrollSwitch(sc)
    local on = S.Wants(sc.holder)
    if on == (sc.on and true or false) then return end
    sc.on = on
    if on and not sc.trackFrame then BuildScroll(sc) end
    sc.track:SetAlpha(on and 0 or 1)
    sc.thumbTex:SetAlpha(on and 0 or 1)
    sc.track:SetWidth(on and BAR_W or 6)
    sc.thumb:SetWidth(on and BAR_W or 6)
    if sc.trackFrame then
        sc.trackFrame:SetShown(on and sc.track:IsShown())
        for _, t in pairs(sc.thumbParts) do t:SetShown(on) end
    end
    if sc.holder.UpdateScroll then sc.holder.UpdateScroll() end
end

function S.Scroll(holder, track, thumb, thumbTex)
    local sc = { holder = holder, track = track, thumb = thumb, thumbTex = thumbTex }
    scrolls[holder] = sc
    holder.fwSkinSync = function(show)
        if sc.trackFrame then sc.trackFrame:SetShown(sc.on and show and true or false) end
    end
    if S.Wants(holder) then ScrollSwitch(sc) end
end

------------------------------------------------------------------------
-- Ein-/Ausschalten
------------------------------------------------------------------------

function S.Refresh()
    for b in pairs(buttons) do Switch(b) end
    for _, sc in pairs(scrolls) do ScrollSwitch(sc) end
end

function S.Apply(on)
    S.active = on and true or false
    S.Refresh()
end
