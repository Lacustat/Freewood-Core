-- Test Holzknoepfe und Holz-Rollbalken (texlua tests/legionkit_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

local function Obj(parent)
    local o = { shown = true, w = 100, h = 26, scripts = {}, parent = parent, alpha = 1 }
    return setmetatable(o, { __index = function(t, k)
        if k == "Show" then return function(self) self.shown = true end
        elseif k == "Hide" then return function(self) self.shown = false end
        elseif k == "SetShown" then return function(self, v) self.shown = v and true or false end
        elseif k == "IsShown" then return function(self) return self.shown end
        elseif k == "SetSize" then return function(self, w, h) self.w, self.h = w, h end
        elseif k == "SetWidth" then return function(self, w) self.w = w end
        elseif k == "SetHeight" then return function(self, h) self.h = h end
        elseif k == "GetWidth" then return function(self) return self.w end
        elseif k == "GetHeight" then return function(self) return self.h end
        elseif k == "GetParent" then return function(self) return self.parent end
        elseif k == "SetAlpha" then return function(self, a) self.alpha = a end
        elseif k == "HookScript" then return function(self, e, f) self.scripts[e] = f end
        elseif k == "CreateTexture" then return function(self) return Obj(self) end
        elseif k == "SetTexCoord" then return function(self, l, r, a, b) self.tc = { l, r, a, b } end
        elseif k == "SetTextColor" then return function(self, r, g, b) self.color = { r, g, b } end
        elseif k == "SetStyle" then return function(self, name) self.fwStyleName = name; if self.fwSkinPaint then self.fwSkinPaint(self, false, true, {}) end end
        elseif k == "IsMouseOver" then return function() return false end
        elseif type(k) == "string" and (k:find("^Set") or k:find("^Clear")) then return function() end
        end
        return nil
    end })
end
local function Btn(parent, w, h)
    local b = Obj(parent); b.w, b.h = w, h; b.fwStyleName = "default"
    b.bg = Obj(b); b.label = Obj(b)
    b.fwBorder = { top = Obj(b), bottom = Obj(b), left = Obj(b), right = Obj(b) }
    return b
end

_G.CreateFrame = function(_, _, parent) return Obj(parent) end
_G.Freewood = { UI = {} }
assert(loadfile("UI/LegionKit.lua"))()
local S = Freewood.UI.LegionSkin
local root = Obj()

local big = Btn(root, 160, 30); S.Button(big)
local small = Btn(root, 160, 20); S.Button(small)
local narrow = Btn(root, 50, 30); S.Button(narrow)
eq(big.fwPlankOn, nil, "aus: kein Holzknopf")

S.Apply(true)
eq(big.fwPlankOn, true, "an: grosser Knopf bekommt Holz")
eq(big.bg.shown, false, "Holz: flacher Grund aus")
eq(big.fwBorder.top.shown, false, "Holz: Rand aus")
eq(small.fwPlankOn == true, false, "zu niedrig bleibt flach")
eq(narrow.fwPlankOn == true, false, "zu schmal bleibt flach")
eq(type(big.fwSkinPaint), "function", "Zeichnen gesetzt")
big:SetStyle("default")
eq(big.fwPlank.left.tc[3], 0, "Zustand 1: oben")
big.fwHover = true; big.fwSkinPaint(big, true, true, {})
eq(math.floor(big.fwPlank.left.tc[3] * 1024 + 0.5), 170, "Maus darueber: Zustand 2")
big.fwDown = true; big.fwSkinPaint(big, true, true, {})
eq(math.floor(big.fwPlank.left.tc[3] * 1024 + 0.5), 340, "gedrueckt: Zustand 3")

-- Groesse aendert sich
small.h = 30; small.scripts.OnSizeChanged(small)
eq(small.fwPlankOn, true, "wird nach Vergroessern zum Holzknopf")

-- Fenstermodus
local win = Obj(); win.fwPlankMode = "off"
local inWin = Btn(win, 160, 30); S.Button(inWin)
eq(inWin.fwPlankOn, nil, "Fenster 'off': flach trotz Design")
win.fwPlankMode = nil; S.Refresh()
eq(inWin.fwPlankOn, true, "Fenster folgt dem Design")

S.Apply(false)
eq(big.fwPlankOn, false, "aus: wieder flach")
eq(big.bg.shown, true, "aus: Grund wieder an")
eq(big.fwBorder.top.shown, true, "aus: Rand wieder an")
local forced = Obj(); forced.fwPlankMode = "on"
local fb = Btn(forced, 160, 30); S.Button(fb)
eq(fb.fwPlankOn, true, "Fenster 'on': Holz auch bei ausgeschaltetem Design")

-- Rollbalken
local holder, track, thumb, thumbTex = Obj(root), Obj(), Obj(), Obj()
track.shown = true; holder.UpdateScroll = function() end
S.Scroll(holder, track, thumb, thumbTex)
eq(holder.fwSkinSync ~= nil, true, "Rollbalken meldet sich an")
S.Apply(true)
eq(track.alpha, 0, "Rollbalken: flache Schiene unsichtbar")
eq(thumb.w, 12, "Rollbalken: 12 breit")
eq(thumb ~= nil and holder.fwSkinSync(false), nil, "Sync ohne Fehler")
S.Apply(false)
eq(track.alpha, 1, "Rollbalken: wieder normal")
eq(thumb.w, 6, "Rollbalken: wieder 6 breit")

print(string.format("legionkit_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
