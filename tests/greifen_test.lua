-- Test der Greifen-Ersetzung mit nachgebauten Rahmen (texlua tests/greifen_test.lua)
local function Proxy()
    local o = {}
    return setmetatable(o, { __index = function(t, k)
        return function(self, ...)
            if k == "GetAtlas" then return rawget(t,"__atlas") end
            if k == "GetRegions" then return unpack(rawget(t,"__regions") or {}) end
            if k == "GetChildren" then return unpack(rawget(t,"__children") or {}) end
            if k == "GetCenter" then return 100, 50 end
            if k == "GetEffectiveScale" then return 1 end
            if k == "IsShown" then return true end
            return Proxy()
        end
    end })
end
local fails=0
local function eq(a,b,m) if a~=b then fails=fails+1 print("FEHLER "..m,a,b) end end
_G.CreateFrame = function() return Proxy() end
_G.UIParent = Proxy()
local tex = Proxy(); tex.__atlas = "UI-HUD-ActionBar-Wyvern-Left"
local tex2 = Proxy(); tex2.__atlas = "UI-HUD-ActionBar-Wyvern-Right"
local fl, fr = Proxy(), Proxy(); fl.__regions = { tex }; fr.__regions = { tex2 }
local root = Proxy(); root.__children = { fl, fr }
_G.MainActionBar = root
local alpha = {}
local hooks = {}
tex.SetAlpha = function(self, a) alpha.l = a end
tex2.SetAlpha = function(self, a) alpha.r = a end
_G.hooksecurefunc = function(t, n, fn) hooks[#hooks+1] = fn end
_G.C_Timer = { After = function(s, f) end }
local ev, handlers, tabs = {}, {}, {}
local UI = setmetatable({ RegisterSettingsSection = function(_, id, def) tabs[id] = def end, CreateSection = function() return Proxy(), { Add = function() end } end },
  { __index = function() return function() return Proxy() end end })
local FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }), RegisterEvent = function(_, e, f) ev[e] = f end, On = function(_, e, f) handlers[e] = f end, Fire = function() end }
assert(loadfile("Media/Greifen/Greifen.lua"))("Freewood-Core", FW)
assert(loadfile("UI/Greifen.lua"))("Freewood-Core", FW)
local Gr = FW.Greifen
eq(Gr.Apply(), true, "Originale gefunden")
eq(alpha.l, 1, "aus: Original sichtbar")
FW.settings.greifen = { enabled = true }
Gr.Apply()
eq(alpha.l, 0, "an: Original links unsichtbar"); eq(alpha.r, 0, "an: rechts unsichtbar")
eq(FW.settings.greifen.right.mirror, true, "rechts gespiegelt (Standard)")
eq(FW.settings.greifen.left.mirror, false, "links normal")
Gr.SetUnlocked(true); Gr.SetUnlocked(false)
FW.settings.greifen.enabled = false
Gr.Apply()
eq(alpha.l, 1, "wieder aus: Original zurueck")
local f = tabs.greifen.build(Proxy())
eq(type(f), "table", "Abschnitt gebaut")
eq(tabs.greifen.category, "interface", "Kategorie")
print(fails == 0 and "OK" or ("FEHLER: "..fails))
