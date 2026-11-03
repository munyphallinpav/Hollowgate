class_name Duel
extends RefCounted
## Duels between the hero and an NPC adventurer (live), and between adventurers (simulated in town).
##
## Before a duel both sides put up a stake (gold and/or items). Stakes must be of similar value
## (within MATCH_TOLERANCE) — or both empty for a friendly duel. The winner takes the whole pot and earns
## XP (more for beating a higher-level opponent; half for friendly duels). Nobody dies: the first to drop
## to 1 HP loses. Potions are not allowed, the fight stays inside the ring and lasts at most TIME_LIMIT.

const MATCH_TOLERANCE := 0.15
const RING := 130.0
const TIME_LIMIT := 90.0
const COUNTDOWN := 3.0
const MAX_STAKE_ITEMS := 4
const DAMAGE_SCALE := 0.5  # damage between duellists (skills are tuned against monster HP)

static var active := false
static var phase := ""  # "countdown", "fight", "over"
static var a: Player = null  # the hero (or an adventurer)
static var b: Player = null  # the opponent
static var npc: Dictionary = {}  # the opponent's record
static var pot_a: Dictionary = {}  # escrowed stakes {"gold": int, "items": []}
static var pot_b: Dictionary = {}
static var center := Vector2.ZERO
static var t := 0.0
static var out_t := 0.0
static var ring_fx: Node2D = null
static var last_result := ""


# =================================================================== stakes
static func stake_value(stake: Dictionary) -> int:
	var v := int(stake.get("gold", 0))
	for it in stake.get("items", []):
		v += Items.sell_price(it) * int(it.get("qty", 1))
	return v


static func values_match(va: int, vb: int) -> bool:
	if va <= 0 and vb <= 0:
		return true
	return absf(va - vb) <= MATCH_TOLERANCE * maxf(va, vb)


## The adventurer's counter-offer for a stake worth `value`: gold first, then things from its bag.
static func npc_offer(n: Dictionary, value: int) -> Dictionary:
	var g := mini(int(n["gold"]), value)
	var offer := {"gold": g, "items": []}
	if g >= value:
		return offer
	var cands := []
	for it in n["inv"]:
		var tp := GameData.item_template(it.get("id", ""))
		if Items.is_gear(it) or tp.get("type", "") == "material":
			cands.append(it)
	cands.sort_custom(func(x, y): return Items.sell_price(x) * int(x.get("qty", 1)) > Items.sell_price(y) * int(y.get("qty", 1)))
	var have := g
	for it in cands:
		if have >= value * (1.0 - MATCH_TOLERANCE * 0.5) or offer["items"].size() >= MAX_STAKE_ITEMS:
			break
		var iv := Items.sell_price(it) * int(it.get("qty", 1))
		if have + iv > value * (1.0 + MATCH_TOLERANCE):
			continue
		offer["items"].append(it)
		have += iv
	return offer


## Rough fighting power from final stats (attack x survivability).
static func power(st: Dictionary, magic: bool) -> float:
	var atk := float(st["matk"] if magic else st["patk"])
	var dps := atk * float(st["aspd"]) * (1.0 + float(st["crit"]) / 100.0 * (float(st["crit_dmg"]) / 100.0 - 1.0))
	var ehp := float(st["max_hp"]) * (1.0 + (float(st["pdef"]) + float(st["mdef"])) / 600.0)
	return sqrt(maxf(1.0, dps * ehp))


## Chance that the adventurer beats the hero, as the adventurer sees it.
static func npc_win_chance(n: Dictionary) -> float:
	var pn := power(NpcWorld.stats_of(n), n["class"] in ["mage", "priest"])
	var ph := power(Game.stats, Game.player["class"] in ["mage", "priest"])
	return clampf(pn * pn / maxf(1.0, pn * pn + ph * ph), 0.03, 0.97)


## Does the adventurer agree to fight for these stakes? [ok, message]
static func npc_accepts(n: Dictionary, hero_value: int) -> Array:
	if n["state"] in ["dead", "dungeon"]:
		return [false, "%s is busy." % n["name"]]
	var ch := npc_win_chance(n)
	var brave := float(n.get("bravery", 0.5))
	var bl := Social.bond_level(n)
	if hero_value <= 0:
		if ch >= 0.25 or bl >= 1 or brave > 0.7:
			return [true, "%s: \"A friendly bout? Sure, let's see what you've got.\"" % n["name"]]
		return [false, "%s: \"I'd rather not embarrass myself.\"" % n["name"]]
	if ch < 0.15:
		return [false, "%s: \"I know when I'm outmatched. Not for money.\"" % n["name"]]
	var small := hero_value <= int(n["gold"]) * 0.08
	if ch >= 0.45 - 0.15 * brave - 0.03 * bl or (small and ch >= 0.25):
		return [true, "%s: \"You're on!\" (thinks their chances are %d%%)" % [n["name"], int(ch * 100.0)]]
	return [false, "%s: \"That's too rich for me. Bet less and I'll think about it.\" (thinks their chances are %d%%)" % [n["name"], int(ch * 100.0)]]


## XP for winning: a share of a level, more for beating a higher level, half for a friendly duel.
static func xp_reward(winner_lv: int, loser_lv: int, staked: bool) -> float:
	var ratio := float(loser_lv) / maxf(1.0, winner_lv)
	var frac := clampf(0.06 * pow(ratio, 1.5), 0.01, 0.25)
	return GameData.xp_to_next(winner_lv) * frac * (1.0 if staked else 0.5)


# =================================================================== live duel
static func is_duelist(p) -> bool:
	return active and p != null and (p == a or p == b)


static func opponent_of(p) -> Player:
	if p == a:
		return b
	if p == b:
		return a
	return null


## Starts a duel between the hero and an adventurer actor. Stakes are taken into escrow now.
static func start(hero: Player, foe: Player, stake_hero: Dictionary, stake_foe: Dictionary) -> bool:
	if active or hero == null or foe == null or not is_instance_valid(foe) or foe.dead:
		return false
	var lv = Game.level_node
	if lv == null:
		return false
	# escrow
	pot_a = {"gold": int(stake_hero.get("gold", 0)), "items": []}
	pot_b = {"gold": int(stake_foe.get("gold", 0)), "items": []}
	if int(Game.player["gold"]) < int(pot_a["gold"]) or int(foe.npc["gold"]) < int(pot_b["gold"]):
		return false
	Game.add_gold(-int(pot_a["gold"]))
	for it in stake_hero.get("items", []):
		var idx: int = Game.player["inv"].find(it)
		if idx >= 0:
			pot_a["items"].append(Game.remove_at(idx))
	foe.npc["gold"] = int(foe.npc["gold"]) - int(pot_b["gold"])
	for it in stake_foe.get("items", []):
		var j: int = foe.npc["inv"].find(it)
		if j >= 0:
			foe.npc["inv"].remove_at(j)
			pot_b["items"].append(it)
	active = true
	phase = "countdown"
	t = 0.0
	out_t = 0.0
	a = hero
	b = foe
	npc = foe.npc
	npc["state_before_duel"] = npc["state"]
	npc["state"] = "duel"
	center = _open_center(lv, (hero.global_position + foe.global_position) * 0.5)
	hero.global_position = center + Vector2(-50, 0)
	foe.global_position = center + Vector2(50, 0)
	hero.invuln_t = COUNTDOWN
	foe.invuln_t = COUNTDOWN
	hero.lock(COUNTDOWN)
	foe.lock(COUNTDOWN)
	hero.set_team("duel_a", "duel_b")
	foe.set_team("duel_b", "duel_a")
	foe.mode = "duel"
	foe.foe = hero
	hero.hp = maxf(hero.hp, hero.max_hp * 0.5)
	foe.hp = maxf(foe.hp, foe.max_hp * 0.5)
	ring_fx = VFX.static_ring(lv, center, RING, Color(1.0, 0.82, 0.35, 0.9), 2.0)
	lv.float_text(center + Vector2(0, -60), "DUEL!", Color("fee761"), 2.0)
	Game.toast("Duel against %s! Pot: %s. No potions; stay inside the ring." % [npc["name"], pot_text()], Color("fee761"))
	Sfx.play("roar", 0.1, 0.8)
	return true


## A spot near `p` where both duellists' starting marks (and a bit of the ring) are open ground.
static func _open_center(lv, p: Vector2) -> Vector2:
	for ring in 12:
		for k in (1 if ring == 0 else 10):
			var c := p + Vector2.from_angle(k * TAU / 10.0) * ring * 24.0
			var ok := true
			for off in [Vector2.ZERO, Vector2(-50, 0), Vector2(50, 0), Vector2(-90, 0), Vector2(90, 0), Vector2(0, -45), Vector2(0, 45)]:
				if not lv.is_walkable(c + off):
					ok = false
					break
			if ok:
				return c
	return p


static func pot_text() -> String:
	var g := int(pot_a.get("gold", 0)) + int(pot_b.get("gold", 0))
	var n_items: int = pot_a.get("items", []).size() + pot_b.get("items", []).size()
	if g <= 0 and n_items == 0:
		return "friendly (no stakes)"
	return "%d gold%s" % [g, (" + %d item(s)" % n_items) if n_items > 0 else ""]


## Called every frame by the level while a duel is on.
static func update(delta: float) -> void:
	if not active:
		return
	var lv = Game.level_node
	if lv == null or a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		cancel("interrupted")
		return
	t += delta
	if phase == "countdown":
		var left := COUNTDOWN - t
		var shown := int(ceil(left))
		if int(ceil(left + delta)) != shown and shown > 0:
			lv.float_text(center + Vector2(0, -50), str(shown), Color.WHITE, 2.2)
			Sfx.play("click")
		if t >= COUNTDOWN:
			phase = "fight"
			t = 0.0
			lv.float_text(center + Vector2(0, -50), "FIGHT!", Color("ff6a6a"), 2.4)
		return
	if phase != "fight":
		return
	if t >= TIME_LIMIT:
		finish(null, "time")
		return
	# leaving the ring for 3 seconds forfeits
	if a.global_position.distance_to(center) > RING * 1.25:
		out_t += delta
		if out_t > 3.0:
			finish(b, "forfeit")
			return
		if int((out_t - delta) * 2.0) != int(out_t * 2.0):
			lv.float_text(a.global_position + Vector2(0, -36), "Back into the ring!", Color("ffb347"), 0.9)
	else:
		out_t = 0.0


## A duellist dropped to 1 HP.
static func ko(loser: Player) -> void:
	if not active or phase != "fight":
		return
	finish(opponent_of(loser), "ko")


static func finish(winner: Player, reason: String) -> void:
	if not active:
		return
	var lv = Game.level_node
	phase = "over"
	active = false
	_restore_sides()
	var hero_won := winner != null and winner == a
	var staked := stake_value(pot_a) + stake_value(pot_b) > 0
	if winner == null:
		_refund()
		last_result = "draw"
		Game.toast("The duel ends in a draw (time). Stakes returned.", Color("c8c0e0"))
	else:
		var loser := opponent_of(winner)
		var xp := xp_reward(int(winner.pd["level"]), int(loser.pd["level"]), staked)
		var gold := int(pot_a["gold"]) + int(pot_b["gold"])
		var items: Array = pot_a["items"] + pot_b["items"]
		if hero_won:
			Game.add_gold(gold)
			for it in items:
				Game.give_item(it)
			Game.add_xp(xp)
			last_result = "won"
			Game.toast("You defeated %s%s! +%d XP%s" % [npc["name"], " (forfeit)" if reason == "forfeit" else "", int(xp),
				(", won %s" % pot_text()) if staked else ""], Color("7be05a"))
			if lv:
				lv.float_text(winner.global_position + Vector2(0, -50), "VICTORY!", Color("fee761"), 2.0)
			Sfx.play("levelup")
		else:
			npc["gold"] = int(npc["gold"]) + gold
			for it in items:
				NpcWorld.add_item(npc, it)
			NpcWorld.gain_xp(npc, xp)
			last_result = "lost"
			Game.toast("%s won the duel%s.%s" % [npc["name"], " — you left the ring" if reason == "forfeit" else "",
				(" They take the pot (%s)." % pot_text()) if staked else ""], Color("ff7a7a"))
			if lv:
				lv.float_text(a.global_position + Vector2(0, -50), "DEFEAT", Color("ff6a6a"), 2.0)
		npc["duels_won"] = int(npc.get("duels_won", 0)) + (0 if hero_won else 1)
		npc["duels_lost"] = int(npc.get("duels_lost", 0)) + (1 if hero_won else 0)
		Game.player["duels_won"] = int(Game.player.get("duels_won", 0)) + (1 if hero_won else 0)
		Game.player["duels_lost"] = int(Game.player.get("duels_lost", 0)) + (0 if hero_won else 1)
		NpcWorld.log_event("%s defeated %s in a duel%s." % [winner.display_name, loser.display_name, (" (pot %s)" % pot_text()) if staked else ""])
	pot_a = {}
	pot_b = {}
	_clear()


static func cancel(why: String) -> void:
	if not active:
		return
	active = false
	_restore_sides()
	_refund()
	last_result = "cancelled"
	Game.toast("The duel was called off (%s). Stakes returned." % why, Color("c8c0e0"))
	_clear()


static func _refund() -> void:
	Game.add_gold(int(pot_a.get("gold", 0)))
	for it in pot_a.get("items", []):
		Game.give_item(it)
	if not npc.is_empty():
		npc["gold"] = int(npc["gold"]) + int(pot_b.get("gold", 0))
		for it in pot_b.get("items", []):
			NpcWorld.add_item(npc, it)


static func _restore_sides() -> void:
	for p in [a, b]:
		if p != null and is_instance_valid(p):
			p.set_team("player", "")
			p.invuln_t = maxf(p.invuln_t, 1.0)
			p.statuses.clear()
	# summons called up during the duel go back to fighting monsters
	var lv = Game.level_node
	if lv:
		for al in lv.get_tree().get_nodes_in_group("allies"):
			if is_instance_valid(al) and al.team.begins_with("duel_"):
				al.set_team("player", "")
	if b != null and is_instance_valid(b) and b is Adventurer:
		b.foe = null
		b.mode = "follow" if Social.in_party(b.npc) else "routine"
	if not npc.is_empty() and npc["state"] == "duel":
		npc["state"] = npc.get("state_before_duel", "town")
		if npc["state"] == "duel":
			npc["state"] = "town"
	npc.erase("state_before_duel")


static func _clear() -> void:
	if ring_fx != null and is_instance_valid(ring_fx):
		ring_fx.queue_free()
	ring_fx = null
	a = null
	b = null
	npc = {}
	phase = ""


# =================================================================== adventurers among themselves
## A friendly-wager duel between two adventurers in town (simulated, logged in the guild hall).
static func sim_duel(x: Dictionary, y: Dictionary, rng: RandomNumberGenerator) -> void:
	var px := power(NpcWorld.stats_of(x), x["class"] in ["mage", "priest"])
	var py := power(NpcWorld.stats_of(y), y["class"] in ["mage", "priest"])
	var bet := int(mini(int(x["gold"]), int(y["gold"])) * rng.randf_range(0.03, 0.12))
	var x_wins := rng.randf() < px * px / maxf(1.0, px * px + py * py)
	var w: Dictionary = x if x_wins else y
	var l: Dictionary = y if x_wins else x
	w["gold"] = int(w["gold"]) + bet
	l["gold"] = int(l["gold"]) - bet
	NpcWorld.gain_xp(w, xp_reward(int(w["level"]), int(l["level"]), bet > 0))
	w["duels_won"] = int(w.get("duels_won", 0)) + 1
	l["duels_lost"] = int(l.get("duels_lost", 0)) + 1
	NpcWorld.log_event("%s beat %s in a duel in the town square%s." % [w["name"], l["name"], (" and won %d gold" % bet) if bet > 0 else ""])
