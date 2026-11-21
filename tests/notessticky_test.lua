-- Test: UI/NotesSticky.lua (Zettel) mit einfachen Ersatz-Bausteinen (Ablauf, keine Darstellung) -- texlua tests/notessticky_test.lua
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
UI.CreateSlider = function(_, _, opts)
    local s = Widget()
    s.opts = opts
    s.Refresh = function(self) self.value = opts.get() if self.onText then self.onText(self.value) end end
    return s
end
UI.CreateCheckbox = function(_, _, get, set)
    local c = Widget()
    c.get, c.set = get, set
    c.Refresh = function() end
    c.scripts.OnClick = function() set(not get()) end
    return c
end
local events = {}
local codexShown
local FW = { db = {}, settings = {}, UI = UI, L = setmetatable({}, { __index = function(_, k) return k end }),
    Codex = { ShowEntry = function(k, id) codexShown = k .. ":" .. id return true end, SearchEntries = function() return {} end } }
function FW:RegisterEvent(ev, fn) events[ev] = events[ev] or {} table.insert(events[ev], fn) return true end
local function Fire(ev) for _, fn in ipairs(events[ev] or {}) do fn() end end
_G.Freewood = FW
local picked
_G.ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) picked = info end, GetColorRGB = function() return 0.1, 0.2, 0.3 end }
assert(loadfile("Core/Notes.lua"))("Freewood-Core", {})
assert(loadfile("UI/NotesWindow.lua"))("Freewood-Core", {})
assert(loadfile("UI/NotesSticky.lua"))("Freewood-Core", {})
local N, S, W = FW.Notes, FW.Notes.Sticky, FW.Notes.Window
assert(S and S.Sync, "Zettel-Modul geladen")
local me = N.CharKey()
local n = N.Add(me, "Einkauf")
N.SetText(me, n.id, "Leinenstoff |cffb48cff|Hfwcodex:units:3067|h[Pyall]|h|r")
N.TodoAdd(me, "Pyall besuchen")
-- Anmelden ohne Zettel: nichts angelegt
Fire("PLAYER_LOGIN")
assert(next(S.frames) == nil)
-- Anheften ueber den Knopf im Notizblock
N.Toggle()
W.pinBtn:Click()
local f = S.frames["n" .. n.id]
assert(f and f:IsShown(), "Zettel sichtbar")
assert(f.body.text:find("Pyall", 1, true), "Text auf dem Zettel")
assert(W.pinBtn.text == "NOTES_UNPIN", "Knopf zeigt Loesen")
-- Live-Aktualisierung
N.SetText(me, n.id, "geaendert")
assert(f.body.text == "geaendert", "Zettel folgt der Notiz")
-- Link-Klick auf dem Zettel oeffnet den Codex
f.scroll.child.scripts.OnHyperlinkClick(f.scroll.child, "fwcodex:units:3067", "[Pyall]", "LeftButton")
assert(codexShown == "units:3067")
-- ToDo-Zettel: Abhaken direkt auf dem Zettel
W.view.tab = "todo" N.Refresh()
W.tPinBtn:Click()
local t = S.frames.todo
assert(t and t:IsShown() and t.rows[1].text.text == "Pyall besuchen", "ToDo-Zettel mit offenem Eintrag")
t.rows[1].check:Click()
assert(#N.TodoOpen(me) == 0 and #N.TodoDone(me) == 1, "abgehakt")
assert(t.rows[1].text.text == "STICKY_TODO_NONE", "Zettel zeigt: alles erledigt")
-- Schloss
t.lock:Click()
assert(t.pin.locked and not t.grip.shown, "gesperrt: kein Groessengriff")
t.lock:Click()
assert(not t.pin.locked and t.grip.shown)
-- Gestalten: Vorlage, Farbwaehler, Regler
f.gear:Click()
local st, pin = S.styleFrame, f.pin
assert(st and st:IsShown() and st.pin == pin, "Gestalten offen fuer diesen Zettel")
st.swatches[3]:Click()
assert(pin.r == S.PRESETS[3][1] and pin.tb == S.PRESETS[3][6], "Vorlage Blau")
st.bgBtn:Click()
assert(picked and picked.r == pin.r, "Farbwaehler mit aktueller Farbe")
picked.swatchFunc()
assert(pin.r == 0.1 and pin.g == 0.2 and pin.b == 0.3, "freie Hintergrundfarbe")
picked.cancelFunc()
assert(pin.r == S.PRESETS[3][1], "Abbrechen stellt zurueck")
st.fgBtn:Click() picked.swatchFunc()
assert(pin.tr == 0.1, "freie Schriftfarbe")
st.alpha.opts.set(40)
assert(pin.a == 0.4, "Deckkraft")
st.size.opts.set(16)
assert(pin.size == 16, "Schriftgroesse")
st.combat:Click()
assert(N.HideInCombat() == true, "Kampf-Einstellung im Gestalten-Fenster")
N.SetHideInCombat(false)
f.gear:Click()
assert(not st:IsShown(), "Zahnrad schliesst wieder")
-- Kampf: Standard sichtbar
S.SetCombat(true)
assert(f:IsShown(), "im Kampf sichtbar (Standard)")
N.SetHideInCombat(true)
assert(not f:IsShown() and not t:IsShown(), "im Kampf ausgeblendet")
Fire("PLAYER_REGEN_ENABLED")
assert(f:IsShown(), "nach dem Kampf wieder da")
N.SetHideInCombat(false)
-- Notizblock vom Zettel aus oeffnen
W.view.tab = "todo"
f.edit:Click()
assert(W.view.tab == "notes" and N.Data().cur == n.id, "Notizblock zeigt die Notiz")
-- Loesen mit x
f.close:Click()
assert(not f:IsShown() and not N.IsPinned(n.id), "geloest, Notiz bleibt")
assert(N.Find(me, n.id), "Notiz noch da")
-- Loeschen entfernt den ToDo-Zettel nicht, aber Notiz loeschen entfernt ihren Zettel
N.Pin(n.id)
assert(S.frames["n" .. n.id]:IsShown())
N.Delete(me, n.id)
assert(not S.frames["n" .. n.id]:IsShown(), "geloeschte Notiz: Zettel weg")
-- Neuanmeldung: Zettel kommen wieder
t:Hide()
Fire("PLAYER_LOGIN")
assert(t:IsShown(), "nach Neuanmeldung wieder da")
print("notessticky_test OK")
