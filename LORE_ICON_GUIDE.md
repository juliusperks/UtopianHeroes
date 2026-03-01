# UtopianHeroes Lore-to-Icon Guide

This guide translates Utopia race/personality lore into readable, game-ready unit icon direction.

## Sources
- Utopia Wiki: Races & Personalities (Age 113): https://wiki.utopia-game.com/index.php?title=Races_and_Personalities
- Utopia Wiki historical race snapshots (for stable race fantasy identity cues):
  - https://wiki.utopia-game.com/index.php?title=Age_52
  - https://wiki.utopia-game.com/index.php?title=WoL_Races_%28Age_49%29

## Core Readability Rules
- Silhouette first: each icon must be recognizable at 32px.
- Two-layer coding:
  - Race base shape/color.
  - Class overlay glyph.
- Keep face detail minimal; prioritize emblem-like symbols.
- Use one dominant hue per race and one high-contrast neutral for class glyphs.

## Race Visual Language
- `avian`: sky, speed, strike pressure. Motifs: wing, feather, beak profile, spear-tip. Palette: azure/cyan.
- `dwarf`: engineering, durability, economy. Motifs: anvil, hammer, rivets, forge crest. Palette: bronze/iron.
- `elf`: mana, finesse, warding. Motifs: crescent, leaf-blade, arc sigil. Palette: emerald/teal.
- `dark_elf`: shadow arcana, corruption pressure. Motifs: void eye, broken rune, thorn crescent. Palette: violet/indigo.
- `orc`: high gains, war momentum, blood rite. Motifs: tusk, war banner, crude totem, blood mark. Palette: olive/crimson.
- `undead`: plague attrition, death-command. Motifs: skull helm, bone crown, fumes, cracked sigil. Palette: sickly green/ash.
- `halfling`: stealth and thievery utility. Motifs: dagger, coin purse, lockpick. Palette: tan/moss.
- `faerie`: magical throughput and trickery. Motifs: butterfly wing, mote ring, wand spark. Palette: magenta/lilac.
- `human`: order, leadership, economy baseline. Motifs: lion crest, standard, seal. Palette: royal blue/gold.
- `gnome` (non-canonical extension in this project): tinkering-cunning archetype. Motifs: gear, monocle, spark coil. Palette: indigo/steel.
- `dryad` (non-canonical extension in this project): living grove / nature magic archetype. Motifs: branch crown, seed rune, vine knot. Palette: moss/leaf green.

## Class Overlay Glyph System
- `paladin`: shield + cross or radiant kite shield.
- `rogue`: twin daggers / masked eye.
- `general`: banner + star/chevron.
- `sage`: open tome + arcane line.
- `mystic`: crystal + orbit ring.
- `heretic`: inverted triangle + eye/rune crack.
- `shepherd`: staff/crook + leaf node.
- `merchant`: coin stack + trade mark.

## Unit-by-Unit Icon Concepts
- `avian_paladin` Skyguard: winged shield with spear notch.
- `avian_rogue` Talon Shade: feathered dagger over crescent wing.
- `avian_general` Sky Marshal: command chevron over spread wings.

- `dwarf_general` Ironclad Marshal: hammer-and-banner over riveted plate.
- `dwarf_sage` Runesmith: anvil with glowing rune-tome.

- `elf_mystic` Arcane Warden: leaf crystal with orbit ring.
- `elf_paladin` Starlight Knight: crescent shield with star flare.
- `elf_rogue` Moonblade Duelist: curved twin blades crossing moon arc.

- `darkelf_heretic` Void Whisperer: cracked void eye in inverted rune-triangle.
- `darkelf_mystic` Drow Arcanist: dark crystal with broken halo.

- `orc_general` Warlord Grunn: tusk crest with torn war-banner.
- `orc_shepherd` Beast Caller: totem staff with beast fang charm.
- `orc_mystic` Bloodshaman: blood rune bowl + spirit plume.

- `undead_mystic` Plague Seer: skull crystal with toxic mist ring.
- `undead_general` Death Commander: bone crown + command sigil.

- `halfling_rogue` Nimble Filch: lockpick dagger + satchel clasp.
- `halfling_merchant` Cellar Dealer: cask coin-mark and trade seal.

- `faerie_merchant` Dewpetal Trader: winged coin and pollen spark.
- `faerie_sage` Willow Sage: fairy tome with floating motes.

- `human_paladin` Highborne Knight: heraldic shield and sunburst cross.
- `human_general` Royal Commander: royal seal + banner chevron.
- `human_sage` Scholar Mage: formal tome with ordered rune grid.

- `gnome_heretic` Tinkered Prophet: broken gear halo + forbidden eye.
- `gnome_merchant` Gadget Peddler: coin gear + wrench mark.

- `dryad_shepherd` Grove Tender: vine crook + seed emblem.
- `dryad_mystic` Wisp Caller: branch crystal and wisp orbit.

## Free-Use Asset Sourcing Criteria
- Prefer `CC0` packs first.
- Accept `CC BY 4.0` only if attribution file is included in repo.
- Reject `NC`, `ND`, and unknown/custom restrictive terms.
- Keep one icon style family for all races to avoid mixed visual quality.

## Implementation Notes
- Build each icon as 512x512 master, export down to 256 and 128.
- Keep glyph stroke thickness >= 3px at 128 export.
- Place class glyph in lower-right badge for quick role scan.
- Use race color as 65-75% of icon area; class glyph in high-contrast neutral.
