## Visual smoke test: drives the real UI and saves screenshots.
##   godot --path . -s res://tests/screenshots.gd -- <out_dir>
## Needs a display (not --headless).
extends SceneTree

var out := "user://shots"
var main


func shot(name: String) -> void:
	for i in 8:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	SaveData.ensure_loaded()
	SaveData.reset()
	root.size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await create_timer(0.6).timeout
	await shot("01_title")
	main.open_map()
	await shot("02a_map_menu_check")
	main.main_menu()
	await shot("02b_back_to_title")
	main.open_map()
	await shot("02_map")
	main.start_level(0)
	await create_timer(0.4).timeout
	await shot("03_briefing")
	main.close_modal()
	var b: Battle = main.battle
	await create_timer(0.8).timeout
	await shot("04_battle_start")
	b.select(b.cur().step.comp)
	await create_timer(0.5).timeout
	await shot("05_selected")
	b.place()
	var wrong: String = b.wrong_cards()[0]
	b.select(wrong)
	b.place()
	await create_timer(0.9).timeout
	await shot("06_after_wrong")
	# finish level 1
	while not b.over:
		var d = b.cur()
		b.place(d.step.comp if d.kind == "comp" else "port:%d" % d.quiz.answer_idx)
		await create_timer(0.2).timeout
	await create_timer(1.6).timeout
	await shot("07_victory")
	main.close_modal()
	# boss level mid-fight, with a blur + icon curse
	main.start_level(3)
	main.close_modal()
	var bb: Battle = main.battle
	for k in 4:
		var d2 = bb.cur()
		bb.place(d2.step.comp if d2.kind == "comp" else "port:%d" % d2.quiz.answer_idx)
	bb.effects.icon = 2
	bb.effects.blur = 0
	bb.changed.emit()
	await create_timer(1.0).timeout
	await shot("08_boss_icon_curse")
	main.goal_modal()
	await create_timer(0.3).timeout
	await shot("08b_goal")
	main.close_modal()
	main.help_modal()
	await create_timer(0.3).timeout
	await shot("09_help")
	main.close_modal()
	main.start_level(2)
	main.close_modal()
	var b7: Battle = main.battle
	while b7.cur() != null and b7.cur().kind == "comp" and b7.di < 3:
		b7.place(b7.cur().step.comp)
	if b7.cur() != null and b7.cur().kind == "quiz":
		b7.select("port:0")
	await create_timer(1.0).timeout
	await shot("10_wire_check")
	SaveData.reset()
	quit()
