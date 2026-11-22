local _, ns = ...
if ns.playerClass ~= "HUNTER" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

local function Pet()
    if ns.PetDead() then
        if not ns.InCombat() and Ready("Revive Pet") then return "Revive Pet" end
    elseif not ns.HasPet() then
        if Ready("Call Pet") then return "Call Pet" end
    elseif ns.InCombat() and ns.HealthPct("pet") < 40 and Ready("Mend Pet") then
        return "Mend Pet"
    end
end

local function Rotation(tree)
    if not ns.InCombat() and tree == 2 and not HasBuff("Trueshot Aura") and Ready("Trueshot Aura") then
        return "Trueshot Aura"
    end
    local pet = Pet()
    if pet then return pet end
    if not ns.HasHostileTarget() then return nil end

    local mana, enemies = ns.PowerPct(ns.PT.Mana), ns.Enemies()

    -- Melee: Monkey aspect, Mongoose Bite after a dodge, Raptor Strike, Wing Clip to get away
    if ns.InMelee() then
        if not HasBuff("Aspect of the Monkey") and Ready("Aspect of the Monkey") then return "Aspect of the Monkey" end
        if Ready("Counterattack") then return "Counterattack" end
        if Ready("Mongoose Bite") then return "Mongoose Bite" end
        if Ready("Raptor Strike") then return "Raptor Strike" end
        if ns.Debuff("Wing Clip") == 0 and mana > 20 and Ready("Wing Clip") then return "Wing Clip" end
        return nil
    end

    -- Ranged
    if not HasBuff("Aspect of the Hawk") and Ready("Aspect of the Hawk") then return "Aspect of the Hawk" end
    if ns.Lives(50) and not ns.TargetHasDebuff("Hunter's Mark") and Ready("Hunter's Mark") then return "Hunter's Mark" end
    if enemies >= 2 and mana > 30 and Ready("Multi-Shot") then return "Multi-Shot" end
    if ns.Lives(40) and mana > 20 and ns.Debuff("Serpent Sting") == 0 and Ready("Serpent Sting") then
        return "Serpent Sting"
    end
    if tree == 2 and mana > 30 and ns.Lives(30) and Ready("Aimed Shot") then return "Aimed Shot" end
    if mana > 40 and Ready("Arcane Shot") then return "Arcane Shot" end
    return ns.AutoRepeat("Auto Shot")
end

local spells = { "Auto Shot", "Arcane Shot", "Serpent Sting", "Hunter's Mark", "Multi-Shot", "Aimed Shot",
    "Raptor Strike", "Mongoose Bite", "Wing Clip", "Counterattack", "Aspect of the Hawk", "Aspect of the Monkey",
    "Trueshot Aura", "Call Pet", "Revive Pet", "Mend Pet" }

for tree, def in ipairs({
    { name = "Beast Mastery", alias = "bm", cooldowns = { "Bestial Wrath", "Rapid Fire", "Intimidation" }, default = true },
    { name = "Marksmanship", alias = "mm", cooldowns = { "Rapid Fire" } },
    { name = "Survival", alias = "survival", cooldowns = { "Rapid Fire", "Deterrence" } },
}) do
    local t = tree
    ns.RegisterSpec{
        spells = spells,
        class = "HUNTER", tree = t, name = def.name, alias = def.alias, default = def.default, ranged = true,
        filler = { "Arcane Shot", "Auto Shot" },
        melee = { "Raptor Strike", "Wing Clip" },
        cooldowns = def.cooldowns,
        resource = function() return ns.PctShown(ns.PT.Mana), 0.3, 0.6, 1 end,
        next = function() return Rotation(t) end,
    }
end
