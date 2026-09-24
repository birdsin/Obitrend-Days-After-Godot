extends Node
## External mission-content foundation.
## Mission packs are kept outside the base APK and can be loaded from
## user://days_after_content/ as downloadable .pck files when a server is added.

const CONTENT_ROOT := "user://days_after_content"

var loaded_packs: Dictionary = {}

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_ROOT))

func get_pack_path(pack_id: String) -> String:
    return CONTENT_ROOT.path_join("%s.pck" % pack_id)

func has_pack(pack_id: String) -> bool:
    return FileAccess.file_exists(get_pack_path(pack_id))

func load_pack(pack_id: String) -> bool:
    if loaded_packs.get(pack_id, false):
        return true
    var path := get_pack_path(pack_id)
    if not FileAccess.file_exists(path):
        return false
    var loaded := ProjectSettings.load_resource_pack(path, false)
    if loaded:
        loaded_packs[pack_id] = true
    return loaded

func get_storage_status() -> Dictionary:
    var total := 0
    var dir := DirAccess.open(CONTENT_ROOT)
    if dir:
        dir.list_dir_begin()
        var file_name := dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.to_lower().ends_with(".pck"):
                var file := FileAccess.open(CONTENT_ROOT.path_join(file_name), FileAccess.READ)
                if file:
                    total += file.get_length()
                    file.close()
            file_name = dir.get_next()
        dir.list_dir_end()
    return {
        "root": CONTENT_ROOT,
        "bytes": total,
        "gigabytes": float(total) / 1073741824.0
    }
