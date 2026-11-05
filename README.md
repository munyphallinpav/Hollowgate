# Hollowgate

A 2.5D pixel-art **action RPG / survival** game for **Godot 4.4 or newer** (GDScript, Compatibility renderer).
Real-time combat, a walled town with shops and a guild, a procedurally generated wild world with biomes,
hidden dungeons that appear and vanish, a full custom **Dungeon Editor**, up to **50 NPC adventurers** who live
the same life as you — befriend them, party up with them, duel them for stakes — and a guild **Dungeon Hall** where
everyone plays everyone else's dungeons for a share of the loot.

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
| Skills 1–4 | 1, 2, 3, 4 (slot 4 also Right mouse) — equip skills in the Skills window (K) with "Equip to" or drag & drop |
| Consumables 1–4 | Z, X, C, V |
| Interact (NPCs, chests, portals) | E / F |
| Teleport to town (channel 1.5 s) | T |
| Inventory / Character / Skills / Quests / Map | I (Tab) / P / K / J / M |
| Dungeon Editor | B |
| Menu / close window | Esc |
| Camera zoom | Mouse wheel |
| Fullscreen on / off | F11 or Alt+Enter |
| Watching a test run | 1 / 2 / 3 follow a runner, Space free camera, WASD move it, Esc → End Test Run |

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
- **Lock** an item (right-click it in your bag → Lock): a padlock shows on it and it is never sold by filter, sold
  by "Sell all Common gear", discarded or salvaged (selling it by hand asks to unlock it first).
- **Sell by filter** (button in every shop): sell many items at once, filtered by
  - **item type** — weapons, armor, accessories, materials, potions & food;
  - **rarity** — any mix of Common … Mythical, with quick presets (Common only, up to Uncommon, up to Rare, all);
  - **item level** range of gear (and a "below my level" preset);
  - **gold value per item** range (e.g. only items worth under 50 gold, or only items worth 500+);
  - **how much gold to raise** — 0 sells everything that matches; a target (say 5 000 gold) sells the cheapest
    matches first and stops as soon as the target is reached.
  Safety rules (on by default): keep gear better than what you wear (only the best piece per slot), enchanted gear,
  boss uniques, materials your guild quests need, and at least N of every potion / food / material stack. Locked
  items, equipped gear, tomes, scrolls and dungeon crystals are never sold by filter. The window shows exactly
  what will be sold and for how much, what your rules held back, and lets you click any item to keep it this
  time; big or valuable batches ask for confirmation. The filter is remembered with your character.
- **Buy back** (tab in every shop): changed your mind? Your last 12 sales — from any shop, sold by hand, by filter
  or as common gear — can be bought back for exactly what you got for them (same item: enchant, affixes and all).
  Repeated sales of one stackable item merge into one entry; if you're short on gold you buy back what you can
  afford. The list is saved with your character.

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

### NPC adventurers
- The game starts with **2–5 adventurers**; more join as you level (start count + your level ÷ 2), up to **50**.
  Newcomers arrive near your level with a matching kit and history.
- They **progress with you**: each one has a personal talent (it settles between 6 levels below and 5 above
  you), catches up fast when far behind and slows to a crawl once ahead, so the crowd stays spread around your level.
- Each one is a full character built exactly like you: a class, level 1–100, stat points spent on a class build,
  a skill tree with 4 equipped actives, gear in every slot, a bag with potions and loot, gold, guild rank and quests.
- They have their own routine: leave town through a gate, walk to an area that suits their level, hunt, drink potions,
  retreat when hurt, come home to turn in quests, sell loot, buy upgrades and equip better drops, enchant their gear
  at the Blacksmith with spare gold, take guild quests, list dungeons in the Dungeon Hall and run other people's
  listed dungeons. They can be defeated (they recover in town) — packs, elites and deadly dungeons take their toll.
- Near you they are **real characters** using the same combat code as the hero (basic attacks, all their skills with full
  effects, a dash to dodge telegraphed attacks — with human reflexes, not perfect ones — and kiting for ranged classes);
  far away they keep living in a lightweight simulation, so the world goes on while you are elsewhere. Their sounds are
  quieter and they never shake your camera.
- **Kill tagging**: the first to hit a monster (you or an adventurer) owns its XP and loot, whoever lands the last blow.
  Adventurers leave monsters you are fighting alone, and a monster claimed by an adventurer shows a grey health bar.
- Talk to one (E) for a **profile**: stats, equipment, bag, skills, quests, record and their listed dungeons — plus
  your bond, gifts, party invitations and duels (below). The guild's **Adventurers** tab lists everyone (your party
  first, with bond names), and they show as coloured dots on the minimap and world map.

### Bonds
- Every adventurer has a **bond** with you: 0–100 in five levels (Stranger → Acquaintance → Friend → Good friend →
  Close friend → Sworn ally). Talk to an adventurer and use **Give item…** or **Give gold…** on its profile.
- Only gifts that **make it stronger** count: gear it can wear (item level up to its level + 5) that beats what it has
  in that slot — it equips it on the spot — potions, food, or materials one of its guild quests needs. Useless gifts are
  politely refused and you keep them. Gold works too (40 + 12 × its level per bond point; only whole points are taken).
- At most **+25 bond per adventurer per in-game day**.
- Bond raises the chance that a stronger adventurer joins your party, how long members stay
  (15 min + 10 min per bond level; **sworn allies stay for good**), and the party's XP bonus.

### Parties
- Invite an adventurer you are talking to: **up to 3 in a party** (you + 2). The chance starts at 75% and drops 9% per
  level the adventurer is above you — strong strangers mostly say no — and every bond level adds 12%. A refusal means
  waiting a minute before asking again.
- Members **follow you** (fighting whatever threatens the group), **teleport to you** when left behind, come along into
  **every dungeon you enter** (and into test runs) and back out, rest and restock with you in town. HP frames for the
  party sit under your status panel.
- **Shared XP**: every kill by anyone in the party is shared — the total grows 15% per extra member (+2% per member bond
  level) and is split evenly, so a party levels faster. A member's kill gives you XP and drops its loot for you.
  Members' guild quests count the party's kills.
- Members leave when their time is up (bond keeps them longer) or when they are defeated; **Part ways** any time.
- Adventurers **team up among themselves** too (up to 3, similar levels): they hunt and run Dungeon Hall listings
  together with better odds, share XP, and break up when back in town. Their profile shows "With X's party".

### Duels
- **Challenge to duel…** on an adventurer's profile (out in the world, not in dungeons). Both sides put up a stake —
  gold and/or up to 4 items (gear, materials) — and the stakes **must be of similar value (within 15%)** before the
  duel can start; the adventurer makes a counter-offer from its own purse and bag, or bet nothing for a friendly bout.
- The adventurer decides whether the bet is worth it from how it rates its chances (shown), its bravery and its bond with you.
- **Winner takes all** and earns **XP** (a share of a level — more for beating a higher level, half for a friendly bout).
- **The Duelling Grounds**: when the duel starts, both duellists (and any summons they have out) are pulled into a
  pocket dimension — a floating stone arena in a starry void, walled by an invisible barrier — and sent back to where
  they stood when it ends, however it ends. The world around the spot you left keeps going (party members hold that
  spot and defend themselves until you return); town teleports and waypoints don't work mid-duel.
- Rules: 3-second countdown, **no potions**, nobody dies — the first to drop to 1 HP loses; ending up outside the
  ring for 3 seconds (e.g. blinking past the barrier) forfeits; after 90 seconds it is a draw and stakes are returned.
- Confident adventurers in town **challenge you** now and then (at most once a day each): they walk up with a **!** over
  their head; talk to them to answer — match their stake or decline. Adventurers also duel each other for gold in town.

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
- **Test Run** the dungeon for free (nothing is gained or lost, you return to the editor with a **report**: result, time,
  rooms explored, monsters defeated, boss HP left, how each runner fared). Choose **who runs it** — up to 3:
  yourself, your party members, and adventurers in town who volunteer. Play it yourself with your party at your side,
  or leave yourself out and **watch it from the spectator camera**: the first runner leads the way room by room to the
  boss, the others follow it; press **1/2/3** to follow a runner, **Space** for a free camera (**WASD** to fly it),
  the mouse wheel zooms out further than usual, **Esc → End Test Run** to stop. Everyone comes back exactly as they went in.
- **Create Dungeon Crystal** — use the crystal out in the wild to raise your dungeon there.
  Designing, editing and test runs are free; imprinting a crystal costs 100 + 25 × rank gold, because a placed
  dungeon gives real loot (including the boss's unique item).

### Guild Dungeon Hall (Adventurer Guild → Dungeon Hall tab)
- **List your Dungeon Crystals** at the guild instead of raising them in the wild: **3 listing slots at rank F**,
  growing with guild rank up to **10 at rank S** (F 3, E 4, D 5, C 6, B 7, A 8, S 10).
- Set the **owner's share** for each listing with the sliders: up to **30% of gold** and **25% of items** found
  inside. Per run the gold share is also capped at 60 + 30 × rank, and lower shares attract more adventurers.
- NPC adventurers whose level fits the dungeon's rank run it; you see each result in the hall log and the
  listing's played / cleared / failed / earned counters. Your shares pile up at the guild — press **Collect**.
- **How you built it matters.** Each listing gets a **Danger** and **Loot** rating against a standard dungeon of its rank
  (also shown live in the Dungeon Architect's status bar). Danger — monsters, mini bosses, traps and spawners per room,
  plus length — decides how many runners clear it and how many are defeated; Loot — chests, mini bosses, monsters —
  decides how much gold and how many items they bring out, and so your share. Adventurers prefer dungeons they can
  clear that pay well, and a bad clear record keeps them away.
- You can **Enter** dungeons listed by NPC adventurers (once per day each). Gold you pick up shows the owner's cut,
  and some items go to the owner; leaving pays them and records the clear. NPCs play each other's dungeons too,
  follow the same 3–10 slot rule, and take down dungeons they have outgrown.
- Withdraw a listing at any time to get the crystal back.

### Monsters
Slime, Wolf, Tiger, Bear, Goblin, Ogre, Skeleton (melee & archer), Zombie, Treant, Dryad, Lizardman, Mermaid,
Vampire, Wyvern, Dragon, Phoenix — plus Mimic, bats and critters. Each has its own AI (pack lunges, pounces,
ground slams with telegraphs, roots, healing, blinking, summoning, breath attacks, meteor rain, rebirth),
elite / mini boss / boss variants, and bosses enrage at half health.

### Display: any resolution, fullscreen
- **Menu → Settings → Display**: Windowed / **Fullscreen (borderless)** / **Exclusive fullscreen**, window size
  (common 16:9, 16:10, 4:3, 5:4 and 21:9 sizes that fit your monitor, or "Automatic" = the largest 16:9 size that fits
  comfortably), which monitor to use (with more than one), scaling, crisp pixel art, VSync and a frame-rate limit
  (30–240 or unlimited). **F11** or **Alt+Enter** toggles fullscreen at any time; a size you drag the window to is
  remembered. Command-line `--resolution WxH` / `--fullscreen` override the saved choice for that launch.
- Switching is done step by step: the game waits for the system to finish each change (leaving fullscreen can take
  a moment) and then sets its scaling from the size the window really has, so the picture and the mouse always line
  up — however quickly you switch, and even if the system or a tiling window manager picks another size.
- **Running from the Godot editor (F5):** Godot 4.4+ shows the game inside the editor's *Game* tab by default, and
  there the editor owns the window. The game then leaves window size, fullscreen and monitor alone (those options
  are greyed out with a note) — resizing an embedded game from inside would put the picture and the mouse out of
  step. Use the exported game, or turn off **Embed Game on Next Play** in the Game tab, to try them.
- Any resolution and aspect ratio works, from an 800 × 450 window to 4K: everything is laid out for a 1280 × 720 view
  that scales to fill the window, and on wider (ultrawide) or taller (4:3, 16:10) screens the view grows instead of
  showing black bars — you see more of the world and the HUD stays at the edges. Menus never leave the screen.
- **Scaling**: *Fit to window* uses every pixel. *Pixel-perfect* scales in whole steps only (×1, ×2, ×3 — e.g. ×1 at
  1920 × 1080, ×2 at 2560 × 1440, ×3 at 4K) for perfectly even pixels, showing a bigger view between steps rather than
  black bars; a window smaller than 1280 × 720 always uses Fit so nothing gets cut off. *Crisp pixel art* (on by
  default) nudges the camera zoom so one art pixel always covers a whole number of screen pixels — no uneven,
  shimmering pixels at in-between scales like ×1.5.

### Saving
3 save slots. **Auto-saves every minute** (never mid-duel), when returning to the title screen, and when the game window
is closed (a duel in progress is called off and the stakes returned).
Saves are in Godot's user data folder (`user://saves/`).

## Debug mode

Available when running from the Godot editor (or a debug export), or when started with
`godot --path . -- --debug-mode`. Release exports don't have it.

| Key | |
|---|---|
| **F3** | Info overlay: FPS, frame/physics time, nodes, draw calls, memory, position, tile/chunk, biome, area level, dungeon room, monster and adventurer counts, active cheats |
| **F4** | Cheat panel (pauses the game) |

The cheat panel offers:
- **Cheats:** god mode, one-hit kills, free skills (no MP or cooldowns), no hunger, noclip, fast movement, and game speed ×0.25 to ×4
- **Character:** +1/+10/max level, gold, stat and skill points, guild points, full restore
- **Items:** random gear of a chosen item level and rarity, 10 of every consumable
- **Monsters:** spawn any monster type at the mouse (level, tier, count), kill nearby or all monsters
- **World:** teleport to the mouse or to town, reveal the world map, set the time, spawn a hidden dungeon, add an NPC adventurer, save now

"At mouse" uses the cursor position from when the panel was opened. Cheats are never saved, and duels
ignore god mode and one-hit kills.

## Project layout

```
project.godot          Godot project (main scene: scenes/main.tscn)
src/autoload/          GameData (formulas/data access), Art (sprite loading), Settings (hotkeys),
                       Sfx (procedural audio), Game (state, inventory, skills, quests, save/load),
                       DebugMode (F3 overlay / F4 cheats)
src/data/              Skills, items and world/monster databases (plain dictionaries — easy to tweak)
src/core/              Stat calculation, items, combat math, quests, dungeon generation,
                       NpcWorld (NPC adventurers' simulation + guild Dungeon Hall),
                       Social (bonds, parties), Duel (staked duels)
src/entities/          Actor base, Player, Adventurer (NPC AI on top of Player), Monster AI, Ally summons, Guard, NPC, projectiles, loot,
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
godot --path . -- --autotest --keytest        # hotkeys 1-4 / V for every class at Lv 3, buffered presses
godot --path . -- --autotest --npctest        # NPC adventurers (2 sim hours, growth to 50, live fights, crowd cost)
                                              #   and the Dungeon Hall (slots, shares, runs, payouts, save/load)
godot --path . -- --autotest --debugtest      # debug mode: overlay, cheat panel, every cheat
godot --path . -- --autotest --tagtest        # kill tagging, adventurers' manners, live fights vs elites and a boss
godot --path . -- --autotest --selltest       # selling by filter (rarity, level, value, type, gold target), locks, buyback
godot --path . -- --autotest --socialtest     # bonds, gifts, parties (follow, teleport, shared XP, dungeons), duels,
                                              #   adventurer parties, spectated and party test runs
godot --path . --resolution 2560x1080 -- --autotest --restest [--pixelperfect] [--modes]
                                              # HUD and every window fit at that window size; --modes switches
                                              #   fullscreen / exclusive / window sizes / pixel-perfect at runtime
godot --path . --resolution 1600x900 -- --autotest --aligntest [--fake-embedded]
                                              # switches sizes / modes / scaling around through the Settings page and
                                              #   checks the real mouse pointer lands on what is drawn under it
                                              #   (menus, HUD, world aim, right-click menus); --fake-embedded acts
                                              #   as if running inside the editor's Game tab
godot --path . -- --autotest --simstat        # balance probe: an hour of NPC life at hero Lv 5/20/45/80
godot --path . -- --autotest --balance        # balance probe: fully built characters vs monsters of their level
godot --path . -- --autotest --bot=240 --class=mage   # a bot plays the game for 240 s
```

Add `--shots=/some/folder` to save screenshots. The tests overwrite save slot 3.

## Balancing knobs
- Level curve, monster stats and XP: `src/autoload/game_data.gd` (`xp_to_next`, `mon_hp`, `mon_atk`, ...).
- Player stat formulas: `src/core/stat_calc.gd`.
- Skills: `src/data/data_skills.gd` (power, cost, cooldown, per-level scaling, effect parameters).
- Items, rarities, affixes, prices, recipes: `src/data/data_items.gd`.
- Monsters, attacks, biomes, dungeon content: `src/data/data_world.gd`.
- NPC adventurers and the Dungeon Hall: constants at the top of `src/core/npc_world.gd` (`MAX_NPCS`, `LISTING_CAPS`,
  `MAX_GOLD_SHARE`, `MAX_ITEM_SHARE`, class builds, armor preferences), `royalty_cap()`, `target_count()`,
  `xp_catchup()` (how closely they follow your level), `_sim_hunt()` (off-screen danger), `design_scores()` /
  `listing_profile()` / `clear_chance()` (Dungeon Hall ratings and outcomes). Live AI reflexes: `reflex()` in
  `src/entities/adventurer.gd`.
- Bonds and parties: constants at the top of `src/core/social.gd` (`BOND_PER_DAY`, `PARTY_MAX`, `PARTY_SHARE_BONUS`),
  `gift_check()`, `gold_per_bond()`, `invite_chance()`, `party_stay()`. Duels: top of `src/core/duel.gd`
  (`MATCH_TOLERANCE`, `RING`, `TIME_LIMIT`), `npc_accepts()`, `xp_reward()`.
