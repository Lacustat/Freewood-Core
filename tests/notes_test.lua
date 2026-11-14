-- Test: Core/Notes.lua (Notizblock, Datenschicht) -- texlua tests/notes_test.lua
local now = 100
_G.time = function() now = now + 1 return now end
local me = "Aroki Sturmhuf"
_G.UnitName = function() return me end
_G.GetRealmName = function() return "Forever" end
_G.SlashCmdList = {}
local shown
local FW = { db = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    Codex = { ShowEntry = function(kind, id) shown = kind .. ":" .. id return true end } }
_G.Freewood = FW
assert(loadfile("Core/Notes.lua"))("Freewood-Core", {})
local N = FW.Notes
local key = N.CharKey()
assert(key == "Aroki Sturmhuf - Forever", key)
-- Notizen
local a = N.Add(nil, "Einkauf")
local b = N.Add(nil, "")
assert(b.title == "NOTES_UNTITLED" and N.Data().notes[1] == b, "neue Notiz oben")
assert(N.SetTitle(nil, b.id, "  Route  ") and b.title == "Route")
assert(not N.SetTitle(nil, b.id, "   "), "leerer Titel")
assert(N.SetText(nil, a.id, "Hallo") and a.text == "Hallo")
assert(N.Delete(nil, b.id) and #N.Data().notes == 1 and N.Data().cur == a.id)
-- ToDo
local t1 = N.TodoAdd(nil, "eins")
local t2 = N.TodoAdd(nil, "zwei")
local t3 = N.TodoAdd(nil, "drei")
assert(not N.TodoAdd(nil, "   "), "leerer Eintrag")
assert(N.TodoMove(nil, t3.id, -1))
local open = N.TodoOpen()
assert(open[1] == t1 and open[2] == t3 and open[3] == t2, "nach oben geschoben")
assert(not N.TodoMove(nil, t1.id, -1), "oberster bleibt")
-- Abhaken: in "Erledigt", zurueckholen: ans Ende der offenen
assert(N.TodoToggle(nil, t1.id) and t1.done)
assert(#N.TodoOpen() == 2 and N.TodoDone()[1] == t1)
assert(N.TodoToggle(nil, t1.id) and not t1.done)
open = N.TodoOpen()
assert(open[3] == t1 and #N.TodoDone() == 0, "zurueckgeholt ans Ende")
-- Verschieben ueberspringt erledigte
N.TodoToggle(nil, t2.id)
assert(N.TodoMove(nil, t1.id, -1))
open = N.TodoOpen()
assert(open[1] == t1 and open[2] == t3, "Verschieben unter offenen: " .. open[1].text .. "," .. open[2].text)
assert(N.TodoDelete(nil, t3.id) and #N.TodoOpen() == 1)
-- andere Charaktere
FW.db.notes["Zweit Charakter - Forever"] = { notes = { { id = 1, title = "x", text = "" } }, todo = {} }
local chars = N.Chars()
assert(#chars == 2 and chars[1].own and chars[1].key == key and chars[2].notes == 1, "eigener zuerst")
assert(N.Data("Gibt Es Nicht - Forever") == nil, "fremde werden nicht angelegt")
assert(N.SetText("Zweit Charakter - Forever", 1, "geaendert") and FW.db.notes["Zweit Charakter - Forever"].notes[1].text == "geaendert")
-- Links
local link = N.MakeLink("units", 3067, "Pyall [Koch]")
assert(link == "|cffb48cff|Hfwcodex:units:3067|h[Pyall Koch]|h|r", link)
assert(select(1, N.ParseLink("fwcodex:units:3067")) == "units" and select(2, N.ParseLink("fwcodex:quests:12")) == 12)
assert(N.ParseLink("item:2589:0:0") == "items")
assert(N.ParseLink("enchant:123") == nil)
assert(N.MakeLink("zones", 1, "x") == nil)
_G.IsModifiedClick = function() return false end
assert(N.OpenLink("fwcodex:quests:748") and shown == "quests:748")
assert(N.Plain("a " .. link .. " b") == "a [Pyall Koch] b")
-- Befehl
local toggled
N.Toggle = function() toggled = true end
_G.SlashCmdList.FREEWOODNOTES("")
assert(toggled)
-- Zettel (0.51.0)
do
    local calls = 0
    N.Listen(function() calls = calls + 1 end)
    local me = N.CharKey()
    local nn = N.Add(me, "Zettel")
    assert(not N.IsPinned(nn.id))
    local p = N.Pin(nn.id)
    assert(p and p.w == 220 and p.a == 0.95 and N.IsPinned(nn.id), "angeheftet mit Standardwerten")
    assert(calls >= 1, "Aenderung gemeldet")
    assert(N.Pin(nn.id) == p, "zweimal anheften = derselbe Zettel")
    local t = N.Pin("todo")
    assert(t and t.x ~= p.x, "zweiter Zettel versetzt")
    assert(#N.PinList() == 2)
    assert(N.Pin(99999) == nil, "unbekannte Notiz nicht anheftbar")
    local before = calls
    N.SetText(me, nn.id, "neu")
    assert(calls > before, "Text aendern meldet")
    assert(N.TogglePin("todo") == false and not N.IsPinned("todo"), "ToDo geloest")
    N.Delete(me, nn.id)
    assert(not N.IsPinned(nn.id) and #N.PinList() == 0, "geloeschte Notiz verliert den Zettel")
    assert(N.HideInCombat() == false, "Standard: im Kampf sichtbar")
    N.SetHideInCombat(true)
    assert(N.HideInCombat() == true)
    N.SetHideInCombat(false)
    assert(N.HideInCombat() == false)
end
print("notes_test OK")
