local _, ns = ...
if ns.playerClass ~= "WARLOCK" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

local function Buffs()
    if ns.InCombat() then return nil end
    if not HasBuff("Demon Armor") and not HasBuff("Demon Skin") then
        local armor = ReadyAny("Demon Armor", "Demon Skin")
        if armor then return armor end
    end
    if not ns.HasPet() then
        -- Voidwalker tanks for you while leveling; Imp before you have one
        local pet = ReadyAny("Summon Voidwalker", "Summon Imp")
        if pet then return pet end
    end
end

-- Dot it up (only on mobs that live long enough), then fill
local function Rotation(tree)
    local buff = Buffs()
    if buff then return buff end
    if not ns.HasHostileTarget() then return nil end

    local hp, mana = ns.HealthPct(), ns.PowerPct(ns.PT.Mana)

    -- Survive
    if hp < 25 and ns.InCombat() and Ready("Death Coil") then return "Death Coil" end
    if hp < 40 and ns.InCombat() and mana > 15 and Ready("Drain Life") then return "Drain Life" end
    -- Mana from health while you can spare it
    if mana < 25 and hp > 60 and Ready("Life Tap") then return "Life Tap" end

    -- Dying mob: Shadowburn (Destruction), or Drain Soul for a shard when you're low on them
    if not ns.Lives(20) and not ns.Endgame() then
        if tree == 3 and Ready("Shadowburn") then return "Shadowburn" end
        local shards = ns.SoulShards()
        if shards and shards < 5 and Ready("Drain Soul") then return "Drain Soul" end
    end

    if mana > 15 then
        if tree == 3 then
            if ns.Lives(50) and ns.Debuff("Immolate") == 0 and Ready("Immolate") then return "Immolate" end
            if ns.Debuff("Immolate") > 0 and Ready("Conflagrate") then return "Conflagrate" end
        end
        if ns.Lives(40) then
            -- Forever renamed Curse of Agony to Bane of Agony; Classic Era keeps the old name
            if ns.Debuff("Bane of Agony") == 0 and ns.Debuff("Curse of Agony") == 0 then
                local bane = ReadyAny("Bane of Agony", "Curse of Agony")
                if bane then return bane end
            end
            if ns.Debuff("Corruption") == 0 and Ready("Corruption") then return "Corruption" end
            if tree == 1 and ns.Debuff("Siphon Life") == 0 and Ready("Siphon Life") then return "Siphon Life" end
        end
        if tree ~= 3 and ns.Lives(60) and ns.Debuff("Immolate") == 0 and mana > 50 and Ready("Immolate") then
            return "Immolate"
        end
        if Ready("Shadow Bolt") then return "Shadow Bolt" end
    end
    -- Low on mana and health: wand while the dots work
    return ns.Wand()
end

local spells = { "Shadow Bolt", "Immolate", "Corruption", "Bane of Agony", "Curse of Agony", "Siphon Life", "Conflagrate",
    "Shadowburn", "Drain Life", "Drain Soul", "Life Tap", "Death Coil", "Demon Armor", "Demon Skin",
    "Summon Voidwalker", "Summon Imp", "Shoot" }

for tree, def in ipairs({
    { name = "Affliction", cooldowns = { "Amplify Curse", "Dark Pact" }, default = true },
    { name = "Demonology", alias = "demo", cooldowns = { "Fel Domination" } },
    { name = "Destruction", alias = "destro", cooldowns = { "Death Coil" } },
}) do
    local t = tree
    ns.RegisterSpec{
        spells = spells,
        class = "WARLOCK", tree = t, name = def.name, alias = def.alias, default = def.default, ranged = true,
        filler = { "Shadow Bolt" },
        cooldowns = def.cooldowns,
        resource = function() return ns.PctShown(ns.PT.Mana), 0.5, 0.3, 0.8 end,
        next = function() return Rotation(t) end,
    }
end
