-- Freewood-Core: Profile. Alles, was nach Geschmack aussieht oder arbeitet (Greifen, Design, Chat-Stil, Fensterpositionen, ...),
-- gilt je Charakter und liegt in FreewoodCharDB.settings. Jeder neue Charakter beginnt mit den Standardwerten; Charaktere, die
-- schon vor dieser Version existierten, uebernehmen einmalig ihre bisherigen (bisher kontoweiten) Werte.
-- Gespeicherte Profile (benannte Abzuege) liegen im Konto (FreewoodDB.profiles) und lassen sich auf jeden Charakter laden;
-- Laden kopiert die Werte in den Charakter (die Charaktere bleiben unabhaengig).
-- Weiche: FW.settings.<Schluessel> liest/schreibt persoenliche Schluessel im Charakter, alle anderen im Konto
-- (debug, locale, shareLocation). Bestehender Code muss deshalb nicht geaendert werden.

local ADDON, NS = ...

local FW = _G.Freewood
if not FW then return end

local Profile = {}
FW.Profile = Profile

-- Persoenlich (je Charakter)
Profile.PERSONAL = {
    minimap = true, scale = true, scaleUser = true, windowPos = true, windowSize = true, tabOrder = true, tabHidden = true,
    settingsCat = true, chatStyle = true, chatWin = true, bubbles = true, greifen = true, design = true, animation = true,
    tooltips = true, whisperSend = true, whisperPopup = true, whisperPopupAlways = true,
}
local PERSONAL = Profile.PERSONAL

local function Copy(v)
    if FW.Util and FW.Util.CopyTable then return FW.Util.CopyTable(v) end
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end

local function Account() return FW.db and FW.db.settings end
local function Char()
    local c = FW.chardb
    if not c then return nil end
    c.settings = c.settings or {}
    return c.settings
end

-- Standardwerte der persoenlichen Schluessel (aus den Kontostandardwerten)
local function Defaults()
    local out = {}
    for k, v in pairs(FW.defaults and FW.defaults.global and FW.defaults.global.settings or {}) do
        if PERSONAL[k] then out[k] = Copy(v) end
    end
    return out
end
Profile.Defaults = Defaults

local proxy = setmetatable({}, {
    __index = function(_, k)
        if PERSONAL[k] then
            local c = Char()
            return c and c[k]
        end
        local a = Account()
        return a and a[k]
    end,
    __newindex = function(_, k, v)
        if PERSONAL[k] then
            local c = Char()
            if c then c[k] = v end
        else
            local a = Account()
            if a then a[k] = v end
        end
    end,
})
Profile.proxy = proxy

-- Beim Laden der Daten aufgerufen (Core/Init.lua, FW:InitDB)
function Profile.Setup()
    local acc = Account()
    if not acc or not FW.chardb then return end
    local c = FW.chardb
    if type(c.settings) ~= "table" then
        c.settings = {}
        if FW.charFresh then
            -- neuer Charakter: Standardwerte
            for k, v in pairs(Defaults()) do c.settings[k] = v end
        else
            -- bestehender Charakter: bisherige Werte einmalig uebernehmen
            for k in pairs(PERSONAL) do
                if acc[k] ~= nil then c.settings[k] = Copy(acc[k]) end
            end
            for k, v in pairs(Defaults()) do
                if c.settings[k] == nil then c.settings[k] = v end
            end
        end
    else
        for k, v in pairs(Defaults()) do
            if c.settings[k] == nil then c.settings[k] = v end
        end
    end
    FW.db.profiles = FW.db.profiles or {}
    FW.settings = proxy
end

------------------------------------------------------------------------
-- Gespeicherte Profile
------------------------------------------------------------------------

local MAX_NAME = 32

local function Clean(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:sub(1, MAX_NAME)
end

function Profile.List()
    local list = {}
    for name, p in pairs(FW.db and FW.db.profiles or {}) do
        list[#list + 1] = { name = name, saved = type(p) == "table" and p.saved or nil, from = type(p) == "table" and p.from or nil }
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function Profile.Exists(name)
    name = Clean(name)
    return name ~= nil and FW.db and FW.db.profiles and FW.db.profiles[name] ~= nil
end

-- Aktuelle persoenliche Einstellungen unter einem Namen speichern (ueberschreibt ein gleichnamiges Profil)
function Profile.Save(name)
    name = Clean(name)
    if not name then return false, "name" end
    local data = {}
    for k in pairs(PERSONAL) do
        local v = Char() and Char()[k]
        if v ~= nil then data[k] = Copy(v) end
    end
    FW.db.profiles[name] = { data = data, saved = _G.time and _G.time() or 0, from = FW.CharName and FW:CharName() or (_G.UnitName and _G.UnitName("player")) }
    FW.chardb.profileName = name
    return true, name
end

-- Profil in den aktuellen Charakter kopieren. Die meisten Teile werden beim Laden des Interface gelesen: danach /reload.
function Profile.Load(name)
    name = Clean(name)
    local p = name and FW.db.profiles[name]
    if not (p and type(p.data) == "table") then return false, "missing" end
    local c = Char()
    for k in pairs(PERSONAL) do c[k] = nil end
    for k, v in pairs(p.data) do c[k] = Copy(v) end
    for k, v in pairs(Defaults()) do
        if c[k] == nil then c[k] = v end
    end
    FW.chardb.profileName = name
    return true, name
end

function Profile.Delete(name)
    name = Clean(name)
    if not (name and FW.db.profiles[name]) then return false end
    FW.db.profiles[name] = nil
    if FW.chardb.profileName == name then FW.chardb.profileName = nil end
    return true
end

function Profile.Rename(old, new)
    old, new = Clean(old), Clean(new)
    if not (old and new and FW.db.profiles[old]) then return false, "missing" end
    if old ~= new and FW.db.profiles[new] then return false, "exists" end
    FW.db.profiles[new] = FW.db.profiles[old]
    if new ~= old then FW.db.profiles[old] = nil end
    if FW.chardb.profileName == old then FW.chardb.profileName = new end
    return true, new
end

-- Auf Standardwerte zuruecksetzen (nur dieser Charakter)
function Profile.Reset()
    local c = Char()
    for k in pairs(PERSONAL) do c[k] = nil end
    for k, v in pairs(Defaults()) do c[k] = v end
    FW.chardb.profileName = nil
    return true
end

function Profile.Current()
    return FW.chardb and FW.chardb.profileName or nil
end
