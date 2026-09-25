extends Node
## Campaign orchestration for DAY'S AFTER.
## Keeps story/cinematic flow separate from the gameplay controller so new
## missions can be added without rewriting the core player systems.

signal cinematic_finished

var cinematic_active := false
var overlay: Control
var title_label: Label
var chapter_label: Label
var briefing_label: Label
var skip_button: Button
var progress_label: Label
var current_mission := 1
var _run_id := 0

var missions := {
    1: {
        "chapter": "CHAPTER 01",
        "title": "THE FIRST NIGHT",
        "briefing": "The city has gone silent.\nFind supplies, survive the night, and reach the safe zone.",
        "objective": "MISSION 01  •  FIND SUPPLIES  •  SURVIVE  •  REACH THE SAFE ZONE"
    },
    2: {
        "chapter": "CHAPTER 01",
        "title": "NO WAY BACK",
        "briefing": "The road ahead is blocked.\nFind another route and keep moving.",
        "objective": "MISSION 02  •  ROUTE TO BE DEFINED"
    }
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_overlay()

func _input(event: InputEvent) -> void:
    # Android can deliver the first tap through the CanvasLayer before the
    # Button receives a pressed signal. Keep a direct fallback for the menu.
    if cinematic_active or not event is InputEventScreenTouch:
        return
    var touch := event as InputEventScreenTouch
    if not touch.pressed:
        return
    var main := get_parent() as Node
    if not is_instance_valid(main):
        return
    var menu := main.get_node_or_null("HUD/Menu") as Control
    if not is_instance_valid(menu) or not menu.visible:
        return
    var start := main.get_node_or_null("HUD/Menu/Panel/Start") as Button
    if not is_instance_valid(start) or start.disabled:
        return
    if start.get_global_rect().has_point(touch.position):
        main.call("_new_game")
        get_viewport().set_input_as_handled()

func _build_overlay() -> void:
    overlay = Control.new()
    overlay.name = "CinematicOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.visible = false
    $"../HUD".add_child(overlay)

    var black := ColorRect.new()
    black.name = "Black"
    black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    black.color = Color(0.0, 0.0, 0.0, 0.94)
    black.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(black)

    var top_bar := ColorRect.new()
    top_bar.position = Vector2(0, 0)
    top_bar.size = Vector2(1280, 86)
    top_bar.color = Color(0.0, 0.0, 0.0, 1.0)
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(top_bar)

    var bottom_bar := ColorRect.new()
    bottom_bar.position = Vector2(0, 634)
    bottom_bar.size = Vector2(1280, 86)
    bottom_bar.color = Color(0.0, 0.0, 0.0, 1.0)
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(bottom_bar)

    chapter_label = Label.new()
    chapter_label.position = Vector2(70, 122)
    chapter_label.size = Vector2(1140, 40)
    chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chapter_label.add_theme_font_size_override("font_size", 18)
    chapter_label.modulate = Color(0.78, 0.68, 0.42, 1.0)
    chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(chapter_label)

    title_label = Label.new()
    title_label.position = Vector2(70, 190)
    title_label.size = Vector2(1140, 92)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 44)
    title_label.modulate = Color(0.95, 0.95, 0.95, 1.0)
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(title_label)

    briefing_label = Label.new()
    briefing_label.position = Vector2(150, 315)
    briefing_label.size = Vector2(980, 130)
    briefing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    briefing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    briefing_label.add_theme_font_size_override("font_size", 22)
    briefing_label.modulate = Color(0.76, 0.79, 0.86, 1.0)
    briefing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(briefing_label)

    progress_label = Label.new()
    progress_label.position = Vector2(70, 574)
    progress_label.size = Vector2(1140, 38)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 15)
    progress_label.modulate = Color(0.62, 0.65, 0.72, 1.0)
    progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(progress_label)

    skip_button = Button.new()
    skip_button.position = Vector2(1080, 570)
    skip_button.size = Vector2(120, 48)
    skip_button.text = "SKIP"
    skip_button.focus_mode = Control.FOCUS_NONE
    skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
    skip_button.add_theme_font_size_override("font_size", 15)
    skip_button.pressed.connect(skip_cinematic)
    overlay.add_child(skip_button)

func play_mission_intro(mission_id: int = 1) -> void:
    if cinematic_active:
        return
    var mission: Dictionary = missions.get(mission_id, missions[1])
    current_mission = mission_id if missions.has(mission_id) else 1
    _run_id += 1
    var run := _run_id
    cinematic_active = true
    overlay.visible = true
    overlay.modulate.a = 0.0
    chapter_label.text = str(mission["chapter"])
    title_label.text = str(mission["title"])
    briefing_label.text = str(mission["briefing"])
    progress_label.text = str(mission["objective"])
    skip_button.visible = true

    var fade_in := overlay.create_tween()
    fade_in.tween_property(overlay, "modulate:a", 1.0, 0.55)
    await fade_in.finished
    if run != _run_id:
        return
    await get_tree().create_timer(4.4).timeout
    if run != _run_id or not cinematic_active:
        return
    _finish_cinematic()

func skip_cinematic() -> void:
    if cinematic_active:
        _finish_cinematic()

func _finish_cinematic() -> void:
    if not cinematic_active:
        return
    cinematic_active = false
    _run_id += 1
    skip_button.visible = false
    var fade_out := overlay.create_tween()
    fade_out.tween_property(overlay, "modulate:a", 0.0, 0.35)
    await fade_out.finished
    overlay.visible = false
    cinematic_finished.emit()
