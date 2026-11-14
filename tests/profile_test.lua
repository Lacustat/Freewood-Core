-- Test: Core/Profile.lua (Einstellungen je Charakter, Profile) -- texlua tests/profile_test.lua
local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
local function NewFW()
    local FW = { Util = { CopyTable = Copy },
        defaults = { global = { settings = { scale = 1, locale = "auto", debug = false, greifen = { on = false }, minimap = { hide = false } } } },
        printed = {} }
    function FW:Print(t) self.printed[#self.printed + 1] = t end
    return FW
end
local function Load(FW)
    _G.Freewood = FW
    _G.time = function() return 123 end
    assert(loadfile("Core/Profile.lua"))("Freewood-Core", {})
end

-- bestehender Charakter: uebernimmt die bisherigen Kontowerte einmalig
local FW = NewFW()
FW.db = { settings = { scale = 1.4, locale = "de", debug = true, greifen = { on = true, left = "x" } } }
FW.chardb = { dbVersion = 1, modules = {} }
FW.charFresh = false
Load(FW)
FW.Profile.Setup()
assert(FW.settings.scale == 1.4 and FW.settings.greifen.left == "x", "Uebernahme")
assert(FW.chardb.settings.greifen ~= FW.db.settings.greifen, "tiefe Kopie")
-- Weiche: persoenlich -> Charakter, sonst Konto
FW.settings.scale = 2
assert(FW.chardb.settings.scale == 2 and FW.db.settings.scale == 1.4, "persoenlich im Charakter")
FW.settings.debug = false
assert(FW.db.settings.debug == false and FW.chardb.settings.debug == nil, "Konto")
assert(FW.settings.locale == "de", "Konto lesen")

-- neuer Charakter: Standardwerte (nicht die des Kontos)
local FW2 = NewFW()
FW2.db = FW.db
FW2.chardb = {}
FW2.charFresh = true
Load(FW2)
FW2.Profile.Setup()
assert(FW2.settings.scale == 1 and FW2.settings.greifen.on == false, "Standard fuer neuen Charakter")
FW2.settings.greifen.on = true
assert(FW.chardb.settings.greifen.on == true and FW2.chardb.settings.greifen.on == true)
assert(FW.db.settings.greifen.on == true)  -- unveraendertes Konto

-- Profile
local P = FW.Profile
assert(P.Save("  Haupt  ") and P.Exists("Haupt") and P.Current() == "Haupt")
FW.settings.scale = 0.8
assert(P.Save("Zweit"))
assert(#P.List() == 2 and P.List()[1].name == "Haupt")
assert(P.Load("Haupt") and FW.settings.scale == 2, "Laden")
assert(FW.db.profiles.Haupt.data.scale == 2)
-- Profile sind im Konto: ein anderer Charakter kann sie laden
FW2.db.profiles = FW.db.profiles
assert(FW2.Profile.Load("Zweit") and FW2.settings.scale == 0.8)
FW2.settings.scale = 5
assert(FW.db.profiles.Zweit.data.scale == 0.8, "Laden kopiert")
-- Umbenennen / Loeschen / Fehler
assert(P.Rename("Zweit", "Dritt") and not P.Exists("Zweit") and P.Exists("Dritt"))
local ok, why = P.Rename("Dritt", "Haupt")
assert(not ok and why == "exists")
assert(not P.Save("   ") and not P.Load("nix"))
assert(P.Delete("Dritt") and not P.Exists("Dritt"))
-- Zuruecksetzen
P.Reset()
assert(FW.settings.scale == 1 and FW.settings.greifen.on == false and P.Current() == nil, "Reset")
print("profile_test OK")
