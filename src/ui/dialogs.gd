class_name Dialogs
extends RefCounted
## Modal dialogs built in code (confirm, quantity picker, text input).


static func _modal(parent: Node, title: String, width: int = 380) -> Dictionary:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.theme = UI.theme()
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	v.add_child(UI.label(title, 18, Color("ffe9a8")))
	return {"root": dim, "body": v}


static func confirm(parent: Node, title: String, text: String, on_yes: Callable, yes_text: String = "Yes") -> void:
	var m := _modal(parent, title)
	var body: VBoxContainer = m["body"]
	var r := UI.rich(text, 15)
	r.custom_minimum_size.x = 340
	body.add_child(r)
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UI.button("Cancel", func(): m["root"].queue_free(), 100))
	h.add_child(UI.button(yes_text, func():
		m["root"].queue_free()
		on_yes.call(), 100))


static func quantity(parent: Node, title: String, max_qty: int, start: int, on_ok: Callable) -> void:
	var m := _modal(parent, title)
	var body: VBoxContainer = m["body"]
	var lbl := UI.label("Amount: %d" % start, 16)
	body.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 1
	s.max_value = max(1, max_qty)
	s.step = 1
	s.value = clampi(start, 1, max(1, max_qty))
	s.custom_minimum_size.x = 320
	s.value_changed.connect(func(v): lbl.text = "Amount: %d" % int(v))
	body.add_child(s)
	var quick := UI.hbox(6)
	for q in [1, 5, 10, max_qty / 2, max_qty]:
		if q >= 1 and q <= max_qty:
			var qq: int = q
			quick.add_child(UI.button(str(qq), func(): s.value = qq))
	body.add_child(quick)
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UI.button("Cancel", func(): m["root"].queue_free(), 100))
	h.add_child(UI.button("OK", func():
		m["root"].queue_free()
		on_ok.call(int(s.value)), 100))


static func text_input(parent: Node, title: String, default: String, on_ok: Callable) -> void:
	var m := _modal(parent, title)
	var body: VBoxContainer = m["body"]
	var le := LineEdit.new()
	le.text = default
	le.max_length = 32
	le.custom_minimum_size.x = 320
	body.add_child(le)
	le.call_deferred("grab_focus")
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	var ok := func():
		m["root"].queue_free()
		on_ok.call(le.text.strip_edges())
	le.text_submitted.connect(func(_t): ok.call())
	h.add_child(UI.button("Cancel", func(): m["root"].queue_free(), 100))
	h.add_child(UI.button("OK", ok, 100))


static func message(parent: Node, title: String, text: String) -> void:
	var m := _modal(parent, title)
	var body: VBoxContainer = m["body"]
	var r := UI.rich(text, 15)
	r.custom_minimum_size.x = 340
	body.add_child(r)
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UI.button("OK", func(): m["root"].queue_free(), 100))
