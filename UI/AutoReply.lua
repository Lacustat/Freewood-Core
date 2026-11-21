-- Freewood-Core: Reiter "Auto-Antwort" (seit 0.59.0; Ausloeser, Aktion, Vorlagen, Export seit 0.60.0), Fenster "Ignorieren?", "Melden" und "Code"
--
-- Links die Regeln (Neue Regel, Klick = bearbeiten, gedimmt = aus), rechts das Formular einer Regel; oben der
-- Hauptschalter und der Wechsel zwischen "Regeln" und "Verlauf". Die Logik steht in Core/AutoReply.lua.

local ADDON, FW = ...

local G = _G
local UI = FW.UI
local AR = FW.AutoReply
if not UI or not AR then return end

FW:AddLocale("enUS", {
    TAB_AUTOREPLY = "Auto reply",
    AR_ON = "Auto reply on",
    AR_ON_INFO = "Rules answer chat messages or buffs automatically. Not possible: say, yell and channels (Blizzard only allows them with a key press), and tickets with attached chat (blocked for addons). Fixed safety rules: never yourself, never GMs, never Blizzard's AFK/DND replies, at most 6 replies per minute.",
    AR_RULES = "Rules", AR_LOG = "History",
    AR_NEW = "New rule", AR_NEW_NAME = "Rule",
    AR_NONE = "No rule yet: press \"New rule\".",
    AR_NAME = "Name", AR_RULE_ON = "Rule on",
    AR_KIND = "Type", AR_KIND_CHAT = "Chat message", AR_KIND_BUFF = "Buff from a player",
    AR_SRC = "From (the answer goes to the same chat)",
    AR_SRC_WHISPER = "Whisper", AR_SRC_BN = "Battle.net", AR_SRC_GUILD = "Guild", AR_SRC_OFFICER = "Officers",
    AR_SRC_PARTY = "Group", AR_SRC_RAID = "Raid",
    AR_BUFFREPLY = "Answer to", AR_BUFFREPLY_W = "Whisper to the player", AR_BUFFREPLY_G = "Group or raid chat",
    AR_MATCH = "Words", AR_MATCH_BUFF = "Spell names (empty = every buff)",
    AR_MATCH_INFO = "One line = all words must appear (AND). Several lines = one line is enough (OR). Inside a line you can write \"and\", \"&\", \"+\" or a comma; \"or\" starts a new line. Case does not matter, part of a word is enough (\"port\" finds \"Portest\"). Empty = every message.",
    AR_NEVER = "Never if", AR_NEVER_INFO = "Words separated by commas: if one of them appears, the rule does not answer.",
    AR_WHOLE = "Whole words only",
    AR_COND = "Conditions", AR_C_AFK = "AFK", AR_C_DND = "DND", AR_C_GROUP = "In a group", AR_C_RAID = "In a raid",
    AR_ANY = "Any", AR_YES = "Only if", AR_NO = "Never if",
    AR_CLASSES = "Classes", AR_CL_ALL = "All classes", AR_CL_ONLY = "Only these", AR_CL_NOT = "Not these",
    AR_CHAR = "Applies to", AR_CHAR_ALL = "All characters", AR_CHAR_ONLY = "Only %s",
    AR_REPLIES = "Answers (one per line, picked at random)",
    AR_REPLIES_INFO = "One answer per line; with several lines one is picked at random. {name} = first name of the other player, {me} = your first name. At most 255 characters.",
    AR_CD_RULE = "Pause of this rule (s)", AR_CD_PLAYER = "Pause per player (s)", AR_IGNORE_AFTER = "Ignore after (0 = off)",
    AR_TIME_INFO = "Pause of this rule: after an answer the rule stays silent for this many seconds for everyone (e.g. \"good night\" in the guild). Pause per player: the same player gets the next answer only after this time. Ignore after: after this many answers to the same player (this session) a window asks for 20 seconds, then the player goes on your ignore list.",
    AR_REPORT = "Open the report window (chat of the last 5 minutes)",
    AR_TEST = "Test", AR_TEST_HINT = "Type a message to test the filter",
    AR_TEST_YES = "|cff66dd66matches|r", AR_TEST_NO = "|cffff6060does not match|r", AR_TEST_COND = "|cffffd100matches, but a condition blocks (%s)|r",
    AR_SAVE = "Save", AR_DELETE = "Delete", AR_DELETE_SURE = "Sure?", AR_SAVED = "Saved.",
    AR_LOG_EMPTY = "No answers yet.", AR_LOG_CLEAR = "Clear history",
    AR_IGNORE_TITLE = "Ignore?", AR_IGNORE_TEXT = "%s got %d automatic answers from the rule \"%s\".",
    AR_IGNORE_COUNT = "Goes on your ignore list in %d s.", AR_IGNORE_NOW = "Ignore now", AR_IGNORE_CANCEL = "Cancel",
    AR_IGNORED = "%s is now on your ignore list.", AR_IGNORE_FAIL = "Could not ignore %s.",
    AR_REPORT_TITLE = "Report: %s", AR_REPORT_INFO = "These are the chat lines of this player from the last 5 minutes (also your whispers to them). Mark and copy them with Ctrl+C. \"Report to Blizzard\" opens Blizzard's own report window; you send it yourself. Blizzard attaches the chat on its own.",
    AR_REPORT_ALL = "Select all", AR_REPORT_BLIZZ = "Report to Blizzard", AR_REPORT_CLOSE = "Close",
    AR_REPORT_NONE = "No lines from this player in the last 5 minutes.",
    AR_REPORT_FAIL = "Blizzard's report window could not be opened. Right-click the name in the chat and choose \"Report\".",
})
FW:AddLocale("deDE", {
    TAB_AUTOREPLY = "Auto-Antwort",
    AR_ON = "Auto-Antwort an",
    AR_ON_INFO = "Regeln beantworten Chatnachrichten oder Buffs automatisch. Nicht möglich: Sagen, Schreien und Kanäle (Blizzard erlaubt sie nur mit Tastendruck) und Tickets mit angehängtem Chat (für Addons gesperrt). Feste Schutzregeln: nie dir selbst, nie GMs, nie auf Blizzards AFK-/DND-Antworten, höchstens 6 Antworten pro Minute.",
    AR_RULES = "Regeln", AR_LOG = "Verlauf",
    AR_NEW = "Neue Regel", AR_NEW_NAME = "Regel",
    AR_NONE = "Noch keine Regel: „Neue Regel“ drücken.",
    AR_NAME = "Name", AR_RULE_ON = "Regel an",
    AR_KIND = "Art", AR_KIND_CHAT = "Chatnachricht", AR_KIND_BUFF = "Buff von einem Spieler",
    AR_SRC = "Woher (die Antwort geht in denselben Chat)",
    AR_SRC_WHISPER = "Flüstern", AR_SRC_BN = "Battle.net", AR_SRC_GUILD = "Gilde", AR_SRC_OFFICER = "Offiziere",
    AR_SRC_PARTY = "Gruppe", AR_SRC_RAID = "Schlachtzug",
    AR_BUFFREPLY = "Antwort an", AR_BUFFREPLY_W = "Flüstern an den Spieler", AR_BUFFREPLY_G = "Gruppen- bzw. Schlachtzugchat",
    AR_MATCH = "Wörter", AR_MATCH_BUFF = "Zaubernamen (leer = jeder Buff)",
    AR_MATCH_INFO = "Eine Zeile = alle Wörter müssen vorkommen (UND). Mehrere Zeilen = eine Zeile reicht (ODER). In einer Zeile geht „und“, „&“, „+“ oder ein Komma; „oder“ beginnt eine neue Zeile. Groß/klein ist egal, ein Wortteil reicht („port“ findet „Portest“). Leer = jede Nachricht.",
    AR_NEVER = "Nie wenn", AR_NEVER_INFO = "Wörter mit Komma getrennt: Kommt eines davon vor, antwortet die Regel nicht.",
    AR_WHOLE = "Nur ganze Wörter",
    AR_COND = "Bedingungen", AR_C_AFK = "AFK", AR_C_DND = "DND", AR_C_GROUP = "In Gruppe", AR_C_RAID = "Im Schlachtzug",
    AR_ANY = "Egal", AR_YES = "Nur wenn", AR_NO = "Nie wenn",
    AR_CLASSES = "Klassen", AR_CL_ALL = "Alle Klassen", AR_CL_ONLY = "Nur diese", AR_CL_NOT = "Nicht diese",
    AR_CHAR = "Gilt für", AR_CHAR_ALL = "Alle Charaktere", AR_CHAR_ONLY = "Nur %s",
    AR_REPLIES = "Antworten (je Zeile eine, zufällig gewählt)",
    AR_REPLIES_INFO = "Je Zeile eine Antwort; bei mehreren Zeilen wird zufällig eine gewählt. {name} = Vorname des anderen Spielers, {me} = dein Vorname. Höchstens 255 Zeichen.",
    AR_CD_RULE = "Pause dieser Regel (s)", AR_CD_PLAYER = "Pause je Spieler (s)", AR_IGNORE_AFTER = "Ignorieren nach (0 = aus)",
    AR_TIME_INFO = "Pause dieser Regel: Nach einer Antwort schweigt die Regel so viele Sekunden für alle (z. B. „Gute Nacht“ in der Gilde). Pause je Spieler: Derselbe Spieler bekommt die nächste Antwort erst nach dieser Zeit. Ignorieren nach: Nach so vielen Antworten an denselben Spieler (in dieser Sitzung) fragt ein Fenster 20 Sekunden lang, danach kommt der Spieler auf die Ignoreliste.",
    AR_REPORT = "Melde-Fenster öffnen (Chat der letzten 5 Minuten)",
    AR_TEST = "Test", AR_TEST_HINT = "Nachricht eintippen, um den Filter zu prüfen",
    AR_TEST_YES = "|cff66dd66passt|r", AR_TEST_NO = "|cffff6060passt nicht|r", AR_TEST_COND = "|cffffd100passt, aber eine Bedingung sperrt (%s)|r",
    AR_SAVE = "Speichern", AR_DELETE = "Löschen", AR_DELETE_SURE = "Sicher?", AR_SAVED = "Gespeichert.",
    AR_LOG_EMPTY = "Noch keine Antworten.", AR_LOG_CLEAR = "Verlauf leeren",
    AR_IGNORE_TITLE = "Ignorieren?", AR_IGNORE_TEXT = "%s hat %d automatische Antworten der Regel „%s“ bekommen.",
    AR_IGNORE_COUNT = "Kommt in %d s auf deine Ignoreliste.", AR_IGNORE_NOW = "Jetzt ignorieren", AR_IGNORE_CANCEL = "Abbrechen",
    AR_IGNORED = "%s steht jetzt auf deiner Ignoreliste.", AR_IGNORE_FAIL = "%s konnte nicht ignoriert werden.",
    AR_REPORT_TITLE = "Melden: %s", AR_REPORT_INFO = "Das sind die Chatzeilen dieses Spielers aus den letzten 5 Minuten (auch deine Flüster an ihn). Markieren und mit Strg+C kopieren. „Bei Blizzard melden“ öffnet Blizzards eigenes Melde-Fenster; abschicken musst du selbst. Blizzard hängt den Chat selbst an.",
    AR_REPORT_ALL = "Alles markieren", AR_REPORT_BLIZZ = "Bei Blizzard melden", AR_REPORT_CLOSE = "Schließen",
    AR_REPORT_NONE = "Keine Zeilen dieses Spielers in den letzten 5 Minuten.",
    AR_REPORT_FAIL = "Blizzards Melde-Fenster ließ sich nicht öffnen. Rechtsklick auf den Namen im Chat und „Melden“ wählen.",
})

local function L() return FW.L end

local function Info(parent, title, text)
    if UI.CreateInfoIcon then return UI.CreateInfoIcon(parent, title, text) end
    local f = CreateFrame("Frame", nil, parent) f:SetSize(1, 1) return f
end

-- Einzeiliges Eingabefeld
local function Edit(parent, width)
    local box = UI.CreatePanel(parent, "card", "bronze")
    box:SetSize(width or 200, 22)
    local e = CreateFrame("EditBox", nil, box)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -2)
    e:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 2)
    UI.SetFont(e, "body", 12)
    e:SetTextColor(UI.Color("text"))
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box.edit = e
    function box:GetText() return e:GetText() or "" end
    function box:SetText(t) e:SetText(t or "") end
    return box
end

local function Movable(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetClampedToScreen(true)
end

------------------------------------------------------------------------
-- Fenster "Ignorieren?" (20 Sekunden, Abbrechen möglich)
------------------------------------------------------------------------

local ignoreWin
local ignoreQueue = {}

local function NextIgnore()
    local job = table.remove(ignoreQueue, 1)
    if not job then return end
    local f = ignoreWin
    f.who = job.who
    f.left = AR.IGNORE_WAIT
    f.text:SetText(string.format(L().AR_IGNORE_TEXT, job.who, job.count, job.rule))
    f.count:SetText(string.format(L().AR_IGNORE_COUNT, f.left))
    f:Show()
end

local function BuildIgnore()
    if ignoreWin then return ignoreWin end
    local f = UI.CreatePanel(G.UIParent, "bg", "gold")
    f:SetSize(400, 140)
    f:SetPoint("TOP", G.UIParent, "TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    Movable(f)
    f:Hide()
    local t = UI.CreateLabel(f, L().AR_IGNORE_TITLE, { font = "heading", size = 14, color = "goldLight" })
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.text = UI.CreateLabel(f, "", { size = 12, justifyV = "TOP" })
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -38)
    f.text:SetHeight(32)
    f.text:SetWordWrap(true)
    f.count = UI.CreateLabel(f, "", { size = 12, color = "gold" })
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -74)
    local function Done(doIt)
        local who = f.who
        f.who = nil
        f:Hide()
        if doIt and who then AR.DoIgnore(who) end
        NextIgnore()
    end
    local now = UI.CreateButton(f, L().AR_IGNORE_NOW, 150, 26, function() Done(true) end, "danger")
    now:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    local cancel = UI.CreateButton(f, L().AR_IGNORE_CANCEL, 120, 26, function() Done(false) end, "primary")
    cancel:SetPoint("LEFT", now, "RIGHT", 8, 0)
    local acc = 0
    f:SetScript("OnUpdate", function(self, el)
        if not self.who then return end
        acc = acc + (el or 0)
        if acc < 1 then return end
        acc = acc - 1
        self.left = self.left - 1
        if self.left <= 0 then Done(true) return end
        self.count:SetText(string.format(L().AR_IGNORE_COUNT, self.left))
    end)
    ignoreWin = f
    return f
end

function AR.AskIgnore(who, rule)
    BuildIgnore()
    local k = rule.id .. "|" .. AR.Norm(who)
    ignoreQueue[#ignoreQueue + 1] = { who = who, rule = rule.name, count = AR.counts[k] or 0 }
    if not ignoreWin.who then NextIgnore() end
end

------------------------------------------------------------------------
-- Fenster "Melden"
------------------------------------------------------------------------

local reportWin

local function BuildReport()
    if reportWin then return reportWin end
    local f = UI.CreatePanel(G.UIParent, "bg", "gold")
    f:SetSize(600, 380)
    f:SetPoint("CENTER", G.UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    Movable(f)
    f:Hide()
    f.title = UI.CreateLabel(f, "", { font = "heading", size = 14, color = "goldLight" })
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    Info(f, function() return f.title:GetText() end, L().AR_REPORT_INFO):SetPoint("LEFT", f.title, "RIGHT", 6, 0)
    local x = UI.CreateButton(f, "X", 22, 22, function() f:Hide() end)
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    f.area = UI.CreateTextArea(f, 572, 280)
    f.area:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 48)
    local all = UI.CreateButton(f, L().AR_REPORT_ALL, 140, 26, function() f.area:SelectAll() end)
    all:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    local blizz = UI.CreateButton(f, L().AR_REPORT_BLIZZ, 170, 26, function()
        if not AR.BlizzardReport(f.who, f.extra) then FW:Print(L().AR_REPORT_FAIL) end
    end, "primary")
    blizz:SetPoint("LEFT", all, "RIGHT", 8, 0)
    local close = UI.CreateButton(f, L().AR_REPORT_CLOSE, 110, 26, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    reportWin = f
    return f
end

function AR.OpenReport(who, extra)
    local f = BuildReport()
    f.who, f.extra = who, extra
    f.title:SetText(string.format(L().AR_REPORT_TITLE, who))
    local text, n = AR.ReportText(who)
    f.area:SetText(n > 0 and text or L().AR_REPORT_NONE)
    f:Show()
end

------------------------------------------------------------------------
-- Texte für 0.60.0 (Auslöser, Bedingungen, Aktion, Vorlagen, Export)
------------------------------------------------------------------------

FW:AddLocale("enUS", {
    AR_TRIGGER = "Trigger",
    AR_TRIGGER_INFO = "Level-up in the guild: the game has no event for it, the guild list is compared every minute (up to ~1 min later). Level-up nearby: the game only reports levels of group members, your target and players with a visible nameplate. Online, joins and guild level-ups stay silent for 60 s after you log in.",
    AR_K_chat = "Chat message", AR_K_buff = "Buff from a player", AR_K_friendon = "Friend comes online",
    AR_K_guildon = "Guild member comes online", AR_K_rollwon = "Item won (roll)", AR_K_levelup = "My level-up",
    AR_K_guildlevel = "Level-up in the guild", AR_K_nearlevel = "Level-up nearby", AR_K_invite = "Group invite",
    AR_K_trade = "Trade request", AR_K_duel = "Duel request", AR_K_rez = "Resurrected",
    AR_K_groupjoin = "Someone joins the group", AR_K_guildjoin = "New guild member", AR_K_boss = "Boss defeated",
    AR_MATCH_ITEM = "Item names (empty = every item)", AR_MATCH_BOSS = "Boss names (empty = every boss)",
    AR_COND_SELF = "Conditions about you", AR_COND_OTHER = "Conditions about the other player",
    AR_C_COMBAT = "In combat", AR_C_INSTANCE = "In an instance",
    AR_O_GUILD = "Guild member", AR_O_PARTY = "Group member", AR_O_FRIEND = "Friend",
    AR_TIME = "Time from - to", AR_TIME_INFO2 = "Only between these times (HH:MM), e.g. 22:00 to 06:00 across midnight. Empty = always.",
    AR_ONCE = "Only once per session per player",
    AR_ACTION = "Action", AR_ACT_TEXT = "Text", AR_ACT_EMOTE = "Emote", AR_ACT_BOTH = "Text and emote",
    AR_DEST = "Text goes to", AR_DEST_SAME = "The same chat", AR_DEST_WHISPER = "Whisper to the player",
    AR_DEST_GUILD = "Guild", AR_DEST_GROUP = "Group or raid",
    AR_EMOTE = "Emote", AR_EMOTE_TARGET = "Aim at the player",
    AR_EMOTE_INFO = "Voice emotes: your character speaks. Blizzard allows them without a key press (about 4 per second at most). Your own emote text (/e ...) is blocked like say.",
    AR_DELAY = "Delay from - to (s)",
    AR_REPLIES_INFO2 = "One answer per line, one is picked at random. Placeholders: {name} first name of the other player, {me} your first name, {level} level, {item} won item, {boss} boss, {spell} buff, {zone} zone, {class} your class, {time} time. At most 255 characters.",
    AR_TEMPLATE = "Template ...", AR_EXPORT = "Export", AR_IMPORT = "Import",
    AR_CODE_EXPORT = "Export: %s", AR_CODE_IMPORT = "Import rules",
    AR_CODE_INFO = "Copy the code with Ctrl+C and share it. To import paste a code and press \"Apply\". Imported rules start switched off so you can check them first.",
    AR_CODE_APPLY = "Apply", AR_IMPORTED = "%d rule(s) imported (switched off, please check).", AR_IMPORT_ERR = "Import failed: %s",
    AR_T_PORT = "Warlock: no ports", AR_T_PORT_M = "port and gold\nport and pay\nsummon", AR_T_PORT_R = "Sorry {name}, I am not summoning right now.",
    AR_T_GN = "Good night in the guild", AR_T_GN_M = "good night\ngn8\ngn", AR_T_GN_R = "Good night!\nSleep well!",
    AR_T_GLVL = "Congratulate level-up (guild)", AR_T_GLVL_R = "Grats on level {level}, {name}!",
    AR_T_LVL = "My level-up", AR_T_LVL_R = "Level {level}!",
    AR_T_BUFF = "Thanks for the buff", AR_T_BUFF_R = "Thanks for {spell}, {name}!",
    AR_T_GJOIN = "Welcome to the guild", AR_T_GJOIN_R = "Welcome to the guild, {name}!",
    AR_T_PJOIN = "Welcome to the group", AR_T_PJOIN_R = "Hi {name}!",
    AR_T_REZ = "Thanks for the rez", AR_T_REZ_R = "Thanks for the resurrection, {name}!",
    AR_T_DUEL = "Decline duels", AR_T_DUEL_R = "No duels please, thanks!",
    AR_T_BOSS = "gg after the boss", AR_T_BOSS_R = "gg!\nWell done!",
    AR_T_INVITE = "Busy (DND)", AR_T_INVITE_R = "I am busy right now, thanks!",
    AR_T_FRIEND = "Greet friends", AR_T_FRIEND_R = "Hi {name}!",
})
FW:AddLocale("deDE", {
    AR_TRIGGER = "Auslöser",
    AR_TRIGGER_INFO = "Level-up in der Gilde: Dafür gibt es kein Ereignis, die Gildenliste wird jede Minute verglichen (bis zu ~1 min später). Level-up in der Umgebung: Das Spiel meldet Stufen nur von Gruppenmitgliedern, deinem Ziel und Spielern mit sichtbarer Namensplakette. Online, Beitritte und Gilden-Level-ups bleiben 60 s nach dem Einloggen still.",
    AR_K_chat = "Chatnachricht", AR_K_buff = "Buff von einem Spieler", AR_K_friendon = "Freund kommt online",
    AR_K_guildon = "Gildenmitglied kommt online", AR_K_rollwon = "Item gewonnen (Würfeln)", AR_K_levelup = "Mein Level-up",
    AR_K_guildlevel = "Level-up in der Gilde", AR_K_nearlevel = "Level-up in der Umgebung", AR_K_invite = "Gruppeneinladung",
    AR_K_trade = "Handelsanfrage", AR_K_duel = "Duellanfrage", AR_K_rez = "Wiederbelebt worden",
    AR_K_groupjoin = "Jemand tritt der Gruppe bei", AR_K_guildjoin = "Neues Gildenmitglied", AR_K_boss = "Boss besiegt",
    AR_MATCH_ITEM = "Itemnamen (leer = jedes Item)", AR_MATCH_BOSS = "Bossnamen (leer = jeder Boss)",
    AR_COND_SELF = "Bedingungen über dich", AR_COND_OTHER = "Bedingungen über den anderen",
    AR_C_COMBAT = "Im Kampf", AR_C_INSTANCE = "In Instanz",
    AR_O_GUILD = "Gildenmitglied", AR_O_PARTY = "Gruppenmitglied", AR_O_FRIEND = "Freund",
    AR_TIME = "Uhrzeit von - bis", AR_TIME_INFO2 = "Nur zwischen diesen Zeiten (HH:MM), z. B. 22:00 bis 06:00 über Mitternacht. Leer = immer.",
    AR_ONCE = "Nur einmal pro Sitzung je Spieler",
    AR_ACTION = "Aktion", AR_ACT_TEXT = "Text", AR_ACT_EMOTE = "Emote", AR_ACT_BOTH = "Text und Emote",
    AR_DEST = "Text geht an", AR_DEST_SAME = "Denselben Chat", AR_DEST_WHISPER = "Flüstern an den Spieler",
    AR_DEST_GUILD = "Gilde", AR_DEST_GROUP = "Gruppe bzw. Schlachtzug",
    AR_EMOTE = "Emote", AR_EMOTE_TARGET = "Auf den Spieler richten",
    AR_EMOTE_INFO = "Voice-Emotes: Dein Charakter spricht. Blizzard erlaubt sie ohne Tastendruck (höchstens etwa 4 pro Sekunde). Eigener Emote-Text (/e ...) ist wie Sagen gesperrt.",
    AR_DELAY = "Verzögerung von - bis (s)",
    AR_REPLIES_INFO2 = "Je Zeile eine Antwort, eine wird zufällig gewählt. Platzhalter: {name} Vorname des anderen, {me} dein Vorname, {level} Stufe, {item} gewonnenes Item, {boss} Boss, {spell} Buff, {zone} Gebiet, {class} deine Klasse, {time} Uhrzeit. Höchstens 255 Zeichen.",
    AR_TEMPLATE = "Vorlage ...", AR_EXPORT = "Export", AR_IMPORT = "Import",
    AR_CODE_EXPORT = "Export: %s", AR_CODE_IMPORT = "Regeln importieren",
    AR_CODE_INFO = "Code mit Strg+C kopieren und teilen. Zum Importieren einen Code einfügen und „Übernehmen“ drücken. Importierte Regeln sind erst aus, damit du sie prüfen kannst.",
    AR_CODE_APPLY = "Übernehmen", AR_IMPORTED = "%d Regel(n) übernommen (ausgeschaltet, bitte prüfen).", AR_IMPORT_ERR = "Import fehlgeschlagen: %s",
    AR_T_PORT = "Hexer: kein Porten", AR_T_PORT_M = "port und gold\nport und bezahl\nsummon\nbeschwör", AR_T_PORT_R = "Sorry {name}, ich porte gerade nicht.",
    AR_T_GN = "Gute Nacht in der Gilde", AR_T_GN_M = "gute nacht\ngn8\ngn", AR_T_GN_R = "Gute Nacht!\nSchlaf gut!",
    AR_T_GLVL = "Level-up gratulieren (Gilde)", AR_T_GLVL_R = "Grats zu Stufe {level}, {name}!",
    AR_T_LVL = "Mein Level-up", AR_T_LVL_R = "Stufe {level}!",
    AR_T_BUFF = "Danke für den Buff", AR_T_BUFF_R = "Danke für {spell}, {name}!",
    AR_T_GJOIN = "Willkommen in der Gilde", AR_T_GJOIN_R = "Willkommen in der Gilde, {name}!",
    AR_T_PJOIN = "Willkommen in der Gruppe", AR_T_PJOIN_R = "Hallo {name}!",
    AR_T_REZ = "Danke fürs Rezzen", AR_T_REZ_R = "Danke fürs Wiederbeleben, {name}!",
    AR_T_DUEL = "Duelle ablehnen", AR_T_DUEL_R = "Keine Duelle bitte, danke!",
    AR_T_BOSS = "gg nach dem Boss", AR_T_BOSS_R = "gg!\nGut gemacht!",
    AR_T_INVITE = "Beschäftigt (DND)", AR_T_INVITE_R = "Bin gerade beschäftigt, danke!",
    AR_T_FRIEND = "Freunde begrüßen", AR_T_FRIEND_R = "Hallo {name}!",
})

------------------------------------------------------------------------
-- Fenster für Export- und Import-Code
------------------------------------------------------------------------

local codeWin

local function BuildCode()
    if codeWin then return codeWin end
    local f = UI.CreatePanel(G.UIParent, "bg", "gold")
    f:SetSize(560, 260)
    f:SetPoint("CENTER", G.UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    Movable(f)
    f:Hide()
    f.title = UI.CreateLabel(f, "", { font = "heading", size = 14, color = "goldLight" })
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    Info(f, function() return f.title:GetText() end, L().AR_CODE_INFO):SetPoint("LEFT", f.title, "RIGHT", 6, 0)
    local x = UI.CreateButton(f, "X", 22, 22, function() f:Hide() end)
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    f.area = UI.CreateTextArea(f, 532, 160)
    f.area:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    f.area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 48)
    local all = UI.CreateButton(f, L().AR_REPORT_ALL, 140, 26, function() f.area:SelectAll() end)
    all:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    f.apply = UI.CreateButton(f, L().AR_CODE_APPLY, 140, 26, function()
        local n, err = AR.ImportRules(f.area:GetText() or "")
        if n then
            FW:Print(string.format(L().AR_IMPORTED, n))
            f:Hide()
            if f.onDone then f.onDone() end
        else
            FW:Print(string.format(L().AR_IMPORT_ERR, tostring(L()[err] or err)))
        end
    end, "primary")
    f.apply:SetPoint("LEFT", all, "RIGHT", 8, 0)
    local close = UI.CreateButton(f, L().AR_REPORT_CLOSE, 110, 26, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    codeWin = f
    return f
end

function AR.ShowCode(mode, rule, onDone)
    local f = BuildCode()
    f.onDone = onDone
    if mode == "export" then
        local code, err = AR.ExportRules({ rule })
        f.title:SetText(string.format(L().AR_CODE_EXPORT, rule.name))
        f.area:SetText(code or tostring(err))
        f.apply:Hide()
    else
        f.title:SetText(L().AR_CODE_IMPORT)
        f.area:SetText("")
        f.apply:Show()
    end
    f:Show()
end

------------------------------------------------------------------------
-- Reiter
------------------------------------------------------------------------

local LIST_W = 230
local LABEL_W = 170

local function BuildTab(content)
    local Lx = L()
    local root = CreateFrame("Frame", nil, content)
    root:SetAllPoints(content)

    -- oben: Hauptschalter, Regeln | Verlauf
    local master = UI.CreateCheckbox(root, Lx.AR_ON, function() return AR.DB().on end, function(v) AR.DB().on = v and true or false end)
    master:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    Info(root, Lx.TAB_AUTOREPLY, Lx.AR_ON_INFO):SetPoint("LEFT", master.label, "RIGHT", 6, 0)
    local bLog = UI.CreateButton(root, Lx.AR_LOG, 110, 24)
    bLog:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    local bRules = UI.CreateButton(root, Lx.AR_RULES, 110, 24)
    bRules:SetPoint("RIGHT", bLog, "LEFT", -6, 0)

    local rulesView = CreateFrame("Frame", nil, root)
    rulesView:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -34)
    rulesView:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    local logView = CreateFrame("Frame", nil, root)
    logView:SetAllPoints(rulesView)
    logView:Hide()

    --------------------------------------------------------------
    -- Liste links: Neue Regel, Vorlage, Regeln, Export/Import
    --------------------------------------------------------------
    local left = UI.CreatePanel(rulesView, "card", "bronze")
    left:SetPoint("TOPLEFT", rulesView, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", rulesView, "BOTTOMLEFT", 0, 0)
    left:SetWidth(LIST_W)
    local bNew = UI.CreateButton(left, Lx.AR_NEW, LIST_W - 12, 24, nil, "primary")
    bNew:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -6)
    local Load, RefreshList, Save
    local cur
    local tplDD = UI.CreateDropdown(left, LIST_W - 12, 24, {
        getOptions = function()
            local o = {}
            for _, t in ipairs(AR.TEMPLATES) do o[#o + 1] = { value = t.id, text = Lx["AR_T_" .. t.id] or t.id } end
            return o
        end,
        textOf = function(v) if not v then return Lx.AR_TEMPLATE end return Lx["AR_T_" .. tostring(v)] or Lx.AR_TEMPLATE end,
        onChange = function(v)
            if not v then return end
            if cur and Save then Save(true) end
            local r = AR.FromTemplate(v)
            if r then Load(r) RefreshList() end
        end,
    })
    tplDD:SetPoint("TOPLEFT", bNew, "BOTTOMLEFT", 0, -6)
    local function ResetTpl() tplDD:SetValue(nil) if tplDD.SetLabel then tplDD:SetLabel(Lx.AR_TEMPLATE) end end
    ResetTpl()
    local bExport = UI.CreateButton(left, Lx.AR_EXPORT, math.floor((LIST_W - 18) / 2), 22)
    bExport:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 6, 6)
    local bImport = UI.CreateButton(left, Lx.AR_IMPORT, math.floor((LIST_W - 18) / 2), 22)
    bImport:SetPoint("LEFT", bExport, "RIGHT", 6, 0)
    local listScroll = UI.CreateScrollFrame(left)
    listScroll:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -68)
    listScroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -4, 34)
    local listButtons = {}
    local none = UI.CreateLabel(rulesView, Lx.AR_NONE, { size = 12, color = "textDim" })
    none:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, -8)

    --------------------------------------------------------------
    -- Formular rechts
    --------------------------------------------------------------
    local formScroll = UI.CreateScrollFrame(rulesView)
    formScroll:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
    formScroll:SetPoint("BOTTOMRIGHT", rulesView, "BOTTOMRIGHT", 0, 0)
    local form = formScroll.child
    local stack = UI.CreateStack(form, { gap = 6, pad = 8 })
    stack.onHeight = function(h) formScroll:SetContentHeight(h + 16) end

    -- Zustand des Formulars; von Anfang an mit allen Tabellen, die Kaestchen fragen ihn schon beim Bau ab (0.59.1)
    local function EmptyState()
        local st = { on = true, kind = "chat", whole = false, report = false, once = false, src = {}, cond = {},
            classes = {}, classMode = "all", char = nil, action = "text", dest = "same", emote = "THANK", emoteTarget = true }
        for _, k in ipairs(AR.CONDS) do st.cond[k] = "any" end
        for _, k in ipairs(AR.OTHER) do st.cond[k] = "any" end
        return st
    end
    local state = EmptyState()
    local Layout

    local function Row(height)
        local r = CreateFrame("Frame", nil, form)
        r:SetHeight(height or 24)
        return r
    end
    local function LabeledRow(text, widget, height)
        local r = Row(height)
        local l = UI.CreateLabel(r, text, { size = 12 })
        l:SetPoint("LEFT", r, "LEFT", 0, 0)
        widget:SetParent(r)
        widget:ClearAllPoints()
        widget:SetPoint("LEFT", r, "LEFT", LABEL_W, 0)
        r.label = l
        return r
    end
    local function Head(text, info)
        local r = Row(20)
        local l = UI.CreateLabel(r, text, { size = 13, color = "gold" })
        l:SetPoint("LEFT", r, "LEFT", 0, 0)
        r.label = l
        if info then r.info = Info(r, text, info) r.info:SetPoint("LEFT", l, "RIGHT", 6, 0) end
        return r
    end
    local function Dropdown(parent, width, options, onChange)
        local function Opts() return type(options) == "function" and options() or options end
        return UI.CreateDropdown(parent or form, width, 22, {
            getOptions = function()
                local o = {}
                for _, v in ipairs(Opts()) do o[#o + 1] = { value = v[1], text = v[2] } end
                return o
            end,
            textOf = function(val)
                for _, v in ipairs(Opts()) do if v[1] == val then return v[2] end end
                return tostring(val or "")
            end,
            onChange = onChange,
        })
    end
    local function Add(w, opts) stack:Add(w, opts) return w end
    local function SetShownStack(w, show)
        w.stackHidden = not show
        if show then w:Show() else w:Hide() end
    end

    -- Name, an/aus, Auslöser
    local nameBox = Edit(form, 280)
    Add(LabeledRow(Lx.AR_NAME, nameBox), { height = 24, gap = 4, stretch = true })
    local onCb = Add(UI.CreateCheckbox(form, Lx.AR_RULE_ON, function() return state.on end, function(v) state.on = v and true or false end), { fit = true, gap = 4 })
    local kindOpts = {}
    for _, k in ipairs(AR.KINDS) do kindOpts[#kindOpts + 1] = { k, Lx["AR_K_" .. k] or k } end
    local kindDD = Dropdown(nil, 260, kindOpts, function(v) state.kind = v Layout() end)
    local kindRow = Add(LabeledRow(Lx.AR_TRIGGER, kindDD), { height = 24, gap = 6, stretch = true })
    Info(kindRow, Lx.AR_TRIGGER, Lx.AR_TRIGGER_INFO):SetPoint("LEFT", kindDD, "RIGHT", 6, 0)

    -- Woher (nur Chat)
    local srcHead = Add(Head(Lx.AR_SRC), { height = 20, gap = 12, stretch = true })
    local srcBoxes, srcRows = {}, {}
    for rowN = 1, 2 do
        local r = Row(24)
        for col = 1, 3 do
            local key = AR.SOURCES[(rowN - 1) * 3 + col]
            local cb = UI.CreateCheckbox(r, Lx["AR_SRC_" .. key], function() return state.src[key] == true end,
                function(v) state.src[key] = v and true or nil end)
            cb:SetPoint("LEFT", r, "LEFT", (col - 1) * 160, 0)
            cb:SetWidth(150)
            srcBoxes[#srcBoxes + 1] = cb
        end
        srcRows[rowN] = Add(r, { height = 24, gap = 2, stretch = true })
    end

    -- Filter
    local matchHead = Add(Head(Lx.AR_MATCH, Lx.AR_MATCH_INFO), { height = 20, gap = 12, stretch = true })
    local matchArea = Add(UI.CreateTextArea(form, 400, 64), { height = 64, gap = 4, stretch = true })
    local neverBox = Edit(form, 300)
    local neverRow = LabeledRow(Lx.AR_NEVER, neverBox)
    Info(neverRow, Lx.AR_NEVER, Lx.AR_NEVER_INFO):SetPoint("LEFT", neverBox, "RIGHT", 6, 0)
    Add(neverRow, { height = 24, gap = 6, stretch = true })
    local wholeCb = Add(UI.CreateCheckbox(form, Lx.AR_WHOLE, function() return state.whole end, function(v) state.whole = v and true or false end), { fit = true, gap = 4 })

    -- Bedingungen über dich
    local condOpts = { { "any", Lx.AR_ANY }, { "yes", Lx.AR_YES }, { "no", Lx.AR_NO } }
    local condDDs = {}
    local condLabels = { afk = Lx.AR_C_AFK, dnd = Lx.AR_C_DND, group = Lx.AR_C_GROUP, raid = Lx.AR_C_RAID,
        combat = Lx.AR_C_COMBAT, instance = Lx.AR_C_INSTANCE, guild = Lx.AR_O_GUILD, party = Lx.AR_O_PARTY, friend = Lx.AR_O_FRIEND }
    local function CondRows(keys)
        local rows = {}
        for rowN = 1, math.ceil(#keys / 2) do
            local r = Row(24)
            for col = 1, 2 do
                local key = keys[(rowN - 1) * 2 + col]
                if key then
                    local l = UI.CreateLabel(r, condLabels[key], { size = 12 })
                    l:SetPoint("LEFT", r, "LEFT", (col - 1) * 260, 0)
                    local dd = Dropdown(r, 120, condOpts, function(v) state.cond[key] = v end)
                    dd:SetPoint("LEFT", r, "LEFT", (col - 1) * 260 + 120, 0)
                    condDDs[key] = dd
                end
            end
            rows[#rows + 1] = Add(r, { height = 24, gap = 4, stretch = true })
        end
        return rows
    end
    Add(Head(Lx.AR_COND_SELF), { height = 20, gap = 12, stretch = true })
    CondRows(AR.CONDS)
    local otherHead = Add(Head(Lx.AR_COND_OTHER), { height = 20, gap = 10, stretch = true })
    local otherRows = CondRows(AR.OTHER)

    -- Uhrzeit, Klassen, Charakter, einmal
    local timeRow = Row(24)
    local tl = UI.CreateLabel(timeRow, Lx.AR_TIME, { size = 12 })
    tl:SetPoint("LEFT", timeRow, "LEFT", 0, 0)
    local tFrom = Edit(timeRow, 60) tFrom.edit:SetMaxLetters(5)
    tFrom:SetPoint("LEFT", timeRow, "LEFT", LABEL_W, 0)
    local tDash = UI.CreateLabel(timeRow, "–", { size = 12, color = "textDim" })
    tDash:SetPoint("LEFT", tFrom, "RIGHT", 6, 0)
    local tTo = Edit(timeRow, 60) tTo.edit:SetMaxLetters(5)
    tTo:SetPoint("LEFT", tFrom, "RIGHT", 20, 0)
    Info(timeRow, Lx.AR_TIME, Lx.AR_TIME_INFO2):SetPoint("LEFT", tTo, "RIGHT", 6, 0)
    Add(timeRow, { height = 24, gap = 10, stretch = true })
    local classDD = Dropdown(nil, 160, { { "all", Lx.AR_CL_ALL }, { "only", Lx.AR_CL_ONLY }, { "not", Lx.AR_CL_NOT } },
        function(v) state.classMode = v Layout() end)
    Add(LabeledRow(Lx.AR_CLASSES, classDD), { height = 24, gap = 6, stretch = true })
    local classRows, classBoxes = {}, {}
    for rowN = 1, 3 do
        local r = Row(24)
        for col = 1, 3 do
            local token = AR.CLASSES[(rowN - 1) * 3 + col]
            local lname = (G.LOCALIZED_CLASS_NAMES_MALE and G.LOCALIZED_CLASS_NAMES_MALE[token]) or token
            local cb = UI.CreateCheckbox(r, lname, function() return state.classes[token] == true end,
                function(v) state.classes[token] = v and true or nil end)
            cb:SetPoint("LEFT", r, "LEFT", (col - 1) * 160, 0)
            cb:SetWidth(150)
            classBoxes[#classBoxes + 1] = cb
        end
        classRows[rowN] = Add(r, { height = 24, gap = 2, stretch = true })
    end
    local charDD = Dropdown(nil, 260, function()
        return { { "all", Lx.AR_CHAR_ALL }, { "me", string.format(Lx.AR_CHAR_ONLY, AR.CharKey()) },
            state.char and state.char ~= AR.CharKey() and { "other", string.format(Lx.AR_CHAR_ONLY, state.char) } or nil }
    end, function(v)
        if v == "all" then state.char = nil elseif v == "me" then state.char = AR.CharKey() end
    end)
    Add(LabeledRow(Lx.AR_CHAR, charDD), { height = 24, gap = 6, stretch = true })
    local onceCb = Add(UI.CreateCheckbox(form, Lx.AR_ONCE, function() return state.once end, function(v) state.once = v and true or false end), { fit = true, gap = 4 })

    -- Aktion
    local actHead = Add(Head(Lx.AR_ACTION), { height = 20, gap = 12, stretch = true })
    local actDD = Dropdown(nil, 200, { { "text", Lx.AR_ACT_TEXT }, { "emote", Lx.AR_ACT_EMOTE }, { "both", Lx.AR_ACT_BOTH } },
        function(v) state.action = v Layout() end)
    Add(LabeledRow(Lx.AR_ACTION, actDD), { height = 24, gap = 4, stretch = true })
    local function DestOpts()
        local k = state.kind or "chat"
        local o = {}
        if k == "chat" then o[#o + 1] = { "same", Lx.AR_DEST_SAME } end
        if not AR.NOPERSON[k] then o[#o + 1] = { "whisper", Lx.AR_DEST_WHISPER } end
        o[#o + 1] = { "guild", Lx.AR_DEST_GUILD }
        o[#o + 1] = { "group", Lx.AR_DEST_GROUP }
        return o
    end
    local destDD = Dropdown(nil, 220, DestOpts, function(v) state.dest = v end)
    local destRow = Add(LabeledRow(Lx.AR_DEST, destDD), { height = 24, gap = 4, stretch = true })
    local emoteOpts = {}
    for _, e in ipairs(AR.EMOTES) do emoteOpts[#emoteOpts + 1] = { e, "/" .. e:lower() } end
    local emoteDD = Dropdown(nil, 160, emoteOpts, function(v) state.emote = v end)
    local emoteRow = LabeledRow(Lx.AR_EMOTE, emoteDD)
    local emoteTarget = UI.CreateCheckbox(emoteRow, Lx.AR_EMOTE_TARGET, function() return state.emoteTarget end,
        function(v) state.emoteTarget = v and true or false end)
    emoteTarget:SetPoint("LEFT", emoteDD, "RIGHT", 12, 0)
    Info(emoteRow, Lx.AR_EMOTE, Lx.AR_EMOTE_INFO):SetPoint("LEFT", emoteTarget.label or emoteTarget, "RIGHT", 6, 0)
    Add(emoteRow, { height = 24, gap = 4, stretch = true })

    -- Antworten
    local replyHead = Add(Head(Lx.AR_REPLIES, Lx.AR_REPLIES_INFO2), { height = 20, gap = 12, stretch = true })
    local replyArea = Add(UI.CreateTextArea(form, 400, 80), { height = 80, gap = 4, stretch = true })

    -- Zeiten
    local numBoxes = {}
    local function NumBox(parent, key, w)
        local b = Edit(parent, w or 70)
        b.edit:SetNumeric(true)
        b.edit:SetMaxLetters(6)
        numBoxes[key] = b
        return b
    end
    local delayRow = Row(24)
    local dl = UI.CreateLabel(delayRow, Lx.AR_DELAY, { size = 12 })
    dl:SetPoint("LEFT", delayRow, "LEFT", 0, 0)
    local dMin = NumBox(delayRow, "delayMin", 50)
    dMin:SetPoint("LEFT", delayRow, "LEFT", LABEL_W, 0)
    local dDash = UI.CreateLabel(delayRow, "–", { size = 12, color = "textDim" })
    dDash:SetPoint("LEFT", dMin, "RIGHT", 6, 0)
    local dMax = NumBox(delayRow, "delayMax", 50)
    dMax:SetPoint("LEFT", dMin, "RIGHT", 20, 0)
    Add(delayRow, { height = 24, gap = 12, stretch = true })
    local cdRow = Add(LabeledRow(Lx.AR_CD_RULE, NumBox(form, "cdRule")), { height = 24, gap = 4, stretch = true })
    Info(cdRow, Lx.AR_CD_RULE, Lx.AR_TIME_INFO):SetPoint("LEFT", numBoxes.cdRule, "RIGHT", 6, 0)
    local cdpRow = Add(LabeledRow(Lx.AR_CD_PLAYER, NumBox(form, "cdPlayer")), { height = 24, gap = 4, stretch = true })
    local ignRow = Add(LabeledRow(Lx.AR_IGNORE_AFTER, NumBox(form, "ignoreAfter")), { height = 24, gap = 4, stretch = true })
    local reportCb = Add(UI.CreateCheckbox(form, Lx.AR_REPORT, function() return state.report end, function(v) state.report = v and true or false end), { fit = true, gap = 8 })

    -- Test
    local testBox = Edit(form, 300)
    local testRow = LabeledRow(Lx.AR_TEST, testBox)
    local testHint = UI.CreateLabel(testBox, Lx.AR_TEST_HINT, { size = 11, color = "textDim" })
    testHint:SetPoint("LEFT", testBox, "LEFT", 8, 0)
    testHint:SetPoint("RIGHT", testBox, "RIGHT", -8, 0)
    testHint:SetWordWrap(false)
    local testRes = UI.CreateLabel(testRow, "", { size = 12 })
    testRes:SetPoint("LEFT", testBox, "RIGHT", 8, 0)
    Add(testRow, { height = 24, gap = 14, stretch = true })

    -- Speichern / Löschen
    local btnRow = Row(28)
    local bSave = UI.CreateButton(btnRow, Lx.AR_SAVE, 130, 26, nil, "primary")
    bSave:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
    local bDel = UI.CreateButton(btnRow, Lx.AR_DELETE, 110, 26, nil, "danger")
    bDel:SetPoint("LEFT", bSave, "RIGHT", 8, 0)
    local saved = UI.CreateLabel(btnRow, "", { size = 11, color = "textDim" })
    saved:SetPoint("LEFT", bDel, "RIGHT", 10, 0)
    Add(btnRow, { height = 28, gap = 14, stretch = true })

    -- Sichtbarkeit je nach Auslöser, Aktion und Klassenwahl
    Layout = function()
        local k = state.kind or "chat"
        local chat = k == "chat"
        local person = not AR.NOPERSON[k]
        local filtered = AR.FILTERED[k] and true or false
        SetShownStack(srcHead, chat)
        for _, r in ipairs(srcRows) do SetShownStack(r, chat) end
        SetShownStack(matchHead, filtered)
        SetShownStack(matchArea, filtered)
        SetShownStack(neverRow, filtered)
        SetShownStack(wholeCb, filtered)
        SetShownStack(testRow, filtered)
        matchHead.label:SetText((k == "buff" and Lx.AR_MATCH_BUFF) or (k == "rollwon" and Lx.AR_MATCH_ITEM)
            or (k == "boss" and Lx.AR_MATCH_BOSS) or Lx.AR_MATCH)
        SetShownStack(otherHead, person)
        for _, r in ipairs(otherRows) do SetShownStack(r, person) end
        SetShownStack(onceCb, person)
        SetShownStack(cdpRow, person)
        SetShownStack(ignRow, chat)
        SetShownStack(reportCb, chat)
        local act = state.action or "text"
        local text, emote = act ~= "emote", act ~= "text"
        SetShownStack(destRow, text)
        SetShownStack(replyHead, text)
        SetShownStack(replyArea, text)
        SetShownStack(emoteRow, emote)
        if emoteTarget then if person then emoteTarget:Show() else emoteTarget:Hide() end end
        -- Ziel der Antwort muss zum Auslöser passen
        local valid = false
        for _, o in ipairs(DestOpts()) do
            if o[1] == state.dest then valid = true end
        end
        if not valid then
            state.dest = chat and "same" or (person and "whisper" or "group")
            destDD:SetValue(state.dest)
        end
        for _, r in ipairs(classRows) do SetShownStack(r, state.classMode and state.classMode ~= "all") end
        stack:Layout()
    end

    -- Formular füllen / auslesen
    Load = function(r)
        cur = r
        bDel.armed = nil
        bDel:SetLabel(Lx.AR_DELETE)
        saved:SetText("")
        if not r then state = EmptyState() formScroll:Hide() none:Show() return end
        AR.Upgrade(r)
        none:Hide()
        formScroll:Show()
        state = EmptyState()
        state.on = r.on ~= false
        state.kind = r.kind
        state.whole = r.whole and true or false
        state.report = r.report and true or false
        state.once = r.once and true or false
        state.classMode = r.classMode or "all"
        state.char = r.char
        state.action = r.action or "text"
        state.dest = r.dest or "same"
        state.emote = r.emote or "THANK"
        state.emoteTarget = r.emoteTarget ~= false
        for k2, v in pairs(r.src or {}) do state.src[k2] = v end
        for k2, v in pairs(r.cond or {}) do state.cond[k2] = v end
        for k2, v in pairs(r.classes or {}) do state.classes[k2] = v end
        nameBox:SetText(r.name)
        matchArea:SetText(r.match or "")
        neverBox:SetText(r.never or "")
        replyArea:SetText(r.replies or "")
        tFrom:SetText(r.timeFrom or "")
        tTo:SetText(r.timeTo or "")
        for _, key in ipairs({ "cdRule", "cdPlayer", "ignoreAfter", "delayMin", "delayMax" }) do
            numBoxes[key]:SetText(tostring(r[key] or 0))
        end
        kindDD:SetValue(state.kind)
        actDD:SetValue(state.action)
        destDD:SetValue(state.dest)
        emoteDD:SetValue(state.emote)
        classDD:SetValue(state.classMode)
        charDD:SetValue(not state.char and "all" or (state.char == AR.CharKey() and "me" or "other"))
        for key, dd in pairs(condDDs) do dd:SetValue(state.cond[key] or "any") end
        onCb:Refresh() wholeCb:Refresh() reportCb:Refresh() onceCb:Refresh() emoteTarget:Refresh()
        for _, cb in ipairs(srcBoxes) do cb:Refresh() end
        for _, cb in ipairs(classBoxes) do cb:Refresh() end
        testBox:SetText("")
        testRes:SetText("")
        Layout()
    end

    Save = function(quiet)
        local r = cur
        if not r or not AR.Find(r.id) then return end
        local name = nameBox:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        r.name = name ~= "" and name or r.name
        for _, key in ipairs({ "on", "kind", "src", "whole", "cond", "classMode", "classes", "char", "report", "once",
            "action", "dest", "emote", "emoteTarget" }) do
            r[key] = state[key]
        end
        r.match = matchArea:GetText() or ""
        r.never = neverBox:GetText()
        r.replies = replyArea:GetText() or ""
        r.timeFrom = AR.ToMin(tFrom:GetText()) and tFrom:GetText() or ""
        r.timeTo = AR.ToMin(tTo:GetText()) and tTo:GetText() or ""
        for _, key in ipairs({ "cdRule", "cdPlayer", "ignoreAfter", "delayMin", "delayMax" }) do
            r[key] = tonumber(numBoxes[key]:GetText()) or 0
        end
        if r.delayMax < r.delayMin then r.delayMax = r.delayMin end
        -- Zustand frisch laden, damit Regel und Formular keine Tabellen teilen
        Load(r)
        if not quiet then saved:SetText(Lx.AR_SAVED) end
        FW:Fire("AUTOREPLY_CHANGED")
    end

    RefreshList = function()
        local rules = AR.DB().rules
        for i, r in ipairs(rules) do
            local b = listButtons[i]
            if not b then
                b = UI.CreateButton(listScroll.child, "", LIST_W - 28, 24, function(self)
                    if cur and cur.id ~= self.ruleId then Save(true) end
                    Load(AR.Find(self.ruleId))
                    RefreshList()
                end)
                b:SetPoint("TOPLEFT", listScroll.child, "TOPLEFT", 0, -(i - 1) * 27)
                listButtons[i] = b
            end
            b.ruleId = r.id
            local tag = (r.kind and r.kind ~= "chat") and ("|cff9a9aa3[" .. (Lx["AR_K_" .. r.kind] or r.kind) .. "]|r ") or ""
            b:SetLabel(tag .. tostring(r.name))
            b:SetStyle(cur and cur.id == r.id and "primary" or "default")
            b:SetAlpha(r.on == false and 0.5 or 1)
            b:Show()
        end
        for i = #rules + 1, #listButtons do listButtons[i]:Hide() end
        listScroll:SetContentHeight(#rules * 27 + 4)
        if #rules == 0 then Load(nil) end
        ResetTpl()
    end

    bNew:SetScript("OnClick", function()
        if cur then Save(true) end
        Load(AR.NewRule("chat"))
        RefreshList()
    end)
    bSave:SetScript("OnClick", function() Save(false) RefreshList() end)
    bDel:SetScript("OnClick", function()
        if not cur then return end
        if not bDel.armed then
            bDel.armed = true
            bDel:SetLabel(Lx.AR_DELETE_SURE)
            return
        end
        local id = cur.id
        cur = nil
        AR.Delete(id)
        Load(AR.DB().rules[1])
        RefreshList()
    end)
    bExport:SetScript("OnClick", function()
        if not cur then return end
        Save(true)
        AR.ShowCode("export", cur)
    end)
    bImport:SetScript("OnClick", function()
        AR.ShowCode("import", nil, function() RefreshList() end)
    end)
    testBox.edit:SetScript("OnTextChanged", function()
        local t = testBox:GetText()
        if t == "" then testHint:Show() testRes:SetText("") return end
        testHint:Hide()
        local probe = { match = matchArea:GetText(), never = neverBox:GetText(), whole = state.whole }
        if not AR.Matches(probe, t) then testRes:SetText(Lx.AR_TEST_NO) return end
        local tmp = { kind = state.kind, cond = state.cond, classMode = state.classMode, classes = state.classes,
            char = state.char, timeFrom = tFrom:GetText(), timeTo = tTo:GetText() }
        local ok, why = AR.CondOK(tmp)
        testRes:SetText(ok and Lx.AR_TEST_YES or string.format(Lx.AR_TEST_COND, tostring(why)))
    end)

    --------------------------------------------------------------
    -- Verlauf
    --------------------------------------------------------------
    local bClear = UI.CreateButton(logView, Lx.AR_LOG_CLEAR, 150, 24)
    bClear:SetPoint("TOPLEFT", logView, "TOPLEFT", 0, 0)
    local logEmpty = UI.CreateLabel(logView, Lx.AR_LOG_EMPTY, { size = 12, color = "textDim" })
    logEmpty:SetPoint("TOPLEFT", logView, "TOPLEFT", 4, -40)
    local logScroll = UI.CreateScrollFrame(logView)
    logScroll:SetPoint("TOPLEFT", logView, "TOPLEFT", 0, -32)
    logScroll:SetPoint("BOTTOMRIGHT", logView, "BOTTOMRIGHT", 0, 0)
    local logRows = {}
    local function RefreshLog()
        local log = AR.DB().log
        for i, e in ipairs(log) do
            local r = logRows[i]
            if not r then
                r = CreateFrame("Frame", nil, logScroll.child)
                r:SetHeight(36)
                r:SetPoint("TOPLEFT", logScroll.child, "TOPLEFT", 0, -(i - 1) * 38)
                r:SetPoint("RIGHT", logScroll, "RIGHT", -14, 0)
                r.l1 = UI.CreateLabel(r, "", { size = 11, color = "textDim" })
                r.l1:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -2)
                r.l1:SetPoint("RIGHT", r, "RIGHT", -4, 0)
                r.l1:SetWordWrap(false)
                r.l2 = UI.CreateLabel(r, "", { size = 12 })
                r.l2:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -18)
                r.l2:SetPoint("RIGHT", r, "RIGHT", -4, 0)
                r.l2:SetWordWrap(false)
                logRows[i] = r
            end
            local ts = G.date and G.date("%d.%m. %H:%M", e.t) or tostring(e.t)
            r.l1:SetText(string.format("%s  ·  %s  ·  %s  ·  %s%s", ts, tostring(e.rule), tostring(e.who), tostring(e.src),
                e.ok == false and "  |cffff6060(!)|r" or ""))
            local msg = tostring(e.msg or "")
            r.l2:SetText((msg ~= "" and ("„" .. msg .. "“  ") or "") .. "|cffffd100->|r  " .. tostring(e.reply))
            r:Show()
        end
        for i = #log + 1, #logRows do logRows[i]:Hide() end
        logScroll:SetContentHeight(#log * 38 + 4)
        if #log == 0 then logEmpty:Show() else logEmpty:Hide() end
    end
    bClear:SetScript("OnClick", function() local log = AR.DB().log for i = #log, 1, -1 do log[i] = nil end RefreshLog() end)

    local function ShowView(which)
        if which == "log" then
            if cur then Save(true) end
            rulesView:Hide() logView:Show() RefreshLog()
        else
            logView:Hide() rulesView:Show() RefreshList()
        end
        bRules:SetStyle(which == "log" and "default" or "primary")
        bLog:SetStyle(which == "log" and "primary" or "default")
    end
    bRules:SetScript("OnClick", function() ShowView("rules") end)
    bLog:SetScript("OnClick", function() ShowView("log") end)

    FW:On("AUTOREPLY_LOG", function() if logView:IsVisible() then RefreshLog() end end)
    root:SetScript("OnHide", function() if cur and AR.Find(cur.id) then Save(true) end end)

    function root.Refresh()
        master:Refresh()
        if not cur then Load(AR.DB().rules[1]) end
        ShowView(logView:IsShown() and "log" or "rules")
    end
    root.Load = function(r) Load(r) end
    root.Save = function(q) Save(q) end
    root.State = function() return state end
    return root
end

if UI.RegisterTab then
    local page
    UI:RegisterTab("autoreply", {
        label = function() return FW.L.TAB_AUTOREPLY end,
        order = 870,
        build = function(content)
            page = BuildTab(content)
            return page
        end,
        onShow = function() if page and page.Refresh then page.Refresh() end end,
    })
end

AR.BuildTab = BuildTab
