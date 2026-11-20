-- Test: Modul-Einstellungen (Zahnrad im Modul-Reiter, seit 0.54.0)   texlua tests/modset_test.lua
local function noop() end
local M = {}
M.__index = function(t, k) if M[k] then return M[k] end if type(k) == "string" and k:match("^%u") then return noop end end
function M.SetSize(f, w, h) f.w, f.h = w, h end
function M.SetWidth(f, w) f.w = w end
function M.SetHeight(f, h) f.h = h end
function M.GetWidth(f) return f.w or 900 end
function M.GetHeight(f) return f.h or 20 end
function M.Show(f) f.shown = true end
function M.Hide(f) f.shown = false end
function M.IsShown(f) return f.shown == true end
function M.SetScript(f, k, fn) f.scripts = f.scripts or {} f.scripts[k] = fn end
function M.GetScript(f, k) return f.scripts and f.scripts[k] end
function M.GetFrameLevel() return 3 end
function M.SetPoint(f, ...) f.points = f.points or {} f.points[#f.points + 1] = { ... } end
function M.ClearAllPoints(f) f.points = {} end
function M.SetParent(f, p) f.parent = p end
function M.GetParent(f) return f.parent end
function M.CreateTexture() return setmetatable({}, M) end
function M.CreateFontString() return setmetatable({}, M) end
function M.SetText(f, t) f.text = t end
function M.GetText(f) return f.text end
function M.GetStringWidth(f) return #(f.text or "") * 6 end
_G.CreateFrame = function() return setmetatable({}, M) end
_G.GetBuildInfo = function() return "1.0", "1", "x", 16001 end

local events = {}
local FW = { L = setmetatable({}, { __index = function(_, k) return k end }), settings = {},
    Util = { Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end } }
function FW:On(ev, fn) events[ev] = events[ev] or {} table.insert(events[ev], fn) end
function FW:Fire(ev, ...) for _, fn in ipairs(events[ev] or {}) do fn(...) end end
function FW:Print() end
local UI = {}
FW.UI = UI
local tabs, active, selected = {}, nil, {}
local tabFrames = { loot = setmetatable({ shown = true }, M) }
function UI:RegisterTab(id, def) tabs[id] = def end
function UI:GetActiveTab() return active end
function UI:SelectTab(id) active = id selected[#selected + 1] = id if tabFrames[id] then tabFrames[id]:Show() end FW:Fire("UI_TAB_SELECTED", id) end
function UI:GetTabFrame(id) return tabFrames[id] end
local known = { overview = true, loot = true, settings = true }
function UI:HasTab(id) return known[id] == true end
function UI:GetTabLabel(id) return id == "loot" and "Beute" or id end
function UI:GetTabList() return { { id = "overview", label = "Übersicht" }, { id = "loot", label = "Beute" }, { id = "settings", label = "Einstellungen" } } end
UI.window = setmetatable({ Content = setmetatable({}, M) }, M)
function UI.CreateLabel(p, t) local l = setmetatable({}, M) l.text = t return l end
function UI.CreateDivider() return setmetatable({}, M) end
function UI.AttachTooltip() end
function UI.Color() return 1, 1, 1, 1 end
function UI.CreateButton(p, t, w, h, fn, style)
    local b = setmetatable({ w = w, h = h, onClick = fn, style = style or "default" }, M)
    b.label = UI.CreateLabel(b, t)
    function b:SetLabel(x) self.label.text = x end
    function b:SetStyle(x) self.style = x end
    return b
end
function UI.CreateScrollFrame()
    local h = setmetatable({}, M)
    h.child = setmetatable({}, M)
    function h:SetContentHeight(v) self.contentH = v end
    return h
end
function UI.CreateCheckbox() return setmetatable({}, M) end
function UI.CreateStack(parent, opts)
    local st = { items = {}, y = opts and opts.y or 0 }
    function st:Add(w, o) self.items[#self.items + 1] = { w = w, height = o and o.height } return w end
    function st:Layout() local h = 0 for _, it in ipairs(self.items) do h = h + (it.height or 20) end if self.onHeight then self.onHeight(h) end return h end
    function st:Width() return 400 end
    return st
end
function UI:OnScaleChanged() end
function UI:GetScale() return 1 end

assert(loadfile("UI/Tabs.lua"))("Freewood-Core", FW)

-- Abschnitte anmelden: einer im Modul, einer zentral
local built = {}
UI:RegisterSettingsSection("loot", { module = "loot", order = 110, build = function(parent)
    built[#built + 1] = parent
    local f, stack = UI.CreateSection(parent, "Beute")
    stack:Add(setmetatable({}, M), { height = 40 })
    stack:Layout()
    return f
end, refresh = function(f) f.refreshed = (f.refreshed or 0) + 1 end })
UI:RegisterSettingsSection("tooltips", { category = "tooltips", order = 50, build = function(parent)
    local f = UI.CreateSection(parent, "Tooltips") return f end })

assert(#built == 0, "Modul-Abschnitt wird erst beim Oeffnen gebaut")
assert(UI:HasModuleSettings("loot") and not UI:HasModuleSettings("overview"), "HasModuleSettings")
local mt = UI:ModuleSettingsTabs()
assert(#mt == 1 and mt[1].id == "loot" and mt[1].label == "Beute", "Liste der Module")

-- Zahnrad nur bei Reitern mit Einstellungen
local gear = UI.moduleGear
assert(gear and not gear.shown, "Zahnrad zuerst verborgen")
UI:SelectTab("overview")
assert(not gear.shown, "Uebersicht: kein Zahnrad")
UI:SelectTab("loot")
assert(gear.shown and gear.style == "default", "Beute: Zahnrad")
assert(gear.label.text:find("MODSET_BUTTON", 1, true), "Beschriftung nach Sprache")
assert(gear.points[#gear.points][1] == "TOPRIGHT" and gear.points[#gear.points][3] == "TOPRIGHT", "auf Hoehe der Ueberschrift")

-- Oeffnen
gear.onClick(gear)
local v = UI.moduleView
assert(v and v.frame.shown and v.tab == "loot", "Ansicht offen")
assert(#built == 1 and built[1] == v.body, "im Modul gebaut")
assert(not tabFrames.loot.shown, "Reiter-Inhalt verborgen")
assert(v.title.text == "MODSET_TITLE" or v.title.text:find("Beute", 1, true), "Titel")
assert(gear.style == "primary", "Zahnrad aktiv")
assert(UI:IsModuleSettingsShown("loot"))
local sec
for _, def in ipairs(UI:ModuleSections("loot")) do sec = def end
assert(sec.frame.refreshed == 2 and sec.frame.shown, "aufgefrischt und sichtbar")
assert(v.scroll.contentH and v.scroll.contentH > 20, "Hoehe gesetzt")

-- Zahnrad erneut = zurueck
gear.onClick(gear)
assert(not v.frame.shown and tabFrames.loot.shown and selected[#selected] == "loot", "zurueck zum Reiter")
assert(gear.style == "default")
-- Zurueck-Knopf
UI:ShowModuleSettings("loot")
v.back.onClick(v.back)
assert(not v.frame.shown, "Zurueck-Knopf")
-- Reiterwechsel schliesst die Ansicht
UI:ShowModuleSettings("loot")
UI:SelectTab("overview")
assert(not v.frame.shown and not gear.shown, "Reiterwechsel")
-- aus einem anderen Reiter direkt oeffnen (Knoepfe unter Einstellungen > Module)
UI:ShowModuleSettings("loot")
assert(active == "loot" and v.frame.shown and not tabFrames.loot.shown, "springt in den Reiter")
assert(sec.frame.refreshed == 5 and #built == 1, "nur einmal gebaut")
assert(UI:ShowModuleSettings("overview") == false, "ohne Einstellungen: nichts")

-- zentraler Reiter: Modul-Abschnitt nicht drin, Knoepfe zum Modul
local sf = tabs.settings.build(setmetatable({}, M))
assert(#built == 1, "nicht im zentralen Reiter gebaut")
local lf = UI.moduleLinks
assert(lf, "Abschnitt Module gebaut")
sf.Refresh()
assert(lf.buttons[1] and lf.buttons[1].shown and lf.buttons[1].label.text == "Beute", "Knopf zum Modul")
UI:SelectTab("settings")
lf.buttons[1].onClick(lf.buttons[1])
assert(active == "loot" and v.frame.shown, "Knopf oeffnet die Modul-Einstellungen")
-- Rueckfall: Modul ohne Reiter (z. B. Quest-Sortierung ohne Quest-Modul) bleibt im Reiter Einstellungen
local qbuilt
UI:RegisterSettingsSection("questsort", { module = "quest", category = "quest", build = function(p) qbuilt = p return UI.CreateSection(p, "Q") end })
assert(not UI:HasModuleSettings("quest"), "ohne Reiter: keine Modul-Einstellungen")
assert(UI.SettingsModuleOf({ module = "quest" }) == nil and UI.SettingsModuleOf({ module = "loot" }) == "loot")
assert(qbuilt ~= nil and qbuilt ~= v.body, "im Reiter Einstellungen gebaut")
known.quest = true
assert(UI:HasModuleSettings("quest"), "Reiter da: im Modul")
UI:ShowModuleSettings("quest")
local qdef
for _, d in ipairs(UI:ModuleSections("quest")) do qdef = d end
assert(qdef.frame.parent == v.body, "umgehaengt")
print("modset_test: ok")
