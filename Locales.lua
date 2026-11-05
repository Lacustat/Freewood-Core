-- Freewood-Core: Texte (Deutsch / Englisch)
-- Fehlende Schluessel fallen auf Englisch und dann auf den Schluessel selbst zurueck.
-- Module koennen eigene Texte mit Freewood:AddLocale("deDE", { ... }) ergaenzen.

local ADDON, FW = ...

FW.locales = { enUS = {}, deDE = {} }
FW.activeLocale = "enUS"

function FW:AddLocale(code, strings)
    local target = self.locales[code]
    if not target then
        target = {}
        self.locales[code] = target
    end
    for key, value in pairs(strings) do
        target[key] = value
    end
end

function FW:SetLocale(code)
    if not self.locales[code] then
        code = "enUS"
    end
    self.activeLocale = code
end

FW.L = setmetatable({}, {
    __index = function(_, key)
        local active = FW.locales[FW.activeLocale]
        local value = active and active[key]
        if value == nil then
            value = FW.locales.enUS[key]
        end
        if value == nil then
            return key
        end
        return value
    end,
})

FW:AddLocale("enUS", {
    TITLE = "Freewood",

    TAB_OVERVIEW = "Overview",
    TAB_EXCHANGE = "Exchange",
    TAB_SETTINGS = "Settings",

    MONEY_G = "g",
    MONEY_S = "s",
    MONEY_C = "c",

    OVERVIEW_HEADER = "Installed modules",
    OVERVIEW_NONE = "No modules installed yet. Modules appear here as soon as they are loaded (for example Freewood-Pet).",
    OVERVIEW_INFO = "Core %s  |  Game %s (build %s)",
    MODULE_ACTIVE = "active",
    MODULE_INACTIVE = "inactive",

    EXCHANGE_INTRO = "Export your data as a short code, or paste a code from another player to import it. Imported data never overwrites your own entries.",
    EXCHANGE_NO_HANDLERS = "No module offers export or import yet.",
    EXCHANGE_EXPORT = "Export",
    EXCHANGE_IMPORT = "Import",
    EXCHANGE_CLEAR = "Clear",
    EXCHANGE_EXPORTED = "Exported: %d characters. Copy the code with Ctrl+C.",
    EXCHANGE_IMPORTED = "Import finished.",
    EXCHANGE_EMPTY = "Nothing to import. Paste a code first.",
    EXCHANGE_NOTHING_EXPORT = "There is nothing to export for this type yet.",

    ERR_FORMAT = "This is not a valid Freewood code.",
    ERR_TOO_LARGE = "The code is too large.",
    ERR_CHECKSUM = "The code is damaged or incomplete (checksum does not match).",
    ERR_DECODE = "The code could not be read.",
    ERR_VERSION = "The code was created with a newer data format. Please update Freewood.",
    ERR_NOAPI = "This game version does not offer the required encoding functions.",
    ERR_INVALID = "The data in the code is invalid.",
    ERR_NO_HANDLER = "No installed module can handle data of the type \"%s\".",

    SETTINGS_HEADER = "Settings",
    SETTINGS_MINIMAP = "Show minimap button",
    SETTINGS_DEBUG = "Show debug messages in chat",
    SETTINGS_SCALE = "Window scale",
    SETTINGS_LANGUAGE = "Language",
    SETTINGS_LANGUAGE_NOTE = "A language change takes effect after /reload.",
    SETTINGS_RESET_POS = "Reset window position and size",
    SETTINGS_CAT_GENERAL = "General",
    SETTINGS_CAT_DATABASE = "Database",
    SETTINGS_CAT_TOOLTIPS = "Tooltips",
    SETTINGS_CAT_QUEST = "Quests and hints",
    SETTINGS_CAT_MODULES = "Modules",
    WINDOW_RESIZE = "Resize",
    WINDOW_RESIZE_TIP = "Drag to change the window size. The size is remembered.",
    WINDOW_SCALE = "Window scale",
    WINDOW_SCALE_TIP = "Drag to scale the whole window from 50 % to 150 %. The value is applied when you let go and is remembered.",
    LANG_AUTO = "Automatic",
    LANG_DE = "Deutsch",
    LANG_EN = "English",

    MINIMAP_TIP_LEFT = "Left click: open or close the window",
    MINIMAP_TIP_RIGHT = "Right click: settings",
    MINIMAP_TIP_DRAG = "Drag: move the button",

    SLASH_HELP_TITLE = "Commands:",
    SLASH_HELP_1 = "/fw - open or close the window",
    SLASH_HELP_2 = "/fw settings - open the settings",
    SLASH_HELP_3 = "/fw exchange - open export and import",
    SLASH_HELP_4 = "/fw minimap - show or hide the minimap button",
    SLASH_HELP_5 = "/fw modules - list loaded modules",
    SLASH_HELP_6 = "/fw debug - toggle debug messages",
    SLASH_HELP_7 = "/fw reset - reset the window position",
    SLASH_VERSION = "Core %s, API %d, interface %s",
    SLASH_NO_MODULES = "No modules loaded.",
    SLASH_DEBUG_ON = "Debug messages enabled.",
    SLASH_DEBUG_OFF = "Debug messages disabled.",
    SLASH_RESET_DONE = "Window position reset.",

    DB_NEWER = "The saved data was written by a newer Freewood version. Features are limited until you update.",
    API_TOO_OLD = "Module %s needs Freewood-Core API %d, installed is %d. Please update Freewood-Core.",
})

FW:AddLocale("deDE", {
    TITLE = "Freewood",

    TAB_OVERVIEW = "Übersicht",
    TAB_EXCHANGE = "Austausch",
    TAB_SETTINGS = "Einstellungen",

    MONEY_G = "G",
    MONEY_S = "S",
    MONEY_C = "K",

    OVERVIEW_HEADER = "Installierte Module",
    OVERVIEW_NONE = "Noch keine Module installiert. Module erscheinen hier, sobald sie geladen sind (zum Beispiel Freewood-Pet).",
    OVERVIEW_INFO = "Core %s  |  Spiel %s (Build %s)",
    MODULE_ACTIVE = "aktiv",
    MODULE_INACTIVE = "inaktiv",

    EXCHANGE_INTRO = "Exportiere deine Daten als kurzen Code oder füge den Code eines anderen Spielers ein, um ihn zu importieren. Importierte Daten überschreiben nie deine eigenen Einträge.",
    EXCHANGE_NO_HANDLERS = "Noch kein Modul bietet Export oder Import an.",
    EXCHANGE_EXPORT = "Exportieren",
    EXCHANGE_IMPORT = "Importieren",
    EXCHANGE_CLEAR = "Leeren",
    EXCHANGE_EXPORTED = "Exportiert: %d Zeichen. Kopiere den Code mit Strg+C.",
    EXCHANGE_IMPORTED = "Import abgeschlossen.",
    EXCHANGE_EMPTY = "Nichts zu importieren. Füge zuerst einen Code ein.",
    EXCHANGE_NOTHING_EXPORT = "Für diese Datenart gibt es noch nichts zu exportieren.",

    ERR_FORMAT = "Das ist kein gültiger Freewood-Code.",
    ERR_TOO_LARGE = "Der Code ist zu groß.",
    ERR_CHECKSUM = "Der Code ist beschädigt oder unvollständig (Prüfsumme stimmt nicht).",
    ERR_DECODE = "Der Code konnte nicht gelesen werden.",
    ERR_VERSION = "Der Code stammt aus einem neueren Datenformat. Bitte aktualisiere Freewood.",
    ERR_NOAPI = "Diese Spielversion bietet die nötigen Kodierfunktionen nicht.",
    ERR_INVALID = "Die Daten im Code sind ungültig.",
    ERR_NO_HANDLER = "Kein installiertes Modul kann Daten der Art „%s“ verarbeiten.",

    SETTINGS_HEADER = "Einstellungen",
    SETTINGS_MINIMAP = "Minimap-Knopf anzeigen",
    SETTINGS_DEBUG = "Debug-Meldungen im Chat anzeigen",
    SETTINGS_SCALE = "Fenstergröße",
    SETTINGS_LANGUAGE = "Sprache",
    SETTINGS_LANGUAGE_NOTE = "Eine Sprachänderung wirkt nach /reload.",
    SETTINGS_RESET_POS = "Position und Größe zurücksetzen",
    SETTINGS_CAT_GENERAL = "Allgemein",
    SETTINGS_CAT_DATABASE = "Datenbank",
    SETTINGS_CAT_TOOLTIPS = "Tooltips",
    SETTINGS_CAT_QUEST = "Quests und Hinweise",
    SETTINGS_CAT_MODULES = "Module",
    WINDOW_RESIZE = "Größe ändern",
    WINDOW_RESIZE_TIP = "Ziehen, um die Fenstergröße zu ändern. Die Größe wird gespeichert.",
    WINDOW_SCALE = "Fenstergröße",
    WINDOW_SCALE_TIP = "Ziehen, um das ganze Fenster von 50 % bis 150 % zu skalieren. Der Wert gilt beim Loslassen und wird gespeichert.",
    LANG_AUTO = "Automatisch",
    LANG_DE = "Deutsch",
    LANG_EN = "English",

    MINIMAP_TIP_LEFT = "Linksklick: Fenster öffnen oder schließen",
    MINIMAP_TIP_RIGHT = "Rechtsklick: Einstellungen",
    MINIMAP_TIP_DRAG = "Ziehen: Knopf verschieben",

    SLASH_HELP_TITLE = "Befehle:",
    SLASH_HELP_1 = "/fw - Fenster öffnen oder schließen",
    SLASH_HELP_2 = "/fw settings - Einstellungen öffnen",
    SLASH_HELP_3 = "/fw exchange - Export und Import öffnen",
    SLASH_HELP_4 = "/fw minimap - Minimap-Knopf ein- oder ausblenden",
    SLASH_HELP_5 = "/fw modules - geladene Module auflisten",
    SLASH_HELP_6 = "/fw debug - Debug-Meldungen umschalten",
    SLASH_HELP_7 = "/fw reset - Fensterposition zurücksetzen",
    SLASH_VERSION = "Core %s, API %d, Interface %s",
    SLASH_NO_MODULES = "Keine Module geladen.",
    SLASH_DEBUG_ON = "Debug-Meldungen eingeschaltet.",
    SLASH_DEBUG_OFF = "Debug-Meldungen ausgeschaltet.",
    SLASH_RESET_DONE = "Fensterposition zurückgesetzt.",

    DB_NEWER = "Die gespeicherten Daten stammen von einer neueren Freewood-Version. Der Funktionsumfang ist bis zum Update eingeschränkt.",
    API_TOO_OLD = "Modul %s benötigt Freewood-Core API %d, installiert ist %d. Bitte aktualisiere Freewood-Core.",
})
