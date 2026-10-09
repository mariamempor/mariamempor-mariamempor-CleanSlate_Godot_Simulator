extends RefCounted
# Os testes apagam o save e destravam finais. Para não mexer na campanha de
# quem roda o teste, o save e a galeria são guardados no início (take) e
# devolvidos no fim (give).

static func take() -> Dictionary:
	var backup: Dictionary = {}
	for path: String in [GameManager.SAVE_PATH, Campaign.META_PATH]:
		if FileAccess.file_exists(path):
			backup[path] = FileAccess.get_file_as_string(path)
	return backup

static func give(backup: Dictionary) -> void:
	for path: String in [GameManager.SAVE_PATH, Campaign.META_PATH]:
		if backup.has(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			file.store_string(str(backup[path]))
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Campaign._load_meta()
