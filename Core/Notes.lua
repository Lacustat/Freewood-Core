-- Freewood-Core: Notizblock (Datenschicht). Notizen mit Titel und ToDo-Liste, je Charakter.
-- Gespeichert im Konto (FreewoodDB.notes[<Charakter>]), damit man die Notizen anderer Charaktere ansehen und
-- (mit Knopf "Bearbeiten") aendern kann; jeder Charakter sieht standardmaessig nur seine eigenen.
-- Verknuepfungen im Text: Spiel-Links (Items, Rezepte per Shift-Klick) und eigene Links
--   |cffb48cff|Hfwcodex:<art>:<id>|h[Name]|h|r   art = units, objects, quests, items
-- Ein Klick darauf oeffnet den Codex bei diesem Eintrag (Codex.ShowEntry).

local ADDON, NS = ...

local FW = _G.Freewood
if not FW then return end

local Notes = {}
FW.Notes = Notes

local MAX_TITLE = 60
local MAX_TEXT = 20000
local MAX_TODO = 300
Notes.LINK_COLOR = "ffb48cff"
Notes.KINDS = { units = true, objects = true, quests = true, items = true }

local function Now() return _G.time and _G.time() or 0 end

-- Schluessel des Charakters: voller Name (Forever: Vor- und Nachname) und Realm
function Notes.CharKey()
    local name = _G.UnitName and _G.UnitName("player")
    -- Realm ueber Util.RealmName: ein leerer Text vom Spiel zaehlt nicht (0.57.0, Forever_Failure F-37)
    local realm = (FW.Util and FW.Util.RealmName and FW.Util.RealmName()) or (_G.GetRealmName and _G.GetRealmName())
    if type(name) ~= "string" or name == "" then return nil end
    return name .. " - " .. (realm or "?")
end

-- Notizen, die unter "Name - " (leerer Realm) entstanden sind, in den richtigen Charakter uebernehmen (0.57.0).
-- Notizen und ToDo bekommen neue Nummern hinter den vorhandenen; angeheftete Zettel ziehen mit.
function Notes.FixEmptyRealm()
    local root = FW.db and FW.db.notes
    local realm = FW.Util and FW.Util.RealmName and FW.Util.RealmName()
    local emptyKey, key = FW.Util.EmptyRealmKeys(" - ", realm)
    if not (root and emptyKey and root[emptyKey] and emptyKey ~= key) then return 0 end
    local src = root[emptyKey]
    local dst = root[key]
    if not dst then
        root[key], root[emptyKey] = src, nil
        return #(src.notes or {}) + #(src.todo or {})
    end
    dst.notes, dst.todo, dst.seq = dst.notes or {}, dst.todo or {}, dst.seq or 0
    local map, n = {}, 0
    for _, note in ipairs(src.notes or {}) do
        dst.seq = dst.seq + 1
        map[note.id] = dst.seq
        note.id = dst.seq
        dst.notes[#dst.notes + 1] = note
        n = n + 1
    end
    for _, t in ipairs(src.todo or {}) do
        dst.seq = dst.seq + 1
        t.id = dst.seq
        dst.todo[#dst.todo + 1] = t
        n = n + 1
    end
    for pk, pin in pairs(src.pins or {}) do
        local newKey = pk
        local old = tonumber(type(pk) == "string" and pk:match("^n(%d+)$") or "")
        if old and map[old] then newKey = "n" .. map[old] end
        dst.pins = dst.pins or {}
        if not dst.pins[newKey] then dst.pins[newKey] = pin end
    end
    root[emptyKey] = nil
    return n
end

local function Root()
    local db = FW.db
    if not db then return nil end
    db.notes = db.notes or {}
    return db.notes
end

-- Daten eines Charakters (legt sie fuer den eigenen Charakter an)
function Notes.Data(key)
    local root = Root()
    if not root then return nil end
    key = key or Notes.CharKey()
    if not key then return nil end
    local d = root[key]
    if not d and key == Notes.CharKey() then
        d = { notes = {}, todo = {}, seq = 0 }
        root[key] = d
    end
    if d then
        d.notes = d.notes or {}
        d.todo = d.todo or {}
        d.seq = d.seq or 0
    end
    return d
end

-- Alle Charaktere mit Notizen (eigener zuerst), Liste { key, own, notes, todo }
function Notes.Chars()
    local root = Root() or {}
    local me = Notes.CharKey()
    if me then Notes.Data(me) end
    local list = {}
    for key, d in pairs(root) do
        if type(d) == "table" then
            list[#list + 1] = { key = key, own = key == me, notes = #(d.notes or {}), todo = #(d.todo or {}) }
        end
    end
    table.sort(list, function(a, b)
        if a.own ~= b.own then return a.own end
        return a.key:lower() < b.key:lower()
    end)
    return list
end

local function NextId(d)
    d.seq = (d.seq or 0) + 1
    return d.seq
end

-- Benachrichtigung bei Aenderungen (z. B. angeheftete Zettel aktualisieren)
local listeners = {}
function Notes.Listen(fn) listeners[#listeners + 1] = fn end
local function Changed(key)
    key = key or Notes.CharKey()
    for _, fn in ipairs(listeners) do fn(key) end
end
Notes.Changed = Changed

local function Clean(text, max)
    text = type(text) == "string" and text or ""
    if #text > max then text = text:sub(1, max) end
    return text
end

------------------------------------------------------------------------
-- Notizen
------------------------------------------------------------------------

function Notes.Add(key, title)
    local d = Notes.Data(key)
    if not d then return nil end
    local n = { id = NextId(d), title = Clean(title, MAX_TITLE), text = "", t = Now() }
    if n.title == "" then n.title = FW.L and FW.L.NOTES_UNTITLED or "Neue Notiz" end
    table.insert(d.notes, 1, n)
    d.cur = n.id
    return n
end

function Notes.Find(key, id)
    local d = Notes.Data(key)
    for i, n in ipairs(d and d.notes or {}) do
        if n.id == id then return n, i end
    end
    return nil
end

function Notes.SetTitle(key, id, title)
    local n = Notes.Find(key, id)
    if not n then return false end
    title = Clean(title, MAX_TITLE):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "" then return false end
    n.title, n.t = title, Now()
    Changed(key)
    return true
end

function Notes.SetText(key, id, text)
    local n = Notes.Find(key, id)
    if not n then return false end
    n.text, n.t = Clean(text, MAX_TEXT), Now()
    Changed(key)
    return true
end

function Notes.Delete(key, id)
    local d = Notes.Data(key)
    local _, i = Notes.Find(key, id)
    if not (d and i) then return false end
    table.remove(d.notes, i)
    if d.cur == id then d.cur = d.notes[1] and d.notes[1].id or nil end
    if d.pins then d.pins["n" .. tostring(id)] = nil end
    Changed(key)
    return true
end

------------------------------------------------------------------------
-- ToDo: offene Eintraege oben (eigene Reihenfolge), erledigte im Bereich "Erledigt" (zuletzt erledigt zuerst)
------------------------------------------------------------------------

function Notes.TodoAdd(key, text)
    local d = Notes.Data(key)
    text = Clean(text, 500):gsub("^%s+", ""):gsub("%s+$", "")
    if not d or text == "" or #d.todo >= MAX_TODO then return nil end
    local e = { id = NextId(d), text = text, done = false, t = Now() }
    d.todo[#d.todo + 1] = e
    Changed(key)
    return e
end

local function TodoFind(d, id)
    for i, e in ipairs(d and d.todo or {}) do
        if e.id == id then return e, i end
    end
    return nil
end

function Notes.TodoOpen(key)
    local out = {}
    for _, e in ipairs((Notes.Data(key) or {}).todo or {}) do
        if not e.done then out[#out + 1] = e end
    end
    return out
end

function Notes.TodoDone(key)
    local out = {}
    for _, e in ipairs((Notes.Data(key) or {}).todo or {}) do
        if e.done then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.dt or 0) > (b.dt or 0) end)
    return out
end

-- Abhaken / zurueckholen. Zurueckgeholte Eintraege kommen ans Ende der offenen Liste.
function Notes.TodoToggle(key, id)
    local d = Notes.Data(key)
    local e, i = TodoFind(d, id)
    if not e then return false end
    e.done = not e.done
    if e.done then
        e.dt = Now()
    else
        e.dt = nil
        table.remove(d.todo, i)
        d.todo[#d.todo + 1] = e
    end
    Changed(key)
    return true
end

function Notes.TodoSetText(key, id, text)
    local e = TodoFind(Notes.Data(key), id)
    text = Clean(text, 500):gsub("^%s+", ""):gsub("%s+$", "")
    if not e or text == "" then return false end
    e.text = text
    Changed(key)
    return true
end

function Notes.TodoDelete(key, id)
    local d = Notes.Data(key)
    local _, i = TodoFind(d, id)
    if not i then return false end
    table.remove(d.todo, i)
    Changed(key)
    return true
end

-- Offenen Eintrag um eine Stelle nach oben (dir = -1) oder unten (dir = 1) unter den offenen Eintraegen schieben
function Notes.TodoMove(key, id, dir)
    local d = Notes.Data(key)
    if not d then return false end
    local open = {}
    for i, e in ipairs(d.todo) do
        if not e.done then open[#open + 1] = i end
    end
    for k, i in ipairs(open) do
        if d.todo[i].id == id then
            local j = open[k + (dir < 0 and -1 or 1)]
            if not j then return false end
            d.todo[i], d.todo[j] = d.todo[j], d.todo[i]
            Changed(key)
            return true
        end
    end
    return false
end

------------------------------------------------------------------------
-- Angeheftete Zettel (Sticky Notes), nur fuer den eigenen Charakter.
-- d.pins["n<id>"] = Notiz, d.pins.todo = ToDo-Liste. Je Zettel: Lage (x, y = Mitte relativ zur Bildschirmmitte),
-- Groesse (w, h), Hintergrund (r, g, b), Schrift (tr, tg, tb), Deckkraft a, Schriftgroesse size, gesperrt locked.
-- d.stickyHideCombat: alle Zettel im Kampf ausblenden (Standard aus = immer sichtbar).
------------------------------------------------------------------------

Notes.STICKY_DEFAULT = { w = 220, h = 170, r = 1, g = 0.92, b = 0.55, tr = 0.16, tg = 0.12, tb = 0.04, a = 0.95, size = 12 }

local function PinKey(id)
    if id == "todo" then return "todo" end
    if tonumber(id) then return "n" .. tonumber(id) end
    return nil
end
Notes.PinKey = PinKey

local function OwnData()
    local me = Notes.CharKey()
    return me and Notes.Data(me) or nil
end

function Notes.GetPin(id)
    local d, k = OwnData(), PinKey(id)
    return d and k and d.pins and d.pins[k] or nil
end

function Notes.IsPinned(id) return Notes.GetPin(id) ~= nil end

function Notes.Pin(id)
    local d, k = OwnData(), PinKey(id)
    if not (d and k) then return nil end
    if id ~= "todo" and not Notes.Find(nil, tonumber(id)) then return nil end
    d.pins = d.pins or {}
    if not d.pins[k] then
        local count = 0
        for _ in pairs(d.pins) do count = count + 1 end
        local p = {}
        for a, v in pairs(Notes.STICKY_DEFAULT) do p[a] = v end
        p.x, p.y = -240 + (count % 8) * 26, 160 - (count % 8) * 26
        d.pins[k] = p
    end
    Changed()
    return d.pins[k]
end

function Notes.Unpin(id)
    local d, k = OwnData(), PinKey(id)
    if not (d and k and d.pins and d.pins[k]) then return false end
    d.pins[k] = nil
    Changed()
    return true
end

function Notes.TogglePin(id)
    if Notes.IsPinned(id) then Notes.Unpin(id) return false end
    return Notes.Pin(id) ~= nil
end

-- Liste der angehefteten Zettel: { pinKey, id (Zahl oder "todo"), pin }. Zettel geloeschter Notizen werden entfernt.
function Notes.PinList()
    local d = OwnData()
    local out = {}
    if not (d and d.pins) then return out end
    for k, p in pairs(d.pins) do
        local id = (k == "todo") and "todo" or tonumber(k:match("^n(%d+)$") or "")
        if type(p) ~= "table" or not id or (id ~= "todo" and not Notes.Find(nil, id)) then
            d.pins[k] = nil
        else
            for a, v in pairs(Notes.STICKY_DEFAULT) do if p[a] == nil then p[a] = v end end
            out[#out + 1] = { pinKey = k, id = id, pin = p }
        end
    end
    table.sort(out, function(a, b) return a.pinKey < b.pinKey end)
    return out
end

function Notes.HideInCombat()
    local d = OwnData()
    return d and d.stickyHideCombat == true or false
end

function Notes.SetHideInCombat(on)
    local d = OwnData()
    if not d then return end
    d.stickyHideCombat = on and true or nil
    Changed()
end

------------------------------------------------------------------------
-- Verknuepfungen
------------------------------------------------------------------------

-- Eigener Link fuer Codex-Eintraege
function Notes.MakeLink(kind, id, name)
    if not Notes.KINDS[kind] or not tonumber(id) then return nil end
    name = tostring(name or ("#" .. id)):gsub("[%[%]|]", "")
    return string.format("|c%s|Hfwcodex:%s:%d|h[%s]|h|r", Notes.LINK_COLOR, kind, tonumber(id), name)
end

-- Link auswerten: Rueckgabe art, id (Codex-Art) oder nil
function Notes.ParseLink(link)
    if type(link) ~= "string" then return nil end
    local kind, id = link:match("^fwcodex:(%a+):(%d+)")
    if kind and Notes.KINDS[kind] then return kind, tonumber(id) end
    local item = link:match("^item:(%d+)")
    if item then return "items", tonumber(item) end
    return nil
end

-- Klick auf einen Link: Codex oeffnen; sonst (Rezepte, Zauber) die normale Spielanzeige
function Notes.OpenLink(link, text, button)
    local kind, id = Notes.ParseLink(link)
    if kind and FW.Codex and FW.Codex.ShowEntry and not (_G.IsModifiedClick and _G.IsModifiedClick()) then
        if FW.Codex.ShowEntry(kind, id) then return true end
    end
    if _G.SetItemRef and type(link) == "string" and not link:find("^fwcodex:") then
        pcall(_G.SetItemRef, link, text, button)
        return true
    end
    return false
end

-- Text ohne Farb- und Link-Codes (fuer Titel-Vorschau und Suche)
function Notes.Plain(text)
    text = type(text) == "string" and text or ""
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    return text
end

------------------------------------------------------------------------
-- Oeffnen: Tastenbelegung und Befehl
------------------------------------------------------------------------

function _G.Freewood_ToggleNotes()
    if Notes.Toggle then Notes.Toggle() end
end

_G.SLASH_FREEWOODNOTES1 = "/fwnotiz"
_G.SLASH_FREEWOODNOTES2 = "/fwnotes"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.FREEWOODNOTES = function() _G.Freewood_ToggleNotes() end

if FW.Util and FW.Util.OnRealmFix then
    FW.Util.OnRealmFix("Notizblock", Notes.FixEmptyRealm)
end
