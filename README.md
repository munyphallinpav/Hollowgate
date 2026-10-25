# Hollowgate

A 2.5D pixel-art **action RPG / survival** game for **Godot 4.4 or newer** (GDScript, Compatibility renderer).
Real-time combat, a walled town with shops and a guild, a procedurally generated wild world with biomes,
hidden dungeons that appear and vanish, and a full custom **Dungeon Editor**.

"2.5D" here is the classic top-down ¾ pixel-art look: walls and cliffs have visible front faces, everything is
depth-sorted by its feet, every character casts a shadow, and things really leave the ground — leaps, pounces,
knock-ups, flying wyverns and phoenixes, lobbed boulders, falling meteors and bombs all have a height that the
shadow follows.

All art (characters, 16 monsters, tiles, buildings, icons, effects) is generated procedurally by the Python
scripts in `tools/art/`, and all sounds and music are synthesized at runtime, so the project has no external assets.

## Running

1. Install **Godot 4.4 or newer** (tested on 4.4.1 and 4.7.2) from <https://godotengine.org>.
2. Open Godot → **Import** → select `project.godot` in this folder → **Import & Edit**.
   The first import takes a few seconds while Godot imports the sprites.
3. Press **F5** (Run Project).

## Controls (all rebindable in Menu → Settings)

| Action | Default |
|---|---|
| Move | WASD / arrow keys |
| Aim | Mouse |
| Basic attack | Left mouse (hold for auto-attack) |
| Dash (immune to attacks while dashing) | Space / Shift |
| Skills 1–4 | 1, 2, 3, 4 (slot 4 also Right mouse) |
| Consumables 1–4 | Z, X, C, V |
| Interact (NPCs, chests, portals) | E / F |
| Teleport to town (channel 1.5 s) | T |
| Inventory / Character / Skills / Quests / Map | I (Tab) / P / K / J / M |
| Dungeon Editor | B |
| Menu / close window | Esc |
| Camera zoom | Mouse wheel |

## Features

### Character building
- 5 classes — **Warrior** (Sword & Shield, STR), **Ranger** (Bow, DEX), **Assassin** (Dagger, LUK),
  **Mage** (Wand/Grimoire, INT), **Priest** (Wand/Grimoire, MND, buffs/debuffs/heals).
  Using your class weapon gives +15% damage and +10% speed.
- Level cap **100**. Each level: full HP/MP restore, **+10 stat points**, **+5 skill points**.
- Main stats STR / VIT / INT / MND / DEX / LUK feeding HP, MP, Phys/Magic Atk & Def, Attack/Cast Speed,
  Crit Rate/Damage, Drop Rate, Move Speed and per-element resistances.
- Each class has its own **skill tree of 10 actives + 10 passives** in 5 tiers with prerequisites,
  plus a **Common tree** (3 actives, 8 passives) and **6 Tome skills** learned from spellbooks bought at the Magic Shop.
  Every active skill has one of six elements: light, dark, fire, water, earth, wind
  (Water > Fire > Earth > Wind > Water; Light ⇄ Dark). Only **4 actives** can be equipped (drag them onto the hotbar).
- Skills have their own animated effects: slashes, shockwaves, leaps with landing quakes, falling holy swords and
  meteors with shadow telegraphs, tornadoes, black holes, beams, arrow rain, summons (hawk, shadow clone, angel),
  shields, auras and passive procs (Counter, Last Stand, Resurrection, Spell Echo, Martyr...).

### Inventory
- Sort (type / rarity / name / value), filter (gear / weapons / armor / accessories / consumables / materials /
  special), stack all, split (Shift+click), discard (right-click menu), drag & drop to move, equip, or put items
  on the hotbar.
- Item types: Consumables (potions, food), Materials/Loot, Gear — weapons (Sword, Spear, Hammer, Dagger,
  Wand, Grimoire, Bow, Gun), armor (Heavy, Light, Leather, Robe), accessories (1 Necklace, 2 Rings, 2 Bracelets).
- Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythical (more affixes and higher base stats).
- Blacksmith: **craft** gear from ores + monster parts, **enchant** +1…+15, **reroll** affixes, **salvage**.
- Bag expansion for gold (30 → 120 slots).

### World
- **Hollowgate** town: walls with 4 gates guarded by very strong guards, Adventurer Guild (daily quest board,
  guild ranks F→S), Gear Shop, Blacksmith, Potion Shop, Artifact Shop (limited rare stock), Magic Shop (spellbooks),
  Food Shop, a Waypoint stone back to where you left the wild, and the Dungeon Architect.
- **Teleport to town at any time** with T (also from inside dungeons).
- Procedural 512×512-tile world: Meadow, Deep Forest, Coast, Murk Swamp, Mushroom Grove, Frostlands,
  Sunscorch Desert and Ashen Wastes. Monster level rises with distance from town — gently at first
  (Lv 1–6 within ~25 tiles of the gates), then faster towards Lv 100 at the edges of the world.
- Trees, rocks and ore veins (copper → adamantite) to harvest, passive animals to hunt, a day/night cycle
  (undead roam at night) and a **hunger** meter fed by food.

### Hidden dungeons
- Appear at random places for a limited time, are always marked on the map (even unexplored areas),
  have a **rank 1–100** and vanish once cleared.
- A maze of connected rooms in one of six biomes: **Lava, Forest, Mushroom, Grass Plain, Beach, Cave**.
- Mini bosses spread through the maze, a main boss in the farthest room, and a boss treasure with a
  **unique item** for that boss type.
- Traps: **Bouncing Boulder, Spike Floor, Arrow Turret, Poison Gas, Teleport Rune, Mimic, Pitfall, Falling Bombs**.
- Monster spawning devices: Monster Nest, Cursed Totem (empowers the room), Summoning Circle (ambush), Restless Grave.

### Dungeon Editor (Architect NPC or B)
- **Quick Setup**: choose grid, room count/size, biome, rank, which monsters and traps may appear and how dense,
  treasure count, boss and mini bosses, then Generate.
- **Room Builder** (drag & drop): add/remove rooms, connect doors up/down/left/right, set the start and boss rooms,
  set each room's size and biome, drag monsters / traps / spawners / treasure onto a room (random spot) or onto a
  tile (pinned — and unpin again from the room's contents list), and paint walls (each with its own style),
  cliffs, water and lava. The room view shows the real tiles of the chosen biome and wall styles.
- **Test Run** the dungeon for free (nothing is gained or lost, you return to the editor) and
  **Create Dungeon Crystal** — use the crystal out in the wild to raise your dungeon there.
  Designing, editing and test runs are free; imprinting a crystal costs 100 + 25 × rank gold, because a placed
  dungeon gives real loot (including the boss's unique item).

### Monsters
Slime, Wolf, Tiger, Bear, Goblin, Ogre, Skeleton (melee & archer), Zombie, Treant, Dryad, Lizardman, Mermaid,
Vampire, Wyvern, Dragon, Phoenix — plus Mimic, bats and critters. Each has its own AI (pack lunges, pounces,
ground slams with telegraphs, roots, healing, blinking, summoning, breath attacks, meteor rain, rebirth),
elite / mini boss / boss variants, and bosses enrage at half health.

### Saving
3 save slots. **Auto-saves every minute**, when returning to the title screen, and when the game window is closed.
Saves are in Godot's user data folder (`user://saves/`).

## Project layout

```
project.godot          Godot project (main scene: scenes/main.tscn)
src/autoload/          GameData (formulas/data access), Art (sprite loading), Settings (hotkeys),
                       Sfx (procedural audio), Game (state, inventory, skills, quests, save/load)
src/data/              Skills, items and world/monster databases (plain dictionaries — easy to tweak)
src/core/              Stat calculation, items, combat math, quests, dungeon generation
src/entities/          Actor base, Player, Monster AI, Ally summons, Guard, NPC, projectiles, loot,
                       harvestables, chests, traps, spawners, portals
src/skills/            Skill executor (29 skill behaviours), zones, player traps
src/vfx/               Effect drawing, flash shader, world text
src/world/             Level base, Overworld (chunks, town, spawning, dungeons on the map), DungeonLevel, tile renderer
src/ui/                HUD, menus, shops, blacksmith, guild, dungeon editor, title screen
tools/art/             Python (Pillow) pixel-art generators → assets/sprites + assets/data/art_manifest.json
```

To regenerate or tweak the art: `pip install pillow` then `python3 tools/art/build_all.py`.

## Automated tests (optional)

`src/dev/` holds test tools that never run during normal play. From a terminal in this folder:

```
godot --path . -- --autotest --check          # compile every script
godot --path . -- --autotest --qa             # 200+ functional checks (keys, shops, blacksmith, quests,
                                              #   dungeons, editor drag & drop, save/load, autosave)
godot --path . -- --autotest                  # screenshot tour: every class casts every skill, traps, editor
godot --path . -- --autotest --bot=240 --class=mage   # a bot plays the game for 240 s
```

Add `--shots=/some/folder` to save screenshots. The tests overwrite save slot 3.

## Balancing knobs
- Level curve, monster stats and XP: `src/autoload/game_data.gd` (`xp_to_next`, `mon_hp`, `mon_atk`, ...).
- Player stat formulas: `src/core/stat_calc.gd`.
- Skills: `src/data/data_skills.gd` (power, cost, cooldown, per-level scaling, effect parameters).
- Items, rarities, affixes, prices, recipes: `src/data/data_items.gd`.
- Monsters, attacks, biomes, dungeon content: `src/data/data_world.gd`.
