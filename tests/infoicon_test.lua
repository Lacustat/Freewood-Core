-- Test 0.58.0: Info-Symbol "i" mit Tooltip (UI.CreateInfoIcon) und Abschnitt:AddInfo   texlua tests/infoicon_test.lua
local M = {}
M.__index = function(t, k)
    if M[k] then return M[k] end
    if type(k) == "string" and k:match("^%u") then return function() end end
end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.HookScript(f, k, fn) M.SetScript(f, k, fn) end
function M.CreateTexture(f) local t = setmetatable({}, M) t.SetVertexColor = function(s, r, g, b) s.col = { r, g, b } end
    t.SetTexture = function(s, p) s.tex = p end return t end
function M.SetPoint(f, ...) f.point = { ... } end
_G.CreateFrame = function() return setmetatable({}, M) end
local tip = { lines = {} }
_G.GameTooltip = setmetatable({ SetOwner = function() end, SetText = function(_, t) tip.title = t tip.lines = {} end,
    AddLine = function(_, l) tip.lines[#tip.lines + 1] = l end, Show = function() tip.shown = true end,
    Hide = function() tip.shown = false end }, M)
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }) }
_G.Freewood = FW
local ok, err = pcall(function() assert(loadfile("UI/Kit.lua"))("Freewood-Core", FW) end)
assert(ok, tostring(err))
local UI = FW.UI
assert(UI and UI.CreateInfoIcon, "CreateInfoIcon da")
assert(UI.INFO_ICON:find("Freewood%-Core\\Media\\Info.tga"), "eigene Grafik")
local i = UI.CreateInfoIcon(setmetatable({}, M), "Titel", "Erklaerung")
assert(i.icon.tex == UI.INFO_ICON)
local gold = i.icon.col
i.scripts.OnEnter(i)
assert(tip.shown and tip.title == "Titel" and tip.lines[1] == "Erklaerung", "Tooltip")
assert(i.icon.col ~= gold, "heller beim Drueberfahren")
i.scripts.OnLeave(i)
assert(not tip.shown)
i:SetInfo("Neu", { "a", "b" })
i.scripts.OnEnter(i)
assert(tip.title == "Neu" and #tip.lines == 2, "Text aendern")
print("infoicon_test: ok")
