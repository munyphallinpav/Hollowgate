class_name GameMenu
extends GameWindow
## Tabbed main menu: Inventory, Character, Skills, Quests, Map, Settings, Game.

const TABS := ["inventory", "character", "skills", "quests", "map", "settings", "system"]
const TAB_NAMES := ["Inventory", "Character", "Skills", "Quests", "Map", "Settings", "Game"]

var tabbar: TabBar
var page_holder: Control
var current := ""


func _init(start: String = "inventory") -> void:
	super._init("Menu", Vector2(1180, 650), "menu")
	tabbar = TabBar.new()
	for i in TABS.size():
		tabbar.add_tab(TAB_NAMES[i])
	tabbar.focus_mode = Control.FOCUS_NONE
	tabbar.clip_tabs = false
	tabbar.tab_changed.connect(func(i): show_tab(TABS[i]))
	body.add_child(tabbar)
	page_holder = MarginContainer.new()
	page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page_holder)
	current = start


func _ready() -> void:
	show_tab(current)


func show_tab(t: String) -> void:
	current = t
	var idx := TABS.find(t)
	if tabbar.current_tab != idx:
		tabbar.set_block_signals(true)
		tabbar.current_tab = idx
		tabbar.set_block_signals(false)
	title_lbl.text = TAB_NAMES[idx]
	for c in page_holder.get_children():
		c.queue_free()
	var page: Control
	match t:
		"inventory":
			page = InventoryPage.new()
		"character":
			page = CharacterPage.new()
		"skills":
			page = SkillsPage.new()
		"quests":
			page = QuestsPage.new()
		"map":
			page = MapPage.new()
		"settings":
			page = SettingsPage.new()
		_:
			page = SystemPage.new()
	page_holder.add_child(page)
	if Game.main:
		Game.main.tooltip.hide_tip()
