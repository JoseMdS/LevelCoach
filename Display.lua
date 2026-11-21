-- LevelCoach display (WoW Forever edition): one big "press this next" icon, an interrupt alert, and a row of ready cooldowns.
-- The frame only exists/updates while your class + spec is supported; otherwise it stays hidden and idle.

local ADDON, ns = ...

local defaults = {
    point = { "CENTER", "UIParent", "CENTER", 0, -160 },
    scale = 1.0,
    locked = false,
    showCooldowns = true,
    showKeybinds = true,
    showSwing = true,
    twist = false,
    mode = "auto",
    alwaysShow = false,
    spec = "auto",
}
local db

---------------------------------------------------------------------------
-- Keybind lookup
---------------------------------------------------------------------------
local BAR_BINDINGS = {
    { first = 1,  prefix = "ACTIONBUTTON" },
    { first = 25, prefix = "MULTIACTIONBAR3BUTTON" },
    { first = 37, prefix = "MULTIACTIONBAR4BUTTON" },
    { first = 49, prefix = "MULTIACTIONBAR2BUTTON" },
    { first = 61, prefix = "MULTIACTIONBAR1BUTTON" },
}

local function ShortKey(key)
    key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
    key = key:gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD")
    key = key:gsub("BUTTON", "M"):gsub("NUMPAD", "N")
    return key
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

-- Action slots holding this spell (any rank): matched by name.
local function SlotsFor(name)
    local slots = {}
    for slot = 1, 120 do
        if HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and id and SpellName(id) == name then slots[#slots + 1] = slot end
        end
    end
    return slots
end

local keyCache = {}
local function KeybindFor(spell)
    if not spell then return nil end
    if keyCache[spell] ~= nil then return keyCache[spell] or nil end
    local result = false
    local slots = SlotsFor(spell)
    if slots then
        for _, slot in ipairs(slots) do
            for _, bar in ipairs(BAR_BINDINGS) do
                if slot >= bar.first and slot < bar.first + 12 then
                    local key = GetBindingKey(bar.prefix .. (slot - bar.first + 1))
                    if key then result = ShortKey(key) break end
                end
            end
            if result then break end
        end
    end
    keyCache[spell] = result
    return result or nil
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local MAIN_SIZE, SMALL_SIZE, MAX_CDS = 56, 32, 8

local function MakeIcon(parent, size)
    local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 2, -2)
    b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.tex)
    b.cd:SetDrawEdge(false)
    b.cd:SetHideCountdownNumbers(true)
    b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.key:SetPoint("TOPRIGHT", -3, -3)
    return b
end

local frame = CreateFrame("Frame", "LevelCoachFrame", UIParent)
frame:SetSize(MAIN_SIZE, MAIN_SIZE)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) if db and not db.locked then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point = { p, "UIParent", rp, x, y }
end)
frame:Hide()

local main = MakeIcon(frame, MAIN_SIZE)
main:SetPoint("CENTER")
main.key:SetFontObject("NumberFontNormalLarge")

-- Soft orange glow so the suggestion reads at a glance.
main.glow = main:CreateTexture(nil, "BACKGROUND")
main.glow:SetPoint("TOPLEFT", -10, 10)
main.glow:SetPoint("BOTTOMRIGHT", 10, -10)
main.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
main.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
main.glow:SetVertexColor(1, 0.45, 0.1, 0.9)

local kick = MakeIcon(frame, SMALL_SIZE)
kick:SetPoint("RIGHT", main, "LEFT", -6, 0)
kick:SetBackdropBorderColor(1, 0.1, 0.1, 1)
kick:Hide()

local cdIcons = {}
for i = 1, MAX_CDS do
    local ic = MakeIcon(frame, SMALL_SIZE)
    ic:SetBackdropBorderColor(1, 0.82, 0, 1)
    ic:Hide()
    cdIcons[i] = ic
end

local resText = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resText:SetPoint("TOP", main, "BOTTOM", 0, -2)


local moveHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
moveHint:SetPoint("BOTTOM", main, "TOP", 0, 22)

-- Swing timer bars above the icon: main hand (thick) and off hand (thin, only when dual wielding).
local function MakeBar(height, r, g, b)
    local bar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
    bar:SetSize(MAIN_SIZE, height)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 1)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar:SetBackdropColor(0, 0, 0, 0.6)
    bar:SetBackdropBorderColor(0, 0, 0, 1)
    bar:Hide()
    return bar
end
local mhBar = MakeBar(6, 1, 0.75, 0.3)
mhBar:SetPoint("BOTTOM", main, "TOP", 0, 8)
local ohBar = MakeBar(3, 0.7, 0.7, 0.7)
ohBar:SetPoint("TOP", mhBar, "BOTTOM", 0, -1)
local swingText = mhBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
swingText:SetPoint("LEFT", mhBar, "RIGHT", 3, 0)

local function UpdateSwing()
    if not db or not db.showSwing or not ns.SwingActive or not ns.SwingActive() then
        mhBar:Hide(); ohBar:Hide(); return
    end
    local mh, oh = ns.swing.mh, ns.swing.oh
    if mh.speed > 0 then
        mhBar:SetValue(math.min(1, ns.SwingSince("mh") / mh.speed))
        swingText:SetFormattedText("%.1f", ns.SwingRemaining("mh"))
        mhBar:Show()
    end
    local _, ohSpeed = UnitAttackSpeed("player")
    if ohSpeed and oh.speed > 0 and oh.start > 0 then
        ohBar:SetValue(math.min(1, ns.SwingSince("oh") / oh.speed))
        ohBar:Show()
    else
        ohBar:Hide()
    end
end

local ATTACK = 6603 -- auto attack

local function SetIcon(icon, spell)
    local tex = ns.Texture(spell)
    if type(spell) == "number" then spell = SpellName(spell) or spell end -- Blizzard assist gives an ID
    icon.tex:SetTexture(tex or ns.Texture(spell) or ns.Texture(ATTACK))
    local ok, start, duration = pcall(ns.GCDInfo)
    if ok and not ns.IsSecret(duration) and start and duration and duration > 0 then
        icon.cd:SetCooldown(start, duration)
    else
        icon.cd:Clear()
    end
    icon.key:SetText(db.showKeybinds and KeybindFor(spell) or "")
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- The spec's core ability you know (spec.filler, then its melee spells), or auto attack.
local function Filler(spec)
    for _, list in ipairs({ spec.filler or {}, spec.melee or {} }) do
        for _, name in ipairs(list) do
            if ns.Known(name) then return name end
        end
    end
    return ATTACK
end

local function ShouldShow()
    if not db.locked or db.alwaysShow then return true end
    return ns.InCombat() or ns.HasHostileTarget()
end

local function Refresh()
    local spec = ns.current
    if not db or not spec then return end
    moveHint:SetShown(not db.locked)
    moveHint:SetText("LevelCoach (" .. spec.name .. "): drag me, /lc lock")
    frame:EnableMouse(not db.locked)

    if not ShouldShow() then frame:SetAlpha(0) return end
    frame:SetAlpha(1)

    local spell = ns.Suggest(spec)
    if spell then
        SetIcon(main, spell)
        main.tex:SetDesaturated(false)
        main.glow:Show()
    else
        -- Nothing usable right now (usually not enough rage/energy/mana): show the next ability, dimmed.
        local waiting = ns.Preview(spec)
        if waiting then
            SetIcon(main, waiting)
        else
            -- Nothing to suggest at all: show your core ability (dimmed) instead of a question mark.
            SetIcon(main, Filler(spec))
        end
        main.tex:SetDesaturated(true)
        main.glow:Hide()
    end

    if spec.resource then
        local ok, text, r, g, b = pcall(spec.resource)
        resText:SetText(ok and text and tostring(text) or "")
        if ok and r then resText:SetTextColor(r, g, b) end
    end

    local okKick, showKick = pcall(function()
        return spec.interrupt and ns.TargetInterruptible() and ns.Ready(spec.interrupt)
    end)
    if okKick and showKick then
        SetIcon(kick, spec.interrupt)
        kick:Show()
    else
        kick:Hide()
    end

    local cds = {}
    if db.showCooldowns then
        local ok, list = pcall(ns.ReadyCooldowns, spec)
        if ok then cds = list end
    end
    local n = math.min(#cds, MAX_CDS)
    local width = n * SMALL_SIZE + math.max(0, n - 1) * 4
    for i, ic in ipairs(cdIcons) do
        local id = cds[i]
        if id and i <= n then
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", main, "BOTTOM", -width / 2 + (i - 1) * (SMALL_SIZE + 4), -16)
            SetIcon(ic, id)
            ic:Show()
        else
            ic:Hide()
        end
    end
end

local elapsed = 0
frame:SetScript("OnUpdate", function(_, dt)
    if (frame:GetAlpha() or 1) > 0 then pcall(UpdateSwing) end -- every frame, so the bar moves smoothly
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    -- Never let hidden combat data spam errors: remember the problem for /lc debug instead.
    local ok, err = pcall(Refresh)
    if not ok then ns.lastError = err end
end)

-- Decide whether we should be active at all for the current class/spec.
local function Evaluate()
    if not db then return end
    ns.current = ns.ActiveSpec(db.spec)
    if ns.current then
        frame:Show()
        Refresh()
    else
        frame:Hide() -- hidden frames don't run OnUpdate: fully idle
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        if not ns.specs[ns.playerClass] then return end -- class not supported: never do anything
        LevelCoachDB = LevelCoachDB or {}
        for k, v in pairs(defaults) do
            if LevelCoachDB[k] == nil then LevelCoachDB[k] = v end
        end
        db = LevelCoachDB
        ns.db = db
        frame:ClearAllPoints()
        frame:SetPoint(unpack(db.point))
        frame:SetScale(db.scale)
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
                             "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
                             "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "ACTIONBAR_SLOT_CHANGED",
                             "UPDATE_BINDINGS" }) do
            pcall(self.RegisterEvent, self, e)
        end
        ns.ScanSpellbook()
        Evaluate()
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
        wipe(keyCache)
    else
        if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_ENTERING_WORLD" then
            ns.ScanSpellbook()
            wipe(keyCache)
        end
        Evaluate()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Print(msg) print("|cffff8000LevelCoach|r: " .. msg) end

SLASH_LEVELCOACH1 = "/levelcoach"
SLASH_LEVELCOACH2 = "/lc"
SlashCmdList.LEVELCOACH = function(msg)
    if not db then Print("your class isn't supported, so LevelCoach stays off.") return end
    local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "lock" then
        db.locked = true; Print("locked. Shows in combat or with a hostile target.")
    elseif cmd == "unlock" then
        db.locked = false; Print("unlocked. Drag the icon to move it.")
    elseif cmd == "scale" and tonumber(arg) then
        db.scale = math.min(3, math.max(0.5, tonumber(arg))); frame:SetScale(db.scale)
        Print("scale " .. db.scale)
    elseif cmd == "cds" then
        db.showCooldowns = not db.showCooldowns; Print("cooldown row " .. (db.showCooldowns and "on" or "off"))
    elseif cmd == "mode" then
        local m = arg ~= "" and arg or "auto"
        if m == "60" or m == "max" then m = "endgame" end
        if m ~= "auto" and m ~= "leveling" and m ~= "endgame" then
            Print("use /lc mode auto | leveling | endgame")
        else
            db.mode = m
            Print("mode " .. m .. (m == "auto" and " (endgame rotation from level 60)" or "")
                .. ", now using the " .. (ns.Endgame() and "endgame" or "leveling") .. " rotation")
        end
    elseif cmd == "debug" then
        Print("client has combat restrictions: " .. tostring(ns.restricted) .. ", swing timer: "
            .. (ns.swingAvailable and "on" or "unavailable on this client"))
        Print("spec: " .. (ns.current and ns.current.name or "none") .. ", last suggestion from Blizzard assist: "
            .. tostring(ns.assisted))
        for _, probe in ipairs({ { "rage/energy/mana", function() return UnitPower("player") end },
                                 { "your health", function() return UnitHealth("player") end },
                                 { "target health", function() return UnitHealth("target") end },
                                 { "GCD", function() return select(2, ns.GCDInfo()) end } }) do
            local ok, v = pcall(probe[2])
            Print("  " .. probe[1] .. ": " .. (not ok and "error" or ns.IsSecret(v) and "HIDDEN in combat" or "readable"))
        end
        local book = ns.Spellbook()
        local sample = {}
        for name in pairs(book) do if #sample < 8 then sample[#sample + 1] = name end end
        Print(("spellbook: %d spells found (%s)%s"):format(ns.bookCount or 0, table.concat(sample, ", "),
            (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) and " [new API]" or " [old API]"))
        Print("in combat: " .. tostring(ns.InCombat()) .. ", hostile target: " .. tostring(ns.HasHostileTarget())
            .. ", in melee: " .. tostring(select(2, pcall(ns.InMelee))))
        if ns.current then
            for _, name in ipairs(ns.current.melee or {}) do
                local id = book[name]
                if id then
                    local okU, u = pcall(ns._Usable, id)
                    local okC, s, d = pcall(ns._CooldownInfo, id)
                    Print(("  %s (id %d): usable=%s cooldown=%s range=%s"):format(name, id,
                        okU and (ns.IsSecret(u) and "HIDDEN" or tostring(u)) or "error",
                        okC and (ns.IsSecret(d) and "HIDDEN" or tostring(d)) or "error",
                        tostring(select(2, pcall(ns.InRange, name)))))
                    break
                end
            end
            local okN, nxt = pcall(ns.current.next)
            Print("suggestion now: " .. (okN and tostring(nxt) or ("ERROR " .. tostring(nxt)))
                .. ", waiting for: " .. tostring(ns.Preview(ns.current)))
        end
        local hid = {}
        for kind, t in pairs(ns.hidden) do if GetTime() - t < 60 then hid[#hid + 1] = kind end end
        table.sort(hid)
        Print("hidden by the game in the last minute: " .. (#hid > 0 and table.concat(hid, ", ") or "nothing")
            .. " (LevelCoach tracks your own casts instead)")
        Print("rotation: " .. (ns.Endgame() and "endgame" or "leveling") .. " (/lc mode " .. db.mode .. ")")
        Print("last error: " .. tostring(ns.lastError or "none"))
    elseif cmd == "twist" then
        db.twist = not db.twist
        Print("twisting " .. (db.twist and "on: seal twisting (Ret, needs Seal of Command and a slow weapon) and "
            .. "totem twisting (Enhancement, Windfury + Grace of Air)" or "off"))
    elseif cmd == "swing" then
        db.showSwing = not db.showSwing; Print("swing timer " .. (db.showSwing and "on" or "off"))
    elseif cmd == "keys" then
        db.showKeybinds = not db.showKeybinds; Print("keybinds " .. (db.showKeybinds and "on" or "off"))
    elseif cmd == "always" then
        db.alwaysShow = not db.alwaysShow; Print("always show " .. (db.alwaysShow and "on" or "off"))
    elseif cmd == "spec" then
        local want = arg ~= "" and arg or "auto"
        if want ~= "auto" and not ns.FindSpec(want) then
            local names = {}
            for _, d in ipairs(ns.specs[ns.playerClass]) do names[#names + 1] = d.alias or d.name:lower() end
            Print("unknown spec '" .. want .. "'. For your class try: auto, " .. table.concat(names, ", "))
        else
            db.spec = want; Print("spec set to " .. want)
        end
    elseif cmd == "shred" then
        db.alwaysShred = not db.alwaysShred
        Print("always suggest Shred: " .. (db.alwaysShred and "on" or "off (only when the mob isn't attacking you)"))
    elseif cmd == "spells" then
        ns.ScanSpellbook()
        local spec = ns.current
        if not spec then Print("no supported spec is active.") else
            local found, missing, seen = {}, {}, {}
            local function check(name)
                if seen[name] then return end
                seen[name] = true
                if ns.Spellbook()[name] then found[#found + 1] = name else missing[#missing + 1] = name end
            end
            for _, name in ipairs(spec.spells or {}) do check(name) end
            for _, name in ipairs(spec.cooldowns or {}) do check(name) end
            table.sort(found); table.sort(missing)
            Print(spec.name .. " - found: " .. (#found > 0 and table.concat(found, ", ") or "none"))
            Print("not learned / not found: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
            if ns.lastError then Print("last error: " .. tostring(ns.lastError)) end
        end
    elseif cmd == "talents" then
        local tree, p = ns.MainTree()
        local names = ns.TREES[ns.playerClass] or {}
        Print(("talent points: %s %d / %s %d / %s %d (detected via %s)"):format(names[1] or "1", p[1],
            names[2] or "2", p[2], names[3] or "3", p[3], ns.talentMethod or "?"))
    elseif cmd == "reset" then
        db.point = defaults.point; db.scale = 1
        frame:ClearAllPoints(); frame:SetPoint(unpack(db.point)); frame:SetScale(1)
        Print("position and scale reset.")
    else
        Print("active spec: " .. (ns.current and ns.current.name or "none (this spec isn't supported)")
            .. "  (spec setting: " .. db.spec .. ", rotation: " .. (ns.Endgame() and "endgame" or "leveling")
            .. ", /lc mode " .. db.mode .. ")")
        Print("/lc lock | unlock | scale 0.5-3 | cds | keys | swing | twist | mode | always | debug | reset")
        Print("/lc spells (what it found) | talents | shred | spec auto|fury|protwarrior|assassination|outlaw|enhancement|"
            .. "retribution|protpaladin|cat|bear")
    end
    Evaluate()
end
