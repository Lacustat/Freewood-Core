-- Test: UI/NotesWindow.lua mit einfachen Ersatz-Bausteinen (Ablauf, keine Darstellung) -- texlua tests/noteswindow_test.lua
local function Obj()
    local o = { scripts = {}, shown = true, text = "", focus = false }
    return setmetatable(o, { __index = function(t, k)
        local v = rawget(t, k)
        if v ~= nil then return v end
        return function() return nil end
    end })
end
local function Widget()
    local o = Obj()
    o.SetScript = function(self, n, fn) self.scripts[n] = fn end
    o.HookScript = function(self, n, fn) self.scripts[n .. "_hook"] = fn end
    o.GetScript = function(self, n) return self.scripts[n] end
    o.Show = function(self) self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
    o.Hide = function(self) local was = self.shown self.shown = false if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
    o.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
    o.IsShown = function(self) return self.shown end
    o.IsVisible = function(self) return self.shown end
    o.SetText = function(self, t) self.text = t or "" if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
    o.GetText = function(self) return self.text end
    o.Insert = function(self, t) self.text = self.text .. t end
    o.SetFocus = function(self) self.focus = true if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
        if self.scripts.OnEditFocusGained_hook then self.scripts.OnEditFocusGained_hook(self) end end
    o.ClearFocus = function(self) self.focus = false end
    o.HasFocus = function(self) return self.focus end
    o.GetWidth = function() return 400 end
    o.GetHeight = function() return 300 end
    o.GetStringHeight = function() return 20 end
    o.GetCenter = function() return 500, 400 end
    o.SetFont = function() return true end
    o.CreateTexture = function() return Widget() end
    o.CreateFontString = function() return Widget() end
    o.Click = function(self) if self.scripts.OnClick then self.scripts.OnClick(self) end end
    return o
end
_G.CreateFrame = function() return Widget() end
_G.UIParent = Widget()
_G.UISpecialFrames = {}
_G.time = function() return 1000 end
_G.UnitName = function() return "Aroki Sturmhuf" end
_G.GetRealmName = function() return "Forever" end
_G.SlashCmdList = {}
_G.C_Timer = { After = function(_, fn) fn() end }
local hooked
_G.ChatEdit_InsertLink = function() end
_G.hooksecurefunc = function(name, fn) hooked = fn end
local UI = {}
UI.Color = function() return 1, 1, 1, 1 end
UI.GetFontPath = function() return "x" end
UI.SetFont = function() end
UI.CreatePanel = function() return Widget() end
UI.CreateLabel = function(_, t) local w = Widget() w.text = t return w end
UI.CreateButton = function(_, text, _, _, fn)
    local b = Widget()
    b.label = Widget()
    b.text = text
    if fn then b.scripts.OnClick = fn end
    b.SetLabel = function(self, t) self.text = t end
    b.SetStyle = function(self, s) self.style = s end
    b.SetButtonEnabled = function(self, on) self.enabled = on end
    return b
end
UI.CreateScrollFrame = function()
    local h = Widget()
    h.child = Widget()
    h.scroll = Widget()
    h.SetContentHeight = function() end
    return h
end
UI.CreateTextArea = function()
    local a = UI.CreateScrollFrame()
    a.edit = Widget()
    a.SetText = function(self, t) self.edit.text = t or "" end
    a.GetText = function(self) return self.edit.text end
    return a
end
UI.CreateDropdown = function(_, _, _, opts)
    local d = UI.CreateButton()
    d.opts = opts
    d.SetValue = function(self, v) self.value = v end
    return d
end
local tabs, sections = {}, {}
function UI:RegisterTab(id, def) tabs[id] = def end
function UI:RegisterSettingsSection(id, def) sections[id] = def end
UI.CreateCheckbox = function(_, t, g, set) local c = Widget() c.get, c.set = g, set c.Refresh = function(self) self.on = g() end return c end
UI.CreateSection = function() local f = Widget() return f, { Add = function() end, Layout = function() end } end
local codexShown
local FW = { db = {}, settings = {}, UI = UI, L = setmetatable({}, { __index = function(_, k) return k end }),
    Codex = { ShowEntry = function(k, id) codexShown = k .. ":" .. id return true end,
        SearchEntries = function(t) return { { kind = "units", id = 3067, name = "Pyall Silentstride" } } end } }
_G.Freewood = FW
assert(loadfile("Core/Notes.lua"))("Freewood-Core", {})
assert(loadfile("UI/NotesWindow.lua"))("Freewood-Core", {})
local N, W = FW.Notes, FW.Notes.Window
assert(W and N.Toggle, "Fenster geladen")
N.Toggle()
local win = _G.FreewoodNotesWindow
assert(win and win:IsShown() and _G.UISpecialFrames[1] == "FreewoodNotesWindow", "offen, ESC schliesst")
-- Neue Notiz, schreiben, speichern
local n = N.Add(N.CharKey(), "Test")
N.Refresh()
W.SaveBody()
local d = N.Data()
assert(d.cur == n.id)
-- Picker fuegt einen Codex-Link ein
local target = Widget()
W.OpenPicker(target)
assert(W.picker:IsShown(), "Suche offen")
-- der erste Treffer per Enter
local searchEdit
for _, v in pairs(W.picker) do end
-- Shift-Klick-Link ins aktive Feld
target:SetFocus()
W.target = target
hooked("|cff1eff00|Hitem:2589|h[Leinenstoff]|h|r")
assert(target.text:find("Leinenstoff", 1, true), "Shift-Klick eingefuegt")
-- Link-Klick oeffnet den Codex
N.OpenLink("fwcodex:units:3067", "[Pyall]", "LeftButton")
assert(codexShown == "units:3067")
-- ToDo
N.TodoAdd(N.CharKey(), "Pyall besuchen")
N.Refresh()
-- anderer Charakter: nur lesen
FW.db.notes["Zweit Charakter - Forever"] = { notes = { { id = 1, title = "fremd", text = "x" } }, todo = {}, seq = 1 }
N.Toggle() N.Toggle()
assert(win:IsShown())
local v = W.view
v.edit = true N.Refresh() W.SaveBody()
v.key = "Zweit Charakter - Forever" N.Refresh()
assert(not v.edit, "fremd: kein Schreiben ohne Bearbeiten")
v.unlock = true v.edit = true N.Refresh()
v.tab = "todo" N.Refresh()
v.key, v.unlock = nil, false
local e = N.TodoAdd(N.CharKey(), "zwei")
N.TodoToggle(N.CharKey(), e.id)
v.doneOpen = true N.Refresh()
v.tab = "notes" v.edit = false N.Refresh()
-- Fenster schliessen speichert ohne Fehler
win:Hide()
assert(not win:IsShown())
-- 0.56.0: Reiter "Notizen" mit eingebautem Notizblock (eigene Ansicht, gleiche Daten)
assert(tabs.notes and tabs.notes.build, "Reiter angemeldet")
local host = tabs.notes.build(Widget())
local T = N.Tab
assert(T.frame and T.Refresh, "eingebaute Instanz")
assert(T.view ~= W.view, "eigene Ansicht")
T.view.tab = "todo"
tabs.notes.onShow()
assert(W.view.tab == "notes", "Fenster unberuehrt")
-- Shift-Klick geht ins aktive Feld des Reiters (Fenster zu)
local t2 = Widget()
t2:SetFocus()
T.target = t2
hooked("|cff1eff00|Hitem:2592|h[Wollstoff]|h|r")
assert(t2.text:find("Wollstoff", 1, true), "Shift-Klick in den Reiter")
-- angeheftete Notiz: Farbpunkt in der Liste
local n2 = N.Add(N.CharKey(), "Zettel")
N.Pin(n2.id)
T.view.tab = "notes"
N.Refresh()
assert(N.IsPinned(n2.id), "angeheftet")
-- Einstellungen im Reiter
assert(sections.notes and sections.notes.module == "notes", "Einstellungen im Reiter Notizen")
local sf = sections.notes.build(Widget())
sf.combat.set(true)
assert(N.HideInCombat() == true, "Im Kampf ausblenden")
sections.notes.refresh(sf)
print("noteswindow_test OK")
