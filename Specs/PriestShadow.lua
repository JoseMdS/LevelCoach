local _, ns = ...
if ns.playerClass ~= "PRIEST" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

-- Only Shadow is a damage spec; Discipline and Holy priests stay hidden.
ns.RegisterSpec{
    spells = { "Smite", "Holy Fire", "Mind Blast", "Shadow Word: Pain", "Mind Flay", "Vampiric Embrace",
        "Devouring Plague", "Power Word: Shield", "Power Word: Fortitude", "Inner Fire", "Shadowform",
        "Flash Heal", "Renew", "Lesser Heal", "Shoot" },
    class = "PRIEST", tree = 3, name = "Shadow", default = true, ranged = true,
    filler = { "Mind Flay", "Mind Blast", "Smite" },
    interrupt = "Silence",
    cooldowns = { "Inner Focus", "Psychic Scream" },
    resource = function() return ns.PctShown(ns.PT.Mana), 0.3, 0.6, 1 end,
    next = function()
        if not ns.InCombat() then
            if not HasBuff("Power Word: Fortitude") and not HasBuff("Prayer of Fortitude")
               and Ready("Power Word: Fortitude") then return "Power Word: Fortitude" end
            if not HasBuff("Inner Fire") and Ready("Inner Fire") then return "Inner Fire" end
            if not HasBuff("Shadowform") and Ready("Shadowform") then return "Shadowform" end
        end
        if not ns.HasHostileTarget() then return nil end

        local hp, mana = ns.HealthPct(), ns.PowerPct(ns.PT.Mana)
        local shadowform = HasBuff("Shadowform")

        -- Survive: shield (not while Weakened Soul), then heal (Shadowform blocks Holy spells)
        if hp < 50 and ns.InCombat() and not HasBuff("Power Word: Shield")
           and ns.SinceCast("Power Word: Shield") > 15 and Ready("Power Word: Shield") then
            return "Power Word: Shield"
        end
        if hp < 35 and not shadowform then
            local heal = ReadyAny("Flash Heal", "Lesser Heal")
            if heal then return heal end
        end
        -- Leveling: wand down dying mobs and save mana
        if (not ns.Lives(25) and not ns.Endgame()) or mana < 15 then
            local wand = ns.Wand()
            if wand then return wand end
        end

        if ns.Lives(50) and ns.Debuff("Vampiric Embrace") == 0 and Ready("Vampiric Embrace") then return "Vampiric Embrace" end
        if ns.Lives(40) and ns.Debuff("Shadow Word: Pain") == 0 and Ready("Shadow Word: Pain") then return "Shadow Word: Pain" end
        if ns.Lives(50) and ns.Debuff("Devouring Plague") == 0 and Ready("Devouring Plague") then return "Devouring Plague" end
        if Ready("Mind Blast") then return "Mind Blast" end
        if mana > 25 and Ready("Mind Flay") then return "Mind Flay" end
        if not Known("Mind Flay") and not shadowform and mana > 30 then
            local nuke = ReadyAny("Smite", "Holy Fire")
            if nuke then return nuke end
        end
        return ns.Wand()
    end,
}
