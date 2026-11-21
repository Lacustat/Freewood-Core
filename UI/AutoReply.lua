-- Freewood-Core: Reiter "Auto-Antwort" (seit 0.59.0), Fenster "Ignorieren?" und "Melden"
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
    local k = rule.id .. "|" .. AR.Lower(who)
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
-- Reiter
------------------------------------------------------------------------

local LIST_W = 220
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
    bLog:SetPoint("TOPRIGHT", root, "TOPRIGHT", -120, 0)
    local bRules = UI.CreateButton(root, Lx.AR_RULES, 110, 24)
    bRules:SetPoint("RIGHT", bLog, "LEFT", -6, 0)

    local rulesView = CreateFrame("Frame", nil, root)
    rulesView:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -34)
    rulesView:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    local logView = CreateFrame("Frame", nil, root)
    logView:SetAllPoints(rulesView)
    logView:Hide()

    --------------------------------------------------------------
    -- Regeln: Liste links
    --------------------------------------------------------------
    local left = UI.CreatePanel(rulesView, "card", "bronze")
    left:SetPoint("TOPLEFT", rulesView, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", rulesView, "BOTTOMLEFT", 0, 0)
    left:SetWidth(LIST_W)
    local bNew = UI.CreateButton(left, Lx.AR_NEW, LIST_W - 12, 24, nil, "primary")
    bNew:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -6)
    local listScroll = UI.CreateScrollFrame(left)
    listScroll:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -36)
    listScroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -4, 6)
    local listButtons = {}
    local none = UI.CreateLabel(rulesView, Lx.AR_NONE, { size = 12, color = "textDim" })
    none:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, -8)

    --------------------------------------------------------------
    -- Regeln: Formular rechts
    --------------------------------------------------------------
    local formScroll = UI.CreateScrollFrame(rulesView)
    formScroll:SetPoint("TOPLEFT", left, "TOPRIGHT", 14, 0)
    formScroll:SetPoint("BOTTOMRIGHT", rulesView, "BOTTOMRIGHT", 0, 0)
    local form = formScroll.child
    local stack = UI.CreateStack(form, { gap = 6, pad = 8 })
    stack.onHeight = function(h) formScroll:SetContentHeight(h + 16) end

    local cur      -- bearbeitete Regel
    local state = {}

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
        if info then Info(r, text, info):SetPoint("LEFT", l, "RIGHT", 6, 0) end
        return r
    end
    local function Dropdown(width, options, onChange)
        return UI.CreateDropdown(form, width, 22, {
            getOptions = function()
                local o = {}
                for _, v in ipairs(type(options) == "function" and options() or options) do o[#o + 1] = { value = v[1], text = v[2] } end
                return o
            end,
            textOf = function(val)
                for _, v in ipairs(type(options) == "function" and options() or options) do if v[1] == val then return v[2] end end
                return tostring(val)
            end,
            onChange = onChange,
        })
    end

    -- Name, an/aus, Art
    local nameBox = Edit(form, 280)
    stack:Add(LabeledRow(Lx.AR_NAME, nameBox), { height = 24, gap = 4, stretch = true })
    local onCb = UI.CreateCheckbox(form, Lx.AR_RULE_ON, function() return state.on end, function(v) state.on = v and true or false end)
    stack:Add(onCb, { fit = true, gap = 4 })
    local Layout
    local kindDD = Dropdown(220, { { "chat", Lx.AR_KIND_CHAT }, { "buff", Lx.AR_KIND_BUFF } }, function(v) state.kind = v Layout() end)
    stack:Add(LabeledRow(Lx.AR_KIND, kindDD), { height = 24, gap = 6, stretch = true })

    -- Woher
    local srcHead = Head(Lx.AR_SRC)
    stack:Add(srcHead, { height = 20, gap = 12, stretch = true })
    local srcBoxes = {}
    local srcRows = {}
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
        srcRows[rowN] = r
        stack:Add(r, { height = 24, gap = 2, stretch = true })
    end
    local buffDD = Dropdown(240, { { "WHISPER", Lx.AR_BUFFREPLY_W }, { "GROUP", Lx.AR_BUFFREPLY_G } }, function(v) state.buffReply = v end)
    local buffRow = LabeledRow(Lx.AR_BUFFREPLY, buffDD)
    stack:Add(buffRow, { height = 24, gap = 12, stretch = true })

    -- Wörter
    local matchHead = Head(Lx.AR_MATCH, Lx.AR_MATCH_INFO)
    stack:Add(matchHead, { height = 20, gap = 12, stretch = true })
    local matchArea = UI.CreateTextArea(form, 400, 64)
    stack:Add(matchArea, { height = 64, gap = 4, stretch = true })
    local neverBox = Edit(form, 300)
    local neverRow = LabeledRow(Lx.AR_NEVER, neverBox)
    Info(neverRow, Lx.AR_NEVER, Lx.AR_NEVER_INFO):SetPoint("LEFT", neverBox, "RIGHT", 6, 0)
    stack:Add(neverRow, { height = 24, gap = 6, stretch = true })
    local wholeCb = UI.CreateCheckbox(form, Lx.AR_WHOLE, function() return state.whole end, function(v) state.whole = v and true or false end)
    stack:Add(wholeCb, { fit = true, gap = 4 })

    -- Bedingungen
    stack:Add(Head(Lx.AR_COND), { height = 20, gap = 12, stretch = true })
    local condOpts = { { "any", Lx.AR_ANY }, { "yes", Lx.AR_YES }, { "no", Lx.AR_NO } }
    local condDDs = {}
    local condLabels = { afk = Lx.AR_C_AFK, dnd = Lx.AR_C_DND, group = Lx.AR_C_GROUP, raid = Lx.AR_C_RAID }
    for rowN = 1, 2 do
        local r = Row(24)
        for col = 1, 2 do
            local key = AR.CONDS[(rowN - 1) * 2 + col]
            local l = UI.CreateLabel(r, condLabels[key], { size = 12 })
            l:SetPoint("LEFT", r, "LEFT", (col - 1) * 250, 0)
            local dd = Dropdown(120, condOpts, function(v) state.cond[key] = v end)
            dd:SetParent(r)
            dd:ClearAllPoints()
            dd:SetPoint("LEFT", r, "LEFT", (col - 1) * 250 + 110, 0)
            condDDs[key] = dd
        end
        stack:Add(r, { height = 24, gap = 4, stretch = true })
    end
    local classDD = Dropdown(160, { { "all", Lx.AR_CL_ALL }, { "only", Lx.AR_CL_ONLY }, { "not", Lx.AR_CL_NOT } },
        function(v) state.classMode = v Layout() end)
    stack:Add(LabeledRow(Lx.AR_CLASSES, classDD), { height = 24, gap = 8, stretch = true })
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
        classRows[rowN] = r
        stack:Add(r, { height = 24, gap = 2, stretch = true })
    end
    local charDD = Dropdown(260, function()
        return { { "all", Lx.AR_CHAR_ALL }, { "me", string.format(Lx.AR_CHAR_ONLY, AR.CharKey()) },
            state.char and state.char ~= AR.CharKey() and { "other", string.format(Lx.AR_CHAR_ONLY, state.char) } or nil }
    end, function(v)
        if v == "all" then state.char = nil elseif v == "me" then state.char = AR.CharKey() end
    end)
    stack:Add(LabeledRow(Lx.AR_CHAR, charDD), { height = 24, gap = 8, stretch = true })

    -- Antworten
    stack:Add(Head(Lx.AR_REPLIES, Lx.AR_REPLIES_INFO), { height = 20, gap = 12, stretch = true })
    local replyArea = UI.CreateTextArea(form, 400, 80)
    stack:Add(replyArea, { height = 80, gap = 4, stretch = true })

    -- Zeiten
    local numBoxes = {}
    local function NumRow(key, text)
        local b = Edit(form, 70)
        b.edit:SetNumeric(true)
        b.edit:SetMaxLetters(6)
        numBoxes[key] = b
        local r = LabeledRow(text, b)
        stack:Add(r, { height = 24, gap = 4, stretch = true })
        return r
    end
    local cdRow = NumRow("cdRule", Lx.AR_CD_RULE)
    Info(cdRow, Lx.AR_CD_RULE, Lx.AR_TIME_INFO):SetPoint("LEFT", numBoxes.cdRule, "RIGHT", 6, 0)
    NumRow("cdPlayer", Lx.AR_CD_PLAYER)
    local ignRow = NumRow("ignoreAfter", Lx.AR_IGNORE_AFTER)
    local reportCb = UI.CreateCheckbox(form, Lx.AR_REPORT, function() return state.report end, function(v) state.report = v and true or false end)
    stack:Add(reportCb, { fit = true, gap = 8 })

    -- Test
    local testBox = Edit(form, 300)
    local testRow = LabeledRow(Lx.AR_TEST, testBox)
    local testHint = UI.CreateLabel(testBox, Lx.AR_TEST_HINT, { size = 11, color = "textDim" })
    testHint:SetPoint("LEFT", testBox, "LEFT", 8, 0)
    testHint:SetPoint("RIGHT", testBox, "RIGHT", -8, 0)
    testHint:SetWordWrap(false)
    local testRes = UI.CreateLabel(testRow, "", { size = 12 })
    testRes:SetPoint("LEFT", testBox, "RIGHT", 8, 0)
    stack:Add(testRow, { height = 24, gap = 14, stretch = true })

    -- Speichern / Löschen
    local btnRow = Row(28)
    local bSave = UI.CreateButton(btnRow, Lx.AR_SAVE, 130, 26, nil, "primary")
    bSave:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
    local bDel = UI.CreateButton(btnRow, Lx.AR_DELETE, 110, 26, nil, "danger")
    bDel:SetPoint("LEFT", bSave, "RIGHT", 8, 0)
    local saved = UI.CreateLabel(btnRow, "", { size = 11, color = "textDim" })
    saved:SetPoint("LEFT", bDel, "RIGHT", 10, 0)
    stack:Add(btnRow, { height = 28, gap = 14, stretch = true })

    -- Sichtbarkeit je nach Art und Klassenwahl
    local function SetShownStack(w, show)
        w.stackHidden = not show
        if show then w:Show() else w:Hide() end
    end
    Layout = function()
        local chat = (state.kind or "chat") == "chat"
        SetShownStack(srcHead, chat)
        for _, r in ipairs(srcRows) do SetShownStack(r, chat) end
        SetShownStack(buffRow, not chat)
        SetShownStack(ignRow, chat)
        matchHead.label:SetText(chat and Lx.AR_MATCH or Lx.AR_MATCH_BUFF)
        for _, r in ipairs(classRows) do SetShownStack(r, state.classMode and state.classMode ~= "all") end
        stack:Layout()
    end

    -- Formular füllen / auslesen
    local function Load(r)
        cur = r
        bDel.armed = nil
        bDel:SetLabel(Lx.AR_DELETE)
        saved:SetText("")
        if not r then formScroll:Hide() none:Show() return end
        none:Hide()
        formScroll:Show()
        state = {
            on = r.on ~= false, kind = r.kind or "chat", whole = r.whole and true or false, report = r.report and true or false,
            src = {}, cond = {}, classes = {}, classMode = r.classMode or "all", char = r.char, buffReply = r.buffReply or "WHISPER",
        }
        for k, v in pairs(r.src or {}) do state.src[k] = v end
        for _, k in ipairs(AR.CONDS) do state.cond[k] = r.cond and r.cond[k] or "any" end
        for k, v in pairs(r.classes or {}) do state.classes[k] = v end
        nameBox:SetText(r.name)
        matchArea:SetText(r.match or "")
        neverBox:SetText(r.never or "")
        replyArea:SetText(r.replies or "")
        numBoxes.cdRule:SetText(tostring(r.cdRule or 0))
        numBoxes.cdPlayer:SetText(tostring(r.cdPlayer or 0))
        numBoxes.ignoreAfter:SetText(tostring(r.ignoreAfter or 0))
        kindDD:SetValue(state.kind)
        buffDD:SetValue(state.buffReply)
        classDD:SetValue(state.classMode)
        charDD:SetValue(not state.char and "all" or (state.char == AR.CharKey() and "me" or "other"))
        for k, dd in pairs(condDDs) do dd:SetValue(state.cond[k]) end
        onCb:Refresh() wholeCb:Refresh() reportCb:Refresh()
        for _, cb in ipairs(srcBoxes) do cb:Refresh() end
        for _, cb in ipairs(classBoxes) do cb:Refresh() end
        testBox:SetText("")
        testRes:SetText("")
        Layout()
    end

    local function Save(quiet)
        local r = cur
        if not r or not AR.Find(r.id) then return end
        local name = nameBox:GetText():gsub("^%s+", ""):gsub("%s+$", "")
        r.name = name ~= "" and name or r.name
        r.on = state.on
        r.kind = state.kind
        r.src = state.src
        r.match = matchArea:GetText() or ""
        r.never = neverBox:GetText()
        r.whole = state.whole
        r.cond = state.cond
        r.classMode = state.classMode
        r.classes = state.classes
        r.char = state.char
        r.replies = replyArea:GetText() or ""
        r.cdRule = tonumber(numBoxes.cdRule:GetText()) or 0
        r.cdPlayer = tonumber(numBoxes.cdPlayer:GetText()) or 0
        r.ignoreAfter = tonumber(numBoxes.ignoreAfter:GetText()) or 0
        r.report = state.report
        r.buffReply = state.buffReply
        -- Zustand frisch anlegen, damit die Regel nicht dieselben Tabellen wie das Formular teilt
        Load(r)
        if not quiet then saved:SetText(Lx.AR_SAVED) end
        FW:Fire("AUTOREPLY_CHANGED")
    end

    local function RefreshList()
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
            b:SetLabel((r.kind == "buff" and "|cff9a9aa3[Buff]|r " or "") .. tostring(r.name))
            b:SetStyle(cur and cur.id == r.id and "primary" or "default")
            b:SetAlpha(r.on == false and 0.5 or 1)
            b:Show()
        end
        for i = #rules + 1, #listButtons do listButtons[i]:Hide() end
        listScroll:SetContentHeight(#rules * 27 + 4)
        if #rules == 0 then Load(nil) end
    end

    bNew:SetScript("OnClick", function()
        if cur then Save(true) end
        local r = AR.NewRule("chat")
        Load(r)
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
        local first = AR.DB().rules[1]
        Load(first)
        RefreshList()
    end)
    testBox.edit:SetScript("OnTextChanged", function()
        local t = testBox:GetText()
        if t == "" then testHint:Show() testRes:SetText("") return end
        testHint:Hide()
        local probe = { match = matchArea:GetText(), never = neverBox:GetText(), whole = state.whole }
        if not AR.Matches(probe, t) then testRes:SetText(Lx.AR_TEST_NO) return end
        local tmp = { cond = state.cond, classMode = state.classMode, classes = state.classes, char = state.char }
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
            r.l2:SetText(string.format("„%s“  |cffffd100->|r  %s", tostring(e.msg), tostring(e.reply)))
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
    root.Load = Load
    root.Save = Save
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
