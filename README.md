# LevelCoach for WoW Forever: leveling rotation helper

LevelCoach shows one big glowing icon for the ability to press next, with its keybind. A red icon appears
when your target's cast can be interrupted, and a row of gold-bordered icons shows your cooldowns when they're ready.

**Supported specs:** Fury and Protection Warrior, Assassination and Combat (Outlaw) Rogue, Elemental and Enhancement Shaman,
Retribution and Protection Paladin, Feral (cat) and Bear Druid, Arcane, Fire and Frost Mage, Affliction,
Demonology and Destruction Warlock, Beast Mastery, Marksmanship and Survival Hunter, and Shadow Priest.
On any other class or spec (healers, Arms, Subtlety, Balance), LevelCoach stays hidden and does nothing.
Only your own class's rotations are loaded; on an unsupported class the addon switches itself off completely.

**How it picks your spec:** it uses the talent tree with the most points and follows dual spec.
Druids get the bear rotation in Bear Form and the cat rotation otherwise. Before you have talent points it
uses Fury, Assassination, Enhancement, Retribution, Frost, Affliction, Beast Mastery or Shadow.
A Druid uses cat (or caster/bear before Cat Form).
If detection ever picks wrong, force it with `/lc spec fury` (or `protwarrior`, `assassination`, `outlaw`,
`elemental`, `enhancement`, `retribution`, `protpaladin`, `cat`, `bear`, `arcane`, `fire`, `frost`,
`affliction`, `demo`, `destro`, `bm`, `mm`, `survival`, `shadow`), and switch back with `/lc spec auto`.

Casters and hunters count enemies by the mobs fighting you (nameplates on). To know when a mob reaches
you in melee, casters need the Attack ability somewhere on an action bar (any bar, even one you hide).

Spells are looked up by name in your spellbook, so it always uses your highest rank and only suggests
spells you've learned.

## Install
1. Unzip so the `LevelCoach` folder sits in the AddOns folder of your Forever install, like
   `World of Warcraft/<forever folder>/Interface/AddOns/LevelCoach/LevelCoach.toc`.
   The Forever folder name may be something like `_forever_`. Use whichever folder sits next to `Interface` in your Forever install.
2. On character select, click **AddOns** and tick LevelCoach. If it says "Out of date", tick **Load out of date AddOns**.
3. In game, drag the icon where you want it, then type `/lc lock`.
4. Turn on enemy nameplates (default key `V`) so it can count nearby enemies for AoE suggestions.

## Commands
- `/lc lock` / `/lc unlock` lock or unlock the icon's position
- `/lc scale 1.2` changes the size
- `/lc cds` turns the cooldown row on or off
- `/lc swing` turns the swing timer bars (above the icon) on or off. Not available on Forever (see below).
- `/lc mode auto|leveling|endgame` sets the rotation. Auto switches to the endgame rotation at level 60, which skips leveling shortcuts like finishing dying mobs early or skipping dots on mobs about to die.
- `/lc debug` shows which combat data the game hides from addons and the last error
- `/lc twist` (off by default) turns on seal twisting for Ret (needs Seal of Command, Seal of Righteousness and a weapon of 3.2 speed or slower) and totem twisting for Enhancement (Windfury and Grace of Air Totem). Both cost a lot of mana and pay off mostly in groups. Seal twisting needs the swing timer, so on Forever only totem twisting works.
- `/lc keys` turns the keybind text on or off
- `/lc always` shows it even out of combat
- `/lc reset` puts the icon back in the default position
- `/lc shred` always suggests Shred instead of Claw (normally only when the mob is attacking someone else)
- `/lc spells` lists which abilities it found in your spellbook and which it didn't
- `/lc talents` shows your points per tree
- `/lc spec ...` forces a spec (see above)
- `/lc` shows the active spec and help

## Important notes for Forever
- Forever can hide combat data from addons, like rage/energy/mana, auras, cooldowns and target health.
  When that happens LevelCoach tracks your own casts instead: cooldowns from the time you last cast,
  buffs and dots from their normal duration, and combo points from your builders and finishers.
  While the game hides your rage/energy/mana, the text under the icon shows an estimate instead:
  `~45` is a best guess (last real value plus energy regen, minus what you've spent), `30+` means you
  can afford a 30-cost ability but nothing pricier, and `<15` means you're short of your cheapest one.
  `/lc debug` lists what's hidden.
- Forever doesn't let addons read the combat log, so there is no swing timer there: `/lc swing` shows nothing,
  Ret seal twisting is off, and Fury doesn't suggest Slam (it needs the swing timer to fit Slam between swings).
  All three work on the Classic Era client.
- There's no question-mark icon any more. When nothing can be suggested, the icon shows your spec's core
  ability dimmed (for example Bloodthirst or Heroic Strike for Fury, Shield Slam or Sunder Armor for
  Protection, Sinister Strike for Combat), or auto attack if you don't know any of them yet.
- Forever launched on 4 Nov 2026 and its class changes are still moving. The priorities follow Classic-era
  leveling play, plus the Forever changes known so far: baseline Victory Rush and Whirlwind for Warriors,
  Reckless Swings, Shank, Mutilate, Venom, Holy Strike on a cooldown, Consecration at 20, Primal Bite
  replacing Mangle, and no Tiger's Fury. If an ability is renamed in game, `/lc spells` will show it as
  not found. Tell me the in-game name and I'll update it.
- Interface number 16001 comes from an addon author's report and Blizzard hasn't confirmed it. If the game
  flags the addon as out of date, it still works with "Load out of date AddOns" ticked.
- Classic poisons are items, not spells, so the Rogue rotation doesn't remind you to apply them.
- Adding a spec: create `Specs/<Class><Spec>.lua` that calls `ns.RegisterSpec{...}` (copy an existing one)
  and list it in `LevelCoach.toc` before `Display.lua`.
