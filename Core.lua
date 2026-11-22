-- LevelCoach core (WoW Forever edition): game-state helpers shared by every spec module + the spec registry.
-- Forever is a Classic-era game: spells have ranks, specs come from talent trees, and many abilities
-- were renamed or reworked. So everything here works by spell NAME, resolved against your spellbook
-- (highest rank you know), and the spec is worked out from where your talent points are.

local ADDON, ns = ...
ns.ADDON = ADDON

local _, playerClass = UnitClass("player")
ns.playerClass = playerClass

---------------------------------------------------------------------------
-- Spec registry
---------------------------------------------------------------------------
-- {
--   class = "WARRIOR", tree = 2, name = "Fury",
--   default = true,            -- used when you have no talent points yet (below level 10)
--   when = function() ... end, -- optional extra condition (e.g. Bear Form for the bear spec)
--   ranged = true,                      -- caster/hunter: assume not in melee when unsure, count enemies by threat
--   melee = { "Heroic Strike" },        -- spells used to test melee range (first known wins)
--   filler = { "Bloodthirst" },         -- core ability shown dimmed when nothing else can be suggested
--   interrupt = "Pummel",               -- red side icon when the target's cast can be stopped
--   cooldowns = { "Recklessness" },     -- row of ready cooldowns under the main icon
--   resource = function() return text, r, g, b end,
--   next = function() return "Spell Name" or nil end,
-- }
ns.specs = {}

-- Event frames created by the core. When your class has no specs, Display shuts all of them down so
-- the addon costs nothing. Spec files return on their first line for other classes, so only your
-- class's rotations are ever built.
ns.coreFrames = {}
function ns.CoreFrame()
    local f = CreateFrame("Frame")
    ns.coreFrames[#ns.coreFrames + 1] = f
    return f
end
function ns.Shutdown()
    for _, f in ipairs(ns.coreFrames) do
        f:UnregisterAllEvents()
        f:SetScript("OnEvent", nil)
    end
end

function ns.RegisterSpec(def)
    ns.specs[def.class] = ns.specs[def.class] or {}
    table.insert(ns.specs[def.class], def)
end

-- Talent tree order (same as the in-game talent frame tabs).
ns.TREES = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    ROGUE   = { "Assassination", "Combat", "Subtlety" },
    SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    DRUID   = { "Balance", "Feral", "Restoration" },
    MAGE    = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
    PRIEST  = { "Discipline", "Holy", "Shadow" },
}

-- Points spent in each talent tree for the active talent group (dual spec aware).
-- Spells only a talented spec has: used to detect your spec when the game's talent API isn't
-- available to addons (testers report GetNumTalentTabs/GetTalentInfo are missing on the Forever client).
ns.SIGNATURE = {
    WARRIOR = { { "Mortal Strike", "Sweeping Strikes" },
                { "Bloodthirst", "Death Wish", "Reckless Swings", "Rampage" },
                { "Shield Slam", "Concussion Blow", "Last Stand" } },
    ROGUE   = { { "Mutilate", "Cold Blood", "Venom" },
                { "Adrenaline Rush", "Blade Flurry", "Riposte" },
                { "Hemorrhage", "Preparation", "Premeditation", "Ghostly Strike" } },
    SHAMAN  = { { "Elemental Mastery" },
                { "Stormstrike", "Shamanistic Rage" },
                { "Mana Tide Totem", "Riptide" } },
    PALADIN = { { "Holy Shock", "Divine Favor" },
                { "Holy Shield", "Avenger's Shield", "Blessing of Sanctuary" },
                { "Repentance", "Seal of Command", "Crusader Strike" } },
    DRUID   = { { "Moonkin Form", "Insect Swarm" },
                { "Feral Charge", "Primal Bite", "Lacerate", "Shifting Power" },
                { "Swiftmend" } },
    MAGE    = { { "Presence of Mind", "Arcane Power" },
                { "Pyroblast", "Blast Wave", "Combustion" },
                { "Ice Barrier", "Cold Snap", "Ice Block" } },
    WARLOCK = { { "Siphon Life", "Amplify Curse", "Curse of Exhaustion", "Dark Pact" },
                { "Fel Domination", "Demonic Sacrifice", "Soul Link" },
                { "Shadowburn", "Conflagrate" } },
    HUNTER  = { { "Intimidation", "Bestial Wrath" },
                { "Aimed Shot", "Scatter Shot", "Trueshot Aura" },
                { "Counterattack", "Deterrence", "Wyvern Sting" } },
    PRIEST  = { { "Power Infusion", "Inner Focus", "Divine Spirit" },
                { "Holy Nova", "Lightwell", "Spirit of Redemption" },
                { "Shadowform", "Mind Flay", "Vampiric Embrace", "Silence" } },
}

local function SafeNum(v) if type(v) == "number" and not (issecretvalue and issecretvalue(v)) then return v end end

function ns.TreePoints()
    local points = { 0, 0, 0 }
    ns.talentMethod = "none"
    -- 1) Classic talent API
    if GetNumTalentTabs and GetTalentInfo then
        local group = GetActiveTalentGroup and SafeNum(GetActiveTalentGroup()) or nil
        local numTabs = SafeNum(GetNumTalentTabs()) or 0
        for tab = 1, math.min(numTabs, 3) do
            local n = GetNumTalents and SafeNum(GetNumTalents(tab)) or 0
            for i = 1, n do
                local ok, _, _, _, _, rank = pcall(GetTalentInfo, tab, i, false, false, group)
                rank = ok and SafeNum(rank)
                if rank then points[tab] = points[tab] + rank end
            end
        end
        if points[1] + points[2] + points[3] > 0 then ns.talentMethod = "talent points" return points end
    end
    -- 2) Points per tab from the tab info (position differs between client versions: take the
    --    first small whole number after the name)
    if GetTalentTabInfo then
        for tab = 1, 3 do
            local info = { pcall(GetTalentTabInfo, tab) }
            if info[1] then
                for k = 3, #info do
                    local v = SafeNum(info[k])
                    if v and v >= 0 and v <= 61 and v == math.floor(v) then points[tab] = v break end
                end
            end
        end
        if points[1] + points[2] + points[3] > 0 then ns.talentMethod = "talent tabs" return points end
    end
    -- 3) Modern specialization API
    local spec = (GetSpecialization and SafeNum(GetSpecialization()))
        or (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and SafeNum(C_SpecializationInfo.GetSpecialization()))
    if spec and spec >= 1 and spec <= 3 then
        points[spec] = 1
        ns.talentMethod = "specialization"
        return points
    end
    -- 4) Which talent-only spells do you know?
    local sig = ns.SIGNATURE[playerClass]
    if sig and ns.Known then
        for tab = 1, 3 do
            for _, name in ipairs(sig[tab]) do
                if ns.Known(name) then points[tab] = points[tab] + 1 end
            end
        end
        if points[1] + points[2] + points[3] > 0 then ns.talentMethod = "talent spells you know" end
    end
    return points
end

-- Returns the main talent tree (1-3), or 0 when no points are spent yet.
function ns.MainTree()
    local p = ns.TreePoints()
    local best, bestPts = 0, 0
    for tab = 1, 3 do
        if p[tab] > bestPts then best, bestPts = tab, p[tab] end
    end
    return best, p
end

-- Find one of your class's specs by name or alias (for /lc spec).
function ns.FindSpec(name)
    for _, def in ipairs(ns.specs[playerClass] or {}) do
        if def.name:lower() == name or def.alias == name then return def end
    end
end

-- Returns the definition to use right now, or nil when this class/spec isn't supported.
function ns.ActiveSpec(forced)
    local list = ns.specs[playerClass]
    if not list then return nil end

    if forced and forced ~= "auto" then
        local def = ns.FindSpec(forced)
        if def then return def end
    end

    local tree = ns.MainTree()
    local function pick(match)
        for _, def in ipairs(list) do
            if match(def) and def.when and def.when() then return def end
        end
        for _, def in ipairs(list) do
            if match(def) and not def.when then return def end
        end
    end

    if tree == 0 then
        return pick(function(d) return d.default end)
    end
    return pick(function(d) return d.tree == tree end) -- e.g. Arms, Combat, Holy => nil => hidden
end

---------------------------------------------------------------------------
-- Spellbook: spell name -> highest-rank spell ID you know
---------------------------------------------------------------------------
local book = {}
ns.queried = {}

function ns.ScanSpellbook()
    wipe(book)
    if ns.ClearLookup then ns.ClearLookup() end
    local ok, err = pcall(ns._Scan)
    if not ok then ns.lastError = "spellbook scan: " .. tostring(err) end
    ns.bookCount = 0
    for _ in pairs(book) do ns.bookCount = ns.bookCount + 1 end
end

function ns._Scan()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info then
                for idx = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(idx, bank)
                    if item and item.name and item.spellID and not item.isPassive then
                        book[item.name] = item.spellID
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            for idx = offset + 1, offset + numSpells do
                local name = GetSpellBookItemName and GetSpellBookItemName(idx, "spell")
                local _, spellID = GetSpellBookItemInfo(idx, "spell")
                if name and spellID then book[name] = spellID end -- later ranks overwrite earlier
            end
        end
    end
end

---------------------------------------------------------------------------
-- Hidden ("secret") combat data
---------------------------------------------------------------------------
-- WoW Forever runs on a client that can hide combat data from addons. Any value we read goes through
-- Clean(): if the game hid it we get nil back (and remember what was hidden for /lc debug), so a hidden
-- value can never break a comparison. Where data is hidden we fall back to what we track ourselves
-- from your own casts (cooldowns, buffs, debuffs, combo points, the global cooldown).
local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) or false end
ns.IsSecret = Secret
ns.hidden = {}
local function Clean(v, kind)
    if Secret(v) then ns.hidden[kind or "other"] = GetTime() return nil end
    return v
end
ns.Clean = Clean

-- Spell ID for a name, or nil if you don't know it.
local lookup = {}
local missAt = {}
function ns.ClearLookup() wipe(lookup) wipe(missAt) end
local function LookupByName(name)
    local cached = lookup[name]
    if cached then return cached end
    -- Spell data can arrive late on this client: retry misses every 10 seconds
    if cached == false and GetTime() - (missAt[name] or 0) < 10 then return nil end
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        id = info and info.spellID
    elseif GetSpellInfo then
        id = select(7, GetSpellInfo(name))
    end
    id = Clean(id, "spells")
    if id and IsPlayerSpell and not IsPlayerSpell(id) and not (IsSpellKnown and IsSpellKnown(id)) then id = nil end
    lookup[name] = id or false
    if not id then missAt[name] = GetTime() end
    return id
end

function ns.ID(name)
    if not name then return nil end
    ns.queried[name] = true
    if type(name) == "number" then return name end
    return book[name] or LookupByName(name)
end

function ns.Known(name) return ns.ID(name) ~= nil end

function ns.KnownAny(...)
    for i = 1, select("#", ...) do
        if ns.Known((select(i, ...))) then return true end
    end
    return false
end

function ns.Spellbook() return book end

local function SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end
ns.SpellName = SpellName

---------------------------------------------------------------------------
-- Tracking your own casts (works even when the game hides combat data)
---------------------------------------------------------------------------
local lastCast, castCount = {}, {}
ns.lastAnyCast = 0
local trackedCP = 0

-- How long a buff/debuff you cast usually lasts (seconds). Used only when the game hides auras.
ns.DUR = {
    ["Battle Shout"] = 120, ["Shield Block"] = 5, ["Demoralizing Shout"] = 30, ["Thunder Clap"] = 10,
    ["Rend"] = 15, ["Sunder Armor"] = 30, ["Bloodrage"] = 10, ["Berserker Rage"] = 10,
    ["Slice and Dice"] = 15, ["Garrote"] = 18, ["Rupture"] = 16, ["Venom"] = 12, ["Blade Flurry"] = 15,
    ["Lightning Shield"] = 600, ["Flame Shock"] = 12,
    ["Righteous Fury"] = 1800, ["Holy Shield"] = 10, ["Blessing of Might"] = 300, ["Blessing of Kings"] = 300,
    ["Blessing of Sanctuary"] = 300, ["Judgement of the Crusader"] = 10,
    ["Rake"] = 9, ["Rip"] = 12, ["Moonfire"] = 12, ["Faerie Fire (Feral)"] = 40, ["Faerie Fire"] = 40,
    ["Demoralizing Roar"] = 30, ["Lacerate"] = 15, ["Mark of the Wild"] = 1800, ["Thorns"] = 600,
    -- Mage
    ["Arcane Intellect"] = 1800, ["Frost Armor"] = 1800, ["Ice Armor"] = 1800, ["Mage Armor"] = 1800,
    ["Ice Barrier"] = 60,
    -- Warlock
    ["Corruption"] = 18, ["Curse of Agony"] = 24, ["Bane of Agony"] = 24, ["Immolate"] = 15, ["Siphon Life"] = 30,
    ["Demon Skin"] = 1800, ["Demon Armor"] = 1800,
    -- Hunter
    ["Hunter's Mark"] = 120, ["Serpent Sting"] = 15, ["Wing Clip"] = 10,
    ["Aspect of the Hawk"] = 1e9, ["Aspect of the Monkey"] = 1e9, ["Trueshot Aura"] = 1e9,
    -- Priest
    ["Shadow Word: Pain"] = 18, ["Devouring Plague"] = 24, ["Vampiric Embrace"] = 60,
    ["Power Word: Fortitude"] = 1800, ["Inner Fire"] = 600, ["Power Word: Shield"] = 30, ["Renew"] = 15,
    ["Shadowform"] = 1e9,
}
local function DurFor(name)
    if ns.DUR[name] then return ns.DUR[name] end
    if name:find("^Seal of") then return 30 end
    if name:find(" Aura$") then return 1e9 end
    if name:find("^Blessing of") or name:find("^Greater Blessing of") then return 300 end
    return 0
end

local CP_GAIN = {
    ["Sinister Strike"] = 1, ["Mutilate"] = 2, ["Shank"] = 1, ["Backstab"] = 1, ["Hemorrhage"] = 1,
    ["Ghostly Strike"] = 1, ["Cheap Shot"] = 2, ["Garrote"] = 1, ["Ambush"] = 1, ["Riposte"] = 1,
    ["Claw"] = 1, ["Shred"] = 1, ["Rake"] = 1, ["Ravage"] = 1, ["Pounce"] = 1,
}
local FINISHER = {
    ["Eviscerate"] = true, ["Slice and Dice"] = true, ["Rupture"] = true, ["Envenom"] = true, ["Venom"] = true,
    ["Kidney Shot"] = true, ["Expose Armor"] = true, ["Ferocious Bite"] = true, ["Rip"] = true,
}

function ns.SinceCast(name)
    local t = lastCast[name]
    if not t then return 999 end
    return GetTime() - t
end

-- Is a buff/debuff you cast probably still running? (fallback when auras are hidden)
local function Tracked(name)
    local d = DurFor(name)
    return d > 0 and ns.SinceCast(name) < d
end

local slotOf = {}
local function RebuildSlots()
    wipe(slotOf)
    if not HasAction or not GetActionInfo then return end
    for slot = 1, 120 do
        if HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and id then
                local n = SpellName(id)
                if n and not slotOf[n] then slotOf[n] = slot end
                if not slotOf[id] then slotOf[id] = slot end
            end
        end
    end
end
function ns.SlotFor(name) return slotOf[name] end

local tracker = ns.CoreFrame()
tracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
tracker:RegisterEvent("PLAYER_TARGET_CHANGED")
tracker:RegisterEvent("PLAYER_REGEN_ENABLED")
tracker:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or Secret(spellID) then return end
        local name = SpellName(spellID)
        if not name or Secret(name) then return end
        local now = GetTime()
        -- Paladin seals (for the hidden-auras fallback): only one seal is active at a time, and
        -- Judgement consumes it. Judging Seal of the Crusader puts its debuff on the target.
        if name:find("^Seal of") or name == "Judgement" then
            local active, activeAt = nil, 0
            for seal, t in pairs(lastCast) do
                if seal:find("^Seal of") then
                    if Tracked(seal) and t > activeAt then active, activeAt = seal, t end
                    lastCast[seal] = nil
                end
            end
            if name == "Judgement" and active == "Seal of the Crusader" then
                lastCast["Judgement of the Crusader"] = now
                castCount["Judgement of the Crusader"] = (castCount["Judgement of the Crusader"] or 0) + 1
            end
        end
        lastCast[name] = now
        castCount[name] = (castCount[name] or 0) + 1
        if name ~= "Attack" and name ~= "Auto Shot" then ns.lastAnyCast = now end
        if CP_GAIN[name] then trackedCP = math.min(5, trackedCP + CP_GAIN[name]) end
        if FINISHER[name] then trackedCP = 0 end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Debuffs and combo points belong to the old target
        trackedCP = 0
        for name in pairs(castCount) do
            if DurFor(name) < 60 then castCount[name] = 0 end
        end
        ns.targetSince = GetTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        trackedCP = 0
        wipe(castCount)
    else
        RebuildSlots()
    end
end)

---------------------------------------------------------------------------
-- API wrappers (modern C_Spell or older globals), all hidden-data safe
---------------------------------------------------------------------------
-- Spells that only light up after something happens (a dodge, a parry, a kill, low target health).
local REACTIVE = { ["Execute"] = true, ["Overpower"] = true, ["Revenge"] = true, ["Victory Rush"] = true,
                   ["Riposte"] = true, ["Hammer of Wrath"] = true }

local function RawPower(kind) return Clean(UnitPower("player", kind), "power") end
local function RawHealthPct(unit)
    local cur, max = Clean(UnitHealth(unit), "health"), Clean(UnitHealthMax(unit), "health")
    if not cur or not max or max == 0 then return nil end
    return cur / max * 100
end
ns.RawPower, ns.RawHealthPct = RawPower, RawHealthPct

local function Cost(id)
    local costs = (C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(id))
        or (GetSpellPowerCost and GetSpellPowerCost(id))
    local c = costs and costs[1]
    if not c then return nil end
    local amount, kind = Clean(c.cost, "cost"), Clean(c.type, "cost")
    if amount and kind then return amount, kind end
end

-- usable, notEnoughPower (nil, nil when the game hides both the spell and its action bar button)
local function RawUsable(id, name)
    local usable, noMana
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(id)
    elseif IsUsableSpell then
        usable, noMana = IsUsableSpell(id)
    else
        return true, false
    end
    usable, noMana = Clean(usable, "usable"), Clean(noMana, "usable")
    if usable == nil then
        -- Hidden: try the action bar button for the same spell
        local slot = slotOf[name] or slotOf[id]
        if slot and IsUsableAction then
            usable, noMana = IsUsableAction(slot)
            usable, noMana = Clean(usable, "usable"), Clean(noMana, "usable")
        end
    end
    return usable, noMana
end

local function Usable(id, name)
    local usable, noMana = RawUsable(id, name)
    if usable ~= nil then
        if ns.preview then return usable or noMana or false end
        return usable and not noMana
    end
    -- Still unknown: reactive spells only when we can prove the condition, others by resource cost.
    if name and REACTIVE[name] then
        if name == "Execute" or name == "Hammer of Wrath" then
            local thp = RawHealthPct("target")
            return thp ~= nil and thp < 20
        end
        return false
    end
    local amount, kind = Cost(id)
    if amount and amount > 0 and not ns.preview then
        local have = RawPower(kind)
        if have then return have >= amount end
    end
    return true
end
ns._Usable = Usable

-- start, duration (nil, nil when hidden)
local function CooldownInfo(id)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(id)
        if not cd then return 0, 0 end
        start, duration = cd.startTime, cd.duration
    else
        start, duration = GetSpellCooldown(id)
    end
    start, duration = Clean(start, "cooldown"), Clean(duration, "cooldown")
    if start == nil or duration == nil then return nil, nil end
    return start, duration
end
ns._CooldownInfo = CooldownInfo

function ns.Texture(name)
    local id = ns.ID(name)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

-- true / false / nil (nil = the game can't tell or hides it)
function ns.InRange(name, unit)
    local id = ns.ID(name)
    if not id then return nil end
    unit = unit or "target"
    local r
    if C_Spell and C_Spell.IsSpellInRange then
        r = C_Spell.IsSpellInRange(id, unit)
    elseif IsSpellInRange then
        r = IsSpellInRange(SpellName(id) or name, unit)
        if r == 1 then r = true elseif r == 0 then r = false end
    end
    r = Clean(r, "range")
    if r == nil and unit == "target" then
        local slot = slotOf[name] or slotOf[id]
        if slot and IsActionInRange then
            r = Clean(IsActionInRange(slot), "range")
            if r == 1 then r = true elseif r == 0 then r = false end
        end
    end
    return r
end

local GCD_SPELL = 61304
-- For the cooldown swirl on the icon: start, duration (0, 0 when unknown)
function ns.GCDInfo()
    local start, duration = CooldownInfo(GCD_SPELL)
    if start == nil then
        local since = GetTime() - ns.lastAnyCast
        if since < 1.5 then return ns.lastAnyCast, 1.5 end
        return 0, 0
    end
    return start, duration
end
function ns.GCDRemaining()
    local start, duration = ns.GCDInfo()
    if duration == 0 then return 0 end
    return math.max(0, start + duration - GetTime())
end

-- Real cooldown left, ignoring the global cooldown.
function ns.CooldownRemaining(name)
    local id = ns.ID(name)
    if not id then return 999 end
    local start, duration = CooldownInfo(id)
    if start == nil then
        -- Hidden: base cooldown minus time since you last cast it
        local base = GetSpellBaseCooldown and Clean(GetSpellBaseCooldown(id), "cooldown") or 0
        base = (base or 0) / 1000
        if base <= 1.5 then return 0 end
        return math.max(0, base - ns.SinceCast(SpellName(id) or name))
    end
    if duration == 0 or duration <= 1.5 then return 0 end -- 0 or just the GCD
    return math.max(0, start + duration - GetTime())
end

-- Ready = known, usable now (resource, stance, form, reactive conditions), off cooldown after the GCD.
function ns.Ready(name)
    local id = ns.ID(name)
    if not id then return false end
    if not Usable(id, name) then return false end
    return ns.CooldownRemaining(name) <= ns.GCDRemaining() + 0.1
end

function ns.ReadyAny(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if ns.Ready(name) then return name end
    end
end

-- Next-swing attacks (Heroic Strike, Cleave, Maul) already queued?
function ns.Queued(name)
    local id = ns.ID(name)
    if not id then return false end
    local q
    if C_Spell and C_Spell.IsCurrentSpell then q = C_Spell.IsCurrentSpell(id)
    elseif IsCurrentSpell then q = IsCurrentSpell(id) end
    return Clean(q, "other") or false
end

---------------------------------------------------------------------------
-- Auras (by name, so every rank matches)
---------------------------------------------------------------------------
local function AuraAt(unit, i, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not a then return nil end
        return a.name, a.applications, a.expirationTime
    end
    local name, _, count, _, _, expiration = UnitAura(unit, i, filter)
    return name, count, expiration
end

-- true, stacks, expiration  |  false (not there)  |  nil (the game hides auras)
local function FindAura(unit, name, filter)
    for i = 1, 40 do
        local ok, n, count, expiration = pcall(AuraAt, unit, i, filter)
        if not ok then ns.hidden.auras = GetTime() return nil end
        if n == nil then return false end
        if Secret(n) then ns.hidden.auras = GetTime() return nil end
        if n == name then
            return true, Clean(count, "auras") or 1, Clean(expiration, "auras") or 0
        end
    end
    return false
end

local function ScanLike(unit, pattern, filter)
    for i = 1, 40 do
        local ok, n = pcall(AuraAt, unit, i, filter)
        if not ok or (n ~= nil and Secret(n)) then ns.hidden.auras = GetTime() return nil end
        if n == nil then return false end
        if n:find(pattern) then return true end
    end
    return false
end

-- Player buff: returns stacks (>=1) or nil
function ns.Buff(name)
    local found, count = FindAura("player", name, "HELPFUL")
    if found then return math.max(count or 1, 1) end
    -- Only guess from your casts when the game hides auras; false means we saw it isn't there.
    if found == nil and Tracked(name) then return 1 end
    return nil
end
function ns.HasBuff(name) return ns.Buff(name) ~= nil end
function ns.HasAnyBuff(list)
    for _, name in ipairs(list) do
        if ns.Buff(name) then return true end
    end
    return false
end
-- Partial-name match, e.g. any "Seal of" or any "Aura"
function ns.HasBuffLike(pattern)
    local found = ScanLike("player", pattern, "HELPFUL")
    if found ~= nil then return found end
    for name in pairs(lastCast) do
        if name:find(pattern) and Tracked(name) then return true end
    end
    return false
end

-- Your debuff on the target: seconds left (0 = missing, 999 = no duration), stacks
function ns.Debuff(name, unit)
    local found, count, expiration = FindAura(unit or "target", name, "HARMFUL|PLAYER")
    if found then
        if not expiration or expiration == 0 then return 999, math.max(count, 1) end
        return math.max(0, expiration - GetTime()), math.max(count, 1)
    end
    -- Fallback (auras hidden only): cast on this target recently?
    if found == nil and (castCount[name] or 0) > 0 and Tracked(name) then
        return DurFor(name) - ns.SinceCast(name), math.min(castCount[name], 5)
    end
    return 0, 0
end
-- Anyone's debuff on the target (e.g. Sunder Armor or Demoralizing Shout from a group member)
function ns.TargetHasDebuff(name)
    local found = FindAura("target", name, "HARMFUL")
    if found ~= nil then return found end
    return (castCount[name] or 0) > 0 and Tracked(name)
end

---------------------------------------------------------------------------
-- Resources, health, range, enemies
---------------------------------------------------------------------------
local PT = Enum and Enum.PowerType or {}
ns.PT = { Mana = PT.Mana or 0, Rage = PT.Rage or 1, Energy = PT.Energy or 3, ComboPoints = PT.ComboPoints or 4 }

-- For priority decisions: real value, or 100 when the game hides it (spell usability still applies).
function ns.Power(kind) return RawPower(kind) or 100 end
function ns.PowerPct(kind)
    local cur, max = RawPower(kind), Clean(UnitPowerMax("player", kind), "power")
    if not cur or not max or max == 0 then return 100 end
    return cur / max * 100
end
---------------------------------------------------------------------------
-- Estimated rage/energy/mana while the game hides the real number
---------------------------------------------------------------------------
-- Three clues, combined:
--  1. The last real value we saw (usually right before combat), plus energy regen since then,
--     minus what your casts since then cost.
--  2. Which of your spells the game says you can afford right now. The action bar still knows when
--     a button is "out of rage", so if Whirlwind (25) is affordable and Bloodthirst (30) isn't,
--     you have 25-29 rage.
--  3. Your maximum.
local ENERGY_PER_SEC = 10
local seen, spent = {}, {}

local function Remember(kind)
    local v = RawPower(kind)
    if v then
        local max = Clean(UnitPowerMax("player", kind), "power")
        seen[kind] = { v = v, t = GetTime(), max = max or (seen[kind] and seen[kind].max) }
        spent[kind] = 0
    end
    return v
end

local spendWatch = ns.CoreFrame()
spendWatch:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
spendWatch:SetScript("OnEvent", function(_, _, unit, _, spellID)
    if unit ~= "player" or Secret(spellID) or not spellID then return end
    local ok, amount, kind = pcall(Cost, spellID)
    if ok and amount and amount > 0 and kind then spent[kind] = (spent[kind] or 0) + amount end
end)

-- lowest you can have, highest you can have (either may be nil)
local function Bounds(kind)
    local spec = ns.current
    if not spec or not spec.spells then return nil, nil end
    local lo, hi
    for _, name in ipairs(spec.spells) do
        local id = ns.ID(name)
        if id then
            local amount, k = Cost(id)
            if amount and amount > 0 and k == kind then
                local usable, noMana = RawUsable(id, name)
                if noMana then
                    if not hi or amount - 1 < hi then hi = amount - 1 end
                elseif usable then
                    if not lo or amount > lo then lo = amount end
                end
            end
        end
    end
    if lo and hi and lo > hi then return nil, nil end -- contradicting clues: trust none
    return lo, hi
end

-- value, how: "exact" (the real number), "about" (estimate), "atleast", "below" (value = the limit)
-- or nil when there's no clue at all
function ns.PowerEstimate(kind)
    local v = Remember(kind)
    if v then return v, "exact" end
    local lo, hi = Bounds(kind)
    local s = seen[kind]
    local guess
    if s and kind == ns.PT.Energy then
        guess = s.v + (GetTime() - s.t) * ENERGY_PER_SEC - (spent[kind] or 0)
        guess = math.min(guess, s.max or 100)
    elseif s and kind == ns.PT.Mana then
        guess = s.v - (spent[kind] or 0)
    end
    if guess then
        if lo then guess = math.max(guess, lo) end
        if hi then guess = math.min(guess, hi) end
        return math.max(0, math.floor(guess + 0.5)), "about"
    end
    if lo then return lo, "atleast" end
    if hi then return hi + 1, "below" end
    return nil
end

local function Shown(v, how, suffix)
    suffix = suffix or ""
    if how == "exact" then return v .. suffix end
    if how == "about" then return "~" .. v .. suffix end
    if how == "atleast" then return v .. suffix .. "+" end
    if how == "below" then return "<" .. v .. suffix end
    return ""
end

-- For the text under the icon: the real number, or "~45" / "30+" / "<15" while the game hides it
function ns.PowerShown(kind)
    return Shown(ns.PowerEstimate(kind))
end
function ns.PctShown(kind)
    local v, how = ns.PowerEstimate(kind)
    local max = Clean(UnitPowerMax("player", kind), "power") or (seen[kind] and seen[kind].max)
    if not v or not max or max == 0 then return "" end
    return Shown(math.floor(v / max * 100), how, "%")
end
function ns.ComboPoints()
    local cp
    if GetComboPoints then cp = GetComboPoints("player", "target") else cp = UnitPower("player", ns.PT.ComboPoints) end
    cp = Clean(cp, "combo points")
    return cp or trackedCP
end

-- Real value, or 100 (healthy) when hidden
function ns.HealthPct(unit) return RawHealthPct(unit or "player") or 100 end

-- Forever can even hide whether you have a target. Hidden "exists"/"can attack" counts as yes when you
-- have a target selected according to the game's own target-changed events.
local hasTarget = false
function ns.HasHostileTarget()
    local exists = Clean(UnitExists("target"), "target")
    if exists == nil then exists = hasTarget end
    if not exists then return false end
    local canAttack = Clean(UnitCanAttack("player", "target"), "target")
    if canAttack == false then return false end
    if Clean(UnitIsDead("target"), "target") == true then return false end
    return true
end
-- Level 60 / endgame mode: skip the leveling shortcuts (finishing dying mobs early, skipping dots and
-- buffs on mobs that are about to die). "auto" switches at max level; /lc mode leveling|endgame forces it.
ns.MAX_LEVEL = 60
function ns.Endgame()
    local mode = ns.db and ns.db.mode or "auto"
    if mode == "endgame" then return true end
    if mode == "leveling" then return false end
    local lvl = Clean(UnitLevel("player"), "other") or 1
    return lvl >= ns.MAX_LEVEL
end
-- Will the target live long enough to be worth a dot/buff? Always yes in endgame mode or when hidden.
function ns.Lives(pct)
    if ns.Endgame() then return true end
    local thp = RawHealthPct("target")
    return thp == nil or thp > pct
end

-- /lc shred: always suggest Shred instead of Claw (for players who keep behind the target)
function ns.Shred() return ns.db and ns.db.alwaysShred or false end
-- /lc twist: opt-in seal twisting (Ret) and totem twisting (Enhancement)
function ns.Twist() return ns.db and ns.db.twist or false end
local inCombatEvt = false
function ns.InCombat()
    local c = Clean(UnitAffectingCombat("player"), "combat")
    if c ~= nil then return c end
    local lock = InCombatLockdown and Clean(InCombatLockdown(), "combat")
    if lock ~= nil then return lock end
    return inCombatEvt
end
local combatFrame = ns.CoreFrame()
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
combatFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then inCombatEvt = true
    elseif event == "PLAYER_REGEN_ENABLED" then inCombatEvt = false
    else
        local e = Clean(UnitExists("target"), "target")
        if e ~= nil then hasTarget = e else hasTarget = true end
    end
end)
function ns.Stealthed() return IsStealthed and Clean(IsStealthed(), "auras") or false end
local function FormID() return GetShapeshiftFormID and Clean(GetShapeshiftFormID(), "form") end
function ns.InCatForm() return FormID() == 1 or ns.HasBuff("Cat Form") end
function ns.InBearForm() return FormID() == 5 or FormID() == 8 or ns.HasBuff("Bear Form") or ns.HasBuff("Dire Bear Form") end
function ns.TargetType() return UnitCreatureType and Clean(UnitCreatureType("target"), "target") end

local function MeleeProbe()
    local spec = ns.current
    if not spec or not spec.melee then return nil end
    for _, name in ipairs(spec.melee) do
        if ns.Known(name) then return name end
    end
end

function ns.InMelee(unit)
    unit = unit or "target"
    local probe = MeleeProbe()
    local r = probe and ns.InRange(probe, unit)
    if r ~= nil then return r end
    -- No usable melee spell: use the action-bar range dot of your Attack button (allowed in combat).
    if unit == "target" and slotOf[6603] and IsActionInRange then
        local inRange = Clean(IsActionInRange(slotOf[6603]), "range")
        if inRange ~= nil then return inRange == true or inRange == 1 end
    end
    -- CheckInteractDistance is a protected call during combat (it triggers "blocked from an action
    -- only available to the Blizzard UI"), so only use it out of combat.
    local locked = InCombatLockdown and InCombatLockdown()
    if not locked and CheckInteractDistance then
        local ok, close = pcall(CheckInteractDistance, unit, 3)
        if ok then close = Clean(close, "range") else close = nil end
        if close ~= nil then return close and true or false end
    end
    -- Unknown: melee specs assume they're in melee, casters and hunters assume they aren't.
    return not (ns.current and ns.current.ranged)
end

-- Hostile enemies in melee range, counted from nameplates (turn enemy nameplates on with V).
-- Ranged specs: enemies fighting you (on your threat table), wherever they stand.
local function EngagedEnemies()
    if not C_NamePlate then return 1 end
    local count = 0
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and Clean(UnitCanAttack("player", unit), "target") and not Clean(UnitIsDead(unit), "target") then
            local engaged
            if UnitThreatSituation then engaged = Clean(UnitThreatSituation("player", unit), "target") ~= nil
            else engaged = Clean(UnitAffectingCombat(unit), "target") end
            if engaged then count = count + 1 end
        end
    end
    return math.max(count, 1)
end

function ns.Enemies()
    if ns.current and ns.current.ranged then return EngagedEnemies() end
    local probe = MeleeProbe()
    if not probe or not C_NamePlate then return 1 end
    local count = 0
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and Clean(UnitCanAttack("player", unit), "target") and not Clean(UnitIsDead(unit), "target")
           and ns.InRange(probe, unit) == true then
            count = count + 1
        end
    end
    return math.max(count, 1)
end

function ns.TargetInterruptible()
    if not UnitCastingInfo then return false end
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
    if name == nil and UnitChannelInfo then
        name, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
    end
    name, notInterruptible = Clean(name, "casts"), Clean(notInterruptible, "casts")
    return name ~= nil and notInterruptible == false
end

-- Totem slots: 1 fire, 2 earth, 3 water, 4 air
function ns.HasTotem(slot)
    if not GetTotemInfo then return true end
    local have, name = GetTotemInfo(slot)
    have, name = Clean(have, "totems"), Clean(name, "totems")
    if have == nil then return true end
    return have and name and name ~= "" or false
end
function ns.TotemName(slot)
    if not GetTotemInfo then return nil end
    return Clean(select(2, GetTotemInfo(slot)), "totems")
end

-- Pets (hunter, warlock). Hidden counts as "you have a living pet".
function ns.PetDead() return Clean(UnitIsDead("pet"), "other") == true end
function ns.HasPet()
    local e = Clean(UnitExists("pet"), "other")
    if e == nil then return true end
    return e and not ns.PetDead()
end

-- Wand (and Auto Shot): returns the spell while it's already repeating, so the icon says "keep going".
function ns.AutoRepeat(name)
    if not ns.Known(name) then return nil end
    if IsAutoRepeatSpell and Clean(IsAutoRepeatSpell(name), "other") then return name end
    if ns.Ready(name) then return name end
end
function ns.Wand() return ns.AutoRepeat("Shoot") end

-- Soul Shards in your bags (warlock); nil when unknown
function ns.SoulShards()
    local n = GetItemCount and GetItemCount(6265)
    return Clean(n, "other")
end

---------------------------------------------------------------------------
-- Running a spec safely
---------------------------------------------------------------------------

-- Runs the spec's priority list. If the game hides the data it needs (secret values in combat),
-- fall back to Blizzard's own suggestion (Assisted Combat) when the client has it.
-- What would be next once you have the resource for it (shown dimmed while you wait)?
function ns.Preview(spec)
    ns.preview = true
    local ok, spell = pcall(spec.next)
    ns.preview = false
    if ok and spell and not ns.IsSecret(spell) then return spell end
end

function ns.Suggest(spec)
    local ok, spell = pcall(spec.next)
    if ok and (spell == nil or not ns.IsSecret(spell)) then ns.assisted = false return spell end
    if not ok then ns.lastError = spell end
    if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        local ok2, id = pcall(C_AssistedCombat.GetNextCastSpell, false)
        if ok2 and id and not ns.IsSecret(id) then ns.assisted = true return id end
    end
    ns.assisted = false
    return nil
end

function ns.ReadyCooldowns(spec)
    local list = {}
    if not spec.cooldowns or not ns.HasHostileTarget() then return list end
    for _, name in ipairs(spec.cooldowns) do
        if ns.Ready(name) then list[#list + 1] = name end
    end
    return list
end
