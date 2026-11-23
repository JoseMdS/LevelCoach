---
status: beslutad
ägare: JoseMdS
datum: 2026-11-21
krav: [LC-KRAV-004, LC-KRAV-008, LC-KRAV-009]
---

# ADR-0002: Förmågor slås upp på namn, och dolda värden uppskattas från egna kast

## Sammanhang
WoW Forever är ett Classic-era-spel där förmågor har ranker, specs kommer från talangträd och många förmågor har bytt namn eller ändrats. Forever kan dessutom dölja stridsdata för addons (rage/energy/mana, auror, cooldowns, målets hälsa) och ger inte addons stridsloggen.

## Beslut
- Rotationerna skrivs med förmågornas **namn**. `Core.lua` slår upp namnet i spellboken och använder högsta rang man kan.
- När spelet döljer ett värde använder LevelCoach **egna kast** i stället: cooldown från när förmågan senast kastades, buffar och dots från normal varaktighet, combo points från byggare och finishers, och en uppskattad resurs (`~45`, `30+`, `<15`).

## Konsekvenser
- Samma spec-fil fungerar för alla ranker och föreslår bara förmågor man har lärt sig.
- En omdöpt förmåga hittas inte förrän namnet rättas (`/lc spells` visar det).
- Uppskattningarna kan vara fel, till exempel om en förmåga kastas utan att addonen ser det. `/lc debug` visar vad som är dolt.

## Alternativ som valdes bort
- **Spell-id per rang:** kräver listor för varje rang och klientvariant, och bryts när Forever ändrar förmågor.
- **Dölja addonen när data saknas:** skulle göra den oanvändbar i just de lägen där Forever döljer data.
