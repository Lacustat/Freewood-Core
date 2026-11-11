-- Test Gesamtdesign "Legion der Affen": Palette, Umschalten, Layout, Dropdown (texlua tests/theme_test.lua)
local fails, n = 0, 0
local function eq(a, b, m) n = n + 1; if a ~= b then fails = fails + 1; print("FEHLER " .. m, a, b) end end

local function Obj()
    local o = { shown = true, points = {}, n = 0 }
    local mt = {}
    mt.__index = function(t, k)
        if k == "SetColorTexture" or k == "SetTextColor" then
            return function(self, ...) self.color = { ... } end
        elseif k == "Show" then return function(self) self.shown = true end
        elseif k == "Hide" then return function(self) self.shown = false end
        elseif k == "ClearAllPoints" then return function(self) self.points = {} end
        elseif k == "SetPoint" then return function(self, ...) self.points[#self.points + 1] = { ... } end
        elseif k == "SetHeight" then return function(self, h) self.height = h end
        elseif k == "SetTexture" then return function(self, p) self.tex = p end
        elseif k == "SetValue" then return function(self, v) self.value = v end
        elseif k == "CreateTexture" then return function() return Obj() end
        elseif k == "SetSize" or k == "SetAllPoints" or k == "SetTexCoord" or k == "SetScale" or k == "SetWidth" then return function() end
        end
        return nil
    end
    return setmetatable(o, mt)
end

local window = Obj()
for _, k in ipairs({ "Bg", "BorderTop", "BorderBottom", "BorderLeft", "BorderRight", "TabBar", "Footer", "Content", "resizeGrip" }) do window[k] = Obj() end
window.Header = Obj()
for _, k in ipairs({ "Bg", "Accent", "Logo", "Title", "Subtitle" }) do window.Header[k] = Obj() end
local sizeSet
local scaleCalls = {}
window.SetSize = function(_, w, h) sizeSet = { w, h } end

_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1000 end }
local handlers = {}
local tabs = { { id = "overview", label = "Overview", hidden = false }, { id = "x", label = "X", hidden = true } }
local dd = Obj()
local ddOpts
local FW
local UI
UI = {
    window = window, tracked = {}, fixedSize = nil,
    closeButton = Obj(), scaleText = Obj(), scaleSlider = Obj(),
    Color = function() return 1, 1, 1, 1 end,
    CreateDropdown = function(_, _, _, o) ddOpts = o; return dd end,
    GetTabList = function() return tabs end,
    GetActiveTab = function() return "overview" end,
    GetScale = function() return 1 end,
    SetScale = function(_, s) scaleCalls[#scaleCalls + 1] = s end,
    ApplySize = function(self) if self.fixedSize then sizeSet = self.fixedSize end end,
    SelectTab = function(_, id) UI.selected = id end,
}
FW = { UI = UI, settings = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    On = function(_, e, f) handlers[e] = handlers[e] or {}; table.insert(handlers[e], f) end,
    Fire = function(_, e, ...) for _, f in ipairs(handlers[e] or {}) do f(...) end end }
UI.hexDefault = { bgDeep = "0c0e14", bg = "0f131f", panel = "141824", card = "1a2030", hover = "242b40", gold = "c89b3c", goldLight = "f0bf5c", bronze = "9d7826", text = "e6e2d6", textDim = "9a978c", danger = "e0645a", success = "6cc070" }
UI.hex = {}
for k, v in pairs(UI.hexDefault) do UI.hex[k] = v end
UI.ResetColorCache = function() end
UI.fontOverride = {}
UI.RegisterSettingsSection = nil
_G.CreateFrame = function() return Obj() end
window.CreateTexture = function() return Obj() end

assert(loadfile("UI/Design.lua"))("Freewood-Core", FW)
assert(loadfile("UI/ThemeLegion.lua"))("Freewood-Core", FW)
local D = FW.Design

eq(D.GetTheme(), "default", "Standard ist default")
D.SetTheme("legion")
eq(D.GetTheme(), "legion", "Design gesetzt")
eq(UI.hex.text, "1a1208", "Palette: dunkler Text")
eq(UI.hex.bg, "e8d9b0", "Palette: helles Pergament")
eq(UI.fixedSize ~= nil and UI.fixedSize[1], 1713, "feste Breite")
eq(sizeSet[2], 1142, "feste Hoehe")
eq(window.Bg.shown, false, "alter Hintergrund aus")
eq(window.TabBar.shown, false, "Reiterleiste aus")
eq(window.resizeGrip.shown, false, "Ziehgriff aus")
eq(window.Header.Title.shown, false, "Titel aus")
eq(#scaleCalls, 1, "Skalierung verkleinert (Bildschirm 1000 hoch)")
eq(scaleCalls[1] <= 0.85, true, "Skalierung passt zur Bildschirmhoehe")
eq(dd.value, "overview", "Dropdown zeigt aktiven Reiter")

-- Dropdown: versteckte Reiter fehlen, Auswahl schaltet um
local opts = ddOpts.getOptions()
eq(#opts, 1, "versteckter Reiter nicht in der Liste")
eq(opts[1].value, "overview", "Reiter in der Liste")
ddOpts.onChange("overview")
eq(UI.selected, "overview", "Auswahl schaltet Reiter")
FW:Fire("UI_TAB_SELECTED", "x")
eq(dd.value, "x", "Dropdown folgt dem Reiterwechsel")

-- zurueck
D.SetTheme("default")
eq(UI.hex.text, "e6e2d6", "Palette zurueck")
eq(UI.fixedSize, nil, "feste Groesse aus")
eq(window.Bg.shown, true, "alter Hintergrund wieder da")
eq(window.TabBar.shown, true, "Reiterleiste wieder da")
eq(window.Header.height, 48, "Kopfhoehe zurueck")
eq(dd.shown, false, "Dropdown aus")

D.SetTheme("unsinn")
eq(D.GetTheme(), "default", "unbekanntes Design faellt auf default")

print(string.format("theme_test: %d Pruefungen, %d Fehler", n, fails))
os.exit(fails == 0 and 0 or 1)
