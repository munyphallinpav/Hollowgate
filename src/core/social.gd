class_name Social
extends RefCounted
## Bonds with NPC adventurers and parties (the hero + up to 2 adventurers, or adventurers among themselves).
##
## Bond (0-100, levels 0-5) grows when you give an adventurer things that make it stronger — gear it can
## equip that beats what it wears, potions, materials its quest needs — or gold. At most BOND_PER_DAY
## points per adventurer per in-game day. Bond raises the chance that a stronger adventurer joins your
## party, how long friends stay, and the party's XP bonus.
##
## Party members share XP (the total grows with the party), travel with you and enter dungeons with you.

const BOND_MAX := 100
const BOND_PER_DAY := 25
const BOND_NAMES := ["Stranger", "Acquaintance", "Friend", "Good friend", "Close friend", "Sworn ally"]
const PARTY_MAX := 3  # including the leader
const PARTY_SHARE_BONUS := 0.15  # total party XP grows 15% per extra member
const INVITE_COOLDOWN := 60.0  # game seconds before asking the same adventurer again


# =================================================================== bond
static func bond(n: Dictionary) -> int:
	return int(n.get("bond", 0))


static func bond_level(n: Dictionary) -> int:
	return mini(5, bond(n) / 20)


static func bond_name(n: Dictionary) -> String:
	return BOND_NAMES[bond_level(n)]


static func bond_left_today(n: Dictionary) -> int:
	if int(n.get("bond_day", -1)) != int(Game.world.get("day", 1)):
		return BOND_PER_DAY
	return maxi(0, BOND_PER_DAY - int(n.get("bond_today", 0)))


## Adds bond within the daily and total limits. Returns the points actually gained.
static func add_bond(n: Dictionary, pts: int) -> int:
	var day := int(Game.world.get("day", 1))
	if int(n.get("bond_day", -1)) != day:
		n["bond_day"] = day
		n["bond_today"] = 0
	var gain := mini(mini(pts, bond_left_today(n)), BOND_MAX - bond(n))
	if gain <= 0:
		return 0
	var before := bond_level(n)
	n["bond"] = bond(n) + gain
	n["bond_today"] = int(n["bond_today"]) + gain
	if bond_level(n) > before:
		NpcWorld.news("%s now sees you as a %s!" % [n["name"], bond_name(n).to_lower()], Color("ff9ad5"), true)
		Sfx.play("levelup")
	return gain


## Gold that buys one bond point with this adventurer.
static func gold_per_bond(n: Dictionary) -> int:
	return 40 + int(n["level"]) * 12


## What happens if the hero gives this item: {"ok", "bond", "why"}.
static func gift_check(n: Dictionary, it: Dictionary) -> Dictionary:
	if it.is_empty():
		return {"ok": false, "bond": 0, "why": ""}
	var nm: String = n["name"]
	if Items.is_gear(it):
		if int(it.get("ilvl", 1)) > int(n["level"]) + 5:
			return {"ok": false, "bond": 0, "why": "%s is not strong enough to use this yet (item level %d)." % [nm, int(it.get("ilvl", 1))]}
		var cat := Items.category(it)
		var slots := [cat] if cat in ["weapon", "armor", "necklace"] else [cat + "1", cat + "2"]
		var worst := INF
		for sl in slots:
			worst = minf(worst, NpcWorld.gear_score(n, n["equip"].get(sl, {})))
		var sc := NpcWorld.gear_score(n, it)
		if sc <= worst * 1.02:
			if cat == "weapon" and sc < Items.gear_value(it) * 0.5:
				return {"ok": false, "bond": 0, "why": "%s can't make good use of a %s." % [nm, GameData.ItemData.GEAR[it["base"]]["name"].to_lower()]}
			return {"ok": false, "bond": 0, "why": "%s already wears something better for that slot." % nm}
		var gain := (sc - worst) / maxf(1.0, maxf(worst, sc * 0.5))
		return {"ok": true, "bond": clampi(int(round(4.0 + gain * 10.0 + float(it.get("rarity", 0)) * 2.0)), 4, 20), "why": "%s would equip it." % nm}
	var t := GameData.item_template(it.get("id", ""))
	match t.get("type", ""):
		"consumable":
			var qty := int(it.get("qty", 1))
			var val := float(t.get("price", 10)) * qty
			if t.get("kind", "") == "potion":
				return {"ok": true, "bond": clampi(int(val / (30.0 + int(n["level"]) * 6.0)), 1, 8), "why": "Potions keep %s alive out there." % nm}
			return {"ok": true, "bond": clampi(int(val / (60.0 + int(n["level"]) * 10.0)), 1, 4), "why": "%s enjoys a good meal." % nm}
		"material":
			for q in n["quests"]:
				if q["type"] == "gather" and q["target"] == it.get("id", "") and not Quests.is_complete_for(q, n):
					return {"ok": true, "bond": clampi(int(it.get("qty", 1)), 2, 8), "why": "%s needs this for a guild quest!" % nm}
			return {"ok": false, "bond": 0, "why": "%s has no use for that." % nm}
	return {"ok": false, "bond": 0, "why": "%s can't use that." % nm}


## Gives the item in the hero's bag slot to the adventurer. Returns a message.
static func give_item(n: Dictionary, inv_index: int) -> String:
	var it = Game.player["inv"][inv_index]
	if not (it is Dictionary) or it.is_empty():
		return ""
	if bond_left_today(n) <= 0 and bond(n) < BOND_MAX:
		return "%s has received enough gifts for today (bond +%d/day)." % [n["name"], BOND_PER_DAY]
	var chk := gift_check(n, it)
	if not chk["ok"]:
		return chk["why"]
	var item: Dictionary = Game.remove_at(inv_index)
	if Items.is_gear(item):
		NpcWorld.add_item(n, item)
		NpcWorld._auto_equip(n)
	else:
		NpcWorld.add_item(n, item)
	var got := add_bond(n, int(chk["bond"]))
	NpcWorld.log_event("%s gave %s %s." % [Game.player["name"], n["name"], Items.name_of(item)])
	return "%s accepts %s. Bond +%d (%s)." % [n["name"], Items.name_of(item), got, bond_name(n)]


## Gives gold; only takes what converts into bond today. Returns a message.
static func give_gold(n: Dictionary, amount: int) -> String:
	var per := gold_per_bond(n)
	var room := mini(bond_left_today(n), BOND_MAX - bond(n))
	if room <= 0:
		return "%s has received enough gifts for today." % n["name"] if bond(n) < BOND_MAX else "%s is already your sworn ally." % n["name"]
	var pts := mini(amount / per, room)
	if pts <= 0:
		return "%s would like at least %d gold." % [n["name"], per]
	var take := pts * per
	if int(Game.player["gold"]) < take:
		return "Not enough gold."
	Game.add_gold(-take)
	n["gold"] = int(n["gold"]) + take
	var got := add_bond(n, pts)
	return "%s accepts %d gold. Bond +%d (%s)." % [n["name"], take, got, bond_name(n)]


# =================================================================== the hero's party
static func party_ids() -> Array:
	if Game.player.is_empty():
		return []
	if not Game.player.has("party"):
		Game.player["party"] = []
	return Game.player["party"]


static func party_members() -> Array:
	var out := []
	for id in party_ids():
		var n := NpcWorld.find(int(id))
		if not n.is_empty():
			out.append(n)
	return out


static func in_party(n: Dictionary) -> bool:
	return int(n["id"]) in party_ids()


static func party_size() -> int:
	return 1 + party_members().size()


## Chance (0-1) that this adventurer accepts the hero's invitation, and why not if 0.
static func invite_chance(n: Dictionary) -> Array:
	if in_party(n):
		return [0.0, "%s is already in your party." % n["name"]]
	if party_size() >= PARTY_MAX:
		return [0.0, "Your party is full (%d members)." % PARTY_MAX]
	if n["state"] in ["dead", "dungeon", "duel"]:
		return [0.0, "%s is busy right now (%s)." % [n["name"], NpcWorld.activity(n).to_lower()]]
	if n.has("sim_party") and not n["sim_party"].is_empty():
		return [0.0, "%s is already adventuring with a party." % n["name"]]
	if float(n.get("invite_cd", -1e9)) > float(Game.world.get("total", 0.0)):
		return [0.0, "%s turned you down a moment ago. Give it a little time." % n["name"]]
	var diff := int(n["level"]) - int(Game.player["level"])
	var c := 0.75
	if diff > 0:
		c -= 0.09 * diff  # stronger adventurers are choosy...
	c += 0.12 * bond_level(n)  # ...unless they know and like you
	return [clampf(c, 0.03, 0.98), ""]


## Invites an adventurer. Returns [joined: bool, message].
static func invite(n: Dictionary) -> Array:
	var ch := invite_chance(n)
	if float(ch[0]) <= 0.0:
		return [false, ch[1]]
	if randf() >= float(ch[0]):
		n["invite_cd"] = float(Game.world.get("total", 0.0)) + INVITE_COOLDOWN
		var why := "\"Maybe some other time.\""
		if int(n["level"]) > int(Game.player["level"]) + 3:
			why = "\"You'd only slow me down out there. Maybe once we know each other better.\""
		return [false, "%s declines. %s" % [n["name"], why]]
	join_party(n)
	return [true, "%s joins your party! (%s)" % [n["name"], "stays until you part ways" if bond_level(n) >= 5 else "stays about %d min" % int(party_stay(n) / 60.0)]]


## How long (game seconds) an adventurer stays in the hero's party; sworn allies stay for good.
static func party_stay(n: Dictionary) -> float:
	return 1e12 if bond_level(n) >= 5 else 900.0 + 600.0 * bond_level(n)


static func join_party(n: Dictionary) -> void:
	party_ids().append(int(n["id"]))
	n["state"] = "party"
	n["state_t"] = 1e9
	n["party_until"] = float(Game.world.get("total", 0.0)) + party_stay(n)
	n["run"] = {}
	NpcWorld.log_event("%s joined %s's party." % [n["name"], Game.player["name"]])
	if Game.level_node and Game.level_node.has_method("sync_party"):
		Game.level_node.sync_party(true)


## Removes an adventurer from the hero's party; it goes back to its own routine.
static func leave_party(n: Dictionary, why: String = "") -> void:
	party_ids().erase(int(n["id"]))
	if n["state"] == "party":
		NpcWorld._enter_town(n)
		n["state_t"] = 8.0
		n["visited"] = true
	n.erase("party_until")
	var a = NpcWorld.actor_of(n)
	if a:
		a.mode = "routine"
	if Game.level_node and Game.level_node.has_method("sync_party"):
		Game.level_node.sync_party(false)
	if why != "":
		Game.toast(why, Color("c8c0e0"))


## Called every simulation second: members whose time is up head home (bond extends it).
static func tick() -> void:
	var now := float(Game.world.get("total", 0.0))
	for n in party_members():
		if n["state"] == "dead":
			leave_party(n, "%s was defeated and returns to town to recover." % n["name"])
		elif now > float(n.get("party_until", 1e12)) and not Game.test_run:
			leave_party(n, "%s has to get back to their own adventures. (A stronger bond keeps friends around longer.)" % n["name"])
	for id in party_ids().duplicate():
		if NpcWorld.find(int(id)).is_empty():
			party_ids().erase(id)


# =================================================================== XP sharing
## Splits a kill's XP between the hero and the adventurers in the party.
## Returns the hero's share (already granted to the party members).
static func share_xp(xp: float) -> float:
	var mem := party_members()
	if mem.is_empty():
		return xp
	var n_all := 1 + mem.size()
	var bond_bonus := 0.0
	for n in mem:
		bond_bonus += 0.02 * bond_level(n)
	var each := xp * (1.0 + PARTY_SHARE_BONUS * (n_all - 1) + bond_bonus) / n_all
	for n in mem:
		NpcWorld.gain_xp(n, each, true)
	return each


## True if both actors fight on the same side as a party (hero + members, or members of one NPC party).
static func same_party(a, b) -> bool:
	if a == null or b == null or not (a is Player) or not (b is Player):
		return false
	if a == b:
		return true
	var ka := party_key(a)
	return ka != "" and ka == party_key(b)


static func party_key(a) -> String:
	if not (a is Player):
		return ""
	if a.is_hero():
		return "hero"
	if in_party(a.npc):
		return "hero"
	var sp: Array = a.npc.get("sim_party", [])
	if not sp.is_empty():
		return "npc%d" % int(sp[0])
	return ""


# =================================================================== adventurers' own parties
## Adventurers team up among themselves too (up to PARTY_MAX). The leader picks what the party does;
## members travel with it ("follow" state), share the XP of every kill and run guild dungeons together.
static func in_npc_party(n: Dictionary) -> bool:
	return not n.get("sim_party", []).is_empty()


static func npc_party_members(n: Dictionary) -> Array:
	var out := []
	for id in n.get("sim_party", []):
		var m := NpcWorld.find(int(id))
		if not m.is_empty():
			out.append(m)
	return out


static func npc_party_leader(n: Dictionary) -> Dictionary:
	var sp: Array = n.get("sim_party", [])
	return {} if sp.is_empty() else NpcWorld.find(int(sp[0]))


static func is_npc_leader(n: Dictionary) -> bool:
	var sp: Array = n.get("sim_party", [])
	return not sp.is_empty() and int(sp[0]) == int(n["id"])


## Splits a kill's XP among an adventurer party (the total grows with the party like the hero's).
static func share_npc_xp(n: Dictionary, xp: float) -> void:
	var mem := npc_party_members(n)
	if mem.size() <= 1:
		NpcWorld.gain_xp(n, xp)
		return
	var each := xp * (1.0 + PARTY_SHARE_BONUS * (mem.size() - 1)) / mem.size()
	for m in mem:
		NpcWorld.gain_xp(m, each, true)


## An adventurer in town looks for companions of a similar level. Stronger ones are pickier.
static func try_form_npc_party(n: Dictionary, rng: RandomNumberGenerator) -> bool:
	if in_npc_party(n) or in_party(n) or int(n["level"]) < 3:
		return false
	var lv := int(n["level"])
	var cands := []
	for m in NpcWorld.npcs():
		if m == n or m["state"] != "town" or in_npc_party(m) or in_party(m) or m.get("physical", false):
			continue
		if absi(int(m["level"]) - lv) <= 6:
			cands.append(m)
	if cands.is_empty():
		return false
	cands.shuffle()
	var ids := [int(n["id"])]
	for m in cands:
		if ids.size() >= PARTY_MAX:
			break
		var diff := int(m["level"]) - lv
		var ch := 0.7 - 0.09 * maxf(0.0, diff)
		if rng.randf() < ch:
			ids.append(int(m["id"]))
	if ids.size() < 2:
		return false
	var names := []
	for id in ids:
		var m2 := NpcWorld.find(int(id))
		m2["sim_party"] = ids.duplicate()
		names.append(m2["name"])
		if int(id) != int(n["id"]):
			m2["state"] = "follow"
			m2["state_t"] = 1e9
	NpcWorld.log_event("%s teamed up as a party." % ", ".join(names))
	return true


static func disband_npc_party(n: Dictionary) -> void:
	var mem := npc_party_members(n)
	for m in mem:
		m.erase("sim_party")
		if m["state"] == "follow":
			m["pos"] = n["pos"].duplicate()
			NpcWorld._enter_town(m)
		var a = NpcWorld.actor_of(m)
		if a and a.mode == "follow" and not in_party(m):
			a.mode = "routine"
			a.leader = null
	n.erase("sim_party")
