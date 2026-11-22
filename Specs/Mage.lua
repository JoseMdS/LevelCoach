local _, ns = ...
if ns.playerClass ~= "MAGE" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

-- One priority list for all three trees; only the main nuke and a few talents differ.
local function Buffs()
    if ns.InCombat() then return nil end
    if not HasBuff("Arcane Intellect") and not HasBuff("Arcane Brilliance") and Ready("Arcane Intellect") then
        return "Arcane Intellect"
    end
    if not ns.HasBuffLike(" Armor$") then
        local armor = ReadyAny("Mage Armor", "Ice Armor", "Frost Armor")
        if armor then return armor end
    end
    if not HasBuff("Ice Barrier") and ns.HasHostileTarget() and Ready("Ice Barrier") then return "Ice Barrier" end
end

local function Rotation(tree)
    local buff = Buffs()
    if buff then return buff end
    if not ns.HasHostileTarget() then return nil end

    local hp, mana, enemies = ns.HealthPct(), ns.PowerPct(ns.PT.Mana), ns.Enemies()
    local melee = ns.InMelee()

    -- Survive
    if hp < 50 and ns.InCombat() and not HasBuff("Ice Barrier") and Ready("Ice Barrier") then return "Ice Barrier" end
    if hp < 40 and ns.InCombat() and Ready("Mana Shield") and not HasBuff("Mana Shield") and mana > 30 then
        return "Mana Shield"
    end
    -- Out of mana: Evocation, otherwise the wand
    if mana < 10 and ns.InCombat() then
        if Ready("Evocation") then return "Evocation" end
        local wand = ns.Wand()
        if wand then return wand end
    end

    -- Something hitting you: root it, and burn packs down at point blank
    if melee and ns.InCombat() then
        if Ready("Frost Nova") then return "Frost Nova" end
        if enemies >= 3 and mana > 30 and Ready("Arcane Explosion") then return "Arcane Explosion" end
        if enemies >= 2 and mana > 30 and Ready("Cone of Cold") then return "Cone of Cold" end
    end
    -- Leveling: finish a dying mob with an instant instead of a cast
    if not ns.Lives(15) and not ns.Endgame() and Ready("Fire Blast") then return "Fire Blast" end
    -- Packs that aren't on you yet
    if enemies >= 3 and mana > 40 and not melee then
        local aoe = ReadyAny("Blizzard", "Flamestrike")
        if aoe then return aoe end
    end

    if tree == 2 then -- Fire
        if not ns.InCombat() and ns.Lives(70) and Ready("Pyroblast") then return "Pyroblast" end
        if mana > 40 and Ready("Fire Blast") then return "Fire Blast" end
        if Ready("Fireball") then return "Fireball" end
    elseif tree == 1 then -- Arcane
        -- Forever: Arcane Blast while waiting for a Missile Barrage (or Clearcasting) proc, then Arcane Missiles
        if (HasBuff("Missile Barrage") or HasBuff("Clearcasting")) and Ready("Arcane Missiles") then return "Arcane Missiles" end
        if Known("Arcane Blast") then
            if mana > 15 and Ready("Arcane Blast") then return "Arcane Blast" end
        elseif mana > 50 and Ready("Arcane Missiles") then return "Arcane Missiles" end
        local nuke = ReadyAny("Frostbolt", "Fireball")
        if nuke then return nuke end
    else -- Frost (and the default before talents)
        if ns.InCombat() and mana > 50 and Ready("Fire Blast") then return "Fire Blast" end
        local nuke = ReadyAny("Frostbolt", "Fireball")
        if nuke then return nuke end
    end
    return ns.Wand()
end

local spells = { "Fireball", "Frostbolt", "Fire Blast", "Arcane Missiles", "Arcane Blast", "Pyroblast", "Scorch", "Frost Nova",
    "Cone of Cold", "Arcane Explosion", "Blizzard", "Flamestrike", "Counterspell", "Evocation", "Ice Barrier",
    "Mana Shield", "Arcane Intellect", "Mage Armor", "Ice Armor", "Frost Armor", "Shoot" }

for tree, def in ipairs({
    { name = "Arcane", cooldowns = { "Arcane Power", "Presence of Mind", "Evocation" }, filler = { "Arcane Blast", "Arcane Missiles", "Frostbolt", "Fireball" } },
    { name = "Fire", cooldowns = { "Combustion", "Blast Wave", "Evocation" }, filler = { "Fireball" } },
    { name = "Frost", cooldowns = { "Cold Snap", "Ice Block", "Evocation" }, filler = { "Frostbolt", "Fireball" }, default = true },
}) do
    local t = tree
    ns.RegisterSpec{
        spells = spells,
        class = "MAGE", tree = t, name = def.name, default = def.default, ranged = true,
        filler = def.filler,
        interrupt = "Counterspell",
        cooldowns = def.cooldowns,
        resource = function() return ns.PctShown(ns.PT.Mana), 0.3, 0.6, 1 end,
        next = function() return Rotation(t) end,
    }
end
