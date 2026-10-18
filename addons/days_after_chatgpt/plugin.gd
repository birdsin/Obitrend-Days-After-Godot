@tool
extends EditorPlugin

const CHATGPT_URL := "https://chatgpt.com/"
const OPENAI_RESPONSES_URL := "https://api.openai.com/v1/responses"
const API_KEY_SETTING := "days_after_chatgpt/openai_api_key"
const MODEL_SETTING := "days_after_chatgpt/model"
const DEFAULT_MODEL := "gpt-5-mini"

var dock: VBoxContainer
var task_input: TextEdit
var context_input: TextEdit
var response_input: TextEdit
var api_key_input: LineEdit
var model_input: LineEdit
var status_label: Label
var ask_button: Button
var http: HTTPRequest

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "DAY'S AFTER AI"
	dock.custom_minimum_size = Vector2(300, 360)

	var heading := Label.new()
	heading.text = "DAY'S AFTER • ChatGPT Assistant"
	heading.add_theme_font_size_override("font_size", 16)
	dock.add_child(heading)

	var note := Label.new()
	note.text = "Live mode calls the OpenAI API and may incur usage charges. The key is stored in this editor's user settings, not in your project files."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(note)

	var key_label := Label.new()
	key_label.text = "OpenAI API key (saved to local editor settings)"
	dock.add_child(key_label)

	api_key_input = LineEdit.new()
	api_key_input.placeholder_text = "Paste API key here"
	api_key_input.secret = true
	api_key_input.clear_button_enabled = true
	dock.add_child(api_key_input)

	var model_label := Label.new()
	model_label.text = "Model"
	dock.add_child(model_label)

	model_input = LineEdit.new()
	model_input.text = DEFAULT_MODEL
	model_input.placeholder_text = DEFAULT_MODEL
	dock.add_child(model_input)

	var task_label := Label.new()
	task_label.text = "What do you want help with?"
	dock.add_child(task_label)

	task_input = TextEdit.new()
	task_input.placeholder_text = "Example: Diagnose the START GAME button without changing other scenes."
	task_input.custom_minimum_size = Vector2(0, 65)
	task_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(task_input)

	var context_label := Label.new()
	context_label.text = "Relevant script/error/context (optional)"
	dock.add_child(context_label)

	context_input = TextEdit.new()
	context_input.placeholder_text = "Paste relevant code or errors only. Remove secrets first."
	context_input.custom_minimum_size = Vector2(0, 95)
	context_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(context_input)

	var save_key_button := Button.new()
	save_key_button.text = "Save API settings on this device"
	save_key_button.pressed.connect(_save_settings)
	dock.add_child(save_key_button)

	ask_button = Button.new()
	ask_button.text = "Ask OpenAI (API usage may cost money)"
	ask_button.pressed.connect(_ask_openai)
	dock.add_child(ask_button)

	var copy_prompt_button := Button.new()
	copy_prompt_button.text = "Copy prompt for ChatGPT app instead"
	copy_prompt_button.pressed.connect(_copy_prompt)
	dock.add_child(copy_prompt_button)

	var response_label := Label.new()
	response_label.text = "Assistant response (read-only workflow; no automatic code changes)"
	dock.add_child(response_label)

	response_input = TextEdit.new()
	response_input.editable = false
	response_input.custom_minimum_size = Vector2(0, 150)
	response_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	dock.add_child(response_input)

	var copy_response_button := Button.new()
	copy_response_button.text = "Copy response text"
	copy_response_button.pressed.connect(_copy_response)
	dock.add_child(copy_response_button)

	status_label = Label.new()
	status_label.text = "Safe mode: this panel does not edit project files."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status_label)

	http = HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	_load_settings()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	if http:
		http.request_completed.disconnect(_on_request_completed)
		http.queue_free()

func _editor_settings() -> EditorSettings:
	return get_editor_interface().get_editor_settings()

func _load_settings() -> void:
	var settings := _editor_settings()
	if settings.has_setting(API_KEY_SETTING):
		api_key_input.text = str(settings.get_setting(API_KEY_SETTING))
	if settings.has_setting(MODEL_SETTING):
		model_input.text = str(settings.get_setting(MODEL_SETTING))
	if model_input.text.strip_edges().is_empty():
		model_input.text = DEFAULT_MODEL

func _save_settings() -> void:
	var settings := _editor_settings()
	settings.set_setting(API_KEY_SETTING, api_key_input.text.strip_edges())
	var model := model_input.text.strip_edges()
	if model.is_empty():
		model = DEFAULT_MODEL
		model_input.text = model
	settings.set_setting(MODEL_SETTING, model)
	status_label.text = "Saved to local Godot editor settings. Do not commit or share your editor settings or API key."

func _build_prompt() -> String:
	var task := task_input.text.strip_edges()
	var context := context_input.text.strip_edges()
	if task.is_empty():
		task = "Help me inspect and improve my DAY'S AFTER Godot project."
	return """You are helping with DAY'S AFTER, an Android-first game built with Godot 4.x.

Safety requirements:
- Preserve existing working gameplay and project structure.
- Explain the likely root cause before proposing a fix.
- Name the exact file path for every proposed code change.
- Suggest the smallest safe change and avoid unrelated files.
- Do not merge branches, publish builds, or change production settings.
- Prefer Godot 4.x APIs and give an Android test checklist.
- Never request or reveal API keys, passwords, signing keys, or tokens.
- Do not claim the project was tested unless it actually was.
- Do not apply code automatically; return suggestions for manual review.

Task:
""" + task + """

Relevant code, error, or context:
""" + (context if not context.is_empty() else "(None provided)") + """

Start with a concise diagnosis and the safest minimal fix.
"""

func _ask_openai() -> void:
	var key := api_key_input.text.strip_edges()
	if key.is_empty():
		status_label.text = "Enter your OpenAI API key first. It will not be added to project files."
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		status_label.text = "A request is already in progress."
		return

	_save_settings()
	ask_button.disabled = true
	response_input.text = ""
	status_label.text = "Contacting OpenAI…"

	var model := model_input.text.strip_edges()
	if model.is_empty():
		model = DEFAULT_MODEL
	var payload := {
		"model": model,
		"instructions": "You are a careful Godot 4.x coding assistant for the DAY'S AFTER Android game. Preserve existing working behavior. Never request secrets. Suggest minimal, reviewable changes only. Do not claim to have run or tested the project. Never edit files automatically.",
		"input": _build_prompt(),
		"max_output_tokens": 1800
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + key
	])
	var err := http.request(OPENAI_RESPONSES_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		ask_button.disabled = false
		status_label.text = "Could not start request (error %s). Check network and Godot HTTP support." % err

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	ask_button.disabled = false
	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		status_label.text = "Network request failed (result %s). Check internet and try again." % result
		response_input.text = body_text
		return

	var parsed: Variant = JSON.parse_string(body_text)
	if response_code < 200 or response_code >= 300:
		status_label.text = "OpenAI returned HTTP %s. Check the message below and your API billing/permissions." % response_code
		response_input.text = body_text
		return
	if typeof(parsed) != TYPE_DICTIONARY:
		status_label.text = "Could not read the API response."
		response_input.text = body_text
		return

	var pieces: Array[String] = []
	var output_items: Variant = parsed.get("output", [])
	if output_items is Array:
		for item in output_items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var content_items: Variant = item.get("content", [])
			if content_items is Array:
				for part in content_items:
					if typeof(part) == TYPE_DICTIONARY and str(part.get("type", "")) == "output_text":
						pieces.append(str(part.get("text", "")))
	if pieces.is_empty():
		response_input.text = "No text was found in the API response. Raw response:\n" + body_text
		status_label.text = "Request finished, but no output text was found."
	else:
		response_input.text = "\n\n".join(pieces)
		status_label.text = "Response received. Review it carefully; no project files were changed."

func _copy_prompt() -> void:
	DisplayServer.clipboard_set(_build_prompt())
	OS.shell_open(CHATGPT_URL)
	status_label.text = "Prompt copied. Paste it into ChatGPT. No API request was made."

func _copy_response() -> void:
	if response_input.text.strip_edges().is_empty():
		status_label.text = "There is no response to copy yet."
		return
	DisplayServer.clipboard_set(response_input.text)
	status_label.text = "Response copied. Review suggestions before manually editing project files."
