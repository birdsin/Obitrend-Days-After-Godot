@tool
extends EditorPlugin

var dock: VBoxContainer
var task_input: TextEdit
var context_input: TextEdit
var response_input: TextEdit
var status_label: Label

const CHATGPT_URL := "https://chatgpt.com/"

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "DAY'S AFTER AI"
	dock.custom_minimum_size = Vector2(280, 300)

	var heading := Label.new()
	heading.text = "DAY'S AFTER • ChatGPT Helper"
	heading.add_theme_font_size_override("font_size", 16)
	dock.add_child(heading)

	var note := Label.new()
	note.text = "No API key or paid API calls. Copy a prompt to ChatGPT, then review its answer here."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(note)

	var task_label := Label.new()
	task_label.text = "What do you want help with?"
	dock.add_child(task_label)

	task_input = TextEdit.new()
	task_input.placeholder_text = "Example: Fix the START GAME button without changing other scenes."
	task_input.custom_minimum_size = Vector2(0, 70)
	task_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(task_input)

	var context_label := Label.new()
	context_label.text = "Relevant script/error/context (optional)"
	dock.add_child(context_label)

	context_input = TextEdit.new()
	context_input.placeholder_text = "Paste only the relevant code or error. Remove secrets first."
	context_input.custom_minimum_size = Vector2(0, 110)
	context_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(context_input)

	var copy_button := Button.new()
	copy_button.text = "1. Copy safe prompt"
	copy_button.pressed.connect(_copy_prompt)
	dock.add_child(copy_button)

	var open_button := Button.new()
	open_button.text = "2. Open ChatGPT"
	open_button.pressed.connect(_open_chatgpt)
	dock.add_child(open_button)

	var response_label := Label.new()
	response_label.text = "Paste ChatGPT's suggested code here for reference"
	dock.add_child(response_label)

	response_input = TextEdit.new()
	response_input.placeholder_text = "Paste the answer here. This helper does not apply code automatically."
	response_input.custom_minimum_size = Vector2(0, 100)
	response_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(response_input)

	var copy_response_button := Button.new()
	copy_response_button.text = "Copy response text"
	copy_response_button.pressed.connect(_copy_response)
	dock.add_child(copy_response_button)

	status_label = Label.new()
	status_label.text = "Safe mode: no files are modified by this panel."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status_label)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()

func _build_prompt() -> String:
	var task := task_input.text.strip_edges()
	var context := context_input.text.strip_edges()
	if task.is_empty():
		task = "Help me inspect and improve my DAY'S AFTER Godot project."
	return """You are helping with DAY'S AFTER, an Android-first game built with Godot 4.x.

Safety requirements:
- Do not assume files or APIs that have not been shown.
- Preserve existing working gameplay and project structure.
- Explain the root cause before proposing changes.
- Return complete replacement code only for the specific file requested, and name its exact path.
- Do not change unrelated files, merge branches, publish builds, or connect production services.
- Prefer Godot 4.x APIs compatible with the Android editor.
- Give a short test checklist for Android.
- Never request or expose API keys, passwords, signing keys, or tokens.
- Do not claim code has been tested unless it actually has.

Task:
""" + task + """

Relevant code, error, or context:
""" + (context if not context.is_empty() else "(None provided)") + """

First explain the safest minimal fix. Wait for approval before suggesting broader changes.
"""

func _copy_prompt() -> void:
	DisplayServer.clipboard_set(_build_prompt())
	status_label.text = "Prompt copied. Open ChatGPT and paste it into the chat."

func _open_chatgpt() -> void:
	OS.shell_open(CHATGPT_URL)
	status_label.text = "ChatGPT opened in your browser/app if supported. Paste the copied prompt there."

func _copy_response() -> void:
	if response_input.text.strip_edges().is_empty():
		status_label.text = "Paste a response first."
		return
	DisplayServer.clipboard_set(response_input.text)
	status_label.text = "Response text copied. Review it before changing project files."
