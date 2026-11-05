class_name Progression
extends RefCounted
## Feature unlocks and the new-player tutorial.
##
## FEATURES: what unlocks at which character level. A locked feature refuses politely (its button is
## disabled with the level it needs, or a toast says so) and a card announces it the moment you reach the
## level. Everything not listed here is available from the start: combat, bag, character, skills, quests,
## map, the guild's Quest Board, the Gear / Potion / Food shops, teleport to town and the waypoint.
##
## TUTORIAL: a short guided first session for new characters (STEPS, in order). The current step is shown
## in the HUD; each step pays a small reward. It can be skipped from the Quests page (J).
##
## State is saved with the character: Game.player["progression"] =
##   {"seen": [feature ids already announced], "tut_step": int, "tut_done": bool, "tut_base": {...}}

## Automated tests switch the tutorial off (its step rewards would skew their gold checks).
static var tutorial_off := false

const FEATURES := [
	{"id": "blacksmith", "level": 3, "name": "Blacksmith",
		"desc": "Durn's Forge in town: craft gear from ores and monster parts, and salvage gear you don't need."},
	{"id": "dungeons", "level": 5, "name": "Hidden Dungeons",
		"desc": "Glowing portals out in the wild lead to dungeons with a boss and a chest. They vanish after a while — rank shows on the portal."},
	{"id": "bonds", "level": 5, "name": "Bonds & Gifts",
		"desc": "Talk to an adventurer (E) and give it gear, potions or gold that makes it stronger to raise your bond."},
	{"id": "magic_shop", "level": 6, "name": "Magic Shop",
		"desc": "Orren sells spellbooks that teach Tome skills to any class, enchanting supplies and rebirth scrolls."},
	{"id": "party", "level": 8, "name": "Parties",
		"desc": "Invite adventurers to your party (up to 3 with you): they follow you, fight beside you and share XP."},
	{"id": "enchant", "level": 8, "name": "Enchanting",
		"desc": "The Blacksmith can now enchant your gear, +1 up to +15."},
	{"id": "duels", "level": 10, "name": "Duels",
		"desc": "Challenge an adventurer to a staked duel in the Duelling Grounds — and expect to be challenged."},
	{"id": "artifact_shop", "level": 12, "name": "Artifact Shop",
		"desc": "Lys' Curiosities: rare one-of-a-kind treasures, new wares every other day."},
	{"id": "reroll", "level": 14, "name": "Affix Rerolling",
		"desc": "The Blacksmith can now reroll the affixes on your gear."},
	{"id": "dungeon_hall", "level": 15, "name": "Dungeon Hall",
		"desc": "List your dungeon crystals at the guild for other adventurers to run — and run theirs for a share of the loot."},
	{"id": "architect", "level": 18, "name": "Dungeon Architect",
		"desc": "Design your own dungeons room by room with the Dungeon Editor (%s), test them and place them in the world."},
]

## Service roles (town NPCs) that need a feature.
const SERVICE_FEATURE := {"blacksmith": "blacksmith", "magic": "magic_shop", "artifact": "artifact_shop", "architect": "architect"}

const STEPS := [
	{"id": "move", "title": "Find your feet", "gold": 20,
		"text": "Walk around town with %s."},
	{"id": "skill", "title": "Learn a skill", "gold": 20,
		"text": "Open Skills (%s), learn a skill with your skill point and put it on your hotbar (drag it, or use \"Equip to\")."},
	{"id": "quest", "title": "Take a quest", "gold": 30,
		"text": "Visit the Adventurer Guild in town (talk with %s) and accept a quest from the Quest Board."},
	{"id": "gate", "title": "Into the wild", "gold": 20,
		"text": "Leave town through any gate. Monsters close to town are weak (Lv 1–6) and get stronger further out."},
	{"id": "kill", "title": "First blood", "gold": 40, "need": 3,
		"text": "Defeat %d monsters. Left mouse attacks (hold for auto-attack), 1–4 use skills, %s dashes through attacks."},
	{"id": "bag", "title": "Check your loot", "gold": 20,
		"text": "Open your bag (%s). Equip better gear by double-clicking it; potions and food go on Z X C V."},
	{"id": "home", "title": "Back to safety", "gold": 30,
		"text": "Teleport back to town: stand still and press %s (it takes 1.5 s)."},
	{"id": "sell", "title": "Make some coin", "gold": 60,
		"text": "Sell something you don't need at any shop in town. Changed your mind? The shop's Buy back tab returns it."},
]


# =================================================================== state
static func state() -> Dictionary:
	if Game.player.is_empty():
		return {}
	if not Game.player.has("progression") or not (Game.player["progression"] is Dictionary):
		Game.player["progression"] = {"seen": [], "tut_step": 0, "tut_done": false, "tut_base": {}}
	return Game.player["progression"]


## A brand-new character: the tutorial runs and level-1 features count as seen.
static func init_new_game() -> void:
	Game.player["progression"] = {"seen": [], "tut_step": 0, "tut_done": false, "tut_base": {}}
	_mark_seen_up_to(int(Game.player["level"]))
	_begin_step()


## A save from before this system: no tutorial, and features it already qualifies for are not announced.
static func init_loaded_game() -> void:
	if Game.player.has("progression") and Game.player["progression"] is Dictionary:
		return
	Game.player["progression"] = {"seen": [], "tut_step": STEPS.size(), "tut_done": true, "tut_base": {}}
	_mark_seen_up_to(int(Game.player["level"]))


static func _mark_seen_up_to(lv: int) -> void:
	var seen: Array = state()["seen"]
	for f in FEATURES:
		if int(f["level"]) <= lv and not f["id"] in seen:
			seen.append(f["id"])


# =================================================================== feature unlocks
static func feature(id: String) -> Dictionary:
	for f in FEATURES:
		if f["id"] == id:
			return f
	return {}


static func unlock_level(id: String) -> int:
	return int(feature(id).get("level", 1))


static func is_unlocked(id: String) -> bool:
	if DebugMode.unlock_all:
		return true
	var f := feature(id)
	if f.is_empty() or Game.player.is_empty():
		return true
	return int(Game.player["level"]) >= int(f["level"])


## "Duels unlock at level 10." — for toasts and disabled buttons.
static func locked_text(id: String) -> String:
	var f := feature(id)
	return "%s unlock%s at level %d." % [f.get("name", id), "" if String(f.get("name", "")).ends_with("s") else "s", int(f.get("level", 1))]


## Refuses (with a toast) if the feature is still locked. Returns true when it may be used.
static func check(id: String) -> bool:
	if is_unlocked(id):
		return true
	Game.toast(locked_text(id) + " (you are level %d)" % int(Game.player["level"]), Color("ffb38a"))
	Sfx.play("error")
	return false


static func description(f: Dictionary) -> String:
	var d: String = f["desc"]
	if f["id"] == "architect":
		d = d % Settings.action_text("open_editor")
	return d


## Called after every level-up: announces each feature that just unlocked. Returns them.
static func check_unlocks() -> Array:
	var st := state()
	if st.is_empty():
		return []
	var seen: Array = st["seen"]
	var fresh := []
	for f in FEATURES:
		if int(f["level"]) <= int(Game.player["level"]) and not f["id"] in seen:
			seen.append(f["id"])
			fresh.append(f)
	for f in fresh:
		Game.toast("Unlocked: %s! %s" % [f["name"], description(f)], Color("fee761"))
		if Game.main and Game.main.hud:
			Game.main.hud.show_unlock(f["name"], description(f))
	return fresh


## The next feature still to unlock, or {} when everything is open.
static func next_unlock() -> Dictionary:
	for f in FEATURES:
		if int(f["level"]) > int(Game.player["level"]):
			return f
	return {}


# =================================================================== tutorial
static func tutorial_active() -> bool:
	var st := state()
	return not tutorial_off and not st.is_empty() and not st["tut_done"] and int(st["tut_step"]) < STEPS.size() and not Game.test_run


static func current_step() -> Dictionary:
	if not tutorial_active():
		return {}
	return STEPS[int(state()["tut_step"])]


static func step_text(s: Dictionary) -> String:
	match s["id"]:
		"move":
			return s["text"] % "WASD / the arrow keys"
		"skill":
			return s["text"] % Settings.action_text("open_skills")
		"quest":
			return s["text"] % Settings.action_text("interact")
		"kill":
			return s["text"] % [int(s["need"]), Settings.action_text("dash")]
		"bag":
			return s["text"] % Settings.action_text("open_inventory")
		"home":
			return s["text"] % Settings.action_text("teleport_town")
	return s["text"]


## Progress text for steps that count, e.g. "1 / 3".
static func step_progress(s: Dictionary) -> String:
	if s.get("id", "") == "kill":
		return "%d / %d" % [mini(_kills_since_start(), int(s["need"])), int(s["need"])]
	return ""


static func _total_kills() -> int:
	var n := 0
	for k in Game.player.get("kills", {}).values():
		n += int(k)
	return n


static func _kills_since_start() -> int:
	return _total_kills() - int(state()["tut_base"].get("kills", 0))


## Remembers where the current step started (for steps that measure a change).
static func _begin_step() -> void:
	var base := {"kills": _total_kills(), "sold": int(Game.player.get("items_sold", 0))}
	var p = Game.player_node
	if p != null and is_instance_valid(p):
		base["pos"] = [p.global_position.x, p.global_position.y]
	state()["tut_base"] = base


static func _step_done(s: Dictionary) -> bool:
	var lvn = Game.level_node
	var p = Game.player_node
	var base: Dictionary = state()["tut_base"]
	match s["id"]:
		"move":
			if p == null or not is_instance_valid(p):
				return false
			if not base.has("pos"):
				base["pos"] = [p.global_position.x, p.global_position.y]
				return false
			return p.global_position.distance_to(Vector2(base["pos"][0], base["pos"][1])) > 90.0
		"skill":
			for id in Game.player["hot_skills"]:
				if String(id) != "":
					return true
			return false
		"quest":
			return not Game.player["quests"].is_empty()
		"gate":
			return lvn is Overworld and p != null and is_instance_valid(p) and not lvn.is_town()
		"kill":
			return _kills_since_start() >= int(s["need"])
		"bag":
			return Game.main != null and Game.main.window is GameMenu and Game.main.window.current == "inventory"
		"home":
			return lvn is Overworld and p != null and is_instance_valid(p) and lvn.is_town()
		"sell":
			return int(Game.player.get("items_sold", 0)) > int(base.get("sold", 0))
	return false


## Polled by the HUD a few times a second.
static func tick() -> void:
	if not tutorial_active():
		return
	var s := current_step()
	if not _step_done(s):
		return
	var st := state()
	# rewards are paid once per character (a restarted tutorial pays nothing again)
	if not st.has("paid"):
		st["paid"] = []
	var gold := 0 if s["id"] in st["paid"] else int(s.get("gold", 0))
	if gold > 0:
		Game.add_gold(gold)
		st["paid"].append(s["id"])
	st["tut_step"] = int(st["tut_step"]) + 1
	Sfx.play("coin")
	if int(st["tut_step"]) >= STEPS.size():
		_finish()
		return
	Game.toast("Tutorial: %s — done!%s" % [s["title"], (" +%d gold" % gold) if gold > 0 else ""], Color("7be05a"))
	_begin_step()


static func _finish() -> void:
	var st := state()
	st["tut_done"] = true
	var reward := ""
	if not "finish" in st.get("paid", []):
		st["paid"].append("finish")
		Game.add_gold(100)
		Game.give_item(Items.stack("pot_hp_s", 5))
		reward = " +100 gold and 5 potions."
	var nx := next_unlock()
	var nxt := ("next unlock: %s at level %d (see Quests → Progression)." % [nx["name"], int(nx["level"])]) if not nx.is_empty() else "everything is unlocked."
	Game.toast("Tutorial complete!%s Turn in quests at the guild and level up — %s" % [reward, nxt], Color("fee761"))
	Sfx.play("levelup")
	if Game.main and Game.main.hud:
		Game.main.hud.show_unlock("Tutorial complete!", "New features unlock as you level up. Quests (%s) → Progression shows what's next." % Settings.action_text("open_quests"))


static func skip_tutorial() -> void:
	var st := state()
	if st.is_empty() or st["tut_done"]:
		return
	st["tut_done"] = true
	st["tut_step"] = STEPS.size()
	Game.toast("Tutorial skipped. You can follow it again from the Quests page (J).", Color("c8c0e0"))


static func restart_tutorial() -> void:
	var st := state()
	st["tut_done"] = false
	st["tut_step"] = 0
	_begin_step()
	Game.toast("Tutorial restarted — follow the steps on the right of the screen.", Color("c8c0e0"))
