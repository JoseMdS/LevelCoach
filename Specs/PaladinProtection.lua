local _, ns = ...
if ns.playerClass ~= "PALADIN" then return end -- other classes never build this spec
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

ns.RegisterSpec{
    spells = { "Holy Strike", "Crusader Strike", "Hammer of Justice", "Templar's Bulwark", "Divine Protection", "Lay on Hands", "Righteous Fury", "Devotion Aura", "Retribution Aura", "Blessing of Sanctuary", "Blessing of Kings", "Blessing of Might", "Flash of Light", "Holy Light", "Seal of Fury", "Seal of Righteousness", "Avenger's Shield", "Judgement", "Exorcism", "Holy Shield", "Consecration", "Hammer of the Righteous", "Hammer of Wrath" },
    class = "PALADIN", tree = 2, name = "Protection", alias = "protpaladin",
    filler = { "Holy Shield", "Holy Strike", "Judgement" }, -- shown dimmed when nothing else fits
    melee = { "Holy Strike", "Crusader Strike" },
    interrupt = "Hammer of Justice",
    cooldowns = { "Templar's Bulwark", "Divine Protection", "Lay on Hands" },
    resource = function() return ns.PctShown(ns.PT.Mana), 0.4, 0.6, 1 end,
    next = function()
        if not HasBuff("Righteous Fury") and Ready("Righteous Fury") then return "Righteous Fury" end
        local buff = ns.Paladin.Buffs({ "Devotion Aura", "Retribution Aura" },
                                      { "Blessing of Sanctuary", "Blessing of Kings", "Blessing of Might" })
        if buff then return buff end
        if not ns.HasHostileTarget() then return nil end

        local hp, mana = ns.HealthPct(), ns.PowerPct(ns.PT.Mana)
        local sealed = ns.HasBuffLike("^Seal of")

        if hp < 30 then
            local heal = ReadyAny("Flash of Light", "Holy Light")
            if heal then return heal end
        end
        if not sealed then
            local seal = ReadyAny("Seal of Fury", "Seal of Righteousness")
            if seal then return seal end
        end

        if not ns.InMelee() then
            if Ready("Avenger's Shield") then return "Avenger's Shield" end
            if sealed and Ready("Judgement") and ns.InRange("Judgement") then return "Judgement" end
            if ns.Paladin.UndeadOrDemon() and Ready("Exorcism") then return "Exorcism" end
            return nil
        end

        if ns.InCombat() and not HasBuff("Holy Shield") and Ready("Holy Shield") then return "Holy Shield" end
        if Ready("Avenger's Shield") then return "Avenger's Shield" end
        if Ready("Holy Strike") then return "Holy Strike" end
        if sealed and Ready("Judgement") then return "Judgement" end
        if ns.InCombat() and mana > 25 and Ready("Consecration") then return "Consecration" end
        local strike = ReadyAny("Holy Strike", "Hammer of the Righteous", "Crusader Strike", "Hammer of Wrath")
        if strike then return strike end
        if ns.Paladin.UndeadOrDemon() and mana > 40 and Ready("Exorcism") then return "Exorcism" end
    end,
}
