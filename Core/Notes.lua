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
    local realm = _G.GetRealmName and _G.GetRealmName()
    if type(name) ~= "string" or name == "" then return nil end
    return name .. " - " .. (realm or "?")
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
    return true
end

function Notes.SetText(key, id, text)
    local n = Notes.Find(key, id)
    if not n then return false end
    n.text, n.t = Clean(text, MAX_TEXT), Now()
    return true
end

function Notes.Delete(key, id)
    local d = Notes.Data(key)
    local _, i = Notes.Find(key, id)
    if not (d and i) then return false end
    table.remove(d.notes, i)
    if d.cur == id then d.cur = d.notes[1] and d.notes[1].id or nil end
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
    return true
end

function Notes.TodoSetText(key, id, text)
    local e = TodoFind(Notes.Data(key), id)
    text = Clean(text, 500):gsub("^%s+", ""):gsub("%s+$", "")
    if not e or text == "" then return false end
    e.text = text
    return true
end

function Notes.TodoDelete(key, id)
    local d = Notes.Data(key)
    local _, i = TodoFind(d, id)
    if not i then return false end
    table.remove(d.todo, i)
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
            return true
        end
    end
    return false
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
