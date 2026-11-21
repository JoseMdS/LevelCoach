local _, ns = ...
local Ready, ReadyAny, Known, HasBuff = ns.Ready, ns.ReadyAny, ns.Known, ns.HasBuff

-- Shared paladin helpers (also used by the Protection file)
ns.Paladin = ns.Paladin or {}
function ns.Paladin.Buffs(auraOrder, blessingOrder)
    if not ns.InCombat() then
        if not ns.HasBuffLike(" Aura$") then
            local a = ReadyAny(unpack(auraOrder))
            if a then return a end
        end
        if not ns.HasBuffLike("^Blessing of") and not ns.HasBuffLike("^Greater Blessing of") then
            local b = ReadyAny(unpack(blessingOrder))
            if b then return b end
        end
    end
end
function ns.Paladin.UndeadOrDemon()
    local t = ns.TargetType()
    return t == "Undead" or t == "Demon"
end

ns.RegisterSpec{
    spells = { "Holy Strike", "Crusader Strike", "Hammer of Justice", "Repentance", "Divine Favor", "Retribution Aura", "Devotion Aura", "Blessing of Might", "Divine Protection", "Flash of Light", "Holy Light", "Seal of the Crusader", "Judgement", "Seal of Command", "Seal of Righteousness", "Exorcism", "Hammer of Wrath", "Consecration" },
    class = "PALADIN", tree = 3, name = "Retribution", default = true,
    filler = { "Crusader Strike", "Holy Strike", "Judgement" }, -- shown dimmed when nothing else fits
    melee = { "Holy Strike", "Crusader Strike" },
    interrupt = "Hammer of Justice",
    cooldowns = { "Repentance", "Divine Favor" },
    resource = function() return ns.PctShown(ns.PT.Mana), 0.4, 0.6, 1 end,
    next = function()
        local buff = ns.Paladin.Buffs({ "Retribution Aura", "Devotion Aura" }, { "Blessing of Might" })
        if buff then return buff end
        if not ns.HasHostileTarget() then return nil end

        local hp, mana = ns.HealthPct(), ns.PowerPct(ns.PT.Mana)
        local sealed = ns.HasBuffLike("^Seal of")

        -- Survive
        if hp < 30 and Ready("Divine Protection") then return "Divine Protection" end
        if hp < 40 then
            local heal = ReadyAny("Flash of Light", "Holy Light")
            if heal then return heal end
        end
        -- Opener on healthy mobs: Seal of the Crusader -> Judgement (debuff), then your main seal
        local crusaderUp = ns.TargetHasDebuff("Judgement of the Crusader")
        if Known("Seal of the Crusader") and not crusaderUp and ns.Lives(60) and Known("Judgement") then
            if HasBuff("Seal of the Crusader") then
                if Ready("Judgement") and ns.InRange("Judgement") ~= false then return "Judgement" end
            elseif ns.CooldownRemaining("Judgement") < 2 and Ready("Seal of the Crusader") then
                return "Seal of the Crusader"
            end
        end
        if not sealed or (HasBuff("Seal of the Crusader") and crusaderUp) then
            local seal = ReadyAny("Seal of Command", "Seal of Righteousness")
            if seal then return seal end
        end

        if not ns.InMelee() then
            if sealed and Ready("Judgement") and ns.InRange("Judgement") then return "Judgement" end
            if ns.Paladin.UndeadOrDemon() and Ready("Exorcism") then return "Exorcism" end
            if Ready("Hammer of Wrath") and ns.InRange("Hammer of Wrath") then return "Hammer of Wrath" end
            return nil
        end

        -- Seal twisting (opt-in, /lc twist): Seal of Command up; just before the swing lands swap to
        -- Seal of Righteousness so that swing gets both, then right after the swing go back to Command.
        -- Needs a slow weapon so two global cooldowns fit inside one swing.
        if ns.Twist() and ns.SwingActive and ns.SwingActive() and Known("Seal of Command")
           and Known("Seal of Righteousness") and mana > 40 and (ns.swing.mh.speed or 0) >= 3.2 then
            local before, after = ns.SwingRemaining("mh"), ns.SwingSince("mh")
            if HasBuff("Seal of Righteousness") and after < 1.2 and before > 1.6 and Ready("Seal of Command") then
                return "Seal of Command"
            end
            if HasBuff("Seal of Command") and before < 0.5 and ns.GCDRemaining() < 0.05
               and Ready("Seal of Righteousness") then
                return "Seal of Righteousness"
            end
        end
        if Ready("Hammer of Wrath") then return "Hammer of Wrath" end
        local strike = ReadyAny("Holy Strike", "Crusader Strike")
        if strike then return strike end
        -- Judge your main seal only (keep Seal of the Crusader for the opener), then reseal
        if sealed and not HasBuff("Seal of the Crusader") and mana > 20 and Ready("Judgement") then return "Judgement" end
        if ns.Paladin.UndeadOrDemon() and Ready("Exorcism") then return "Exorcism" end
        if ns.Enemies() >= 2 and mana > 40 and Ready("Consecration") then return "Consecration" end
    end,
}
