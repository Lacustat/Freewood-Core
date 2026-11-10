-- Freewood-Core: Grundgeruest
-- Namensraum, Ereignissystem, Modulverwaltung, Datenspeicher.
-- Andere Addons der Familie greifen ueber die globale Variable "Freewood" darauf zu.

local ADDON, FW = ...

_G.Freewood = FW

FW.ADDON = ADDON
FW.API_VERSION = 1   -- wird erhoeht, wenn sich die Modul-Schnittstelle inkompatibel aendert
FW.DB_VERSION = 1    -- Version des gespeicherten Datenformats

local function GetMeta(field)
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if fn then
        local ok, value = pcall(fn, ADDON, field)
        if ok then
            return value
        end
    end
    return nil
end

FW.version = GetMeta("Version") or "dev"

------------------------------------------------------------------------
-- Ausgabe und Fehlerbehandlung
------------------------------------------------------------------------

local PREFIX = "|cffc89b3cFreewood|r"

local function Join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

function FW:Print(...)
    print(PREFIX .. ": " .. Join(...))
end

function FW:Debug(...)
    if self.db and self.db.settings and self.db.settings.debug then
        print(PREFIX .. " |cff8c8a84[debug]|r " .. Join(...))
    end
end

-- Ruft fn geschuetzt auf. Ein Fehler wird an den Standard-Fehlerhandler
-- weitergereicht und bricht den Aufrufer nicht ab.
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        else
            print(err)
        end
    end
    return ok
end
FW.SafeCall = SafeCall

-- Leichter Zeitmesser fuer Ruckler-Suche: je Marke Anzahl, Summe und laengster Aufruf (ms). Anzeige: /fwcpu (Dev-Modul).
-- Aufrufe ueber SLOW_MS landen zusaetzlich in FW.Perf.slow (letzte 30) und werden dem Dev-Log gemeldet (FW.Perf.OnSlow).
local Perf = { stats = {}, slow = {} }
FW.Perf = Perf
local SLOW_MS = 30
local function Prof() return debugprofilestop and debugprofilestop() or 0 end
function Perf.Note(label, dt)
    local st = Perf.stats[label]
    if not st then st = { calls = 0, total = 0, max = 0 } Perf.stats[label] = st end
    st.calls = st.calls + 1
    st.total = st.total + dt
    if dt > st.max then st.max = dt end
    if dt >= SLOW_MS then
        local s = Perf.slow
        s[#s + 1] = { label = label, ms = dt, at = GetTime and GetTime() or 0 }
        if #s > 30 then table.remove(s, 1) end
        if Perf.OnSlow then pcall(Perf.OnSlow, label, dt) end
    end
end
-- Ruft pcall(fn, ...) und misst die Zeit
function Perf.Call(label, fn, ...)
    local t0 = Prof()
    local ok, err = pcall(fn, ...)
    Perf.Note(label, Prof() - t0)
    return ok, err
end
-- Umhuellt fn (fuer Skripte wie OnUpdate): liefert die Funktion mit Zeitmessung
function Perf.Wrap(label, fn)
    return function(...)
        local t0 = Prof()
        local a, b, c = fn(...)
        Perf.Note(label, Prof() - t0)
        return a, b, c
    end
end

------------------------------------------------------------------------
-- Interne Nachrichten (Ereignissystem des Cores)
------------------------------------------------------------------------


-- Herkunft einer Anmeldung (Datei:Zeile des Aufrufers) fuer die Zeitmessung; nur einmal beim Anmelden
local function Src(level)
    if not debugstack then return "?" end
    local s = debugstack((level or 3), 1, 0)
    if type(s) ~= "string" then return "?" end
    s = s:match("AddOns[\\/]([^\n]-:%d+)") or s:match("([^\n]-:%d+)") or "?"
    s = s:gsub("[%[%]]", "")
    return (s:gsub("\\", "/"))
end

local callbacks = {}

-- Ladezeit je Addon: Zeit zwischen dem ADDON_LOADED des Vorgaengers und dem eigenen (= Einlesen der Dateien des Addons)
Perf.load = {}
local lastLoad = Prof()
local loadFrame = _G.CreateFrame and _G.CreateFrame("Frame")
if loadFrame then
    loadFrame:RegisterEvent("ADDON_LOADED")
    loadFrame:SetScript("OnEvent", function(_, _, name)
        local now = Prof()
        Perf.load[#Perf.load + 1] = { name = tostring(name), ms = now - lastLoad }
        lastLoad = now
    end)
end

function FW:On(event, fn, owner)
    local list = callbacks[event]
    if not list then
        list = {}
        callbacks[event] = list
    end
    list[#list + 1] = { fn = fn, owner = owner, label = "FW:" .. tostring(event) .. " [" .. Src(3) .. "]" }
end

function FW:Off(event, owner)
    local list = callbacks[event]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i].owner == owner then
            table.remove(list, i)
        end
    end
end

function FW:Fire(event, ...)
    local list = callbacks[event]
    if not list then
        return
    end
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end
    for i = 1, #snapshot do
        local cb = snapshot[i]
        local t0 = Prof()
        if cb.owner then
            SafeCall(cb.fn, cb.owner, ...)
        else
            SafeCall(cb.fn, ...)
        end
        Perf.Note(cb.label or event, Prof() - t0)
    end
end

------------------------------------------------------------------------
-- Spielereignisse (ein gemeinsamer Frame fuer alle Module)
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local gameHandlers = {}

function FW:RegisterEvent(event, fn, owner)
    local list = gameHandlers[event]
    if not list then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            self:Debug("Ereignis nicht verfuegbar:", event)
            return false
        end
        list = {}
        gameHandlers[event] = list
    end
    list[#list + 1] = { fn = fn, owner = owner, label = tostring(event) .. " [" .. Src(3) .. "]" }
    return true
end

function FW:UnregisterEvent(event, owner)
    local list = gameHandlers[event]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i].owner == owner then
            table.remove(list, i)
        end
    end
    if #list == 0 then
        gameHandlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = gameHandlers[event]
    if not list then
        return
    end
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end
    for i = 1, #snapshot do
        local h = snapshot[i]
        local t0 = Prof()
        if h.owner then
            SafeCall(h.fn, h.owner, ...)
        else
            SafeCall(h.fn, ...)
        end
        Perf.Note(h.label or tostring(event), Prof() - t0)
    end
end)

------------------------------------------------------------------------
-- Datenspeicher
-- FreewoodDB      : gilt fuer den ganzen Account
-- FreewoodCharDB  : gilt nur fuer den aktuellen Charakter
-- Module legen ihre Daten unter db.modules[<Modulname>] ab (siehe NewModule).
------------------------------------------------------------------------

FW.defaults = {
    global = {
        dbVersion = FW.DB_VERSION,
        installed = 0,
        settings = {
            minimap = { hide = false, angle = 215 },
            scale = 1,
            locale = "auto",
            debug = false,
            windowPos = false,
            windowSize = false,
            tabOrder = {},
            tabHidden = {},
        },
        disabledModules = {},
        modules = {},
    },
    char = {
        dbVersion = FW.DB_VERSION,
        modules = {},
    },
}

-- Migrationen: FW.migrations[n] hebt Daten von Version n-1 auf n.
FW.migrations = {}

local function Migrate(db, kind)
    local from = tonumber(db.dbVersion) or 0
    for version = from + 1, FW.DB_VERSION do
        local migration = FW.migrations[version]
        if migration then
            SafeCall(migration, db, kind)
        end
    end
    db.dbVersion = FW.DB_VERSION
end

function FW:InitDB()
    if type(FreewoodDB) ~= "table" then
        FreewoodDB = {}
    end
    if type(FreewoodCharDB) ~= "table" then
        FreewoodCharDB = {}
    end

    self.dbNewer = false

    local sets = {
        { db = FreewoodDB, defaults = self.defaults.global, kind = "global" },
        { db = FreewoodCharDB, defaults = self.defaults.char, kind = "char" },
    }

    for _, set in ipairs(sets) do
        local db = set.db
        local fresh = next(db) == nil
        local stored = tonumber(db.dbVersion)

        if fresh then
            db.dbVersion = self.DB_VERSION
        elseif stored and stored > self.DB_VERSION then
            -- Daten einer neueren Version: nichts migrieren, nichts abwerten.
            self.dbNewer = true
        else
            Migrate(db, set.kind)
        end

        self.Util.MergeDefaults(db, set.defaults)
    end

    if FreewoodDB.installed == 0 then
        FreewoodDB.installed = time()
    end

    self.db = FreewoodDB
    self.settings = FreewoodDB.settings
    self.chardb = FreewoodCharDB
end

function FW:ApplyLocale()
    local setting = self.settings and self.settings.locale or "auto"
    local code
    if setting == "deDE" or setting == "enUS" then
        code = setting
    else
        code = (GetLocale() == "deDE") and "deDE" or "enUS"
    end
    self:SetLocale(code)
end

------------------------------------------------------------------------
-- Module
-- Ablauf eines Moduls: NewModule -> OnInitialize (einmal, Daten bereit)
--                      -> OnEnable (nach PLAYER_LOGIN) -> optional OnDisable
------------------------------------------------------------------------

FW.modules = {}
FW.moduleList = {}

function FW:RequireAPI(minVersion, who)
    if (self.API_VERSION or 0) >= minVersion then
        return true
    end
    self:Print(string.format(self.L.API_TOO_OLD, tostring(who or "?"), minVersion, self.API_VERSION))
    return false
end

function FW:NewModule(name, opts)
    assert(type(name) == "string" and name ~= "", "Freewood:NewModule - Name fehlt")
    if self.modules[name] then
        error("Freewood: Modul '" .. name .. "' ist bereits registriert", 2)
    end

    local mod = opts or {}
    mod.name = name
    mod.state = "registered"
    mod.core = self

    function mod:IsEnabled()
        return self.state == "enabled"
    end

    self.modules[name] = mod
    self.moduleList[#self.moduleList + 1] = mod

    if self.ready then
        self:InitModule(mod)
        if self.loggedIn then
            self:EnableModule(mod)
        end
    end

    self:Fire("FW_MODULE_REGISTERED", mod)
    return mod
end

function FW:GetModule(name)
    return self.modules[name]
end

function FW:InitModule(mod)
    if mod.state ~= "registered" then
        return
    end

    local globalData = self.db.modules
    local charData = self.chardb.modules
    globalData[mod.name] = globalData[mod.name] or {}
    charData[mod.name] = charData[mod.name] or {}

    if mod.defaults then
        self.Util.MergeDefaults(globalData[mod.name], mod.defaults)
    end
    if mod.charDefaults then
        self.Util.MergeDefaults(charData[mod.name], mod.charDefaults)
    end

    mod.db = globalData[mod.name]
    mod.chardb = charData[mod.name]
    mod.state = "initialized"

    if mod.OnInitialize then
        SafeCall(mod.OnInitialize, mod)
    end
end

function FW:EnableModule(mod)
    if mod.state ~= "initialized" and mod.state ~= "disabled" then
        return
    end
    if self.db.disabledModules[mod.name] then
        mod.state = "disabled"
        return
    end
    mod.state = "enabled"
    if mod.OnEnable then
        SafeCall(mod.OnEnable, mod)
    end
    self:Fire("FW_MODULE_ENABLED", mod)
end

function FW:DisableModule(mod)
    if mod.state ~= "enabled" then
        return
    end
    mod.state = "disabled"
    if mod.OnDisable then
        SafeCall(mod.OnDisable, mod)
    end
end

function FW:SetModuleEnabled(name, enabled)
    local mod = self.modules[name]
    self.db.disabledModules[name] = (not enabled) or nil
    if mod then
        if enabled then
            self:EnableModule(mod)
        else
            self:DisableModule(mod)
        end
    end
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

function FW:OnAddonLoaded(name)
    if name ~= ADDON then
        return
    end
    self:UnregisterEvent("ADDON_LOADED", self)

    self:InitDB()
    self:ApplyLocale()
    self.ready = true

    if self.dbNewer then
        self:Print(self.L.DB_NEWER)
    end

    self:Fire("FW_DB_READY")

    -- Module, die vor der Datenbank registriert wurden (sollte nicht vorkommen)
    for _, mod in ipairs(self.moduleList) do
        self:InitModule(mod)
    end
end

function FW:OnLogin()
    self.loggedIn = true
    self:Fire("FW_LOGIN")
    for _, mod in ipairs(self.moduleList) do
        self:InitModule(mod)
        self:EnableModule(mod)
    end
end

FW:RegisterEvent("ADDON_LOADED", FW.OnAddonLoaded, FW)
FW:RegisterEvent("PLAYER_LOGIN", FW.OnLogin, FW)
